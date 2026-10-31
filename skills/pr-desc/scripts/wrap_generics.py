#!/usr/bin/env python3
"""Wrap C#/TS generics (List<Foo>, Task<IResult>, <T>) in backticks so ADO markdown
doesn't swallow them as HTML tags. Leaves fenced blocks and existing code spans alone.

Usage: wrap_generics.py FILE   (rewrites FILE in place, prints the number of wraps)
"""
import re
import sys

INNER = r"[^<>`\n]*"
GENERIC = re.compile(
    # Identifier<...> with one level of nesting: Dictionary<string, List<int>>
    rf"\b[A-Za-z_][\w.]*<{INNER}(?:<{INNER}>{INNER})*>(?:\[\])?\??"
    # Bare type parameters: <T>, <TKey, TValue>
    r"|<[A-Z]\w*(?:\s*,\s*[A-Z]\w*)*>"
)
CODE_SPAN = re.compile(r"(`+)[^`]*?\1")


def wrap_line(line: str) -> tuple[str, int]:
    out, count, pos = [], 0, 0
    for span in CODE_SPAN.finditer(line):
        text, n = GENERIC.subn(lambda m: f"`{m.group(0)}`", line[pos:span.start()])
        out += [text, span.group(0)]
        count, pos = count + n, span.end()
    text, n = GENERIC.subn(lambda m: f"`{m.group(0)}`", line[pos:])
    return "".join(out) + text, count + n


def main(path: str) -> None:
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    in_fence, total = False, 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith(("```", "~~~")):
            in_fence = not in_fence
            continue
        if not in_fence:
            lines[i], n = wrap_line(line)
            total += n
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrapped {total} generic(s)")


if __name__ == "__main__":
    main(sys.argv[1])
