-- ============================================================================
-- Blocco E.1a: cancellazione account (Google Play 2024, Apple 5.1.1(v),
-- GDPR art. 17). Run in: Supabase Dashboard -> SQL Editor.
-- Transazionale. Idempotente.
--
-- TOCCA AUTH, RLS E DATI PERSONALI. Le due funzioni qui sotto sono
-- eseguibili SOLO da service_role, cioè dalla Edge Function
-- "delete-account" (supabase/functions/delete-account). Mai dall'app.
--
-- Chiavi esterne reali lette dal database il 02/10/2026 (lo schema base non
-- è nelle migrazioni):
--   profiles.id            -> auth.users  on delete cascade
--   events.host_id         -> profiles    on delete cascade
--   event_requests.user_id -> profiles    on delete cascade
--   event_requests.event_id-> events      on delete cascade
--   messages.sender_id     -> auth.users  on delete cascade
--   messages.event_id      -> events      on delete cascade
--   subscriptions.user_id  -> profiles    on delete cascade
--   blocks, device_tokens  -> auth.users  on delete cascade
--   event_attendance.request_id -> event_requests on delete cascade (0015)
-- Il cascade da solo cancellerebbe anche le serate passate di un gestore e,
-- a catena, le presenze dei suoi ospiti: per questo la cancellazione si fa
-- qui, in modo esplicito e in una transazione, PRIMA di eliminare l'utente
-- auth. I file nello Storage il cascade non li tocca: li elenca
-- account_deletion_files() e li cancella la Edge Function con l'API Storage
-- (Supabase blocca il DELETE SQL su storage.objects).
--
-- Cosa succede ai dati:
--   cliente: profilo, richieste, presenze, messaggi inviati, blocchi (in
--            entrambe le direzioni), token push -> cancellati.
--   gestore: in più abbonamento e serate. Le serate passate con presenze
--            registrate restano in forma anonima (host_id vuoto, stato
--            'archived', niente titolo, descrizione, luogo, coordinate,
--            copertina; chat cancellata) con le sole richieste che hanno una
--            presenza: lo storico degli ospiti è un dato degli ospiti.
--            Tutte le altre serate (future comprese) sono cancellate con
--            richieste e chat.
--   resta:   una riga anonima in account_deletions (data, ruolo, canale;
--            né uid né email), per dimostrare l'esecuzione (art. 5.2).
-- ============================================================================

begin;

-- 1) EVENTS: spazio per le serate archiviate ----------------------------------
alter table public.events alter column host_id drop not null;

-- Il check su status è stato creato dalla dashboard e il nome non è noto:
-- si toglie ogni check che riguarda status e se ne crea uno con nome fisso.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.events'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%status%'
  loop
    execute format('alter table public.events drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.events add constraint events_status_check
  check (status = any (array['draft', 'published', 'cancelled', 'archived']));

-- 2) REGISTRO ANONIMO DELLE CANCELLAZIONI ----------------------------------------
create table if not exists public.account_deletions (
  id         uuid primary key default gen_random_uuid(),
  role       text,
  channel    text not null check (channel in ('app', 'web', 'email')),
  deleted_at timestamptz not null default now()
);

alter table public.account_deletions enable row level security;
-- Nessuna policy: lo scrivono solo service_role (Edge Function) e il SQL Editor.
revoke all on table public.account_deletions from public, anon, authenticated;
grant select, insert on table public.account_deletions to service_role;

-- 3) FILE DA CANCELLARE NELLO STORAGE --------------------------------------------
-- Galleria: la cartella radice è l'uid (0008). Copertine: il path non
-- contiene l'uid (0004), quindi si cercano per proprietario del file e per
-- URL salvato nelle serate dell'utente.
create or replace function public.account_deletion_files(p_user_id uuid)
returns table (bucket text, path text)
language sql
stable
security invoker
set search_path = public
as $$
  select o.bucket_id::text, o.name::text
  from storage.objects o
  where (o.bucket_id = 'profile_photos'
         and (storage.foldername(o.name))[1] = p_user_id::text)
     or (o.bucket_id = 'event_covers' and o.owner = p_user_id)
  union
  select 'event_covers',
         split_part(e.image_url, '/object/public/event_covers/', 2)
  from public.events e
  where e.host_id = p_user_id
    and e.image_url like '%/object/public/event_covers/_%';
$$;

revoke execute on function public.account_deletion_files(uuid)
  from public, anon, authenticated;
grant execute on function public.account_deletion_files(uuid) to service_role;

-- 4) CANCELLAZIONE DEI DATI --------------------------------------------------------
-- SECURITY INVOKER: gira con i permessi di chi la chiama (service_role, che
-- salta la RLS). Se il grant sfuggisse, un utente normale si scontrerebbe
-- comunque con la RLS. Rieseguibile: una seconda chiamata non trova nulla.
-- Ritorna il ruolo dell'utente e i conteggi, per il registro e i log.
create or replace function public.delete_account_data(p_user_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_role              text;
  v_archived_events   int;
  v_deleted_events    int;
  v_deleted_requests  int;
  v_deleted_messages  int;
begin
  if p_user_id is null then
    raise exception 'Utente mancante' using errcode = '22004';
  end if;

  select role into v_role from public.profiles where id = p_user_id;

  -- a) Serate passate del gestore con presenze registrate: archiviate.
  with archived as (
    update public.events e
       set host_id       = null,
           status        = 'archived',
           title         = 'Serata archiviata',
           description   = null,
           location_name = null,
           latitude      = null,
           longitude     = null,
           image_url     = null
     where e.host_id = p_user_id
       and e.event_date < now()
       and exists (
         select 1
         from public.event_requests r
         join public.event_attendance a on a.request_id = r.id
         where r.event_id = e.id
       )
    returning e.id
  ),
  -- La chat delle serate archiviate non serve più a nessuno.
  dropped_chat as (
    delete from public.messages m
     using archived
     where m.event_id = archived.id
    returning 1
  ),
  -- Delle serate archiviate restano solo le richieste con una presenza.
  dropped_requests as (
    delete from public.event_requests r
     using archived
     where r.event_id = archived.id
       and not exists (select 1 from public.event_attendance a
                       where a.request_id = r.id)
    returning 1
  )
  select (select count(*) from archived),
         (select count(*) from dropped_chat),
         (select count(*) from dropped_requests)
    into v_archived_events, v_deleted_messages, v_deleted_requests;

  -- b) Presenze: quelle dell'utente come ospite e quelle delle sue serate
  --    che non sono state archiviate (cioè tutte quelle che restano sue).
  delete from public.event_attendance a
   using public.event_requests r
   where a.request_id = r.id
     and (r.user_id = p_user_id
          or r.event_id in (select id from public.events
                            where host_id = p_user_id));

  -- c) Messaggi inviati dall'utente e chat delle sue serate.
  with d as (
    delete from public.messages
     where sender_id = p_user_id
        or event_id in (select id from public.events where host_id = p_user_id)
    returning 1
  )
  select v_deleted_messages + count(*) into v_deleted_messages from d;

  -- d) Richieste dell'utente e richieste alle sue serate.
  with d as (
    delete from public.event_requests
     where user_id = p_user_id
        or event_id in (select id from public.events where host_id = p_user_id)
    returning 1
  )
  select v_deleted_requests + count(*) into v_deleted_requests from d;

  -- e) Serate rimaste (future, o passate senza presenze).
  with d as (
    delete from public.events where host_id = p_user_id returning 1
  )
  select count(*) into v_deleted_events from d;

  -- f) Il resto, dai figli al profilo.
  delete from public.blocks
   where blocker_id = p_user_id or blocked_id = p_user_id;
  delete from public.device_tokens where user_id = p_user_id;
  delete from public.subscriptions where user_id = p_user_id;
  delete from public.profiles where id = p_user_id;

  return jsonb_build_object(
    'role',              v_role,
    'archived_events',   v_archived_events,
    'deleted_events',    v_deleted_events,
    'deleted_requests',  v_deleted_requests,
    'deleted_messages',  v_deleted_messages
  );
end;
$$;

revoke execute on function public.delete_account_data(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- ============================================================================
-- a) funzioni: EXECUTE solo per service_role (attese false, false, true):
--   select has_function_privilege('anon',
--            'public.delete_account_data(uuid)', 'execute'),
--          has_function_privilege('authenticated',
--            'public.delete_account_data(uuid)', 'execute'),
--          has_function_privilege('service_role',
--            'public.delete_account_data(uuid)', 'execute');
--   (stesse tre righe con 'public.account_deletion_files(uuid)')
--
-- b) events: host_id nullable e 'archived' ammesso:
--   select is_nullable from information_schema.columns
--   where table_schema = 'public' and table_name = 'events'
--     and column_name = 'host_id';                          -- atteso YES
--   select pg_get_constraintdef(oid) from pg_constraint
--   where conrelid = 'public.events'::regclass and contype = 'c';
--
-- c) Prima e dopo aver cancellato un account di prova, righe rimaste per
--    quell'uid (attese tutte 0 dopo la cancellazione):
--   select 'profiles' t, count(*) from public.profiles where id = '<UID>'
--   union all select 'events', count(*) from public.events where host_id = '<UID>'
--   union all select 'event_requests', count(*) from public.event_requests where user_id = '<UID>'
--   union all select 'messages', count(*) from public.messages where sender_id = '<UID>'
--   union all select 'blocks', count(*) from public.blocks where '<UID>' in (blocker_id, blocked_id)
--   union all select 'device_tokens', count(*) from public.device_tokens where user_id = '<UID>'
--   union all select 'subscriptions', count(*) from public.subscriptions where user_id = '<UID>'
--   union all select 'auth.users', count(*) from auth.users where id = '<UID>'
--   union all select 'storage', count(*) from storage.objects
--     where owner = '<UID>' or name like '<UID>/%';
--
-- d) Registro: select * from public.account_deletions order by deleted_at desc;
--
-- Prove di comportamento: supabase/tests/0016_cancellazione_account_test.sql
-- (Postgres locale, mai su Supabase).
