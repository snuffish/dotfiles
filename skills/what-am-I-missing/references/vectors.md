# Universal Blindspot Vectors

Audit the user's current task, active file, recent diff, plan, or conversation context across these **7 Universal Blindspot Vectors**:

### 1. 💾 Persistence, Transactions & Data Integrity

- **Database Engine Invariants:** Are there constraints or engine rules (e.g. foreign keys, unique indexes, cascading delete restrictions, table locks, trigger side-effects, temporal/versioned tables) that differ from in-memory behavior?
- **Atomicity & Partial Failures:** If step 2 of an operation fails, does step 1 leave orphaned, corrupted, or inconsistent data? Are transactions or compensating operations required?
- **Schema & Migration Safety:** Does this change break existing records, require backward-compatible data backfills, or introduce schema migration locks?
- **State that outlives the request:** Persisted or restored data, resumed runs, retries, background jobs, and data created before this change (backfills, old rows, cached clients).

### 2. ⚡ Concurrency, State Drift & Lifecycles

- **Race Conditions & Lost Updates:** What happens if two requests, two users, two tabs, two jobs, or two of the plan's own new features modify the same resource concurrently? Are optimistic concurrency tokens, row locks, or atomic operations needed?
- **Cache Synchronization:** If this data is mutated, are in-memory caches, distributed caches (Redis), or query caches properly invalidated?
- **Lifecycle & Invariant States:** What happens if the target entity is already archived, cancelled, soft-deleted, suspended, or completed? Are state transitions guarded at all entry points?

### 3. 🌐 Boundaries, Contracts & Blast Radius

- **Upstream & Downstream Consumers:** Who else calls or consumes this? Will modifying a DTO, model, event, or route break background jobs, CLI tools, webhooks, or frontends?
- **Contract consumers a sibling feature never had:** A new enum member, permission, DTO field, or event that other code switches on.
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
- **The library's real behaviour, not its docs:** When a design or plan leans on a framework feature (ORM behaviour, a job scheduler, a realtime hub, a client cache, a third-party SDK), read the installed source under `bin/`, `obj/`, `node_modules/`, `vendor/` or the package cache for the path the plan depends on.
- **Negative & Asymmetric Paths:** Are failure paths, validation rejections, unauthorized attempts, and conflict states tested with the same rigor as the happy path?
- **Idempotency:** What happens if a webhook, message queue consumer, or client retries the exact same request twice?

### 7. 🧩 Leaky Abstractions & Design Consistency

- **Developer Traps:** Does this solution require future developers to remember a subtle convention (e.g. manually preloading a relationship, calling a specific setup method) or is it enforced automatically by the architecture/type system?
- **Single Source of Truth:** Is domain logic duplicated across controllers, handlers, validators, and client code, risking divergence over time?
- **Project profile blind-spot vectors:** Whatever the active project profile lists under its own blind-spot checks.
