-- ============================================================================
-- Prove della migrazione 0016 su un Postgres LOCALE, mai su Supabase.
-- Uno schema minimo imita Supabase: ruoli anon/authenticated/service_role,
-- auth.uid(), storage.objects con storage.foldername(), le tabelle base con
-- le chiavi esterne reali (lette dal database il 02/10/2026) e la 0015.
--
-- Uso (database vuoto):
--   psql -v ON_ERROR_STOP=1 -d <db> -f supabase/tests/0016_cancellazione_account_test.sql
-- Esito: termina con "TUTTE LE PROVE 0016 SUPERATE", altrimenti si ferma
-- sulla prima prova fallita.
-- ============================================================================

-- --- Schema minimo tipo Supabase --------------------------------------------
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create schema storage;
grant usage on schema auth, public, storage to anon, authenticated, service_role;
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Supabase concede tutto ai tre ruoli su tabelle e funzioni nuove.
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;

create table auth.users (id uuid primary key);

create table storage.objects (
  bucket_id text not null,
  name      text not null,
  owner     uuid,
  primary key (bucket_id, name)
);
grant all on storage.objects to service_role;
create function storage.foldername(name text) returns text[]
language sql immutable as
  $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'cliente',
  nickname text
);
alter table public.profiles enable row level security;
create policy "lettura" on public.profiles
  for select to authenticated using (true);
create policy "Consenti aggiornamento solo al proprietario" on public.profiles
  for update to authenticated using (auth.uid() = id);

-- events come nel database reale: host_id not null, check su status senza
-- nome noto (qui il nome di default di Postgres).
create table public.events (
  id uuid primary key,
  host_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text,
  event_date timestamptz not null,
  status text check (status = any (array['draft', 'published', 'cancelled'])),
  latitude double precision,
  longitude double precision,
  location_name text,
  image_url text
);
alter table public.events enable row level security;

create table public.event_requests (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  event_id uuid not null references public.events (id) on delete cascade,
  status text check (status = any (array['pending', 'approved', 'rejected']))
);
alter table public.event_requests enable row level security;

create table public.messages (
  id bigserial primary key,
  event_id uuid not null references public.events (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  content text not null
);
alter table public.messages enable row level security;

create table public.blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  primary key (blocker_id, blocked_id)
);
alter table public.blocks enable row level security;

create table public.device_tokens (
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  primary key (user_id, token)
);
alter table public.device_tokens enable row level security;

create table public.subscriptions (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  purchase_token text not null unique,
  expiry_time timestamptz not null
);
alter table public.subscriptions enable row level security;

create function public.is_gestore() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'gestore');
$$;

\ir ../migrations/0015_presenze_e_eta.sql

-- --- Dati ---------------------------------------------------------------------
-- g1, g2 gestori; c1, c2, c3 clienti.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000c2'),
  ('00000000-0000-0000-0000-0000000000c3');
insert into public.profiles (id, role, nickname) values
  ('00000000-0000-0000-0000-0000000000a1', 'gestore', 'g1'),
  ('00000000-0000-0000-0000-0000000000a2', 'gestore', 'g2'),
  ('00000000-0000-0000-0000-0000000000c1', 'cliente', 'c1'),
  ('00000000-0000-0000-0000-0000000000c2', 'cliente', 'c2'),
  ('00000000-0000-0000-0000-0000000000c3', 'cliente', 'c3');

insert into public.events
  (id, host_id, title, description, event_date, status, latitude, longitude,
   location_name, image_url) values
  -- g1: passata con presenze, passata senza presenze, futura
  ('00000000-0000-0000-0000-00000000e101', '00000000-0000-0000-0000-0000000000a1',
   'Serata g1 passata', 'desc', now() - interval '3 days', 'published', 43.7, 11.2,
   'Locale g1', 'https://x.supabase.co/storage/v1/object/public/event_covers/111_g1.jpg'),
  ('00000000-0000-0000-0000-00000000e102', '00000000-0000-0000-0000-0000000000a1',
   'Serata g1 vuota', null, now() - interval '20 days', 'published', 43.7, 11.2,
   'Locale g1', null),
  ('00000000-0000-0000-0000-00000000e103', '00000000-0000-0000-0000-0000000000a1',
   'Serata g1 futura', null, now() + interval '5 days', 'published', 43.7, 11.2,
   'Locale g1', 'https://x.supabase.co/storage/v1/object/public/event_covers/333_g1.jpg'),
  -- g2: passata con presenze
  ('00000000-0000-0000-0000-00000000e201', '00000000-0000-0000-0000-0000000000a2',
   'Serata g2 passata', null, now() - interval '2 days', 'published', 43.8, 11.3,
   'Locale g2', null);

insert into public.event_requests (id, user_id, event_id, status) values
  -- serata passata di g1: c2 approvato e venuto, c3 in attesa
  ('00000000-0000-0000-0000-0000000f0001', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000e101', 'approved'),
  ('00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-00000000e101', 'pending'),
  -- serata vuota di g1: c2 approvato, presenza mai segnata
  ('00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000e102', 'approved'),
  -- serata futura di g1: c2 approvato
  ('00000000-0000-0000-0000-0000000f0004', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000e103', 'approved'),
  -- serata di g2: c1 venuto, c2 assente
  ('00000000-0000-0000-0000-0000000f0005', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000e201', 'approved'),
  ('00000000-0000-0000-0000-0000000f0006', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000e201', 'approved');

insert into public.event_attendance (request_id, attended) values
  ('00000000-0000-0000-0000-0000000f0001', true),
  ('00000000-0000-0000-0000-0000000f0005', true),
  ('00000000-0000-0000-0000-0000000f0006', false);

insert into public.messages (event_id, sender_id, content) values
  ('00000000-0000-0000-0000-00000000e201', '00000000-0000-0000-0000-0000000000c1', 'c1 da g2'),
  ('00000000-0000-0000-0000-00000000e201', '00000000-0000-0000-0000-0000000000c2', 'c2 da g2'),
  ('00000000-0000-0000-0000-00000000e101', '00000000-0000-0000-0000-0000000000c2', 'c2 da g1 passata'),
  ('00000000-0000-0000-0000-00000000e103', '00000000-0000-0000-0000-0000000000a1', 'g1 futura');

insert into public.blocks (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c3'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c3'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000c3');

insert into public.device_tokens (user_id, token) values
  ('00000000-0000-0000-0000-0000000000c1', 'tok-c1'),
  ('00000000-0000-0000-0000-0000000000a1', 'tok-g1'),
  ('00000000-0000-0000-0000-0000000000c2', 'tok-c2');

insert into public.subscriptions (user_id, purchase_token, expiry_time) values
  ('00000000-0000-0000-0000-0000000000a1', 'tok-play-g1', now() + interval '20 days');

insert into storage.objects (bucket_id, name, owner) values
  ('profile_photos', '00000000-0000-0000-0000-0000000000c1/1_a.jpg', '00000000-0000-0000-0000-0000000000c1'),
  ('profile_photos', '00000000-0000-0000-0000-0000000000c1/2_b.jpg', '00000000-0000-0000-0000-0000000000c1'),
  ('profile_photos', '00000000-0000-0000-0000-0000000000c2/1_c.jpg', '00000000-0000-0000-0000-0000000000c2'),
  ('event_covers', '111_g1.jpg', '00000000-0000-0000-0000-0000000000a1'),
  ('event_covers', '222_g1_mai_usata.jpg', '00000000-0000-0000-0000-0000000000a1'),
  ('event_covers', '444_g2.jpg', '00000000-0000-0000-0000-0000000000a2');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0016_cancellazione_account.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0016_cancellazione_account.sql

-- --- Helper per le prove -------------------------------------------------------
-- Esegue sql con il ruolo indicato (e, se dato, come utente uid) e
-- restituisce lo SQLSTATE dell'errore, o 'OK'.
create function pg_temp.try_as(r text, uid text, sql text) returns text
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid, ''), true);
  execute format('set local role %I', r);
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

-- Presenze/assenze di c2 viste da c2 stesso (get_guest_reliability, 0015).
create function pg_temp.reliability_c2() returns text
language plpgsql as $$
declare
  v text;
begin
  perform set_config('request.jwt.claim.sub',
                     '00000000-0000-0000-0000-0000000000c2', true);
  execute 'set local role authenticated';
  select attended || '/' || no_shows into v
  from public.get_guest_reliability(
         array['00000000-0000-0000-0000-0000000000c2'::uuid]);
  execute 'reset role';
  return v;
end;
$$;

-- --- Prove: permessi -----------------------------------------------------------------
begin;
select pg_temp.expect('permessi: anon non chiama delete_account_data',
  pg_temp.try_as('anon', null,
    $q$ select public.delete_account_data('00000000-0000-0000-0000-0000000000c1') $q$),
  '42501');
select pg_temp.expect('permessi: un utente non cancella nemmeno se stesso via RPC',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select public.delete_account_data('00000000-0000-0000-0000-0000000000c1') $q$),
  '42501');
select pg_temp.expect('permessi: authenticated non elenca i file',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select * from public.account_deletion_files('00000000-0000-0000-0000-0000000000c1') $q$),
  '42501');
select pg_temp.expect('permessi: il registro non si legge da authenticated',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select * from public.account_deletions $q$),
  '42501');
commit;

-- --- Prove: file nello Storage --------------------------------------------------------
begin;
set local role service_role;
select pg_temp.expect('file: c1 -> solo le sue due foto',
  (select string_agg(bucket || ':' || path, ',' order by path)
     from public.account_deletion_files('00000000-0000-0000-0000-0000000000c1')),
  'profile_photos:00000000-0000-0000-0000-0000000000c1/1_a.jpg,profile_photos:00000000-0000-0000-0000-0000000000c1/2_b.jpg');
select pg_temp.expect('file: g1 -> copertine sue, anche mai usata o solo da URL',
  (select string_agg(bucket || ':' || path, ',' order by path)
     from public.account_deletion_files('00000000-0000-0000-0000-0000000000a1')),
  'event_covers:111_g1.jpg,event_covers:222_g1_mai_usata.jpg,event_covers:333_g1.jpg');
reset role;
commit;

-- --- Prove: cancellazione di un cliente -----------------------------------------------
begin;
select pg_temp.expect('affidabilità c2 prima: 1 presenza da g1, 1 assenza da g2',
  pg_temp.reliability_c2(), '1/1');
commit;

begin;
set local role service_role;
select pg_temp.expect('cliente: ritorna ruolo e conteggi',
  public.delete_account_data('00000000-0000-0000-0000-0000000000c1')::text,
  '{"role": "cliente", "deleted_events": 0, "archived_events": 0, "deleted_messages": 1, "deleted_requests": 1}');
reset role;
commit;

select pg_temp.expect('cliente: profilo cancellato',
  (select count(*)::text from public.profiles
    where id = '00000000-0000-0000-0000-0000000000c1'), '0');
select pg_temp.expect('cliente: richieste cancellate',
  (select count(*)::text from public.event_requests
    where user_id = '00000000-0000-0000-0000-0000000000c1'), '0');
select pg_temp.expect('cliente: la sua presenza è cancellata',
  (select count(*)::text from public.event_attendance
    where request_id = '00000000-0000-0000-0000-0000000f0005'), '0');
select pg_temp.expect('cliente: messaggi cancellati',
  (select count(*)::text from public.messages
    where sender_id = '00000000-0000-0000-0000-0000000000c1'), '0');
select pg_temp.expect('cliente: blocchi cancellati in entrambe le direzioni',
  (select count(*)::text from public.blocks
    where '00000000-0000-0000-0000-0000000000c1' in (blocker_id, blocked_id)), '0');
select pg_temp.expect('cliente: token push cancellato',
  (select count(*)::text from public.device_tokens
    where user_id = '00000000-0000-0000-0000-0000000000c1'), '0');
select pg_temp.expect('cliente: gli altri non perdono nulla (messaggi)',
  (select count(*)::text from public.messages), '3');
select pg_temp.expect('cliente: gli altri non perdono nulla (blocchi)',
  (select count(*)::text from public.blocks), '2');
select pg_temp.expect('cliente: gli altri non perdono nulla (presenze)',
  (select count(*)::text from public.event_attendance), '2');
-- Dopo i dati, la Edge Function elimina l'utente auth: nessuna chiave
-- esterna deve impedirlo.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';

-- --- Prove: cancellazione di un gestore -----------------------------------------------
begin;
set local role service_role;
select pg_temp.expect('gestore: ritorna ruolo e conteggi',
  public.delete_account_data('00000000-0000-0000-0000-0000000000a1')::text,
  '{"role": "gestore", "deleted_events": 2, "archived_events": 1, "deleted_messages": 2, "deleted_requests": 3}');
reset role;
commit;

select pg_temp.expect('gestore: serata passata con presenze archiviata anonima',
  (select coalesce(host_id::text, 'null') || '|' || status || '|' || title || '|'
          || coalesce(description, 'null') || '|' || coalesce(location_name, 'null') || '|'
          || coalesce(latitude::text, 'null') || '|' || coalesce(image_url, 'null')
     from public.events where id = '00000000-0000-0000-0000-00000000e101'),
  'null|archived|Serata archiviata|null|null|null|null');
select pg_temp.expect('gestore: resta solo la richiesta con presenza',
  (select string_agg(id::text, ',') from public.event_requests
    where event_id = '00000000-0000-0000-0000-00000000e101'),
  '00000000-0000-0000-0000-0000000f0001');
select pg_temp.expect('gestore: chat della serata archiviata cancellata',
  (select count(*)::text from public.messages
    where event_id = '00000000-0000-0000-0000-00000000e101'), '0');
select pg_temp.expect('gestore: serata futura e serata senza presenze cancellate',
  (select count(*)::text from public.events
    where id in ('00000000-0000-0000-0000-00000000e102',
                 '00000000-0000-0000-0000-00000000e103')), '0');
select pg_temp.expect('gestore: nessuna serata resta a suo nome',
  (select count(*)::text from public.events
    where host_id = '00000000-0000-0000-0000-0000000000a1'), '0');
select pg_temp.expect('gestore: abbonamento cancellato',
  (select count(*)::text from public.subscriptions), '0');
select pg_temp.expect('gestore: profilo, token e blocchi cancellati',
  (select (select count(*) from public.profiles
            where id = '00000000-0000-0000-0000-0000000000a1')
        + (select count(*) from public.device_tokens
            where user_id = '00000000-0000-0000-0000-0000000000a1')
        + (select count(*) from public.blocks
            where blocker_id = '00000000-0000-0000-0000-0000000000a1'))::text, '0');
select pg_temp.expect('gestore: le serate di g2 non si toccano',
  (select count(*)::text from public.events
    where host_id = '00000000-0000-0000-0000-0000000000a2'), '1');

begin;
select pg_temp.expect('affidabilità c2 dopo: invariata',
  pg_temp.reliability_c2(), '1/1');
commit;

delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.expect('gestore: la serata archiviata sopravvive all''utente auth',
  (select count(*)::text from public.events
    where id = '00000000-0000-0000-0000-00000000e101'), '1');

-- --- Prove: ripetizione e serate archiviate nascoste ----------------------------------
begin;
set local role service_role;
select pg_temp.expect('ripetizione: nessun errore, niente da cancellare',
  public.delete_account_data('00000000-0000-0000-0000-0000000000a1')::text,
  '{"role": null, "deleted_events": 0, "archived_events": 0, "deleted_messages": 0, "deleted_requests": 0}');
reset role;
commit;

select pg_temp.expect('vincolo: stato inventato ancora rifiutato',
  pg_temp.try_as('service_role', null,
    $q$ update public.events set status = 'boh'
        where id = '00000000-0000-0000-0000-00000000e201' $q$),
  '23514');

\echo 'TUTTE LE PROVE 0016 SUPERATE'
