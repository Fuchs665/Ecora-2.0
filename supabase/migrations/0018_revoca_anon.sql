-- ============================================================================
-- Blocco S.4: niente ad anon, meno privilegi ad authenticated.
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA PERMESSI E RLS. Nessuna policy viene cambiata.
--
-- Stato trovato il 02/10/2026 (schema base, Blocco S.1):
--   - anon aveva tutti i permessi su events, event_requests, messages,
--     blocks, device_tokens e la scrittura su profiles (permessi automatici
--     di Supabase). Le policy coprono solo authenticated, quindi oggi non
--     entrava; ma una policy futura "to public" lo farebbe entrare subito.
--   - authenticated aveva anche TRUNCATE (che non passa dalla RLS),
--     TRIGGER e REFERENCES sulle stesse tabelle.
--   - is_approved_for_event (SECURITY DEFINER, creata dalla dashboard)
--     eseguibile da PUBLIC e anon, senza search_path fisso.
--   - get_events_within_radius (creata dalla dashboard, non usata)
--     eseguibile da PUBLIC, anon e authenticated.
-- L'app usa tabelle e funzioni solo dopo il login (authenticated); la
-- pagina web di cancellazione pure (login, poi Edge Function).
--
-- In più (approvato il 02/10/2026): i privilegi di default di postgres in
-- public non danno più nulla ad anon sulle tabelle e sequenze create da qui
-- in avanti. authenticated e service_role restano. Quelli di supabase_admin
-- sono della piattaforma e non si toccano.
-- LIMITE per le funzioni: i privilegi di default per schema possono solo
-- aggiungere, non togliere quelli di base di Postgres, e ogni funzione nuova
-- resta eseguibile da PUBLIC (quindi da anon). Qui si toglie solo il grant
-- esplicito ad anon; ogni migrazione che crea una funzione deve continuare a
-- scrivere "revoke execute ... from public, anon" (come 0013, 0015, 0016).
-- ============================================================================

begin;

-- 1) Tabelle: niente ad anon ------------------------------------------------------
revoke all on table
  public.events, public.event_requests, public.messages,
  public.blocks, public.device_tokens, public.profiles
  from anon;

-- 2) Tabelle: authenticated senza TRUNCATE, TRIGGER, REFERENCES -------------------
--    SELECT/INSERT/UPDATE/DELETE restano, governati dalle policy (su
--    profiles la lettura resta per colonna, 0012/0015).
revoke truncate, trigger, references on table
  public.events, public.event_requests, public.messages,
  public.blocks, public.device_tokens, public.profiles
  from authenticated;

-- 3) is_approved_for_event: solo authenticated (la usano le policy) ---------------
revoke execute on function public.is_approved_for_event(uuid) from public, anon;
grant execute on function public.is_approved_for_event(uuid) to authenticated;
alter function public.is_approved_for_event(uuid) set search_path = public;

-- 4) get_events_within_radius: non usata, nessun client la chiama ----------------
revoke execute on function
  public.get_events_within_radius(double precision, double precision, double precision)
  from public, anon, authenticated;

-- 5) Oggetti futuri creati da postgres in public: niente ad anon ------------------
alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- ============================================================================
-- a) nessun permesso di anon sulle tabelle di public (attese 0 righe):
--   select table_name, privilege_type from information_schema.role_table_grants
--   where table_schema = 'public' and grantee = 'anon';
--
-- b) authenticated senza TRUNCATE/TRIGGER/REFERENCES (attese 0 righe):
--   select table_name, privilege_type from information_schema.role_table_grants
--   where table_schema = 'public' and grantee = 'authenticated'
--     and privilege_type in ('TRUNCATE', 'TRIGGER', 'REFERENCES');
--
-- c) funzioni (attese: false, false, true | false, false):
--   select has_function_privilege('anon', 'public.is_approved_for_event(uuid)', 'execute'),
--          has_function_privilege('public', 'public.is_approved_for_event(uuid)', 'execute'),
--          has_function_privilege('authenticated', 'public.is_approved_for_event(uuid)', 'execute'),
--          has_function_privilege('anon', 'public.get_events_within_radius(double precision, double precision, double precision)', 'execute'),
--          has_function_privilege('authenticated', 'public.get_events_within_radius(double precision, double precision, double precision)', 'execute');
--
-- d) privilegi di default di postgres in public: anon assente ovunque:
--   select defaclobjtype, defaclacl from pg_default_acl
--   where defaclrole = 'postgres'::regrole
--     and defaclnamespace = 'public'::regnamespace;
--
-- Prove di comportamento: supabase/tests/0018_revoca_anon_test.sql
-- (Postgres locale, mai su Supabase).
-- ============================================================================
