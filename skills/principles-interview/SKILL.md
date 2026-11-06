---
name: principles-interview
description: Interviews me in multiple-choice rounds, each question with an evidence-backed recommended pick, to surface my guiding principles and decision frameworks, then saves the confirmed ones as memory files.
disable-model-invocation: true
argument-hint: "[agents|engineering|planning ...] [--dry-run]"
---

# Skill: `/principles-interview`: Surface My Principles

Turns how I actually decide into memory that later sessions follow. The interview checks patterns already visible in my memories, rules and past sessions, then probes the places where no rule exists yet. Every question comes with a recommended pick, so I mostly confirm or correct instead of writing from scratch.

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`
- `../_modules/artifact-protocol.md`: writes no artifact. The deliverable is memory files.

- **Writes only the memory directory**, and only in step 5. `--dry-run` stops after step 4 and writes nothing.
- **Saving follows [`remember-this`](../remember-this/SKILL.md).** Read its *Core Protocol & Workflow*, steps 2–5, before step 5 here. This skill owns the interview; remember-this owns how a memory is split, deduplicated, written and indexed.

---

## 1. When *not* to use

| Situation | Use instead |
|---|---|
| Save one decision just made in this conversation | [`/remember-this`](../remember-this/SKILL.md) |
| Stress-test a plan or design | `/grilling` (plugin skill) |
| Review what others said about my work | [`/analyze-personal-feedback`](../analyze-personal-feedback/SKILL.md) |
| A rule the whole team should follow | The repo's `AGENTS.md`, through a normal change |

---

## 2. Areas

| Area | Covers |
|---|---|
| `agents` | How agents work for me: autonomy, when to ask, verification, output length, commits, parallelism, tooling |
| `engineering` | Code and architecture tradeoffs: abstraction vs duplication, test strategy, quality gates, when to write an ADR |
| `planning` | Scoping, phasing, sequencing, what "done" and "good enough" mean |

With no area arguments, ask one multi-select question naming all three, recommending the area with the most evidence gaps found in step 2.

---

## 3. Core Protocol & Workflow

### Step 1: Pick areas

From the arguments or the question in *Areas*. Done when at least one area is chosen.

### Step 2: Gather evidence

Read everything that already records how I decide, so recommendations rest on my own history:

- The memory directory: the one the host names, else the folder holding the `MEMORY.md` the host loaded. If neither exists, say so and stop. Read every listed file that carries memory frontmatter; skip the rest (e.g. a repo `README.md`).
- `~/.claude-mem/MY-RULES.md` (written by claude-mem from My Rules; read-only here).
- `~/.claude/CLAUDE.md`, and the `CLAUDE.md` / `AGENTS.md` / `CLAUDE.local.md` / `AGENTS.local.md` chain for the current directory.
- When claude-mem's `search` tool is available: one search per chosen area across all projects (principles are cross-project) for corrections and decisions (e.g. "user corrected", "user preferred", "decided"), then `get_observations` for the few that look like lasting patterns. Cite only observations you fetched. Skip silently when the tool is absent.

Sort each candidate into one of three buckets:

- **Stated**: written somewhere as a general rule. Ask about it only when two sources conflict, or when its *why* is missing everywhere (most My Rules lines carry none; a memory file may supply it).
- **Inferred**: a general rule that only two or more narrower memories or incidents imply. Confirm it.
- **Gap**: a recurring decision in the area with no recorded stance. Keep the 4 per area that recur most.

Something found outside the chosen areas goes to the *next run* list in the output, not into this run's questions.

Done when every chosen area has a candidate list, each candidate carrying its bucket and source path (or observation ID).

### Step 3: Interview in rounds

Each round is one AskUserQuestion call with up to 4 questions, in this order: follow-ups on last round's free-text answers, inferred, gaps, stated conflicts, tipping points. At most one missing-*why* question per round.

Write each question as a concrete **fork**: a realistic situation with two to four ways to act, never "what do you value?". "A fix touches 3 files and the tests take 8 minutes: run them, run a targeted subset, or skip and list them?" surfaces a framework; "how important is testing?" surfaces a slogan.

- **Recommended pick first**, labelled `(Recommended)`, and its description names the evidence: the memory, rule or observation and what it showed. Recommend from general best practice only when no evidence exists, and say so in the description.
- After a pick, follow up on the **tipping point** in a later round when the framework needs one: "what would make you choose the other option?". A principle without its tipping point is a slogan, not a framework.
- A free-text "Other" answer is often the richest one; follow it up.
- My words outrank the evidence. After an absolute answer ("always", "never"), the tipping-point question includes "No exception" as an option, and a recommendation that softens my answer says so in its description.
- Build each round on the last round's answers. I can end the interview at any point.

Done when every inferred candidate is confirmed or rejected, every kept gap has been asked, and each chosen area has at least one framework with its tipping point (a principle counts toward the area of the question that produced it), or when I end it. If I end it early, the output names each area still lacking a framework.

### Step 4: Draft and confirm

Write the draft in chat, one entry per principle:

```markdown
**<principle as an instruction>**
Why: <my reason, quoted; "accepted recommendation: …" for the parts I only picked>
Tipping point: <when the other choice wins>   ← frameworks only
Source: <interview round, plus the evidence paths it confirmed>
Action: create <file> | update <file> | unchanged <file>   [; conflicts with <file › section or My Rules line>]
```

Below the draft, quote each conflicting memory file. Everything else is **report-only**: name the source and its section or line, and what I would change there; never edit it.

- `MY-RULES.md` (claude-mem owns it): name the entry for me to change in the claude-mem web UI.
- A `CLAUDE.md` / `AGENTS.md`, skill or Module (e.g. `core.md` › *Post-edit verification*): name the file and section.
- A *why* I gave for a My Rules line goes here as a suggested rewording of that entry, not into a new memory file, so the rule keeps one home.

Then ask one AskUserQuestion round: one question per memory-file conflict (update it, keep it, or record the new answer as a scoped exception), and last the save question (save all, save some, or revise). More than 3 conflicts spill into a second round before the save question. With `--dry-run`, print these questions as text, ask nothing, and stop.

Done when every principle has an Action and I have answered the save question.

### Step 5: Save

Follow remember-this steps 2–5 for the approved principles. Type each as `feedback` (how to work) or `user` (who I am), put the tipping point in `**How to apply:**`, and link principles that share a tradeoff with `[[name]]`.

---

## 4. Output Format & Deliverables

In chat, short:

- Areas covered and the number of rounds.
- One bullet per memory file: created / updated / unchanged, path, principle in one line. After `--dry-run`: "Dry run: nothing written" instead.
- Report-only items: My Rules edits (conflicts and suggested *why* rewordings), then conflicts in instruction files, skills and Modules.
- *Next run*: gaps and tipping points not asked, and findings outside the chosen areas.

---

## 5. Verification & Validation

Before reporting, run remember-this *Verification & Validation*, plus:

- Every saved principle traces to an answer I gave in this run.
- No file outside the memory directory changed, and no memory file restates a My Rules line.
