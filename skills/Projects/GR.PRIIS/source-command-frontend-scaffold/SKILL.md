---
name: source-command-frontend-scaffold
description: "[Project: GR.PRIIS.Frontend] Scaffold a new feature slice — RTK Query endpoint builder, form schema, component, TanStack Router route file, and Playwright test IDs. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# source-command-frontend-scaffold

Use this skill when the user asks to run the migrated source command `scaffold` for the GR.PRIIS.Frontend project.

## Command Template

# /scaffold — Feature Scaffolding

Generate a complete feature slice for a new frontend feature. Provide a short description:

```
/scaffold "GET /suppliers/{id}/notes — list notes for a supplier"
/scaffold "POST /operations/{id}/status — update operation status, mutation"
/scaffold "New page /suppliers/:supplierId/notes — shows list of notes with create modal"
```

---

## Step 1: Gather Context

Before generating, read:
- The nearest existing endpoint builder file in the same domain (`source/priis-web/src/store/api/endpoint-builders/{domain}/index.ts`)
- The existing `source/priis-web/src/store/api/index.ts` to understand how builders are wired and how hooks are exported
- The existing `source/priis-web/src/store/api/tags.ts` to check if domain tags already exist

Ask for clarification if: the domain folder is unclear, or a form is involved but the request/response shape is not described.

---

## Step 2: Determine What to Generate

Based on the description, identify which of these apply:
- [ ] New endpoint builder (always)
- [ ] New tag in `tags.ts` (if domain doesn't have one yet)
- [ ] Form schema + form component (if mutation with user input)
- [ ] List/display component (if read query displaying data)
- [ ] New route file (if a new page is needed)
- [ ] Playwright test IDs (if interactive UI is involved)

---

## Step 3: Endpoint Builder

**Location:** `source/priis-web/src/store/api/endpoint-builders/{domain}/index.ts`

Add to the existing domain file, or create a new one if the domain doesn't exist yet.

```typescript
import { Builder } from '../..';
import { Tags } from '../tags';

// Types (co-located or in a separate types.ts in the same folder)
export type SupplierNote = {
    id: string;
    content: string;
    createdAt: string;
    createdBy: string;
};

export type ListSupplierNotesResponse = {
    items: SupplierNote[];
};

// Query endpoint (for GET requests)
export const listSupplierNotes = (builder: Builder) =>
    builder.query<ListSupplierNotesResponse, { supplierId: string }>({
        query: ({ supplierId }) => ({
            method: 'get',
            url: `suppliers/${supplierId}/notes`,
        }),
        providesTags: (_result, _error, { supplierId }) => [
            { type: Tags.suppliers.notes, id: supplierId },
        ],
    });

// Mutation endpoint (for POST/PUT/PATCH/DELETE)
export const createSupplierNote = (builder: Builder) =>
    builder.mutation<{ id: string }, { supplierId: string; content: string }>({
        query: ({ supplierId, content }) => ({
            method: 'post',
            url: `suppliers/${supplierId}/notes`,
            body: { content },
        }),
        invalidatesTags: (_result, _error, { supplierId }) => [
            { type: Tags.suppliers.notes, id: supplierId },
        ],
    });
```

**Wire into api/index.ts:**

```typescript
// In the endpoints object:
listSupplierNotes: suppliersBuilders.listSupplierNotes(builder),
createSupplierNote: suppliersBuilders.createSupplierNote(builder),

// In the exports at the bottom:
export const {
    // ...existing exports...
    useListSupplierNotesQuery,
    useCreateSupplierNoteMutation,
} = priisApi;
```

---

## Step 4: Tags (if new domain)

If the domain has no existing tags, add to `source/priis-web/src/store/api/tags.ts`:

```typescript
// Inside the Tags object:
supplierNotes: {
    all: tagOf('SupplierNotes'),
    listBySupplier: (supplierId: Guid) => tagOf('SupplierNotes', `List-${supplierId}`),
},
```

Add the new type string to the `tagTypes` array at the top of `source/priis-web/src/store/api/index.ts`:

```typescript
const tagTypes = [
    // ...existing...
    'SupplierNotes',
] as const;
```

---

## Step 5: Form Schema (if mutation with user input)

**Location:** `source/priis-web/src/features/{domain}/schema.ts`

```typescript
import { z } from 'zod/v4';

export const createSupplierNoteSchema = z.object({
    content: z.string().min(1, { message: 'Obligatoriskt fält' }),
    // Additional fields as needed
});

export type CreateSupplierNoteFormValues = z.infer<typeof createSupplierNoteSchema>;
```

**Rules:**
- Always `from 'zod/v4'` — never `from 'zod'`
- Swedish validation messages
- Use `ErrorMessages.*` from `~strings/error-messages` for standard messages
- For conditional fields: use `z.discriminatedUnion('fieldName', [...])` pattern

---

## Step 6: Component

**Location:** `source/priis-web/src/features/{domain}/{component-name}.tsx`

```typescript
import { Flex, Heading, Text } from '@radix-ui/themes';
import { SubmitHandler, useForm } from 'react-hook-form';
import { z } from 'zod/v4';
import { zodResolver } from '~/utility/validation/zod-v4-resolver';
import { useCreateSupplierNoteMutation } from '~api';
import { createSupplierNoteSchema, CreateSupplierNoteFormValues } from './schema';
import styles from './create-supplier-note-form.module.css';

type CreateSupplierNoteFormProps = {
    supplierId: string;
    onSuccess: () => void;
};

export function CreateSupplierNoteForm({ supplierId, onSuccess }: CreateSupplierNoteFormProps) {
    const [createNote, { error }] = useCreateSupplierNoteMutation();

    const { control, handleSubmit, formState: { errors } } = useForm<CreateSupplierNoteFormValues>({
        resolver: zodResolver(createSupplierNoteSchema),
        defaultValues: { content: '' },
        shouldUnregister: true,
    });

    const submit: SubmitHandler<CreateSupplierNoteFormValues> = (data) => {
        createNote({ supplierId, content: data.content })
            .unwrap()
            .then(() => onSuccess())
            .catch(() => { /* handled by error state */ });
    };

    return (
        <form onSubmit={handleSubmit(submit)} className={styles.form}>
            <Flex direction='column' gap='3'>
                <Controlled.TextArea control={control} name='content' label='Notering' />
                <Buttons.Primary type='submit'>Lägg till</Buttons.Primary>
            </Flex>
        </form>
    );
}
```

**Rules:**
- Path aliases only (`~api`, `~components/`, `~features/`, `~enums/`, `~strings/`)
- Radix UI for layout — `Flex`, `Grid`, `Text`, `Heading`, `Badge`, etc.
- CSS Modules for custom styles (`component-name.module.css` co-located)
- `Controlled.*` components for form fields — not raw `<input>` or Radix inputs directly
- Swedish labels, placeholders, button text
- Props interface named `ComponentNameProps`
- File name: kebab-case (`create-supplier-note-form.tsx`)

---

## Step 7: Route File (if new page)

**Location:** `source/priis-web/src/routes/{english-path}.tsx`

```typescript
import { createFileRoute } from '@tanstack/react-router';
import { SupplierNotesPage } from '~features/supplier/supplier-notes-page';

export const Route = createFileRoute('/suppliers/$supplierId/notes')({
    component: SupplierNotesPage,
    staticData: {
        type: 'general',
        title: 'Noteringar',   // Swedish title for breadcrumbs
    },
});

export default SupplierNotesPage;
```

**Route file naming:**
- Static segment: `suppliers.tsx` → `/suppliers`
- Dynamic segment: `suppliers/$supplierId.tsx` → `/suppliers/:supplierId`
- Nested: `suppliers/$supplierId/notes.tsx` → `/suppliers/:supplierId/notes`
- Layout: `_authenticated.tsx` → wraps all child routes with authentication

**Rules:**
- `routeTree.gen.ts` is auto-generated — never edit it
- URLs must be English — never Swedish URL segments
- Always include `staticData` with Swedish `title`
- Use `$` prefix for dynamic segments (not `:`)

---

## Step 8: Playwright Test IDs

**Location:** `source/priis-web/e2e/test-ids.ts`

Add a typed object for the new feature:

```typescript
type SupplierNotesTestIds = {
    createButton: string;
    createDialog: string;
    contentInput: string;
    submitButton: string;
    noteItem: (index: number) => string;
};

export const supplierNotesTestIds: SupplierNotesTestIds = {
    createButton: 'supplier-notes-create-button',
    createDialog: 'supplier-notes-create-dialog',
    contentInput: 'supplier-notes-content-input',
    submitButton: 'supplier-notes-submit-button',
    noteItem: (i) => `supplier-notes-item-${i}`,
};
```

Add `data-testid` attributes to the corresponding interactive elements in the component using these constants.

**Test ID naming:** `{feature}-{element}-{type}` — all lowercase kebab-case.

---

## Anti-Patterns — Never Generate

```
❌ import { z } from 'zod'                    — use 'zod/v4'
❌ from '@hookform/resolvers/zod'             — use '~/utility/validation/zod-v4-resolver'
❌ Relative imports (../ or ../../)           — use path aliases
❌ style={{ }} inline styles                  — use CSS Modules
❌ English labels/placeholders in JSX         — Swedish only
❌ fetch() or axios outside store/            — use RTK Query hooks
❌ Missing invalidatesTags on mutations        — every mutation must invalidate affected queries
❌ Hardcoded data-testid strings in tests     — export from test-ids.ts
❌ Editing routeTree.gen.ts                   — auto-generated, never touch
❌ Swedish URL segments                       — /notiser should be /notifications
```
