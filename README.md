# Bayan RME

Flutter implementation of the **Bayan RME — Alur Klinis** design
(`project/Bayan RME - Alur Klinis (Standalone).html` in the design handoff
bundle at the repo root). One app, four roles chosen automatically from the
logged-in account: **Perawat** (nurse intake), **Dokter** (diagnosis &
prescription), **Apotek** (pharmacy fulfillment), **Lab** (results). Built
tablet-first (side nav rail + master-detail lists, matching the prototype)
with a responsive phone fallback (bottom nav + single-pane navigation),
targeting Android and iOS.

## Running it

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api-host
```

If `--dart-define=API_BASE_URL` is omitted, it defaults to
`http://127.0.0.1:8080` (the dev address from the API spec). Notes:

- **Android emulator**: the emulator's own loopback is `127.0.0.1`, not your
  host machine's. To reach a server running on your host, use
  `--dart-define=API_BASE_URL=http://10.0.2.2:8080` instead.
- **iOS simulator**: `127.0.0.1` correctly reaches your host machine, so the
  default works as-is.
- **Physical devices**: point at your host's real LAN IP or a deployed URL.

## What's real vs. mock

- **Login is a real API integration**: `POST {API_BASE_URL}/api/v1/auth/login`
  with `{ email, password }`, expecting `{ token, user: { id, name, email,
  role } }` back. The session (token + user) is persisted on-device via
  `flutter_secure_storage` so it survives app restarts ("Ingat saya" toggles
  whether this happens). `role` must be one of `perawat` / `dokter` /
  `pharmacy` / `lab` — that's the only input that decides which app the user
  sees; there is no manual role picker anywhere in this build.
- **Patient records are connected directly to the API**: `GET /api/v1/patients`,
  `POST /api/v1/patients`, and `POST /api/v1/patients/{id}/medical-records`
  (`lib/features/patients/data/patient_repository.dart`) with pagination
  and infinite load-more scroll support.
- **The on-duty doctor directory** (`lib/features/patients/domain/
  doctor.dart`) used for Perawat's "assign dokter" dropdown is also seed
  data with placeholder emails. A signed-in Dokter account is matched to
  this directory by email (`resolveDoctorId`) so "Pasien" shows the
  right patients; update those emails (or wire this to a real staff
  directory) to match your actual doctor accounts.

## Structure

```
lib/
  core/            theme, shared widgets, network client, responsive helpers
  features/
    auth/          login form, session persistence, role resolution
    patients/      domain models + mock repository shared by every role
    perawat/        }
    dokter/         }  one folder per role: home screen + role-specific
    pharmacy/       }  detail/forms
    lab/            }
    profile/       shared "Profil" screen (logout) reused by all 4 roles
    shell/         side-nav-rail (tablet) / bottom-nav (phone) app shell
```

## Tests

```bash
flutter analyze
flutter test
```

`test/responsive_layout_test.dart` pumps the login screen and all 4 role
home screens at both a phone-sized (390×844) and tablet-sized (1180×820)
viewport and fails on any layout overflow, since that's the actual
breakpoint behavior the app ships with.
