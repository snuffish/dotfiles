# Plan Review Protocol (`--review` / Case D)

Used by `/plan --review [target]` (Case D) and `/plan` self-review (Case B step 4).

## Case D Steps

1. **Locate the plan:** the argument names it (`/plan --review 18176`, `/plan --review begar-prefix`); otherwise follow _Case A_ step 1 (`artifact-protocol` › _Claim_ › _Readers & family selection_). For a proposal that is not a plan artifact (a branch, PR or design doc), locate its files or work items.
2. **Read the project's rules** (`core` › _Precedence_): the workspace rulebooks, the project-scoped References for the layers the plan touches, and the base profile when one matches the workspace (`project-profile` › _Discovery_). Its _References per layer_, _Contract touchpoints_ and _Plan-review checks_ fields name the concrete conventions to check.
3. **Evaluate against five pillars** (_Case D step 3_), plus every item of the profile's _Plan-review checks_ under the pillar it names. Run the pillars as `fan-out` › _Review lenses_: each lens brief carries its pillars' bullets below and the _Plan-review checks_ filed under them. Below the lenses' inline threshold, evaluate them here in the main context:
   1. **Architecture & domain modeling**
      - Aggregate and module boundaries respected; domain logic in the domain layer, not endpoints, controllers or DTOs.
      - Follows the nearest existing feature of the same kind (profile's _Sibling chain_), or says why not.
      - No antipatterns: inheritance where composition fits, bypassing an entity's invariants.
   2. **Project conventions**
      - Every new endpoint, query, component, form and test follows its layer's References and the rulebook's language idioms (e.g. `modern-csharp`).
      - New abstractions justified: an interface for real I/O or a library boundary, not per class.
      - A cross-repo contract (profile's _Contract touchpoints_) is updated on both sides.
      - Follows `SKILL.md` › _Style_: _Open Questions_ not last, or a question without **Rec:**, is 🟡; prose instead of fragments is 🟢.
   3. **Security, authorization & access rules**
      - Every new endpoint or write path carries the project's authorization; data scoped to the caller (tenant, owner, role).
      - No privilege escalation or unprotected write paths.
   4. **Edge cases, resilience & invariants**
      - Every claim the plan builds on is checked in the code, not taken on trust. This covers a type or interface exposing what a change needs (e.g. an extension method that only accepts `DbSet<T>`, not `IQueryable<T>`) and the schema a test database actually has (tables a migration keeps can be missing from a database built from the current model). A claim that turns out wrong is 🔴 when the change can't compile or the test can't run.
      - Validation failures handled; messages follow the project's language and locale.
      - Constraints, cascades and foreign keys satisfied; migration safe for existing data.
      - Cancellation tokens threaded through async calls.
      - Multi-table mutations transactional; retried requests idempotent.
   5. **Verification & testing**
      - Concrete automated test strategy in the project's framework and fixtures.
      - Covers authorized, forbidden and unauthenticated paths, not only the happy path.
4. **Report** (`--review` only; skipped during Case B self-review): render the plan's link block (`SKILL.md` › _Link block_) with real line numbers and a one-sentence summary after each section link (what the context decides, what the changes touch, how it is verified), then:

   ```markdown
   # 🔍 Plan Review: [Feature / Topic Name]

   ## 🚦 Verdict

   > **[READY FOR /proceed | NEEDS REVISION | BLOCKED]**
   > _One-sentence summary of overall readiness._

   ## 💡 Key Strengths

   - What the plan gets right (architecture, conventions, scoping).

   ## ⚠️ Findings & Concerns

   ### 🔴 Critical (must resolve before proceeding)

   - Breaks the build, violates security or authorization, or fails at runtime.

   ### 🟡 Important (should address or clarify)

   - Convention deviations, performance risks, missing edge cases, test gaps.

   ### 🟢 Minor / Suggestions

   - Naming, documentation clarity, small cleanup.

   ## 📋 Recommended Action Items

   1. [Actionable change to the plan]

   ## 🔒 Next Step Gate

   > [!IMPORTANT]
   > **Execution is locked.** No code changes or commands have been executed.
   > Wait for the user to open `core` › _The `/proceed` gate_ before implementing.
   ```
