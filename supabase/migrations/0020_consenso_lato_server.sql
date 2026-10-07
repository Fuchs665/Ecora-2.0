-- ============================================================================
-- Blocco E.4a: consensi scritti dal server (audit A1) e riaccettazione dei
-- Termini (E.3c).
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA AUTH/RLS: trigger su profiles e funzioni SECURITY DEFINER. Nessuna
-- policy cambiata, nessun grant di tabella cambiato.
--
-- Problema: age_confirmed_at e terms_accepted_at li scriveva l'app (insert
-- in registrazione, upsert al primo accesso con i valori dei metadati auth,
-- che l'utente può riscrivere). authenticated ha l'UPDATE dell'intera
-- tabella profiles, quindi poteva cambiarli quando voleva: la traccia non
-- era probatoria. In più non si sapeva quale versione dei Termini fosse
-- stata accettata, e chi si è iscritto prima di E.3 ha accettato Termini
-- che non esistevano.
--
-- Fix:
--   - colonne nuove terms_version (versione accettata) e
--     sensitive_consent_at (consenso esplicito art. 9 GDPR, separato dai
--     Termini). Nessun grant di SELECT: come per i timestamp della 0012,
--     l'app non le legge;
--   - current_terms_version(): la versione in vigore. Quando i Termini
--     cambiano in modo sostanziale, una nuova migrazione la alza;
--   - accept_terms(p_version): unico modo per scrivere i quattro campi,
--     sempre con now() del server. Rifiuta una versione diversa da quella
--     in vigore (22023), l'assenza di sessione (42501) e il profilo
--     mancante (P0002);
--   - terms_to_accept(): null se l'utente collegato è in regola, altrimenti
--     la versione da accettare (l'app non la scrive mai nel codice);
--   - trigger proteggi_consensi (SECURITY INVOKER): se chi scrive è
--     authenticated o anon, all'INSERT i quattro campi diventano null e
--     all'UPDATE tornano com'erano, senza errore (come la 0017). Dentro
--     accept_terms current_user è il proprietario della funzione, quindi
--     passa; service_role e il SQL Editor pure.
--
-- Righe esistenti: non toccate. terms_version è null per tutti, quindi
-- tutti (gestori compresi) dovranno accettare i Termini al primo accesso;
-- in quel momento age_confirmed_at e terms_accepted_at vengono riscritti
-- con l'ora del server.
-- ============================================================================

begin;

-- 1) Colonne ---------------------------------------------------------------------
alter table public.profiles add column if not exists terms_version text;
alter table public.profiles add column if not exists sensitive_consent_at timestamptz;

-- 2) Versione in vigore dei Termini -------------------------------------------------
--    Uguale alla data "Ultimo aggiornamento" di docs/terms.html.
create or replace function public.current_terms_version()
returns text
language sql
stable
set search_path = public
as $$ select '2026-10-06'::text $$;

revoke execute on function public.current_terms_version() from public, anon;
grant execute on function public.current_terms_version() to authenticated;

-- 3) Protezione dei campi di consenso -------------------------------------------------
create or replace function public.proteggi_consensi()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  -- current_user è authenticated/anon solo per le scritture dirette
  -- dell'app; dentro accept_terms (SECURITY DEFINER) è il proprietario.
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.age_confirmed_at := null;
      new.terms_accepted_at := null;
      new.terms_version := null;
      new.sensitive_consent_at := null;
    else
      new.age_confirmed_at := old.age_confirmed_at;
      new.terms_accepted_at := old.terms_accepted_at;
      new.terms_version := old.terms_version;
      new.sensitive_consent_at := old.sensitive_consent_at;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function public.proteggi_consensi() from public, anon;

drop trigger if exists trg_profiles_proteggi_consensi on public.profiles;
create trigger trg_profiles_proteggi_consensi
  before insert or update on public.profiles
  for each row execute function public.proteggi_consensi();

-- 4) Accettazione ------------------------------------------------------------------------
--    Un atto unico: Termini, Privacy, 18+ e consenso art. 9 sono tutte
--    caselle obbligatorie, in registrazione e nella schermata
--    "Termini aggiornati".
create or replace function public.accept_terms(p_version text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'sessione assente' using errcode = '42501';
  end if;
  if p_version is distinct from public.current_terms_version() then
    raise exception 'versione dei Termini non in vigore' using errcode = '22023';
  end if;
  update public.profiles
     set terms_version = p_version,
         terms_accepted_at = now(),
         age_confirmed_at = now(),
         sensitive_consent_at = now()
   where id = uid;
  if not found then
    raise exception 'profilo assente' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.accept_terms(text) from public, anon;
grant execute on function public.accept_terms(text) to authenticated;

-- 5) Cosa resta da accettare ----------------------------------------------------------------
create or replace function public.terms_to_accept()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  versione text;
begin
  if uid is null then
    raise exception 'sessione assente' using errcode = '42501';
  end if;
  select terms_version into versione from public.profiles where id = uid;
  if versione is not distinct from public.current_terms_version() then
    return null;
  end if;
  return public.current_terms_version();
end;
$$;

revoke execute on function public.terms_to_accept() from public, anon;
grant execute on function public.terms_to_accept() to authenticated;

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- ============================================================================
-- a) colonne nuove, nessun SELECT per authenticated (attese 0 righe):
--   select column_name from information_schema.column_privileges
--   where table_schema = 'public' and table_name = 'profiles'
--     and grantee in ('anon', 'authenticated') and privilege_type = 'SELECT'
--     and column_name in ('age_confirmed_at', 'terms_accepted_at',
--                         'terms_version', 'sensitive_consent_at');
--
-- b) trigger presente (attesa 1 riga, "BEFORE INSERT OR UPDATE"):
--   select pg_get_triggerdef(oid) from pg_trigger
--   where tgrelid = 'public.profiles'::regclass
--     and tgname = 'trg_profiles_proteggi_consensi';
--
-- c) funzioni: chi le esegue e search_path (attese 4 righe; anon mai
--    presente; accept_terms e terms_to_accept secdef = true):
--   select p.proname, p.prosecdef, p.proconfig, p.proacl
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in ('current_terms_version', 'proteggi_consensi',
--                       'accept_terms', 'terms_to_accept');
--
-- d) versione in vigore (attesa '2026-10-06'):
--   select public.current_terms_version();
--
-- Prove di comportamento: supabase/tests/0020_consenso_lato_server_test.sql
-- (Postgres locale, mai su Supabase).
