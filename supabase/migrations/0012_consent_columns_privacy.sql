-- ============================================================================
-- Block 6.2: privacy colonne consenso su profiles (finding rimandato da 6.1)
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale.
--
-- Problema: la policy profiles_select_scoped (0010) filtra le RIGHE (blocchi)
-- ma non le COLONNE: ogni utente non bloccato leggeva anche
-- age_confirmed_at/terms_accepted_at altrui. Sono timestamp di compliance,
-- servono solo lato server: il client li SCRIVE (insert/upsert) ma non li
-- legge mai (SupabaseProfile.fromRow li ignora).
--
-- Fix: privilegi a livello di colonna. Revoke del SELECT tabellare e grant
-- esplicito delle sole colonne non sensibili. Le policy RLS restano invariate
-- (continuano a filtrare le righe); INSERT/UPDATE non sono toccati, quindi
-- la scrittura dei consensi alla registrazione continua a funzionare.
--
-- ATTENZIONE LATO CLIENT: con i grant per colonna, `select=*` di PostgREST
-- fallisce con "permission denied". Il client deve enumerare le colonne:
-- fatto in pari con questo block (kProfileSelectColumns in lib/models.dart).
--
-- NOTA MANUTENZIONE: ogni futura `alter table profiles add column` richiede
-- un grant esplicito della nuova colonna (e l'aggiunta a kProfileSelectColumns
-- se il client deve leggerla).
-- ============================================================================

begin;

revoke select on table public.profiles from anon, authenticated;

grant select (
  id,
  role,
  nickname,
  avatar_url,
  generic_location,
  is_verified,
  created_at,
  profile_type,
  privacy_level
) on public.profiles to authenticated;

commit;

-- Verifica post-apply (SQL Editor):
--   select column_name, privilege_type
--   from information_schema.column_privileges
--   where table_name = 'profiles' and grantee = 'authenticated';
-- Attese: 9 righe SELECT, NESSUNA per age_confirmed_at/terms_accepted_at.
-- Live-probe REST (con access token utente):
--   GET /rest/v1/profiles?select=*                -> 42501 permission denied
--   GET /rest/v1/profiles?select=id,nickname      -> 200
--   GET /rest/v1/profiles?select=age_confirmed_at -> 42501 permission denied
