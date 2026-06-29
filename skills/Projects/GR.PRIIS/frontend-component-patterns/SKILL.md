---
name: frontend-component-patterns
description: "[Project: GR.PRIIS.Frontend] React component patterns for GR.PRIIS.Frontend — Radix UI (Themes + Primitives), CSS Modules, path aliases (~, ~components, ~features, ~api, ~enums, ~strings), modal registration pattern (priis-modal-keys → priis-modals → openModal), Controlled.* form components, accessibility, Swedish text, mobile responsiveness. Load when creating or modifying components. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# Component Patterns

This skill documents the conventions for building React components in this project.

---

## 1. Path Aliases — Never Use Relative Imports

All imports must use the configured path aliases. Relative imports (`../`, `../../`) are forbidden.

| Alias | Resolves to |
|-------|-------------|
| `~` | `source/priis-web/src/` |
| `~components/` | `source/priis-web/src/components/` |
| `~features/` | `source/priis-web/src/features/` |
| `~api` | `source/priis-web/src/store/api/index.ts` |
| `~enums/` | `source/priis-web/src/enums/` |
| `~strings/` | `source/priis-web/src/strings/` |
| `$e2e/test-ids` | `source/priis-web/e2e/test-ids.ts` |

```typescript
// ✅ Correct
import { Button } from '~components/button';
import { useListSuppliersQuery } from '~api';
import { SystemAction } from '~enums/systemAction';
import { ErrorMessages } from '~strings/error-messages';

// ❌ Wrong
import { Button } from '../../components/button';
import { useListSuppliersQuery } from '../../../store/api';
```

---

## 2. Radix UI First

Before building a custom component, check `source/priis-web/src/components/` — the project wraps many Radix primitives there.

**Radix Themes** for layout and typography:

```tsx
import { Badge, Flex, Grid, Heading, Separator, Text } from '@radix-ui/themes';

<Flex direction='column' gap='3'>
    <Heading size='4'>Leverantörer</Heading>
    <Grid columns='2' gap='4'>...</Grid>
    <Text color='gray'>Inga resultat</Text>
    <Badge color='green'>Aktiv</Badge>
</Flex>
```

**Radix Primitives** for interactive components (Dialog, Select, Popover, etc.) — use the project's wrapped versions in `~components/` which add consistent styling and behavior.

**Never build a custom modal/dialog from scratch** — use the project's modal pattern (see section 5).

---

## 3. CSS Modules — No Inline Styles

Every component that needs custom styling uses a co-located `.module.css` file:

```
source/priis-web/src/features/supplier/
  supplier-list.tsx
  supplier-list.module.css   ← co-located
```

```typescript
// supplier-list.tsx
import styles from './supplier-list.module.css';

<div className={styles.container}>
    <table className={styles.table}>...</table>
</div>
```

```css
/* supplier-list.module.css */
.container { padding: var(--space-4); }
.table { width: 100%; }
```

Use **Radix Themes CSS tokens** for spacing, colors, and typography — do not hardcode values.

```
❌ style={{ marginTop: '16px' }}
✅ gap='3' (Radix Themes prop, 3 = var(--space-3))
✅ className={styles.spacing}  + .spacing { margin-top: var(--space-4); }
```

---

## 4. File Naming

- **Files:** kebab-case — `supplier-notes-form.tsx`, `supplier-notes-form.module.css`
- **Components:** PascalCase — `export function SupplierNotesForm`
- **Props interface:** `ComponentNameProps` — `type SupplierNotesFormProps = { ... }`
- **Feature folder:** `source/priis-web/src/features/{domain}/` — group related components together
- **Shared UI:** `source/priis-web/src/components/` — project-wide reusable components only

---

## 5. Modal Pattern

Every modal follows a three-step registration process:

**Step 1** — Add a key to `source/priis-web/src/features/modals/priis-modal-keys.ts`:

```typescript
export const PriisModalKeys = {
    // ...existing...
    CreateSupplierNote: 'CreateSupplierNote',
} as const;
```

**Step 2** — Register the component in `source/priis-web/src/features/modals/components/priis-modals.tsx`:

```typescript
import { CreateSupplierNoteModal } from '~features/supplier/create-supplier-note-modal';

const modalMap: Record<string, React.ComponentType<never>> = {
    // ...existing...
    [PriisModalKeys.CreateSupplierNote]: CreateSupplierNoteModal,
};
```

**Step 3** — Dispatch to open:

```typescript
import { openModal } from '~features/modals/modal-slice';

dispatch(openModal({
    key: PriisModalKeys.CreateSupplierNote,
    props: { supplierId: 'abc123' },
}));
```

The modal component receives its props via `useGlobalModalPreloadDataContext()` or directly as component props, depending on the modal variant used.

---

## 6. `Controlled.*` Form Components

The project provides `Controlled.*` wrappers around Radix UI inputs that integrate with react-hook-form. Use these instead of building raw `<input>` elements.

```typescript
import { Controlled } from '~components/form/controlled';

// In a form component:
<Controlled.Text
    control={control}
    name='name'
    label='Namn'
    placeholder='Ange namn'
/>

<Controlled.Combobox
    control={control}
    name='administrationId'
    label='Förvaltning'
    items={administrations}
    placeholder='Välj förvaltning'
/>

<Controlled.TextArea
    control={control}
    name='description'
    label='Beskrivning'
/>

<Controlled.RadioGroup
    control={control}
    name='type'
    label='Typ'
    items={typeOptions}
/>
```

Check `source/priis-web/src/components/form/` for all available `Controlled.*` variants before building custom inputs.

---

## 7. Accessibility

Radix UI handles most accessibility requirements (ARIA roles, keyboard navigation, focus trapping in dialogs). When adding custom interactive elements:

- Semantic HTML first (`<button>`, `<nav>`, `<main>`, `<section>`, `<article>`)
- All interactive elements must be keyboard navigable
- Images and icons need `aria-label` or `aria-hidden`
- Form fields need associated `<label>` (Radix handles this via `Controlled.*`)
- Focus management after modal open/close is handled by Radix Dialog

---

## 8. Swedish Text — Everything Visible Must Be Swedish

**All user-visible text must be in Swedish.** This includes:

- Labels, headings, descriptions
- Button text
- Placeholder text
- Error messages
- Empty state messages
- Confirmation dialogs

```tsx
// ✅ Swedish
<Buttons.Primary>Lägg till</Buttons.Primary>
<Text>Inga noteringar hittades.</Text>
<input placeholder='Ange namn' />

// ❌ English in UI
<Buttons.Primary>Add</Buttons.Primary>
<Text>No notes found.</Text>
<input placeholder='Enter name' />
```

Standard error messages: use `ErrorMessages.*` from `~strings/error-messages` — don't duplicate string literals.

---

## 9. Mobile Responsiveness

Breakpoints (defined in `source/priis-web/src/globals.css`):

- Mobile: `< 768px`
- Tablet: `768px – 1024px`
- Desktop: `> 1024px`

Use the media query hooks for conditional rendering:

```typescript
import { useIsMobile, useIsTablet, useIsDesktop } from '~/hooks/use-breakpoints';

const isMobile = useIsMobile();
return isMobile ? <MobileView /> : <DesktopView />;
```

For routes that don't support mobile, wrap with `MobileGuard`:

```tsx
import { MobileGuard } from '~components/mobile-guard';

export default function AdminPage() {
    return (
        <MobileGuard>
            <PageContent />
        </MobileGuard>
    );
}
```

---

## 10. Anti-Patterns

```
❌ Relative imports — use path aliases
❌ style={{ }} inline styles — use CSS Modules
❌ Hardcoded English UI text — Swedish only
❌ Building a custom modal without using the modal pattern (priis-modal-keys → priis-modals)
❌ Raw <input> or Radix input without Controlled.* wrapper in forms
❌ Custom dialog from scratch — use Radix Dialog via project components
❌ Missing MobileGuard on desktop-only routes
```
