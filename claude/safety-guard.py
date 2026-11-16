#!/usr/bin/env python3
"""PreToolUse hook for Bash: deny commands whose side effects were costly before.

- `rm` with an unquoted glob: a glob deleted a user backup on 2026-11-03. Delete by exact path.
- `az repos pr update --description` without `--draft`: the call publishes a draft PR.
- An unquoted glob in a `--flag=value` word (`--include=*.py`, `--format=%(trailers)`): zsh expands it and
  aborts the whole command with "no matches found" (sessions d5b3dbc1, 26411941 and afba83ab).
- `az … --output-file` outside `az rest`, or `--out-file` on `az repos`, `az boards` or `az pipelines`:
  the flag does not exist there. Agents wrote one of the two 9 times in one week, 6 of them after
  `pr-host` warned against it (sessions a018cbeb and 3b2d4e79 among them).
- `git grep <pattern> -A3`: git grep stops reading options at the pattern and takes the rest as revisions
  ("unable to resolve revision: -A3", sessions 1f97fede, 5e64b301, 662c886a, 2d5d9c51 and cb4f6a96).
- A backtick inside double quotes: zsh runs it as a command substitution (session 50076a9e ran `az`).

Set CLAUDE_SAFETY_GUARD=0 to turn the guard off.
"""
import json
import os
import re
import sys

SEGMENT_START = re.compile(r"&&|\|\||[;\n(|]")
QUOTED = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"")
# rm as the segment's command, so `echo rm *` and `git rm` pass.
RM = re.compile(r"^\s*(sudo\s+)?rm\s")
GLOB = re.compile(r"[*?]|\[[^\]]*\]")
PR_UPDATE = re.compile(r"\baz\s+repos\s+pr\s+update\b")
# A `--flag=value` word whose value holds a glob character that no backslash escapes. A bare `(` counts
# (`--format=%(trailers)`, session afba83ab); the `(` of a `$(…)` substitution does not.
FLAG_GLOB = re.compile(r"(?<!\S)--[\w-]+=(?:\\.|\$\(|(?!\$\()[^\s\\*?(])*[*?(]\S*")
# az as the segment's command, so another tool's own `--output-file` passes. `az rest` has the flag.
AZ_OUTPUT_FILE = re.compile(r"^\s*az\s+(?!rest\b).*(?<!\S)--output-file\b")
# In the azure-devops groups only `az devops invoke` has `--out-file`.
AZ_OUT_FILE = re.compile(r"^\s*az\s+(?:repos|boards|pipelines)\s.*(?<!\S)--out-file\b")
# grep as git's subcommand, after any of git's own options (`-C <dir>`, `-P`), so `git log --grep` passes.
GIT_GREP = re.compile(r"\bgit(?:\s+-[Cc]\s+\S+|\s+-{1,2}[\w-]+(?:=\S+)?)*\s+grep\s+(.*)")
# git grep options that take their value as the next word.
GREP_VALUE_OPTIONS = {
    "-e", "-f", "-A", "-B", "-C", "-m",
    "--context", "--after-context", "--before-context", "--max-depth", "--max-count", "--threads",
}  # fmt: skip


def segments(command):
    return SEGMENT_START.split(command)


def rm_glob(command):
    # Quoted globs reach rm literally, so only unquoted ones expand.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    for segment in segments(unquoted):
        match = RM.search(segment)
        if match and GLOB.search(segment[match.end() :]):
            return segment.strip()
    return None


def pr_update_without_draft(command):
    # Quoted text such as "$(cat body.md)" holds no flags, and its `(` must not split the call.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    for segment in segments(unquoted):
        if PR_UPDATE.search(segment) and "--description" in segment and "--draft" not in segment:
            return segment.strip()
    return None


def flag_glob(command):
    # Quoted globs reach the command literally, so only unquoted ones make zsh abort.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    match = FLAG_GLOB.search(unquoted)
    return match.group(0) if match else None


def az_file_flag(command):
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    for segment in segments(unquoted):
        if AZ_OUTPUT_FILE.search(segment):
            return "--output-file"
        if AZ_OUT_FILE.search(segment):
            return "--out-file"
    return None


def grep_option_after_pattern(command):
    # A quoted pattern becomes one word, so its spaces and dashes are not read as options. A quoted
    # `(` or `)` groups `-e` patterns and is an option to git grep, not the pattern.
    unquoted = QUOTED.sub(lambda m: "--paren" if m.group(0)[1:-1] in ("(", ")") else "Q", command)
    for segment in segments(unquoted):
        match = GIT_GREP.search(segment)
        if not match:
            continue
        words = match.group(1).split()
        seen_positional = False
        index = 0
        while index < len(words):
            word = words[index]
            if word == "--" or word[0] in "<>" or word[:2] == "2>":
                break
            if word.startswith("-") and len(word) > 1:
                if seen_positional:
                    return word
                if word in GREP_VALUE_OPTIONS:
                    index += 1
            else:
                seen_positional = True
            index += 1
    return None


def backtick_in_double_quotes(command):
    # A here-document body (always on later lines) is not shell-quoted, so its quotes cannot be read here.
    if "`" not in command or ("<<" in command and "\n" in command):
        return False
    quote = None
    index = 0
    while index < len(command):
        char = command[index]
        if quote == "'":
            if char == "'":
                quote = None
        elif char == "\\":
            index += 1
        elif quote == '"':
            if char == '"':
                quote = None
            elif char == "`":
                return True
        elif char in "'\"":
            quote = char
        index += 1
    return False


def main():
    if os.environ.get("CLAUDE_SAFETY_GUARD") == "0":
        return 0
    payload = json.load(sys.stdin)
    if payload.get("tool_name") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command") or ""
    if hit := rm_glob(command):
        reason = (
            f"`{hit}` deletes through a glob. List the matches first, then rm each approved path "
            "exactly, with no wildcards."
        )
    elif hit := pr_update_without_draft(command):
        reason = (
            "`az repos pr update --description` without `--draft` publishes a draft PR. Read the PR's "
            "isDraft and pass `--draft <isDraft>`."
        )
    elif hit := flag_glob(command):
        reason = (
            f"`{hit}` holds an unquoted glob: zsh expands it and aborts with \"no matches found\". "
            "Quote the value, e.g. `--include='*.py'`."
        )
    elif hit := az_file_flag(command):
        reason = (
            f"This `az` command has no `{hit}`. Redirect with `> <path>`. `--output-file` belongs to "
            "`az rest` and `--out-file` to `az devops invoke`."
        )
    elif hit := grep_option_after_pattern(command):
        reason = (
            f"`{hit}` comes after the pattern, where git grep reads it as a revision. Put every option "
            "before the pattern: `git grep -n -A3 <pattern> -- <path>`."
        )
    elif backtick_in_double_quotes(command):
        reason = (
            "A backtick inside double quotes runs as a command in zsh. Single-quote the text, escape "
            "the backtick, or put the text in a script file and run that."
        )
    else:
        return 0
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
