#!/usr/bin/env python3
"""Collect feedback I received in a window and print it as JSON for /analyze-personal-feedback.

Sources: Azure DevOps PR review threads and votes (live, via `az repos` / `az devops invoke`) and an
optional export folder (.eml mail, .vtt call transcripts, Telegram result.json,
.txt/.md notes). Each source degrades to one line in `notes` when it fails.
"""

import argparse
import concurrent.futures
import datetime as dt
import email
import email.policy
import json
import re
import shutil
import subprocess
from pathlib import Path

TIMEOUT = 30
WORKERS = 8
PAGE = 100
OPEN_PR_GRACE_DAYS = 120  # stop paging once PRs were created this long before the window
TEXT_CAP = 1200
APPENDIX_CAP = 220
VOTES = {10: "approved", 5: "approved with suggestions", -5: "waiting for author", -10: "rejected"}
BOT_NAME = re.compile(r"build service|project collection|azure pipelines|\[bot\]|microsoft\.visualstudio", re.I)
# Words that mark a message as feedback in English or Swedish; --no-filter keeps every message.
CUES = re.compile(
    r"\b(feedback|should|shouldn't|could you|can you|please|why|instead|consider|suggest|concern|worried|"
    r"nice|great|good job|well done|thanks|thank you|love|impressed|confus|unclear|too (long|much|many)|"
    r"borde|kan du|kunde du|varför|hellre|istället|bra jobbat|snyggt|grymt|tack|förvirr|otydlig|för (lång|mycket))",
    re.I,
)

NOTES = []
META = {"az_calls": 0}


class Skip(Exception):
    pass


def iso(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def clip(text):
    text = re.sub(r"\s+", " ", text or "").strip()
    return text if len(text) <= TEXT_CAP else text[:TEXT_CAP] + " …"


# --- Azure DevOps -----------------------------------------------------------------------------

def az(*args):
    if shutil.which("az") is None:
        raise Skip("az not installed")
    try:
        p = subprocess.run(["az", *args, "-o", "json"], capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        raise Skip(f"`az {' '.join(args[:3])}` timed out after {TIMEOUT}s")
    META["az_calls"] += 1
    if p.returncode != 0:
        raise Skip(f"`az {' '.join(args[:3])}` failed: {(p.stderr.strip().splitlines() or ['?'])[0][:160]}")
    return json.loads(p.stdout or "null")


def pr_web_url(org, pr):
    repo = pr["repository"]
    return f"{org.rstrip('/')}/{repo['project']['name']}/_git/{repo['name']}/pullrequest/{pr['pullRequestId']}"


def is_me(identity, me):
    return (identity.get("uniqueName") or "").lower() == me


def pr_items(org, pr, me, since, role):
    """Feedback on one PR: others' comments (author role) or others' replies in my threads (reviewer role)."""
    repo = pr["repository"]
    where = {"source": "ado-pr", "pr": pr["pullRequestId"], "pr_title": pr["title"], "repo": repo["name"],
             "url": pr_web_url(org, pr), "role": role}
    threads = az("devops", "invoke", "--area", "git", "--resource", "pullRequestThreads", "--route-parameters",
                 f"project={repo['project']['name']}", f"repositoryId={repo['id']}",
                 f"pullRequestId={pr['pullRequestId']}", "--api-version", "7.1")
    items = []
    for t in threads.get("value", []):
        comments = [c for c in t.get("comments", []) if c.get("commentType") == "text" and not c.get("isDeleted")]
        if not comments or (role == "reviewer" and not is_me(comments[0]["author"], me)):
            continue
        for c in comments:
            a = c["author"]
            when = iso(c.get("publishedDate"))
            if is_me(a, me) or BOT_NAME.search(a.get("displayName", "")) or not when or when < since:
                continue
            items.append({**where, "who": a.get("displayName"), "when": c["publishedDate"][:10],
                          "file": (t.get("threadContext") or {}).get("filePath"), "thread_status": t.get("status"),
                          "text": clip(c.get("content"))})
    if role == "author":
        for r in pr.get("reviewers", []):
            if not is_me(r, me) and r.get("vote") in (-5, -10) and not r.get("isContainer"):
                items.append({**where, "who": r["displayName"], "when": None, "file": None, "thread_status": None,
                              "text": f"[vote] {VOTES[r['vote']]}"})
    return items


def list_prs(flag, me, since):
    """Every PR with me as creator or reviewer that was still open at `since`, newest first, paged by --skip."""
    prs, skip = [], 0
    while True:
        page = az("repos", "pr", "list", flag, me, "--status", "all", "--top", str(PAGE), "--skip", str(skip))
        prs += [p for p in page if (iso(p.get("closedDate")) or since) >= since]
        if len(page) < PAGE or iso(page[-1]["creationDate"]) < since - dt.timedelta(days=OPEN_PR_GRACE_DAYS):
            return prs
        skip += PAGE


def collect_ado(since):
    org = next((l.split("=", 1)[1].strip() for l in subprocess.run(
        ["az", "devops", "configure", "-l"], capture_output=True, text=True).stdout.splitlines()
                if l.startswith("organization")), None)
    if not org:
        raise Skip("no default organization in `az devops configure -l`")
    me = az("account", "show", "--query", "user.name").lower()
    prs = [(p, "author") for p in list_prs("--creator", me, since)]
    prs += [(p, "reviewer") for p in list_prs("--reviewer", me, since) if not is_me(p["createdBy"], me)]
    items, me_name = [], next((p["createdBy"]["displayName"] for p, r in prs if r == "author"), None)
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        for fut in [pool.submit(pr_items, org, pr, me, since, role) for pr, role in prs]:
            try:
                items += fut.result()
            except Skip as e:
                NOTES.append(f"ado: {e}")
    return {"me": me_name, "prs_scanned": len(prs), "items": items}


# --- Export folder -----------------------------------------------------------------------------

def keep(text, filtered):
    return bool(text) and (not filtered or CUES.search(text))


def from_eml(path, me, since, filtered):
    msg = email.message_from_bytes(path.read_bytes(), policy=email.policy.default)
    when = email.utils.parsedate_to_datetime(msg["date"]) if msg["date"] else None
    sender = str(msg["from"] or "")
    if (when and when < since) or any(m.lower() in sender.lower() for m in me):
        return []
    body = msg.get_body(preferencelist=("plain", "html"))
    text = body.get_content() if body else ""
    text = re.split(r"\n(?:On .+wrote:|Från:|From:|-----Original)", re.sub(r"<[^>]+>", " ", text), maxsplit=1)[0]
    if not keep(text, filtered):
        return []
    return [{"source": "email", "who": sender, "when": when.date().isoformat() if when else None,
             "where": f"mail: {msg['subject']}", "file": path.name, "text": clip(text)}]


def from_vtt(path, me, since, filtered):
    when = dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc)
    if when < since:
        return []
    items = []
    for who, text in re.findall(r"<v ([^>]+)>(.*?)</v>", path.read_text(errors="replace"), re.S):
        if any(m.lower() in who.lower() for m in me) or not keep(text, filtered):
            continue
        items.append({"source": "call", "who": who.strip(), "when": when.date().isoformat(),
                      "where": f"transcript: {path.stem}", "file": path.name, "text": clip(text)})
    return items


def from_telegram(path, me, since, filtered):
    data = json.loads(path.read_text())
    chats = data.get("chats", {}).get("list", [data])
    items = []
    for chat in chats:
        for m in chat.get("messages", []):
            who, text = m.get("from") or "", m.get("text")
            text = "".join(t if isinstance(t, str) else t.get("text", "") for t in text) if isinstance(text, list) else text
            when = dt.datetime.fromisoformat(m["date"]).replace(tzinfo=dt.timezone.utc) if m.get("date") else None
            if (when and when < since) or any(x.lower() in who.lower() for x in me) or not keep(text, filtered):
                continue
            items.append({"source": "telegram", "who": who, "when": m["date"][:10],
                          "where": f"telegram: {chat.get('name') or path.stem}", "file": path.name, "text": clip(text)})
    return items


def from_text(path, me, since, filtered):
    when = dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc)
    if when < since:
        return []
    return [{"source": "note", "who": None, "when": when.date().isoformat(), "where": f"file: {path.name}",
             "file": path.name, "text": clip(path.read_text(errors="replace"))}]


READERS = {".eml": from_eml, ".vtt": from_vtt, ".json": from_telegram, ".txt": from_text, ".md": from_text}


def collect_exports(root, me, since, filtered):
    if not Path(root).expanduser().is_dir():
        NOTES.append(f"export: {root} is not a folder")
        return []
    items, skipped = [], 0
    for path in sorted(Path(root).expanduser().rglob("*")):
        reader = READERS.get(path.suffix.lower())
        if not path.is_file() or not reader:
            skipped += path.is_file()
            continue
        try:
            items += reader(path, me, since, filtered)
        except Exception as e:  # one bad export file must not sink the run
            NOTES.append(f"export: {path.name} unreadable ({type(e).__name__})")
    if skipped:
        NOTES.append(f"export: {skipped} file(s) with unsupported extensions skipped")
    return items


# --- Main --------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--exports", help="folder with .eml, .vtt, Telegram result.json, .txt/.md files")
    ap.add_argument("--me", action="append", default=[], help="name or address that is me (repeatable)")
    ap.add_argument("--no-ado", action="store_true")
    ap.add_argument("--no-filter", action="store_true", help="keep export messages without feedback cue words")
    ap.add_argument("--format", choices=("json", "md"), default="json", help="md prints the appendix table only")
    ap.add_argument("--from", dest="from_json", help="render an earlier run's JSON instead of collecting again")
    a = ap.parse_args()
    if a.from_json:
        out = json.loads(Path(a.from_json).read_text())
        print(appendix(out) if a.format == "md" else json.dumps(out, ensure_ascii=False, indent=1))
        return

    now = dt.datetime.now(dt.timezone.utc)
    since = now - dt.timedelta(days=a.days)
    out = {"window": {"since": since.date().isoformat(), "until": now.date().isoformat(), "days": a.days},
           "sources": {}, "items": [], "notes": NOTES, "meta": META}
    me = list(a.me)
    if not a.no_ado:
        try:
            ado = collect_ado(since)
            out["sources"]["ado"] = {"prs_scanned": ado["prs_scanned"], "items": len(ado["items"])}
            out["items"] += ado["items"]
            me.append(ado["me"] or "")
        except Skip as e:
            NOTES.append(f"ado: {e}")
    if a.exports:
        me = [m for m in me if m] or [subprocess.run(["git", "config", "user.name"], capture_output=True,
                                                    text=True).stdout.strip()]
        ex = collect_exports(a.exports, me, since, not a.no_filter)
        out["sources"]["exports"] = {"root": a.exports, "items": len(ex)}
        out["items"] += ex
    else:
        NOTES.append("email, calls, chat: no --exports folder given, so only Azure DevOps was read")
    out["items"].sort(key=lambda i: i.get("when") or "")
    print(appendix(out) if a.format == "md" else json.dumps(out, ensure_ascii=False, indent=1))


def appendix(out):
    """Every item as one markdown table row, grouped by person, for the report's appendix."""
    cell = lambda s: (s or "").replace("|", "\\|").replace("\n", " ")
    rows = ["| When | Who | Where | What they said |", "| --- | --- | --- | --- |"]
    for i in sorted(out["items"], key=lambda i: (i.get("who") or "", i.get("when") or "")):
        where = (f"[!{i['pr']}]({i['url']}) {i['role']}" + (f" `{i['file'].rsplit('/', 1)[-1]}`" if i.get("file") else "")
                 if i["source"] == "ado-pr" else i["where"])
        text = i["text"] if len(i["text"]) <= APPENDIX_CAP else i["text"][:APPENDIX_CAP] + " …"
        rows.append(f"| {i.get('when') or '–'} | {cell(i.get('who'))} | {cell(where)} | {cell(text)} |")
    return "\n".join(rows)


if __name__ == "__main__":
    main()
