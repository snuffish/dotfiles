#!/usr/bin/env python3
"""
render_html.py - PRIIS Standalone Artifact HTML Compiler

Compiles Markdown artifacts into standalone, styled HTML pages featuring:
- Tailwind CSS CDN for modern typography and layout
- Mermaid 11 ESM CDN for client-side rendering of diagrams
- GitHub Flavored Markdown alerts ([!NOTE], [!WARNING], etc.)
- GFM tables (a table whose header row is empty renders without one), code blocks
- Checklists that can be ticked; state is remembered per page in localStorage
- <details>/<summary> blocks (collapsible; markdown between the tags still renders)
- A contents list after the H1 when the page has three or more H2 sections
- Artifact-owner metadata as <meta> tags and a small footer line
- Native browser launch (--open) via xdg-open / open / start
- Offline-resilient fallback CSS
"""

import sys
import os
import re
import html
import argparse
import subprocess
from pathlib import Path


ALERT_STYLES = {
    "NOTE": {
        "title": "Note",
        "icon": "ℹ️",
        "container": "bg-sky-50 border-sky-500 text-sky-900",
        "title_class": "text-sky-800",
    },
    "TIP": {
        "title": "Tip",
        "icon": "💡",
        "container": "bg-emerald-50 border-emerald-500 text-emerald-900",
        "title_class": "text-emerald-800",
    },
    "IMPORTANT": {
        "title": "Important",
        "icon": "🟣",
        "container": "bg-purple-50 border-purple-500 text-purple-900",
        "title_class": "text-purple-800",
    },
    "WARNING": {
        "title": "Warning",
        "icon": "⚠️",
        "container": "bg-amber-50 border-amber-500 text-amber-900",
        "title_class": "text-amber-800",
    },
    "CAUTION": {
        "title": "Caution",
        "icon": "🛑",
        "container": "bg-rose-50 border-rose-500 text-rose-900",
        "title_class": "text-rose-800",
    },
}


def slugify(text: str) -> str:
    cleaned = re.sub(r"<[^>]+>", "", text)
    slug = re.sub(r"[^a-zA-Z0-9_\-]+", "-", cleaned.strip().lower())
    return slug.strip("-") or "section"


class MarkdownRenderer:
    def __init__(self, raw_md: str, title: str | None = None):
        self.raw_md = raw_md
        self.title = title or "PRIIS Artifact Document"
        self.owner_meta: dict[str, str] = {}
        self.toc: list[tuple[str, str]] = []
        self.h1_index: int | None = None
        self._extract_owner_meta()

    def _extract_owner_meta(self):
        m = re.search(
            r"<!--\s*artifact-owner:\s*([^·\n]+)\s*·\s*session\s*([^·\n]+)\s*·\s*created\s*([^\s-]+(?:[^\n>]*))\s*-->",
            self.raw_md,
        )
        if m:
            self.owner_meta = {
                "owner": m.group(1).strip(),
                "session": m.group(2).strip(),
                "created": m.group(3).strip(),
            }

    def render_inline(self, text: str) -> str:
        if not text:
            return ""

        code_spans: list[str] = []

        def save_code(m: re.Match) -> str:
            idx = len(code_spans)
            escaped = html.escape(m.group(2))
            code_spans.append(
                f'<code class="px-1.5 py-0.5 rounded bg-slate-100 text-slate-800 font-mono text-xs border border-slate-200">{escaped}</code>'
            )
            return f"§§PRIISCODE{idx}§§"

        # Protect inline code spans
        text = re.sub(r"(`+)(.+?)\1", save_code, text)

        # Protect markdown links: [text](url)
        links: list[str] = []

        def save_link(m: re.Match) -> str:
            idx = len(links)
            label = m.group(1)
            url = m.group(2).strip()
            # Recursively render inline markdown inside link label (except code spans already protected)
            formatted_label = self._format_inline_decorations(label)
            escaped_url = html.escape(url, quote=True)
            links.append(
                f'<a href="{escaped_url}" class="text-emerald-700 hover:text-emerald-900 underline font-medium break-all">{formatted_label}</a>'
            )
            return f"§§PRIISLINK{idx}§§"

        text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", save_link, text)

        # Autolinks <http...>
        def save_autolink(m: re.Match) -> str:
            idx = len(links)
            url = m.group(1).strip()
            escaped_url = html.escape(url, quote=True)
            links.append(
                f'<a href="{escaped_url}" class="text-emerald-700 hover:text-emerald-900 underline font-medium break-all">{escaped_url}</a>'
            )
            return f"§§PRIISLINK{idx}§§"

        text = re.sub(r"<(https?://[^>]+)>", save_autolink, text)

        # Apply decorations: bold, italic, strikethrough
        text = self._format_inline_decorations(text)

        # Restore links
        for idx, link_html in enumerate(links):
            text = text.replace(f"§§PRIISLINK{idx}§§", link_html)

        # Restore code spans
        for idx, code_html in enumerate(code_spans):
            text = text.replace(f"§§PRIISCODE{idx}§§", code_html)

        return text

    def _format_inline_decorations(self, text: str) -> str:
        # Bold with trailing italic: **prefix *italic***
        text = re.sub(
            r"\*\*(.*?)\*(.*?)\*\*\*",
            r'<strong class="font-semibold text-slate-900">\1<em class="italic text-slate-800">\2</em></strong>',
            text,
        )
        # Bold and italic combined: ***text***
        text = re.sub(r"\*\*\*(.+?)\*\*\*", r'<strong class="font-semibold text-slate-900"><em class="italic text-slate-800">\1</em></strong>', text)
        text = re.sub(r"___(.+?)___", r'<strong class="font-semibold text-slate-900"><em class="italic text-slate-800">\1</em></strong>', text)

        # Bold: **bold** or __bold__
        text = re.sub(r"\*\*(.+?)\*\*", r'<strong class="font-semibold text-slate-900">\1</strong>', text)
        text = re.sub(r"__(.+?)__", r'<strong class="font-semibold text-slate-900">\1</strong>', text)

        # Strikethrough: ~~del~~
        text = re.sub(r"~~([^~]+)~~", r'<del class="line-through text-slate-400">\1</del>', text)

        # Italic: *italic* or _italic_
        text = re.sub(r"(?<!\*)\*([^*\n]+?)\*(?!\*)", r'<em class="italic text-slate-800">\1</em>', text)
        text = re.sub(r"(?<!_)_([^_\n]+?)_(?!_)", r'<em class="italic text-slate-800">\1</em>', text)

        return text

    def parse_blocks(self) -> list[str]:
        lines = self.raw_md.splitlines()
        n = len(lines)
        i = 0
        blocks: list[str] = []

        while i < n:
            line = lines[i]

            # 1. Skip leading artifact-owner comment
            if i == 0 and line.startswith("<!-- artifact-owner:"):
                i += 1
                continue

            # 2. Empty line
            if not line.strip():
                i += 1
                continue

            # 3. Horizontal rule
            if re.match(r"^(\*{3,}|-{3,}|_{3,})\s*$", line.strip()):
                blocks.append('<hr class="border-slate-200 my-8" />')
                i += 1
                continue

            # 4. Fenced code block (``` or ~~~)
            m_fence = re.match(r"^(\s*)(```+|~~~+)(.*)$", line)
            if m_fence:
                fence_str = m_fence.group(2)
                fence_char = fence_str[0]
                fence_len = len(fence_str)
                lang = m_fence.group(3).strip()
                code_lines = []
                i += 1
                while i < n:
                    m_close = re.match(r"^\s*(" + re.escape(fence_char) + r"{" + str(fence_len) + r",})\s*$", lines[i])
                    if m_close:
                        i += 1
                        break
                    code_lines.append(lines[i])
                    i += 1

                raw_code = "\n".join(code_lines)
                if lang.lower() == "mermaid":
                    # Mermaid diagram container
                    blocks.append(
                        '<div class="rounded-lg border border-slate-200 bg-white p-4 my-6 shadow-sm overflow-x-auto">\n'
                        f'  <pre class="mermaid">\n{raw_code}\n  </pre>\n'
                        '</div>'
                    )
                else:
                    escaped_code = html.escape(raw_code)
                    header_badge = ""
                    if lang:
                        header_badge = (
                            '<div class="flex items-center justify-between px-4 py-1.5 bg-slate-800 border-b border-slate-700 text-slate-400 text-xs font-mono">'
                            f"<span>{html.escape(lang)}</span>"
                            "</div>"
                        )
                    blocks.append(
                        '<div class="relative my-6 rounded-lg border border-slate-800 bg-slate-900 overflow-hidden shadow-sm">'
                        f"{header_badge}"
                        f'<pre class="p-4 text-xs font-mono text-slate-100 overflow-x-auto leading-relaxed"><code>{escaped_code}</code></pre>'
                        "</div>"
                    )
                continue

            # 4b. Collapsible blocks: <details>, <summary>…</summary>, </details>
            if re.match(r"^\s*</?(details|summary)\b", line):
                for tag in re.findall(r"<details[^>]*>|</details>|<summary[^>]*>.*?</summary>", line.strip()):
                    if tag.startswith("<details"):
                        blocks.append(
                            '<details class="my-4 rounded-lg border border-slate-200 bg-white px-4 py-2 shadow-sm">'
                        )
                    elif tag == "</details>":
                        blocks.append("</details>")
                    else:
                        inner = re.sub(r"^<summary[^>]*>|</summary>$", "", tag)
                        blocks.append(
                            '<summary class="cursor-pointer select-none py-1 text-sm font-semibold text-slate-800">'
                            f"{self.render_inline(inner)}</summary>"
                        )
                i += 1
                continue

            # 5. Headings (# H1 to ###### H6)
            m_head = re.match(r"^(#{1,6})\s+(.*)$", line)
            if m_head:
                level = len(m_head.group(1))
                h_text = m_head.group(2).strip()
                slug = slugify(h_text)
                rendered_h = self.render_inline(h_text)

                if level == 2:
                    self.toc.append((slug, rendered_h))
                if level == 1 and self.h1_index is None:
                    self.h1_index = len(blocks)

                if level == 1:
                    blocks.append(
                        f'<h1 id="{slug}" class="text-3xl font-serif font-bold text-slate-900 mt-8 mb-4 border-b border-slate-200 pb-3">{rendered_h}</h1>'
                    )
                elif level == 2:
                    blocks.append(
                        f'<h2 id="{slug}" class="text-2xl font-bold tracking-tight text-slate-900 mt-8 mb-3 border-b border-slate-100 pb-2">{rendered_h}</h2>'
                    )
                elif level == 3:
                    blocks.append(
                        f'<h3 id="{slug}" class="text-xl font-bold text-slate-900 mt-6 mb-2">{rendered_h}</h3>'
                    )
                elif level == 4:
                    blocks.append(
                        f'<h4 id="{slug}" class="text-lg font-semibold text-slate-800 mt-4 mb-2">{rendered_h}</h4>'
                    )
                elif level == 5:
                    blocks.append(
                        f'<h5 id="{slug}" class="text-base font-semibold text-slate-700 mt-3 mb-1">{rendered_h}</h5>'
                    )
                else:
                    blocks.append(
                        f'<h6 id="{slug}" class="text-sm font-semibold uppercase tracking-wider text-slate-600 mt-3 mb-1">{rendered_h}</h6>'
                    )
                i += 1
                continue

            # 6. Blockquote and Alerts (> ...)
            if line.startswith(">"):
                bq_lines = []
                while i < n and (lines[i].startswith(">") or (bq_lines and lines[i].strip() and not lines[i].startswith("#"))):
                    l_val = lines[i]
                    if l_val.startswith(">"):
                        l_val = l_val[1:]
                        if l_val.startswith(" "):
                            l_val = l_val[1:]
                    bq_lines.append(l_val)
                    i += 1

                # Check for GitHub-style alert
                alert_type = None
                first_line = bq_lines[0].strip() if bq_lines else ""
                m_alert = re.match(r"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*(.*)$", first_line, re.IGNORECASE)
                if m_alert:
                    alert_type = m_alert.group(1).upper()
                    rest_of_first = m_alert.group(2).strip()
                    bq_lines = bq_lines[1:]
                    if rest_of_first:
                        bq_lines.insert(0, rest_of_first)

                if alert_type and alert_type in ALERT_STYLES:
                    cfg = ALERT_STYLES[alert_type]
                    body_text = "<br />".join(self.render_inline(l) for l in bq_lines if l.strip())
                    blocks.append(
                        f'<div class="my-6 rounded-lg border-l-4 p-4 shadow-sm {cfg["container"]}">'
                        f'<div class="flex items-center gap-2 font-bold mb-1 {cfg["title_class"]}">'
                        f'<span>{cfg["icon"]}</span><span>{cfg["title"]}</span>'
                        '</div>'
                        f'<div class="text-sm leading-relaxed">{body_text}</div>'
                        '</div>'
                    )
                else:
                    body_text = "<br />".join(self.render_inline(l) for l in bq_lines)
                    blocks.append(
                        f'<blockquote class="border-l-4 border-slate-300 pl-4 py-2 my-4 text-slate-600 bg-slate-50/50 rounded-r italic text-sm leading-relaxed">{body_text}</blockquote>'
                    )
                continue

            # 7. Tables (| Col 1 | Col 2 |)
            if "|" in line and i + 1 < n and "|" in lines[i + 1] and re.search(r"^\s*\|?\s*:?-+:?\s*\|", lines[i + 1]):
                table_lines = []
                while i < n and "|" in lines[i]:
                    table_lines.append(lines[i].strip())
                    i += 1

                rendered_table = self._render_table(table_lines)
                blocks.append(rendered_table)
                continue

            # 8. Lists (ordered, unordered, checklists)
            m_list = re.match(r"^(\s*)([-*+]|\d+\.)\s+(.*)$", line)
            if m_list:
                list_lines = []
                while i < n:
                    curr = lines[i]
                    if not curr.strip():
                        # Check lookahead: if next line is part of list, keep going; else break
                        if i + 1 < n and re.match(r"^(\s*)([-*+]|\d+\.)\s+", lines[i + 1]):
                            i += 1
                            continue
                        break
                    if re.match(r"^(\s*)([-*+]|\d+\.)\s+", curr) or (list_lines and re.match(r"^\s{2,}", curr)):
                        list_lines.append(curr)
                        i += 1
                    else:
                        break

                rendered_list = self._render_list(list_lines)
                blocks.append(rendered_list)
                continue

            # 9. Paragraph
            para_lines = []
            while i < n:
                curr = lines[i]
                if not curr.strip():
                    break
                if (
                    curr.startswith("#")
                    or curr.startswith(">")
                    or re.match(r"^(\*{3,}|-{3,}|_{3,})\s*$", curr.strip())
                    or re.match(r"^(\s*)(```+|~~~+)", curr)
                    or re.match(r"^(\s*)([-*+]|\d+\.)\s+", curr)
                    or re.match(r"^\s*</?(details|summary)\b", curr)
                    or ("|" in curr and i + 1 < n and "|" in lines[i + 1] and re.search(r"^\s*\|?\s*:?-+:?\s*\|", lines[i + 1]))
                ):
                    break
                para_lines.append(curr.strip())
                i += 1

            if para_lines:
                text = " ".join(para_lines)
                blocks.append(f'<p class="text-slate-700 leading-relaxed my-3">{self.render_inline(text)}</p>')

        return blocks

    def _render_table(self, table_lines: list[str]) -> str:
        if len(table_lines) < 2:
            return ""

        def split_cells(row_str: str) -> list[str]:
            raw = row_str.strip()
            if raw.startswith("|"):
                raw = raw[1:]
            if raw.endswith("|"):
                raw = raw[:-1]
            return [c.strip() for c in raw.split("|")]

        headers = split_cells(table_lines[0])
        separators = split_cells(table_lines[1])
        aligns: list[str] = []
        for sep in separators:
            s = sep.strip()
            if s.startswith(":") and s.endswith(":"):
                aligns.append("text-center")
            elif s.endswith(":"):
                aligns.append("text-right")
            else:
                aligns.append("text-left")

        thead_cells = []
        for idx, h in enumerate(headers):
            align_class = aligns[idx] if idx < len(aligns) else "text-left"
            thead_cells.append(
                f'<th class="px-4 py-3 font-semibold tracking-wide text-xs uppercase text-slate-700 {align_class}">{self.render_inline(h)}</th>'
            )

        has_header = any(h for h in headers)

        tbody_rows = []
        for r_line in table_lines[2:]:
            cells = split_cells(r_line)
            td_cells = []
            for idx, c in enumerate(cells):
                align_class = aligns[idx] if idx < len(aligns) else "text-left"
                td_cells.append(
                    f'<td class="px-4 py-2.5 text-sm border-t border-slate-100 {align_class}">{self.render_inline(c)}</td>'
                )
            tbody_rows.append(f'<tr class="hover:bg-slate-50/75 transition-colors">{"".join(td_cells)}</tr>')

        return (
            '<div class="overflow-x-auto my-6 rounded-lg border border-slate-200 bg-white shadow-sm">\n'
            '  <table class="w-full text-left border-collapse">\n'
            + (
                f'    <thead class="bg-slate-50 border-b border-slate-200"><tr>{"".join(thead_cells)}</tr></thead>\n'
                if has_header
                else ""
            )
            +
            f'    <tbody class="divide-y divide-slate-100 text-slate-700">{"".join(tbody_rows)}</tbody>\n'
            '  </table>\n'
            '</div>'
        )

    def _render_list(self, list_lines: list[str]) -> str:
        # Determine if ordered or unordered from first line
        first_m = re.match(r"^(\s*)([-*+]|\d+\.)\s+(.*)$", list_lines[0])
        is_ordered = first_m.group(2).endswith(".") if first_m else False

        items_html: list[str] = []
        for line in list_lines:
            m = re.match(r"^(\s*)([-*+]|\d+\.)\s+(.*)$", line)
            if not m:
                # Continuation line
                if items_html:
                    items_html[-1] += f" {self.render_inline(line.strip())}"
                continue

            content = m.group(3).strip()

            # Check for task list [ ] or [x]
            m_task = re.match(r"^\[([ xX])\]\s+(.*)$", content)
            if m_task:
                checked = m_task.group(1).lower() == "x"
                rest = m_task.group(2)
                checked_attr = " checked" if checked else ""
                checkbox = (
                    f'<input type="checkbox" data-task{checked_attr} '
                    'class="mt-1 mr-2 h-4 w-4 shrink-0 cursor-pointer accent-emerald-600" />'
                )
                items_html.append(
                    f'<li class="list-none"><label class="flex items-start text-sm text-slate-700 my-1 cursor-pointer">'
                    f"{checkbox}<span>{self.render_inline(rest)}</span></label></li>"
                )
            else:
                items_html.append(
                    f'<li class="text-sm text-slate-700 my-1">{self.render_inline(content)}</li>'
                )

        tag = "ol" if is_ordered else "ul"
        list_style = "list-decimal list-inside space-y-1 my-3" if is_ordered else "list-disc list-inside space-y-1 my-3"
        return f'<{tag} class="{list_style}">{"".join(items_html)}</{tag}>'

    def generate_html(self) -> str:
        # Extract title from raw_md if not provided
        first_h1 = re.search(r"^#\s+(.+)$", self.raw_md, re.MULTILINE)
        doc_title = self.title
        if first_h1:
            doc_title = re.sub(r"<[^>]+>", "", first_h1.group(1)).strip()

        blocks = self.parse_blocks()
        if len(self.toc) >= 3:
            links = "".join(
                f'<li><a href="#{slug}" class="text-emerald-700 hover:text-emerald-900 hover:underline">{label}</a></li>'
                for slug, label in self.toc
            )
            toc_html = (
                '<nav aria-label="Contents" class="my-6 rounded-lg border border-slate-200 bg-white px-4 py-3 text-sm shadow-sm">'
                '<div class="mb-1 text-xs font-semibold uppercase tracking-wider text-slate-500">Contents</div>'
                f'<ul class="flex flex-wrap gap-x-5 gap-y-1">{links}</ul></nav>'
            )
            insert_at = self.h1_index + 1 if self.h1_index is not None else 0
            blocks.insert(insert_at, toc_html)
        content_body = "\n".join(blocks)

        owner_banner = ""
        owner_meta_tag = ""
        if self.owner_meta:
            owner = html.escape(self.owner_meta.get("owner", ""))
            session = html.escape(self.owner_meta.get("session", ""))
            created = html.escape(self.owner_meta.get("created", ""))
            owner_meta_tag = f'    <meta name="artifact-owner" content="{owner}" />\n    <meta name="artifact-session" content="{session}" />\n    <meta name="artifact-created" content="{created}" />\n'
            owner_banner = (
                '\n      <footer class="mt-12 border-t border-slate-200 pt-3 text-xs text-slate-400">'
                f"Written by {owner} · {created}</footer>\n"
            )

        escaped_title = html.escape(doc_title)

        return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{escaped_title}</title>
{owner_meta_tag}    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({{ startOnLoad: true, theme: "neutral", securityLevel: "loose" }});
    </script>
    <style>
      .seam {{ stroke-dasharray: 4 4; }}
      .leak {{ stroke: #dc2626; }}
      .deep-module {{ background: linear-gradient(135deg, #0f172a, #1e293b); }}
      pre.mermaid {{ background: transparent !important; }}
      /* Offline fallback styling */
      body {{ font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
      table {{ border-collapse: collapse; width: 100%; }}
      th, td {{ border: 1px solid #e2e8f0; padding: 0.5rem 0.75rem; }}
      th {{ background-color: #f8fafc; font-weight: 600; text-align: left; }}
      code {{ font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }}
      @media print {{
        body {{ background: white !important; color: black !important; }}
      }}
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans antialiased selection:bg-emerald-100 selection:text-emerald-900 min-h-screen">
    <main class="max-w-5xl mx-auto px-4 sm:px-6 py-12">
{content_body}
{owner_banner}
    </main>
    <script>
      // Checklist ticks survive a reload; stored per page, never required for the page to render.
      (() => {{
        const key = "task-state:" + location.pathname;
        let saved = {{}};
        try {{ saved = JSON.parse(localStorage.getItem(key) || "{{}}"); }} catch {{}}
        document.querySelectorAll("input[data-task]").forEach((box, i) => {{
          if (i in saved) box.checked = saved[i];
          box.addEventListener("change", () => {{
            saved[i] = box.checked;
            try {{ localStorage.setItem(key, JSON.stringify(saved)); }} catch {{}}
          }});
        }});
      }})();
    </script>
  </body>
</html>
"""


def open_in_browser(file_path: Path):
    resolved = file_path.resolve()
    try:
        if sys.platform.startswith("linux"):
            subprocess.run(["xdg-open", str(resolved)], check=False)
        elif sys.platform == "darwin":
            subprocess.run(["open", str(resolved)], check=False)
        elif sys.platform == "win32":
            os.startfile(str(resolved))  # type: ignore[attr-defined]
        else:
            import webbrowser
            webbrowser.open(resolved.as_uri())
    except Exception as e:
        sys.stderr.write(f"Warning: Failed to launch browser for {resolved}: {e}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Compile Markdown artifacts into styled, standalone HTML pages with Mermaid and Tailwind support."
    )
    parser.add_argument("input", type=Path, help="Input Markdown (.md) file path")
    parser.add_argument("output", type=Path, nargs="?", default=None, help="Output HTML (.html) file path (optional)")
    parser.add_argument("--open", action="store_true", help="Launch the generated HTML file in the default browser")
    parser.add_argument("--title", type=str, default=None, help="Custom document title (optional)")

    args = parser.parse_args()

    input_path = args.input
    if not input_path.is_file():
        sys.stderr.write(f"Error: Input file does not exist: {input_path}\n")
        sys.exit(1)

    output_path = args.output
    if output_path is None:
        if input_path.suffix.lower() == ".md":
            output_path = input_path.with_suffix(".html")
        else:
            output_path = input_path.with_name(input_path.name + ".html")

    raw_md = input_path.read_text(encoding="utf-8")
    renderer = MarkdownRenderer(raw_md, title=args.title)
    html_output = renderer.generate_html()

    output_path.write_text(html_output, encoding="utf-8")
    print(f"Compiled: {output_path}")

    if args.open:
        open_in_browser(output_path)


if __name__ == "__main__":
    main()
