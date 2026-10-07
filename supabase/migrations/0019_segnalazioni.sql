-- ============================================================================
-- Blocco E.2a: segnalazione di messaggi, utenti e serate, filtro dei
-- messaggi e coda di moderazione (Apple 1.2, Google UGC).
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA RLS E DATI PERSONALI.
--   - reports: l'app può solo INSERIRE (colonne bersaglio, motivo, nota),
--     come se stessa e con la RLS dei messaggi e delle serate di chi
--     segnala; nessuna lettura, modifica o cancellazione dal client. La coda
--     la leggono solo service_role e il SQL Editor (view reports_open).
--   - content_snapshot conserva una copia del contenuto segnalato (testo del
--     messaggio, dati della serata, nickname e galleria dell'utente) anche se
--     l'autore lo cancella o cancella l'account: è la prova per la
--     moderazione. Conservazione: 12 mesi dalla segnalazione, poi
--     purge_old_reports() (procedura mensile in supabase/MODERAZIONE.md).
--   - Cancellazione account (0016, invariata): le chiavi esterne sono
--     "on delete set null", quindi le segnalazioni fatte o ricevute da chi
--     si cancella restano senza uid fino alla scadenza dei 12 mesi.
--   - blocked_terms: parole rifiutate nei messaggi della chat, gestite dal
--     SQL Editor; nessun accesso dal client. La lista parte vuota.
--
-- Tipi letti dal catalogo della produzione (02/10/2026):
-- messages.id, events.id e profiles.id sono uuid.
-- ============================================================================

begin;

-- 1) TABELLA REPORTS ------------------------------------------------------------
create table if not exists public.reports (
  id                uuid primary key default gen_random_uuid(),
  reporter_id       uuid default auth.uid()
                      references public.profiles (id) on delete set null,
  target_type       text not null
                      check (target_type in ('message', 'user', 'event')),
  target_user_id    uuid references public.profiles (id) on delete set null,
  target_message_id uuid references public.messages (id) on delete set null,
  target_event_id   uuid references public.events (id) on delete set null,
  reason            text not null,
  note              text check (char_length(note) <= 500),
  content_snapshot  jsonb,
  status            text not null default 'open'
                      check (status in ('open', 'actioned', 'dismissed')),
  created_at        timestamptz not null default now(),
  resolved_at       timestamptz,
  -- Motivi a lista fissa, diversi per tipo di bersaglio.
  constraint reports_reason_check check (
       (target_type = 'message' and reason in
          ('harassment', 'threats', 'unwanted_sexual', 'spam', 'other'))
    or (target_type = 'user' and reason in
          ('underage', 'fake_profile', 'inappropriate_photos',
           'harassment', 'spam', 'other'))
    or (target_type = 'event' and reason in
          ('not_a_venue', 'misleading', 'inappropriate_content',
           'spam', 'other'))
  ),
  -- Solo le colonne del proprio tipo. NON si chiede che il bersaglio sia
  -- presente: quando l'autore cancella il messaggio o l'account la colonna
  -- diventa null e la segnalazione deve restare (con lo snapshot).
  -- La presenza alla creazione la controlla la policy di insert.
  constraint reports_target_columns_check check (
       (target_type = 'message' and target_event_id is null)
    or (target_type = 'event' and target_message_id is null)
    or (target_type = 'user' and target_message_id is null
                             and target_event_id is null)
  ),
  constraint reports_resolved_check check ((status = 'open') = (resolved_at is null))
);

-- Anti-flood: una sola segnalazione aperta per segnalante e bersaglio.
-- Un indice per tipo sulla sola colonna del bersaglio: quando il bersaglio
-- sparisce la colonna diventa null e due null non collidono (con un unico
-- indice su coalesce(...) due segnalazioni di messaggi diversi dello stesso
-- autore collidevano e facevano fallire delete_account_data).
create unique index if not exists reports_one_open_message
  on public.reports (reporter_id, target_message_id)
  where status = 'open' and target_type = 'message';
create unique index if not exists reports_one_open_event
  on public.reports (reporter_id, target_event_id)
  where status = 'open' and target_type = 'event';
create unique index if not exists reports_one_open_user
  on public.reports (reporter_id, target_user_id)
  where status = 'open' and target_type = 'user';
-- Tetto giornaliero e coda di moderazione.
create index if not exists reports_reporter_created
  on public.reports (reporter_id, created_at);
create index if not exists reports_open_created
  on public.reports (created_at) where status = 'open';

alter table public.reports enable row level security;

-- Permessi: i privilegi di default darebbero tutto ad authenticated.
revoke all on table public.reports from public, anon, authenticated;
grant insert (target_type, target_user_id, target_message_id, target_event_id,
              reason, note)
  on table public.reports to authenticated;
grant all on table public.reports to service_role;

-- Insert solo come se stessi, aperta, mai su di sé, e solo su un bersaglio
-- che chi segnala può vedere: le sottoquery girano con la RLS di chi
-- segnala (messaggi della chat di cui fa parte e non bloccati, serate
-- pubblicate non bloccate o proprie, profili non bloccati).
-- target_user_id e lo snapshot li scrive il trigger qui sotto, che in
-- Postgres scatta PRIMA di questo controllo.
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own" on public.reports
  for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and status = 'open'
    and target_user_id is distinct from auth.uid()
    and case target_type
      when 'message' then exists (
        select 1 from public.messages m where m.id = target_message_id)
      when 'event' then exists (
        select 1 from public.events e where e.id = target_event_id)
      when 'user' then exists (
        select 1 from public.profiles p where p.id = target_user_id)
      else false
    end
  );

-- 2) TRIGGER: campi decisi dal server, snapshot e tetto giornaliero ------------------
-- SECURITY DEFINER per leggere messaggio, serata, profilo e galleria anche
-- oltre la RLS di chi segnala. Se il bersaglio non esiste lascia i campi
-- vuoti: è la policy a respingere, con lo stesso errore di un bersaglio non
-- visibile (non dice se un id esiste).
create or replace function public.reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_gallery jsonb;
begin
  new.reporter_id      := v_uid;
  new.status           := 'open';
  new.created_at       := now();
  new.resolved_at      := null;
  new.content_snapshot := null;
  new.note             := nullif(btrim(new.note), '');

  if v_uid is not null and (
       select count(*) from public.reports r
       where r.reporter_id = v_uid
         and r.created_at > now() - interval '24 hours') >= 20 then
    raise exception 'Troppe segnalazioni nelle ultime 24 ore'
      using errcode = 'EC429';
  end if;

  if new.target_type = 'message' then
    new.target_user_id := null;
    select m.sender_id,
           jsonb_build_object('content', m.content,
                              'sender_id', m.sender_id,
                              'event_id', m.event_id,
                              'created_at', m.created_at)
      into new.target_user_id, new.content_snapshot
      from public.messages m
     where m.id = new.target_message_id;

  elsif new.target_type = 'event' then
    new.target_user_id := null;
    select e.host_id,
           jsonb_build_object('title', e.title,
                              'description', e.description,
                              'location_name', e.location_name,
                              'image_url', e.image_url,
                              'event_date', e.event_date,
                              'status', e.status,
                              'host_id', e.host_id)
      into new.target_user_id, new.content_snapshot
      from public.events e
     where e.id = new.target_event_id;

  elsif new.target_type = 'user' then
    -- Elenco dei file della galleria (0008: cartella radice = uid). Se lo
    -- Storage non è leggibile da qui, lo snapshot resta senza galleria.
    begin
      select coalesce(jsonb_agg(o.name order by o.name), '[]'::jsonb)
        into v_gallery
        from storage.objects o
       where o.bucket_id = 'profile_photos'
         and (storage.foldername(o.name))[1] = new.target_user_id::text;
    exception when insufficient_privilege or undefined_table then
      v_gallery := null;
    end;
    select jsonb_build_object('nickname', p.nickname,
                              'avatar_url', p.avatar_url,
                              'role', p.role,
                              'gallery', v_gallery)
      into new.content_snapshot
      from public.profiles p
     where p.id = new.target_user_id;
  end if;

  return new;
end;
$$;

revoke execute on function public.reports_before_insert()
  from public, anon, authenticated;

drop trigger if exists reports_before_insert on public.reports;
create trigger reports_before_insert
  before insert on public.reports
  for each row execute function public.reports_before_insert();

-- 3) CODA DI MODERAZIONE ----------------------------------------------------------
-- security_invoker: chi la legge ha bisogno dei permessi su reports, cioè
-- solo service_role e il SQL Editor. "Sembra minorenne" sempre in cima.
create or replace view public.reports_open
with (security_invoker = true) as
  select r.id,
         r.created_at,
         round(extract(epoch from now() - r.created_at) / 3600)::int as ore_trascorse,
         r.target_type,
         r.reason,
         r.target_user_id,
         r.target_message_id,
         r.target_event_id,
         r.reporter_id,
         r.note,
         r.content_snapshot
    from public.reports r
   where r.status = 'open'
   order by (r.reason = 'underage') desc, r.created_at;

revoke all on table public.reports_open
  from public, anon, authenticated, service_role;
grant select on table public.reports_open to service_role;

-- 4) CONSERVAZIONE: 12 MESI ---------------------------------------------------------
create or replace function public.purge_old_reports()
returns integer
language sql
security invoker
set search_path = public
as $$
  with d as (
    delete from public.reports
     where created_at < now() - interval '12 months'
    returning 1
  )
  select count(*)::int from d;
$$;

revoke execute on function public.purge_old_reports()
  from public, anon, authenticated;
grant execute on function public.purge_old_reports() to service_role;

-- 5) FILTRO DEI MESSAGGI ----------------------------------------------------------
-- Una parola o espressione per riga, in minuscolo; confronto a parole
-- intere, senza distinguere maiuscole e minuscole. Si gestisce dal SQL
-- Editor (supabase/MODERAZIONE.md).
create table if not exists public.blocked_terms (
  term       text primary key check (term = lower(btrim(term)) and term <> ''),
  created_at timestamptz not null default now()
);
alter table public.blocked_terms enable row level security;
-- Nessuna policy: solo service_role e il SQL Editor.
revoke all on table public.blocked_terms from public, anon, authenticated;
grant all on table public.blocked_terms to service_role;

create or replace function public.messages_filter_terms()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.blocked_terms t
     where lower(new.content) ~ ('\m' ||
             regexp_replace(t.term, '([.\\+*?\[^\]$(){}=!<>|:#-])', '\\\1', 'g')
             || '\M')
  ) then
    raise exception 'Il messaggio contiene termini non ammessi su Ecora.'
      using errcode = 'EC422';
  end if;
  return new;
end;
$$;

revoke execute on function public.messages_filter_terms()
  from public, anon, authenticated;

drop trigger if exists messages_filter_terms on public.messages;
create trigger messages_filter_terms
  before insert or update of content on public.messages
  for each row execute function public.messages_filter_terms();

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- ============================================================================
-- a) permessi su reports: authenticated solo INSERT per colonna, anon nulla
--    (attese: authenticated INSERT su note, reason, target_event_id,
--    target_message_id, target_type, target_user_id; service_role tutto):
--   select grantee, privilege_type, string_agg(column_name, ', ' order by column_name)
--   from information_schema.column_privileges
--   where table_schema = 'public' and table_name = 'reports'
--     and grantee in ('anon', 'authenticated')
--   group by 1, 2;
--   select grantee, privilege_type from information_schema.role_table_grants
--   where table_schema = 'public'
--     and table_name in ('reports', 'reports_open', 'blocked_terms')
--     and grantee in ('anon', 'authenticated');                 -- attese 0 righe
--
-- b) RLS e policy:
--   select relname, relrowsecurity from pg_class
--   where oid in ('public.reports'::regclass, 'public.blocked_terms'::regclass);
--   select policyname, cmd, roles from pg_policies
--   where schemaname = 'public' and tablename in ('reports', 'blocked_terms');
--                                     -- attesa solo reports_insert_own, INSERT
--
-- c) funzioni (attese false, false, true):
--   select has_function_privilege('anon', 'public.purge_old_reports()', 'execute'),
--          has_function_privilege('authenticated', 'public.purge_old_reports()', 'execute'),
--          has_function_privilege('service_role', 'public.purge_old_reports()', 'execute');
--
-- d) trigger:
--   select tgname, tgrelid::regclass from pg_trigger
--   where tgname in ('reports_before_insert', 'messages_filter_terms');
--
-- e) coda (vuota subito dopo l'applicazione):
--   select count(*) from public.reports_open;
--
-- Prove di comportamento: supabase/tests/0019_segnalazioni_test.sql
-- (Postgres locale, mai su Supabase).
-- ============================================================================
