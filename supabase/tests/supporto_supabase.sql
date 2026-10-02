-- ============================================================================
-- Supporto per lo staging LOCALE (Postgres del container, mai Supabase).
-- Imita i pezzi che Supabase crea da sé e che un Postgres vuoto non ha, così
-- 0000_schema_base.sql e le migrazioni 0001-... girano come in produzione:
--   - ruoli anon / authenticated / service_role (service_role salta la RLS);
--   - schema auth con auth.users e auth.uid() (stessa lettura del JWT di
--     Supabase: request.jwt.claim.sub oppure request.jwt.claims ->> 'sub');
--   - schema storage con storage.buckets, storage.objects (RLS attiva) e
--     storage.foldername();
--   - publication supabase_realtime, vuota (la 0007 ci aggiunge messages);
--   - privilegi di default della produzione: tutto ai tre ruoli sulle
--     tabelle, funzioni e sequenze nuove create da postgres in public e
--     storage (letti da pg_default_acl il 02/10/2026).
--
-- Uso: lo applica supabase/tests/run_chain.sh su un database nuovo, prima
-- della 0000. I ruoli sono globali al cluster: li crea solo se mancano e
-- run_chain.sh li elimina alla fine.
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

create schema if not exists auth;
create schema if not exists storage;
grant usage on schema public, auth, storage to anon, authenticated, service_role;

-- Privilegi di default come in produzione (prima di creare qualsiasi tabella).
alter default privileges for role postgres in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on functions to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges for role postgres in schema storage
  grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema storage
  grant all on functions to anon, authenticated, service_role;
alter default privileges for role postgres in schema storage
  grant all on sequences to anon, authenticated, service_role;

-- --- auth ---------------------------------------------------------------------
create table if not exists auth.users (
  id                 uuid primary key,
  email              text,
  raw_user_meta_data jsonb,
  created_at         timestamptz not null default now()
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- --- storage ------------------------------------------------------------------
create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null,
  owner              uuid,
  public             boolean default false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);
alter table storage.buckets enable row level security;

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text references storage.buckets (id),
  name       text,
  owner      uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  metadata   jsonb,
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;

create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;

-- --- realtime -------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;
