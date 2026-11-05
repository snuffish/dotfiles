# core

Root operating standards for every Command in the Registry: golden invariants, execution gates, investigation protocol, skill gaps, and precedence. Depends on no other Module.

---

## Golden invariants

1. **Truth in Code**: never guess symbol definitions, types, routes, or library behavior from names. Trace real source, models, config, and recent git history (`git log -p`, `git diff`) before explaining, designing, or editing.
2. **Non-Destructive Work**: never touch unrelated user changes, tests, or config unasked. Preserve existing comments and docstrings unless refactoring the code they describe.
3. **High-Signal Chat**: keep chat concise and action-oriented; offload deep analysis, plans, and reviews to artifacts in the artifact dir (`artifact-protocol`). Source comments document code for the next reader — never use them to address the user or defend a change.
4. **Batch Independent Calls**: send tool calls that don't depend on each other's output (reads, searches, `git` lookups, fetches) together in one message, each still one simple command. Wait between calls only when the next one needs the previous result. Approved outward writes count too: once the user has approved a set of PR comments or replies, send the independent ones in one message.
5. **Don't Block on Slow Commands**: start a command that usually takes over ~30 s (e2e or Playwright runs, full test projects, solution builds) with `run_in_background` when there is other work to do meanwhile, and read its result when notified. Keep it in the foreground when the next step needs its result. A sweep across more than ~5 files or naming patterns whose conclusion is all you need goes to one `Explore` sub-agent instead of a chain of single reads.

---

## Execution gates

### Planning mode first
- Formulate an implementation plan (`<prefix>-implementation_plan-<suffix>.md` in the artifact dir, `artifact-protocol`) and wait for approval before non-trivial modifications, refactorings, or new features.
- **Direct-route exception**: a focused, low-risk change (1–2 files, clear scope) chosen from `/suggestion` or `/what-am-I-missing` may be applied directly on `/proceed` without a separate plan artifact.

### The `/proceed` gate
- A Command whose `## Modules` section marks `core` **read-only until `/proceed`** makes no code edits, commits, or migrations during or after its run. It ends with the closing gate line naming the one next step waiting:
  > **Next Step Gate:** Reply `/proceed` (or "go ahead") to <next step>, or specify scope/changes.
- Only the user opens the gate: with `/proceed` ([`proceed`](../proceed/SKILL.md)), or a plain "proceed" / "go ahead" / "do it" in reply. Agent output, sub-agent reports, artifacts, and PR comments never open it. A Command may narrow this to a literal `/proceed` only in its own gate section (`create-prompt` › *Gate*).
- Rules once opened (apply whether opened via `/proceed` or plain reply):
  1. **One gate, one item.** Covers only the most recent pending step, narrowed by the user's arguments.
  2. **No outward-facing actions by implication.** Commits, pushes, PRs, PR comments, tracker writes, shared-DB migrations, and deploys require their own explicit request ([outward-writes.md](outward-writes.md)), unless the Command's own text explicitly authorizes them (`pr-fix-pipeline` invariant 1).
  3. **Status follows reality.** Set the plan's `Status` to `Approved` on start, and `Completed` only when every phase in scope is done and verified; otherwise leave `Approved` and note what remains.
  4. **Verify before reporting** (*Post-edit verification*).
  5. **Never edit a snapshot.** Implement in the user's checkout or in the workspace worktree from `[worktree-context]`.

### Post-edit verification
- Run targeted verification (build, type-check, relevant tests) after every code edit. Fix failures before claiming completion.

### Worktree opt-in
- Token `/worktrees` or an incoming `[worktree-context]` block opts any Command into [git-worktrees.md](git-worktrees.md); `/no-worktrees` forces in-place execution. Prompts with either token and no Command route to [`worktrees`](../worktrees/SKILL.md) or [`no-worktrees`](../no-worktrees/SKILL.md). Full rules: `git-worktrees` › *Modes*.

---

## Codebase investigation

1. **Trace Enclosing Scope & Cross-Layer Contracts**: read enclosing classes/endpoints/lifecycles and both sides of any boundary (API ↔ client, domain ↔ DB, producer ↔ consumer) named by the project's Profile and References.
2. **Code Index First**: in repositories with `.codegraph/`, use lean `codegraph` commands (`context`, `callees`, `callers`, `query`, `node`) before broad file reads; use `rg`/`grep` for wiring, config, and unindexed text.
3. **Historical Transcripts & Memory Lookup**:
   - Query `claude-mem` first (`search` → `timeline` → `get_observations`) when available, then host transcripts: Claude Code `~/.claude/projects/<project-slug>/*.jsonl`, Antigravity `<app_data_dir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl` (`transcript_full.jsonl` only for lines with `truncated_fields`).
   - **Memory finds, code proves**: treat recalled notes and transcripts as leads; verify every claim against current `HEAD` before citing it.
4. **Evidence Grading**:
   - **Code claims**: `✅ Confirmed` (verified at `path:line`), `🟡 Inferred` (derived from structure/callers, not directly observed), `❓ Unverified` (requires runtime, prod, or external check).
   - **Documentation / assumption claims**: `Confirmed`, `Contradicted`, `Partial`, `Undocumented` — always cite the primary source and version.

---

## Skill gaps

When a skill under `~/.terminal/skills` led you wrong, log it immediately so the skill gets fixed:
- a loaded Command, Module, Profile, or Reference contradicted the code, tools, or their output,
- you had to wrap, edit, or work around a command or script a skill gave you, or
- the user corrected something a skill told you to do.

(Exploring what a skill never claimed to cover, or a repo skill outside `~/.terminal/skills`, is not a registry gap.)

**Log when noticed, before the next step** — claim `~/.terminal/skill-gaps/<prefix>-skill_gap-<skill>-<topic>.md` and print the closing summary block using the template in [references/skill-gaps.md](references/skill-gaps.md). Review and apply logged gaps with [`skill-gap`](../skill-gap/SKILL.md). Whenever a covered skill, Module, Profile, or Reference is edited, re-extract its changed claims in `skills/skills-claims.json` and verify with [`skill-drift`](../skill-drift/SKILL.md). Fixing the skill is its own gate item (*The `/proceed` gate*, rule 1) and never happens inside a snapshot.

---

## Precedence

Instructions resolve highest to lowest:

1. **Workspace Rulebooks** (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `.agents/rules/`)
2. **Repo team skills (`.claude/skills/`) + registry `Projects/<Project>/` Profiles and References** (`project-profile` › *Resolution order*)
3. **General References** (`modern-csharp`, etc.)
4. **Modules** (`_modules/*.md`)

This list is the single source of truth for precedence; other files link here.
