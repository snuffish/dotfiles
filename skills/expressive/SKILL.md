---
name: expressive
description: Transforms imperative, convoluted, nested, or procedural code into declarative, intent-revealing, domain-expressive code — replacing nested ternaries with lookup tables, decomposing nested conditionals, introducing domain predicates, and flattening control flow.
---

# Skill: `/expressive` — Make Code Expressive & Intent-Revealing

Elevates code readability and maintainability by refactoring low-level, nested, or procedural constructs into clean, self-documenting, domain-expressive logic.

---

## Operating Standards & Invariants

This skill adheres strictly to the **[core](../core/SKILL.md)** operating standards and the **[artifacts](../artifacts/SKILL.md)** delivery protocol.
- **Target Artifact** (when requested or providing an in-depth review): `<prefix>-expressive.md` at the **workspace root**.
- When asked directly on specific code lines (e.g. *"make lines 168–174 more expressive"*), propose and apply the clean refactoring directly to the file while explaining the transformation.

---

## 1. When to Use

Invoke this skill whenever:
- The user runs `/expressive` (or mentions "make it more expressive").
- The user asks to:
  - *"make this more expressive"*
  - *"refactor for expressiveness / intent"*
  - *"clean up this nested logic / ternary ladder"*
  - *"make this code read like domain English"*

---

## 2. Core Transformation Catalog

Apply these battle-tested patterns to transform code from mechanical execution to domain expression:

### Pattern 1: Declarative Lookup Tables over Nested Ternary Ladders
Nested ternaries create cognitive overload and obscure the underlying decision matrix.

**Before (Convoluted Nested Ternaries):**
```tsx
const helperText =
    customText ??
    (fileType === 'image'
        ? allowMultiple
            ? 'Select one or more images (PNG, JPG, WebP).'
            : 'Select a single image for your profile.'
        : allowMultiple
          ? 'Upload documents in PDF or DOCX format.'
          : 'Upload a single document in PDF format.');
```

**After (Expressive Declarative Dictionary):**
```tsx
const DEFAULT_HELPER_TEXT = {
    image: {
        single: 'Select a single image for your profile.',
        multiple: 'Select one or more images (PNG, JPG, WebP).',
    },
    document: {
        single: 'Upload a single document in PDF format.',
        multiple: 'Upload documents in PDF or DOCX format.',
    },
} as const;

const selectionMode = allowMultiple ? 'multiple' : 'single';
const helperText = customText ?? DEFAULT_HELPER_TEXT[fileType][selectionMode];
```
*Why it is better*: Separates text/configuration from execution logic, eliminates nesting, is easily extensible, and can be inspected at a glance.

---

### Pattern 2: Domain Predicates & Semantic Variables over Raw Booleans
Never make the reader mentally compute a multi-factor boolean check.

**Before (Cryptic Inline Conditions):**
```ts
if (order.status === 2 && !order.isLocked && user.permissions.includes('ORDER_EDIT') && order.items.length > 0) {
    proceed();
}
```

**After (Self-Documenting Intent):**
```ts
const isEditable = order.status === OrderStatus.Draft && !order.isLocked;
const hasEditPermission = user.hasPermission(Permission.OrderEdit);
const hasLineItems = order.items.length > 0;

if (isEditable && hasEditPermission && hasLineItems) {
    proceed();
}
```
*Or extracted as a pure domain function:*
```ts
if (canModifyOrder(order, user)) {
    proceed();
}
```

---

### Pattern 3: Guard Clauses over the "Pyramid of Doom"
Invert conditionals to exit early, keeping the primary "happy path" unindented.

**Before (Deeply Nested Indentation):**
```ts
function processInvoice(invoice: Invoice) {
    if (invoice != null) {
        if (invoice.isApproved) {
            if (!invoice.isPaid) {
                // Actual business work 4 levels deep
                sendPayment(invoice);
            } else {
                logger.warn('Already paid');
            }
        } else {
            logger.warn('Not approved');
        }
    }
}
```

**After (Flat Guard Clauses):**
```ts
function processInvoice(invoice: Invoice) {
    if (!invoice) return;
    if (!invoice.isApproved) return logger.warn('Not approved');
    if (invoice.isPaid) return logger.warn('Already paid');

    // Happy path sits cleanly at root indentation
    sendPayment(invoice);
}
```

---

### Pattern 4: Strategy Maps & Pattern Matching over Giant `switch` Blocks
Replace sprawling switch statements with mapped handlers or pattern matching.

**Before:**
```ts
function getBadgeColor(status: Status) {
    switch (status) {
        case Status.Active:
            return 'green';
        case Status.Pending:
            return 'amber';
        case Status.Failed:
            return 'red';
        default:
            return 'gray';
    }
}
```

**After:**
```ts
const STATUS_COLORS: Record<Status, BadgeColor> = {
    [Status.Active]: 'green',
    [Status.Pending]: 'amber',
    [Status.Failed]: 'red',
    [Status.Archived]: 'gray',
};

function getBadgeColor(status: Status): BadgeColor {
    return STATUS_COLORS[status] ?? 'gray';
}
```

---

### Pattern 5: Declarative Pipelines over Mutable Loops
Avoid manual index counters, temporary accumulator arrays, and flag variables.

**Before:**
```ts
const activeNames: string[] = [];
for (let i = 0; i < users.length; i++) {
    if (users[i].isActive && users[i].role === 'admin') {
        activeNames.push(users[i].name);
    }
}
```

**After:**
```ts
const activeAdminNames = users
    .filter((user) => user.isActive && user.role === Role.Admin)
    .map((user) => user.name);
```

---

## 3. Step-by-Step Refactoring Protocol

When prompted to make code more expressive:

1. **Identify the Core Decision or Intent**:
   - What business decision is this code actually making?
   - What are the dimensions or axes of variation (e.g. `mode`, `selectionKind`, `status`)?
2. **Select the Right Pattern**:
   - Nested ternaries / branching values → **Declarative Lookup Map (Pattern 1)**
   - Complex inline booleans → **Domain Predicates (Pattern 2)**
   - Nested `if` blocks → **Guard Clauses (Pattern 3)**
   - Multi-branch action dispatching → **Strategy / Dispatch Map (Pattern 4)**
3. **Verify Type Safety & Exhaustiveness**:
   - In TypeScript, use `as const` or typed `Record<Key, Value>` so the compiler enforces that all cases are covered.
   - In C#, use exhaustive pattern-matching expressions (`status switch { ... }`).
4. **Preserve Semantic Equivalence**:
   - Ensure null/undefined handling, edge cases, and defaults match the original logic 100%.

---

## 4. Verification & Validation

After refactoring for expressiveness:
1. Run linter and type-checker (`npm run lint`, `tsc -b`, or `dotnet build`).
2. Run existing unit and regression test suites to guarantee zero behavioral regressions.
