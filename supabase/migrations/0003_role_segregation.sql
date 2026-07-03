-- ============================================================================
-- Block 3.1: segregazione ruoli + hardening RLS della tabella events
-- Run in: Supabase Dashboard -> SQL Editor.
-- Transazionale: se qualcosa fallisce, rollback completo (trigger incluso).
--
-- Contesto: il vocabolario ruoli del DB (user_single/user_couple/
-- business_locale) non era mai stato allineato a quello di app e policy
-- (cliente/gestore). Inoltre la policy events "L'organizzatore gestisce i
-- propri eventi" era FOR ALL USING (auth.uid()=host_id) SENZA with_check:
-- Postgres riusa la USING come check di INSERT, quindi qualunque utente
-- poteva creare un evento nominandosi host, senza controllo di ruolo.
-- ============================================================================

begin;

-- 1) NORMALIZZAZIONE RUOLI (legacy -> cliente/gestore).
--    Il trigger trigger_proteggi_profilo reverte i cambi di role se chi
--    scrive non e' service_role (nel SQL Editor current_setting('role')
--    vale 'none'): lo disabilitiamo SOLO dentro questa transazione.
--    La colonna ha anche un CHECK constraint (profiles_role_check) che
--    ammette solo il vocabolario legacy: va rimosso prima di scrivere i
--    nuovi valori e ricreato DOPO, quando tutte le righe sono già pulite
--    (altrimenti la validazione fallirebbe contro le righe legacy ancora
--    presenti nello stesso momento).
alter table public.profiles drop constraint if exists profiles_role_check;

alter table public.profiles disable trigger trigger_proteggi_profilo;
update public.profiles set role = 'cliente' where role in ('user_single', 'user_couple');
update public.profiles set role = 'gestore' where role = 'business_locale';
alter table public.profiles enable trigger trigger_proteggi_profilo;

alter table public.profiles add constraint profiles_role_check
  check (role in ('cliente', 'gestore'));

-- 2) Helper SECURITY DEFINER: legge il ruolo bypassando la RLS di profiles,
--    cosi' le policy non dipendono dal fatto che profiles resti leggibile.
create or replace function public.is_gestore()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role = 'gestore'
  );
$$;
grant execute on function public.is_gestore() to authenticated;

-- 3) EVENTS: via le 5 policy ambigue, ricreate esplicite.
drop policy if exists "Consenti inserimento/modifica solo ai gestori" on public.events;
drop policy if exists "Consenti lettura eventi a tutti"               on public.events;
drop policy if exists "Consentiti eventi in lettura a tutti"          on public.events;
drop policy if exists "L'organizzatore gestisce i propri eventi"      on public.events;
drop policy if exists "Tutti vedono gli eventi pubblicati"            on public.events;

-- SELECT: pubblicati visibili a tutti; le bozze solo al proprio host
create policy "events_select_published" on public.events
  for select to anon, authenticated
  using (status = 'published');
create policy "events_select_own" on public.events
  for select to authenticated
  using (auth.uid() = host_id);

-- INSERT: solo gestori, e solo come host di se stessi
create policy "events_insert_gestore" on public.events
  for insert to authenticated
  with check (auth.uid() = host_id and public.is_gestore());

-- UPDATE / DELETE: solo i propri eventi, e solo se gestore
create policy "events_update_own" on public.events
  for update to authenticated
  using (auth.uid() = host_id and public.is_gestore())
  with check (auth.uid() = host_id and public.is_gestore());
create policy "events_delete_own" on public.events
  for delete to authenticated
  using (auth.uid() = host_id and public.is_gestore());

-- 4) EVENT_REQUESTS: via la INSERT debole (permetteva auto-inserirsi gia'
--    come 'approved') e i duplicati; l'approvazione ora richiede il ruolo.
drop policy if exists "Gli utenti possono richiedere di partecipare" on public.event_requests;
drop policy if exists "L'organizzatore può approvare le richieste"   on public.event_requests;
drop policy if exists "Lettura richieste protetta"                   on public.event_requests;
drop policy if exists "Solo il gestore approva o rifiuta"            on public.event_requests;

create policy "event_requests_review_by_gestore" on public.event_requests
  for update to authenticated
  using (
    public.is_gestore()
    and exists (select 1 from public.events e
                where e.id = event_requests.event_id and e.host_id = auth.uid())
  )
  with check (
    public.is_gestore()
    and exists (select 1 from public.events e
                where e.id = event_requests.event_id and e.host_id = auth.uid())
  );
-- restano intatte:
--   "Clienti possono solo candidarsi"                      (INSERT, status=pending)
--   "Regola blindata per la visibilità dei partecipanti"  (SELECT)

-- 5) PROFILES: rimuovi i duplicati di SELECT/UPDATE (comportamento invariato).
drop policy if exists "Modifica solo il tuo profilo"                on public.profiles;
drop policy if exists "Profili visibili a tutti gli utenti loggati" on public.profiles;
-- restano:
--   "Consenti aggiornamento solo al proprietario"    (UPDATE, auth.uid()=id)
--   "Consenti lettura profili a utenti autenticati"  (SELECT)
--   "Ogni utente crea solo il proprio profilo"       (INSERT, migration 0002)

-- 6) PULIZIA DATI: elimina l'evento orfano creato sfruttando la vecchia falla
--    ("Exclusive Gold Night", host M&L che dopo la normalizzazione e' cliente).
--    Prima le richieste collegate (evita conflitti di foreign key), poi l'evento.
delete from public.event_requests
  where event_id in (select id from public.events where title = 'Exclusive Gold Night');
delete from public.events where title = 'Exclusive Gold Night';

commit;
