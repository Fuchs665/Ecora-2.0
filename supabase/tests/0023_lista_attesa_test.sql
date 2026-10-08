-- ============================================================================
-- Prove della migrazione 0023 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0022 (riga
-- "catena-fino-a" qui sotto). La 0023 la applica la prova stessa, dopo i
-- dati: come in produzione.
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0023 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0022

-- --- Dati ---------------------------------------------------------------------
-- g1 gestore verificato, gn non verificato. Clienti: k1, k2, k3 coppie;
-- d1 donna; u1 uomo; x1 senza tipologia.
-- e1: 3 posti, al massimo 1 coppia; k1 già approvato.
-- e2: bozza di g1. en: pubblicata da gn (non visibile).
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000b2'),
  ('00000000-0000-0000-0000-0000000000b3'),
  ('00000000-0000-0000-0000-0000000000d1'),
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000f1');
insert into public.profiles (id, nickname, profile_type) values
  ('00000000-0000-0000-0000-0000000000a1', 'g1', null),
  ('00000000-0000-0000-0000-0000000000a2', 'gn', null),
  ('00000000-0000-0000-0000-0000000000b1', 'k1', 'Coppia U/D'),
  ('00000000-0000-0000-0000-0000000000b2', 'k2', 'Coppia D/D'),
  ('00000000-0000-0000-0000-0000000000b3', 'k3', 'Coppia U/U'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1', 'Donna Singola'),
  ('00000000-0000-0000-0000-0000000000e1', 'u1', 'Uomo Singolo'),
  ('00000000-0000-0000-0000-0000000000f1', 'x1', null);
set role service_role;
update public.profiles set role = 'gestore', is_verified = true
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set role = 'gestore', is_verified = false
  where id = '00000000-0000-0000-0000-0000000000a2';
reset role;
insert into public.events (id, host_id, title, event_date, status, max_guests, max_couples) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000a1',
   'e1', now() + interval '5 days', 'published', 3, 1),
  ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000a1',
   'e2', now() + interval '5 days', 'draft', 3, null),
  ('00000000-0000-0000-0000-00000000e003', '00000000-0000-0000-0000-0000000000a2',
   'en', now() + interval '5 days', 'published', 3, null);
insert into public.event_requests (id, user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000001b1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-00000000e001', 'approved');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0023_lista_attesa.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0023_lista_attesa.sql

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

-- L'utente uid si candida alla serata ev con lo stato indicato: OK o SQLSTATE.
create function pg_temp.candida(uid text, ev text, stato text default 'pending') returns text
language sql as $$
  select pg_temp.try_as('authenticated', uid,
    format('insert into public.event_requests (user_id, event_id, status) values (auth.uid(), %L, %L)', ev, stato))
$$;

create function pg_temp.stato(uid text, ev text) returns text
language sql as $$
  select coalesce((select status from public.event_requests
                    where user_id = uid::uuid and event_id = ev::uuid), '(assente)')
$$;

create function pg_temp.posizione(uid text, ev text) returns text
language sql as $$
  select pg_temp.value_as('authenticated', uid,
    format('select public.my_waitlist_position(%L)::text', ev))
$$;

-- --- Prove: stato deciso dal server ---------------------------------------------------
begin;
select pg_temp.expect('coppia con il posto coppie pieno: in lista',
  pg_temp.candida('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e001'), 'OK');
select pg_temp.expect('... stato waitlisted',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e001'), 'waitlisted');
select pg_temp.expect('donna con posti liberi: in attesa',
  pg_temp.candida('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e001'), 'OK');
select pg_temp.expect('... stato pending',
  pg_temp.stato('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e001'), 'pending');
select pg_temp.expect('il cliente non si mette in lista da solo con posti liberi',
  pg_temp.candida('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000e001', 'waitlisted'), 'OK');
select pg_temp.expect('... diventa pending',
  pg_temp.stato('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000e001'), 'pending');
select pg_temp.expect('il cliente non si approva da solo (stato approved rifiutato o riscritto)',
  pg_temp.candida('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000e001', 'approved'), 'OK');
select pg_temp.expect('... diventa pending',
  pg_temp.stato('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000e001'), 'pending');
rollback;

begin;
-- Totale pieno: 3 approvati.
set local role service_role;
insert into public.event_requests (user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e001', 'approved'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000e001', 'approved');
reset role;
select pg_temp.expect('totale pieno: anche chi è senza tipologia va in lista',
  pg_temp.candida('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000e001'), 'OK');
select pg_temp.expect('... stato waitlisted',
  pg_temp.stato('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000e001'), 'waitlisted');
rollback;

-- --- Prove: la policy resta quella della 0021 ----------------------------------------------
begin;
select pg_temp.expect('bozza: rifiutata',
  pg_temp.candida('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e002'), '42501');
select pg_temp.expect('locale non verificato: rifiutata',
  pg_temp.candida('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e003'), '42501');
select pg_temp.expect('per conto di un altro: rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000d1',
    $q$ insert into public.event_requests (user_id, event_id, status)
        values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000e001', 'pending') $q$),
  '42501');
rollback;

begin;
insert into public.blocks (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000d1');
select pg_temp.expect('bloccato dal gestore: rifiutata',
  pg_temp.candida('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e001'), '42501');
rollback;

-- --- Prove: posizione in lista ------------------------------------------------------------------
begin;
select pg_temp.candida('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e001');
select pg_temp.candida('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e001');
select pg_temp.candida('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000e001');
-- Nella stessa transazione now() non cambia: l'ordine lo fissa la prova.
update public.event_requests set created_at = now() + interval '1 minute'
 where user_id = '00000000-0000-0000-0000-0000000000b3';
select pg_temp.expect('posizione: prima coppia in lista',
  pg_temp.posizione('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e001'), '1');
select pg_temp.expect('posizione: seconda coppia in lista',
  pg_temp.posizione('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000e001'), '2');
select pg_temp.expect('posizione: chi non è in lista ha null',
  pg_temp.posizione('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000e001'), '(null)');
select pg_temp.expect('posizione: senza sessione rifiutata',
  pg_temp.value_as('authenticated', null,
    $q$ select public.my_waitlist_position('00000000-0000-0000-0000-00000000e001')::text $q$),
  'ERR 42501');
select pg_temp.expect('posizione: anon non la esegue',
  pg_temp.value_as('anon', null,
    $q$ select public.my_waitlist_position('00000000-0000-0000-0000-00000000e001')::text $q$),
  'ERR 42501');

-- --- Prove: il gestore approva dalla lista quando c'è posto --------------------------------------
select pg_temp.expect('approvare dalla lista con il posto coppie pieno: EC002',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.event_requests set status = 'approved'
         where user_id = '00000000-0000-0000-0000-0000000000b2' $q$),
  'EC002');
select pg_temp.expect('si libera il posto (k1 rifiutato)',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.event_requests set status = 'rejected'
         where user_id = '00000000-0000-0000-0000-0000000000b1' $q$),
  'OK');
select pg_temp.expect('ora il primo in lista si approva',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.event_requests set status = 'approved'
         where user_id = '00000000-0000-0000-0000-0000000000b2' $q$),
  'OK');
select pg_temp.expect('... e il secondo sale al primo posto',
  pg_temp.posizione('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000e001'), '1');
select pg_temp.expect('nessuna promozione automatica: il secondo resta in lista',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000e001'), 'waitlisted');
rollback;

-- service_role inserisce con lo stato che vuole (correzioni manuali).
begin;
set local role service_role;
insert into public.event_requests (user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e001', 'pending');
reset role;
select pg_temp.expect('service_role: stato lasciato com''è',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000e001'), 'pending');
rollback;

-- Le richieste già in attesa non cambiano.
select pg_temp.expect('richieste esistenti invariate',
  pg_temp.stato('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000e001'), 'approved');

\echo 'TUTTE LE PROVE 0023 SUPERATE'
