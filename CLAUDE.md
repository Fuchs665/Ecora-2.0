# Ecora — build rules

## What this is
Adult (18+) events/social app for the swinger/lifestyle community. Italian UI.
Flutter (Android-first) + Supabase (Postgres, Auth, Storage). Roles: `cliente` (attendee), `gestore` (host).

## Hard rules
- ZERO BUDGET: free tiers only. Never add paid infra without asking.
- Work in SMALL BLOCKS: one concern per block; every block ends green (analyze + test pass); commit at every green block.
- Before editing files: show a short plan (files + approach) and WAIT for approval.
- Never touch auth, RLS, or payment code without explicitly calling it out first.
- UI: premium dark + gold (tokens at top of lib/main.dart). Consistent across screens. No explicit imagery anywhere (Play Store policy).
- The in-memory `SupabaseClient` mock in lib/main.dart is being REMOVED block by block in favor of real Supabase calls. Never add new features on the mock.
- Any Python tooling: safe Windows console encoding (no crashes on non-ASCII/emoji).

## Commands (Flutter not on PATH)
- Flutter: `C:\src\flutter\flutter\bin\flutter.bat`
- Deps: `flutter.bat pub get`
- Analyze: `flutter.bat analyze`
- Test: `flutter.bat test`
- Run (emulator): `flutter.bat run`

## Known landmines
- `android/` was generated with the default applicationId `com.example.ecora` — must be changed before release (Play Console requires a unique id you own).
- Event coordinates are still randomized near Florence on creation (no geocoding yet); cover images are a preset list, not real uploads.

## Definition of done for a block
Compiles, `analyze` clean, tests pass, diff reviewed by user, committed.
