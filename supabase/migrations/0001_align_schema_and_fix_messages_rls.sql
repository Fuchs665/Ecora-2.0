-- ============================================================================
-- Block 1.1: schema alignment + messages RLS fix
-- Run in: Supabase Dashboard -> SQL Editor
-- Idempotent: safe to re-run.
-- ============================================================================

-- 1) Role vocabulary: canonical = cliente / gestore
alter table public.profiles alter column role set default 'cliente';
update public.profiles set role = 'cliente' where role = 'user_single' or role is null;

-- 2) Events: add the columns the app needs (image + human location name)
alter table public.events add column if not exists image_url text;
alter table public.events add column if not exists location_name text;

-- 3) Live approved-participant count (NOT stored -- avoids drift).
--    SECURITY DEFINER so the count is correct for every viewer; it only
--    returns integer counts + fields already readable on published events.
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
  where e.status = 'published';
$$;
grant execute on function public.get_events_with_stats() to authenticated, anon;

-- 4) FIX THE LEAK: messages were world-readable (qual = true, role public).
drop policy if exists "Gli utenti possono leggere i messaggi degli eventi a cui partec" on public.messages;
drop policy if exists "Gli utenti autenticati possono inserire messaggi" on public.messages;

create policy "Messaggi leggibili da host e partecipanti approvati"
on public.messages for select to authenticated
using (
  exists (select 1 from events e where e.id = messages.event_id and e.host_id = auth.uid())
  or public.is_approved_for_event(event_id)
);

create policy "Messaggi inviabili da host e partecipanti approvati"
on public.messages for insert to authenticated
with check (
  auth.uid() = sender_id
  and (
    exists (select 1 from events e where e.id = messages.event_id and e.host_id = auth.uid())
    or public.is_approved_for_event(event_id)
  )
);
