-- ============================================================================
-- Block 3.8a: blocco utenti (bidirezionale) — infrastruttura database
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale.
--
-- Il blocco e' bidirezionale: se A blocca B, ne' A vede i contenuti di B
-- ne' B vede quelli di A. L'helper is_blocked_with() controlla entrambe le
-- direzioni ed e' SECURITY DEFINER (legge blocks bypassando la sua RLS).
--
-- PUNTO CRITICO: gli eventi lato cliente arrivano dalla RPC
-- get_events_with_stats(), che e' SECURITY DEFINER e BYPASSA la RLS della
-- tabella events. Il filtro-blocco va quindi messo ANCHE dentro la RPC,
-- non basta la policy sulla tabella.
-- ============================================================================

begin;

-- 1) TABELLA BLOCCHI
create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
alter table public.blocks enable row level security;

-- Solo tu gestisci/vedi i TUOI blocchi (chi ti ha bloccato resta nascosto).
drop policy if exists "blocks_select_own" on public.blocks;
drop policy if exists "blocks_insert_own" on public.blocks;
drop policy if exists "blocks_delete_own" on public.blocks;
create policy "blocks_select_own" on public.blocks
  for select to authenticated using (auth.uid() = blocker_id);
create policy "blocks_insert_own" on public.blocks
  for insert to authenticated with check (auth.uid() = blocker_id);
create policy "blocks_delete_own" on public.blocks
  for delete to authenticated using (auth.uid() = blocker_id);

-- 2) HELPER: blocco in ENTRAMBE le direzioni.
--    Con auth.uid() = se stessi ritorna false (vedi sempre i tuoi contenuti);
--    con anon (auth.uid() null) ritorna false (nessuna regressione).
create or replace function public.is_blocked_with(other uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from public.blocks
    where (blocker_id = auth.uid() and blocked_id = other)
       or (blocker_id = other and blocked_id = auth.uid())
  );
$$;
grant execute on function public.is_blocked_with(uuid) to authenticated, anon;

-- 3) RPC EVENTI: aggiunge il filtro-blocco (la RPC bypassa la RLS).
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
    and not public.is_blocked_with(e.host_id);
$$;
grant execute on function public.get_events_with_stats() to authenticated, anon;

-- 4) POLICY EVENTS SELECT: pubblicati visibili solo se non c'e' blocco.
drop policy if exists "events_select_published" on public.events;
create policy "events_select_published" on public.events
  for select to anon, authenticated
  using (status = 'published' and not public.is_blocked_with(host_id));

-- 5) EVENT_REQUESTS INSERT: un bloccato non puo' candidarsi ai tuoi eventi.
drop policy if exists "Clienti possono solo candidarsi" on public.event_requests;
create policy "Clienti possono solo candidarsi" on public.event_requests
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and status = 'pending'
    and not public.is_blocked_with(
      (select e.host_id from public.events e where e.id = event_id))
  );

-- 6) EVENT_REQUESTS SELECT: non vedi candidati bloccati (e viceversa).
drop policy if exists "Regola blindata per la visibilità dei partecipanti" on public.event_requests;
create policy "Regola blindata per la visibilità dei partecipanti" on public.event_requests
  for select to authenticated
  using (
    (
      auth.uid() = user_id
      or exists (select 1 from public.events e
                 where e.id = event_requests.event_id and e.host_id = auth.uid())
      or (status = 'approved' and public.is_approved_for_event(event_id))
    )
    and not public.is_blocked_with(user_id)
  );

-- 7) MESSAGES SELECT: non vedi i messaggi di chi hai bloccato.
drop policy if exists "Messaggi leggibili da host e partecipanti approvati" on public.messages;
create policy "Messaggi leggibili da host e partecipanti approvati" on public.messages
  for select to authenticated
  using (
    (
      exists (select 1 from public.events e
              where e.id = messages.event_id and e.host_id = auth.uid())
      or public.is_approved_for_event(event_id)
    )
    and not public.is_blocked_with(sender_id)
  );

commit;
