-- ============================================================================
-- Prove della migrazione 0018 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0017 (riga
-- "catena-fino-a" qui sotto). La 0018 la applica la prova stessa, dopo i
-- dati: come in produzione.
--
-- Prova due cose: anon non arriva più a nulla, e authenticated fa ancora
-- tutto quello che fa l'app.
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0018 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0017

-- --- Dati ---------------------------------------------------------------------
-- g1 gestore con abbonamento; c1, c2 clienti. e1 serata di g1 iniziata ieri,
-- e2 serata futura. c1 si candida a e1 (in attesa).
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000c2');
-- Il trigger della 0017 crea i profili da postgres sempre come cliente:
-- il gestore si promuove come da procedura, con service_role.
insert into public.profiles (id, nickname) values
  ('00000000-0000-0000-0000-0000000000a1', 'g1'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2');
set role service_role;
update public.profiles set role = 'gestore'
  where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
insert into public.subscriptions (user_id, purchase_token, expiry_time) values
  ('00000000-0000-0000-0000-0000000000a1', 'tok-g1', now() + interval '20 days');
insert into public.events (id, host_id, title, event_date, status) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000a1',
   'Serata di ieri', now() - interval '1 day', 'published'),
  ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000a1',
   'Serata futura', now() + interval '5 days', 'published');
insert into public.event_requests (id, user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000f0001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-00000000e001', 'pending');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0018_revoca_anon.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0018_revoca_anon.sql

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

-- Primo valore di una query eseguita come utente, in forma testuale.
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

create function pg_temp.expect(label text, got text, want text) returns void
language plpgsql as $$
begin
  if got is distinct from want then
    raise exception 'FALLITA: % (atteso %, ottenuto %)', label, want, got;
  end if;
  raise notice 'ok  %', label;
end;
$$;

-- --- Prove: anon non arriva a nulla --------------------------------------------
begin;
select pg_temp.expect(format('anon: select su %s rifiutata', t),
  pg_temp.try_as('anon', null, format('select 1 from public.%I limit 1', t)),
  '42501')
from unnest(array['events', 'event_requests', 'messages', 'blocks',
                  'device_tokens', 'profiles', 'subscriptions',
                  'event_attendance', 'account_deletions']) as t;
select pg_temp.expect('anon: insert in profiles rifiutato',
  pg_temp.try_as('anon', null,
    $q$ insert into public.profiles (id, nickname)
        values ('00000000-0000-0000-0000-0000000000c2', 'x') $q$),
  '42501');
select pg_temp.expect('anon: update di events rifiutato',
  pg_temp.try_as('anon', null, $q$ update public.events set title = 'x' $q$),
  '42501');
select pg_temp.expect('anon: delete di messages rifiutato',
  pg_temp.try_as('anon', null, $q$ delete from public.messages $q$),
  '42501');
select pg_temp.expect('anon: nessun permesso residuo sulle tabelle di public',
  (select count(*)::text from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'anon'), '0');
select pg_temp.expect(format('anon: %s non eseguibile', f),
  pg_temp.try_as('anon', null, format('select %s', f)), '42501')
from unnest(array[
  $f$public.is_approved_for_event('00000000-0000-0000-0000-00000000e001')$f$,
  $f$public.get_events_within_radius(43.7, 11.2, 10)$f$,
  $f$public.get_events_with_stats()$f$,
  $f$public.mark_attendance('00000000-0000-0000-0000-0000000f0001', true)$f$]) as f;
select pg_temp.expect('PUBLIC: is_approved_for_event non eseguibile',
  (select case when has_function_privilege('public',
     'public.is_approved_for_event(uuid)', 'execute') then 'SI' else 'NO' end),
  'NO');
commit;

-- --- Prove: authenticated senza TRUNCATE e funzione inutilizzata ----------------
begin;
select pg_temp.expect(format('authenticated: truncate di %s rifiutato', t),
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    format('truncate public.%I cascade', t)),
  '42501')
from unnest(array['events', 'event_requests', 'messages', 'blocks',
                  'device_tokens', 'profiles']) as t;
select pg_temp.expect('authenticated: get_events_within_radius non eseguibile',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select public.get_events_within_radius(43.7, 11.2, 10) $q$),
  '42501');
select pg_temp.expect('authenticated: is_approved_for_event ancora eseguibile',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select public.is_approved_for_event('00000000-0000-0000-0000-00000000e001') $q$),
  'OK');
select pg_temp.expect('is_approved_for_event: search_path fisso',
  (select proconfig::text from pg_proc
    where oid = 'public.is_approved_for_event(uuid)'::regprocedure),
  '{search_path=public}');
commit;

-- --- Prove: authenticated fa ancora quello che fa l'app ------------------------
begin;
select pg_temp.expect('app: il cliente vede le serate pubblicate',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000c1',
    $q$ select count(*)::text from public.events where status = 'published' $q$),
  '2');
select pg_temp.expect('app: get_events_with_stats',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000c1',
    $q$ select count(*)::text from public.get_events_with_stats() $q$),
  '2');
select pg_temp.expect('app: il cliente legge i profili (colonne permesse)',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select id, role, nickname, avatar_url, generic_location, is_verified,
               created_at, profile_type, privacy_level, birth_year
        from public.profiles $q$),
  'OK');
select pg_temp.expect('app: il cliente aggiorna il proprio profilo',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set nickname = 'c1bis' where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('app: il cliente si candida a una serata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into public.event_requests (user_id, event_id, status)
        values (auth.uid(), '00000000-0000-0000-0000-00000000e002', 'pending') $q$),
  'OK');
select pg_temp.expect('app: il gestore approva una richiesta',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.event_requests set status = 'approved'
        where id = '00000000-0000-0000-0000-0000000f0001' $q$),
  'OK');
select pg_temp.expect('app: ... approvazione salvata',
  (select status from public.event_requests
    where id = '00000000-0000-0000-0000-0000000f0001'), 'approved');
select pg_temp.expect('app: l''ospite approvato scrive in chat',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into public.messages (event_id, sender_id, content)
        values ('00000000-0000-0000-0000-00000000e001', auth.uid(), 'ciao') $q$),
  'OK');
select pg_temp.expect('app: ... e legge la chat',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000c1',
    $q$ select count(*)::text from public.messages $q$),
  '1');
select pg_temp.expect('app: il cliente blocca un utente',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into public.blocks (blocker_id, blocked_id)
        values (auth.uid(), '00000000-0000-0000-0000-0000000000c2') $q$),
  'OK');
select pg_temp.expect('app: ... e lo sblocca',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ delete from public.blocks where blocker_id = auth.uid() $q$),
  'OK');
select pg_temp.expect('app: salva il token push',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into public.device_tokens (user_id, token)
        values (auth.uid(), 'tok-c1')
        on conflict (user_id, token) do update set updated_at = now() $q$),
  'OK');
select pg_temp.expect('app: ... e lo cancella al logout',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ delete from public.device_tokens where user_id = auth.uid() $q$),
  'OK');
select pg_temp.expect('app: il gestore crea una serata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ insert into public.events (id, host_id, title, event_date, status)
        values ('00000000-0000-0000-0000-00000000e003', auth.uid(), 'Nuova',
                now() + interval '9 days', 'published') $q$),
  'OK');
select pg_temp.expect('app: ... la modifica',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.events set title = 'Nuova bis'
        where id = '00000000-0000-0000-0000-00000000e003' $q$),
  'OK');
select pg_temp.expect('app: ... e la cancella',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ delete from public.events
        where id = '00000000-0000-0000-0000-00000000e003' $q$),
  'OK');
select pg_temp.expect('app: ... cancellata davvero',
  (select count(*)::text from public.events
    where id = '00000000-0000-0000-0000-00000000e003'), '0');
select pg_temp.expect('app: il gestore segna una presenza',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ select public.mark_attendance('00000000-0000-0000-0000-0000000f0001', true) $q$),
  'OK');
select pg_temp.expect('app: ... la legge',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select count(*)::text from public.event_attendance $q$),
  '1');
select pg_temp.expect('app: ... e vede l''affidabilità del candidato',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select attended || '/' || no_shows from public.get_guest_reliability(
          array['00000000-0000-0000-0000-0000000000c1']::uuid[]) $q$),
  '1/0');
select pg_temp.expect('app: il gestore legge il proprio abbonamento',
  pg_temp.read_as('00000000-0000-0000-0000-0000000000a1',
    $q$ select count(*)::text from public.subscriptions $q$),
  '1');
commit;

-- --- Prove: oggetti futuri -------------------------------------------------------
create table public.prova_nuova (id int);
create function public.prova_nuova_fn() returns int language sql as $$ select 1 $$;
select pg_temp.expect('futuro: tabella nuova, niente ad anon',
  (select case when has_table_privilege('anon', 'public.prova_nuova', 'select')
     then 'SI' else 'NO' end), 'NO');
select pg_temp.expect('futuro: tabella nuova, authenticated sì',
  (select case when has_table_privilege('authenticated', 'public.prova_nuova', 'select')
     then 'SI' else 'NO' end), 'SI');
select pg_temp.expect('futuro: funzione nuova, nessun grant esplicito ad anon',
  (select count(*)::text from pg_proc p, aclexplode(p.proacl) a
    where p.oid = 'public.prova_nuova_fn()'::regprocedure
      and a.grantee = 'anon'::regrole), '0');
-- Limite documentato nella 0018: resta eseguibile da PUBLIC (e quindi da
-- anon) finché la migrazione che la crea non fa "revoke ... from public, anon".
select pg_temp.expect('futuro: funzione nuova, PUBLIC resta (limite noto)',
  (select case when has_function_privilege('public', 'public.prova_nuova_fn()', 'execute')
     then 'SI' else 'NO' end), 'SI');
revoke execute on function public.prova_nuova_fn() from public;
select pg_temp.expect('futuro: dopo il revoke da PUBLIC, anon non la esegue',
  (select case when has_function_privilege('anon', 'public.prova_nuova_fn()', 'execute')
     then 'SI' else 'NO' end), 'NO');
select pg_temp.expect('futuro: funzione nuova, authenticated sì',
  (select case when has_function_privilege('authenticated', 'public.prova_nuova_fn()', 'execute')
     then 'SI' else 'NO' end), 'SI');
drop function public.prova_nuova_fn();
drop table public.prova_nuova;

\echo 'TUTTE LE PROVE 0018 SUPERATE'
