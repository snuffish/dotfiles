---
name: what-am-I-missing
description: Universal blind spot and critical omission detector. Discovers the single most critical hidden assumption, edge case, failure mode, or architectural implication across any software project, tech stack, or situation. Triggered by /what-am-I-missing or requests like "what am I missing here?"
---

# Skill: `/what-am-I-missing` — Blind Spot & Critical Omission Detector

Identifies the single most important blind spot, hidden invariant, or architectural risk in the user's current situation. Answers: *"What is the most important thing I'm missing here?"* with technical depth, contextual awareness, and zero fluff.

Applicable to **any software project, language, framework, or technology stack**.

---

## 1. When to Use

Invoke this skill whenever:
- The user issues `/what-am-I-missing`.
- The user asks: *"What am I missing here?"*, *"What's the most important thing I overlooked?"*, *"What are my blind spots?"*, *"Is there any hidden trap here?"*, or *"Sanity check this approach"*.
- A feature, bug fix, or architecture change appears complete locally, but needs a rigorous systems-level audit for subtle failure modes before shipping.

---

## 2. Universal Investigation Protocol

When evaluating the user's current task, active file, recent diff, or conversation context, audit the situation across these **7 Universal Blindspot Vectors**:

### 1. 💾 Persistence, Transactions & Data Integrity
- **Database Engine Invariants:** Are there constraints or engine rules (e.g. foreign keys, unique indexes, cascading delete restrictions, table locks, trigger side-effects, temporal/versioned tables) that differ from in-memory behavior?
- **Atomicity & Partial Failures:** If step 2 of an operation fails, does step 1 leave orphaned, corrupted, or inconsistent data? Are transactions or compensating operations required?
- **Schema & Migration Safety:** Does this change break existing records, require backward-compatible data backfills, or introduce schema migration locks?

### 2. ⚡ Concurrency, State Drift & Lifecycles
- **Race Conditions & Lost Updates:** What happens if two requests modify the same resource concurrently? Are optimistic concurrency tokens, row locks, or atomic operations needed?
- **Cache Synchronization:** If this data is mutated, are in-memory caches, distributed caches (Redis), or query caches properly invalidated?
- **Lifecycle & Invariant States:** What happens if the target entity is already archived, cancelled, soft-deleted, suspended, or completed? Are state transitions guarded at all entry points?

### 3. 🌐 Boundaries, Contracts & Blast Radius
- **Upstream & Downstream Consumers:** Who else calls or consumes this? Will modifying a DTO, model, event, or route break background jobs, CLI tools, webhooks, or frontends?
- **Polymorphism & Variant Coverage:** If working with an abstract class, interface, or union/discriminated type, does the logic hold true for **all** concrete variants, or only the one actively being tested?
- **Third-Party Failures:** What happens if an external API, network call, or service times out, rate-limits, or returns an unexpected error payload?

### 4. 🔒 Security, Authorization & Tenancy
- **Tenant & Row Isolation:** Is data scoped to the current user, tenant, or organization? Is there an IDOR (Insecure Direct Object Reference) risk where a caller can pass an arbitrary ID?
- **Privilege & Permission Revocation:** Are permissions checked at the data-access level or only in the UI? Can a lower-privileged role trigger this path?
- **Sensitive Data & Auditability:** Are secrets, PII, or tokens logged or leaked in error responses? Is the mutation traceable to an actor in audit history?

### 5. 🚀 Operational Realities & Performance
- **Hidden Scale Traps:** Is there an accidental $O(N)$ database query (N+1), unbounded collection load, or unindexed search that works with 5 test records but chokes in production?
- **Resource Leaks:** Are connections, file handles, cancellation tokens, streams, or timers properly disposed of?
- **Observability:** If this fails in production at 3 AM, will logs, metrics, or traces contain sufficient correlation context to diagnose the problem quickly?

### 6. 🧪 Testing Realities & False Confidence
- **Mocks That Lie:** Do tests pass only because an in-memory mock or stub ignores a strict database/network constraint that exists in real environments?
- **Negative & Asymmetric Paths:** Are failure paths, validation rejections, unauthorized attempts, and conflict states tested with the same rigor as the happy path?
- **Idempotency:** What happens if a webhook, message queue consumer, or client retries the exact same request twice?

### 7. 🧩 Leaky Abstractions & Design Consistency
- **Developer Traps:** Does this solution require future developers to remember a subtle convention (e.g. manually preloading a relationship, calling a specific setup method) or is it enforced automatically by the architecture/type system?
- **Single Source of Truth:** Is domain logic duplicated across controllers, handlers, validators, and client code, risking divergence over time?

---

## 3. Output Format & Artifact Deliverable

1. **Write the Analysis Artifact**:
   - Always write a dedicated markdown artifact, `what_am_i_missing.md`, at the **workspace
     root**. That location is what makes the link clickable, so do not put it elsewhere.
   - The artifact must follow this high-impact structure:

```markdown
# 🎯 The #1 Most Important Thing You Are Missing

> **[One bold, unambiguous sentence identifying the primary blind spot]**

[Direct technical explanation: What is the unstated assumption or hidden invariant, why does it exist, and why is it easy to overlook?]

---

## 💥 The Blast Radius / Failure Scenario
- **Trigger:** [The exact condition, user action, edge case, or production event that triggers the failure]
- **Impact:** [The precise exception, data corruption, security vulnerability, or performance cliff that occurs]
- **Why it went unnoticed:** [Why existing tests, mocks, or local development didn't catch it]

---

## 🔍 Secondary Blind Spots & Nuances
1. **[Secondary Risk 1]:** [Concise explanation of related implication]
2. **[Secondary Risk 2]:** [Concise explanation of related implication]

---

## 🛠️ Actionable Recommendation
1. **Immediate Fix:** [Concrete step to eliminate the #1 blind spot]
2. **Structural Prevention:** [How to make this impossible to get wrong in the future via types, architecture, or automated tests]

---

## 📄 Relevant References
- 📄 [Active Plan / Relevant File](path/to/relevant/file.ts#L10)
```

2. **Report Back in Chat**:
   - In the conversation response, provide:
     - The bold **#1 Most Important Thing You Are Missing** takeaway sentence.
     - A clickable link to open the artifact in the IDE:
       `📄 [what_am_i_missing.md](what_am_i_missing.md)`
     - Anchor links to key sections, as line numbers from `grep -n` (placeholders here):
       - 💥 [Blast Radius / Failure Scenario](what_am_i_missing.md#L18)
       - 🔍 [Secondary Blind Spots & Nuances](what_am_i_missing.md#L26)
       - 🛠️ [Actionable Recommendation](what_am_i_missing.md#L33)

> [!IMPORTANT]
> **Link format — links only resolve one way.** Use a **workspace-relative** path with no
> scheme; an absolute `file:///...` URI renders as dead text, as does any path outside the
> workspace root. Section anchors must be **line numbers** (`#L42`), never heading slugs
> (`#design-rationale` does not work). Read the numbers off the file *after* writing it:
> `grep -n '^#\{1,3\} ' <artifact>.md`, and re-read them if you edit it afterwards.

     - A concise overview of the core failure scenario and actionable fix.
