-- ============================================================================
-- Block 3.7: colonne di consenso (18+ e Privacy/Termini) su profiles
-- Run in: Supabase Dashboard -> SQL Editor. Idempotente.
--
-- Il consenso viene raccolto alla registrazione (checkbox obbligatorie) e
-- salvato come metadato auth (sopravvive al gap della conferma email), poi
-- rispecchiato qui quando la riga profilo viene creata. Timestamp non nullo
-- = consenso dato in quel momento (traccia per compliance Play Store).
-- ============================================================================

alter table public.profiles add column if not exists age_confirmed_at  timestamptz;
alter table public.profiles add column if not exists terms_accepted_at timestamptz;
