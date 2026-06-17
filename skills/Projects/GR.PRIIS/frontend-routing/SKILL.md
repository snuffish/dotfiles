---
name: frontend-routing
description: "[Project: GR.PRIIS.Frontend] TanStack Router file-based routing for GR.PRIIS.Frontend — route file naming conventions, createFileRoute, staticData, dynamic segments ($param), layout routes with Outlet, Link component, search params, routeTree.gen.ts is auto-generated (never edit). Load when adding or modifying routes or navigation. Load ONLY when working on the GR.PRIIS.Frontend project or in the GR repository."
---

# TanStack Router — File-Based Routing

This project uses TanStack Router with file-based routing. Route files live in `source/priis-web/src/routes/`. The route tree is auto-generated — every file added to that directory automatically becomes a route.

---

## 1. File Name → URL Mapping

| File path | URL |
|-----------|-----|
| `src/routes/suppliers.tsx` | `/suppliers` |
| `src/routes/suppliers/$supplierId.tsx` | `/suppliers/:supplierId` |
| `src/routes/suppliers/$supplierId/notes.tsx` | `/suppliers/:supplierId/notes` |
| `src/routes/_authenticated.tsx` | Layout wrapper (no URL segment, wraps children) |
| `src/routes/_authenticated/admin.tsx` | `/admin` (inside _authenticated layout) |
| `src/routes/__root.tsx` | Root layout (not a URL) |

**Dynamic segments** use `$` prefix in the filename — not `:`. The parameter name comes from the filename after `$`.

---

## 2. Route File Structure

Every route file exports `Route` and a default component:

```typescript
// source/priis-web/src/routes/suppliers/$supplierId/notes.tsx
import { createFileRoute, Outlet } from '@tanstack/react-router';
import { SupplierNotesPage } from '~features/supplier/supplier-notes-page';

export const Route = createFileRoute('/suppliers/$supplierId/notes')({
    component: SupplierNotesPage,
    staticData: {
        type: 'general',      // 'general' or 'management' — controls layout/breadcrumb style
        title: 'Noteringar',  // Swedish page title shown in breadcrumbs and <title>
    },
});

export default SupplierNotesPage;
```

The path string passed to `createFileRoute()` must exactly match the file path from `routes/`. If they don't match, TanStack Router will error at runtime.

---

## 3. `staticData`

All route files must include `staticData`:

```typescript
staticData: {
    type: 'general',      // standard page layout
    // OR
    type: 'management',   // admin/management section layout
    title: 'Swedish title here',
}
```

`title` is used by the layout component for the page title, breadcrumbs, and `<title>` tag. It must be in **Swedish**.

---

## 4. Accessing Route Params

```typescript
// In the component (or a loader):
const { supplierId } = Route.useParams();

// In a child component that needs the param:
import { useParams } from '@tanstack/react-router';
const { supplierId } = useParams({ from: '/suppliers/$supplierId' });
```

---

## 5. Layout Routes (with `Outlet`)

Files prefixed with `_` are layout routes — they wrap their children but don't add a URL segment:

```typescript
// src/routes/_authenticated.tsx — wraps all authenticated routes
import { createFileRoute, Outlet } from '@tanstack/react-router';
import { AuthGuard } from '~features/auth/auth-guard';

export const Route = createFileRoute('/_authenticated')({
    component: AuthenticatedLayout,
});

function AuthenticatedLayout() {
    return (
        <AuthGuard>
            <MainLayout>
                <Outlet />   {/* renders the matched child route */}
            </MainLayout>
        </AuthGuard>
    );
}
```

Regular layout routes (without `_` prefix) add a URL segment AND wrap children:
```typescript
// src/routes/suppliers.tsx — renders at /suppliers, also wraps /suppliers/* children
export const Route = createFileRoute('/suppliers')({
    component: SuppliersLayout,
});

function SuppliersLayout() {
    return (
        <Flex direction='column'>
            <SuppliersHeader />
            <Outlet />   {/* renders /suppliers/:id etc. */}
        </Flex>
    );
}
```

---

## 6. `routeTree.gen.ts` — Never Edit

`source/priis-web/src/routeTree.gen.ts` is **automatically generated** by the TanStack Router Vite plugin when running `npm run dev` or `npm run build`. It contains the complete type-safe route tree.

```
❌ Never edit routeTree.gen.ts manually
❌ Never import from routeTree.gen.ts directly
✅ After adding a new route file, run npm run dev to regenerate it
```

---

## 7. `Link` Component

Always use TanStack Router's `Link` for navigation — never plain `<a href>`:

```typescript
import { Link } from '@tanstack/react-router';

// Static route
<Link to='/suppliers'>Leverantörer</Link>

// Dynamic route with params
<Link to='/suppliers/$supplierId' params={{ supplierId: supplier.id }}>
    {supplier.name}
</Link>

// With search params
<Link to='/suppliers' search={{ status: 'active' }}>
    Aktiva leverantörer
</Link>
```

`Link` is type-safe — TypeScript will error if the route or params don't match a real route.

---

## 8. Search Params

Validate and type search params in the route definition:

```typescript
import { z } from 'zod/v4';
import { zodValidator } from '@tanstack/zod-adapter';

export const Route = createFileRoute('/suppliers')({
    validateSearch: zodValidator(z.object({
        status: z.enum(['active', 'inactive']).optional(),
        page: z.number().int().positive().optional(),
    })),
    component: SuppliersPage,
    staticData: { type: 'general', title: 'Leverantörer' },
});

// In the component:
const { status, page } = Route.useSearch();
```

---

## 9. English URLs — Always

Route paths must be English — no Swedish URL segments:

```
✅ /suppliers           ❌ /leverantorer
✅ /operations          ❌ /verksamheter
✅ /notifications       ❌ /notifieringar
✅ /administrations     ❌ /forvaltningar
```

Page titles (`staticData.title`) are Swedish — only the URL path segment must be English.

---

## 10. Anti-Patterns

```
❌ Editing routeTree.gen.ts — auto-generated, never touch
❌ Swedish URL segments (/verksamheter) — English only
❌ <a href='/path'> for internal navigation — use <Link to='/path'>
❌ Missing staticData on route file
❌ English title in staticData — page titles must be Swedish
❌ createFileRoute path that doesn't match the actual file path
❌ Accessing params from useParams without specifying the 'from' option in child components
```
