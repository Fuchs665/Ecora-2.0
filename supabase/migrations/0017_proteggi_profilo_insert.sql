-- ============================================================================
-- Blocco S.2: ruolo e verifica protetti anche alla CREAZIONE del profilo.
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- TOCCA LA PROTEZIONE DI RUOLO E VERIFICA (auth/RLS).
--
-- Problema (trovato con lo schema base, 02/10/2026): il trigger
-- trigger_proteggi_profilo, creato dalla dashboard, scattava solo su
-- UPDATE. La policy INSERT "Ogni utente crea solo il proprio profilo"
-- (0002) controlla solo l'id, e il check su role ammette 'gestore': con una
-- chiamata diretta all'API REST un utente poteva creare il proprio profilo
-- già 'gestore' e con is_verified = true. L'app manda sempre 'cliente' e
-- false (lib/main.dart): i gestori li crea solo l'amministratore.
--
-- Fix: la stessa funzione copre anche INSERT. Chi non è service_role
-- ottiene sempre role = 'cliente' e is_verified = false alla creazione
-- (corretto senza errore, come già succede per l'UPDATE); su UPDATE il
-- comportamento resta quello di prima (si rimettono i valori vecchi).
-- In più search_path fisso sulla funzione (SECURITY DEFINER).
--
-- Il SQL Editor NON è service_role: anche da lì un profilo nasce cliente e
-- non verificato. Per promuovere un gestore: "set local role service_role"
-- nella stessa transazione, oppure disattivare il trigger come fa la 0003.
-- Le righe esistenti non vengono toccate.
-- ============================================================================

begin;

create or replace function public.proteggi_ruolo_profilo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Ruolo e verifica si decidono solo lato server (service_role).
  if current_setting('role', true) is distinct from 'service_role' then
    if tg_op = 'INSERT' then
      new.role := 'cliente';
      new.is_verified := false;
    elsif old.role is distinct from new.role
          or old.is_verified is distinct from new.is_verified then
      new.role := old.role;
      new.is_verified := old.is_verified;
    end if;
  end if;
  return new;
end;
$$;

-- Stesso nome di prima (la 0003 lo disattiva e riattiva per nome).
drop trigger if exists trigger_proteggi_profilo on public.profiles;
create trigger trigger_proteggi_profilo
  before insert or update on public.profiles
  for each row execute function public.proteggi_ruolo_profilo();

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor). Tutte in sola lettura.
-- ============================================================================
-- a) trigger su INSERT e UPDATE (attesa 1 riga, con "BEFORE INSERT OR UPDATE"):
--   select pg_get_triggerdef(oid) from pg_trigger
--   where tgrelid = 'public.profiles'::regclass
--     and tgname = 'trigger_proteggi_profilo';
--
-- b) search_path fisso (atteso {search_path=public}):
--   select proconfig from pg_proc
--   where oid = 'public.proteggi_ruolo_profilo()'::regprocedure;
--
-- Prove di comportamento: supabase/tests/0017_proteggi_profilo_insert_test.sql
-- (Postgres locale, mai su Supabase).
