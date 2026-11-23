#!/usr/bin/env python3
"""Render a JSON file as one tabbed HTML page.

Usage: render_overview.py <page.json> <out.html>

Two shapes, told apart by the top-level keys (schema: references/schema.md):
- a PR overview (`pr`, `overview`, `architecture`, `spec`, `review`): the four fixed /pr-overview tabs;
- a walkthrough (`page`, `tabs`): the tabs the JSON names, each a list of blocks, with collapsible
  `details` blocks for depth (/walkthrough).

The model fills the JSON; this script validates it, escapes every string and writes the page. A missing
or mistyped field prints one line per problem to stderr and exits 1, so a broken JSON never becomes a
half-empty page.
"""

import html
import json
import re
import sys

MERMAID = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs"
STATUSES = {"Met": "ok", "Met in UI": "warn", "Met · PO open": "warn", "Partly": "warn",
            "Not met": "bad", "Out of scope": "mute"}
TONES = {"ok", "warn", "bad", "mute"}
# Walkthrough block types and the keys each may carry besides "type".
BLOCK_KEYS = {"text": {"text", "ref"}, "heading": {"text"}, "command": {"text"}, "steps": {"items"}, "list": {"items"},
              "table": {"head", "rows"}, "diagram": {"mermaid", "label"}, "note": {"text", "ref", "tone"},
              "tiles": {"items"}, "cols": {"boxes"}, "details": {"summary", "blocks"}}
TAB_ID = re.compile(r"[a-z][a-z0-9-]*")
# Hashes claude.ai keeps for itself on a published page (plus any comment-*): a tab with one would never open.
RESERVED = {"settings", "sidebar", "customize", "upgrade", "downloads"}
INLINE = re.compile(r"`([^`]+)`|\*\*([^*]+)\*\*")
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
  pre.mermaid[data-processed] { white-space: normal; cursor: zoom-in; border-radius: 6px; padding: 6px;
    transition: background .12s, outline-color .12s; outline: 1px solid transparent; }
  pre.mermaid[data-processed]:hover, pre.mermaid[data-processed]:focus-visible { background: var(--hi); outline-color: var(--accent); }
  pre.mermaid svg { max-width: 100%; height: auto; }
  dialog.dmodal { padding: 0; border: 1px solid var(--line); border-radius: 10px; background: var(--panel); color: var(--fg);
    width: min(94vw, 1360px); max-width: 94vw; max-height: 92vh; overflow: hidden; }
  dialog.dmodal::backdrop { background: rgba(1, 20, 35, .75); backdrop-filter: blur(2px); }
  .dmodal-bar { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 10px 14px;
    background: var(--hi); border-bottom: 1px solid var(--line); }
  .dmodal-title { font-size: 13px; font-weight: 600; color: var(--fg); }
  .dmodal-actions { display: flex; gap: 6px; align-items: center; }
  .dmodal-actions button { background: var(--panel); color: var(--fg); border: 1px solid var(--line); border-radius: 6px;
    padding: 3px 9px; font: inherit; font-size: 12px; cursor: pointer; }
  .dmodal-body { overflow: auto; max-height: calc(92vh - 50px); padding: 20px; display: flex; justify-content: center;
    align-items: flex-start; background: var(--bg); }
  .dmodal-body svg { max-width: none; height: auto; display: block; }
  .tablewrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; background: var(--panel); }
  table { border-collapse: collapse; width: 100%; font-size: 14px; }
  th, td { text-align: left; vertical-align: top; padding: 7px 10px; border-bottom: 1px solid var(--line); }
  th { background: var(--hi); font-size: 12px; text-transform: uppercase; letter-spacing: .06em; }
  td.ev { font-family: var(--mono); font-size: 12px; color: var(--muted); overflow-wrap: anywhere; min-width: 200px; }
  .first { background: var(--hi); border: 1px solid var(--accent); border-radius: 8px; padding: 14px 18px; margin-top: 18px; }
  .first a { color: var(--accent); }
  footer { margin-top: 32px; font-size: 12px; color: var(--muted); }
  code { font-size: 13px; }
  h3.sub { margin: 22px 0 8px; }
  .wt > p, .wt > ol, .wt > ul { max-width: 78ch; }
  .wt > .box, .wt > .cols, .wt > .tablewrap, .wt .note, details > .tablewrap { margin: 12px 0; }
  ol.steps > li { margin: 8px 0; }
  .ref { font-family: var(--mono); font-size: 12px; color: var(--muted); }
  pre.cmd { margin: 10px 0; padding: 10px 14px; background: var(--panel); border: 1px solid var(--line); border-radius: 8px;
    font-family: var(--mono); font-size: 13px; overflow-x: auto; white-space: pre; }
  details { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 0 16px; margin: 8px 0; }
  details[open] { padding-bottom: 12px; }
  summary { cursor: pointer; padding: 10px 0; font-weight: 600; }
  details .tablewrap, details pre.cmd, details .box { background: var(--bg); }
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
  // A diagram in a closed <details> has no size to lay out in: it is drawn when the section opens.
  const nodes = [...scope.querySelectorAll('pre.mermaid:not([data-processed])')].filter(n => !n.closest('details:not([open])'));
  if (nodes.length) { try { await mm.run({ nodes }); } catch (err) { console.error(err); } }
  nodes.forEach(n => {
    if (n.querySelector('svg:not([aria-roledescription="error"])')) {
      n.tabIndex = 0; n.setAttribute('role', 'button'); n.title = 'Click to enlarge diagram';
      n.setAttribute('aria-label', 'Enlarge diagram');
    }
  });
}
const dmodal = document.getElementById('diagram-modal');
const dbody = dmodal.querySelector('.dmodal-body');
const dtitle = dmodal.querySelector('.dmodal-title');
let dbase = 0, dscale = 1, dfit = 1;
function applyZoom(s) {
  dscale = Math.min(4, Math.max(0.5, s));
  const svg = dbody.querySelector('svg');
  if (svg && dbase > 0) svg.style.width = Math.round(dbase * dscale) + 'px';
}
function openDiagram(pre) {
  const svg = pre.querySelector('svg:not([aria-roledescription="error"])');
  if (!svg) return;
  const parts = [];
  const card = pre.closest('.card, section.panel');
  const h = card && card.querySelector('h3, h2');
  if (h) parts.push(h.textContent.trim());
  const box = pre.closest('.box');
  const lbl = box && box.querySelector(':scope > .label');
  if (lbl) parts.push(lbl.textContent.trim());
  dtitle.textContent = parts.join(' — ') || 'Diagram';
  const clone = svg.cloneNode(true);
  clone.style.maxWidth = 'none';
  clone.removeAttribute('height');
  const vb = svg.viewBox && svg.viewBox.baseVal;
  dbase = (vb && vb.width > 0) ? vb.width : svg.getBoundingClientRect().width || 600;
  dbody.replaceChildren(clone);
  dmodal.showModal();
  dfit = Math.min(2.2, Math.max(1.2, (dbody.clientWidth - 40) / dbase));
  applyZoom(dfit);
}
document.addEventListener('click', ev => {
  const pre = ev.target.closest('pre.mermaid[data-processed]');
  if (pre && !pre.closest('dialog')) openDiagram(pre);
});
document.addEventListener('keydown', ev => {
  if ((ev.key === 'Enter' || ev.key === ' ') && ev.target.matches('pre.mermaid[data-processed]')) {
    ev.preventDefault(); openDiagram(ev.target);
  }
});
dmodal.addEventListener('click', ev => { if (ev.target === dmodal) dmodal.close(); });
dmodal.addEventListener('close', () => { dbody.replaceChildren(); });
dmodal.querySelector('[data-zoom="in"]').addEventListener('click', () => applyZoom(dscale + 0.25));
dmodal.querySelector('[data-zoom="out"]').addEventListener('click', () => applyZoom(dscale - 0.25));
dmodal.querySelector('[data-zoom="fit"]').addEventListener('click', () => applyZoom(dfit));
dmodal.querySelector('[data-close]').addEventListener('click', () => dmodal.close());
// ?expand opens every collapsible section on load: check_diagrams.py uses it to draw the diagrams inside them.
if (new URLSearchParams(location.search).has('expand')) document.querySelectorAll('details').forEach(d => { d.open = true; });
document.addEventListener('toggle', ev => { if (ev.target.open) draw(ev.target); }, true);
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


def tile(obj, path):
    label, value = need(obj, "label", str, path), need(obj, "value", str, path)
    tone = opt(obj, "tone", str, path) or "mute"
    if tone not in TONES:
        errors.append(f"{path}.tone: must be one of {sorted(TONES)}")
    return f'<div class="tile {e(tone)}"><b>{e(value)}</b><span>{e(label)}</span></div>' if label and value else ""


def shell(name, meta, h1, lead, nav, panels, footer):
    """The page around the tabs: head, theme toggle, title block, tab bar, footer and script. Every argument is HTML."""
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{name}</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
  <div class="top"><p class="meta">{meta}</p>
    <button class="theme" id="theme" type="button">Light / dark</button></div>
  <h1>{h1}</h1>
  {lead}
  <nav class="tabs" aria-label="Sections">
    {nav}
  </nav>
  {panels}
  <footer>{footer}</footer>
</div>
<dialog id="diagram-modal" class="dmodal" aria-label="Enlarged diagram">
  <div class="dmodal-bar">
    <span class="dmodal-title"></span>
    <div class="dmodal-actions">
      <button type="button" data-zoom="out" aria-label="Zoom out">&minus;</button>
      <button type="button" data-zoom="fit">Fit</button>
      <button type="button" data-zoom="in" aria-label="Zoom in">+</button>
      <button type="button" data-close aria-label="Close">&times;</button>
    </div>
  </div>
  <div class="dmodal-body"></div>
</dialog>
<script type="module">
const MERMAID_URL = {json.dumps(MERMAID)};
{JS}
</script>
</body>
</html>
"""


def inline(text):
    """Escape a walkthrough string, then turn `code` and **bold** into tags: the only markup it may carry."""
    return INLINE.sub(lambda m: f"<code>{m.group(1)}</code>" if m.group(1) is not None else f"<b>{m.group(2)}</b>", e(text))


def known(obj, allowed, path):
    """Record an error per key of `obj` outside `allowed`: a misspelt optional key (`refs`) would otherwise vanish."""
    if isinstance(obj, dict):
        for key in sorted(set(obj) - set(allowed)):
            errors.append(f"{path}.{key}: unknown key (allowed: {sorted(allowed)})")


def line(item, path, block=False):
    """A string, or {"text", "ref"?}; ref is the path:line behind the sentence, shown after it in small type.
    With `block`, item is a text or note block, whose keys blocks() has already checked."""
    if isinstance(item, str) and item.strip():
        return inline(item)
    if not isinstance(item, dict):
        errors.append(f"{path}: expected non-empty str or object with text")
        return ""
    if not block:
        known(item, {"text", "ref"}, path)
    text, ref = need(item, "text", str, path), opt(item, "ref", str, path)
    if not text:
        return ""
    return inline(text) + (f' <span class="ref">{e(ref)}</span>' if ref else "")


def table(b, p):
    head, rows = str_list(b, "head", p), need(b, "rows", list, p) or []
    if not rows:
        errors.append(f"{p}.rows: needs at least one row")
    trs = []
    for j, row in enumerate(rows):
        if not isinstance(row, list) or len(row) != len(head):
            errors.append(f"{p}.rows[{j}]: expected {len(head)} cells")
            continue
        cells = "".join(f"<td>{line(c, f'{p}.rows[{j}][{k}]')}</td>" for k, c in enumerate(row))
        trs.append(f"<tr>{cells}</tr>")
    ths = "".join(f"<th>{e(h)}</th>" for h in head)
    return f'<div class="tablewrap"><table><thead><tr>{ths}</tr></thead><tbody>{"".join(trs)}</tbody></table></div>'


def blocks(items, path, inside=None):
    """Render a list of walkthrough blocks. `inside` names the enclosing details or cols block, which hold no
    details or cols of their own."""
    if not isinstance(items, list) or not items:
        errors.append(f"{path}: needs at least one block")
        return ""
    out = []
    for i, b in enumerate(items):
        p = f"{path}[{i}]"
        kind = need(b, "type", str, p)
        if kind is None:
            continue
        if kind not in BLOCK_KEYS:
            errors.append(f"{p}.type: {kind!r} not in {sorted(BLOCK_KEYS)}")
            continue
        known(b, BLOCK_KEYS[kind] | {"type"}, p)
        if kind in ("details", "cols") and inside:
            errors.append(f"{p}: a {kind} block cannot sit inside a {inside} block")
        elif kind == "text":
            out.append(f"<p>{line(b, p, block=True)}</p>")
        elif kind == "note":
            tone = opt(b, "tone", str, p) or "warn"
            if tone not in ("warn", "bad"):
                errors.append(f"{p}.tone: must be warn or bad")
            out.append(f'<div class="note{" bad" if tone == "bad" else ""}">{line(b, p, block=True)}</div>')
        elif kind == "heading":
            out.append(f'<h3 class="sub">{inline(need(b, "text", str, p) or "")}</h3>')
        elif kind == "command":
            out.append(f'<pre class="cmd">{e(need(b, "text", str, p) or "")}</pre>')
        elif kind in ("steps", "list"):
            rows = need(b, "items", list, p) or []
            if not rows:
                errors.append(f"{p}.items: needs at least one entry")
            lis = "".join(f"<li>{line(x, f'{p}.items[{j}]')}</li>" for j, x in enumerate(rows))
            out.append(f'<ol class="steps">{lis}</ol>' if kind == "steps" else f"<ul>{lis}</ul>")
        elif kind == "table":
            out.append(table(b, p))
        elif kind == "diagram":
            label = opt(b, "label", str, p)
            head = f'<p class="label">{e(label)}</p>' if label else ""
            out.append(f'<div class="box">{head}{diagram(b, p)}</div>')
        elif kind == "tiles":
            tiles = []
            for j, t in enumerate(need(b, "items", list, p) or []):
                known(t, {"label", "value", "tone"}, f"{p}.items[{j}]")
                tiles.append(tile(t, f"{p}.items[{j}]"))
            out.append(f'<div class="tiles">{"".join(tiles)}</div>')
        elif kind == "cols":
            boxes = []
            for j, box in enumerate(need(b, "boxes", list, p) or []):
                bp = f"{p}.boxes[{j}]"
                known(box, {"label", "blocks"}, bp)
                label = need(box, "label", str, bp)
                body = blocks(box.get("blocks") if isinstance(box, dict) else None, f"{bp}.blocks", "cols")
                boxes.append(f'<div class="box"><p class="label">{e(label or "")}</p>{body}</div>')
            if len(boxes) < 2:
                errors.append(f"{p}.boxes: needs at least two boxes")
            out.append(f'<div class="cols">{"".join(boxes)}</div>')
        else:  # details
            summary = inline(need(b, "summary", str, p) or "")
            out.append(f'<details><summary>{summary}</summary>{blocks(b.get("blocks"), f"{p}.blocks", "details")}</details>')
    return "".join(out)


def build_walkthrough(data):
    page = need(data, "page", dict, "$")
    tabs = need(data, "tabs", list, "$")
    footer = need(data, "footer", str, "$")
    if page is None or tabs is None:
        return None
    known(data, {"page", "tabs", "footer"}, "$")
    known(page, {"name", "title", "summary", "source", "head", "date"}, "page")
    name, title, summary = (need(page, k, str, "page") for k in ("name", "title", "summary"))
    source, head, date = (need(page, k, str, "page") for k in ("source", "head", "date"))
    if len(tabs) < 2:
        errors.append("tabs: needs at least two tabs")
    nav, panels, seen = [], [], set()
    for i, t in enumerate(tabs):
        p = f"tabs[{i}]"
        if not isinstance(t, dict):
            errors.append(f"{p}: expected object")
            continue
        known(t, {"id", "label", "title", "blocks"}, p)
        tid, label, heading = (need(t, k, str, p) for k in ("id", "label", "title"))
        if tid and (not TAB_ID.fullmatch(tid) or tid in RESERVED or tid.startswith("comment-")):
            errors.append(f"{p}.id: {tid!r} must be lower-case letters, digits and dashes, and not one of "
                          f"{sorted(RESERVED)} or comment-*")
        if tid and tid in seen:
            errors.append(f"{p}.id: {tid!r} is used by an earlier tab")
        seen.add(tid)
        body = blocks(t.get("blocks"), f"{p}.blocks")
        if tid and label and heading:
            nav.append(f'<a href="#{e(tid)}">{e(label)}</a>')
            panels.append(f'<section class="panel wt{"" if panels else " on"}" id="{e(tid)}"><h2>{inline(heading)}</h2>{body}</section>')
    if errors:
        return None
    return shell(e(name), f"{e(source)} · {e(head)} · {e(date)}", e(title), f"<p>{inline(summary)}</p>",
                 "".join(nav), "\n  ".join(panels), e(footer))


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
    tiles = [tile(t, f"overview.tiles[{i}]") for i, t in enumerate(need(ov, "tiles", list, "overview") or [])]
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

    nav = '<a href="#overview">Overview</a><a href="#architecture">Architecture</a><a href="#spec">Spec</a><a href="#review">Review</a>'
    panels = f"""<section class="panel on" id="overview">
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
    <div class="cols">{"".join(sections)}</div>{f'<p class="meta">Source: {e(rsrc)}</p>' if rsrc else ""}</section>"""
    return shell(f"PR !{e(pid)} overview", f"{e(repo)} · PR !{e(pid)} · head {e(head)} · {e(date)}", e(ptitle),
                 f'<p>{e(summary)}</p><p class="meta">{e(size)}</p>', nav, panels, e(footer))


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
    walkthrough = isinstance(data, dict) and "tabs" in data
    page = build_walkthrough(data) if walkthrough else build(data)
    if errors or page is None:
        for problem in errors or ["the JSON is missing a top-level section"]:
            print(f"error: {problem}", file=sys.stderr)
        return 1
    with open(sys.argv[2], "w", encoding="utf-8") as fh:
        fh.write(page)
    print(sys.argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
