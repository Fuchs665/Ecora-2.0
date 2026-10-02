-- ============================================================================
-- Prove della migrazione 0017 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0016 (riga
-- "catena-fino-a" qui sotto): profiles con le policy e i trigger veri.
-- La 0017 la applica la prova stessa, dopo i dati: come in produzione.
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0017 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0016

-- --- Dati ---------------------------------------------------------------------
-- g1 gestore verificato e c1 cliente esistono già (creati prima della 0017);
-- u1..u7 hanno solo l'utente auth: il profilo lo creano le prove.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000b2'),
  ('00000000-0000-0000-0000-0000000000b3'),
  ('00000000-0000-0000-0000-0000000000b4'),
  ('00000000-0000-0000-0000-0000000000b5'),
  ('00000000-0000-0000-0000-0000000000b6'),
  ('00000000-0000-0000-0000-0000000000b7');
insert into public.profiles (id, role, nickname, is_verified) values
  ('00000000-0000-0000-0000-0000000000a1', 'gestore', 'g1', true),
  ('00000000-0000-0000-0000-0000000000c1', 'cliente', 'c1', false);

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0017_proteggi_profilo_insert.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0017_proteggi_profilo_insert.sql

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

-- Ruolo e verifica di un profilo, letti da postgres.
create function pg_temp.stato(uid text) returns text
language sql as $$
  select coalesce((select role || '|' || is_verified::text
                     from public.profiles where id = uid::uuid), '(assente)')
$$;

-- --- Prove: creazione del profilo ----------------------------------------------
begin;
select pg_temp.expect('insert: un utente non si crea gestore verificato (nessun errore)',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000b1',
    $q$ insert into public.profiles (id, nickname, role, is_verified)
        values (auth.uid(), 'b1', 'gestore', true) $q$),
  'OK');
select pg_temp.expect('insert: ... e il profilo nasce cliente non verificato',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b1'), 'cliente|false');
select pg_temp.expect('insert: come fa l''app (cliente, false) funziona',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000b2',
    $q$ insert into public.profiles (id, nickname, role, is_verified)
        values (auth.uid(), 'b2', 'cliente', false) $q$),
  'OK');
select pg_temp.expect('insert: ... cliente non verificato',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b2'), 'cliente|false');
select pg_temp.expect('insert: service_role crea un gestore verificato',
  pg_temp.try_as('service_role', null,
    $q$ insert into public.profiles (id, nickname, role, is_verified)
        values ('00000000-0000-0000-0000-0000000000b3', 'b3', 'gestore', true) $q$),
  'OK');
select pg_temp.expect('insert: ... e resta gestore verificato',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b3'), 'gestore|true');
select pg_temp.expect('insert: un profilo per un altro utente resta vietato (RLS)',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000b6',
    $q$ insert into public.profiles (id, nickname)
        values ('00000000-0000-0000-0000-0000000000b7', 'b7') $q$),
  '42501');
select pg_temp.expect('insert: la guardia sull''anno di nascita vale ancora',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000b5',
    format($q$ insert into public.profiles (id, nickname, birth_year)
               values (auth.uid(), 'b5', %s) $q$,
           extract(year from now())::int - 17)),
  '23514');
commit;

-- Come dal SQL Editor (postgres, non service_role): anche qui nasce cliente.
insert into public.profiles (id, nickname, role, is_verified)
  values ('00000000-0000-0000-0000-0000000000b4', 'b4', 'gestore', true);
select pg_temp.expect('insert: dal SQL Editor senza service_role nasce cliente',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b4'), 'cliente|false');

-- --- Prove: upsert dell'app e modifiche ------------------------------------------
begin;
select pg_temp.expect('upsert di riparazione (ignoreDuplicates) su un gestore: nessun errore',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ insert into public.profiles (id, nickname, role)
        values (auth.uid(), 'g1', 'cliente')
        on conflict (id) do nothing $q$),
  'OK');
select pg_temp.expect('upsert di riparazione: il gestore resta gestore verificato',
  pg_temp.stato('00000000-0000-0000-0000-0000000000a1'), 'gestore|true');
select pg_temp.expect('upsert con aggiornamento: un cliente non si promuove',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into public.profiles (id, nickname, role, is_verified)
        values (auth.uid(), 'c1', 'gestore', true)
        on conflict (id) do update
          set role = excluded.role, is_verified = excluded.is_verified $q$),
  'OK');
select pg_temp.expect('upsert con aggiornamento: ... resta cliente non verificato',
  pg_temp.stato('00000000-0000-0000-0000-0000000000c1'), 'cliente|false');
select pg_temp.expect('update: un cliente non cambia ruolo né verifica',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set role = 'gestore', is_verified = true
        where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('update: ... valori rimessi com''erano',
  pg_temp.stato('00000000-0000-0000-0000-0000000000c1'), 'cliente|false');
select pg_temp.expect('update: le altre colonne restano modificabili',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set nickname = 'c1bis' where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('update: ... nickname cambiato',
  (select nickname from public.profiles
    where id = '00000000-0000-0000-0000-0000000000c1'), 'c1bis');
select pg_temp.expect('update: un gestore non si toglie né si dà la verifica',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.profiles set is_verified = false where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('update: ... il gestore resta verificato',
  pg_temp.stato('00000000-0000-0000-0000-0000000000a1'), 'gestore|true');
select pg_temp.expect('update: service_role promuove e verifica',
  pg_temp.try_as('service_role', null,
    $q$ update public.profiles set role = 'gestore', is_verified = true
        where id = '00000000-0000-0000-0000-0000000000c1' $q$),
  'OK');
select pg_temp.expect('update: ... promozione applicata',
  pg_temp.stato('00000000-0000-0000-0000-0000000000c1'), 'gestore|true');
commit;

\echo 'TUTTE LE PROVE 0017 SUPERATE'
