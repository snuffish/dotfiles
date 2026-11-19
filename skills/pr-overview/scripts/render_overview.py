#!/usr/bin/env python3
"""Render overview.json as the /pr-overview page (one HTML file, four tabs).

Usage: render_overview.py <overview.json> <out.html>

The model fills overview.json (schema: references/schema.md); this script validates it, escapes every
string and writes the page. A missing or mistyped field prints one line per problem to stderr and
exits 1, so a broken JSON never becomes a half-empty page.
"""

import html
import json
import sys

MERMAID = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs"
STATUSES = {"Met": "ok", "Met in UI": "warn", "Met · PO open": "warn", "Partly": "warn",
            "Not met": "bad", "Out of scope": "mute"}
TONES = {"ok", "warn", "bad", "mute"}
e = html.escape

CSS = """
  :root {
    --bg: #011423; --panel: #0b2438; --hi: #143652; --fg: #CBE0F0; --muted: #8fb0c9; --line: #547998;
    --ok: #9ece6a; --warn: #e0af68; --bad: #f7768e; --accent: #7aa2f7;
    --body: system-ui, -apple-system, "Segoe UI", sans-serif;
    --mono: "MesloLGS Nerd Font Mono", ui-monospace, "SF Mono", Menlo, monospace;
    color-scheme: dark;
  }
  @media (prefers-color-scheme: light) { :root:not([data-theme="dark"]) {
    --bg: #e1e2e7; --panel: #f2f3f7; --hi: #d0d5e3; --fg: #3760bf; --muted: #5c6fa3; --line: #8990b3;
    --ok: #587539; --warn: #8c6c3e; --bad: #c4294f; --accent: #2e7de9; color-scheme: light } }
  :root[data-theme="light"] {
    --bg: #e1e2e7; --panel: #f2f3f7; --hi: #d0d5e3; --fg: #3760bf; --muted: #5c6fa3; --line: #8990b3;
    --ok: #587539; --warn: #8c6c3e; --bad: #c4294f; --accent: #2e7de9; color-scheme: light }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 15px/1.55 var(--body); overflow-wrap: anywhere; }
  .wrap { max-width: 1040px; margin: 0 auto; padding: 28px 16px 48px; }
  h1 { font-size: 26px; margin: 4px 0 8px; text-wrap: balance; }
  h2 { font-size: 20px; margin: 28px 0 12px; }
  h3 { font-size: 17px; margin: 0; }
  .meta, code, .mono { font-family: var(--mono); }
  .meta { font-size: 12px; color: var(--muted); }
  p { margin: 6px 0; }
  .top { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; flex-wrap: wrap; }
  button.theme { background: var(--panel); color: var(--fg); border: 1px solid var(--line); border-radius: 6px;
    padding: 4px 10px; font: inherit; font-size: 12px; cursor: pointer; }
  nav.tabs { display: flex; gap: 4px; margin: 20px 0 16px; border-bottom: 1px solid var(--line); overflow-x: auto; }
  nav.tabs a { padding: 8px 14px; color: var(--muted); text-decoration: none; border-bottom: 2px solid transparent;
    white-space: nowrap; }
  nav.tabs a[aria-current="true"] { color: var(--fg); border-bottom-color: var(--accent); font-weight: 700; }
  nav.tabs a:focus-visible, button:focus-visible, summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  .js .panel { display: none; } .js .panel.on { display: block; }
  .panel > h2:first-child { margin-top: 4px; }
  .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin: 16px 0; }
  .tile { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 12px 14px; }
  .tile b { display: block; font-size: 26px; font-variant-numeric: tabular-nums; }
  .tile span { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }
  .tile.ok b { color: var(--ok); } .tile.warn b { color: var(--warn); } .tile.bad b { color: var(--bad); }
  .cols { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
  @media (max-width: 760px) { .cols { grid-template-columns: minmax(0, 1fr); } }
  .box, .card { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 14px 16px; min-width: 0; }
  .card { margin-bottom: 18px; display: flex; flex-direction: column; gap: 10px; }
  .label { font-size: 11px; text-transform: uppercase; letter-spacing: .09em; color: var(--muted); margin: 0 0 6px; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { font-family: var(--mono); font-size: 12px; padding: 1px 9px; border-radius: 999px; border: 1px solid var(--line); color: var(--muted); }
  .chip.ok { color: var(--ok); border-color: var(--ok); } .chip.warn { color: var(--warn); border-color: var(--warn); }
  .chip.bad { color: var(--bad); border-color: var(--bad); }
  ul { margin: 4px 0; padding-left: 20px; }
  ul.files { list-style: none; padding: 0; font-family: var(--mono); font-size: 12px; color: var(--muted); overflow-wrap: anywhere; }
  .note { border-left: 3px solid var(--warn); background: var(--hi); padding: 8px 12px; border-radius: 4px; font-size: 14px; }
  .note.bad { border-left-color: var(--bad); }
  pre.mermaid { margin: 0; overflow-x: auto; font-family: var(--mono); font-size: 12px; white-space: pre; }
  pre.mermaid[data-processed] { white-space: normal; }
  pre.mermaid svg { max-width: 100%; height: auto; }
  .tablewrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; background: var(--panel); }
  table { border-collapse: collapse; width: 100%; font-size: 14px; }
  th, td { text-align: left; vertical-align: top; padding: 7px 10px; border-bottom: 1px solid var(--line); }
  th { background: var(--hi); font-size: 12px; text-transform: uppercase; letter-spacing: .06em; }
  td.ev { font-family: var(--mono); font-size: 12px; color: var(--muted); overflow-wrap: anywhere; min-width: 200px; }
  .first { background: var(--hi); border: 1px solid var(--accent); border-radius: 8px; padding: 14px 18px; margin-top: 18px; }
  .first a { color: var(--accent); }
  footer { margin-top: 32px; font-size: 12px; color: var(--muted); }
"""

JS = """
const tabs = [...document.querySelectorAll('nav.tabs a')];
const panels = [...document.querySelectorAll('.panel')];
let mm = null;
const isLight = () => { const t = document.documentElement.dataset.theme;
  return t ? t === 'light' : matchMedia('(prefers-color-scheme: light)').matches; };
function vars() { const s = getComputedStyle(document.documentElement), g = n => s.getPropertyValue(n).trim();
  return { background: g('--bg'), primaryColor: g('--hi'), primaryTextColor: g('--fg'), primaryBorderColor: g('--line'),
    lineColor: g('--muted'), secondaryColor: g('--panel'), tertiaryColor: g('--panel'), fontFamily: g('--mono') }; }
async function draw(scope) {
  if (!mm) return;
  mm.initialize({ startOnLoad: false, theme: 'base', securityLevel: 'strict', themeVariables: vars() });
  const nodes = [...scope.querySelectorAll('pre.mermaid:not([data-processed])')];
  if (nodes.length) { try { await mm.run({ nodes }); } catch (err) { console.error(err); } }
}
function show(id) {
  if (!panels.some(p => p.id === id)) id = panels[0].id;
  panels.forEach(p => p.classList.toggle('on', p.id === id));
  tabs.forEach(a => a.setAttribute('aria-current', a.getAttribute('href') === '#' + id ? 'true' : 'false'));
  draw(document.getElementById(id));
}
document.documentElement.classList.add('js');
addEventListener('hashchange', () => show(location.hash.slice(1)));
show(location.hash.slice(1));
document.getElementById('theme').addEventListener('click', () => {
  document.documentElement.dataset.theme = isLight() ? 'dark' : 'light';
  document.querySelectorAll('pre.mermaid').forEach(n => { n.textContent = n.dataset.src; n.removeAttribute('data-processed'); });
  draw(document.querySelector('.panel.on'));
});
import(MERMAID_URL).then(m => { mm = m.default; draw(document.querySelector('.panel.on')); }).catch(console.error);
"""

errors = []


def need(obj, key, kind, path):
    """Return obj[key] when present and of `kind`; record an error otherwise."""
    if not isinstance(obj, dict) or key not in obj:
        errors.append(f"{path}.{key}: missing")
        return None
    v = obj[key]
    if not isinstance(v, kind) or (kind is str and not v.strip()):
        errors.append(f"{path}.{key}: expected non-empty {kind.__name__}")
        return None
    return v


def opt(obj, key, kind, path):
    if isinstance(obj, dict) and key in obj and obj[key] not in (None, "", []):
        return need(obj, key, kind, path)
    return None


def str_list(obj, key, path, required=True):
    v = need(obj, key, list, path) if required else opt(obj, key, list, path)
    out = []
    if required and v == []:
        errors.append(f"{path}.{key}: needs at least one entry")
    for i, x in enumerate(v or []):
        if isinstance(x, str) and x.strip():
            out.append(x)
        else:
            errors.append(f"{path}.{key}[{i}]: expected non-empty str")
    return out


def diagram(obj, path):
    """A before/after side: {"mermaid": "..."} or {"text": "..."}; returns HTML."""
    if not isinstance(obj, dict):
        errors.append(f"{path}: expected object with mermaid or text")
        return ""
    if "mermaid" in obj:
        src = need(obj, "mermaid", str, path)
        if src is None:
            return ""
        return f'<pre class="mermaid" data-src="{e(src)}">{e(src)}</pre>'
    t = need(obj, "text", str, path)
    return f"<p>{e(t)}</p>" if t else ""


def build(data):
    pr = need(data, "pr", dict, "$")
    ov = need(data, "overview", dict, "$")
    arch = need(data, "architecture", list, "$")
    spec = need(data, "spec", dict, "$")
    rev = need(data, "review", dict, "$")
    footer = need(data, "footer", str, "$")
    if None in (pr, ov, arch, spec, rev):
        return None

    pid, ptitle = need(pr, "id", str, "pr"), need(pr, "title", str, "pr")
    head, repo, date = need(pr, "head", str, "pr"), need(pr, "repo", str, "pr"), need(pr, "date", str, "pr")
    size, summary = need(pr, "size", str, "pr"), need(pr, "summary", str, "pr")

    # Overview
    problem = need(ov, "problem", dict, "overview")
    before = diagram(need(problem, "before", dict, "overview.problem"), "overview.problem.before") if problem else ""
    after = diagram(need(problem, "after", dict, "overview.problem"), "overview.problem.after") if problem else ""
    psrc = opt(problem, "source", str, "overview.problem") if problem else None
    tiles = []
    for i, t in enumerate(need(ov, "tiles", list, "overview") or []):
        p = f"overview.tiles[{i}]"
        label, value = need(t, "label", str, p), need(t, "value", str, p)
        tone = opt(t, "tone", str, p) or "mute"
        if tone not in TONES:
            errors.append(f"{p}.tone: must be one of {sorted(TONES)}")
        if label and value:
            tiles.append(f'<div class="tile {e(tone)}"><b>{e(value)}</b><span>{e(label)}</span></div>')
    first = need(ov, "review_first", dict, "overview")
    first_html = ""
    if first:
        ft, fx, tg = (need(first, k, str, "overview.review_first") for k in ("title", "text", "target"))
        ids = {c.get("id") for c in arch if isinstance(c, dict)}
        if tg and tg not in ids:
            errors.append(f"overview.review_first.target: no architecture card with id {tg!r}")
        if ft and fx and tg:
            first_html = (f'<div class="first"><p class="label">Review this first</p><h3><a href="#architecture" '
                          f'data-card="{e(tg)}">{e(ft)}</a></h3><p>{e(fx)}</p></div>')

    # Architecture
    cards = []
    for i, c in enumerate(arch):
        p = f"architecture[{i}]"
        if not isinstance(c, dict):
            errors.append(f"{p}: expected object")
            continue
        cid, title = need(c, "id", str, p), need(c, "title", str, p)
        specs = str_list(c, "spec", p)
        tags = str_list(c, "tags", p, required=False)
        files = str_list(c, "files", p)
        pb, sl = need(c, "problem", str, p), need(c, "solution", str, p)
        wins = str_list(c, "wins", p, required=False)
        b = diagram(c["before"], f"{p}.before") if c.get("before") else ""
        a = diagram(c["after"], f"{p}.after") if c.get("after") else ""
        risk = opt(c, "risk", str, p)
        if not (cid and title and pb and sl):
            continue
        chips = "".join(f'<span class="chip ok">{e(s)}</span>' for s in specs)
        chips += "".join(f'<span class="chip">{e(t)}</span>' for t in tags)
        chips += '<span class="chip bad">Open risk</span>' if risk else ""
        risk_html = '<div class="note bad">' + e(risk) + "</div>" if risk else ""
        cols = ""
        if b or a:
            cols = (f'<div class="cols"><div class="box"><p class="label">Before</p>{b}</div>'
                    f'<div class="box"><p class="label">After</p>{a}</div></div>')
        cards.append(
            f'<article class="card" id="{e(cid)}"><h3>{i + 1} · {e(title)}</h3><div class="chips">{chips}</div>'
            f'<ul class="files">{"".join(f"<li>{e(f)}</li>" for f in files)}</ul>{cols}'
            f'<p><b>Problem:</b> {e(pb)}</p><p><b>Solution:</b> {e(sl)}</p>'
            f'{"<ul>" + "".join(f"<li>{e(w)}</li>" for w in wins) + "</ul>" if wins else ""}'
            f"{risk_html}</article>")
    if not cards:
        errors.append("architecture: needs at least one card")

    # Spec
    srows, counts = [], {}
    note = opt(spec, "note", str, "spec")
    for i, r in enumerate(need(spec, "rows", list, "spec") or []):
        p = f"spec.rows[{i}]"
        rid, text, st, ev = (need(r, k, str, p) for k in ("id", "text", "status", "evidence"))
        if st is not None and st not in STATUSES:
            errors.append(f"{p}.status: {st!r} not in {sorted(STATUSES)}")
            continue
        if rid and text and st and ev:
            counts[st] = counts.get(st, 0) + 1
            srows.append(f'<tr><td class="mono">{e(rid)}</td><td>{e(text)}</td>'
                         f'<td><span class="chip {STATUSES[st]}">{e(st)}</span></td><td class="ev">{e(ev)}</td></tr>')
    if not srows:
        errors.append("spec.rows: needs at least one row")

    # Review
    sections = []
    for key, label, tone in (("findings", "Review findings", "bad"), ("po_questions", "PO questions", "warn"),
                             ("merge", "Merge state", "warn"), ("followups", "Follow-ups (out of scope)", "mute")):
        items = str_list(rev, key, "review", required=False)
        if items:
            sections.append(f'<div class="box"><p class="label">{label}</p>'
                            f'<ul>{"".join(f"<li>{e(x)}</li>" for x in items)}</ul></div>')
    rsrc = opt(rev, "source", str, "review")

    if errors:
        return None

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PR !{e(pid)} overview</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
  <div class="top"><p class="meta">{e(repo)} · PR !{e(pid)} · head {e(head)} · {e(date)}</p>
    <button class="theme" id="theme" type="button">Light / dark</button></div>
  <h1>{e(ptitle)}</h1>
  <p>{e(summary)}</p><p class="meta">{e(size)}</p>
  <nav class="tabs" aria-label="Sections">
    <a href="#overview">Overview</a><a href="#architecture">Architecture</a><a href="#spec">Spec</a><a href="#review">Review</a>
  </nav>
  <section class="panel on" id="overview">
    <h2>The problem it solves</h2>
    <div class="cols"><div class="box"><p class="label">Before</p>{before}</div>
      <div class="box"><p class="label">After</p>{after}</div></div>
    {f'<p class="meta">Source: {e(psrc)}</p>' if psrc else ""}
    <div class="tiles">{"".join(tiles)}</div>
    {first_html}
  </section>
  <section class="panel" id="architecture"><h2>How the PR is built</h2>{"".join(cards)}</section>
  <section class="panel" id="spec"><h2>Spec coverage</h2>
    <div class="chips">{"".join(f'<span class="chip {STATUSES[k]}">{e(k)}: {v}</span>' for k, v in counts.items())}</div>
    {f"<p>{e(note)}</p>" if note else ""}
    <div class="tablewrap"><table><thead><tr><th>ID</th><th>Decision</th><th>Status</th><th>Evidence</th></tr></thead>
    <tbody>{"".join(srows)}</tbody></table></div></section>
  <section class="panel" id="review"><h2>Still open</h2>
    <div class="cols">{"".join(sections)}</div>{f'<p class="meta">Source: {e(rsrc)}</p>' if rsrc else ""}</section>
  <footer>{e(footer)}</footer>
</div>
<script type="module">
const MERMAID_URL = {json.dumps(MERMAID)};
{JS}
</script>
</body>
</html>
"""


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as err:
        print(f"{sys.argv[1]}: {err}", file=sys.stderr)
        return 1
    page = build(data)
    if errors or page is None:
        for line in errors or ["overview.json is missing a top-level section"]:
            print(f"error: {line}", file=sys.stderr)
        return 1
    with open(sys.argv[2], "w", encoding="utf-8") as fh:
        fh.write(page)
    print(sys.argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
