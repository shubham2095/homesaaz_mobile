# HomeSaaz backend ZIP review

Review date: 2026-09-23 (updated 2026-09-26 with the user-access review below). Source: the user-provided `homeSaaz.zip`.

## Scope and validation

Static review of application structure, web/API routes, authentication, permissions, file handling, database dependencies, representative controllers/models, and Flutter integration. No application bootstrap, migrations, production database requests, or write endpoint tests were performed. Credentials and environment secrets are intentionally omitted.

- Archive: approximately 77.2 MiB compressed, 153.6 MiB uncompressed; 12,840 files.
- 16 web controller files, 16 API controller files, 16 model files.
- PHP syntax lint: 81 application, route, configuration, migration, and bootstrap files passed using PHP 8.2.12 with `php -n -l`.
- No project `tests/` directory in the archive. Vendor test files are not application tests.
- No application SQL Server database backup or stored procedure definitions were found. The SQL file in the archive belongs to Laravel Sail's PostgreSQL setup.
- Runtime behavior and production configuration may differ from this archive.

## Architecture

| Layer | Implementation |
| --- | --- |
| Framework | Laravel v12.50.0 from composer.lock; PHP requirement ^8.2 |
| Browser frontend | Blade views with page scripts; Vite/Tailwind tooling declared |
| Browser authentication | Laravel session authentication |
| Mobile authentication | Laravel Sanctum v4.3.0 bearer tokens |
| Database | SQL Server (`sqlsrv`), existing business tables and stored procedures |
| PDFs | barryvdh/laravel-dompdf v3.1.2 |
| Images | Intervention Image; local public uploads and remote HTTP image server on port 85 |
| Runtime storage | File cache and file sessions; synchronous queue in packaged environment |

Browser requests use `routes/web.php` and controllers directly under `app/Http/Controllers`. Flutter requests use `/api` routes and controllers under `app/Http/Controllers/Api`. Both share models and the same business database. Business logic is substantially duplicated between the two controller sets.

Key tables include `Online_Tbl_Users`, `HSStock`, `ItemDet`, `ItemStockUpdateDis`, `GoodsReceived`, `VendorInvoices`, `DocumentPrint`, and `Location`, plus home stay data sources. Stored procedure dependencies include `ProcGoodsReceived`, `ProcGrnDetDetails`, `ProcWHGoodsDetails`, and `ProcItemCodeDet`. Copying this ZIP and running migrations alone cannot reproduce the full application database.

## Priority findings

### 1. High: plaintext password handling and inconsistent password changes

`app/Http/Controllers/Api/AuthController.php:38` directly compares `Pwd` with the supplied password. Web login queries the password directly at `app/Http/Controllers/AuthController.php:25`. API user creation/update stores the supplied `Pwd` unchanged.

Reset/change methods instead hash and write `password`, while the User model authenticates using `Pwd` and does not list `password` as fillable. Email reset also uses the conventional `email` field while the model uses `EmailID`, without a corresponding mapping in this model. These flows do not share a consistent credential contract.

Action: design a coordinated migration to hashed credentials in one canonical field, update both login paths and reset/change flows, and validate the legacy database integration before rollout.

### 2. High: approval authorization differs between endpoints

`app/Http/Controllers/Api/UploadgateentrybillController.php:331` restricts `updateStatus` to admins. Separate `approve` and `reject` methods at lines 237 and 268 perform the same status changes without that role check. Their routes are inside the authenticated group, outside the admin group. The response-field middleware does not authorize mutations.

Impact: in this source, an authenticated non-admin can reach approval/rejection operations intended to be admin-only. The web controller has the same separate operation pattern. This was not exercised against production.

Action: apply one shared authorization rule to every status mutation endpoint.

### 3. High: item upload path is derived from unrestricted input

`app/Http/Controllers/Api/ItemStockController.php:341` validates `itemCode` only as a required string, uses it to form a directory under `public/items`, then deletes files in that directory before saving the upload. It lacks a safe-code allowlist and resolved-path containment check. The web upload implementation should be fixed together with the API.

Impact: a user permitted to upload images can supply path components that escape the intended item folder, risking unintended file deletion. Exploitability depends on filesystem permissions; no payload was executed.

Action: validate item identity, reject path separators/traversal, verify containment, and replace only the intended image after a successful upload.

### 4. High: field restrictions do not consistently cover all outputs

`ApplyFieldPermissions.php:24` filters JSON responses only. `FieldPermissionService.php:179` preserves unknown field names. GRN virtual fields omit response keys such as `CostPrice`, `TaxRate`, and `SupplierName`, so these are not protected by that virtual field list when it is used.

The Item Stock PDF explicitly removes MRP, Discount, and Image according to special permissions, but retains other fields from `H.*`; the PDF view renders `ACost` and supplier data without the general field filtering used for JSON. The stock image proxy also has no image-field permission check.

Action: enforce an explicit output allowlist consistently across JSON, PDF, image responses, and derived field aliases. Keep read and write permissions distinct.

### 5. High: archive contains deployment secrets and debug configuration

The ZIP includes `.env`, `bootstrap/cache/config.php`, runtime logs, and a session file. Both `.env` and the cached configuration specify local environment/debug mode. Many controllers include exception messages in API error responses.

Action: distribute a sanitized source package with an example environment file, exclude runtime caches/logs/sessions, and verify production debug mode is disabled. If this archive has been shared outside trusted recipients, assess and rotate affected credentials. No secret values were copied into this report.

### 6. Medium: web login ignores account activation

API login requires `IsActive = 1`; web login does not. Inactive accounts can still match the browser login query. No application-level login throttling was found in the inspected routes/providers. External server rate limits were not assessed.

### 7. Medium: API admin denials return browser redirects

`app/Http/Middleware/RestrictToAdmin.php:16` redirects denied requests to the web dashboard instead of returning a JSON 403 for API callers. This can result in HTML or misleading authentication errors in Flutter.

The users routes do have backend admin middleware. This resolves the earlier mobile review's uncertainty about whether backend user administration is protected; the missing Flutter route guard remains a UX issue.

### 8. Medium: deployment portability and incomplete setup

The directory is named `Controllers/Api`, while namespaces/imports use `Controllers/API`. There is also a filename/class casing difference for `UploadgateentrybillController`. These should be aligned before deployment to a case-sensitive filesystem or regenerating PSR-4 autoload metadata.

Migrations create starter tables such as `users` and `locations`, but application models use legacy business tables such as `Online_Tbl_Users` and `Location`. No application-owned Sanctum token migration appears in the migrations folder; a vendor migration exists. A fresh setup needs a documented schema and migration baseline.

### 9. Medium: several write endpoints have no role check

Beyond the approve/reject gap in finding 2, these authenticated-only routes perform destructive or configuration writes without an admin or permission check in the controller: `DELETE /documentdownload/{id}`, `POST /locations/save`, and `DELETE /locations/{id}`. Only the `/users/*` routes are behind the `admin` middleware. Item Stock writes (`update-mrp`, `update-discount`, `upload-image`) are different: they do check the user's field access.

Action: apply an admin or module-permission rule to these routes, and return the same JSON 403 used elsewhere.

### 10. Medium: user access model has gaps for API clients

The access system (`app/Services/UserAccessService.php`, `config/user_access.php`, `CheckModuleAccess`) is appended to the `api` middleware group. It maps request paths to modules and answers `403` when a user lacks the module, or sends a `locationID` they were not granted. Admins pass everything. This works for the mobile app, with these gaps:

- There is no endpoint that tells a client which locations the current user may see. `GET /dashboard` returns only the allowed module tiles (`data[].slug`) and `is_admin`; `/auth/me` returns the raw user row. Clients must probe location by location. Suggested one-line fix: add `'access' => UserAccessService::accessForUser($user)` to `DashboardController::dashboard()`.
- `GET /locations/all` is not location-filtered and belongs to no module, so every user receives every location.
- Location enforcement relies on a `locationID` request parameter. Endpoints that take no location (documents, home stay lists) are not location-filtered. Stock, Item Stock, Daily Collection, Attendance and the GRN/Gate Entry web pages filter by allowed locations or codes; the Gate Entry and GRN API list endpoints depend on the middleware check alone.
- `profileImage` in the users datatable is built with `asset()`, so its host and port follow `APP_URL` (`http://127.0.0.1:8000` in the archive). A wrong `APP_URL` breaks profile photos for clients; the default avatar is an SVG.

## Flutter integration

- Login's top-level `token` and `user` response matches the Flutter auth controller. It has no `profileImage`; the app reads it from `/auth/me`, which returns the full user row (bare path such as `uploads/users/x.jpg`).
- `/auth/me` returns the profile under `data`, matching Flutter's parser.
- List endpoints use DataTables or conventional page metadata, matching the shared mobile pagination approach.
- GRN detail returns `items` at the top level and requires `locationID`, matching the mobile repository.
- Gate Entry: the API supports `month=YYYY-MM` (one month per call, cached 10 minutes for recent months), which the web list uses and the app now uses too. Rows arrive in stored-procedure order and the web sorts them newest first in the browser; the app sorts the same way.
- Item Stock API image resolution can return the named web `stock.imageProxy` route. Flutter's rewrite to `/api/stock/image-proxy/...` is therefore necessary with this source; preferably the API should return its own authenticated image URL.
- `POST /itemstock/search` returns `permissions.fields` (supplier_name, supplier_mobile, contact_person, markup, markdown, discount, dp_exclusive, mrp, image_upload). The app hides unticked fields and the matching Save buttons from it.
- `POST /users/save` accepts `access_submitted`, `access_modules[]`, `access_fields[module][]` and `access_locations[]`; `GET /users/{id}` returns `access` and `GET /users/access-options` returns the module and location options. The mobile User form uses all three. Access is only replaced when `access_submitted` is sent; each save also deletes the older per-table `user_field_permissions` rows.
- `GET /dashboard` drives the mobile dashboard tiles and drawer links.
- Daily Collection (`GET /daily-collection`) is now built in the app. Attendance, Pearl Stay and Floor Wise Sales remain placeholders.

## Clarification of the earlier live-site observation

`resources/views/itemstock/list.blade.php:816` contains URL-prefill auto-search for `?itemCode=...`. On the earlier live-site check, item data appeared only after manually clicking Search. The ZIP therefore does not establish missing auto-search code as the cause. Compare the deployed view, compiled Blade cache, browser errors, and request timing before changing that flow.

## Suggested order of work

1. Correct approval authorization (findings 2 and 9), upload path handling, and credential handling.
   Add the `access` block to `GET /dashboard` (finding 10) so clients need no location probing.
2. Make field restrictions consistent across API, PDFs, and images.
3. Verify production HTTPS/debug settings and sanitize deployment artifacts.
4. Normalize API errors and web/mobile contracts; reduce duplicate controller logic.
5. Document database/procedure setup and add integration tests using an isolated database.
