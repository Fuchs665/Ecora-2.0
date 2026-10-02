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
- UI: design system v2 "Club privato" — bottle green + brass, Bodoni Moda italic titles, Hanken Grotesk text, generated "Luce" covers, 3D only in three purposeful moments. Tokens in lib/theme.dart (names match the spec); spec: design system "Ecora" at https://claude.ai/artifact/A2MsQoNJfUDiyyN5849dgW (private to the owner). test/theme_test.dart guards WCAG contrast. Consistent across screens. No explicit imagery anywhere (Play Store policy).
- The in-memory `SupabaseClient` mock in lib/main.dart is being REMOVED block by block in favor of real Supabase calls. Never add new features on the mock.
- Any Python tooling: safe Windows console encoding (no crashes on non-ASCII/emoji).

## Supabase access (connector)
The connector can reach every project in the "Fuchs" org. Only Ecora is in scope.
- **K-Hub** (`yiysqhbtmjdpooznsgbg`): never call any tool on it.
- **Local staging** (Postgres in the cloud container, never the user's PC): free to apply migrations,
  run SQL and tests. Synthetic data only — never copy production data.
  Every new migration must pass the full chain 0000→N there first.
- **Production Ecora** (`fswzykzclfrpzlufjhfg`), allowed only after the change
  has passed local staging AND the user has approved that specific change in
  the current conversation:
  - apply migrations from `supabase/migrations/` exactly as committed (no ad-hoc DDL);
  - deploy Edge Functions from `supabase/functions/` exactly as committed;
  - read-only queries on schema, grants, policies, triggers; read logs and advisors.
- **Production, never:** read, export or modify rows of user data (profiles,
  events, event_requests, event_attendance, messages, blocks, device_tokens,
  subscriptions, account_deletions, reports, storage objects, auth.users);
  change auth settings, API keys, secrets, webhooks, billing or project
  settings; disable RLS; create, pause, restore or delete projects; create or
  merge branches. Only exception: a documented manual procedure (e.g.
  supabase/CANCELLAZIONE_MANUALE.md) run on the user's explicit request for
  one named account.
- Every production change: announce what and where → wait for "ok" → apply →
  run the VERIFICA queries of that migration → report the result → record it in
  docs/PIANO_LAVORO.md.
- The auth/RLS/payments rule above still applies.

## Commands (Flutter not on PATH)
- Flutter: `C:\Users\FCD\Documents\flutter\bin\flutter.bat`
- Deps: `flutter.bat pub get`
- Analyze: `flutter.bat analyze`
- Test: `flutter.bat test`
- Run (emulator): `flutter.bat run`
- Cloud sessions (the user works only in the cloud, not on the company PC): `.claude/hooks/session-start.sh` installs Flutter (`/opt/flutter-sdk/flutter/bin/flutter`), Deno (`/opt/deno/deno`) and a local Postgres 16 for SQL tests (`psql -h /var/tmp/ecora-pg -p 54329 -U postgres`). After `flutter analyze/test` run `git checkout -- analysis_options.yaml pubspec.lock` (the newer SDK rewrites them).

## Known landmines
- (resolved) Privacy policy is live on GitHub Pages (`kPrivacyPolicyUrl` in lib/main.dart → `https://fuchs665.github.io/Ecora-2.0/privacy.html`) and the consent link is clickable via `TapGestureRecognizer`.

## Definition of done for a block
Compiles, `analyze` clean, tests pass, diff reviewed by user, committed.

## Current work status
See [docs/AUDIT_2026-07-28.md](docs/AUDIT_2026-07-28.md) and [docs/PIANO_LAVORO.md](docs/PIANO_LAVORO.md) for the current state of the work and the plan going forward.
