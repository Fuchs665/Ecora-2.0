-- ============================================================================
-- 0000 · Schema base (creato dalla dashboard Supabase, mai versionato prima).
--
-- NON APPLICARE IN PRODUZIONE: la produzione ha già queste tabelle.
-- Serve allo staging locale (supabase/tests/run_chain.sh) e alla
-- documentazione.
--
-- Ricostruito il 02/10/2026 dal catalogo della produzione (sola lettura) e
-- dai commenti delle migrazioni 0001-0016. Regola: qui c'è solo quello che
-- la dashboard ha creato e che nessuna migrazione crea. Dove una migrazione
-- successiva lo modifica, qui c'è la forma di PRIMA, così la catena
-- 0000 -> ultima arriva allo stato della produzione:
--   - profiles.role: vocabolario vecchio (user_single/user_couple/
--     business_locale), lo cambia la 0003; senza age_confirmed_at e
--     terms_accepted_at (0005) e birth_year (0015);
--   - events: host_id obbligatorio e stato senza 'archived' (0016), senza
--     image_url e location_name (0001).
-- Dedotto, non osservato: il vecchio check e il vecchio default di
-- profiles.role. In produzione profiles ha anche una colonna cancellata
-- (posizione 8) di cui non resta traccia. profiles.role è NOT NULL in
-- produzione ma nessuna migrazione lo imposta: è messo qui.
--
-- Policy create dalla dashboard e cancellate dalle migrazioni: non sono
-- qui, perché rieseguire questo file le farebbe tornare (alcune erano
-- falle). Sono, per nome:
--   profiles: "Consenti lettura profili a utenti autenticati" (0010),
--     "Modifica solo il tuo profilo", "Profili visibili a tutti gli utenti
--     loggati" (0003);
--   events: "Consenti inserimento/modifica solo ai gestori", "Consenti
--     lettura eventi a tutti", "Consentiti eventi in lettura a tutti",
--     "L'organizzatore gestisce i propri eventi", "Tutti vedono gli eventi
--     pubblicati" (0003);
--   event_requests: "Gli utenti possono richiedere di partecipare",
--     "L'organizzatore può approvare le richieste", "Lettura richieste
--     protetta", "Solo il gestore approva o rifiuta" (0003), "Clienti
--     possono solo candidarsi", "Regola blindata per la visibilità dei
--     partecipanti" (ricreate dalla 0006);
--   messages: "Gli utenti possono leggere i messaggi degli eventi a cui
--     partec", "Gli utenti autenticati possono inserire messaggi" (0001).
--
-- Webhook configurati dalla dashboard, non versionati: due trigger di nome
-- "event_requests" che chiamano supabase_functions.http_request verso la
-- Edge Function push (INSERT su event_requests, UPDATE su events). Gli
-- argomenti contengono un segreto: non vanno mai copiati qui.
--
-- Idempotente e mai distruttivo: ogni oggetto si crea solo se manca, così
-- rieseguirlo sopra la catena non riporta indietro ciò che le migrazioni
-- successive hanno cambiato (es. proteggi_ruolo_profilo, 0017).
-- ============================================================================

-- 1) TABELLE --------------------------------------------------------------------
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  role             text not null default 'user_single'
                   check (role in ('user_single', 'user_couple', 'business_locale')),
  nickname         text,
  avatar_url       text,
  generic_location text,
  is_verified      boolean default false,
  created_at       timestamptz not null default timezone('utc', now()),
  profile_type     text,
  privacy_level    text
);
alter table public.profiles enable row level security;

create table if not exists public.events (
  id          uuid primary key default gen_random_uuid(),
  host_id     uuid not null references public.profiles (id) on delete cascade,
  title       text not null,
  description text,
  event_date  timestamptz not null,
  max_guests  integer default 50,
  status      text default 'draft'
              check (status = any (array['draft', 'published', 'cancelled'])),
  created_at  timestamptz not null default timezone('utc', now()),
  latitude    double precision,
  longitude   double precision
);
alter table public.events enable row level security;

create table if not exists public.event_requests (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  status     text default 'pending'
             check (status = any (array['pending', 'approved', 'rejected'])),
  created_at timestamptz not null default timezone('utc', now()),
  unique (event_id, user_id)
);
alter table public.event_requests enable row level security;

create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events (id) on delete cascade,
  sender_id  uuid not null references auth.users (id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default timezone('utc', now())
);
alter table public.messages enable row level security;

-- 2) FUNZIONI (testo identico alla produzione) -----------------------------------
-- Usata dalle policy di messages ed event_requests (0001, 0006).
do $do$
begin
  if to_regprocedure('public.is_approved_for_event(uuid)') is null then
    execute $fn$
create function public.is_approved_for_event(target_event_id uuid)
returns boolean
language sql
security definer
as $$
  select exists(
    select 1 from public.event_requests
    where event_id = target_event_id
    and user_id = auth.uid()
    and status = 'approved'
  );
$$
$fn$;
  end if;
end
$do$;

-- Ruolo e verifica si cambiano solo da service_role. Qui la versione
-- creata dalla dashboard, solo per UPDATE; la 0017 la estende a INSERT.
do $do$
begin
  if to_regprocedure('public.proteggi_ruolo_profilo()') is null then
    execute $fn$
create function public.proteggi_ruolo_profilo()
returns trigger
language plpgsql
security definer
as $$
BEGIN
    -- Se l'utente tenta di cambiare il ruolo o lo stato di verifica, rimetti i valori precedenti
    IF (OLD.role IS DISTINCT FROM NEW.role OR OLD.is_verified IS DISTINCT FROM NEW.is_verified) THEN
        -- Consenti la modifica solo se l'utente che esegue l'operazione è un amministratore di sistema (service_role)
        IF current_setting('role', true) != 'service_role' THEN
            NEW.role := OLD.role;
            NEW.is_verified := OLD.is_verified;
        END IF;
    END IF;
    RETURN NEW;
END;
$$
$fn$;
  end if;
end
$do$;

-- La 0003 lo disattiva e riattiva per nome; la 0017 lo estende a INSERT.
do $do$
begin
  if not exists (select 1 from pg_trigger
                 where tgrelid = 'public.profiles'::regclass
                   and tgname = 'trigger_proteggi_profilo') then
    create trigger trigger_proteggi_profilo
      before update on public.profiles
      for each row execute function public.proteggi_ruolo_profilo();
  end if;
end
$do$;

-- Non usata dall'app.
do $do$
begin
  if to_regprocedure('public.get_events_within_radius(double precision, double precision, double precision)') is null then
    execute $fn$
create function public.get_events_within_radius(
  user_lat double precision,
  user_lon double precision,
  max_distance_km double precision
)
returns setof public.events
language sql
as $$
  select *
  from events
  where (
    6371 * acos(
      cos(radians(user_lat)) * cos(radians(latitude)) *
      cos(radians(longitude) - radians(user_lon)) +
      sin(radians(user_lat)) * sin(radians(latitude))
    )
  ) <= max_distance_km;
$$
$fn$;
  end if;
end
$do$;

-- RLS attivata da sola su ogni tabella nuova di public (opzione del
-- progetto Supabase). Le migrazioni la attivano comunque in modo esplicito.
do $do$
begin
  if to_regprocedure('public.rls_auto_enable()') is null then
    execute $fn$
create function public.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$
$fn$;
  end if;
end
$do$;

do $$
begin
  if not exists (select 1 from pg_event_trigger where evtname = 'ensure_rls') then
    create event trigger ensure_rls on ddl_command_end
      when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      execute function public.rls_auto_enable();
  end if;
end $$;

-- 3) POLICY sopravvissute (nessuna migrazione le crea o le cancella) -------------
do $do$
begin
  if not exists (select 1 from pg_policies
                 where schemaname = 'public' and tablename = 'profiles'
                   and policyname = 'Consenti aggiornamento solo al proprietario') then
    create policy "Consenti aggiornamento solo al proprietario" on public.profiles
      for update to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end
$do$;
