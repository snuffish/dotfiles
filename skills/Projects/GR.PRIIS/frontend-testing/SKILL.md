---
name: frontend-testing
description: "[Project: GR.PRIIS.Frontend] Playwright E2E testing for GR.PRIIS.Frontend — test IDs centralized in e2e/test-ids.ts with typed objects and parameterized functions, offline per-persona storage states from auth.fixtures.ts (auth.setup.ts only on the real-backend leg), helper functions for repeated steps, step-by-step assertions. No Jest/Vitest — lint + build + Playwright are the only automated quality gates. Load when writing or modifying E2E tests. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# Playwright E2E Testing

There is no unit test framework (Jest/Vitest) in this project. The quality gates are:
1. `npm run lint` — zero warnings
2. `npm run build` — TypeScript + bundle
3. `npm run e2e` — Playwright tests

All tests are end-to-end tests that run against the real application. Run from `source/priis-web/`.

---

## 1. Test IDs — Centralized Registry

All `data-testid` values are defined in `source/priis-web/e2e/test-ids.ts` as typed objects. Never hardcode test ID strings directly in spec files.

```typescript
// e2e/test-ids.ts — add a typed object per feature

type SupplierNotesTestIds = {
    createButton: string;
    createDialog: string;
    contentInput: string;
    submitButton: string;
    noteItem: (index: number) => string;                         // parameterized
    noteEditButton: (noteId: string) => string;                  // parameterized by ID
};

export const supplierNotesTestIds: SupplierNotesTestIds = {
    createButton: 'supplier-notes-create-button',
    createDialog: 'supplier-notes-create-dialog',
    contentInput: 'supplier-notes-content-input',
    submitButton: 'supplier-notes-submit-button',
    noteItem: (i) => `supplier-notes-item-${i}`,
    noteEditButton: (id) => `supplier-notes-edit-button-${id}`,
};
```

In the component, add `data-testid`:
```tsx
<button
    data-testid={supplierNotesTestIds.createButton}
    onClick={() => dispatch(openModal({ key: PriisModalKeys.CreateSupplierNote }))}
>
    Lägg till notering
</button>
```

In the spec file, import from `$e2e/test-ids`:
```typescript
import { supplierNotesTestIds } from '$e2e/test-ids';
// or from relative path when in e2e/ folder:
import { supplierNotesTestIds } from './test-ids';
```

---

## 2. Test ID Naming

Format: `{feature}-{element}-{type}` — all lowercase kebab-case.

```
supplier-notes-create-button     ← feature: supplier-notes, element: create, type: button
login-email-address-input        ← feature: login, element: email-address, type: input
contract-template-category-combobox
form-stepper-next-button
form-stepper-error-alert
```

Parameterized IDs append the discriminator:
```typescript
noteItem: (i) => `supplier-notes-item-${i}`,              // index
noteEditButton: (id) => `supplier-notes-edit-${id}`,      // entity ID
```

---

## 3. Spec File Structure

```typescript
// e2e/supplier-notes.spec.ts
import { expect, Page, test } from '@playwright/test';
import { supplierNotesTestIds, navigationTestIds } from './test-ids';
import { ErrorMessages } from '../src/strings/error-messages';
import { navigateToPage, openDialog } from './helpers';

// Unique data for this test run
const runId = Date.now().toString(36).slice(-5).toUpperCase();
const data = {
    content: `Testnotering-${runId}`,
};

// Helper functions for repeated multi-step operations
async function openCreateDialog(page: Page) {
    await navigateToPage(page, '/suppliers/test-supplier-id/notes');
    await page.getByTestId(supplierNotesTestIds.createButton).click();
    await expect(page.getByTestId(supplierNotesTestIds.createDialog)).toBeVisible();
}

async function fillNoteForm(page: Page, content: string) {
    await page.getByTestId(supplierNotesTestIds.contentInput).fill(content);
}

// Tests
test('create note — empty content shows validation error', async ({ page }) => {
    await openCreateDialog(page);
    await page.getByTestId(supplierNotesTestIds.submitButton).click();
    await expect(page.getByText('Obligatoriskt fält')).toBeVisible();
});

test('create note — valid content creates note successfully', async ({ page }) => {
    await openCreateDialog(page);
    await fillNoteForm(page, data.content);
    await page.getByTestId(supplierNotesTestIds.submitButton).click();
    await expect(page.getByTestId(supplierNotesTestIds.createDialog)).toBeHidden();
    await expect(page.getByText(data.content)).toBeVisible();
});
```

---

## 4. Auth Setup

Storage states are not checked in. `e2e/auth.fixtures.ts` builds one per persona offline from the generated grant table (`e2e/generated/role-access-rules.gen.ts`, produced by codegen from the backend's `x-roleAccessRules`), so the default run needs no backend and has no `setup` project. `playwright.config.ts` adds `dependencies: ['setup']` only when `PW_API_BASE_URL` is set (`USES_REAL_BACKEND`); on that leg `e2e/auth.setup.ts` re-logs the personas in so the states carry genuine session cookies.

Most specs inherit the register-administrator state from the `chromium` project; switch persona through the fixtures. For unauthenticated behaviour, use a context without storage state.

Run a subset with `npx playwright test <specs> --project=chromium`. Never pass `--no-deps` on the real-backend leg — without the setup project every test lands on the login page.

---

## 5. Test Data

Use `Date.now().toString(36)` suffix for names that must be unique across runs:

```typescript
const runId = Date.now().toString(36).slice(-5).toUpperCase();

const data = {
    name: `TestLeverantör-${runId}`,
    email: `test-${runId}@test.se`,
    content: `Testnotering-${runId}`,
};
```

Define all test data in a `data` object at the top of the spec file. Don't scatter magic strings throughout the test.

---

## 6. Helper Functions

Extract repeated operations into async helper functions at the top of the spec file or in `e2e/helpers.ts`:

```typescript
// In the spec file (local helpers):
async function openCreateDialog(page: Page) { ... }
async function fillBasicForm(page: Page, data: typeof testData) { ... }
async function submitForm(page: Page) { ... }

// In e2e/helpers.ts (shared helpers):
export async function navigateToSite(page: Page) { ... }
export async function selectComboboxItem(page: Page, testId: string, value: string) { ... }
export async function fillDate(locator: Locator, dateString: string) { ... }
```

---

## 7. Assertions — Step by Step

Don't just assert the final outcome. Assert intermediate states too:

```typescript
// ✅ Step-by-step — catches failures at the right step
await page.getByTestId(testIds.submitButton).click();
await expect(page.getByTestId(testIds.dialog)).toBeHidden();          // dialog closed
await expect(page.getByText(data.content)).toBeVisible();             // note appears in list
await expect(page.getByText('Notering skapad')).toBeVisible();        // success toast

// ❌ Only final outcome — harder to debug
await page.getByTestId(testIds.submitButton).click();
await expect(page.getByText(data.content)).toBeVisible();
```

Check ARIA attributes, text content, visibility, and disabled state:
```typescript
await expect(button).toBeDisabled();
await expect(input).toHaveAttribute('aria-invalid', 'true');
await expect(heading).toContainText('Noteringar');
```

---

## 8. When to Run E2E

`npm run e2e` is required for:
- UI changes (new components, form flows, navigation)
- Interactive behavior (modals, multi-step forms, real-time updates)

`npm run e2e` is NOT required for:
- Pure API-only changes (new endpoint builders without UI)
- Logic/utility changes with no UI impact

When in doubt, run it. CI runs the full suite on every PR.

Parallel runs flake under load (the login `waitForURL` and some dialogs time out, and the failing test names move between runs). Before attributing a failure to your change: re-run the spec alone, then `git stash -u` and run it again for a baseline. Failures that move or reproduce on stashed code are not yours.

---

## 9. Anti-Patterns

```
❌ Hardcoded 'my-button' strings in tests — export from test-ids.ts
❌ No data-testid in components — every interactive element in a test must have one
❌ Missing runId suffix on test-data names — causes test pollution between runs
❌ Testing only the happy path — also test validation errors, empty states, loading states
❌ One huge test function — split into focused tests with helper functions
❌ page.waitForTimeout(1000) — use expect().toBeVisible() or proper wait conditions
❌ No intermediate assertions — assert each step, not just final state
```
