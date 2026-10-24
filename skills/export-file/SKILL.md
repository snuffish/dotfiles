---
name: export-file
description: Exports the latest review, plan, or explanation from chat into a standalone file.
disable-model-invocation: true
argument-hint: "[/markdown|/html|/txt] [directory or file path] [what to export]"
---

# Skill: `/export-file` — Export Conversation Content to a File

Turns something already said in the conversation into a standalone file the user can keep, share or open in an editor. It writes one file and changes nothing else.

The name is `export-file` because Claude Code's built-in `/export` (the raw transcript) would shadow a skill called `export`. Typing `export /markdown` as a plain prompt still reaches this skill through its description.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes `<prefix>-export-<suffix>.<ext>`, in the current working directory instead of the workspace root unless the user gives a location; prefix, suffix, owner marker and *Claim* apply as written there

- Write exactly one file. No git staging or commits, no edits to other files, and no new analysis: the export carries what the conversation already established.
- Never overwrite an existing file. A name the user chose that is already taken is a question, not a write.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| The verbatim conversation transcript | Claude Code's built-in `/export` |
| A review, plan or investigation that doesn't exist yet | [`/code-review`](../code-review/SKILL.md), [`/plan`](../plan/SKILL.md), [`/investigate`](../investigate/SKILL.md) |
| A page to publish and share by link | the host's artifact or document tool |

---

## 2. Core Protocol & Workflow

### Step 1: Parse the arguments

Read the arguments and the user's sentence together. Every part is optional.

**Format.** The first match wins: an explicit token, then the extension of a named file, then markdown. If a token and an extension disagree (`/html notes.md`), ask which one is meant.

| Tokens | Extension | Notes |
|---|---|---|
| `/markdown`, `/md`, `markdown`, `md` (default) | `.md` | GitHub-flavoured markdown; owner marker on line 1 |
| `/html`, `html` | `.html` | One self-contained page: `<!doctype html>`, charset and viewport metas, inline CSS with colour tokens on `:root` and a `prefers-color-scheme: dark` override, an explicit `body` background, no external scripts. Owner marker as the first line inside `<head>` |
| `/txt`, `/text`, `txt`, `text` | `.txt` | Plain text: headings underlined, tables as aligned columns, links as `text (url)`. No owner marker |

Any other format token: say which ones are supported and stop.

**Destination.**
- None given: the current working directory. Run `pwd` once and use that path.
- A directory (it exists, or the path ends in `/`): write there. Create it with `mkdir -p` only when the user named it.
- A path with a file name: write exactly that file. Relative paths resolve against `pwd`; expand `~`.

**What to export.** Anything left in the sentence that names content ("the spec section", "the plan from earlier", "both reports") picks the content in Step 2.

### Step 2: Pick the content

- **Default:** the most recent substantial assistant answer, meaning the last deliverable, not the last status line. In "Done, saved the file", the deliverable is the answer before it.
- **Named:** the part the user points at, such as one section or several answers combined in the order they appeared.
- **Unclear:** if two or more candidates fit equally well, ask with the candidates as options. Don't merge them by guess.
- **Already a file:** if the content lives in a file this conversation wrote, export the file's current text, not the chat paraphrase of it.

### Step 3: Make it standalone

Rewrite only what stops the file from reading on its own. Keep the substance, wording, order, findings, numbers and `path:line` references.

- Add a title, and a short header with what this is and where it came from, using facts the conversation established: subject, scope, branch, commit or ticket, sources, and today's date.
- Replace chat-relative wording ("above", "as I said", "the second agent") with the thing it refers to.
- Drop chat-only scaffolding: tool chatter, "I'll now…", offers of next steps, and notes addressed to the user ("I saved…").
- Keep links that work outside the chat. Turn chat-only references into plain text.
- Keep any statement of what was not checked or not verified. An export is never more certain than its source.
- If the content holds secrets or personal data the user may not want in a file, name them and ask before writing.

### Step 4: Write without overwriting

The host's file-writing tool overwrites silently, so never write the target with it directly.

1. **Draft** the export in a session-private path: the host's scratchpad, else `mktemp`.
2. **Name** it. A user-given file name is used as is. Otherwise use `<prefix>-export-<suffix>.<ext>`:
   - `<prefix>` follows `artifact-protocol` › *Artifact Location, Host & Model Prefix Resolution & Mandatory Contextual Suffix*.
   - `<suffix>` is the content kind followed by that section's suffix (ID + slug, else the branch, else a topic), e.g. `claude-opus-5.5-export-code-review-18815-local-env-scripts.md`.
   - The base name is always `export`, never a catalog name such as `code_review`. Commands that read those families expect their own structure.
3. **Publish** with an exclusive create.
   - **Generated name:** let the counter pick the next free name.

     ```bash
     # $1 = draft file, $2 = target path without extension, $3 = extension; prints the path written
     publish_new_export() {
       local p="$2.$3" n=1
       [ -d "$(dirname "$2")" ] && [ -w "$(dirname "$2")" ] || return 1
       until ( set -C; cat "$1" > "$p" ) 2>/dev/null; do
         n=$((n + 1)); [ "$n" -gt 99 ] && return 1
         p="$2-$n.$3"
       done
       printf '%s\n' "$p"
     }
     ```

   - **User-given name:** make one attempt with `( set -C; cat "$draft" > "$target" )`. If the file exists, show its first lines and ask whether to overwrite it or choose another name. Overwrite only on an explicit yes.
   - **Failure:** if publishing fails (missing or read-only directory), report the path and the reason. Don't fall back to another location unasked.

---

## 3. Output Format & Deliverables

Reply with the path that was actually written, as a clickable link:
- workspace-relative when the file is inside the workspace;
- absolute otherwise;
- formatted per `artifact-protocol` › *Host-Specific Link Formats & Section Anchors*.

Add one line on what was exported, and mention anything you had to decide: a counter added to the name, content you dropped or asked about, or a format inferred from the extension. Don't repeat the content in chat.

---

## 4. Verification & Validation

Before replying:
- The file exists at the printed path and is not empty: `ls -l <path>`.
- No chat-relative wording is left: `grep -niE '\b(above|below|as I said|earlier in (this|the) (chat|conversation))\b' <path>`. Fix any hit that points at chat content, not at the file's own sections.
- For `.html`: the file starts with `<!doctype html>` and contains no `<script src=`.
- Delete the draft from the scratchpad.
