-- ============================================================================
-- Prove della migrazione 0021 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0020 (riga
-- "catena-fino-a" qui sotto). La 0021 la applica la prova stessa, dopo i
-- dati: come in produzione.
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0021 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0020

-- --- Dati ---------------------------------------------------------------------
-- gv gestore verificato, gn gestore non verificato, entrambi con
-- abbonamento attivo; c1 cliente.
-- ev: serata pubblicata di gv; en: serata pubblicata di gn; bv: bozza di gv.
-- rv: candidatura di c1 a ev; rn: candidatura di c1 a en.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000c2');
insert into public.profiles (id, nickname) values
  ('00000000-0000-0000-0000-0000000000a1', 'gv'),
  ('00000000-0000-0000-0000-0000000000a2', 'gn'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2');
set role service_role;
update public.profiles set role = 'gestore', is_verified = true
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set role = 'gestore', is_verified = false
  where id = '00000000-0000-0000-0000-0000000000a2';
reset role;
insert into public.subscriptions (user_id, purchase_token, expiry_time) values
  ('00000000-0000-0000-0000-0000000000a1', 'tok-gv', now() + interval '20 days'),
  ('00000000-0000-0000-0000-0000000000a2', 'tok-gn', now() + interval '20 days');
insert into public.events (id, host_id, title, event_date, status) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000a1',
   'ev', now() + interval '5 days', 'published'),
  ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000a2',
   'en', now() + interval '5 days', 'published'),
  ('00000000-0000-0000-0000-00000000e003', '00000000-0000-0000-0000-0000000000a1',
   'bv', now() + interval '9 days', 'draft');
insert into public.event_requests (id, user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-00000000e002', 'pending');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0021_gestori_verificati.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0021_gestori_verificati.sql

-- --- Helper per le prove -------------------------------------------------------
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

create function pg_temp.value_as(r text, uid text, sql text) returns text
language plpgsql as $$
declare
  v text;
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid, ''), true);
  execute format('set local role %I', r);
  begin
    execute sql into v;
  exception when others then
    execute 'reset role';
    return 'ERR ' || sqlstate;
  end;
  execute 'reset role';
  return coalesce(v, '(null)');
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

-- Titoli delle serate visibili all'utente, in ordine.
create function pg_temp.visibili(uid text) returns text
language sql as $$
  select pg_temp.value_as('authenticated', uid,
    'select coalesce(string_agg(title, '','' order by title), ''-'') from public.events')
$$;
create function pg_temp.feed(uid text) returns text
language sql as $$
  select pg_temp.value_as('authenticated', uid,
    'select coalesce(string_agg(title, '','' order by title), ''-'') from public.get_events_with_stats()')
$$;
create function pg_temp.stato_evento(p_id text) returns text
language sql as $$
  select status from public.events where id = p_id::uuid
$$;

-- --- Prove: funzioni ----------------------------------------------------------------
begin;
select pg_temp.expect('is_verified_gestore: gestore verificato',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    'select public.is_verified_gestore()::text'), 'true');
select pg_temp.expect('is_verified_gestore: gestore non verificato',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    'select public.is_verified_gestore()::text'), 'false');
select pg_temp.expect('is_verified_gestore: cliente',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    'select public.is_verified_gestore()::text'), 'false');
select pg_temp.expect('host_is_verified: anon non la esegue',
  pg_temp.value_as('anon', null,
    'select public.host_is_verified(''00000000-0000-0000-0000-0000000000a1'')::text'),
  'ERR 42501');
select pg_temp.expect('is_verified_gestore: anon non la esegue',
  pg_temp.value_as('anon', null, 'select public.is_verified_gestore()::text'),
  'ERR 42501');
commit;

-- --- Prove: visibilità delle serate ------------------------------------------------------
begin;
select pg_temp.expect('cliente: vede solo la serata del locale verificato',
  pg_temp.visibili('00000000-0000-0000-0000-0000000000c1'), 'ev');
select pg_temp.expect('feed del cliente: solo il locale verificato',
  pg_temp.feed('00000000-0000-0000-0000-0000000000c1'), 'ev');
select pg_temp.expect('gestore non verificato: vede ancora le sue serate',
  pg_temp.visibili('00000000-0000-0000-0000-0000000000a2'), 'en,ev');
select pg_temp.expect('gestore verificato: le sue (anche la bozza) e nessuna di gn',
  pg_temp.visibili('00000000-0000-0000-0000-0000000000a1'), 'bv,ev');
commit;

-- --- Prove: creazione e modifica ------------------------------------------------------------
begin;
select pg_temp.expect('insert: il gestore verificato crea una serata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ insert into public.events (host_id, title, event_date, status)
        values (auth.uid(), 'nuova gv', now() + interval '3 days', 'published') $q$),
  'OK');
select pg_temp.expect('insert: il gestore non verificato no (con abbonamento)',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ insert into public.events (host_id, title, event_date, status)
        values (auth.uid(), 'nuova gn', now() + interval '3 days', 'published') $q$),
  '42501');
select pg_temp.expect('insert: il non verificato neanche in bozza',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ insert into public.events (host_id, title, event_date, status)
        values (auth.uid(), 'bozza gn', now() + interval '3 days', 'draft') $q$),
  '42501');
select pg_temp.expect('update: il non verificato non modifica una serata pubblicata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ update public.events set title = 'en bis'
         where id = '00000000-0000-0000-0000-00000000e002' $q$),
  '42501');
select pg_temp.expect('update: il non verificato annulla la sua serata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ update public.events set status = 'cancelled'
         where id = '00000000-0000-0000-0000-00000000e002' $q$),
  'OK');
select pg_temp.expect('update: ... annullata',
  pg_temp.stato_evento('00000000-0000-0000-0000-00000000e002'), 'cancelled');
select pg_temp.expect('update: il non verificato non la ripubblica',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ update public.events set status = 'published'
         where id = '00000000-0000-0000-0000-00000000e002' $q$),
  '42501');
select pg_temp.expect('update: il verificato pubblica la sua bozza',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.events set status = 'published'
         where id = '00000000-0000-0000-0000-00000000e003' $q$),
  'OK');
select pg_temp.expect('update: il verificato modifica una serata pubblicata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.events set title = 'ev'
         where id = '00000000-0000-0000-0000-00000000e001' $q$),
  'OK');
select pg_temp.expect('delete: il non verificato cancella la sua serata',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ with d as (delete from public.events
         where id = '00000000-0000-0000-0000-00000000e002' returning 1)
        select count(*)::text from d $q$),
  '1');
rollback;

-- --- Prove: candidature ------------------------------------------------------------------------
begin;
select pg_temp.expect('candidatura a una serata del locale verificato',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.event_requests (user_id, event_id, status)
        values (auth.uid(), '00000000-0000-0000-0000-00000000e001', 'pending') $q$),
  'OK');
select pg_temp.expect('candidatura a una serata del locale non verificato: rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.event_requests (user_id, event_id, status)
        values (auth.uid(), '00000000-0000-0000-0000-00000000e002', 'pending') $q$),
  '42501');
select pg_temp.expect('candidatura a una bozza: rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.event_requests (user_id, event_id, status)
        values (auth.uid(), '00000000-0000-0000-0000-00000000e003', 'pending') $q$),
  '42501');
select pg_temp.expect('valutazione: il verificato approva',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ with u as (update public.event_requests set status = 'approved'
         where id = '00000000-0000-0000-0000-0000000000f1' returning 1)
        select count(*)::text from u $q$),
  '1');
select pg_temp.expect('valutazione: il non verificato non approva (0 righe)',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ with u as (update public.event_requests set status = 'approved'
         where id = '00000000-0000-0000-0000-0000000000f2' returning 1)
        select count(*)::text from u $q$),
  '0');
rollback;

-- --- Prove: copertine ----------------------------------------------------------------------------
begin;
select pg_temp.expect('copertina: il verificato carica',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ insert into storage.objects (bucket_id, name, owner)
        values ('event_covers', 'gv/c.jpg', auth.uid()) $q$),
  'OK');
select pg_temp.expect('copertina: il non verificato no',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ insert into storage.objects (bucket_id, name, owner)
        values ('event_covers', 'gn/c.jpg', auth.uid()) $q$),
  '42501');
select pg_temp.expect('copertina: il cliente no',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into storage.objects (bucket_id, name, owner)
        values ('event_covers', 'c1/c.jpg', auth.uid()) $q$),
  '42501');
rollback;

-- --- Prove: sospensione e riattivazione ----------------------------------------------------------
begin;
set local role service_role;
update public.profiles set is_verified = false
 where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
select pg_temp.expect('sospeso: la sua serata sparisce per il cliente',
  pg_temp.visibili('00000000-0000-0000-0000-0000000000c1'), '-');
select pg_temp.expect('sospeso: ... e dal feed',
  pg_temp.feed('00000000-0000-0000-0000-0000000000c1'), '-');
select pg_temp.expect('sospeso: la serata non è cancellata',
  pg_temp.stato_evento('00000000-0000-0000-0000-00000000e001'), 'published');
set local role service_role;
update public.profiles set is_verified = true
 where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
select pg_temp.expect('riattivato: la serata torna visibile',
  pg_temp.visibili('00000000-0000-0000-0000-0000000000c1'), 'ev');
rollback;

-- Il gestore non si verifica da solo (protezione della 0017, ancora valida).
begin;
select pg_temp.expect('il gestore non verificato non si verifica da solo',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a2',
    $q$ update public.profiles set is_verified = true where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('... e resta non verificato',
  (select is_verified::text from public.profiles
    where id = '00000000-0000-0000-0000-0000000000a2'), 'false');
rollback;

\echo 'TUTTE LE PROVE 0021 SUPERATE'
