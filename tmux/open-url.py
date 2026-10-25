#!/usr/bin/env python3
import os
import re
import shutil
import subprocess
import sys
from urllib.parse import urlparse, unquote

# File extensions that should open in Antigravity IDE (code/docs/config)
IDE_EXTENSIONS = {
    ".md", ".markdown",
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".json", ".jsonc",
    ".cs", ".csproj", ".sln",
    ".py", ".pyi",
    ".css", ".scss", ".less",
    ".yaml", ".yml", ".toml", ".xml",
    ".sh", ".bash", ".zsh",
    ".sql", ".graphql", ".gql",
    ".rs", ".go", ".c", ".cpp", ".h", ".hpp",
    ".env", ".gitignore", ".dockerignore", "dockerfile",
}

# Web extensions that should open in Brave Browser
BROWSER_EXTENSIONS = {
    ".html", ".htm", ".xhtml", ".svg", ".pdf"
}

def notify_tmux(message):
    try:
        subprocess.run(
            ["tmux", "display-message", "-d", "2000", message],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass

def extract_target(hyperlink, line, col_str, cwd):
    if hyperlink and hyperlink.strip():
        return hyperlink.strip()

    if not line:
        return None

    try:
        col = int(col_str)
    except Exception:
        col = -1

    # Remove ANSI escape sequences
    clean_line = re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", line)
    clean_line = re.sub(r"\x1b\].*?\x1b\\", "", clean_line)

    # Patterns for URLs and file paths
    pattern = re.compile(
        r"(?:https?|file)://[^\s'\"<>`]+|"
        r"(?:/[^\s'\"<>`]+|\./[^\s'\"<>`]+|\.\./[^\s'\"<>`]+|[a-zA-Z0-9_.-]+/[^\s'\"<>`]+)"
    )

    matches = list(pattern.finditer(clean_line))
    if not matches:
        return None

    target = None
    if col >= 0:
        for m in matches:
            if m.start() <= col <= m.end():
                target = m.group(0)
                break

    if not target and len(matches) == 1:
        target = matches[0].group(0)
    elif not target and col >= 0 and matches:
        target = min(
            matches,
            key=lambda m: min(abs(m.start() - col), abs(m.end() - col)),
        ).group(0)

    if not target:
        return None

    # Strip trailing punctuation
    target = target.rstrip(".,;:!?)>]}\"'`")

    # If relative path, resolve against cwd
    if not target.startswith(("http://", "https://", "file://")):
        if not os.path.isabs(target) and cwd:
            target = os.path.normpath(os.path.join(cwd, target))

    return target

def open_target(target):
    brave_bin = shutil.which("brave") or shutil.which("brave-browser") or "/usr/bin/brave"
    ide_bin = shutil.which("antigravity-ide") or os.path.expanduser("~/.local/bin/antigravity-ide")
    display_name = target if len(target) <= 50 else "..." + target[-47:]

    # 1. HTTP / HTTPS web links -> Brave
    if target.startswith(("http://", "https://")):
        subprocess.Popen(
            [brave_bin, target],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        notify_tmux(f"Opened in Brave: {display_name}")
        return

    # 2. Extract local path if file:// URI
    file_path = target
    if target.startswith("file://"):
        parsed = urlparse(target)
        file_path = unquote(parsed.path)

    _, ext = os.path.splitext(file_path.lower())
    basename = os.path.basename(file_path.lower())

    # 3. HTML / web documents (.html, .htm, .pdf, .svg) -> Brave
    if ext in BROWSER_EXTENSIONS:
        subprocess.Popen(
            [brave_bin, target],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        notify_tmux(f"Opened in Brave: {display_name}")
        return

    # 4. Source code, markdown, config files -> Antigravity IDE
    if ext in IDE_EXTENSIONS or basename in IDE_EXTENSIONS:
        subprocess.Popen(
            [ide_bin, file_path],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        notify_tmux(f"Opened in Antigravity IDE: {display_name}")
        return

    # 5. Fallback to system default opener (xdg-open)
    xdg_bin = shutil.which("xdg-open") or "/usr/bin/xdg-open"
    subprocess.Popen(
        [xdg_bin, target],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    notify_tmux(f"Opened: {display_name}")

def main():
    hyperlink = os.environ.get("URL", "")
    line = os.environ.get("LINE", "")
    col = os.environ.get("COL", "")
    cwd = os.environ.get("CWD", "")

    if len(sys.argv) > 1 and sys.argv[1]:
        target = sys.argv[1]
    else:
        target = extract_target(hyperlink, line, col, cwd)

    if target:
        open_target(target)

if __name__ == "__main__":
    main()
