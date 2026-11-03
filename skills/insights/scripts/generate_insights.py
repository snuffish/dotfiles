#!/usr/bin/env python3
"""Antigravity /insights: collect session data, then render the report.

  collect  read agy transcripts -> usage-data/{session-meta,digests}/<id>.json, list ids that need a facet
  render   validate facets + sections.json, aggregate charts, fill assets/report_template.html

The agent writes facets/<id>.json and sections.json; this script writes no narrative text.
"""

import argparse
import html
import json
import os
import re
import statistics
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path

DEFAULT_BRAIN = Path("~/.gemini/antigravity-cli/brain").expanduser()
DEFAULT_DATA = Path("~/.gemini/antigravity-cli/usage-data").expanduser()
TEMPLATE = Path(__file__).resolve().parent.parent / "assets" / "report_template.html"

KNOWN_TYPES = {
    "USER_INPUT", "PLANNER_RESPONSE", "GENERIC", "SYSTEM_MESSAGE", "EPHEMERAL_MESSAGE", "CODE_ACTION",
    "RUN_COMMAND", "VIEW_FILE", "CHECKPOINT", "GREP_SEARCH", "ERROR_MESSAGE", "CONVERSATION_HISTORY",
    "LIST_DIRECTORY", "SEARCH_WEB", "READ_URL_CONTENT", "ASK_QUESTION",
}
EDIT_TOOLS = {"edit_file", "write_file", "write_to_file", "replace_file_content"}
LANGS = {
    ".py": "Python", ".ts": "TypeScript", ".tsx": "TypeScript", ".js": "JavaScript", ".jsx": "JavaScript",
    ".cs": "C#", ".md": "Markdown", ".json": "JSON", ".sh": "Shell", ".yml": "YAML", ".yaml": "YAML",
    ".sql": "SQL", ".css": "CSS", ".html": "HTML", ".go": "Go", ".rs": "Rust", ".toml": "TOML",
    ".ps1": "PowerShell", ".razor": "Razor", ".csproj": "XML", ".xml": "XML",
}
GIT_COMMIT = re.compile(r"\bgit\s+(?:-C\s+\S+\s+)?commit\b")
USER_REQ = re.compile(r"<USER_REQUEST>(.*?)</USER_REQUEST>", re.DOTALL)
EXIT_NONZERO = re.compile(r"exited with code ([1-9]\d*)")
DIGEST_MAX_BYTES = 6144

FACET_KEYS = [
    "underlying_goal", "goal_categories", "outcome", "user_satisfaction_counts", "agent_helpfulness",
    "session_type", "friction_counts", "friction_detail", "primary_success", "brief_summary",
    "session_id", "transcript_mtime",
]

# "text" = non-empty str, "int" = integer, [spec] = non-empty list of spec, {k: spec} = object with required keys
SECTIONS_SPEC = {
    "at_a_glance": {"whats_working": "text", "whats_hindering": "text", "quick_wins": "text", "ambitious_workflows": "text"},
    "project_areas": {"areas": [{"name": "text", "session_count": "int", "description": "text"}]},
    "interaction_style": {"narrative": "text", "key_pattern": "text"},
    "what_works": {"intro": "text", "impressive_workflows": [{"title": "text", "description": "text"}]},
    "friction_analysis": {"intro": "text", "categories": [{"category": "text", "description": "text", "examples": ["text"]}]},
    "suggestions": {
        "rules_additions": [{"addition": "text", "why": "text"}],
        "features_to_try": [{"feature": "text", "one_liner": "text", "why_for_you": "text", "example_code": "text"}],
        "usage_patterns": [{"title": "text", "suggestion": "text", "detail": "text", "copyable_prompt": "text"}],
    },
    "on_the_horizon": {"intro": "text", "opportunities": [{"title": "text", "whats_possible": "text", "how_to_try": "text", "copyable_prompt": "text"}]},
    "fun_ending": {"headline": "text", "detail": "text"},
}


# ---------------------------------------------------------------- collect

def decode(v):
    """agy stores tool args as JSON-encoded strings (e.g. '"/path"'); unwrap one level."""
    if isinstance(v, str) and len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        try:
            return json.loads(v)
        except ValueError:
            return v
    return v


def parse_ts(s):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def user_text(content):
    m = USER_REQ.findall(content or "")
    if m:
        return "\n".join(x.strip() for x in m if x.strip())
    return re.sub(r"<[^>]+>", "", content or "").strip()


def project_of(paths):
    """Most common 5-component prefix among absolute paths ('' when none)."""
    c = Counter("/".join(p.split("/")[:5]) for p in paths if p.startswith("/") and p.count("/") >= 4)
    return c.most_common(1)[0][0] if c else ""


def parse_transcript(path):
    sid = path.parent.parent.parent.name
    tool_counts, err_cats, langs, unknown = Counter(), Counter(), Counter(), Counter()
    files, paths, hours, user_ts = set(), [], [], []
    resp_times, prompts, replies, failed_cmds, errors = [], [], [], [], []
    added = removed = commits = users = assistants = 0
    first = last = None
    last_cmd = ""
    prev_model_ts = None

    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            d = json.loads(line)
        except ValueError:
            continue
        typ, content = d.get("type"), d.get("content") or ""
        ts = parse_ts(d.get("created_at"))
        if ts:
            first = first or ts
            last = ts
        if typ not in KNOWN_TYPES:
            unknown[typ or "?"] += 1

        if typ == "USER_INPUT":
            text = user_text(content)
            if not text:
                continue
            users += 1
            prompts.append(text)
            if ts:
                user_ts.append(ts)
                hours.append(ts.astimezone().hour)
                if prev_model_ts and users > 1:
                    dt = (ts - prev_model_ts).total_seconds()
                    if 0 < dt <= 3600:
                        resp_times.append(round(dt, 1))
        elif typ == "PLANNER_RESPONSE":
            if ts:
                prev_model_ts = ts
            if content.strip():
                assistants += 1
                replies.append(content.strip())
            # tool_calls are only on PLANNER_RESPONSE lines (checked on all local transcripts); GENERIC lines carry results
            for tc in d.get("tool_calls") or []:
                name = tc.get("name") or "unknown"
                args = {k: decode(v) for k, v in (tc.get("args") or {}).items()}
                tool_counts[name] += 1
                p = args.get("Path") or args.get("TargetFile") or args.get("AbsolutePath")
                if isinstance(p, str):
                    paths.append(p)
                if name == "run_command":
                    last_cmd = str(args.get("CommandLine", ""))
                    if GIT_COMMIT.search(last_cmd):
                        commits += 1
                    if isinstance(args.get("Cwd"), str):
                        paths.append(args["Cwd"])
                if name in EDIT_TOOLS and isinstance(p, str):
                    files.add(p)
                    ext = os.path.splitext(p)[1].lower()
                    if ext in LANGS:
                        langs[LANGS[ext]] += 1
                    new = args.get("Replacement") or args.get("Content") or args.get("ReplacementContent") or ""
                    old = args.get("Target") or args.get("TargetContent") or ""
                    added += len(str(new).splitlines())
                    removed += len(str(old).splitlines())
        elif typ in ("GENERIC", "SYSTEM_MESSAGE"):
            if ts and typ == "GENERIC":
                prev_model_ts = ts
            m = EXIT_NONZERO.search(content)
            if m:
                err_cats["Command Failed"] += 1
                if last_cmd:
                    failed_cmds.append(f"{last_cmd[:150]} (exit {m.group(1)})")
            if "Target must exactly match" in content:
                err_cats["Edit Mismatch"] += 1
                errors.append("edit_file: Target must exactly match existing file text")
        elif typ == "ERROR_MESSAGE":
            err_cats["Error Message"] += 1
            errors.append(content.strip()[:150])

    if not users:
        return None
    duration = round((last - first).total_seconds() / 60) if first and last else 0
    meta = {
        "session_id": sid,
        "project_path": project_of(paths),
        "start_time": first.isoformat() if first else "",
        "duration_minutes": duration,
        "user_message_count": users,
        "assistant_message_count": assistants,
        "tool_counts": dict(tool_counts),
        "languages": dict(langs),
        "git_commits": commits,
        "user_response_times": resp_times,
        "tool_errors": sum(err_cats.values()),
        "tool_error_categories": dict(err_cats),
        "lines_added": added,
        "lines_removed": removed,
        "files_modified": len(files),
        "message_hours": hours,
        "user_message_timestamps": [t.isoformat() for t in user_ts],
        "first_prompt": prompts[0][:200],
        "unknown_step_types": dict(unknown),
        "transcript_mtime": int(path.stat().st_mtime * 1000),
    }
    digest = {
        "session_id": sid,
        "transcript_mtime": meta["transcript_mtime"],
        "project_path": meta["project_path"],
        "user_prompts": [p[:500] for p in prompts],
        "agent_replies": [r[:200] for r in replies[-5:]],
        "failed_commands": failed_cmds[:10],
        "errors": errors[:10],
        "counts": {"tools": dict(tool_counts), "tool_errors": meta["tool_errors"], "files_modified": len(files), "git_commits": commits},
    }
    fit_digest(digest)
    return meta, digest


def fit_digest(digest):
    size = lambda: len(json.dumps(digest, ensure_ascii=False, indent=2).encode())  # as written to disk
    for key in ("agent_replies", "errors", "failed_commands", "user_prompts"):
        while size() > DIGEST_MAX_BYTES and len(digest[key]) > 1:
            digest[key].pop(0 if key == "agent_replies" else -1)
    if size() > DIGEST_MAX_BYTES:
        digest["user_prompts"] = [p[:150] for p in digest["user_prompts"]]
    while size() > DIGEST_MAX_BYTES and len(digest["user_prompts"]) > 1:
        digest["user_prompts"].pop()


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def facet_is_fresh(data, sid, mtime):
    try:
        return json.loads((data / "facets" / f"{sid}.json").read_text())["transcript_mtime"] == mtime
    except (OSError, ValueError, KeyError, TypeError):
        return False


def cmd_collect(a):
    brain, data = Path(a.brain), Path(a.data)
    cutoff = time.time() - a.days * 86400
    found = [p for p in brain.glob("*/.system_generated/logs/transcript.jsonl") if p.stat().st_mtime >= cutoff]
    found.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    selected, pending, unknown = [], [], Counter()
    for p in found[: a.max]:
        parsed = parse_transcript(p)
        if not parsed:
            continue
        meta, digest = parsed
        sid = meta["session_id"]
        write_json(data / "session-meta" / f"{sid}.json", meta)
        write_json(data / "digests" / f"{sid}.json", digest)
        unknown.update(meta["unknown_step_types"])
        selected.append(sid)
        if not facet_is_fresh(data, sid, meta["transcript_mtime"]):
            pending.append(sid)
    write_json(data / "selected.json", selected)
    print(f"transcripts in window: {len(found)} (cap {a.max}); analysed sessions with user messages: {len(selected)}")
    print(f"facets cached: {len(selected) - len(pending)}; facets needed: {len(pending)}")
    if unknown:
        print(f"unknown step types (schema drift?): {dict(unknown)}")
    for sid in pending:
        print(sid)
    return 0


# ---------------------------------------------------------------- render

def check(spec, value, where, errs):
    if spec == "text":
        if not (isinstance(value, str) and value.strip()):
            errs.append(f"{where}: missing or empty text")
    elif spec == "int":
        if not isinstance(value, int) or isinstance(value, bool):
            errs.append(f"{where}: must be an integer")
    elif isinstance(spec, list):
        if not (isinstance(value, list) and value):
            errs.append(f"{where}: missing or empty list")
            return
        for i, item in enumerate(value):
            check(spec[0], item, f"{where}[{i}]", errs)
    elif isinstance(spec, dict):
        if not isinstance(value, dict):
            errs.append(f"{where}: missing object")
            return
        for k, s in spec.items():
            check(s, value.get(k), f"{where}.{k}", errs)


def load_inputs(data):
    errs = []
    try:
        selected = json.loads((data / "selected.json").read_text())
    except (OSError, ValueError):
        sys.exit("render: selected.json missing; run collect first")
    metas, facets = {}, {}
    for sid in selected:
        try:
            metas[sid] = json.loads((data / "session-meta" / f"{sid}.json").read_text())
        except (OSError, ValueError):
            errs.append(f"session-meta/{sid}.json: missing")
            continue
        try:
            f = json.loads((data / "facets" / f"{sid}.json").read_text())
        except (OSError, ValueError):
            errs.append(f"facets/{sid}.json: missing")
            continue
        missing = [k for k in FACET_KEYS if k not in f]
        if missing:
            errs.append(f"facets/{sid}.json: missing keys {missing}")
        elif f["transcript_mtime"] != metas[sid]["transcript_mtime"]:
            errs.append(f"facets/{sid}.json: stale (transcript changed since it was rated)")
        else:
            facets[sid] = f
    try:
        sections = json.loads((data / "sections.json").read_text())
    except (OSError, ValueError):
        sections = {}
        errs.append("sections.json: missing or invalid JSON")
    for name, spec in SECTIONS_SPEC.items():
        check(spec, sections.get(name), name, errs)
    if errs:
        sys.exit("render: refusing to write a report; fix:\n  " + "\n  ".join(errs))
    return selected, metas, facets, sections


def E(v):
    """Every value that reaches the HTML goes through this."""
    return html.escape(str(v), quote=True)


def bars(items, color, limit=8):
    items = [(k, v) for k, v in items if v][:limit]
    if not items:
        return '<div class="bar-label">no data</div>'
    top = max(v for _, v in items)
    return "\n".join(
        f'<div class="bar-row"><div class="bar-label" title="{E(k)}">{E(k)}</div>'
        f'<div class="bar-track"><div class="bar-fill" style="width:{v / top * 100:.1f}%;background:{color}"></div></div>'
        f'<div class="bar-value">{v:,}</div></div>'
        for k, v in items
    )


def chart(title, items, color, limit=8):
    return f'<div class="chart-card"><div class="chart-title">{E(title)}</div>{bars(items, color, limit)}</div>'


def sum_counters(dicts):
    c = Counter()
    for d in dicts:
        c.update({k: v for k, v in (d or {}).items() if isinstance(v, int)})
    return c


def pretty(k):
    return str(k).replace("_", " ").title()


def response_buckets(times):
    edges = [(2, 10, "2-10s"), (10, 30, "10-30s"), (30, 60, "30s-1m"), (60, 120, "1-2m"), (120, 300, "2-5m"), (300, 900, "5-15m"), (900, 3601, ">15m")]
    return [(label, sum(1 for t in times if lo <= t < hi)) for lo, hi, label in edges]


def parallel_overlap(metas):
    """A->B->A switches between sessions within 30 min: (events, sessions involved, messages involved)."""
    ev = sorted((parse_ts(t), sid) for sid, m in metas.items() for t in m["user_message_timestamps"])
    events, involved, last_seen, prev = 0, set(), {}, None
    for ts, sid in ev:
        if prev and prev != sid and sid in last_seen and (ts - last_seen[sid]).total_seconds() <= 1800:
            events += 1
            involved.update((sid, prev))
        last_seen[sid] = ts
        prev = sid
    return events, len(involved), events


def render_html(selected, metas, facets, sections):
    tmpl = TEMPLATE.read_text(encoding="utf-8")
    ms = [metas[s] for s in selected]
    fs = [facets[s] for s in selected]
    msgs = sum(m["user_message_count"] for m in ms)
    stamps = sorted(parse_ts(t) for m in ms for t in m["user_message_timestamps"])
    days = (stamps[-1].date() - stamps[0].date()).days + 1 if stamps else 1
    span = f"{stamps[0].date()} to {stamps[-1].date()}" if stamps else ""
    added, removed = sum(m["lines_added"] for m in ms), sum(m["lines_removed"] for m in ms)
    files = sum(m["files_modified"] for m in ms)

    stats = [(f"{msgs:,}", "Messages"), (f"+{added:,}/-{removed:,}", "Lines"), (f"{files:,}", "Files"), (str(days), "Days"), (f"{msgs / days:.1f}", "Msgs/Day")]
    stats_html = "".join(f'<div class="stat"><div class="stat-value">{E(v)}</div><div class="stat-label">{E(l)}</div></div>' for v, l in stats)

    mc = lambda counter: [(pretty(k), v) for k, v in counter.most_common()]
    rt = [t for m in ms for t in m["user_response_times"]]
    ev, sess_n, msg_n = parallel_overlap(metas)
    rt_title = "User Response Time Distribution" + (f" (median {statistics.median(rt):.0f}s)" if rt else "")
    charts = {
        "WORK": chart("What You Wanted", mc(sum_counters(f["goal_categories"] for f in fs)), "#2563eb")
        + chart("Top Tools Used", sum_counters(m["tool_counts"] for m in ms).most_common(), "#0891b2"),
        "USAGE": chart("Languages", sum_counters(m["languages"] for m in ms).most_common(), "#10b981")
        + chart("Session Types", mc(Counter(f["session_type"] for f in fs)), "#8b5cf6"),
        "TIMING": chart(rt_title, response_buckets(rt), "#6366f1")
        + chart("Parallel Sessions", [("Overlap events", ev), ("Sessions involved", sess_n)], "#0ea5e9"),
        "WINS": chart("Tool Errors Encountered", sum_counters(m["tool_error_categories"] for m in ms).most_common(), "#dc2626")
        + chart("What Helped Most", mc(Counter(f["primary_success"] for f in fs if f["primary_success"] != "none")), "#16a34a"),
        "FRICTION": chart("Outcomes", mc(Counter(f["outcome"] for f in fs)), "#8b5cf6")
        + chart("Primary Friction Types", mc(sum_counters(f["friction_counts"] for f in fs)), "#dc2626")
        + chart("Inferred Satisfaction (model-estimated)", mc(sum_counters(f["user_satisfaction_counts"] for f in fs)), "#eab308"),
    }

    s = sections
    g = s["at_a_glance"]
    glance = "".join(
        f'<div class="glance-section"><strong>{E(l)}:</strong> {E(g[k])}</div>'
        for k, l in (("whats_working", "What's working"), ("whats_hindering", "What's hindering you"), ("quick_wins", "Quick wins to try"), ("ambitious_workflows", "Ambitious workflows"))
    )
    areas = "".join(
        f'<div class="project-area"><div class="area-header"><span class="area-name">{E(a["name"])}</span><span class="area-count">~{E(a["session_count"])} sessions</span></div><div class="area-desc">{E(a["description"])}</div></div>'
        for a in s["project_areas"]["areas"]
    )
    style = s["interaction_style"]
    narrative = "".join(f"<p>{E(p)}</p>" for p in style["narrative"].split("\n\n") if p.strip()) + f'<div class="key-insight"><strong>Key pattern:</strong> {E(style["key_pattern"])}</div>'
    wins = "".join(f'<div class="big-win"><div class="big-win-title">{E(w["title"])}</div><div class="big-win-desc">{E(w["description"])}</div></div>' for w in s["what_works"]["impressive_workflows"])
    friction = "".join(
        f'<div class="friction-category"><div class="friction-title">{E(c["category"])}</div><div class="friction-desc">{E(c["description"])}</div><ul class="friction-examples">'
        + "".join(f"<li>{E(x)}</li>" for x in c["examples"]) + "</ul></div>"
        for c in s["friction_analysis"]["categories"]
    )
    sg = s["suggestions"]
    rules = "".join(
        f'<div class="rules-item"><input type="checkbox" class="cmd-checkbox" id="rule-{i}" data-text="{E(r["addition"])}" checked>'
        f'<div style="flex:1"><code class="cmd-code">{E(r["addition"])}</code><button class="copy-btn" onclick="copyRuleItem({i})">Copy</button><div class="cmd-why">{E(r["why"])}</div></div></div>'
        for i, r in enumerate(sg["rules_additions"])
    )
    copy_row = lambda text: f'<div class="copyable-prompt-section"><div class="copyable-prompt-row"><code class="copyable-prompt">{E(text)}</code><button class="copy-btn" onclick="copyText(this)">Copy</button></div></div>'
    features = "".join(
        f'<div class="feature-card"><div class="feature-title">{E(f["feature"])}</div><div class="feature-oneliner">{E(f["one_liner"])}</div><div class="feature-why">{E(f["why_for_you"])}</div>{copy_row(f["example_code"])}</div>'
        for f in sg["features_to_try"]
    )
    patterns = "".join(
        f'<div class="pattern-card"><div class="pattern-title">{E(p["title"])}</div><div class="pattern-summary">{E(p["suggestion"])}</div><div class="pattern-detail">{E(p["detail"])}</div>{copy_row(p["copyable_prompt"])}</div>'
        for p in sg["usage_patterns"]
    )
    hz = s["on_the_horizon"]
    horizon = "".join(
        f'<div class="horizon-card"><div class="horizon-title">{E(o["title"])}</div><div class="horizon-possible">{E(o["whats_possible"])}</div><div class="horizon-tip">{E(o["how_to_try"])}</div>{copy_row(o["copyable_prompt"])}</div>'
        for o in hz["opportunities"]
    )
    fe = s["fun_ending"]

    slots = {
        "SUBTITLE": E(f"{msgs:,} messages across {len(ms)} sessions | {span}"),
        "AT_A_GLANCE": glance, "STATS": stats_html, "PROJECT_AREAS": areas, "INTERACTION_STYLE": narrative,
        "WINS_INTRO": E(s["what_works"]["intro"]), "WINS": wins,
        "FRICTION_INTRO": E(s["friction_analysis"]["intro"]), "FRICTION": friction,
        "RULES": rules, "FEATURES": features, "PATTERNS": patterns,
        "HORIZON_INTRO": E(hz["intro"]), "HORIZON": horizon,
        "FUN_HEADLINE": E(fe["headline"]), "FUN_DETAIL": E(fe["detail"]),
    }
    slots.update({f"CHARTS_{k}": v for k, v in charts.items()})
    # single pass: inserted text is never re-expanded
    return re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: slots[m.group(1)], tmpl)


def cmd_render(a):
    data = Path(a.data)
    selected, metas, facets, sections = load_inputs(data)
    out = render_html(selected, metas, facets, sections)
    path = data / f"report-{datetime.now().strftime('%Y-%m-%d-%H%M%S')}.html"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(out)
    print(path)
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("collect")
    c.add_argument("--days", type=int, default=14)
    c.add_argument("--max", type=int, default=200)
    c.add_argument("--brain", default=str(DEFAULT_BRAIN))
    c.add_argument("--data", default=str(DEFAULT_DATA))
    c.set_defaults(fn=cmd_collect)
    r = sub.add_parser("render")
    r.add_argument("--data", default=str(DEFAULT_DATA))
    r.set_defaults(fn=cmd_render)
    a = p.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
