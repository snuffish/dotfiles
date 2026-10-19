---
name: frontend-rtk-query
description: "[Project: GR.PRIIS.Frontend] RTK Query patterns for GR.PRIIS.Frontend — endpoint builders in src/store/api/endpoint-builders/{domain}/, Builder type from api/base.ts, per-domain api.ts registration via injectEndpoints (each API domain exports its own hooks; api/index.ts is a barrel), per-domain tags.ts with change sets (<domain>Changed) and published subscriptions (<domain>Subscriptions) for cross-domain cache effects, providesTags/invalidatesTags. Load when adding or modifying API calls, endpoint builders, or cache invalidation. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# RTK Query — Project Patterns

All API calls in this project go through RTK Query. There is no direct `fetch` or `axios` — every backend call is defined as an endpoint builder and consumed via a typed hook.

---

## 1. Endpoint Builder Structure

Endpoint builders are modular functions organized by domain under `source/priis-web/src/store/api/endpoint-builders/`:

```
src/store/api/
  base.ts                    ← createApi (no endpoints), base query, tagTypes, Builder, TypedEndpoint
  index.ts                   ← barrel only: `base`, `shared` and one `export *` line per API domain
  tags.ts                    ← TagDescription + tagOf helper only
  endpoint-builders/
    shared/index.ts          ← shared DTOs (Id, Name, PaginatedRequest, PaginatedListResponse, Breadcrumbs, …)
    suppliers/index.ts       ← builder functions + request/response types
    suppliers/api.ts         ← injectEndpoints registration + hook exports for this domain
    suppliers/tags.ts        ← suppliersTags (domain-private), suppliersChanged(), optional suppliersSubscriptions
    ...
```

Each `index.ts` exports named endpoint builder functions:

```typescript
// source/priis-web/src/store/api/endpoint-builders/supplier-notes/index.ts
import { Guid } from '~/types/guid';
import { Builder } from '../../base';               // Builder type
import { supplierNotesTags } from './tags';         // this domain's tags (§4)

export type SupplierNote = {
    id: Guid;
    content: string;
    createdAt: string;
    createdByName: string;
};

export type ListSupplierNotesResponse = {
    items: SupplierNote[];
};

export type CreateSupplierNoteRequest = {
    supplierId: Guid;
    content: string;
};

export const listSupplierNotes = (builder: Builder) =>
    builder.query<ListSupplierNotesResponse, { supplierId: Guid }>({
        query: ({ supplierId }) => ({
            method: 'get',
            url: `suppliers/${supplierId}/notes`,
        }),
        providesTags: (_result, _error, { supplierId }) => [supplierNotesTags.listBySupplier(supplierId)],
    });

export const createSupplierNote = (builder: Builder) =>
    builder.mutation<{ id: Guid }, CreateSupplierNoteRequest>({
        query: ({ supplierId, content }) => ({
            method: 'post',
            url: `suppliers/${supplierId}/notes`,
            body: { content },
        }),
        invalidatesTags: (_result, _error, { supplierId }) => [supplierNotesTags.listBySupplier(supplierId)],
    });
```

---

## 2. Query vs Mutation

| Use | When |
|-----|------|
| `builder.query<TRes, TArg>` | GET requests, read operations |
| `builder.mutation<TRes, TArg>` | POST, PUT, PATCH, DELETE |

Query hooks: `useXxxQuery(arg)`, `useLazyXxxQuery()`
Mutation hooks: `useXxxMutation()` (returns `[trigger, { data, error, isLoading }]`)

---

## 3. Tags — `providesTags` and `invalidatesTags`

Each API domain owns its tags in `endpoint-builders/<domain>/tags.ts` (see `docs/adr/0001-api-domain-change-sets.md` and `GLOSSARY.md` in the repo). Never hardcode tag strings.

```typescript
// endpoint-builders/suppliers/tags.ts
import { TagDescription, tagOf } from '../../tags';

export const suppliersTags = {
    all: tagOf('Suppliers'),
    list: tagOf('Suppliers', 'List'),
    details: tagOf('Suppliers', 'Details'),
    operationsTab: tagOf('Suppliers', 'DetailsOperationsTab'),
} as const;

/** Every cached read of this API domain; announced by mutations in other domains that write its data. */
export const suppliersChanged = (): TagDescription[] => [tagOf('Suppliers')];

/** Only when another domain's query shows this domain's data. */
export const suppliersSubscriptions = { list: suppliersTags.list } as const;
```

**The writes / reads rule:**

```typescript
// Own domain — invalidate precisely with this domain's tags
invalidatesTags: (_result, _error, { id }) => [suppliersTags.list, suppliersTags.details],

// Writing ANOTHER domain's data (status cascades, apply-on-close, …) — announce its change set
invalidatesTags: (_result, _error, request) => [
    controlTicketsTags.detail(request.id),
    ...operationsChanged(),   // from '../operations/tags'
    ...contractsChanged(),
],

// A query that SHOWS another domain's data — provide that domain's published subscription
providesTags: [dashboardTags.tickets, matchingSubscriptions.list],
```

- `no-restricted-imports` allows importing only `*Changed` / `*Subscriptions` from another domain's `tags.ts` — never its raw `<x>Tags`.
- A change set is the domain's whole tag type(s), so every mounted query of that domain refetches — intended; add a finer change set only for a measured cost.
- A new cross-domain reader needs the read in the owning domain's `*Subscriptions`; add it there (the owning domain's own mutations already invalidate it).
- Outside `endpoint-builders` (listeners, components) use `dispatch(priisApi.util.invalidateTags(xChanged()))`.

**Every mutation must have `invalidatesTags`** — omitting it causes stale UI after mutations.

**Check both sides of every cross-domain effect.** Before finishing an endpoint builder, answer two questions:

1. Does my new query show another domain's data? Provide that domain's subscription. A control-ticket profile that shows the operation's status provides `operationsSubscriptions.details`, so `changeOperationStatus`, `cascadeOperationStatus` and `changeContractStatus` refresh it without naming control tickets. If the read is not published yet, add it to the owning domain's `*Subscriptions`.
2. Does my new mutation write another domain's data? Announce that domain's change set. Closing a control ticket that applies a status to the operation and its contracts spreads `operationsChanged()` and `contractsChanged()`. A mutation that only *reads* another domain (a guard, a count) announces nothing for it.

A query whose data changes through admin screens needs its own published read (`usersSubscriptions.devPersonas`) so those mutations can refresh it. Reviews find a missing side in almost every PR that adds a domain.

---

## 4. Adding a New Tag

**Step 1** — add the type string to `tagTypes` in `source/priis-web/src/store/api/base.ts`:
```typescript
const tagTypes = [
    'AuthExpires',
    'Suppliers',
    // ...existing...
    'SupplierNotes',   // ← add here
] as const;
```

**Step 2** — add the tag constants to the owning domain's `endpoint-builders/<domain>/tags.ts`, and add the new type to that domain's `<domain>Changed()`. A new domain gets its own file:
```typescript
// source/priis-web/src/store/api/endpoint-builders/supplier-notes/tags.ts
import { Guid } from '~/types/guid';
import { TagDescription, tagOf } from '../../tags';

export const supplierNotesTags = {
    all: tagOf('SupplierNotes'),
    listBySupplier: (supplierId: Guid) => tagOf('SupplierNotes', `List-${supplierId}`),
} as const;

/** Every cached read of this API domain; announced by mutations in other domains that write its data. */
export const supplierNotesChanged = (): TagDescription[] => [tagOf('SupplierNotes')];
```

---

## 5. Registering in the domain's `api.ts`

After defining the builder function, register it in the **same domain's** `api.ts` and export its hooks there. Never edit `api/index.ts` for a new endpoint — it only changes when a new API domain (folder) is added, as one `export * from './endpoint-builders/<domain>/api';` line.

```typescript
// source/priis-web/src/store/api/endpoint-builders/supplier-notes/api.ts
import { createSupplierNote, listSupplierNotes } from '.';
import priisApi from '../../base';

export const supplierNotesApi = priisApi.injectEndpoints({
    endpoints: (builder) => ({
        listSupplierNotes: listSupplierNotes(builder),
        createSupplierNote: createSupplierNote(builder),
    }),
});

export const { useListSupplierNotesQuery, useCreateSupplierNoteMutation } = supplierNotesApi;
```

The domain api is named `<camelCasedFolder>Api`. Endpoint names must be unique across all domains (`injectEndpoints` ignores a duplicate name).

The one exception is `dev/index.ts`: the dev-only endpoints inject themselves as `devApi` in the builder module and are not exported from the barrel; import them from `endpoint-builders/dev` directly.

**Referencing an endpoint object** (modal `preloadData`, `GlobalModal` mutation slots, `paginated-table`) or a typed util goes through the domain api — `priisApi` from `base.ts` has no endpoints in its type:

```typescript
import { operationsApi } from '~api';

preloadData={{ endpoint: operationsApi.endpoints.getOperationProfile, request: { operationId } }}
dispatch(matchingApi.util.updateQueryData('getMatchingSelectionProcess', { id }, (draft) => { /* … */ }));
dispatch(priisApi.util.invalidateTags(notificationsChanged())); // untyped utils may stay on priisApi
```

---

## 6. Hook Usage in Components

```typescript
import { useListSupplierNotesQuery, useCreateSupplierNoteMutation } from '~api';

// Query hook
const { data, isLoading, isError } = useListSupplierNotesQuery({ supplierId });

// Mutation hook
const [createNote, { isLoading: isSaving, error }] = useCreateSupplierNoteMutation();

// Calling a mutation with .unwrap() for error handling
createNote({ supplierId, content: formData.content })
    .unwrap()
    .then(() => onSuccess())
    .catch((err) => console.error(err));  // or use the error state
```

**Conditional/deferred queries:**
```typescript
// Skip until supplierId is available
const { data } = useListSupplierNotesQuery({ supplierId }, { skip: !supplierId });

// Lazy query (triggered manually)
const [triggerSearch, { data }] = useLazyListSupplierNotesQuery();
triggerSearch({ supplierId });
```

---

## 7. Common Options

```typescript
builder.query<TRes, TArg>({
    query: ...,
    keepUnusedDataFor: 600,         // seconds to keep cache (default: 10)
    refetchOnMountOrArgChange: 30,  // refetch if older than N seconds
    providesTags: [...],
});
```

Global defaults (from `createApi` config): `keepUnusedDataFor: 10`, `refetchOnMountOrArgChange: 30`.

---

## 8. Anti-Patterns

```
❌ fetch() or axios.get() in components — use RTK Query hooks
❌ Mutations without invalidatesTags — stale UI after save
❌ A new query that shows another domain's data without providing that domain's <domain>Subscriptions entry (see §3)
❌ A request body built by spreading the request object (`...body`) — build it field by field with `satisfies ApiXRequest`, and never send an id in both the route and the body
❌ Hardcoded tag strings like ['Suppliers'] — use the domain's <domain>Tags / <domain>Changed()
❌ Naming another domain's individual tags (invalidate or provide) — use <domain>Changed() / <domain>Subscriptions
❌ A new tag type missing from its domain's <domain>Changed()
❌ Duplicating an endpoint that already exists in another domain builder
❌ Adding endpoints or hooks to api/index.ts — register them in the domain's api.ts
❌ priisApi.endpoints.X / priisApi.useXQuery — use <domain>Api.endpoints.X or the exported hook
❌ Importing from '../..' or '~api' inside endpoint-builders — import ../../base, ../shared or a sibling domain (the barrel imports every domain, so it creates a cycle)
❌ Skipping the tagTypes array update when adding a new tag type
```
