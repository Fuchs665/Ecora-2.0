-- ============================================================================
-- Prove della migrazione 0019 su un Postgres LOCALE, mai su Supabase.
-- Girano sopra la catena supporto_supabase.sql + 0000 -> 0018 (riga
-- "catena-fino-a" qui sotto). La 0019 la applica la prova stessa, dopo i
-- dati: come in produzione.
--
-- Prova: chi può segnalare cosa, i campi che decide il server, lo snapshot,
-- l'anti-flood, la coda di moderazione, la conservazione, il filtro dei
-- messaggi e l'incontro con delete_account_data (0016).
--
-- Uso: supabase/tests/run_chain.sh. Esito: termina con
-- "TUTTE LE PROVE 0019 SUPERATE", altrimenti si ferma sulla prima prova
-- fallita.
-- ============================================================================
-- catena-fino-a: 0018

-- --- Dati ---------------------------------------------------------------------
-- g1 gestore; c1, c2 clienti approvati alla serata e1 (pubblicata, futura);
-- c3 cliente estraneo. e2 è una bozza di g1. m1, m4 messaggi di c2; m2 di
-- c1; m3 di g1. c1 ha una foto in galleria.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000c2'),
  ('00000000-0000-0000-0000-0000000000c3');
insert into public.profiles (id, nickname) values
  ('00000000-0000-0000-0000-0000000000a1', 'g1'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2'),
  ('00000000-0000-0000-0000-0000000000c3', 'c3');
set role service_role;
update public.profiles set role = 'gestore'
  where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
insert into public.events (id, host_id, title, description, event_date, status,
                           location_name) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000a1',
   'Serata e1', 'desc e1', now() + interval '5 days', 'published', 'Locale g1'),
  ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000a1',
   'Bozza e2', null, now() + interval '9 days', 'draft', 'Locale g1');
insert into public.event_requests (id, user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000f0001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-00000000e001', 'approved'),
  ('00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-0000000000c2',
   '00000000-0000-0000-0000-00000000e001', 'approved');
insert into public.messages (id, event_id, sender_id, content) values
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000e001',
   '00000000-0000-0000-0000-0000000000c2', 'Messaggio offensivo di c2'),
  ('00000000-0000-0000-0000-00000000a002', '00000000-0000-0000-0000-00000000e001',
   '00000000-0000-0000-0000-0000000000c1', 'Messaggio di c1'),
  ('00000000-0000-0000-0000-00000000a003', '00000000-0000-0000-0000-00000000e001',
   '00000000-0000-0000-0000-0000000000a1', 'Messaggio di g1'),
  ('00000000-0000-0000-0000-00000000a004', '00000000-0000-0000-0000-00000000e001',
   '00000000-0000-0000-0000-0000000000c2', 'Altro messaggio di c2');
insert into storage.objects (bucket_id, name, owner) values
  ('profile_photos', '00000000-0000-0000-0000-0000000000c1/1_foto.jpg',
   '00000000-0000-0000-0000-0000000000c1');

-- --- Migrazione ------------------------------------------------------------------
\ir ../migrations/0019_segnalazioni.sql
-- Rieseguibile: la seconda applicazione non deve fallire.
\ir ../migrations/0019_segnalazioni.sql

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

-- Segnalazione come utente uid: restituisce lo SQLSTATE o 'OK'.
create function pg_temp.report(uid text, tipo text, utente text, messaggio text,
                               serata text, motivo text, nota text default null)
returns text
language sql as $$
  select pg_temp.try_as('authenticated', uid, format(
    'insert into public.reports (target_type, target_user_id, target_message_id,
                                 target_event_id, reason, note)
     values (%L, %L, %L, %L, %L, %L)',
    tipo, utente, messaggio, serata, motivo, nota));
$$;

-- --- Prove: segnalare un messaggio ---------------------------------------------------
begin;
select pg_temp.expect('messaggio: c1 segnala il messaggio di c2',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a001', null, 'harassment', '  dettagli  '),
  'OK');
select pg_temp.expect('messaggio: segnalante, bersaglio e stato decisi dal server',
  (select format('%s|%s|%s|%s', reporter_id, target_user_id, status, note)
     from public.reports where target_message_id = '00000000-0000-0000-0000-00000000a001'),
  '00000000-0000-0000-0000-0000000000c1|00000000-0000-0000-0000-0000000000c2|open|dettagli');
select pg_temp.expect('messaggio: snapshot con testo e mittente',
  (select format('%s|%s', content_snapshot ->> 'content', content_snapshot ->> 'sender_id')
     from public.reports where target_message_id = '00000000-0000-0000-0000-00000000a001'),
  'Messaggio offensivo di c2|00000000-0000-0000-0000-0000000000c2');
select pg_temp.expect('messaggio: seconda segnalazione aperta dello stesso rifiutata',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a001', null, 'spam'),
  '23505');
select pg_temp.expect('messaggio: il proprio messaggio non si segnala',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a002', null, 'spam'),
  '42501');
select pg_temp.expect('messaggio: chi non è nella chat non può segnalarlo',
  pg_temp.report('00000000-0000-0000-0000-0000000000c3', 'message', null,
    '00000000-0000-0000-0000-00000000a001', null, 'spam'),
  '42501');
select pg_temp.expect('messaggio: id inesistente, stesso errore di non visibile',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000afff', null, 'spam'),
  '42501');
select pg_temp.expect('messaggio: il gestore della serata può segnalare',
  pg_temp.report('00000000-0000-0000-0000-0000000000a1', 'message', null,
    '00000000-0000-0000-0000-00000000a002', null, 'threats'),
  'OK');
select pg_temp.expect('messaggio: target_user_id forzato dal client ignorato',
  pg_temp.report('00000000-0000-0000-0000-0000000000c2', 'message',
    '00000000-0000-0000-0000-0000000000c3',
    '00000000-0000-0000-0000-00000000a003', null, 'spam'),
  'OK');
select pg_temp.expect('messaggio: bersaglio ricavato dal mittente, non dal client',
  (select target_user_id::text from public.reports
    where target_message_id = '00000000-0000-0000-0000-00000000a003'),
  '00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect('messaggio: motivo di un altro tipo rifiutato',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a004', null, 'underage'),
  '23514');
select pg_temp.expect('messaggio: con una serata nelle colonne rifiutato',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a004',
    '00000000-0000-0000-0000-00000000e001', 'spam'),
  '23514');
select pg_temp.expect('messaggio: nota oltre 500 caratteri rifiutata',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a004', null, 'other', repeat('x', 501)),
  '23514');
select pg_temp.expect('messaggio: nota di soli spazi salvata vuota',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a004', null, 'other', '   '),
  'OK');
select pg_temp.expect('messaggio: nota vuota diventa null',
  (select coalesce(note, '(null)') from public.reports
    where target_message_id = '00000000-0000-0000-0000-00000000a004'),
  '(null)');
commit;

-- Ordine "segnala, poi blocca": dopo il blocco il messaggio non è più
-- visibile e non si può più segnalare.
begin;
select pg_temp.expect('blocco: c1 blocca c2',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1',
    $q$ insert into public.blocks (blocker_id, blocked_id)
        values ('00000000-0000-0000-0000-0000000000c1',
                '00000000-0000-0000-0000-0000000000c2') $q$),
  'OK');
select pg_temp.expect('blocco: messaggio di un bloccato non segnalabile',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'message', null,
    '00000000-0000-0000-0000-00000000a001', null, 'threats'),
  '42501');
select pg_temp.expect('blocco: profilo di un bloccato non segnalabile',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'user',
    '00000000-0000-0000-0000-0000000000c2', null, null, 'spam'),
  '42501');
delete from public.blocks;
commit;

-- --- Prove: segnalare una serata ---------------------------------------------------
begin;
select pg_temp.expect('serata: c3 segnala una serata pubblicata',
  pg_temp.report('00000000-0000-0000-0000-0000000000c3', 'event', null, null,
    '00000000-0000-0000-0000-00000000e001', 'not_a_venue'),
  'OK');
select pg_temp.expect('serata: bersaglio = organizzatore, snapshot con titolo e luogo',
  (select format('%s|%s|%s', target_user_id, content_snapshot ->> 'title',
                 content_snapshot ->> 'location_name')
     from public.reports where target_event_id = '00000000-0000-0000-0000-00000000e001'),
  '00000000-0000-0000-0000-0000000000a1|Serata e1|Locale g1');
select pg_temp.expect('serata: il gestore non segnala la propria',
  pg_temp.report('00000000-0000-0000-0000-0000000000a1', 'event', null, null,
    '00000000-0000-0000-0000-00000000e001', 'spam'),
  '42501');
select pg_temp.expect('serata: una bozza altrui non è segnalabile',
  pg_temp.report('00000000-0000-0000-0000-0000000000c3', 'event', null, null,
    '00000000-0000-0000-0000-00000000e002', 'spam'),
  '42501');
commit;

-- --- Prove: segnalare un utente ------------------------------------------------------
begin;
select pg_temp.expect('utente: il gestore segnala un candidato',
  pg_temp.report('00000000-0000-0000-0000-0000000000a1', 'user',
    '00000000-0000-0000-0000-0000000000c1', null, null, 'underage'),
  'OK');
select pg_temp.expect('utente: snapshot con nickname e galleria',
  (select format('%s|%s', content_snapshot ->> 'nickname',
                 content_snapshot -> 'gallery' ->> 0)
     from public.reports where target_type = 'user'
      and target_user_id = '00000000-0000-0000-0000-0000000000c1'),
  'c1|00000000-0000-0000-0000-0000000000c1/1_foto.jpg');
select pg_temp.expect('utente: se stessi no',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'user',
    '00000000-0000-0000-0000-0000000000c1', null, null, 'spam'),
  '42501');
select pg_temp.expect('utente: uid inesistente rifiutato',
  pg_temp.report('00000000-0000-0000-0000-0000000000c1', 'user',
    '00000000-0000-0000-0000-0000000000ff', null, null, 'spam'),
  '42501');
commit;

-- --- Prove: permessi ---------------------------------------------------------------
begin;
select pg_temp.expect('permessi: anon non segnala',
  pg_temp.try_as('anon', null,
    $q$ insert into public.reports (target_type, target_user_id, reason)
        values ('user', '00000000-0000-0000-0000-0000000000c1', 'spam') $q$),
  '42501');
select pg_temp.expect('permessi: il client non sceglie lo stato',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.reports (target_type, target_user_id, reason, status)
        values ('user', '00000000-0000-0000-0000-0000000000c3', 'spam', 'dismissed') $q$),
  '42501');
select pg_temp.expect('permessi: il client non sceglie il segnalante',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.reports (target_type, target_user_id, reason, reporter_id)
        values ('user', '00000000-0000-0000-0000-0000000000c3', 'spam',
                '00000000-0000-0000-0000-0000000000c3') $q$),
  '42501');
select pg_temp.expect('permessi: il client non scrive lo snapshot',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.reports (target_type, target_user_id, reason, content_snapshot)
        values ('user', '00000000-0000-0000-0000-0000000000c3', 'spam', '{}') $q$),
  '42501');
select pg_temp.expect('permessi: insert con RETURNING rifiutato (l''app non usa .select())',
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c2',
    $q$ insert into public.reports (target_type, target_user_id, reason)
        values ('user', '00000000-0000-0000-0000-0000000000c3', 'spam') returning id $q$),
  '42501');
select pg_temp.expect(format('permessi: %s rifiutato al client', q),
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1', q),
  '42501')
from unnest(array[
  'select 1 from public.reports',
  $q$update public.reports set status = 'dismissed'$q$,
  'delete from public.reports',
  'select 1 from public.reports_open',
  'select 1 from public.blocked_terms',
  $q$insert into public.blocked_terms (term) values ('x')$q$,
  'select public.purge_old_reports()']) as q;
select pg_temp.expect('permessi: la view è security_invoker',
  (select coalesce(array_to_string(reloptions, ','), '-') from pg_class
    where oid = 'public.reports_open'::regclass),
  'security_invoker=true');
commit;

-- --- Prove: tetto giornaliero ----------------------------------------------------------
-- c3 ha già 1 segnalazione (serata e1). Se ne aggiungono 19 chiuse sullo
-- stesso utente (l'indice vale solo per le aperte), poi la ventunesima.
begin;
do $$
begin
  for i in 1..19 loop
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c3', true);
    set local role authenticated;
    insert into public.reports (target_type, target_user_id, reason)
      values ('user', '00000000-0000-0000-0000-0000000000c2', 'spam');
    reset role;
    update public.reports set status = 'dismissed', resolved_at = now()
     where reporter_id = '00000000-0000-0000-0000-0000000000c3'
       and target_type = 'user' and status = 'open';
  end loop;
end $$;
select pg_temp.expect('tetto: 20 segnalazioni di c3 nelle 24 ore',
  (select count(*)::text from public.reports
    where reporter_id = '00000000-0000-0000-0000-0000000000c3'), '20');
select pg_temp.expect('tetto: la ventunesima rifiutata (EC429)',
  pg_temp.report('00000000-0000-0000-0000-0000000000c3', 'user',
    '00000000-0000-0000-0000-0000000000c1', null, null, 'spam'),
  'EC429');
update public.reports set created_at = created_at - interval '25 hours'
 where reporter_id = '00000000-0000-0000-0000-0000000000c3';
select pg_temp.expect('tetto: dopo 24 ore si torna a segnalare',
  pg_temp.report('00000000-0000-0000-0000-0000000000c3', 'user',
    '00000000-0000-0000-0000-0000000000c1', null, null, 'spam'),
  'OK');
commit;

-- --- Prove: coda di moderazione ------------------------------------------------------
begin;
set local role service_role;
select pg_temp.expect('coda: "minorenne" in cima',
  (select reason from public.reports_open limit 1), 'underage');
select pg_temp.expect('coda: chiusa senza data di chiusura rifiutata',
  pg_temp.try_as('service_role', null,
    $q$ update public.reports set status = 'actioned'
        where reason = 'underage' $q$),
  '23514');
update public.reports set status = 'actioned', resolved_at = now()
 where reason = 'underage';
select pg_temp.expect('coda: chiusa, esce dalla coda',
  (select count(*)::text from public.reports_open where reason = 'underage'), '0');
reset role;
commit;

-- --- Prove: contenuto rimosso e account cancellati ---------------------------------
begin;
delete from public.messages where id = '00000000-0000-0000-0000-00000000a001';
select pg_temp.expect('rimozione: messaggio cancellato, segnalazione e snapshot restano',
  (select format('%s|%s', coalesce(target_message_id::text, 'null'),
                 content_snapshot ->> 'content')
     from public.reports where reason = 'harassment'),
  'null|Messaggio offensivo di c2');
commit;

begin;
set local role service_role;
-- c2: segnalato (messaggio a004, profilo) e segnalante (messaggio a003).
-- c1 ha due segnalazioni aperte su due messaggi di c2 (a001 già rimosso,
-- a004): quando anche a004 sparisce non devono collidere.
select pg_temp.expect('cancellazione: delete_account_data(c2) funziona con le segnalazioni',
  (select (public.delete_account_data('00000000-0000-0000-0000-0000000000c2') ->> 'role')),
  'cliente');
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c2';
select pg_temp.expect('cancellazione: nessun riferimento a c2 nelle colonne',
  (select count(*)::text from public.reports
    where '00000000-0000-0000-0000-0000000000c2' in (reporter_id, target_user_id)), '0');
select pg_temp.expect('cancellazione: le segnalazioni ricevute restano con lo snapshot',
  (select content_snapshot ->> 'content' from public.reports
    where reason = 'harassment'), 'Messaggio offensivo di c2');
select pg_temp.expect('cancellazione: la segnalazione fatta resta senza segnalante',
  (select coalesce(reporter_id::text, 'null') from public.reports
    where content_snapshot ->> 'content' = 'Messaggio di g1'), 'null');
-- g1: la serata futura e1 viene cancellata.
set local role service_role;
select pg_temp.expect('cancellazione: delete_account_data(g1)',
  (select (public.delete_account_data('00000000-0000-0000-0000-0000000000a1') ->> 'role')),
  'gestore');
reset role;
select pg_temp.expect('cancellazione: serata cancellata, snapshot resta',
  (select format('%s|%s', coalesce(target_event_id::text, 'null'),
                 content_snapshot ->> 'title')
     from public.reports where reason = 'not_a_venue'),
  'null|Serata e1');
commit;

-- --- Prove: conservazione -------------------------------------------------------------
begin;
update public.reports set created_at = now() - interval '13 months'
 where reason = 'not_a_venue';
set local role service_role;
select pg_temp.expect('conservazione: purge cancella solo oltre i 12 mesi',
  (select public.purge_old_reports()::text), '1');
select pg_temp.expect('conservazione: seconda purge senza nulla da fare',
  (select public.purge_old_reports()::text), '0');
reset role;
commit;

-- --- Prove: filtro dei messaggi ----------------------------------------------------------
-- g1 e c2 sono stati cancellati e la serata e1 non c'è più: nuova serata
-- di un nuovo gestore, con c1 approvato.
insert into public.blocked_terms (term) values ('parolaccia'), ('a.b');
insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a2');
insert into public.profiles (id, nickname) values
  ('00000000-0000-0000-0000-0000000000a2', 'g2');
insert into public.events (id, host_id, title, event_date, status) values
  ('00000000-0000-0000-0000-00000000e003', '00000000-0000-0000-0000-0000000000a2',
   'Serata e3', now() + interval '3 days', 'published');
insert into public.event_requests (id, user_id, event_id, status) values
  ('00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-00000000e003', 'approved');
begin;
select pg_temp.expect(format('filtro: "%s" -> %s', txt, want),
  pg_temp.try_as('authenticated', '00000000-0000-0000-0000-0000000000c1', format(
    'insert into public.messages (event_id, sender_id, content) values (%L, %L, %L)',
    '00000000-0000-0000-0000-00000000e003', '00000000-0000-0000-0000-0000000000c1', txt)),
  want)
from (values ('Che PAROLACCIA!', 'EC422'),
             ('parolacciata', 'OK'),
             ('Ciao a tutti', 'OK'),
             ('scrivo a.b qui', 'EC422'),
             ('scrivo axb qui', 'OK')) as v(txt, want);
select pg_temp.expect('filtro: anche la modifica del testo passa dal filtro',
  pg_temp.try_as('service_role', null,
    $q$ update public.messages set content = 'parolaccia'
        where content = 'Ciao a tutti' $q$),
  'EC422');
commit;

\echo 'TUTTE LE PROVE 0019 SUPERATE'
