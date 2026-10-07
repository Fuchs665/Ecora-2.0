-- ============================================================================
-- Prove della migrazione 0022 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0021 (riga
-- "catena-fino-a" qui sotto). La 0022 la applica la prova stessa, dopo i
-- dati: come in produzione.
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0022 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0021

-- --- Dati ---------------------------------------------------------------------
-- g1 gestore verificato. Candidati: k1, k2 coppie; d1, d2 donne; u1 uomo;
-- x1 senza tipologia. e1: serata pubblicata di g1 (max_guests 4), con una
-- candidatura in attesa per ognuno. e0: serata creata prima della 0022 con
-- già 2 approvati e max_guests 1 (oltre il limite).
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000b2'),
  ('00000000-0000-0000-0000-0000000000d1'),
  ('00000000-0000-0000-0000-0000000000d2'),
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000f1');
insert into public.profiles (id, nickname, profile_type) values
  ('00000000-0000-0000-0000-0000000000a1', 'g1', null),
  ('00000000-0000-0000-0000-0000000000b1', 'k1', 'Coppia U/D'),
  ('00000000-0000-0000-0000-0000000000b2', 'k2', 'Coppia D/D'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1', 'Donna Singola'),
  ('00000000-0000-0000-0000-0000000000d2', 'd2', 'Donna Singola'),
  ('00000000-0000-0000-0000-0000000000e1', 'u1', 'Uomo Singolo'),
  ('00000000-0000-0000-0000-0000000000f1', 'x1', null);
set role service_role;
update public.profiles set role = 'gestore', is_verified = true
  where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
insert into public.events (id, host_id, title, event_date, status, max_guests) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000a1',
   'e1', now() + interval '5 days', 'published', 4),
  ('00000000-0000-0000-0000-00000000e000', '00000000-0000-0000-0000-0000000000a1',
   'e0', now() + interval '6 days', 'published', 1);
insert into public.event_requests (id, user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000001b1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000001b2', '00000000-0000-0000-0000-0000000000b2',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000001d1', '00000000-0000-0000-0000-0000000000d1',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000001d2', '00000000-0000-0000-0000-0000000000d2',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000001e1', '00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000001f1', '00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-00000000e001', 'pending'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-00000000e000', 'approved'),
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d1',
   '00000000-0000-0000-0000-00000000e000', 'approved'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-00000000e000', 'pending');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0022_posti_per_tipologia.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0022_posti_per_tipologia.sql

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

-- Il gestore g1 approva (o rifiuta) una candidatura: OK o SQLSTATE.
create function pg_temp.esito(req text, stato text) returns text
language sql as $$
  select pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    format('update public.event_requests set status = %L where id = %L', stato, req))
$$;

create function pg_temp.limiti(c int, d int, u int, tot int) returns void
language sql as $$
  update public.events set max_couples = c, max_women = d, max_men = u, max_guests = tot
   where id = '00000000-0000-0000-0000-00000000e001'
$$;

-- --- Prove: categoria ---------------------------------------------------------------
select pg_temp.expect('categoria: coppie',
  (select string_agg(coalesce(public.guest_category(t), '-'), ',')
     from unnest(array['Coppia U/D', 'Coppia D/D', 'Coppia U/U']) t),
  'coppia,coppia,coppia');
select pg_temp.expect('categoria: donna, uomo, nessuna',
  public.guest_category('Donna Singola') || ',' || public.guest_category('Uomo Singolo')
    || ',' || coalesce(public.guest_category(null), '-')
    || ',' || coalesce(public.guest_category('Altro'), '-'),
  'donna,uomo,-,-');

-- --- Prove: vincolo sui limiti ------------------------------------------------------------
begin;
select pg_temp.expect('vincolo: categoria oltre il totale rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.events set max_couples = 5
         where id = '00000000-0000-0000-0000-00000000e001' $q$), '23514');
select pg_temp.expect('vincolo: negativo rifiutato',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.events set max_men = -1
         where id = '00000000-0000-0000-0000-00000000e001' $q$), '23514');
select pg_temp.expect('vincolo: limiti validi accettati dal gestore',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.events set max_couples = 2, max_women = 1, max_men = 0
         where id = '00000000-0000-0000-0000-00000000e001' $q$), 'OK');
rollback;

-- --- Prove: limite totale ------------------------------------------------------------------
begin;
select pg_temp.limiti(null, null, null, 2);
select pg_temp.expect('totale: primo approvato', pg_temp.esito('00000000-0000-0000-0000-0000000001b1', 'approved'), 'OK');
select pg_temp.expect('totale: secondo approvato', pg_temp.esito('00000000-0000-0000-0000-0000000001d1', 'approved'), 'OK');
select pg_temp.expect('totale: terzo rifiutato (al completo)', pg_temp.esito('00000000-0000-0000-0000-0000000001e1', 'approved'), 'EC001');
select pg_temp.expect('totale: rifiutare un approvato libera il posto', pg_temp.esito('00000000-0000-0000-0000-0000000001d1', 'rejected'), 'OK');
select pg_temp.expect('totale: ... e ora il terzo passa', pg_temp.esito('00000000-0000-0000-0000-0000000001e1', 'approved'), 'OK');
select pg_temp.expect('totale: rifiutare una candidatura non conta', pg_temp.esito('00000000-0000-0000-0000-0000000001f1', 'rejected'), 'OK');
select pg_temp.expect('totale: riapprovare un già approvato non ricontrolla',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ update public.event_requests set status = 'approved'
         where id = '00000000-0000-0000-0000-0000000001b1' $q$), 'OK');
rollback;

-- --- Prove: limiti per tipologia --------------------------------------------------------------
begin;
select pg_temp.limiti(1, 2, 0, 4);
select pg_temp.expect('coppie: la prima passa', pg_temp.esito('00000000-0000-0000-0000-0000000001b1', 'approved'), 'OK');
select pg_temp.expect('coppie: la seconda no (EC002)', pg_temp.esito('00000000-0000-0000-0000-0000000001b2', 'approved'), 'EC002');
select pg_temp.expect('donne: la prima passa', pg_temp.esito('00000000-0000-0000-0000-0000000001d1', 'approved'), 'OK');
select pg_temp.expect('donne: la seconda passa (limite 2)', pg_temp.esito('00000000-0000-0000-0000-0000000001d2', 'approved'), 'OK');
select pg_temp.expect('uomini: limite 0, rifiutato (EC004)', pg_temp.esito('00000000-0000-0000-0000-0000000001e1', 'approved'), 'EC004');
select pg_temp.expect('senza tipologia: conta solo sul totale e passa', pg_temp.esito('00000000-0000-0000-0000-0000000001f1', 'approved'), 'OK');
select pg_temp.expect('totale raggiunto (4): la coppia resta fuori anche se', pg_temp.esito('00000000-0000-0000-0000-0000000001b2', 'approved'), 'EC001');
rollback;

begin;
select pg_temp.limiti(null, 1, null, 4);
select pg_temp.expect('donne: limite 1', pg_temp.esito('00000000-0000-0000-0000-0000000001d1', 'approved'), 'OK');
select pg_temp.expect('donne: la seconda no (EC003)', pg_temp.esito('00000000-0000-0000-0000-0000000001d2', 'approved'), 'EC003');
select pg_temp.expect('coppie senza limite: passano', pg_temp.esito('00000000-0000-0000-0000-0000000001b1', 'approved'), 'OK');
rollback;

-- --- Prove: correzioni manuali e serate oltre il limite ------------------------------------------
begin;
select pg_temp.limiti(null, null, null, 1);
select pg_temp.expect('service_role approva oltre il limite',
  pg_temp.try_as('service_role', null,
    $q$ update public.event_requests set status = 'approved'
         where event_id = '00000000-0000-0000-0000-00000000e001' $q$), 'OK');
rollback;

begin;
select pg_temp.expect('serata già oltre il limite: nessuno tolto',
  (select count(*)::text from public.event_requests
    where event_id = '00000000-0000-0000-0000-00000000e000' and status = 'approved'), '2');
select pg_temp.expect('serata già oltre il limite: non se ne approvano altri',
  pg_temp.esito('00000000-0000-0000-0000-0000000000e1', 'approved'), 'EC001');
rollback;

-- --- Prove: feed ---------------------------------------------------------------------------------
begin;
select pg_temp.limiti(2, 2, 1, 4);
set local role service_role;
update public.event_requests set status = 'approved'
 where id in ('00000000-0000-0000-0000-0000000001b1', '00000000-0000-0000-0000-0000000001d1',
              '00000000-0000-0000-0000-0000000001d2', '00000000-0000-0000-0000-0000000001f1');
reset role;
select pg_temp.expect('feed: limiti e approvati per categoria',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000e1',
    $q$ select concat_ws('|', max_guests, approved_count, max_couples, max_women, max_men,
                         approved_couples, approved_women, approved_men)
          from public.get_events_with_stats() where title = 'e1' $q$),
  '4|4|2|2|1|1|2|0');
select pg_temp.expect('feed: serata senza limiti per categoria',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000e1',
    $q$ select concat_ws('|', max_guests, approved_count, coalesce(max_couples::text, '-'),
                         approved_couples, approved_women, approved_men)
          from public.get_events_with_stats() where title = 'e0' $q$),
  '1|2|-|1|1|0');
select pg_temp.expect('feed: anon non lo esegue',
  pg_temp.value_as('anon', null, 'select count(*)::text from public.get_events_with_stats()'),
  'ERR 42501');
rollback;

begin;
set local role service_role;
update public.profiles set is_verified = false
 where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
select pg_temp.expect('feed: il filtro dei locali verificati (0021) resta',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000e1',
    'select count(*)::text from public.get_events_with_stats()'), '0');
rollback;

\echo 'TUTTE LE PROVE 0022 SUPERATE'
