-- ============================================================================
-- Blocco C.5c: posti per tipologia (coppie, donne, uomini) e limite dei
-- posti controllato dal server.
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA TRIGGER E FUNZIONI SECURITY DEFINER: trigger nuovo su
-- event_requests, get_events_with_stats() ricreata. Nessuna policy cambiata.
--
-- Problema: max_guests era solo uno slider dell'app: il server non lo
-- controllava, e un gestore (o una chiamata diretta all'API) poteva
-- approvare più ospiti del limite. Il gestore non poteva dividere i posti
-- tra coppie, donne e uomini.
--
-- Unità: un posto è una candidatura approvata (una coppia = 1 posto), come
-- già per max_guests e approved_count. Deciso il 07/10/2026.
--
-- Fix:
--   - events.max_couples, max_women, max_men: facoltativi (null = nessun
--     limite), tra 0 e max_guests;
--   - guest_category(profile_type): 'coppia' | 'donna' | 'uomo' | null,
--     dagli stessi valori della registrazione (lib/main.dart);
--   - trigger event_requests_check_capacity (BEFORE UPDATE): quando una
--     candidatura diventa 'approved' blocca la riga della serata (due
--     approvazioni insieme non superano il limite) e rifiuta se è piena la
--     serata (EC001) o la categoria del candidato (EC002 coppie, EC003
--     donne, EC004 uomini). Un profilo senza tipologia conta solo sul
--     totale. service_role passa sempre (correzioni manuali);
--   - get_events_with_stats(): in più i tre limiti e gli approvati per
--     categoria. Cambiano le colonne restituite, quindi drop + create con
--     gli stessi permessi (solo authenticated) e lo stesso filtro della
--     0021.
-- Serate esistenti: nessun limite per categoria; se una ha già più
-- approvati di max_guests nessuno viene tolto, solo non se ne approvano
-- altri (vedi PRE-VERIFICA in fondo).
-- ============================================================================

begin;

-- 1) Limiti per tipologia ---------------------------------------------------------
alter table public.events add column if not exists max_couples integer;
alter table public.events add column if not exists max_women integer;
alter table public.events add column if not exists max_men integer;

alter table public.events drop constraint if exists events_category_limits_check;
alter table public.events add constraint events_category_limits_check check (
  (max_couples is null or (max_couples >= 0 and (max_guests is null or max_couples <= max_guests)))
  and (max_women is null or (max_women >= 0 and (max_guests is null or max_women <= max_guests)))
  and (max_men is null or (max_men >= 0 and (max_guests is null or max_men <= max_guests)))
);

-- 2) Categoria dell'ospite ----------------------------------------------------------
create or replace function public.guest_category(p_profile_type text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_profile_type in ('Coppia U/D', 'Coppia D/D', 'Coppia U/U') then 'coppia'
    when p_profile_type = 'Donna Singola' then 'donna'
    when p_profile_type = 'Uomo Singolo' then 'uomo'
    else null
  end;
$$;

revoke execute on function public.guest_category(text) from public, anon;
grant execute on function public.guest_category(text) to authenticated;

-- 3) Controllo dei posti all'approvazione ---------------------------------------------
create or replace function public.event_requests_check_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max_guests integer;
  v_max_cat    integer;
  v_category   text;
  v_total      integer;
  v_in_cat     integer;
begin
  if new.status is distinct from 'approved'
     or old.status is not distinct from 'approved' then
    return new;
  end if;
  if current_setting('role', true) = 'service_role' then
    return new;
  end if;

  select guest_category(p.profile_type) into v_category
    from public.profiles p where p.id = new.user_id;

  -- Blocca la serata: le approvazioni sulla stessa serata passano una
  -- alla volta.
  select e.max_guests,
         case v_category
           when 'coppia' then e.max_couples
           when 'donna' then e.max_women
           when 'uomo' then e.max_men
         end
    into v_max_guests, v_max_cat
    from public.events e
   where e.id = new.event_id
   for update;

  select count(*),
         count(*) filter (where v_category is not null
                            and guest_category(p.profile_type) = v_category)
    into v_total, v_in_cat
    from public.event_requests r
    left join public.profiles p on p.id = r.user_id
   where r.event_id = new.event_id
     and r.status = 'approved'
     and r.id <> new.id;

  if v_max_guests is not null and v_total >= v_max_guests then
    raise exception 'Serata al completo' using errcode = 'EC001';
  end if;
  if v_max_cat is not null and v_in_cat >= v_max_cat then
    raise exception 'Posti esauriti per la categoria %', v_category
      using errcode = case v_category
                        when 'coppia' then 'EC002'
                        when 'donna' then 'EC003'
                        else 'EC004'
                      end;
  end if;
  return new;
end;
$$;

revoke execute on function public.event_requests_check_capacity() from public, anon;

drop trigger if exists trg_event_requests_check_capacity on public.event_requests;
create trigger trg_event_requests_check_capacity
  before update on public.event_requests
  for each row execute function public.event_requests_check_capacity();

-- 4) Feed con i posti per tipologia -----------------------------------------------------
--    Stesso filtro della 0021; colonne in più in fondo.
drop function if exists public.get_events_with_stats();
create function public.get_events_with_stats()
returns table (
  id uuid, host_id uuid, title text, description text,
  event_date timestamptz, max_guests int, status text,
  latitude double precision, longitude double precision,
  image_url text, location_name text, approved_count bigint,
  max_couples int, max_women int, max_men int,
  approved_couples bigint, approved_women bigint, approved_men bigint
)
language sql security definer set search_path = public as $$
  select e.id, e.host_id, e.title, e.description, e.event_date,
         e.max_guests, e.status, e.latitude, e.longitude,
         e.image_url, e.location_name,
         (select count(*) from event_requests r
           where r.event_id = e.id and r.status = 'approved') as approved_count,
         e.max_couples, e.max_women, e.max_men,
         c.couples, c.women, c.men
  from events e
  cross join lateral (
    select count(*) filter (where guest_category(p.profile_type) = 'coppia') as couples,
           count(*) filter (where guest_category(p.profile_type) = 'donna') as women,
           count(*) filter (where guest_category(p.profile_type) = 'uomo') as men
      from event_requests r
      join profiles p on p.id = r.user_id
     where r.event_id = e.id and r.status = 'approved'
  ) c
  where e.status = 'published'
    and not public.is_blocked_with(e.host_id)
    and public.host_is_verified(e.host_id);
$$;

revoke execute on function public.get_events_with_stats() from public, anon;
grant execute on function public.get_events_with_stats() to authenticated;

commit;

-- ============================================================================
-- PRE-VERIFICA (prima di applicare, SQL Editor). Solo conteggi: serate con
-- più approvati del limite (non bloccano la migrazione, ma non potranno
-- approvarne altri). Attesa 0 o un numero noto.
--   select count(*) as serate_oltre_il_limite
--   from public.events e
--   where e.max_guests is not null
--     and (select count(*) from public.event_requests r
--           where r.event_id = e.id and r.status = 'approved') > e.max_guests;
--
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- a) colonne e vincolo (attese 3 colonne integer e 1 vincolo):
--   select column_name, data_type from information_schema.columns
--   where table_schema = 'public' and table_name = 'events'
--     and column_name in ('max_couples', 'max_women', 'max_men');
--   select conname from pg_constraint
--   where conname = 'events_category_limits_check';
--
-- b) trigger (atteso "BEFORE UPDATE ON public.event_requests"):
--   select pg_get_triggerdef(oid) from pg_trigger
--   where tgname = 'trg_event_requests_check_capacity';
--
-- c) funzioni: permessi e search_path (attese 3 righe, mai anon;
--    get_events_with_stats solo authenticated):
--   select proname, prosecdef, proconfig, proacl from pg_proc
--   where pronamespace = 'public'::regnamespace
--     and proname in ('guest_category', 'event_requests_check_capacity',
--                     'get_events_with_stats');
--
-- d) il feed filtra ancora i locali verificati (attesa true):
--   select pg_get_functiondef('public.get_events_with_stats()'::regprocedure)
--          like '%host_is_verified%';
--
-- Prove di comportamento: supabase/tests/0022_posti_per_tipologia_test.sql
-- (Postgres locale, mai su Supabase).
