-- ============================================================================
-- Blocco B.2a: età e presenze reali (base dati per scheda candidato e
-- lista "chi è venuto?"). Run in: Supabase Dashboard -> SQL Editor.
-- Transazionale. Idempotente. Nessuna policy esistente viene toccata.
--
-- Perché NON una colonna profiles.no_shows: la policy "Consenti
-- aggiornamento solo al proprietario" lascia a ogni utente la scrittura
-- della propria riga, quindi chiunque potrebbe azzerarsi le assenze.
-- Si salva invece, per ogni ospite approvato, se si è presentato; i
-- conteggi si calcolano da lì (non falsificabili, niente deriva, il gestore
-- può correggere un errore entro la finestra).
--
-- Perché una tabella a parte e non una colonna di event_requests: gli
-- ospiti approvati alla stessa serata leggono le richieste l'uno dell'altro
-- (policy SELECT della 0006) e vedrebbero chi non si è presentato.
--
-- Da applicare PRIMA di rilasciare B.2b/B.2c lato app.
-- ============================================================================

begin;

-- 1) ETÀ ---------------------------------------------------------------------
-- Solo l'anno: basta per mostrare l'età e rivela meno di una data completa.
alter table public.profiles add column if not exists birth_year smallint;

alter table public.profiles drop constraint if exists profiles_birth_year_range;
alter table public.profiles add constraint profiles_birth_year_range
  check (birth_year is null or birth_year between 1900 and 2100);

-- Maggiore età (sull'anno: il consenso 18+ di age_confirmed_at copre il
-- resto) e anno immutabile dopo il primo salvataggio. Una correzione va
-- fatta da SQL Editor disattivando il trigger.
create or replace function public.profiles_birth_year_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.birth_year is not null
     and new.birth_year is distinct from old.birth_year then
    raise exception 'L''anno di nascita non si può modificare'
      using errcode = '42501';
  end if;
  if new.birth_year is not null
     and extract(year from now())::int - new.birth_year < 18 then
    raise exception 'Ecora è riservata ai maggiorenni'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_birth_year_guard on public.profiles;
create trigger trg_profiles_birth_year_guard
  before insert or update of birth_year on public.profiles
  for each row execute function public.profiles_birth_year_guard();

-- Grant per colonna (vedi 0012): senza, la colonna non è leggibile.
grant select (birth_year) on public.profiles to authenticated;

-- 2) PRESENZE ------------------------------------------------------------------
create table if not exists public.event_attendance (
  request_id uuid primary key
    references public.event_requests (id) on delete cascade,
  attended   boolean not null,
  marked_at  timestamptz not null default now()
);

alter table public.event_attendance enable row level security;

-- Supabase concede di default tutto ad anon/authenticated sulle tabelle
-- nuove: si parte da zero e si concede solo la lettura.
revoke all on table public.event_attendance from public, anon, authenticated;
grant select on table public.event_attendance to authenticated;

-- Lettura: solo il gestore della serata. Nessuna policy di scrittura: si
-- scrive solo con mark_attendance().
drop policy if exists "event_attendance_select_host" on public.event_attendance;
create policy "event_attendance_select_host" on public.event_attendance
  for select to authenticated
  using (
    exists (
      select 1
      from public.event_requests r
      join public.events e on e.id = r.event_id
      where r.id = event_attendance.request_id
        and e.host_id = auth.uid()
    )
  );

-- 3) SEGNARE UNA PRESENZA -----------------------------------------------------
-- Solo il gestore della serata, solo ospiti approvati, dall'inizio della
-- serata a 7 giorni dopo. Rieseguibile: l'ultima scelta vince.
create or replace function public.mark_attendance(
  p_request_id uuid,
  p_attended boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_host   uuid;
  v_status text;
  v_date   timestamptz;
begin
  if p_attended is null then
    raise exception 'Indica se l''ospite è venuto' using errcode = '22004';
  end if;

  select e.host_id, r.status, e.event_date
    into v_host, v_status, v_date
  from public.event_requests r
  join public.events e on e.id = r.event_id
  where r.id = p_request_id;

  if not found then
    raise exception 'Richiesta inesistente' using errcode = 'P0002';
  end if;
  if v_host is distinct from auth.uid() or not public.is_gestore() then
    raise exception 'Solo il gestore della serata può segnare le presenze'
      using errcode = '42501';
  end if;
  if v_status <> 'approved' then
    raise exception 'Si segnano solo gli ospiti approvati'
      using errcode = '22023';
  end if;
  if v_date is null or now() < v_date then
    raise exception 'La serata non è ancora iniziata' using errcode = '22023';
  end if;
  if now() > v_date + interval '7 days' then
    raise exception 'Sono passati più di 7 giorni dalla serata'
      using errcode = '22023';
  end if;

  insert into public.event_attendance (request_id, attended, marked_at)
  values (p_request_id, p_attended, now())
  on conflict (request_id)
  do update set attended = excluded.attended, marked_at = excluded.marked_at;
end;
$$;

revoke execute on function public.mark_attendance(uuid, boolean)
  from public, anon;
grant execute on function public.mark_attendance(uuid, boolean)
  to authenticated;

-- 4) AFFIDABILITÀ DI UN OSPITE --------------------------------------------------
-- Presenze e assenze contate su TUTTI i locali (il dato che solo Ecora ha).
-- Risponde solo per se stessi, o a un gestore per chi ha una richiesta
-- verso una sua serata: niente interrogazioni su utenti a caso.
create or replace function public.get_guest_reliability(p_user_ids uuid[])
returns table (user_id uuid, attended bigint, no_shows bigint)
language sql
stable
security definer
set search_path = public
as $$
  select u.id,
         count(a.request_id) filter (where a.attended),
         count(a.request_id) filter (where not a.attended)
  from unnest(p_user_ids) as u(id)
  left join public.event_requests r on r.user_id = u.id
  left join public.event_attendance a on a.request_id = r.id
  where u.id = auth.uid()
     or (
       public.is_gestore()
       and exists (
         select 1
         from public.event_requests r2
         join public.events e2 on e2.id = r2.event_id
         where r2.user_id = u.id and e2.host_id = auth.uid()
       )
     )
  group by u.id;
$$;

revoke execute on function public.get_guest_reliability(uuid[])
  from public, anon;
grant execute on function public.get_guest_reliability(uuid[])
  to authenticated;

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- ============================================================================
-- a) birth_year leggibile, timestamp di consenso ancora no (attese 10 righe,
--    nessuna per age_confirmed_at/terms_accepted_at):
--   select column_name from information_schema.column_privileges
--   where table_name = 'profiles' and grantee = 'authenticated'
--     and privilege_type = 'SELECT';
--
-- b) event_attendance: solo SELECT per authenticated, niente per anon:
--   select grantee, privilege_type from information_schema.table_privileges
--   where table_name = 'event_attendance';
--
-- c) funzioni: EXECUTE solo per authenticated (attese true, false):
--   select has_function_privilege('authenticated',
--            'public.mark_attendance(uuid, boolean)', 'execute'),
--          has_function_privilege('anon',
--            'public.mark_attendance(uuid, boolean)', 'execute');
--
-- Prove di comportamento: supabase/tests/0015_presenze_e_eta_test.sql
-- (Postgres locale con auth.uid() simulato).
