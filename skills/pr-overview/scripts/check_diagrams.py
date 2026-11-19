#!/usr/bin/env python3
"""Check that every Mermaid diagram on a rendered page draws, with one headless Chrome load per tab.

Usage: check_diagrams.py <page.html>

Loads the page at each tab's hash with ?expand (render_overview.py opens every collapsible section then)
and counts the diagrams Mermaid drew in that tab. Prints one line per tab.

Exit 0: every diagram drew. Exit 1: a diagram has a syntax error or did not draw.
Exit 2: wrong usage, or no Chrome or Chromium on this machine. Mermaid loads from its pinned URL, so the
check needs the network; without it every diagram counts as not drawn.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

MAC_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
NAMES = ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser")
PANEL = re.compile(r'<section class="panel[^"]*" id="([^"]+)"')
BUDGET_MS = 15000  # virtual time Chrome gives the page to import Mermaid and draw
ERROR = 'aria-roledescription="error"'  # the graphic Mermaid draws in place of a diagram it cannot parse


def chrome():
    if Path(MAC_CHROME).exists():
        return MAC_CHROME
    return next((path for path in map(shutil.which, NAMES) if path), None)


def panels(page: str) -> dict:
    """{tab id: that tab's HTML}, cut at the next tab or the footer."""
    marks = list(PANEL.finditer(page))
    ends = [m.start() for m in marks[1:]] + [page.find("<footer")]
    return {m.group(1): page[m.start():end if end >= 0 else len(page)] for m, end in zip(marks, ends)}


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = Path(sys.argv[1]).resolve()
    binary = chrome()
    if binary is None:
        print("no Chrome or Chromium found: diagrams not checked", file=sys.stderr)
        return 2
    wanted = {tab: body.count('<pre class="mermaid"') for tab, body in panels(path.read_text(encoding="utf-8")).items()}
    failed = False
    for tab, want in wanted.items():
        if not want:
            print(f"{tab}: no diagram")
            continue
        run = subprocess.run([binary, "--headless=new", "--disable-gpu", f"--virtual-time-budget={BUDGET_MS}",
                              "--dump-dom", f"{path.as_uri()}?expand#{tab}"],
                             capture_output=True, text=True, timeout=120)
        body = panels(run.stdout).get(tab, "")
        broken = body.count(ERROR)
        drawn = body.count("aria-roledescription=") - broken
        ok = drawn == want and not broken
        failed = failed or not ok
        print(f"{tab}: {drawn}/{want} drawn" + (f", {broken} with a syntax error" if broken else "") + ("" if ok else "  FAIL"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
