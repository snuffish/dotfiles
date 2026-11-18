#!/usr/bin/env python3
"""Render collect.py's JSON as the /standup-recap --artifact page (HTML for the Artifact tool).

Usage: render_page.py <collector.json> <phrases.json> <out.html>

phrases.json maps an entry key (`wi:31438`, `chore:<repo>:<branch>`, or `reviews` for the shared
review card) to the one-line phrase the model wrote for it. An entry with no phrase shows its title only.
"""

import datetime as dt
import html
import json
import sys

TODAY_CAP = 6
STATE_CHIPS = {"Pull Request": "wait", "Resolved": "ship", "Closed": "ship", "Done": "ship"}

CSS = """
  /* Layout: count bar, then "Say these" (rank shown by card size) beside a Today / Blockers rail */
  :root {
    --bg: #f7f8f6; --surface: #ffffff; --fg: #1d2420; --muted: #5d6862; --line: #dfe3df;
    --accent: #2f5d8a; --ship: #1f7a45; --ship-bg: #e3f2e8; --wait: #8a5a00; --wait-bg: #fbf1d9;
    --bad: #a3271f; --bad-bg: #fbe4e1;
    --body: "Atkinson Hyperlegible", "Segoe UI", system-ui, sans-serif;
    --mono: "IBM Plex Mono", ui-monospace, "SF Mono", Menlo, monospace;
  }
  @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
    --bg: #121614; --surface: #1a201d; --fg: #e4e9e5; --muted: #9aa69f; --line: #2c3430;
    --accent: #8db8e3; --ship: #7fd3a0; --ship-bg: #1d3226; --wait: #e8c06a; --wait-bg: #352b14;
    --bad: #f19a90; --bad-bg: #3a1d1a; color-scheme: dark } }
  :root[data-theme="dark"] {
    --bg: #121614; --surface: #1a201d; --fg: #e4e9e5; --muted: #9aa69f; --line: #2c3430;
    --accent: #8db8e3; --ship: #7fd3a0; --ship-bg: #1d3226; --wait: #e8c06a; --wait-bg: #352b14;
    --bad: #f19a90; --bad-bg: #3a1d1a; color-scheme: dark }
  body { background: var(--bg); color: var(--fg); font-family: var(--body); font-size: 15px; line-height: 1.5; }
  .wrap { max-width: 1040px; margin: 0 auto; padding-block: 28px 40px;
    padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
  header { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 8px; }
  h1 { font-size: 26px; margin: 0; text-wrap: balance; }
  .meta { font-family: var(--mono); font-size: 12px; color: var(--muted); }
  .counts { display: flex; flex-wrap: wrap; gap: 8px 28px; margin: 16px 0 24px; padding-block: 12px;
    border-block: 1px solid var(--line); font-variant-numeric: tabular-nums; }
  .counts div { display: flex; align-items: baseline; gap: 6px; }
  .counts b { font-size: 24px; }
  .counts span { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }
  .counts .zero b { color: var(--ship); }
  .counts .hot b { color: var(--bad); }
  .grid { display: grid; grid-template-columns: minmax(0, 1.7fr) minmax(0, 1fr); gap: 28px; }
  @media (max-width: 760px) { .grid { grid-template-columns: 1fr; } }
  h2 { font-size: 12px; text-transform: uppercase; letter-spacing: .09em; color: var(--muted); margin: 0 0 10px; }
  .list { display: flex; flex-direction: column; gap: 10px; }
  .item { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 12px 14px;
    display: flex; flex-direction: column; gap: 6px; }
  .item.top { padding: 16px 18px; }
  .item.top .title { font-size: 18px; }
  .title { font-weight: 700; font-size: 15px; text-wrap: balance; }
  .id { font-family: var(--mono); font-weight: 500; color: var(--accent); margin-right: 6px; }
  .say { margin: 0; }
  .facts { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { font-family: var(--mono); font-size: 12px; padding: 1px 8px; border-radius: 999px; border: 1px solid var(--line); color: var(--muted); }
  .chip.ship { background: var(--ship-bg); color: var(--ship); border-color: transparent; }
  .chip.wait { background: var(--wait-bg); color: var(--wait); border-color: transparent; }
  .chip.bad { background: var(--bad-bg); color: var(--bad); border-color: transparent; }
  details { margin-top: 14px; color: var(--muted); font-size: 14px; }
  summary { cursor: pointer; }
  summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  details ul { margin: 8px 0 0; padding-left: 18px; }
  .rail { display: flex; flex-direction: column; gap: 22px; }
  .rail ul { list-style: none; margin: 0; padding: 0; border-top: 1px solid var(--line); }
  .rail li { padding: 8px 0; border-bottom: 1px solid var(--line); font-size: 14px; display: flex; flex-direction: column; }
  .rail li small { color: var(--muted); font-size: 12px; }
  .none { color: var(--ship); font-weight: 700; margin: 0; }
  .empty { color: var(--muted); margin: 0; }
  footer { margin-top: 32px; font-size: 12px; color: var(--muted); display: flex; flex-direction: column; gap: 4px; }
"""

e = html.escape


def label(entry):
    """`#id` for a work item, `!id` for a review, the branch for a chore."""
    kind, _, rest = entry["key"].partition(":")
    if kind == "wi":
        return f"#{rest}"
    if kind == "review":
        return f"!{rest}"
    return entry.get("branch") or rest


def chips(entry, reason):
    out = []
    if entry["commits"]:
        n = len(entry["commits"])
        out.append(("", f"{n} commit{'s' if n != 1 else ''}"))
    for pr in entry["prs"]:
        for ev in pr["events"]:
            out.append(("ship" if ev == "completed" else "bad" if ev == "abandoned" else "wait", f"!{pr['id']} {ev}"))
    if entry["states"]:
        to = entry["states"][-1]["to"]
        out.append((STATE_CHIPS.get(to, ""), f"→ {to}"))
    if entry["pipelines"]:
        ok = all(p["result"] == "succeeded" for p in entry["pipelines"])
        out.append(("ship" if ok else "bad", "CI green" if ok else "CI red"))
    for vote in entry["votes"]:
        out.append(("", f"reviewed: {vote}"))
    if entry["comments"]:
        out.append(("", f"{entry['comments']} comment{'s' if entry['comments'] != 1 else ''}"))
    if reason == "needs review" and not any(k == "wait" for k, _ in out):
        out.append(("wait", "needs review"))
    return "".join(f'<span class="chip {k}">{e(t)}</span>' for k, t in out)


def card(entry, reason, phrase, top):
    say = f'<p class="say">{e(phrase)}</p>' if phrase else ""
    return (f'<article class="item{" top" if top else ""}"><div class="title"><span class="id">{e(label(entry))}</span>'
            f'{e(entry["title"])}</div>{say}<div class="facts">{chips(entry, reason)}</div></article>')


def review_card(entries, phrase):
    """One card for every PR reviewed in the window: a chip per PR with my last vote."""
    tags = "".join(f'<span class="chip">!{x["pr"]} {e(x["votes"][-1] if x["votes"] else "commented")}</span>'
                   for x in entries)
    authors = ", ".join(dict.fromkeys(x.get("author") or "" for x in entries if x.get("author")))
    title = f"PRs by {authors}" if authors else "PRs for the team"
    say = f'<p class="say">{e(phrase)}</p>' if phrase else ""
    return (f'<article class="item"><div class="title"><span class="id">Reviews</span>{e(title)}</div>'
            f'{say}<div class="facts">{tags}</div></article>')


def today_rows(today):
    rows = []
    for pr in today["open_prs"]:
        sub = ("approved by " + ", ".join(pr["approved_by"]) if pr["approved_by"] else
               "changes requested by " + ", ".join(pr["changes_requested_by"]) if pr["changes_requested_by"] else
               "draft" if pr["draft"] else "awaiting review")
        rows.append((f"!{pr['id']} {pr['title']}", sub))
    rows += [(f"#{i['id']} {i.get('System.Title')}", f"in {i.get('System.State')}")
             for i in today["active_items"] if i.get("System.State") == "Pull Request"]
    rows += [(w["branch"], f"{w['ahead']} commits ahead, no PR")
             for w in sorted(today["wip_branches"], key=lambda w: -w["ahead"])]
    rows += [(f"{t.get('repo')} {t.get('branch')}", "unpushed commits") for t in today["unpushed"]]
    return rows


def blocker_text(b):
    if b["type"] == "pipeline_failed":
        return f"!{b['pr']} {b['pipeline']} failed"
    if b["type"] == "waiting_on_review":
        return f"!{b['pr']} {b['title']}: no reviewer vote yet"
    return f"#{b['id']} {b['title']}: Blocked"


def render(data, phrases):
    window = data["window"]
    start = dt.date.fromisoformat(window["start"])
    by_key = {x["key"]: x for x in data["yesterday"]}
    picked = {k for h in data["highlights"] for k in h.get("keys", [h["key"]])}
    rest = [x for x in data["yesterday"] if x["key"] not in picked]
    c = data["counts"]
    repos = " + ".join(r["name"] for r in data["meta"]["repos"] if r["work"]) or "no work repos"

    count_bar = "".join(
        f'<div class="{cls}"><b>{n}</b><span>{e(name)}</span></div>' for n, name, cls in (
            (c["commits"], "commits", ""), (c["prs_completed"], "PRs completed", ""),
            (c["reviews"], "PRs reviewed", ""), (c["blockers"], "blockers", "hot" if c["blockers"] else "zero")))
    cards = "".join(
        review_card([by_key[k] for k in h["keys"]], phrases.get("reviews")) if h["key"] == "reviews"
        else card(by_key[h["key"]], h["reason"], phrases.get(h["key"]), i < 3)
        for i, h in enumerate(data["highlights"]))
    if not cards:
        cards = '<p class="empty">Nothing recorded in this window.</p>'
    also = ""
    if rest:
        lines = "".join(f"<li>{e(label(x))}: {e(phrases.get(x['key']) or x['title'])}</li>" for x in rest)
        also = f"<details><summary>Also, {len(rest)} smaller item{'s' if len(rest) != 1 else ''}</summary><ul>{lines}</ul></details>"

    rows = today_rows(data["today"])
    shown = "".join(f"<li>{e(t)}<small>{e(s)}</small></li>" for t, s in rows[:TODAY_CAP])
    more = f"<li><small>+{len(rows) - TODAY_CAP} more</small></li>" if len(rows) > TODAY_CAP else ""
    today_html = f"<ul>{shown}{more}</ul>" if rows else '<p class="empty">Nothing open.</p>'
    blockers = data["blockers"]
    blockers_html = (f"<ul>{''.join(f'<li>{e(blocker_text(b))}</li>' for b in blockers)}</ul>" if blockers
                     else '<p class="none">None found</p>')

    foot = [f"Collected {e(window['today'])} by /standup-recap from git, Azure DevOps and claude-mem sessions."]
    if window.get("today_is_live"):
        foot.append("Today and Blockers show the live state, not the state on that date.")
    foot += [f"⚠ {e(n)}" for n in data["notes"]]

    heading = f"Standup · {start:%A} {start.day} {start:%B}"
    return f"""<title>Standup {start:%A} {start.day} {start:%b}</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>{CSS}</style>
<div class="wrap">
  <header><h1>{e(heading)}</h1><div class="meta">window {e(window['start'])} · {e(repos)}</div></header>
  <div class="counts">{count_bar}</div>
  <div class="grid">
    <section><h2>Say these</h2><div class="list">{cards}</div>{also}</section>
    <aside class="rail">
      <div><h2>Today</h2>{today_html}</div>
      <div><h2>Blockers</h2>{blockers_html}</div>
    </aside>
  </div>
  <footer>{''.join(f'<div>{f}</div>' for f in foot)}</footer>
</div>
"""


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    with open(sys.argv[2], encoding="utf-8") as f:
        phrases = json.load(f)
    with open(sys.argv[3], "w", encoding="utf-8") as f:
        f.write(render(data, phrases))
    print(sys.argv[3])


if __name__ == "__main__":
    main()
