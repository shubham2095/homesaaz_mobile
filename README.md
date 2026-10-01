# HomeSaaz Mobile

Flutter Android app for HomeSaaz staff to manage stock, gate entry bills, GRNs, documents, and home stay records. It connects to an external Laravel API; backend source code is not included here.

## Features

| Module | Available functionality |
| --- | --- |
| Authentication | Login, cached profile and profile photo, secure token storage, logout, authenticated navigation |
| Dashboard | Tiles for the modules granted to the signed-in user (admins see all) |
| All Stock Details | Search, filters, paginated tables, item details, images |
| Item Stock | Item lookup, branch stock distribution, image upload, MRP and discount updates, PDF download; fields shown follow the user's Field Access |
| Gate Entry | Warehouse and date filters, newest-first list loaded month by month, entry details with totals and PDF download |
| GRN | Filtered lists, item details and popup, PDF download |
| Upload Gate Entry Bill | Create, edit, view, approve, reject, and delete bills |
| Documents | Filtered lists, details, PDF download |
| Home Stay | Pending rent, student details, bed occupancy, new admission records |
| Daily Collection | Location-wise cash, credit card and cheque totals with search and grand total |
| Attendance | Location and status (Present/Absent/Late/All) filters, search, 4 summary cards, paginated employee list |
| Locations | List, create, edit, and delete locations |
| Users | User management with profile photo and access control (modules, per-module fields, locations); navigation is shown to admins |

Pearl Stay and Floor Wise Sales are dashboard placeholders showing **Coming soon**; their backend endpoints exist but the mobile screens are not built yet. Only the Android platform project is included. The app uses a light theme.

### User access

Admins grant each non-admin user three kinds of access on the User form:

- **Module Access:** which dashboard modules the user can open. Dashboard tiles and drawer links show only these.
- **Field Access:** per-module fields (currently Item Stock: supplier name/mobile, contact person, markup, markdown, discount, DP exclusive, MRP, image upload). Unticked fields and their Save buttons are hidden.
- **Location Access:** the locations whose data the user sees. Location dropdowns (Gate Entry, GRN, All Stock), the Locations list and stock detail rows show only these.

Admins always have full access and their grants are never overwritten from the app. The backend enforces module and location access itself (it answers `403` for anything not granted); the app only decides what to show. Because the API has no "my locations" endpoint, the app finds a user's allowed locations once after login by probing each location and treating `403` as not allowed (`lib/features/access/access_provider.dart`). If the backend adds `access.locations` to `GET /dashboard`, that is used instead.

## Requirements

- Flutter SDK with Dart compatible with `^3.12.2`, as specified in `pubspec.yaml`.
- Android SDK and a compatible Java 17 environment for Android builds.
- Android emulator or physical Android device.
- Access to the HomeSaaz API and a valid staff account.

## Getting started

Run from the repository root:

```sh
flutter doctor
flutter pub get
flutter devices
flutter run
```

Use `flutter run -d <device-id>` when multiple devices are available.

## API configuration

The base URL is defined in `lib/core/config.dart`. Override it at run or build time with `API_BASE_URL`. Include the API prefix; repository endpoints append paths such as `/auth/login` and `/stock/datatable`.

Current default:

```text
http://web.homesaaz.in:84/api
```

To use an HTTPS backend, replace the example hostname with your deployed API host:

```sh
flutter run --dart-define=API_BASE_URL=https://your-api-host.example/api
```

For local development, the Android emulator reaches the host computer at `10.0.2.2`. A physical device needs the computer's reachable LAN address:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api
```

**Local HTTP configuration:** the checked-in Android network security configuration permits cleartext traffic only for HomeSaaz domains. Local HTTP addresses also need an appropriate development-only network security configuration; changing the Dart define alone does not permit them. See `android/app/src/main/res/xml/network_security_config.xml`.

GRN item images use a separate HTTP image service on port `85`, derived from the API hostname. Changing the API host may also require updating the image URL logic in `lib/features/grn/grn_items_screen.dart`.

## Project structure

```text
lib/
  main.dart          Entry point and Riverpod ProviderScope
  app/               App shell, routes, theme, design tokens
  core/              API client, auth storage, providers, formatting, pagination
  features/          Feature screens, forms, and repositories
  widgets/           Shared tables, dialogs, navigation, and list states
android/             Android manifests, resources, and Gradle configuration
assets/
  images/            Branding and dashboard images
  icon/              Launcher icon source images
test/                Flutter tests
```

`build/` and `.dart_tool/` contain generated output and are ignored by Git. Editor settings and machine-specific configuration are also ignored.

## Architecture

- **State and dependencies:** Riverpod providers expose authentication, the API client, repositories, and cached detail requests. Screens also maintain local form and filter state.
- **Access control:** `userAccessProvider` (`lib/features/access/`) loads the user's modules and locations after login; screens read it to filter tiles, links and dropdowns.
- **Navigation:** GoRouter redirects unauthenticated users to login and shows a splash screen while the stored session loads.
- **Networking:** `ApiClient` wraps Dio, injects bearer tokens, normalizes API errors, and supports JSON, multipart uploads, and binary downloads.
- **Authentication storage:** `AuthStore` uses `flutter_secure_storage` for the token and cached profile, with an in-memory token cache.
- **Pagination:** shared parsing supports DataTables and conventional paginated responses. `PagedListView` provides debounced search, refresh, and infinite scrolling.
- **Presentation:** shared theme tokens and `Hs` widgets provide tables, panels, navigation, dialogs, and feedback states.
- **Files and images:** image picking and caching support stock and bill workflows. PDFs are written to temporary storage and opened with an external viewer.

The API must enforce authorization. Hiding admin navigation does not replace server-side permission checks.

## Development checks

```sh
flutter analyze
flutter test
```

After installing dependencies, add `--no-pub` to skip dependency resolution:

```sh
flutter analyze --no-pub
flutter test --no-pub
```

### Last verified status

During the directory review on September 23, 2026:

- `flutter analyze --no-pub` passed with no issues.
- `flutter test --no-pub` failed in the sole test, `test/widget_test.dart`. It expects the `LOGIN` submit button before opening the initially hidden login form. The test needs to open the form before asserting that button is present.
- Live API behavior, device UI, and a release build were not validated.

## Android release build

Configure production signing in `android/app/build.gradle.kts` before distribution. The checked-in release build currently uses debug signing.

Use a deployed HTTPS API for production. The HTTP default transmits credentials and bearer tokens without transport encryption; update the API and image service configuration as part of release preparation.

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-host.example/api
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-api-host.example/api
```

Standard output locations:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App bundle: `build/app/outputs/bundle/release/app-release.aab`

The app version and build number are set in `pubspec.yaml` as `version: 1.0.0+1`.

After changing launcher icon sources in `assets/icon/`, regenerate them with:

```sh
 dart run flutter_launcher_icons
```

## Known follow-up work

- Clear or scope cached detail providers when accounts change.
- Guard paginated searches and refreshes against stale responses from overlapping requests.
- Show retryable pagination and stock filter errors.
- Check widget lifecycle before updating dismissed forms or screens after asynchronous operations.
- Add a role guard for the users route alongside backend authorization.
- Home Stay and Document Download rows are not location-filtered (the backend does not filter them either).
- Gate Entry without a From date loads only the last 6 months (`_defaultMonthsBack` in `gate_entry_repository.dart`).
- `lib/features/users/field_permissions_screen.dart` (old DB-table field permissions editor) is no longer used by the User form.
- Expand tests to cover authentication, pagination, API parsing, and important write workflows.

Android Gradle configuration disables Kotlin incremental compilation to avoid cross-drive path issues when the project and dependency cache are on different Windows drives.
