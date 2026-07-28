# Ecora — build rules

## What this is
Adult (18+) events/social app for the swinger/lifestyle community. Italian UI.
Flutter (Android-first) + Supabase (Postgres, Auth, Storage). Roles: `cliente` (attendee), `gestore` (host).

## Hard rules
- ZERO BUDGET: free tiers only. Never add paid infra without asking.
- Work in SMALL BLOCKS: one concern per block; every block ends green (analyze + test pass); commit at every green block.
- Before editing files: show a short plan (files + approach) and WAIT for approval.
- Never touch auth, RLS, or payment code without explicitly calling it out first and waiting for approval.
- Domain assumption: gestori are exclusively commercial venues with a public address — no events at private homes. This must be anchored to gestore verification (`is_verified` exists in `profiles` but is not yet enforced anywhere).
- UI: premium dark + gold (tokens at top of lib/main.dart). Consistent across screens. No explicit imagery anywhere (Play Store policy).
- The in-memory `SupabaseClient` mock in lib/main.dart is being REMOVED block by block in favor of real Supabase calls. Never add new features on the mock.
- Any Python tooling: safe Windows console encoding (no crashes on non-ASCII/emoji).

## Commands (Flutter not on PATH)
- Flutter: `C:\Users\FCD\Documents\flutter\bin\flutter.bat`
- Deps: `flutter.bat pub get`
- Analyze: `flutter.bat analyze`
- Test: `flutter.bat test`
- Run (emulator): `flutter.bat run`

## Known landmines
- (resolved) Privacy policy is live on GitHub Pages (`kPrivacyPolicyUrl` in lib/main.dart → `https://fuchs665.github.io/Ecora-2.0/privacy.html`) and the consent link is clickable via `TapGestureRecognizer`.

## Definition of done for a block
Compiles, `analyze` clean, tests pass, diff reviewed by user, committed.

## Current work status
See [docs/AUDIT_2026-07-28.md](docs/AUDIT_2026-07-28.md) and [docs/PIANO_LAVORO.md](docs/PIANO_LAVORO.md) for the current state of the work and the plan going forward.
