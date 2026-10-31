---
name: create-prompt
description: "Transforms draft, raw, or prior prompts into 3 distinct, hardened prompt variations (Surgical, Deep, Interactive) grounded in live workspace context. Inspects git state, referenced skills, domain docs, and execution gates. Use for /create-prompt, 'create a prompt', 'craft a prompt', 'enhance this prompt', 'turn this into a prompt', 'refine prompt', 'write a prompt for this'. Not for UI Stitch generation (use /enhance-prompt) or issue tickets (use /create-ticket)."
disable-model-invocation: true
---

# Skill: `/create-prompt` — Context-Grounded Prompt Architect

Transforms draft instructions, rough concepts, or prior prompts into a curated palette of 3 distinct, battle-tested prompt variants (Surgical, Deep, Interactive) grounded in the live repository state and target skills.

---

## ⛔ Execution Gate — Never Run the Prompt

> [!CAUTION]
> 1. **The Command ends at the printed prompt.** Never invoke the target skill, spawn agents, or run any step a variant describes. Read-only grounding commands (Step 2) are the only commands it runs.
> 2. **Only a literal `/proceed` runs a prompt**: a user message that *starts with* `/proceed` (`/proceed`, `/proceed variant 2`, …). A `/proceed` mentioned mid-sentence ("ok, /proceed later") does not count. This is stricter than `core` › *The `/proceed` gate*: a plain "go ahead", picking a variant, answering the unresolved questions or "use your recommendations" does **not** open it.
> 3. **Follow-up input refines, never runs.** Apply answers, picks or corrections to the prompt, reprint the final variant as one paste-ready block, and end with the waiting step (*Step 4* › *Closing line*).

---

## Modules

Paths are relative to this skill's real folder. Run `realpath` on the skill's base directory once (it may be a symlink), then resolve each path from there. If any Module cannot be read, stop and report the path. Do not continue without it.

Read these before step 1:
- `../_modules/core.md`: read-only until `/proceed`, and only a literal `/proceed` opens the gate (*Execution Gate*)
- `../_modules/artifact-protocol.md`: writes no artifact by default; prints paste-ready blocks in chat. If the user passes `--file` or requests a saved prompt, writes `<prefix>-prompt-<suffix>.md` at workspace root

---

## 1. When to Use

### Use when:
- You have a rough prompt or instruction (e.g. `Scope: This PR`, "review these changes", "refactor the auth flow") and want clean, high-signal prompt options.
- You want to target a specific workflow skill (e.g. `/code-review`, `/improve-codebase-architecture`, `/tdd`, `/implement-feature`) with verified parameters and correct invariants.
- You need to choose between different execution styles (minimal token footprint vs deep edge-case verification vs phased human-in-the-loop).

### When *not* to use — pick the right neighbor:

| Situation | Use instead |
|---|---|
| Enhancing UI generation prompts for Google Stitch | `/enhance-prompt` |
| Creating an issue tracker ticket | [`/create-ticket`](../create-ticket/SKILL.md) |
| Drafting an implementation plan directly | [`/plan`](../plan/SKILL.md) |
| Identifying hidden traps or blind spots in an existing plan | [`/what-am-I-missing`](../what-am-I-missing/SKILL.md) |

---

## Planning & Prompt Framing

- Keep generated prompts **concise, directional, and open to discovery**: outline intent, scope boundaries, reference exemplars, and invariants without prescribing file-by-file targets, section numbers, or low-level mechanics upfront.
- **Ground boundaries, never findings**: resolve the concrete anchors the user pointed at (workspace/directory path, branch/diff ref, reference repo/pattern, target skill, verification command), but never pre-solve the audit during Step 2 or bake a pre-picked list of candidate files into the prompt. Leave room for the downstream agent and its explorer sub-agents to uncover things not yet known.
- Sacrifice grammar for extreme brevity.
- If genuine architectural forks or domain ambiguities exist, end with a concise bullet list of unresolved questions; omit if none.

---

## 2. Step-by-Step Workflow

### Step 1: Parse Input & Ambiguity Check

1. **Extract Core Target**:
   - What is the user trying to accomplish? (Refactoring, architecture survey, code review, test creation, bug fix).
   - Did the user name a target skill (e.g. `/code-review`, `/plan`, `/refine`) or a reference exemplar (`@[...]` directory/file)?
2. **Ambiguity Gate**:
   - If the input is clear enough to infer the intent and scope, proceed directly to Step 2.
   - If the input is fundamentally vague (e.g. only "fix it" or "make it better" with no files or context indicated), stop and ask **1–2 focused multiple-choice questions** using the question tool before generating variants.

---

### Step 2: Live Workspace & Skill Grounding

**Never emit abstract placeholders (`<branch>`, `<pr-url>`, `<paths>`) for the scope or exemplar when live values exist — but keep grounding lightweight and boundary-focused.**

1. **Resolve Scope & Exemplar Anchors**:
   - Resolve any `@[...]` paths, active branch (`git branch --show-current`), or uncommitted state (`git status -s`).
   - When the task targets a branch diff or PR ("This PR", "my changes", "active branch"), resolve the merge-base range (`git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD`).
   - When the task targets a broader directory, subsystem, or cross-project pattern, record the root path and the reference exemplar path/structure — **do not** inventory every file or section inside the target to paste into the prompt.
2. **Inspect Referenced Skills & Rulebooks**:
   - If a specific slash command or skill is named (e.g. `/plan`, `/code-review`, `/refine`), locate and read its `SKILL.md` to extract:
     - Exact argument formats and supported flags (e.g. `Scope: This PR`, `deep`, `live`).
     - Required domain vocabulary and verification commands.
     - Mandated deliverable formats and non-destructive execution gates (`core` read-only invariant, `/proceed` gate).
3. **Inspect Domain Language & ADRs**:
   - Check `GLOSSARY.md` and `docs/adr/` if relevant so the prompt names the right domain concepts and ADR boundaries without restating their contents inline.

---

### Step 3: Multi-Variant Synthesis (The 3 Archetypes)

Always synthesize **3 distinct, concise prompt variants**. State *what to look for* and *which rules hold*, not a pre-baked inventory of files to touch:

#### Variant 1: Surgical / Fast
- **Focus**: Minimal context tokens, tight scope, direct to point, zero ceremony.
- **Best for**: Small changes, single-file audits, quick sanity checks, or a fast pass with minimal overhead.
- **Structure**: Concrete command + bounded scope & reference exemplar + 1–2 core constraints + verification/stop condition. (List specific files only when the user's request is already about those exact files or a small diff).

#### Variant 2: Deep / Rigorous
- **Focus**: Edge-case verification, architectural invariants, and cross-layer contract checks, each constraint stated with its reason.
- **Best for**: Complex PRs, security/persistence logic, core architectural modifications, or thorough system-wide audits.
- **Structure**: Target command & scope + reference pattern/ADRs + invariants to enforce (and why) + verification gate.

#### Variant 3: Interactive / Guarded
- **Focus**: Plan-first, open-ended explorer discovery before execution, strict human-in-the-loop checkpoints.
- **Best for**: Broad refactorings, unfamiliar areas, or tasks where explorer sub-agents should uncover opportunities we are not yet aware of before any files change.
- **Structure**: Target command (e.g. `/plan`) + open-ended discovery goals for parallel explorer sub-agents + mandated planning artifact + explicit stop gate (`Stop and wait for /proceed before editing any files`) + post-approval verification.

---

### Step 4: Output Presentation

Present the results in chat with clear visual separation. Do not dump commentary inside the code blocks.

- Mark exactly one variant **(Recommended)** in its heading. A bare `/proceed` runs that one.
- A reprint after follow-up input shows only the final variant, which becomes the one `/proceed` runs.

```markdown
### 1. Surgical / Fast (Lean Token Footprint)
*Best for quick, focused execution with minimal context overhead.*

```markdown
[Paste-ready prompt with concrete git branch/paths pre-filled]
```

---

### 2. Deep / Rigorous (Comprehensive & Defensive)
*Best for thorough review, strict adherence to architectural vocabulary, and edge-case prevention.*

```markdown
[Paste-ready prompt with full constraints, vocabulary rules, and verification criteria]
```

---

### 3. Interactive / Guarded (Plan-First with Stop Gates)
*Best for high-leverage decisions where you want to review the approach before any code changes.*

```markdown
[Paste-ready prompt with phased checkpoints and explicit confirmation gates]
```

---

### Key Injected Guardrails
- **Scope bounded to:** `refs/heads/...` or `merge-base..HEAD` (no whole-repo hallucination).
- **Enforced standards:** [e.g. `/codebase-design` vocabulary, `_modules/core.md` read-only gate].
- **Expected deliverable:** [e.g. HTML report in `$TMPDIR` / workspace artifact].
```

#### Closing line

End every response, including a reprint after follow-up answers, with exactly one line naming the waiting step and nothing after it:

```markdown
Next: paste a variant yourself, or `/proceed [variant N]` to run it here (default: the recommended variant).
```

---

## 3. Options & Flags

- `--file`: In addition to printing the variants in chat, write the full output to `<prefix>-prompt-<suffix>.md` at the workspace root.
