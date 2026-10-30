---
name: skill-gap
description: 'Works through the skill gaps logged in ~/.terminal/skill-gaps/ (core › Skill gaps). Lists which gaps are open and which look already fixed or out of date, verifies those, groups the open ones by skill, then asks Fix or log once and edits each group in the registry or leaves it logged for later. Use for /skill-gap, "any open skill gaps?", "fix the skill gaps", "which skill gaps are still open?", "clean up the skill-gap files".'
argument-hint: "[skill name — defaults to every gap]"
---

# Skill: `/skill-gap` — From Logged Gaps to Fixed Skills

A skill gap is a fact or instruction in a registry skill that proved wrong, logged as one file in `~/.terminal/skill-gaps/`. `core` › _Skill gaps_ is the only home of the rules: what counts, the file format and the **Status** values. This skill finds the gaps still worth acting on and takes them to a fix or an explicit "log it for later"; it adds no rule of its own.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:

- `../_modules/core.md`: read-only until the _Fix or log_ answer (step 4); that answer opens step 5's edits, nothing else
- `../_modules/artifact-protocol.md`: writes no artifact — the deliverable is the edited skills and Status lines

---

## Guards

- **Status** is the only field you edit in an existing gap file. Never delete, rename or overwrite one.
- Steps 1–4 only read. No edit (Status included) before the _Fix or log_ answer.
- **No commit, no push.** The registry is trunk-only and commits are asked for separately (`/commit`). A gap in a skill that lives outside the registry follows that repo's own rules (`core` › _Skill gaps_ › Scope).

## 1. List the gaps

`<registry>` is the parent of this skill's real folder.

```bash
python3 -I <registry>/skill-gap/scripts/list_gaps.py          # table
python3 -I <registry>/skill-gap/scripts/list_gaps.py --json   # every parsed field, for grouping
```

The script reads `skill-gaps/` next to the registry, understands both the template's `- **Status:**` line and the older `Status: <value> · Command: …` line, and never writes. It compares against the working tree and its git history, since fixes are often uncommitted. `--dir <folder>` reads another folder. Exit 2 means the folder can't be read. With an argument, keep only that skill's gaps.

| Class          | The script found                                                                                                                            | Next    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `open`         | Status `open` (or a value core.md doesn't define, flagged in the reason) and none of the below                                              | Step 3  |
| `likely-fixed` | A file the Proposed edit targets (else the skill's folder) has a commit since the gap's Found time, or an uncommitted change saved after it | Step 2  |
| `stale`        | No skill of that name in the registry, or the text the Proposed edit says to `replace` is no longer in its file                             | Step 2  |
| `closed`       | Status `fixed` or `not a gap: …`                                                                                                            | Nothing |

No gaps, or only `closed` ones: say so and stop.

## 2. Verify each likely-fixed or stale gap

The class is a hint from git history and file times, not a verdict. For each gap, read its **Skill gap** line and **Proposed edit**, then the file today and the changes the script lists (`git -C <registry> show <sha>`, `git -C <registry> diff -- <path>`). Decide:

| Finding                                                                                                 | Proposed Status                                                                                                                             |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| The file now says what the gap asked for                                                                | `fixed`                                                                                                                                     |
| The gap no longer applies (skill or section removed, or it never was a gap under `core` › _Skill gaps_) | `not a gap: <reason>`                                                                                                                       |
| Still wrong                                                                                             | Stays `open` and joins step 3. For a stale quote, restate the Proposed edit against today's text in your reply; the file keeps its original |

Quote the line you checked (`path:line`) beside each proposed Status. Don't write it yet.

## 3. Group the open gaps

Group the open gaps by the skill each mostly concerns; one group is one set of edits to that skill. For each gap, give its block as `core` › _Skill gaps_ shows, headed `**Skill gap (<skill>):**`, and name its file.

## 4. Ask Fix or log once

One question, at the end: through AskUserQuestion when the host has it, otherwise as the reply's last lines. It covers every group from step 3 and every Status proposed in step 2, so the user answers once:

- **Fix it** (recommended), per group: step 5.
- **Log it for later:** name the files and change nothing.
- The step 2 Status updates: apply them, or leave the files as they are.

With several groups, put one question per group in the same AskUserQuestion call. Stop after asking. A choice the request already made ("fix the skill gaps") counts as the answer.

## 5. Fix a group

Once per group, in the registry checkout (never a snapshot, `core` › _The `/proceed` gate_ rule 5):

1. Re-check each fact against the code or tool it names, then make the Proposed edit (restated against today's text when step 2 found the quote stale).
2. Run the gap's **Check**, then lint the registry: `python3 -I <registry>/sync-skills/sync_skills.py` (report only; it applies nothing without `--apply`). Zero new errors.
3. Set **Status** to `fixed` in each gap file of the group. Change nothing else in the file.

Then apply the step 2 Status updates the user accepted, the same way. End with the files edited and offer `/commit`; don't run it.
