-- ============================================================================
-- Prove della migrazione 0020 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0019 (riga
-- "catena-fino-a" qui sotto). La 0020 la applica la prova stessa, dopo i
-- dati: come in produzione.
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0020 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0019

-- --- Dati ---------------------------------------------------------------------
-- v1 iscritto prima della 0020 con timestamp scritti dall'app; g1 gestore;
-- n1..n3 hanno solo l'utente auth: il profilo lo creano le prove.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000d1'),
  ('00000000-0000-0000-0000-0000000000d2'),
  ('00000000-0000-0000-0000-0000000000d3');
-- Da service_role: la 0017 farebbe nascere cliente anche il gestore.
begin;
set local role service_role;
insert into public.profiles (id, role, nickname, is_verified,
                             age_confirmed_at, terms_accepted_at) values
  ('00000000-0000-0000-0000-0000000000c1', 'cliente', 'v1', false,
   '2026-01-01 10:00+00', '2026-01-01 10:00+00'),
  ('00000000-0000-0000-0000-0000000000a1', 'gestore', 'g1', true, null, null);
commit;

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0020_consenso_lato_server.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0020_consenso_lato_server.sql

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

-- Come try_as, ma restituisce il valore della prima colonna della query.
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

-- Quali campi di consenso sono valorizzati: età|termini|versione|art9.
create function pg_temp.consensi(uid text) returns text
language sql as $$
  select coalesce((
    select (age_confirmed_at is not null)::text || '|'
        || (terms_accepted_at is not null)::text || '|'
        || coalesce(terms_version, '-') || '|'
        || (sensitive_consent_at is not null)::text
      from public.profiles where id = uid::uuid), '(assente)')
$$;

-- --- Prove: il client non scrive i consensi -------------------------------------
begin;
select pg_temp.expect('insert dell''app con i timestamp: nessun errore',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000d1',
    $q$ insert into public.profiles (id, nickname, role, age_confirmed_at,
          terms_accepted_at, terms_version, sensitive_consent_at)
        values (auth.uid(), 'd1', 'cliente', now(), now(), '2026-10-06', now()) $q$),
  'OK');
select pg_temp.expect('insert dell''app: ... i consensi restano vuoti',
  pg_temp.consensi('00000000-0000-0000-0000-0000000000d1'), 'false|false|-|false');
select pg_temp.expect('update dell''app sui consensi: nessun errore',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles
           set age_confirmed_at = '2020-01-01', terms_accepted_at = null,
               terms_version = '2026-10-06', sensitive_consent_at = now(),
               nickname = 'v1bis'
         where id = auth.uid() $q$),
  'OK');
select pg_temp.expect('update dell''app: ... i consensi restano com''erano',
  (select age_confirmed_at::text || '|' || terms_accepted_at::text || '|'
          || coalesce(terms_version, '-') || '|'
          || (sensitive_consent_at is not null)::text
     from public.profiles where id = '00000000-0000-0000-0000-0000000000c1'),
  '2026-01-01 10:00:00+00|2026-01-01 10:00:00+00|-|false');
select pg_temp.expect('update dell''app: ... le altre colonne cambiano',
  (select nickname from public.profiles
    where id = '00000000-0000-0000-0000-0000000000c1'), 'v1bis');
select pg_temp.expect('upsert di riparazione con i metadati: nessun errore',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000d2',
    $q$ insert into public.profiles (id, nickname, role, age_confirmed_at, terms_accepted_at)
        values (auth.uid(), 'd2', 'cliente', now(), now())
        on conflict (id) do nothing $q$),
  'OK');
select pg_temp.expect('upsert di riparazione: ... consensi vuoti',
  pg_temp.consensi('00000000-0000-0000-0000-0000000000d2'), 'false|false|-|false');
commit;

-- --- Prove: cosa resta da accettare ----------------------------------------------
begin;
select pg_temp.expect('terms_to_accept: iscritto prima della 0020 deve accettare',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    'select public.terms_to_accept()'), '2026-10-06');
select pg_temp.expect('terms_to_accept: anche il gestore',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    'select public.terms_to_accept()'), '2026-10-06');
select pg_temp.expect('terms_to_accept: senza sessione rifiutata',
  pg_temp.value_as('authenticated', null, 'select public.terms_to_accept()'),
  'ERR 42501');
select pg_temp.expect('terms_to_accept: anon non la esegue',
  pg_temp.value_as('anon', null, 'select public.terms_to_accept()'), 'ERR 42501');
select pg_temp.expect('current_terms_version: anon non la esegue',
  pg_temp.value_as('anon', null, 'select public.current_terms_version()'), 'ERR 42501');
commit;

-- --- Prove: accettazione ----------------------------------------------------------
begin;
select pg_temp.expect('accept_terms: versione vecchia rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select public.accept_terms('2026-01-01') $q$), '22023');
select pg_temp.expect('accept_terms: versione null rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select public.accept_terms(null) $q$), '22023');
select pg_temp.expect('accept_terms: senza sessione rifiutata',
  pg_temp.try_as('authenticated', null,
    $q$ select public.accept_terms('2026-10-06') $q$), '42501');
select pg_temp.expect('accept_terms: anon non la esegue',
  pg_temp.try_as('anon', null,
    $q$ select public.accept_terms('2026-10-06') $q$), '42501');
select pg_temp.expect('accept_terms: senza profilo rifiutata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000d3',
    $q$ select public.accept_terms('2026-10-06') $q$), 'P0002');
select pg_temp.expect('accept_terms: versione in vigore accettata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select public.accept_terms('2026-10-06') $q$), 'OK');
select pg_temp.expect('accept_terms: ... tutti i consensi scritti',
  pg_temp.consensi('00000000-0000-0000-0000-0000000000c1'), 'true|true|2026-10-06|true');
select pg_temp.expect('accept_terms: ... con l''ora del server (non quella vecchia)',
  (select (age_confirmed_at = now() and terms_accepted_at = now()
           and sensitive_consent_at = now())::text
     from public.profiles where id = '00000000-0000-0000-0000-0000000000c1'), 'true');
select pg_temp.expect('accept_terms: ... solo per il proprio profilo',
  pg_temp.consensi('00000000-0000-0000-0000-0000000000a1'), 'false|false|-|false');
select pg_temp.expect('terms_to_accept: dopo l''accettazione niente da accettare',
  pg_temp.value_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    'select public.terms_to_accept()'), '(null)');
select pg_temp.expect('accept_terms: il gestore accetta',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
    $q$ select public.accept_terms('2026-10-06') $q$), 'OK');
select pg_temp.expect('accept_terms: ... e resta gestore verificato',
  (select role || '|' || is_verified::text from public.profiles
    where id = '00000000-0000-0000-0000-0000000000a1'), 'gestore|true');
select pg_temp.expect('update dell''app dopo l''accettazione: consensi intatti',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ update public.profiles set terms_version = null, age_confirmed_at = null
         where id = auth.uid() $q$), 'OK');
select pg_temp.expect('update dell''app dopo l''accettazione: ... ancora in regola',
  pg_temp.consensi('00000000-0000-0000-0000-0000000000c1'), 'true|true|2026-10-06|true');
commit;

-- --- Prove: lettura -------------------------------------------------------------------
begin;
select pg_temp.expect('l''app non legge la versione accettata',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select terms_version from public.profiles where id = auth.uid() $q$), '42501');
select pg_temp.expect('l''app non legge il consenso art. 9',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ select sensitive_consent_at from public.profiles where id = auth.uid() $q$), '42501');
commit;

-- Dal SQL Editor (postgres) e da service_role i consensi si possono
-- correggere (procedure manuali documentate).
update public.profiles set terms_version = 'manuale'
 where id = '00000000-0000-0000-0000-0000000000d1';
select pg_temp.expect('postgres scrive i consensi',
  pg_temp.consensi('00000000-0000-0000-0000-0000000000d1'), 'false|false|manuale|false');

\echo 'TUTTE LE PROVE 0020 SUPERATE'
