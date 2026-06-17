---
name: frontend-forms
description: "[Project: GR.PRIIS.Frontend] Form patterns for GR.PRIIS.Frontend — Zod v4 (always import from 'zod/v4' NOT 'zod'), custom zodResolver from ~/utility/validation/zod-v4-resolver, schema location in features/{domain}/schema.ts, discriminated unions, react-hook-form setup, Controlled.* components, Swedish validation messages. Load when creating or modifying forms. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# Forms — react-hook-form + Zod v4

Every form in this project uses react-hook-form with Zod v4 for validation. The two most common mistakes are the wrong Zod import path and the wrong resolver import — both are covered first.

---

## 1. Critical Imports — These Are Always Wrong Without the `/v4`

```typescript
// ✅ CORRECT — always use 'zod/v4'
import { z } from 'zod/v4';

// ❌ WRONG — 'zod' without /v4 uses Zod v3 API (project uses v4)
import { z } from 'zod';
import { z } from 'zod/v3';
```

```typescript
// ✅ CORRECT — project's custom resolver that works with Zod v4
import { zodResolver } from '~/utility/validation/zod-v4-resolver';

// ❌ WRONG — the standard @hookform resolver is for Zod v3
import { zodResolver } from '@hookform/resolvers/zod';
```

---

## 2. Schema Location

Place schemas in `source/priis-web/src/features/{domain}/schema.ts`. Export both the schema and the inferred type:

```typescript
// source/priis-web/src/features/supplier/schema.ts
import { z } from 'zod/v4';
import { ErrorMessages } from '~strings/error-messages';

export const createSupplierNoteSchema = z.object({
    content: z.string().min(1, { message: ErrorMessages.obligatoryField }),
    type: z.enum(['internal', 'external'], { message: 'Välj en typ' }),
});

export type CreateSupplierNoteFormValues = z.infer<typeof createSupplierNoteSchema>;
```

For update forms, reuse or extend the create schema:
```typescript
export const updateSupplierNoteSchema = createSupplierNoteSchema.partial();
export type UpdateSupplierNoteFormValues = z.infer<typeof updateSupplierNoteSchema>;
```

---

## 3. Discriminated Unions for Conditional Fields

When form fields depend on a selected type, use `z.discriminatedUnion`:

```typescript
import { z } from 'zod/v4';
import { SupplierType } from '~enums/supplierType';

const municipalitySchema = z.object({
    type: z.literal(SupplierType.Municipality),
    administrationId: z.string().min(1, { message: 'Välj förvaltning' }),
    name: z.string().min(1, { message: 'Obligatoriskt fält' }),
});

const companySchema = z.object({
    type: z.literal(SupplierType.Company),
    organizationNumber: z.string().regex(/^\d{6}-\d{4}$/, { message: 'Ogiltigt organisationsnummer' }),
    name: z.string().min(1, { message: 'Obligatoriskt fält' }),
});

export const createSupplierSchema = z.discriminatedUnion('type', [
    municipalitySchema,
    companySchema,
]);

export type CreateSupplierFormValues = z.infer<typeof createSupplierSchema>;
```

The discriminated union enables TypeScript to narrow the type based on the selected value, so conditional rendering is type-safe.

---

## 4. `useForm` Setup

```typescript
import { SubmitHandler, useForm } from 'react-hook-form';
import { z } from 'zod/v4';
import { zodResolver } from '~/utility/validation/zod-v4-resolver';
import { createSupplierNoteSchema, CreateSupplierNoteFormValues } from './schema';

function CreateSupplierNoteForm({ supplierId, onSuccess }: Props) {
    const form = useForm<CreateSupplierNoteFormValues>({
        resolver: zodResolver(createSupplierNoteSchema as z.ZodType<CreateSupplierNoteFormValues>),
        defaultValues: {
            content: '',
            type: 'internal',
        },
        shouldUnregister: true,   // unregisters fields removed from DOM (important for conditional fields)
    });

    const { control, handleSubmit, watch, formState: { errors } } = form;
    const selectedType = watch('type');   // watch for conditional rendering
    // ...
}
```

**`shouldUnregister: true`** is important for forms with conditional fields (discriminated unions) — ensures removed fields don't contribute stale values to submission.

---

## 5. Form Submission

```typescript
const [createNote, { error, isLoading }] = useCreateSupplierNoteMutation();
const { errors: apiErrors } = useApiError(error);   // server-side errors

const submit: SubmitHandler<CreateSupplierNoteFormValues> = (data) => {
    createNote({ supplierId, content: data.content })
        .unwrap()
        .then(() => {
            dispatch(closeModal());
            onSuccess?.();
        })
        // .unwrap() throws on error — handle via error state, not catch
        ;
};

return (
    <form onSubmit={handleSubmit(submit)}>
        {/* form fields */}
        <Buttons.Primary type='submit' loading={isLoading}>
            Spara
        </Buttons.Primary>
    </form>
);
```

---

## 6. Error Handling

**Client-side validation errors** are handled by `formState.errors` from react-hook-form. The `Controlled.*` components display these automatically.

**Server-side errors** from the API mutation:
```typescript
const [createNote, { error }] = useCreateSupplierNoteMutation();
const { errors: apiErrors } = useApiError(error);

// Display server errors (e.g., validation failures from backend SystemResult)
{apiErrors?.map((err) => (
    <Text color='red' key={err.message}>{err.message}</Text>
))}
```

---

## 7. Validation Messages — Swedish Only

All validation messages must be in Swedish. Use `ErrorMessages.*` from `~strings/error-messages` for standard patterns; write custom Swedish strings for domain-specific messages.

```typescript
// ✅ Correct — Swedish
content: z.string().min(1, { message: 'Obligatoriskt fält' }),
email: z.string().email({ message: 'Ogiltig e-postadress' }),
amount: z.number().positive({ message: 'Beloppet måste vara positivt' }),

// ✅ Using shared constants
import { ErrorMessages } from '~strings/error-messages';
name: z.string().min(1, { message: ErrorMessages.obligatoryField }),

// ❌ Wrong — English
content: z.string().min(1, { message: 'Required field' }),
```

---

## 8. `Controlled.*` Components

Use the project's form field components — they integrate with react-hook-form and display validation errors automatically.

```typescript
import { Controlled } from '~components/form/controlled';

// Single line text input
<Controlled.Text control={control} name='name' label='Namn' placeholder='Ange namn' />

// Multi-line text
<Controlled.TextArea control={control} name='description' label='Beskrivning' />

// Searchable dropdown
<Controlled.Combobox control={control} name='supplierId' label='Leverantör' items={suppliers} />

// Date picker
<Controlled.DatePicker control={control} name='startDate' label='Startdatum' />

// Radio group
<Controlled.RadioGroup control={control} name='type' label='Typ' items={typeOptions} />

// Checkbox
<Controlled.Checkbox control={control} name='isActive' label='Aktiv' />
```

Check `source/priis-web/src/components/form/` for all available `Controlled.*` variants. Do not build custom form inputs unless no suitable `Controlled.*` component exists.

---

## 9. Anti-Patterns

```
❌ import { z } from 'zod'                       — must be 'zod/v4'
❌ import { zodResolver } from '@hookform/resolvers/zod'  — use '~/utility/validation/zod-v4-resolver'
❌ English validation messages                    — Swedish only
❌ Schema defined inline in component             — put in features/{domain}/schema.ts
❌ Forgetting shouldUnregister: true for conditional fields
❌ Using raw <input> instead of Controlled.*      — validators won't connect
❌ Handling server errors in .catch() — use error state from mutation hook
❌ Not exporting the inferred type (export type FooFormValues = z.infer<typeof fooSchema>)
```
