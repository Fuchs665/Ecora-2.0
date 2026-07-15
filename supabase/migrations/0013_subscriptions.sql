-- ============================================================================
-- Block 5.1: tabella subscriptions + gate abbonamento su creazione eventi
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale.
--
-- Monetizzazione v1 (decisioni 2026-07-15): i gestori pagano un abbonamento
-- mensile (product id: ecora_gestore_monthly) per PUBBLICARE NUOVI eventi.
-- Alla scadenza/cancellazione si blocca solo l'INSERT di nuovi eventi: gli
-- eventi gia' pubblicati restano attivi e gestibili (SELECT/UPDATE/DELETE
-- invariate).
--
-- Scritture: SOLO la Edge Function verify-subscription (Block 5.2) con
-- service_role, dopo aver verificato il purchase token con la Google Play
-- Developer API. Il client puo' unicamente leggere la PROPRIA riga.
--
-- ATTENZIONE: appena applicata, NESSUN gestore puo' creare eventi finche'
-- 5.2/5.3 non scrivono righe qui. Per i test manuali vedi la sezione
-- "VERIFICA" in fondo (riga finta con expiry futura).
-- ============================================================================

begin;

-- 1) Tabella: una riga per gestore = stato piu' recente dell'abbonamento.
--    purchase_token UNIQUE = anti-replay: lo stesso token Google non puo'
--    attivare due account. expiry_time e' la fonte di verita' del gate.
create table if not exists public.subscriptions (
  user_id          uuid primary key references public.profiles(id) on delete cascade,
  product_id       text not null default 'ecora_gestore_monthly',
  purchase_token   text not null unique,
  expiry_time      timestamptz not null,
  auto_renewing    boolean not null default false,
  last_verified_at timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

-- updated_at automatico (le scritture arrivano solo dalla Edge Function,
-- il trigger evita di doversi ricordare di settarlo li').
create or replace function public.subscriptions_touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_subscriptions_touch_updated_at on public.subscriptions;
create trigger trg_subscriptions_touch_updated_at
  before update on public.subscriptions
  for each row execute function public.subscriptions_touch_updated_at();

-- 2) RLS: il gestore legge solo la propria riga. NESSUNA policy di
--    scrittura client-side: insert/update/delete passano solo da
--    service_role (bypassa RLS by design).
drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own" on public.subscriptions
  for select to authenticated
  using (auth.uid() = user_id);

-- Grants espliciti (igiene 0011/0012): via i default del progetto,
-- authenticated solo SELECT (le righe le filtra la policy), anon niente.
revoke all on table public.subscriptions from anon, authenticated;
grant select on table public.subscriptions to authenticated;

-- 3) Helper per il gate. SENZA parametro (usa auth.uid() internamente,
--    stile is_gestore): con un parametro uuid chiunque potrebbe sondare
--    via RPC lo stato abbonamento di altri utenti.
--    SECURITY DEFINER: il gate resta funzionante anche se in futuro i
--    grant/policy di lettura su subscriptions cambiano.
create or replace function public.has_active_subscription()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from public.subscriptions
    where user_id = auth.uid() and expiry_time > now()
  );
$$;

revoke execute on function public.has_active_subscription() from public, anon;
grant execute on function public.has_active_subscription() to authenticated;

-- 4) Gate su events: si tocca SOLO la policy INSERT (stesso nome della 0003,
--    ricreata con la condizione in piu'). SELECT/UPDATE/DELETE invariate.
drop policy if exists "events_insert_gestore" on public.events;
create policy "events_insert_gestore" on public.events
  for insert to authenticated
  with check (
    auth.uid() = host_id
    and public.is_gestore()
    and public.has_active_subscription()
  );

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor, DA ESEGUIRE SENZA i '--' iniziali).
-- L'editor Supabase NON mostra i `raise notice`: l'esito arriva come
-- "errore" finale (raise exception), che rende anche tutto auto-annullante
-- (riga finta + eventi di test spariscono col rollback dell'eccezione).
-- Esito atteso: TEST1 OK (42501) | TEST2 OK (insert riuscito) | TEST3 OK (42501).
-- ============================================================================
-- do $$
-- declare
--   g uuid;
--   r1 text; r2 text; r3 text;
-- begin
--   select id into g from public.profiles where role = 'gestore' limit 1;
--   if g is null then raise exception 'ESITO: nessun gestore in profiles'; end if;
--
--   perform set_config('request.jwt.claims',
--                      json_build_object('sub', g, 'role', 'authenticated')::text, true);
--   perform set_config('request.jwt.claim.sub', g::text, true);
--
--   -- TEST 1: gestore SENZA subscription -> insert bloccato
--   set local role authenticated;
--   begin
--     insert into public.events (host_id, title, description, event_date)
--     values (g, 'TEST 5.1', 'test rls', now() + interval '7 days');
--     r1 := 'FALLITO: insert riuscito senza subscription';
--   exception
--     when insufficient_privilege then r1 := 'OK (42501)';
--     when others then r1 := 'ANOMALO: ' || sqlerrm;
--   end;
--   reset role;
--
--   -- riga finta con expiry futura
--   insert into public.subscriptions (user_id, purchase_token, expiry_time)
--   values (g, 'fake-token-test-5-1', now() + interval '30 days');
--
--   -- TEST 2: con subscription attiva -> insert riesce
--   set local role authenticated;
--   begin
--     insert into public.events (host_id, title, description, event_date)
--     values (g, 'TEST 5.1', 'test rls', now() + interval '7 days');
--     r2 := 'OK (insert riuscito)';
--   exception
--     when insufficient_privilege then r2 := 'FALLITO: 42501 con subscription attiva';
--     when others then r2 := 'ANOMALO: ' || sqlerrm;
--   end;
--   reset role;
--
--   -- TEST 3: expiry passata -> bloccato di nuovo
--   update public.subscriptions set expiry_time = now() - interval '1 day'
--   where user_id = g;
--   set local role authenticated;
--   begin
--     insert into public.events (host_id, title, description, event_date)
--     values (g, 'TEST 5.1', 'test rls', now() + interval '7 days');
--     r3 := 'FALLITO: insert riuscito con subscription scaduta';
--   exception
--     when insufficient_privilege then r3 := 'OK (42501)';
--     when others then r3 := 'ANOMALO: ' || sqlerrm;
--   end;
--   reset role;
--
--   raise exception
--     'ESITO TEST 5.1 (tutto annullato) -> TEST1 senza sub: % | TEST2 sub attiva: % | TEST3 sub scaduta: %',
--     r1, r2, r3;
-- end $$;
--
-- Dump policy (fuori transazione, sola lettura):
--   select tablename, policyname, cmd, roles, qual, with_check
--   from pg_policies where tablename in ('subscriptions','events')
--   order by tablename, policyname;
-- Attese: subscriptions 1 sola policy (select_own); events_insert_gestore
-- con has_active_subscription() nel with_check; le altre 4 di events invariate.
--
-- Per attivarti una subscription finta nei test manuali dell'app:
--   insert into public.subscriptions (user_id, purchase_token, expiry_time)
--   values ('<UUID_GESTORE>', 'manual-test-token', now() + interval '30 days')
--   on conflict (user_id) do update
--     set expiry_time = excluded.expiry_time, purchase_token = excluded.purchase_token;
-- ============================================================================
