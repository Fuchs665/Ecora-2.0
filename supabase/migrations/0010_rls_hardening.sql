-- ============================================================================
-- Block 6.1: hardening RLS post-audit (findings 2026-07-04)
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale.
--
-- Chiude tre problemi trovati dall'audit sullo stato cumulativo 0001-0009:
--   ALTA  profiles SELECT era qual=true: ogni autenticato leggeva l'intera
--         tabella profili (posizione, privacy_level, timestamp consenso),
--         ignorando i blocchi. Ora filtra per blocco.
--   MEDIA event_requests UPDATE non blindava user_id/event_id: un gestore
--         poteva riscrivere una richiesta cambiando destinatario/evento e
--         forzarne l'approvazione. Ora un trigger li rende immutabili.
--   BASSA le funzioni SECURITY DEFINER restavano eseguibili da PUBLIC (grant
--         implicito Postgres). Innocuo oggi (collassano a false/null con
--         auth.uid() nullo) ma superficie inutile: revoke + grant espliciti.
-- ============================================================================

begin;

-- 1) ALTA — PROFILES SELECT filtrato per blocco.
--    is_blocked_with() e' SECURITY DEFINER e legge `blocks` (non `profiles`):
--    nessuna ricorsione con questa policy. L'owner vede sempre se stesso.
drop policy if exists "Consenti lettura profili a utenti autenticati" on public.profiles;
drop policy if exists "profiles_select_scoped" on public.profiles;
create policy "profiles_select_scoped" on public.profiles
  for select to authenticated
  using (
    auth.uid() = id
    or not public.is_blocked_with(id)
  );

-- 2) MEDIA — event_requests: user_id/event_id immutabili su UPDATE.
--    La policy UPDATE (0003) autorizza il gestore host; questo trigger
--    impedisce che lo stesso UPDATE sposti la riga su un altro utente/evento.
create or replace function public.event_requests_lock_keys()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.user_id is distinct from old.user_id
     or new.event_id is distinct from old.event_id then
    raise exception
      'user_id e event_id non sono modificabili su event_requests';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_event_requests_lock_keys on public.event_requests;
create trigger trg_event_requests_lock_keys
  before update on public.event_requests
  for each row execute function public.event_requests_lock_keys();

-- 3) BASSA — least privilege sulle funzioni SECURITY DEFINER.
--    revoke dal grant implicito PUBLIC, poi grant espliciti (invariati
--    rispetto all'intento originale: anon solo dove gia' previsto).
revoke execute on function public.is_gestore() from public;
grant execute on function public.is_gestore() to authenticated;

revoke execute on function public.can_view_gallery(uuid) from public;
grant execute on function public.can_view_gallery(uuid) to authenticated;

revoke execute on function public.get_events_with_stats() from public;
grant execute on function public.get_events_with_stats() to authenticated, anon;

revoke execute on function public.is_blocked_with(uuid) from public;
grant execute on function public.is_blocked_with(uuid) to authenticated, anon;

commit;
