# Identity module — authentication migration plan

Plan for moving the authentication features from the Laravel app into the
`identity` module (`app-modules/identity`, managed by `internachi/modular`).

Status: **not started**. Nothing below has been applied yet.

---

## 1. Current inventory

| Area | Current location |
|---|---|
| Fortify setup (views, actions, rate limiting) | `app/Providers/FortifyServiceProvider.php`, registered in `bootstrap/providers.php` |
| Fortify config | `config/fortify.php` (registration + 2FA enabled) |
| Fortify actions | `app/Actions/Fortify/ResetUserPassword.php` |
| Validation rule traits | `app/Concerns/PasswordValidationRules.php`, `app/Concerns/ProfileValidationRules.php` |
| Settings controllers | `app/Http/Controllers/Settings/ProfileController.php`, `SecurityController.php` |
| Settings form requests | `app/Http/Requests/Settings/*` (password, profile update/delete, 2FA) |
| Settings routes | `routes/settings.php` (required from `routes/web.php`) |
| Inertia pages | `resources/js/pages/auth/*`, `resources/js/pages/settings/*` |
| Auth-only layouts/components | `resources/js/layouts/auth-layout.tsx`, `layouts/auth/*`, `layouts/settings/*`, `components/delete-user.tsx` |
| Tests | `tests/Feature/Auth/*`, `tests/Feature/Settings/*` |
| User model | `app/Models/User.php` (used by `config/auth.php`, `UserFactory`, `DatabaseSeeder`) |

---

## 2. Target structure

```
app-modules/identity/
├── config/register.php                 (keep only if still needed, see §4)
├── routes/identity-routes.php          ← content of routes/settings.php
├── src/
│   ├── Providers/
│   │   ├── IdentityServiceProvider.php ← registers the Fortify provider below
│   │   └── FortifyServiceProvider.php  ← moved; removed from bootstrap/providers.php
│   ├── Actions/Fortify/                ← ResetUserPassword (+ CreateNewUser)
│   ├── Concerns/                       ← validation rule traits
│   └── Http/
│       ├── Controllers/Settings/
│       └── Requests/Settings/
├── resources/js/
│   ├── pages/auth/*
│   ├── pages/settings/*                (profile, security)
│   ├── layouts/auth-layout.tsx, layouts/auth/*, layouts/settings/*
│   └── components/delete-user.tsx
└── tests/Feature/
    ├── Auth/*
    └── Settings/*
```

Namespaces change from `App\…` to `Demokratsika\Identity\…`.

Stays in the app: shared UI (`components/ui/*`, `layouts/app-layout.tsx`,
hooks, types), `HandleInertiaRequests` (shares `auth.user`), `config/fortify.php`
and `config/auth.php`.

---

## 3. Frontend: Inertia pages outside `resources/js/pages`

Everything below currently assumes a single pages directory.

1. **Page resolution, client and SSR.** `resources/js/app.tsx` relies on the
   `@inertiajs/vite` plugin's default `./pages` lookup. Add an explicit
   `resolve()` globbing both locations:
   - `./pages/**/*.tsx` → `welcome`, `dashboard`, …
   - `../../app-modules/*/resources/js/pages/**/*.tsx` → `identity::auth/login`, …

   `app.tsx` is also the SSR entry, so this keeps SSR working for the public
   identity pages (`login`, `register`, `password.request`, `password.reset`,
   listed in `config/inertia.php` → `ssr.routes`).
2. **Blade root view.** `resources/views/app.blade.php` hard-codes
   `resources/js/pages/{component}.tsx` in `@vite(...)`. It must map
   `identity::foo/bar` to `app-modules/identity/resources/js/pages/foo/bar.tsx`.
3. **Layouts.** The `layout` callback in `app.tsx` checks
   `name.startsWith('auth/')` and `name.startsWith('settings/')`. Update it to
   `identity::auth/` and `identity::settings/`. `settings/appearance` stays in
   the app if appearance isn't moved (see §6).
4. **Import alias.** Add `@identity/*` → `app-modules/identity/resources/js/*`
   in `vite.config.ts` and `tsconfig.json`. Module files keep importing shared
   UI through `@/…`.
5. **Wayfinder.** Controller actions get regenerated under
   `@/actions/Demokratsika/Identity/Http/Controllers/Settings/...`. Update the
   imports in `profile.tsx`, `security.tsx` and `delete-user.tsx`. Named routes
   (`@/routes/...`) don't change.
6. **Lint/format.** Check that `vp check` and `tsc --noEmit` cover the module's
   `resources/js` (tsconfig `include`).

---

## 4. Registration

The current module route is **overridden by Fortify**:

```php
// app-modules/identity/routes/identity-routes.php
Route::inertia(config('register.route_path'), 'welcome')->name('register.index');
```

`Features::registration()` in `config/fortify.php` registers its own
`GET /register` (named `register`). Laravel keeps only one route per
method + URI, so the module route never shows up in `php artisan route:list`.

Plan:
- Delete that route.
- In the module's Fortify provider:
  `Fortify::registerView(fn () => Inertia::render('identity::auth/register', [...]))`.
- Add `Actions/Fortify/CreateNewUser.php` and register it with
  `Fortify::createUsersUsing(CreateNewUser::class)`.
- Create `resources/js/pages/auth/register.tsx` in the module.
- Add a registration feature test.
- Keep `config/register.php` (merged in `IdentityServiceProvider::register()`)
  only if it still configures something. If it stays, consider renaming the
  key to `identity.register` to avoid global config clashes.

---

## 5. Tests and tooling

- `config/inertia.php` → `pages.paths`: add
  `base_path('app-modules/identity/resources/js/pages')` so `assertInertia()`
  finds module pages (`testing.ensure_pages_exist` is `true`).
- `phpunit.xml`: add the module tests directory to a test suite
  (for example `<directory>app-modules/*/tests</directory>`).
- `tests/Pest.php`: extend `TestCase` + `RefreshDatabase` to the module tests
  directory (check that Pest's `in()` accepts that path).
- Module test namespace: `Demokratsika\Identity\Tests\…` (already in the
  module's `composer.json` autoload).

---

## 6. Open decisions

1. **User model.** Recommended: keep `App\Models\User` in the app for this
   step, and move it to the module in a separate change. Moving it means
   updating `config/auth.php`, `UserFactory`, `DatabaseSeeder`, the Fortify
   actions and every test.
2. **Settings pages.** Recommended: move profile, password and 2FA into
   identity. Keep `appearance` in the app (UI preference, not identity).
3. **Page naming.** Recommended: namespaced names (`identity::auth/login`).
   The alternative is plain `auth/login` with the lookup searching every
   folder: shorter, but two modules could collide.

---

## 7. Execution checklist

- [ ] Decide §6 (User model, settings scope, page naming)
- [ ] Move PHP classes, fix namespaces and imports
- [ ] Move the Fortify provider into the module, remove it from `bootstrap/providers.php`
- [ ] Move `routes/settings.php` content into `identity-routes.php`, remove the `require` in `routes/web.php`
- [ ] Set up registration the Fortify way (§4)
- [ ] Move pages, layouts and components, add the `@identity` alias
- [ ] Custom `resolve()` in `app.tsx` + layout callback + Blade `@vite` mapping
- [ ] Update `Inertia::render()` component names
- [ ] Update Wayfinder action imports
- [ ] Update `inertia.pages.paths`, `phpunit.xml`, `tests/Pest.php`
- [ ] Move tests and update their namespaces/imports
- [ ] `composer dump-autoload`, then `vendor/bin/pint --dirty --format agent`

Run inside the Docker containers (the host PHP is 7.4):

```bash
docker compose exec app composer dump-autoload
docker compose exec app php artisan route:list          # every route listed once
docker compose exec app php artisan test --compact      # full suite
docker compose exec vite npm run build:ssr
docker compose exec vite npm run check
docker compose exec vite npm run types:check
```

Then curl `/login`: the HTML must contain `data-server-rendered`.
