-- ============================================================================
-- Prove della migrazione 0015 su un Postgres LOCALE, mai su Supabase.
-- Uno schema minimo imita Supabase: ruoli anon/authenticated, auth.uid()
-- letto da request.jwt.claim.sub, permessi di default larghi sulle tabelle
-- nuove, is_gestore() e la policy "aggiornamento solo al proprietario".
--
-- Uso (database vuoto):
--   psql -v ON_ERROR_STOP=1 -d <db> -f supabase/tests/0015_presenze_e_eta_test.sql
-- Esito: termina con "TUTTE LE PROVE 0015 SUPERATE", altrimenti si ferma
-- sulla prima prova fallita.
-- ============================================================================

-- --- Schema minimo tipo Supabase --------------------------------------------
create role anon nologin;
create role authenticated nologin;
create schema auth;
grant usage on schema auth, public to anon, authenticated;
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant execute on function auth.uid() to anon, authenticated;

-- Supabase concede tutto ad anon/authenticated su tabelle e funzioni nuove.
alter default privileges in schema public
  grant all on tables to anon, authenticated;
alter default privileges in schema public
  grant execute on functions to anon, authenticated;

create table public.profiles (
  id uuid primary key,
  role text not null default 'cliente',
  nickname text,
  age_confirmed_at timestamptz
);
alter table public.profiles enable row level security;
create policy "Consenti aggiornamento solo al proprietario" on public.profiles
  for update to authenticated using (auth.uid() = id);
create policy "Ogni utente crea solo il proprio profilo" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
create policy "lettura" on public.profiles
  for select to authenticated using (true);
revoke select on table public.profiles from anon, authenticated;
grant select (id, role, nickname) on public.profiles to authenticated;

create table public.events (
  id uuid primary key,
  host_id uuid not null,
  event_date timestamptz not null,
  status text not null default 'published'
);
create table public.event_requests (
  id uuid primary key,
  user_id uuid not null,
  event_id uuid not null references public.events (id),
  status text not null default 'pending'
);

create function public.is_gestore() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'gestore');
$$;

-- --- Dati ---------------------------------------------------------------------
-- g1, g2 gestori; c1 cliente (ospite di g1), c2 cliente (ospite solo di g2),
-- c3 cliente senza richieste.
insert into public.profiles (id, role, nickname) values
  ('00000000-0000-0000-0000-0000000000a1', 'gestore', 'g1'),
  ('00000000-0000-0000-0000-0000000000a2', 'gestore', 'g2'),
  ('00000000-0000-0000-0000-0000000000c1', 'cliente', 'c1'),
  ('00000000-0000-0000-0000-0000000000c2', 'cliente', 'c2'),
  ('00000000-0000-0000-0000-0000000000c3', 'cliente', 'c3');

insert into public.events (id, host_id, event_date) values
  -- g1: serata di 2 giorni fa, di 10 giorni fa, di domani
  ('00000000-0000-0000-0000-00000000e101', '00000000-0000-0000-0000-0000000000a1', now() - interval '2 days'),
  ('00000000-0000-0000-0000-00000000e102', '00000000-0000-0000-0000-0000000000a1', now() - interval '10 days'),
  ('00000000-0000-0000-0000-00000000e103', '00000000-0000-0000-0000-0000000000a1', now() + interval '1 day'),
  -- g2: serata di 1 giorno fa
  ('00000000-0000-0000-0000-00000000e201', '00000000-0000-0000-0000-0000000000a2', now() - interval '1 day');

insert into public.event_requests (id, user_id, event_id, status) values
  -- c1 approvato alla serata recente di g1
  ('00000000-0000-0000-0000-0000000f0001', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000e101', 'approved'),
  -- c3 in attesa alla stessa serata (non approvato)
  ('00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-00000000e101', 'pending'),
  -- c1 approvato alla serata vecchia di g1 (oltre 7 giorni)
  ('00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000e102', 'approved'),
  -- c1 approvato alla serata futura di g1
  ('00000000-0000-0000-0000-0000000f0004', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000e103', 'approved'),
  -- c1 approvato alla serata di g2
  ('00000000-0000-0000-0000-0000000f0005', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000e201', 'approved'),
  -- c2 approvato solo da g2
  ('00000000-0000-0000-0000-0000000f0006', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000e201', 'approved');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0015_presenze_e_eta.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0015_presenze_e_eta.sql

-- --- Helper per le prove -------------------------------------------------------
-- Esegue sql come utente "uid" (ruolo authenticated) e restituisce lo
-- SQLSTATE dell'errore, o 'OK'.
create function pg_temp.try_as(uid text, sql text) returns text
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid, ''), true);
  execute 'set local role authenticated';
  begin
    execute sql;
  exception when others then
    execute 'reset role';
    return sqlstate;
  end;
  execute 'reset role';
  return 'OK';
end;
$$;

create function pg_temp.expect(label text, got text, want text) returns void
language plpgsql as $$
begin
  if got is distinct from want then
    raise exception 'FALLITA: % (atteso %, ottenuto %)', label, want, got;
  end if;
  raise notice 'ok  %', label;
end;
$$;

-- --- Prove: età ---------------------------------------------------------------------
begin;
select pg_temp.expect('età: c1 salva il proprio anno (1990)',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set birth_year = 1990 where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('età: poi non lo può più cambiare',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set birth_year = 1995 where id = auth.uid() $q$),
  '42501');
select pg_temp.expect('età: minorenne rifiutato',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c2',
    format($q$ update public.profiles set birth_year = %s where id = auth.uid() $q$,
           extract(year from now())::int - 17)),
  '23514');
select pg_temp.expect('età: fuori intervallo rifiutato',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c2',
    $q$ update public.profiles set birth_year = 1800 where id = auth.uid() $q$),
  '23514');
select pg_temp.expect('età: leggibile dagli iscritti',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c2',
    $q$ select birth_year from public.profiles $q$),
  'OK');
select pg_temp.expect('età: cambiare altre colonne resta libero',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set nickname = 'c1bis' where id = auth.uid() $q$),
  'OK');
commit;

-- --- Prove: scrivere presenze -----------------------------------------------
begin;
select pg_temp.expect('presenze: nessuna scrittura diretta in tabella',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ insert into public.event_attendance (request_id, attended)
        values ('00000000-0000-0000-0000-0000000f0001', true) $q$),
  '42501');
select pg_temp.expect('presenze: il cliente non può segnare',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000c1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0001', true) $q$),
  '42501');
select pg_temp.expect('presenze: g2 non segna una serata di g1',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a2',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0001', false) $q$),
  '42501');
select pg_temp.expect('presenze: non su una richiesta in attesa',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0002', true) $q$),
  '22023');
select pg_temp.expect('presenze: non prima della serata',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0004', true) $q$),
  '22023');
select pg_temp.expect('presenze: non dopo 7 giorni',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0003', true) $q$),
  '22023');
select pg_temp.expect('presenze: valore mancante rifiutato',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0001', null) $q$),
  '22004');
select pg_temp.expect('presenze: anon non può chiamare la funzione',
  (select case when has_function_privilege('anon',
     'public.mark_attendance(uuid, boolean)', 'execute') then 'SI' else 'NO' end),
  'NO');
select pg_temp.expect('presenze: g1 segna c1 assente',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0001', false) $q$),
  'OK');
select pg_temp.expect('presenze: g1 corregge in presente (ultima scelta vince)',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0001', true) $q$),
  'OK');
select pg_temp.expect('presenze: una sola riga, con attended = true',
  (select string_agg(attended::text, ',') from public.event_attendance
   where request_id = '00000000-0000-0000-0000-0000000f0001'),
  'true');
select pg_temp.expect('presenze: g2 segna c1 assente alla sua serata',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a2',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0005', false) $q$),
  'OK');
select pg_temp.expect('presenze: g2 segna c2 presente',
  pg_temp.try_as('00000000-0000-0000-0000-0000000000a2',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0006', true) $q$),
  'OK');
commit;

-- --- Prove: leggere presenze ------------------------------------------------------
-- Risultato di una query eseguita come uid, in forma testuale.
create function pg_temp.read_as(uid text, sql text) returns text
language plpgsql as $$
declare v text;
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid, ''), true);
  execute 'set local role authenticated';
  execute sql into v;
  execute 'reset role';
  return coalesce(v, '(vuoto)');
end;
$$;

begin;
select pg_temp.expect('lettura: g1 vede solo le presenze delle sue serate',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select count(*)::text from public.event_attendance $q$),
  '1');
select pg_temp.expect('lettura: il cliente non vede nessuna riga',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000c1',
    $q$ select count(*)::text from public.event_attendance $q$),
  '0');

-- Affidabilità di c1: 1 presenza (g1) + 1 assenza (g2), su tutti i locali.
select pg_temp.expect('affidabilità: g1 vede c1 su tutti i locali',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select attended || '/' || no_shows from public.get_guest_reliability(
          array['00000000-0000-0000-0000-0000000000c1']::uuid[]) $q$),
  '1/1');
select pg_temp.expect('affidabilità: c1 vede i propri numeri',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000c1',
    $q$ select attended || '/' || no_shows from public.get_guest_reliability(
          array['00000000-0000-0000-0000-0000000000c1']::uuid[]) $q$),
  '1/1');
select pg_temp.expect('affidabilità: g1 non vede c2 (mai candidato da g1)',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select count(*)::text from public.get_guest_reliability(
          array['00000000-0000-0000-0000-0000000000c2']::uuid[]) $q$),
  '0');
select pg_temp.expect('affidabilità: un cliente non vede un altro cliente',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000c3',
    $q$ select count(*)::text from public.get_guest_reliability(
          array['00000000-0000-0000-0000-0000000000c1']::uuid[]) $q$),
  '0');
select pg_temp.expect('affidabilità: ospite senza storico = 0/0',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select attended || '/' || no_shows from public.get_guest_reliability(
          array['00000000-0000-0000-0000-0000000000c3']::uuid[]) $q$),
  '0/0');
select pg_temp.expect('affidabilità: anon non può chiamare la funzione',
  (select case when has_function_privilege('anon',
     'public.get_guest_reliability(uuid[])', 'execute') then 'SI' else 'NO' end),
  'NO');
commit;

-- Cancellare la richiesta cancella la presenza.
delete from public.event_requests where id = '00000000-0000-0000-0000-0000000f0006';
select pg_temp.expect('cascade: presenza cancellata con la richiesta',
  (select count(*)::text from public.event_attendance
   where request_id = '00000000-0000-0000-0000-0000000f0006'),
  '0');

\echo 'TUTTE LE PROVE 0015 SUPERATE'
