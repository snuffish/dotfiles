# Core Transformation Catalog

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
    if (!invoice.isApproved) {
        logger.warn('Not approved');
        return;
    }
    if (invoice.isPaid) {
        logger.warn('Already paid');
        return;
    }

    // Happy path sits cleanly at root indentation
    sendPayment(invoice);
}
```

Write `{ action(); return; }` rather than `return action();` when `action` returns `void` — the shorthand reads as if a value were being returned.

**Three refinements that come up often:**

- **Hoist the shared precondition.** When every branch only does something under the same condition, test it once at the top instead of inside each branch.

  ```ts
  // Before: the "anything changed?" check is buried in one branch and implied in the other
  if (!item.isTracked) {
      if (nameChanged || priceChanged) startTracking(item);
      return;
  }
  if (priceChanged && item.isPublished) notifySubscribers(item);

  // After
  if (!nameChanged && !priceChanged) return;
  if (!item.isTracked) {
      startTracking(item);
      return;
  }
  if (priceChanged && item.isPublished) notifySubscribers(item);
  ```

- **Don't re-test the last member of a closed set.** Once earlier guards have ruled out every other value of a union or enum, the remaining branch is unconditional. Return early on the earlier cases and drop the redundant `x === Last &&` from the last one.

  ```ts
  // Before — status is 'approved' | 'rejected' here
  if (status === 'rejected' && !comment.trim()) addIssue('A rejection needs a comment');
  if (status === 'approved') validateAppliedValue(value);

  // After
  if (status === 'approved') {
      validateAppliedValue(value);
      return;
  }
  if (!comment.trim()) addIssue('A rejection needs a comment');
  ```

  Only do this when the set really is closed (a string-literal union, an enum, a discriminated union). For an open `string` or `number`, keep the explicit test.

- **Order guards from cheapest and most common to rarest.** Null checks and "nothing to do" exits first, permission and state checks next, the happy path last.

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
    return STATUS_COLORS[status];
}
```

This assumes `Status` has exactly these four members; the old `default:` covered `Archived`. The exhaustive `Record` makes the compiler demand a color for every new member, which `default:` silently swallowed. Do not add `?? 'gray'`: under the `Record` type it is dead code, and it would hide a missing key at runtime. If some members really should fall back, say so in the type: `Partial<Record<Status, BadgeColor>>` plus an explicit `?? 'gray'`.

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

### Pattern 6: Early-Return Subcomponents over `&&` Chains in Markup
Markup (JSX, Razor, templates) can't early-return inline, so a "one of these renders" decision ends up as a run of sibling `{status === 'a' && …}{status === 'b' && …}` blocks. The reader has to check every condition to learn that only one survives. Move the run into a small component in the same file with one `if … return` per case and a final `return null`.

**Before:**
```tsx
<Card>
    <OrderHeader order={order} />
    {status === 'pending' && errors?.eta && (
        <Text color='red'>{errors.eta.message}</Text>
    )}
    {status === 'shipped' && !order.trackingId && (
        <Text color='red'>Shipped orders need a tracking id.</Text>
    )}
    {status === 'cancelled' && (
        <Flex direction='column' gap='1'>
            <Controlled.TextArea control={control} name={`orders.${index}.cancelReason`} />
            {errors?.cancelReason && <Text color='red'>{errors.cancelReason.message}</Text>}
        </Flex>
    )}
</Card>
```

**After:**
```tsx
<Card>
    <OrderHeader order={order} />
    <OrderCardFooter index={index} order={order} status={status} control={control} errors={errors} />
</Card>

type OrderCardFooterProps = Pick<OrderCardProps, 'index' | 'order' | 'status' | 'control' | 'errors'>;

/** Status-specific content below the header: the cancel reason, or the row's validation error. */
function OrderCardFooter({ index, order, status, control, errors }: OrderCardFooterProps) {
    if (status === 'cancelled') {
        return (
            <Flex direction='column' gap='1'>
                <Controlled.TextArea control={control} name={`orders.${index}.cancelReason`} />
                {errors?.cancelReason && <Text color='red'>{errors.cancelReason.message}</Text>}
            </Flex>
        );
    }
    if (status === 'shipped' && !order.trackingId) {
        return <Text color='red'>Shipped orders need a tracking id.</Text>;
    }
    if (status === 'pending' && errors?.eta) {
        return <Text color='red'>{errors.eta.message}</Text>;
    }
    return null;
}
```
*Why it is better*: one branch per case, read top to bottom; the parent's markup shrinks to a single named element; and the component's doc comment states what the region is *for*, which the `&&` chain never did.

**How to do it well:**
- Derive the props with `Pick<ParentProps, …>` (and `& { … }` for anything extra) so they can't drift from the parent.
- Put the unconditional case first, then the conditional ones, then `return null`.
- Keep it in the same file and unexported unless another file needs it. It's an extraction, not a new public component.
- Name it for the region it fills (`…Footer`, `…Status`, `…Actions`), not for the condition it tests.
- C# equivalent: a `switch` expression or pattern-matched method on the discriminator, returning the fragment or `null`.

**When *not* to apply it:**
- **The blocks aren't mutually exclusive.** Two badges that can both show, or a hint plus an error. Early returns would silently drop one. Verify exclusivity before merging; keep independent `&&` toggles inline.
- **Extraction would need a long prop list.** Roughly more than six props, or handlers that close over parent state. The new component would cost more than the conditionals it replaces.
- **A single `&&` toggle or a plain `cond ? <A /> : <B />`.** Already as short as it gets.
- **The component already early-returns** (loading → empty → main). Leave it.

---
