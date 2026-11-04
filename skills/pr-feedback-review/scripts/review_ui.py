#!/usr/bin/env python3
"""Localhost review page for a pr_feedback_review artifact (stdlib only; run with python3 -I).

serve <md> [--open]   serve the page on 127.0.0.1, autosave answers to <base>.answers.json
merge <md>            merge the submitted answers back into the .md
Never talks to the PR host; writes only .answers.json and .answers.done.
"""
import argparse, hashlib, html, http.server, json, os, re, secrets, subprocess, sys, tempfile, threading, datetime

ANCHOR = re.compile(r'^### <a id="thread-([^"]+)"></a>(.*)$', re.M)
REPLY_H = re.compile(r'^#### (Ready-to-Send Reply[^\n]*|Reply \((?:skipped in|rewrite from) --ui[^\n]*)$', re.M)
SKIP_HEAD = '#### Reply (skipped in --ui — not posted)'
ADJUST_HEAD = '#### Reply (rewrite from --ui notes — not posted yet)'
DECISION = re.compile(r'^- \*\*UI decision:\*\*[^\n]*\n(?:  >[^\n]*\n)*', re.M)
MAX_BODY = 1 << 20


def base(md):
    return re.sub(r'\.md$', '', md)


def sha(md):
    with open(md, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def cells(row):
    return [c.strip() for c in row.strip().strip('|').split('|')]


def matrix(text):
    """thread id -> list of dict rows, in order (ids may repeat across PRs)."""
    rows, hdr = [], None
    for line in text.splitlines():
        if line.startswith('|') and hdr is None and 'Thread' in line and 'Category' in line:
            hdr = cells(line)
        elif hdr and line.startswith('|'):
            c = cells(line)
            if set(line) <= set('|- :'):
                continue
            m = re.search(r'#(\d+)', c[0])
            if m and len(c) == len(hdr):
                rows.append((m.group(1), dict(zip(hdr, c))))
        elif hdr and rows:
            break
    return rows


QUOTE = re.compile(r'([ \t]*\n(?:[ \t]*\n)*)((?:>[^\n]*(?:\n|$))+)')
TITLE = re.compile(r'^Thread \[#[^\]]*\]\(([^)]*)\):\s*')


def reply_block(body):
    """Match the blockquote right under a reply heading; blank lines before it are allowed."""
    return QUOTE.match(body)


def split_sections(sec):
    """Section md -> (meta md, reviewer comment md, [(heading, md)]) without the reply block."""
    sec = re.sub(r'\n-{3,}\s*$', '', sec.rstrip())
    parts = re.split(r'^#### (.+)$', sec, flags=re.M)
    meta, subs = parts[0].split('\n', 1)[1] if '\n' in parts[0] else '', []
    for h, b in zip(parts[1::2], parts[2::2]):
        if not REPLY_H.match('#### ' + h):
            subs.append((h.strip(), b.strip('\n')))
    comment = ''
    m = re.search(r'^- \*\*Reviewer Comment:\*\*[^\n]*\n((?:[ \t]+[^\n]*\n?|[ \t]*\n(?=[ \t]))*)', meta, re.M)
    if m:
        comment = '\n'.join(re.sub(r'^ {0,4}', '', l) for l in m.group(1).rstrip().split('\n'))
        comment = '\n'.join(re.sub(r'^> ?', '', l) for l in comment.split('\n'))
        meta = meta[:m.start()] + meta[m.end():]
    return meta.strip('\n'), comment.strip(), subs


def doc_info(text):
    h1 = re.search(r'^# (.+)$', text, re.M)
    head = text.split('\n---', 1)[0]
    fields, cur = [], None
    for l in head.split('\n'):
        m = re.match(r'^> \*\*([^*]+):\*\*\s*(.*?)\s*$', l)
        s = re.match(r'^>\s*- \*\*([^*]+):\*\*\s*(.*?)\s*$', l)
        if m:
            cur = [m.group(1), m.group(2), []]; fields.append(cur)
        elif s and cur:
            cur[2].append([s.group(1), s.group(2)])
    sm = re.search(r'^## Executive Summary[^\n]*\n(.*?)(?=^\||^## |^---)', text, re.M | re.S)
    return dict(title=re.sub(r'^PR Feedback Review:\s*', '', h1.group(1)) if h1 else '',
                fields=fields, summary=sm.group(1).strip() if sm else '')


def parse(text):
    """Threads in document order (ids may repeat across counterpart PRs, so key = order:id)."""
    rows = matrix(text)
    used, out = {}, []
    ms = list(ANCHOR.finditer(text))
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        sec = text[m.start():end]
        tid = m.group(1)
        n = used.get(tid, 0)
        used[tid] = n + 1
        cand = [r for t, r in rows if t == tid]
        row = cand[n] if n < len(cand) else (cand[0] if cand else {})
        h = REPLY_H.search(sec)
        reply, skipped, voice, rlabel = '', False, False, ''
        if h:
            skipped = h.group(1).startswith('Reply (skipped')
            rlabel = h.group(1)
            body = sec[h.end():]
            q = reply_block(body)
            if q:
                reply = '\n'.join(re.sub(r'^> ?', '', l) for l in q.group(2).rstrip('\n').split('\n'))
            voice = 'Voice pass: done' in rlabel or 'Voice pass: done' in body[:600]
        title = m.group(2).strip()
        tm = TITLE.match(title)
        meta, comment, subs = split_sections(sec)
        pending, notes = rlabel.startswith('Reply (rewrite from'), ''
        dm = DECISION.search(sec)
        if pending and dm:
            notes = '\n'.join(re.sub(r'^  > ?', '', l) for l in dm.group(0).split('\n')[1:] if l.startswith('  >'))
        out.append(dict(key=f'{i}:{tid}', pending_adjust=pending, notes=notes, id=tid, title=TITLE.sub('', title), url=tm.group(1) if tm else '',
                        pr=row.get('PR', ''), file=row.get('File', ''), reviewer=row.get('Reviewer', ''),
                        vote=row.get('Vote', ''), category=row.get('Category', ''), state=row.get('State at head', ''),
                        recommendation=row.get('Recommendation', ''), reply=reply, skipped=skipped, voice=voice,
                        reply_label=rlabel, has_reply=bool(h), meta=meta, comment=comment, sections=subs))
    return out


# ---------------------------------------------------------------- merge
def reconcile(old, seed):
    """Keep the user's real changes from an existing answers file; refresh everything else from the .md.

    A reply the user never touched (equal to the draft it was seeded with) follows the current draft,
    so a file seeded from an older parse or an older .md never shows stale or empty replies."""
    if old.get('md_sha256') == seed['md_sha256'] and old.get('drafts') == seed['drafts']:
        old['threads'] = {k: dict(seed['threads'][k], **old.get('threads', {}).get(k, {})) for k in seed['threads']}
        return old
    out = dict(seed)
    for k, new in seed['threads'].items():
        o = old.get('threads', {}).get(k)
        if not o:
            continue
        od = old.get('drafts', {}).get(k, '')
        keep = dict(new, decision=o.get('decision', new['decision']), own=o.get('own', ''), notes=o.get('notes', ''))
        if keep['decision'] == 'adjust' and new['decision'] != 'adjust':  # the session already rewrote it from the notes
            keep.update(decision=new['decision'], notes='')
        if o.get('reply', od).strip() and o.get('reply', od).strip() != od.strip():
            keep['reply'] = o['reply']
        out['threads'][k] = keep
    return out


def merge(md, force=False):
    ap, text = base(md) + '.answers.json', open(md, encoding='utf-8').read()
    if not os.path.exists(ap):
        print('no answers file', file=sys.stderr); return 1
    ans = json.load(open(ap, encoding='utf-8'))
    threads = parse(text)
    if not threads:
        print('no threads parsed from .md', file=sys.stderr); return 1
    today = datetime.date.today().isoformat()
    merged_hdr = re.search(r'^> \*\*UI answers:\*\*', text, re.M)
    if ans.get('md_sha256') != sha(md):
        print('stale: .md changed since serve', file=sys.stderr); return 2
    if not ans.get('submitted') and not force:
        print('answers not submitted (use --force-unsubmitted)', file=sys.stderr); return 3
    need = {'accept': 'reply', 'adjust': 'notes', 'own': 'own'}
    empty = [t['key'] for t in threads if t['has_reply']
             and (a := ans.get('threads', {}).get(t['key']) or {}).get('decision') in need
             and not (a.get(need[a['decision']]) or '').strip()]
    if empty:
        print('empty reply, notes or own text on ' + ', '.join(empty) + ': re-serve, then fill or skip them',
              file=sys.stderr); return 4
    ms = list(ANCHOR.finditer(text))
    parts, last, counts, adjust = [], 0, dict(accepted=0, adjust=0, own=0, skipped=0), []
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        sec = text[m.start():end]
        t = threads[i]
        a = ans.get('threads', {}).get(t['key'])
        if a and t['has_reply']:
            draft = ans.get('drafts', {}).get(t['key'], t['reply'])
            d, text_out, notes = a.get('decision'), draft, ''
            if d == 'own':
                kind, text_out = 'own', a['own'].strip('\n')
            elif d == 'adjust':
                kind, notes = 'adjust', a['notes'].strip('\n')
                adjust.append(t)
            elif d == 'skip':
                kind = 'skipped'
            else:
                kind = 'accepted'
            counts[kind] += 1
            sec = rewrite(sec, kind, text_out, today, notes)
        parts.append(text[last:m.start()]); parts.append(sec); last = end
    parts.append(text[last:])
    new = ''.join(parts)
    line = f"> **UI answers:** merged {today} — {counts['accepted']} accepted, {counts['adjust']} to rewrite from notes, {counts['own']} own, {counts['skipped']} skipped"
    if merged_hdr:
        new = re.sub(r'^> \*\*UI answers:\*\*[^\n]*', lambda _: line + '  ', new, count=1, flags=re.M)
    else:
        new = re.sub(r'(^> \*\*Status:\*\*[^\n]*\n)', lambda mm: mm.group(1) + line + '  \n', new, count=1, flags=re.M)
    if new != text:
        open(md, 'w', encoding='utf-8').write(new)
    ans['md_sha256'] = sha(md); ans['merged'] = True
    atomic(ap, ans)
    print(f"MERGED {counts}")
    for t in adjust:  # the session rewrites these from the notes (ui-mode.md)
        print(f"ADJUST {t['key']} thread-{t['id']}")
    return 0


def rewrite(sec, kind, reply, today, notes=''):
    h = REPLY_H.search(sec)
    body = sec[h.end():]
    q = reply_block(body)
    pre = q.group(1) if q else '\n'
    rest = body[q.end():] if q else body
    hline = h.group(1)
    if kind == 'skipped':
        head = SKIP_HEAD
    elif kind == 'adjust':
        head = ADJUST_HEAD
    elif hline.startswith('Reply ('):
        head = "#### Ready-to-Send Reply (in the PR's language)"
    else:
        head = '#### ' + hline
    if kind == 'own':  # user's own text: the Voice pass runs again at post time
        head = re.sub(r'\s*[·\-—(]*\s*Voice pass: done\)?', '', head)
        rest = re.sub(r'\A((?:[ \t]*\n)*)[^\n]*Voice pass: done[^\n]*\n?', r'\1', rest, count=1)
    block = '\n'.join('> ' + l if l else '>' for l in reply.split('\n'))
    sec2 = DECISION.sub('', sec[:h.start()] + head + pre + block + '\n' + rest)
    label = {'own': 'own reply', 'adjust': 'adjust — rewrite the draft from these notes'}.get(kind, kind)
    ins = f'- **UI decision:** {label} ({today})\n'
    if notes:
        ins += ''.join('  > ' + l + '\n' if l else '  >\n' for l in notes.split('\n'))
    mstat = re.search(r'^- \*\*Status:\*\*[^\n]*\n', sec2, re.M)
    if mstat:
        return sec2[:mstat.end()] + ins + sec2[mstat.end():]
    nl = sec2.index('\n') + 1
    return sec2[:nl] + ins + sec2[nl:]


# ---------------------------------------------------------------- serve
def atomic(path, obj):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(path)), prefix='.ans-')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


PAGE = r'''<!doctype html><html lang=en><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><meta name=color-scheme content="light dark"><meta name=darkreader-lock>
<title>PR Feedback Review</title>
<style>
:root{color-scheme:light;--bg:#f8fafc;--card:#fff;--fg:#334155;--strong:#0f172a;--mut:#64748b;--faint:#94a3b8;--bd:#e2e8f0;--chip:#f1f5f9;--chip-h:#e2e8f0;
--ac:#2563eb;--ac-h:#1d4ed8;--code:#f1f5f9;--pre:#f8fafc;
--g-bg:#f0fdf4;--g-bd:#bbf7d0;--g-fg:#166534;--y-bg:#fffbeb;--y-bd:#fcd34d;--y-fg:#92400e;--r-bg:#fef2f2;--r-bd:#fca5a5;--r-fg:#991b1b;--b-bg:#eff6ff;--b-bd:#bfdbfe;--b-fg:#1e40af;--p-bg:#faf5ff;--p-bd:#e9d5ff;--p-fg:#6b21a8;
--add:#dcfce7;--del:#fee2e2}
:root[data-theme=dark]{color-scheme:dark;--bg:#0f1115;--card:#171a21;--fg:#cbd5e1;--strong:#f1f5f9;--mut:#94a3b8;--faint:#64748b;--bd:#2a2f3a;--chip:#222733;--chip-h:#2c3340;
--ac:#3b82f6;--ac-h:#60a5fa;--code:#222733;--pre:#12151b;
--g-bg:#0f2a1a;--g-bd:#1f5132;--g-fg:#86efac;--y-bg:#2a2210;--y-bd:#6b5414;--y-fg:#fcd34d;--r-bg:#2a1214;--r-bd:#6b2329;--r-fg:#fca5a5;--b-bg:#111d33;--b-bd:#1e3a6b;--b-fg:#93c5fd;--p-bg:#1f1530;--p-bd:#4c2d70;--p-fg:#d8b4fe;
--add:#11301d;--del:#3a1518}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Inter,sans-serif;background:var(--bg);color:var(--fg);line-height:1.6;padding:40px 16px 120px}
.wrap{max-width:860px;margin:0 auto}
h1{font-size:28px;font-weight:700;color:var(--strong);margin-bottom:6px}
h2{font-size:18px;font-weight:600;color:var(--strong);margin:36px 0 12px}
a{color:var(--ac);text-decoration:none}a:hover{text-decoration:underline}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.86em;background:var(--code);padding:1px 5px;border-radius:4px;word-break:break-word}
pre{background:var(--pre);border:1px solid var(--bd);border-radius:6px;padding:10px 12px;overflow-x:auto;font-size:12.5px;line-height:1.5;margin:8px 0}
pre code{background:none;padding:0;font-size:inherit;word-break:normal}
pre .add{background:var(--add);display:block}pre .del{background:var(--del);display:block}
.top{display:flex;justify-content:space-between;align-items:center;gap:12px}
.theme{background:var(--card);color:var(--fg);border:1px solid var(--bd);border-radius:999px;padding:5px 12px;font:inherit;font-size:13px;cursor:pointer;white-space:nowrap}.theme:hover{background:var(--chip)}
.subtitle{color:var(--mut);font-size:15px;margin-bottom:20px}
.meta-grid{display:grid;grid-template-columns:max-content 1fr;gap:4px 14px;font-size:13px;background:var(--card);border:1px solid var(--bd);border-radius:8px;padding:14px 16px}
.meta-grid dt{color:var(--mut)}.meta-grid dd{color:var(--fg);min-width:0}
.stats{display:flex;gap:28px;flex-wrap:wrap;padding:18px 0;margin:24px 0;border-top:1px solid var(--bd);border-bottom:1px solid var(--bd)}
.stat{text-align:center;min-width:56px}.stat b{display:block;font-size:24px;color:var(--strong)}.stat span{font-size:11px;color:var(--mut);text-transform:uppercase;letter-spacing:.03em}
.glance{background:var(--y-bg);border:1px solid var(--y-bd);border-radius:12px;padding:18px 22px;color:var(--fg);font-size:14px}
.glance h3{color:var(--y-fg);font-size:15px;margin-bottom:8px}
.glance p+p{margin-top:8px}
.toc{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0;padding:14px;background:var(--card);border:1px solid var(--bd);border-radius:8px}
.toc a{font-size:12px;color:var(--mut);padding:5px 10px;border-radius:6px;background:var(--chip);text-decoration:none}
.toc a:hover{background:var(--chip-h);color:var(--fg)}.toc a.s-skip{text-decoration:line-through;opacity:.6}.toc a.s-none{opacity:.6}.toc a.s-edit{box-shadow:inset 0 0 0 1px var(--ac)}
.card{background:var(--card);border:1px solid var(--bd);border-radius:10px;padding:18px 20px;margin:16px 0;scroll-margin-top:16px;transition:opacity .15s}
.card.skip{opacity:.62}
.card-head{display:flex;gap:12px;align-items:flex-start;justify-content:space-between}
.card-title{font-size:16px;font-weight:600;color:var(--strong);line-height:1.4}
.card-title .num{color:var(--faint);font-weight:500;margin-right:6px}
.pills{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0 4px}
.pill{font-size:12px;padding:2px 9px;border-radius:999px;border:1px solid var(--bd);background:var(--chip);color:var(--fg);white-space:nowrap}
.pill.cat-block{background:var(--r-bg);border-color:var(--r-bd);color:var(--r-fg)}
.pill.cat-prop{background:var(--b-bg);border-color:var(--b-bd);color:var(--b-fg)}
.pill.cat-pol{background:var(--p-bg);border-color:var(--p-bd);color:var(--p-fg)}
.pill.st-ok{background:var(--g-bg);border-color:var(--g-bd);color:var(--g-fg)}
.pill.st-open{background:var(--y-bg);border-color:var(--y-bd);color:var(--y-fg)}
.sub{font-size:13px;color:var(--mut);display:flex;gap:6px 14px;flex-wrap:wrap}
.label{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:var(--mut);margin:14px 0 6px}
.quote{border-left:3px solid var(--bd);padding:4px 0 4px 12px;color:var(--fg);font-size:14px;font-style:italic}
.rec{background:var(--g-bg);border:1px solid var(--g-bd);color:var(--g-fg);border-radius:8px;padding:9px 13px;font-size:14px;margin-top:12px}
details{margin-top:12px;border-top:1px solid var(--bd)}
summary{cursor:pointer;padding:10px 0 4px;font-size:13px;font-weight:600;color:var(--mut);list-style:none}
summary::-webkit-details-marker{display:none}summary::before{content:"▸ ";display:inline-block;transition:transform .15s}
details[open] summary::before{transform:rotate(90deg)}
.md{font-size:14px}.md p{margin:6px 0}.md ul{margin:6px 0 6px 20px}.md li{margin:3px 0}.md h4{font-size:13px;color:var(--strong);margin:14px 0 4px}
.md blockquote{border-left:3px solid var(--bd);padding-left:10px;color:var(--mut)}
.md table{border-collapse:collapse;font-size:12.5px;margin:8px 0;display:block;overflow-x:auto}.md td,.md th{border:1px solid var(--bd);padding:4px 8px;text-align:left}
.reply{margin-top:14px;background:var(--pre);border:1px solid var(--bd);border-radius:8px;padding:12px 14px}
.reply-head{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:8px}
.reply-head .label{margin:0}
.tag{font-size:11px;color:var(--mut)}.tag.edited{color:var(--ac)}
textarea{width:100%;min-height:72px;resize:vertical;overflow:hidden;background:var(--card);color:var(--fg);border:1px solid var(--bd);border-radius:6px;padding:9px 11px;font:inherit;font-size:14px;line-height:1.55}
textarea:focus{outline:2px solid var(--ac);outline-offset:-1px;border-color:transparent}
textarea:disabled{opacity:.7}
.actions{display:flex;gap:8px;align-items:center;margin-top:10px;flex-wrap:wrap}
.seg{display:inline-flex;border:1px solid var(--bd);border-radius:7px;overflow:hidden}
.seg button{border:0;background:transparent;color:var(--mut);padding:6px 14px;font:inherit;font-size:13px;cursor:pointer}
.seg button.on{background:var(--ac);color:#fff}.seg button.on.skipbtn{background:var(--faint)}.seg.mode{margin-bottom:10px}.seg button+button{border-left:1px solid var(--bd)}.seg.mode{flex-wrap:wrap}
.ai-ref{margin-bottom:10px}.ref-head{display:flex;justify-content:space-between;align-items:center}.ref-head .label{margin:0 0 4px}.ai-ref .quote{font-style:normal;color:var(--mut)}
.hint{font-size:12px;color:var(--mut);margin-top:6px}.tag.warn{color:var(--y-fg)}[hidden]{display:none!important}
.seg button:disabled,.link:disabled{cursor:default}
.link{background:none;border:0;color:var(--ac);font:inherit;font-size:13px;cursor:pointer}
.none{font-size:13px;color:var(--faint);margin-top:12px}
.bar{position:fixed;left:0;right:0;bottom:0;background:var(--card);border-top:1px solid var(--bd);padding:12px 16px}
.bar .wrap{display:flex;align-items:center;gap:14px;justify-content:space-between;flex-wrap:wrap}
.bar .counts{font-size:13px;color:var(--fg)}.bar .save{font-size:12px;color:var(--mut)}
.primary{background:var(--ac);color:#fff;border:0;border-radius:7px;padding:9px 18px;font:inherit;font-weight:600;font-size:14px;cursor:pointer}
.primary:hover{background:var(--ac-h)}.primary:disabled{opacity:.5;cursor:default}
.stalebar{background:var(--y-bg);border:1px solid var(--y-bd);color:var(--y-fg);border-radius:10px;padding:12px 16px;margin:20px 0;font-size:14px;position:sticky;top:8px;z-index:2}
.btns{display:flex;gap:8px}.sec{background:var(--card);color:var(--fg);border:1px solid var(--bd);border-radius:7px;padding:9px 14px;font:inherit;font-size:14px;cursor:pointer}.sec:hover{background:var(--chip)}.sec:disabled{opacity:.5;cursor:default}
.done{background:var(--g-bg);border:1px solid var(--g-bd);color:var(--g-fg);border-radius:10px;padding:14px 18px;margin:20px 0;font-size:14px;display:none}
@media(max-width:640px){body{padding-top:24px}.stats{gap:16px;justify-content:center}.meta-grid{grid-template-columns:1fr}.meta-grid dt{margin-top:6px}}
</style>
<div class=wrap>
 <div class=top><h1>PR feedback review</h1><button class=theme id=theme type=button aria-label="Toggle dark mode">🌙 Dark</button></div><p class=subtitle id=sub>Loading…</p>
 <dl class=meta-grid id=meta></dl>
 <div class=stats id=stats></div>
 <div class=glance id=glance hidden><h3>At a glance</h3><div class=md id=summary></div></div>
 <div class=done id=done></div>
 <div class=stalebar id=stale hidden>The session updated the review while you were editing. <button class=link id=reload type=button>Load the latest version</button> (your last unsaved keystrokes are dropped).</div>
 <h2>Threads</h2><nav class=toc id=toc></nav>
 <div id=list></div>
</div>
<div class=bar><div class=wrap><div><div class=counts id=counts></div><div class=save id=save>Ready</div></div><div class=btns><button class=sec id=finish type=button title="Stop the review page server">Finish</button><button class=primary id=submit type=button>Submit answers</button></div></div></div>
<script>
"use strict";
(()=>{const r=document.documentElement,b=document.getElementById('theme');let t='light';try{t=localStorage.getItem('review-ui-theme')||'light'}catch(e){}
 const set=v=>{t=v;r.dataset.theme=v;b.textContent=v==='dark'?'☀️ Light':'🌙 Dark';try{localStorage.setItem('review-ui-theme',v)}catch(e){}};
 set(t);b.onclick=()=>set(t==='dark'?'light':'dark')})();
const T=new URLSearchParams(location.search).get('t')||'';
const H={'Content-Type':'application/json','X-Token':T};
const $=id=>document.getElementById(id);
let D=null,timer=null,locked=false;
function el(tag,cls,txt){const e=document.createElement(tag);if(cls)e.className=cls;if(txt!=null)e.textContent=txt;return e}
/* tiny safe markdown: builds DOM nodes, never innerHTML */
function inline(s,into){into=into||document.createDocumentFragment();
 const re=/`([^`]+)`|\*\*([^*]+)\*\*|(?<![\w*])[*_]([^*_\n]+)[*_](?![\w*])|\[([^\]]+)\]\(([^)\s]+)\)/g;let i=0,m;
 while((m=re.exec(s))){if(m.index>i)into.append(s.slice(i,m.index));
  if(m[1]!=null)into.append(el('code',null,m[1]));
  else if(m[2]!=null)inline(m[2],into.appendChild(el('strong')));
  else if(m[3]!=null)inline(m[3],into.appendChild(el('em')));
  else{const u=m[5];if(/^https?:\/\//.test(u)){const a=el('a');a.href=u;a.target='_blank';a.rel='noopener';inline(m[4],a);into.append(a)}
   else if(u.startsWith('#')){const a=el('a');a.href=u;inline(m[4],a);into.append(a)}else inline(m[4],into)}
  i=re.lastIndex}
 if(i<s.length)into.append(s.slice(i));return into}
function md(src){const out=document.createDocumentFragment();const L=src.replace(/\r/g,'').split('\n');let i=0,para=[];
 const flush=()=>{if(para.length){out.append(inline(para.join(' '),el('p')));para=[]}};
 const indent=l=>l.match(/^ */)[0].length;
 while(i<L.length){const l=L[i];
  let f=l.match(/^(\s*)(```+)(\S*)/);
  if(f){flush();const ind=f[1].length,lang=f[3];const body=[];i++;
   while(i<L.length&&!L[i].trim().startsWith(f[2]))body.push(L[i].slice(Math.min(ind,indent(L[i])))),i++;i++;
   const pre=el('pre'),c=el('code');
   if(lang==='diff')for(const b of body){c.append(el('span',b[0]==='+'?'add':b[0]==='-'?'del':'',b+'\n'))}else c.textContent=body.join('\n');
   pre.append(c);out.append(pre);continue}
  if(/^\s*$/.test(l)){flush();i++;continue}
  if(/^\s*\|/.test(l)){flush();const t=el('table');let first=true;
   while(i<L.length&&/^\s*\|/.test(L[i])){const row=L[i].trim().replace(/^\||\|$/g,'').split('|');i++;
    if(row.every(c=>/^\s*:?-+:?\s*$/.test(c)))continue;const tr=el('tr');
    for(const c of row)tr.append(inline(c.trim(),el(first?'th':'td')));t.append(tr);first=false}
   out.append(t);continue}
  if(/^#{1,6} /.test(l)){flush();out.append(inline(l.replace(/^#+ /,''),el('h4')));i++;continue}
  if(/^\s*>/.test(l)){flush();const q=[];while(i<L.length&&/^\s*>/.test(L[i]))q.push(L[i].replace(/^\s*> ?/,'')),i++;
   const b=el('blockquote');b.append(md(q.join('\n')));out.append(b);continue}
  const li=l.match(/^(\s*)([-*]|\d+\.) (.*)$/);
  if(li){flush();const ul=el('ul'),base=li[1].length;
   while(i<L.length){const m2=L[i].match(/^(\s*)([-*]|\d+\.) (.*)$/);if(!m2||m2[1].length!==base)break;
    const item=[m2[3]];i++;
    while(i<L.length&&(indent(L[i])>base||(/^\s*$/.test(L[i])&&i+1<L.length&&indent(L[i+1])>base))){item.push(L[i].slice(Math.min(base+2,indent(L[i]))));i++}
    const e=el('li');e.append(md(item.join('\n')));if(e.childNodes.length===1&&e.firstChild.tagName==='P')e.replaceChildren(...e.firstChild.childNodes);ul.append(e)}
   out.append(ul);continue}
  para.push(l.trim());i++}
 flush();return out}
function catClass(c){return /⛔|Block/i.test(c)?'cat-block':/💡|Propos/i.test(c)?'cat-prop':/✏️|Polish/i.test(c)?'cat-pol':''}
function stClass(s){return /✅|🕓/.test(s)?'st-ok':/⏸|◐/.test(s)?'st-open':''}
function plain(s){return s.replace(/`/g,'').replace(/\*\*/g,'')}
let dirty=false,typedAt=0,stale=false;
async function save(){timer=null;$('save').textContent='Saving…';
 try{const r=await fetch('/api/answers',{method:'PUT',headers:H,body:JSON.stringify({version:D.version,threads:D.answers})});
  if(r.status===409){showStale();return false}
  if(r.ok){dirty=false;$('save').textContent='All changes saved';return true}$('save').textContent='Save failed ('+r.status+')'}
 catch(e){$('save').textContent='Save failed — is the server still running?'}return false}
function later(){clearTimeout(timer);dirty=true;typedAt=Date.now();$('save').textContent='Unsaved changes…';timer=setTimeout(save,500)}
function showStale(){stale=true;$('stale').hidden=false;$('save').textContent='The session updated the review — load it to keep editing'}
function banner(){const b=$('done');if(D.submitted){b.style.display='block';
  b.textContent=`Submitted at ${D.submitted_at||'—'}. The session is merging your answers; this page refreshes itself when it is done. You can keep adjusting and submit again.`}
 else if(D.mergedNote){b.style.display='block';b.textContent=D.mergedNote}else b.style.display='none'}
function state(t){const a=D.answers[t.key];if(!t.has_reply)return'none';
 const need={adjust:'notes',own:'own'}[a.decision];if(a.decision==='skip')return'skip';
 if(need)return (a[need]||'').trim()?a.decision:'empty';return'post'}
function counts(){const c={post:0,adjust:0,own:0,skip:0,empty:0};for(const t of D.threads){const s=state(t);if(s in c)c[s]++}
 const n=c.post+c.adjust+c.own,ex=[c.adjust&&c.adjust+' rewritten from your notes',c.own&&c.own+' your own'].filter(Boolean).join(', ');
 $('counts').textContent=`${n} replies to post${ex?` (${ex})`:''} · ${c.skip} skipped`+(c.empty?` · ${c.empty} still empty`:'');
 $('submit').disabled=locked||c.empty>0;$('submit').title=c.empty?'Fill in the empty notes or own replies, or pick another option':'';
 for(const t of D.threads){const a=document.querySelector(`.toc a[data-k="${t.key}"]`);if(a)a.className='s-'+state(t)}}
function grow(ta){ta.style.height='auto';ta.style.height=ta.scrollHeight+2+'px'}
function header(){const d=D.doc;$('sub').replaceChildren(inline(d.title||'Pull request'));
 const keep=['PR','Head reviewed','Status','UI answers','Mode','Profile','Counterpart'];const dl=$('meta');dl.replaceChildren();$('stats').replaceChildren();$('summary').replaceChildren();
 for(const [k,v,subs] of d.fields){if(!keep.includes(k)&&k!=='Reviewers')continue;dl.append(el('dt',null,k));const dd=el('dd');
  if(k==='Reviewers')dd.append(inline(subs.map(([n,s])=>`**${n}** ${s}`).join(' · ')));else inline(v,dd);dl.append(dd)}
 const c={'⛔':0,'💡':0,'✏️':0,'⚪':0};for(const t of D.threads)for(const k in c)if(t.category.includes(k))c[k]++;
 const st=$('stats');const add=(v,l)=>{const s=el('div','stat');s.append(el('b',null,v),el('span',null,l));st.append(s)};
 add(D.threads.length,'threads');add(c['⛔'],'⛔ blocking');add(c['💡'],'💡 proposals');add(c['✏️'],'✏️ polish');add(c['⚪'],'⚪ info');
 add(D.threads.filter(t=>t.has_reply).length,'drafted replies');
 if(d.summary){$('glance').hidden=false;$('summary').append(md(d.summary))}}
function card(t){const a=D.answers[t.key];const c=el('section','card');c.id='t-'+t.key.replace(':','-');
 const h=el('div','card-head');const ti=el('div','card-title');ti.append(el('span','num','#'+t.id));inline(t.title,ti);h.append(ti);
 if(t.url){const l=el('a',null,'Open in PR ↗');l.href=t.url;l.target='_blank';l.rel='noopener';l.style.fontSize='13px';l.style.whiteSpace='nowrap';h.append(l)}
 c.append(h);
 const p=el('div','pills');if(t.category)p.append(el('span','pill '+catClass(t.category),plain(t.category)));
 if(t.state)p.append(el('span','pill '+stClass(t.state),plain(t.state)));if(t.pr)p.append(el('span','pill',t.pr));c.append(p);
 const s=el('div','sub');if(t.file)s.append(inline(t.file,el('span')));if(t.reviewer)s.append(el('span',null,'by '+t.reviewer+(t.vote&&t.vote!=='0'&&t.vote!=='—'?' · vote '+t.vote:'')));c.append(s);
 if(t.comment){c.append(el('div','label','Reviewer comment'));const q=el('div','quote md');q.append(md(t.comment));c.append(q)}
 if(t.recommendation){const r=el('div','rec');r.append(el('strong',null,'Recommendation: '));inline(t.recommendation,r);c.append(r)}
 if(t.meta||t.sections.length){const det=el('details');det.append(el('summary',null,'Analysis & proposed code'));const body=el('div','md');
  if(t.meta)body.append(md(t.meta));for(const [hd,b] of t.sections){body.append(el('h4',null,hd));body.append(md(b))}det.append(body);c.append(det)}
 if(!t.has_reply){c.append(el('div','none','No reply drafted for this thread.'));return c}
 const box=el('div','reply');const rh=el('div','reply-head');
 const lang=(t.reply_label.match(/\(([^)]+)\)/)||[])[1];
 rh.append(el('div','label','Reply'+(lang&&!/--ui/.test(lang)?' ('+lang+')':'')));
 const tag=el('span','tag');rh.append(tag);box.append(rh);
 const seg=el('div','seg mode');const B={accept:el('button',null,'Use AI draft'),adjust:el('button',null,'Adjust AI draft'),own:el('button',null,'Write my own'),skip:el('button','skipbtn','Skip')};
 seg.append(...Object.values(B));box.append(seg);
 const ref=el('div','ai-ref');const refHead=el('div','ref-head');const refLabel=el('span','label','AI draft');refHead.append(refLabel);
 const copy=el('button','link','Start from the draft');refHead.append(copy);ref.append(refHead);const refq=el('div','quote md');refq.append(md(D.drafts[t.key]));ref.append(refq);box.append(ref);
 const ta=el('textarea');ta.setAttribute('aria-label','Thread '+t.id);box.append(ta);
 const hint=el('div','hint');box.append(hint);
 const field=()=>({adjust:'notes',own:'own'}[a.decision]);
 const PH={adjust:'What is wrong or missing in the draft? E.g. "too long", "mention that the ADR covers this", "softer tone, admit the miss". Claude rewrites the reply from your notes.',
  own:'Write your reply to '+(t.reviewer||'the reviewer')+'… This exact text is posted.'};
 const HINT={accept:'The AI draft is posted as it is.',adjust:'Your notes go back to the Claude session, which rewrites the reply and runs the voice pass. You see the new text before anything is posted.',
  own:'Your own text is posted instead of the AI draft; the voice pass runs on it first.',skip:'This thread gets no reply.'};
 const fill=()=>{const f=field();ta.value=f?(a[f]||''):'';ta.placeholder=PH[a.decision]||'';grow(ta)};
 const sync=()=>{const st=state(t),m=a.decision;c.classList.toggle('skip',m==='skip');
  for(const k in B)B[k].classList.toggle('on',k===m);
  ref.hidden=m==='skip';copy.hidden=m!=='own';refLabel.textContent=m==='own'?'AI draft (reference)':m==='adjust'?'AI draft (to be rewritten)':'AI draft';
  ta.hidden=!field();ta.disabled=locked;[...Object.values(B),copy].forEach(b=>b.disabled=locked);hint.textContent=HINT[m]||'';
  tag.className='tag'+(st==='adjust'||st==='own'?' edited':st==='empty'?' warn':'');
  tag.textContent={post:t.voice?'Voice pass ✓':'',adjust:'Rewrite from notes',own:'Own reply',empty:m==='adjust'?'Notes empty':'Own reply empty',skip:'Skipped'}[st]||'';counts()};
 ta.oninput=()=>{const f=field();if(f)a[f]=ta.value;grow(ta);sync();later()};
 for(const k in B)B[k].onclick=()=>{a.decision=k;fill();sync();later();if(field())ta.focus()};
 copy.onclick=()=>{a.own=D.drafts[t.key];fill();sync();later();ta.focus()};
 c.append(box);c._sync=sync;c._ta=ta;fill();sync();return c}
function render(){const L=$('list'),toc=$('toc');L.replaceChildren();toc.replaceChildren();
 for(const t of D.threads){const a=el('a',null,'#'+t.id+' '+(t.category.match(/^\S+/)||[''])[0]);a.href='#t-'+t.key.replace(':','-');a.dataset.k=t.key;toc.append(a);
  const c=card(t);L.append(c);if(c._ta)requestAnimationFrame(()=>grow(c._ta))}counts()}
function lock(msg){locked=true;$('submit').disabled=true;$('finish').disabled=true;$('done').style.display='block';$('done').textContent=msg;
 $('save').textContent='Closed';document.querySelectorAll('.card').forEach(c=>c._sync&&c._sync())}
async function load(note){const y=scrollY,was=D&&D.version;const r=await fetch('/api/threads',{headers:H});if(!r.ok)throw r.status;
 D=await r.json();if(note&&was&&was!==D.version)D.mergedNote='Updated from the session at '+new Date().toTimeString().slice(0,5)+': merged replies and any rewrites from your notes are below as the new drafts.';
 stale=false;dirty=false;$('stale').hidden=true;header();render();banner();$('submit').textContent=D.submitted?'Submit again':'Submit answers';
 $('save').textContent='Up to date';requestAnimationFrame(()=>scrollTo(0,y))}
load().catch(e=>{$('sub').textContent='Could not load threads ('+e+'). Open the exact URL the session printed.'});
$('reload').onclick=()=>load(true);
setInterval(async()=>{if(locked||!D)return;try{const r=await fetch('/api/state',{headers:H});if(!r.ok)return;const s=await r.json();
 if(s.version!==D.version){if(!dirty&&!timer&&Date.now()-typedAt>4000&&!stale)await load(true);else showStale()}
 else if(s.submitted!==D.submitted){D.submitted=s.submitted;D.submitted_at=s.submitted_at;banner()}}
 catch(e){$('save').textContent='Server stopped — the page is read-only now';locked=true;$('submit').disabled=true;$('finish').disabled=true}},2500);
$('submit').onclick=async()=>{clearTimeout(timer);if(dirty&&!(await save()))return;
 const r=await fetch('/api/submit',{method:'POST',headers:H,body:JSON.stringify({version:D.version})});
 if(r.status===409)return showStale();
 if(r.ok){D.submitted=true;D.submitted_at=new Date().toTimeString().slice(0,5);D.mergedNote='';banner();$('submit').textContent='Submit again';$('save').textContent='Submitted';scrollTo({top:0,behavior:'smooth'})}
 else $('save').textContent='Submit failed ('+r.status+')'};
$('finish').onclick=async()=>{clearTimeout(timer);if(dirty)await save();
 try{await fetch('/api/close',{method:'POST',headers:H,body:'{}'})}catch(e){}
 lock('Finished. The review page server has stopped; you can close this tab. Submitted answers stay in the review.')};
addEventListener('resize',()=>document.querySelectorAll('textarea').forEach(grow));
</script>
'''


def make_seed(md, threads):
    """Answers that mirror the .md as it is now (the baseline after a merge)."""
    def first(t):
        if t['skipped']:
            return 'skip'
        return 'adjust' if t['pending_adjust'] else 'accept'
    return dict(md_sha256=sha(md), submitted=False, merged=False, drafts={t['key']: t['reply'] for t in threads},
                threads={t['key']: dict(decision=first(t), reply=t['reply'], own='', notes=t['notes']) for t in threads})


def serve(md, do_open, bind='127.0.0.1'):
    ap, dp = base(md) + '.answers.json', base(md) + '.answers.done'
    lock = threading.Lock()
    st = dict(sha=None)

    def load():
        """Re-read the .md when it changed (a merge, a rewrite from notes, a hand edit). Call under lock."""
        cur = sha(md)
        if cur == st['sha']:
            return True
        text = open(md, encoding='utf-8').read()
        threads = parse(text)
        if not threads:
            return False
        seed = make_seed(md, threads)
        try:
            old = json.load(open(ap, encoding='utf-8'))
        except (OSError, ValueError):
            old = None
        if old is None or old.get('merged'):
            ans = seed  # after a merge the .md is the new baseline
        else:
            ans = reconcile(old, seed)
        atomic(ap, ans)
        os.chmod(ap, 0o600)
        st.update(sha=cur, threads=threads, doc=doc_info(text), drafts=seed['drafts'])
        return True

    with lock:
        if not load():
            print('no threads parsed from .md', file=sys.stderr); return 1
    if os.path.exists(dp):
        os.remove(dp)
    token = secrets.token_urlsafe(24)

    class H(http.server.BaseHTTPRequestHandler):
        server_version = 'review-ui'
        def log_message(self, *a): pass
        def _send(self, code, body=b'', ctype='application/json'):
            if isinstance(body, (dict, list)):
                body = json.dumps(body, ensure_ascii=False).encode()
            elif isinstance(body, str):
                body = body.encode()
            self.send_response(code)
            self.send_header('Content-Type', ctype + ('; charset=utf-8' if 'text' in ctype else ''))
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers(); self.wfile.write(body)
        def _auth(self, api):
            port = self.server.server_address[1]
            if self.headers.get('Host') != f'127.0.0.1:{port}':
                return False
            q = re.search(r'[?&]t=([^&]+)', self.path)
            tok = self.headers.get('X-Token') or (q.group(1) if q else '')
            return secrets.compare_digest(tok, token)
        def _state(self, ans):
            return dict(version=st['sha'], submitted=ans.get('submitted', False), submitted_at=ans.get('submitted_at'),
                        merged=ans.get('merged', False))
        def do_GET(self):
            path = self.path.split('?')[0]
            if path not in ('/', '/api/threads', '/api/state'):
                return self._send(404, {'error': 'not found'})
            if not self._auth(path != '/'):
                return self._send(403, {'error': 'forbidden'})
            if path == '/':
                return self._send(200, PAGE, 'text/html')
            with lock:
                load()
                ans = json.load(open(ap, encoding='utf-8'))
            if path == '/api/state':
                return self._send(200, self._state(ans))
            self._send(200, dict(self._state(ans), doc=st['doc'], threads=st['threads'], answers=ans['threads'],
                                 drafts=st['drafts']))
        def _body(self):
            if not self._auth(True):
                self._send(403, {'error': 'forbidden'}); return None
            if (self.headers.get('Content-Type') or '').split(';')[0].strip() != 'application/json':
                self._send(415, {'error': 'json only'}); return None
            n = int(self.headers.get('Content-Length') or 0)
            if n > MAX_BODY:
                self._send(413, {'error': 'too large'}); return None
            try:
                b = json.loads(self.rfile.read(n) or b'{}')
                return b if isinstance(b, dict) else {}
            except ValueError:
                self._send(400, {'error': 'bad json'}); return None
        def _stale(self, b):
            """The page edits the version it loaded; after a merge or rewrite it must reload first."""
            if b.get('version') != st['sha']:
                self._send(409, {'error': 'the review changed; reload', 'version': st['sha']}); return True
            return False
        def do_PUT(self):
            if self.path.split('?')[0] != '/api/answers':
                return self._send(404, {'error': 'not found'})
            b = self._body()
            if b is None: return
            with lock:
                load()
                if self._stale(b): return
                ans = json.load(open(ap, encoding='utf-8'))
                for k, v in (b.get('threads') or {}).items():
                    if k in ans['threads'] and isinstance(v, dict):
                        d = v.get('decision')
                        if d in ('accept', 'adjust', 'own', 'skip'): ans['threads'][k]['decision'] = d
                        for f in ('own', 'notes'):
                            if isinstance(v.get(f), str): ans['threads'][k][f] = v[f]
                atomic(ap, ans)
            self._send(200, {'ok': True})
        def do_POST(self):
            path = self.path.split('?')[0]
            if path not in ('/api/submit', '/api/close'):
                return self._send(404, {'error': 'not found'})
            b = self._body()
            if b is None: return
            if path == '/api/close':
                print('CLOSED', flush=True)
                self._send(200, {'ok': True})
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return
            with lock:
                load()
                if self._stale(b): return
                ans = json.load(open(ap, encoding='utf-8'))
                ans['submitted'] = True
                ans['submitted_at'] = datetime.datetime.now().strftime('%H:%M')
                atomic(ap, ans)
                open(dp, 'w').close()
            print('SUBMITTED', flush=True)
            print(f'Next: the session merges the answers. Standalone: python3 -I {os.path.abspath(__file__)} merge {os.path.abspath(md)}',
                  flush=True)
            self._send(200, {'ok': True})

    srv = http.server.ThreadingHTTPServer((bind, 0), H)
    url = f'http://127.0.0.1:{srv.server_address[1]}/?t={token}'
    print('URL', url, flush=True)
    print('PID', os.getpid(), flush=True)
    if do_open:
        for cmd in (['xdg-open', url], ['open', url]):
            try:
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); break
            except OSError:
                continue
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sp = p.add_subparsers(dest='cmd', required=True)
    s = sp.add_parser('serve'); s.add_argument('md'); s.add_argument('--open', action='store_true')
    m = sp.add_parser('merge'); m.add_argument('md'); m.add_argument('--force-unsubmitted', action='store_true')
    a = p.parse_args()
    return serve(a.md, a.open) if a.cmd == 'serve' else merge(a.md, a.force_unsubmitted)


if __name__ == '__main__':
    sys.exit(main())
