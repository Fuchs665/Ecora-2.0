-- ============================================================================
-- Blocco L.1: lista d'attesa.
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA RLS: la policy INSERT "Clienti possono solo candidarsi" ricreata con
-- lo stesso nome; trigger nuovo su event_requests; funzione SECURITY
-- DEFINER nuova.
--
-- Problema: con la serata piena (0022) le richieste nuove restavano "in
-- attesa" senza che il cliente sapesse che non c'era posto, e al gestore
-- restava solo rifiutarle.
--
-- Fix:
--   - stato nuovo 'waitlisted';
--   - trigger event_requests_assign_status (BEFORE INSERT): per chi non è
--     service_role lo stato lo decide il server: 'waitlisted' se la serata
--     è piena nel totale o nella categoria del candidato (stessi conteggi
--     della 0022), altrimenti 'pending'. Il client non sceglie lo stato;
--   - policy "Clienti possono solo candidarsi": status in ('pending',
--     'waitlisted') al posto di status = 'pending' (la RLS controlla la riga
--     dopo il trigger); il resto invariato (0021);
--   - my_waitlist_position(event_id): posizione dell'utente collegato tra
--     chi è in lista per la stessa serata e la stessa categoria, in ordine
--     di arrivo; null se non è in lista.
-- Nessuna promozione automatica: chi è in lista lo approva il gestore,
-- quando c'è posto (il trigger della 0022 controlla anche questo caso).
-- Le richieste già 'pending' restano come sono (deciso il 08/10/2026).
-- ============================================================================

begin;

-- 1) Stato nuovo --------------------------------------------------------------------
alter table public.event_requests drop constraint if exists event_requests_status_check;
alter table public.event_requests add constraint event_requests_status_check
  check (status = any (array['pending', 'approved', 'rejected', 'waitlisted']));

-- 2) Stato deciso dal server alla candidatura ------------------------------------------
create or replace function public.event_requests_assign_status()
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
  if current_setting('role', true) = 'service_role' then
    return new;
  end if;

  select guest_category(p.profile_type) into v_category
    from public.profiles p where p.id = new.user_id;

  select e.max_guests,
         case v_category
           when 'coppia' then e.max_couples
           when 'donna' then e.max_women
           when 'uomo' then e.max_men
         end
    into v_max_guests, v_max_cat
    from public.events e
   where e.id = new.event_id;

  select count(*),
         count(*) filter (where v_category is not null
                            and guest_category(p.profile_type) = v_category)
    into v_total, v_in_cat
    from public.event_requests r
    left join public.profiles p on p.id = r.user_id
   where r.event_id = new.event_id
     and r.status = 'approved';

  if (v_max_guests is not null and v_total >= v_max_guests)
     or (v_max_cat is not null and v_in_cat >= v_max_cat) then
    new.status := 'waitlisted';
  else
    new.status := 'pending';
  end if;
  return new;
end;
$$;

revoke execute on function public.event_requests_assign_status() from public, anon;

drop trigger if exists trg_event_requests_assign_status on public.event_requests;
create trigger trg_event_requests_assign_status
  before insert on public.event_requests
  for each row execute function public.event_requests_assign_status();

-- 3) Candidatura: anche in lista d'attesa ------------------------------------------------
drop policy if exists "Clienti possono solo candidarsi" on public.event_requests;
create policy "Clienti possono solo candidarsi" on public.event_requests
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and status in ('pending', 'waitlisted')
    and not public.is_blocked_with(
      (select e.host_id from public.events e where e.id = event_requests.event_id))
    and exists (select 1 from public.events e
                where e.id = event_requests.event_id
                  and e.status = 'published'
                  and public.host_is_verified(e.host_id))
  );

-- 4) Posizione in lista ------------------------------------------------------------------
create or replace function public.my_waitlist_position(p_event_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_created  timestamptz;
  v_id       uuid;
  v_category text;
  v_position integer;
begin
  if uid is null then
    raise exception 'sessione assente' using errcode = '42501';
  end if;
  select r.created_at, r.id, guest_category(p.profile_type)
    into v_created, v_id, v_category
    from public.event_requests r
    left join public.profiles p on p.id = r.user_id
   where r.event_id = p_event_id and r.user_id = uid and r.status = 'waitlisted';
  if not found then
    return null;
  end if;
  select count(*) + 1 into v_position
    from public.event_requests r
    left join public.profiles p on p.id = r.user_id
   where r.event_id = p_event_id
     and r.status = 'waitlisted'
     and guest_category(p.profile_type) is not distinct from v_category
     and (r.created_at, r.id) < (v_created, v_id);
  return v_position;
end;
$$;

revoke execute on function public.my_waitlist_position(uuid) from public, anon;
grant execute on function public.my_waitlist_position(uuid) to authenticated;

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- a) vincolo con il nuovo stato (atteso ... 'waitlisted' ...):
--   select pg_get_constraintdef(oid) from pg_constraint
--   where conname = 'event_requests_status_check';
--
-- b) trigger (atteso "BEFORE INSERT ON public.event_requests"):
--   select pg_get_triggerdef(oid) from pg_trigger
--   where tgname = 'trg_event_requests_assign_status';
--
-- c) policy (atteso status = ANY ('pending','waitlisted') e host_is_verified):
--   select with_check from pg_policies
--   where policyname = 'Clienti possono solo candidarsi';
--
-- d) funzioni: search_path e permessi, mai anon (attese 2 righe):
--   select proname, prosecdef, proconfig, proacl from pg_proc
--   where pronamespace = 'public'::regnamespace
--     and proname in ('event_requests_assign_status', 'my_waitlist_position');
--
-- Prove di comportamento: supabase/tests/0023_lista_attesa_test.sql
-- (Postgres locale, mai su Supabase).
-- ============================================================================
