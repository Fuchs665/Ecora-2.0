-- ============================================================================
-- Blocco V.1: solo i locali verificati pubblicano (profiles.is_verified).
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA RLS: cinque policy ricreate con lo stesso nome, la funzione
-- SECURITY DEFINER get_events_with_stats() e due funzioni nuove.
--
-- Problema: is_verified (ruolo e verifica li cambia solo service_role,
-- 0017) non era letto da nessuna parte: role = 'gestore' bastava per tutto.
-- I Termini (punto 4) dicono che l'account del locale lo attiviamo noi dopo
-- averlo verificato (locale commerciale con indirizzo pubblico, mai
-- un'abitazione), e l'unico modo di sospendere un locale era annullarne a
-- mano le serate.
--
-- Significato: is_verified = true vuol dire locale controllato da noi.
-- Toglierlo SOSPENDE il locale: le sue serate spariscono subito per gli
-- iscritti, senza cancellare nulla; rimetterlo le fa ricomparire.
--
-- Fix:
--   - host_is_verified(uuid) e is_verified_gestore() (SECURITY DEFINER,
--     solo authenticated);
--   - events_insert_gestore: serve il gestore verificato (oltre
--     all'abbonamento);
--   - events_update_own: lo stato 'published' richiede la verifica (un
--     locale sospeso può annullare una serata, non pubblicarla né
--     modificarne una pubblicata);
--   - events_select_published e get_events_with_stats(): solo serate di
--     locali verificati (la funzione ignora la RLS, quindi va filtrata
--     anche lei);
--   - event_requests_review_by_gestore: serve il gestore verificato;
--   - "Clienti possono solo candidarsi": solo a serate pubblicate di locali
--     verificati (prima una chiamata diretta poteva candidarsi a una serata
--     invisibile);
--   - event_covers_insert_gestore (storage): serve il gestore verificato.
-- Invariati: events_delete_own, events_select_own, chat, presenze.
--
-- PRIMA DI APPLICARE in produzione: contare i gestori non verificati (query
-- in fondo, PRE-VERIFICA). Le loro serate spariscono appena applicata.
-- ============================================================================

begin;

-- 1) Funzioni ----------------------------------------------------------------------
create or replace function public.host_is_verified(p_host uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = p_host and role = 'gestore' and is_verified is true
  );
$$;

revoke execute on function public.host_is_verified(uuid) from public, anon;
grant execute on function public.host_is_verified(uuid) to authenticated;

create or replace function public.is_verified_gestore()
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select public.host_is_verified(auth.uid()); $$;

revoke execute on function public.is_verified_gestore() from public, anon;
grant execute on function public.is_verified_gestore() to authenticated;

-- 2) events ----------------------------------------------------------------------------
drop policy if exists "events_insert_gestore" on public.events;
create policy "events_insert_gestore" on public.events
  for insert to authenticated
  with check (
    auth.uid() = host_id
    and public.is_verified_gestore()
    and public.has_active_subscription()
  );

drop policy if exists "events_update_own" on public.events;
create policy "events_update_own" on public.events
  for update to authenticated
  using (auth.uid() = host_id and public.is_gestore())
  with check (
    auth.uid() = host_id
    and public.is_gestore()
    and (status is distinct from 'published' or public.is_verified_gestore())
  );

drop policy if exists "events_select_published" on public.events;
create policy "events_select_published" on public.events
  for select to authenticated
  using (
    status = 'published'
    and not public.is_blocked_with(host_id)
    and public.host_is_verified(host_id)
  );

-- Stessa firma, stessi permessi (solo authenticated, 0014): cambia solo il
-- filtro.
create or replace function public.get_events_with_stats()
returns table (
  id uuid, host_id uuid, title text, description text,
  event_date timestamptz, max_guests int, status text,
  latitude double precision, longitude double precision,
  image_url text, location_name text, approved_count bigint
)
language sql security definer set search_path = public as $$
  select e.id, e.host_id, e.title, e.description, e.event_date,
         e.max_guests, e.status, e.latitude, e.longitude,
         e.image_url, e.location_name,
         (select count(*) from event_requests r
           where r.event_id = e.id and r.status = 'approved') as approved_count
  from events e
  where e.status = 'published'
    and not public.is_blocked_with(e.host_id)
    and public.host_is_verified(e.host_id);
$$;

-- 3) event_requests ------------------------------------------------------------------------
drop policy if exists "event_requests_review_by_gestore" on public.event_requests;
create policy "event_requests_review_by_gestore" on public.event_requests
  for update to authenticated
  using (
    public.is_verified_gestore()
    and exists (select 1 from public.events e
                where e.id = event_requests.event_id and e.host_id = auth.uid())
  )
  with check (
    public.is_verified_gestore()
    and exists (select 1 from public.events e
                where e.id = event_requests.event_id and e.host_id = auth.uid())
  );

drop policy if exists "Clienti possono solo candidarsi" on public.event_requests;
create policy "Clienti possono solo candidarsi" on public.event_requests
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and status = 'pending'
    and not public.is_blocked_with(
      (select e.host_id from public.events e where e.id = event_requests.event_id))
    and exists (select 1 from public.events e
                where e.id = event_requests.event_id
                  and e.status = 'published'
                  and public.host_is_verified(e.host_id))
  );

-- 4) Copertine delle serate -----------------------------------------------------------------
drop policy if exists "event_covers_insert_gestore" on storage.objects;
create policy "event_covers_insert_gestore" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'event_covers' and public.is_verified_gestore());

commit;

-- ============================================================================
-- PRE-VERIFICA (prima di applicare, SQL Editor). Solo conteggi: quanti
-- gestori non sono verificati e quante serate pubblicate hanno. Se il
-- primo numero non è 0, verificare quei locali prima (supabase/VERIFICA_LOCALI.md).
--   select count(*) filter (where is_verified is not true) as gestori_non_verificati,
--          count(*) as gestori
--   from public.profiles where role = 'gestore';
--   select count(*) as serate_pubblicate_di_non_verificati
--   from public.events e join public.profiles p on p.id = e.host_id
--   where e.status = 'published' and p.is_verified is not true;
--
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- a) policy ricreate (attese 6 righe, con is_verified_gestore() o
--    host_is_verified() nella condizione):
--   select tablename, policyname, qual, with_check from pg_policies
--   where policyname in ('events_insert_gestore', 'events_update_own',
--     'events_select_published', 'event_requests_review_by_gestore',
--     'Clienti possono solo candidarsi', 'event_covers_insert_gestore');
--
-- b) funzioni nuove: secdef, search_path, niente anon (attese 2 righe):
--   select proname, prosecdef, proconfig, proacl from pg_proc
--   where pronamespace = 'public'::regnamespace
--     and proname in ('host_is_verified', 'is_verified_gestore');
--
-- c) get_events_with_stats filtra i locali verificati (attesa true):
--   select pg_get_functiondef('public.get_events_with_stats()'::regprocedure)
--          like '%host_is_verified%';
--
-- Prove di comportamento: supabase/tests/0021_gestori_verificati_test.sql
-- (Postgres locale, mai su Supabase).
