---
name: frontend-rtk-query
description: "[Project: GR.PRIIS.Frontend] RTK Query patterns for GR.PRIIS.Frontend — endpoint builders in src/store/api/endpoint-builders/{domain}/, Builder type, Tags object from tags.ts, providesTags/invalidatesTags, hook exports from api/index.ts. Load when adding or modifying API calls, endpoint builders, or cache invalidation. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# RTK Query — Project Patterns

All API calls in this project go through RTK Query. There is no direct `fetch` or `axios` — every backend call is defined as an endpoint builder and consumed via a typed hook.

---

## 1. Endpoint Builder Structure

Endpoint builders are modular functions organized by domain under `source/priis-web/src/store/api/endpoint-builders/`:

```
src/store/api/endpoint-builders/
  addresses/index.ts
  auth/index.ts
  suppliers/index.ts
  operations/index.ts
  ...
```

Each file exports named endpoint builder functions:

```typescript
import { Builder } from '../..';       // Builder type from api/index.ts
import { Tags } from '../tags';         // Tag constants
import { Guid } from '~/types/guid';

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
        providesTags: (_result, _error, { supplierId }) => [
            Tags.suppliers.notes,
            { type: 'SupplierNotes', id: supplierId },
        ],
    });

export const createSupplierNote = (builder: Builder) =>
    builder.mutation<{ id: Guid }, CreateSupplierNoteRequest>({
        query: ({ supplierId, content }) => ({
            method: 'post',
            url: `suppliers/${supplierId}/notes`,
            body: { content },
        }),
        invalidatesTags: (_result, _error, { supplierId }) => [
            Tags.suppliers.notes,
            { type: 'SupplierNotes', id: supplierId },
        ],
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

Tags are defined in `source/priis-web/src/store/api/tags.ts`. Always use the `Tags` object — never hardcode tag strings.

```typescript
// tags.ts structure (excerpt):
export const Tags = {
    suppliers: {
        all: tagOf('Suppliers'),
        list: tagOf('Suppliers', 'List'),
        details: tagOf('Suppliers', 'Details'),
    },
    users: {
        all: tagOf('Users'),
        detailsWithId: (id: Guid) => tagOf('Users', `Details-${id}`),
    },
    // ...
} as const;
```

**Invalidation patterns:**

```typescript
// Invalidate a whole domain (all supplier queries)
invalidatesTags: [Tags.suppliers.all]

// Invalidate a specific list view
invalidatesTags: [Tags.suppliers.list]

// Invalidate a specific entity (parameterized)
invalidatesTags: (_result, _error, { supplierId }) => [
    { type: 'Suppliers', id: supplierId }
]

// Invalidate multiple related caches
invalidatesTags: (_result, _error, { supplierId }) => [
    Tags.suppliers.list,
    { type: 'Suppliers', id: `Details-${supplierId}` },
]
```

**Every mutation must have `invalidatesTags`** — omitting it causes stale UI after mutations.

---

## 4. Adding a New Tag

When a domain needs tags that don't exist yet:

**Step 1** — add the type string to `tagTypes` in `source/priis-web/src/store/api/index.ts`:
```typescript
const tagTypes = [
    'AuthExpires',
    'Suppliers',
    // ...existing...
    'SupplierNotes',   // ← add here
] as const;
```

**Step 2** — add the tag constants to `source/priis-web/src/store/api/tags.ts`:
```typescript
supplierNotes: {
    all: tagOf('SupplierNotes'),
    listBySupplier: (supplierId: Guid) => tagOf('SupplierNotes', `List-${supplierId}`),
},
```

---

## 5. Wiring into `api/index.ts`

After defining the builder function, wire it into the central API slice and export the hook:

```typescript
// In source/priis-web/src/store/api/index.ts

// Import the builder module at the top:
import * as supplierNotesBuilders from './endpoint-builders/supplier-notes';

// Add to the endpoints object:
const priisApi = createApi({
    endpoints: (builder) => ({
        // ...existing...
        listSupplierNotes: supplierNotesBuilders.listSupplierNotes(builder),
        createSupplierNote: supplierNotesBuilders.createSupplierNote(builder),
    }),
});

// Export the auto-generated hooks at the bottom:
export const {
    // ...existing...
    useListSupplierNotesQuery,
    useCreateSupplierNoteMutation,
} = priisApi;
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
❌ Hardcoded tag strings like ['Suppliers'] — use Tags.suppliers.all
❌ Duplicating an endpoint that already exists in another domain builder
❌ Exporting hooks from the builder file — hooks come from api/index.ts only
❌ Skipping the tagTypes array update when adding a new tag type
❌ Calling the query/mutation directly from api/index.ts builder; always go through hooks
```
