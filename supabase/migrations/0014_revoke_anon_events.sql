-- ============================================================================
-- Block 7.1: revoca accesso anonimo agli eventi
-- Run in: Supabase Dashboard -> SQL Editor. Transazionale. Idempotente.
--
-- get_events_with_stats()/events_select_published erano anon-facing di
-- proposito dalla 0006 ("eventi pubblicati visibili anche da anonimi") e
-- mantenute tali dalla 0010/0011. Verifica su lib/: fetchEvents() (che
-- chiama la RPC) e' invocata solo da ClientNavigationHub/GestoreDashboard,
-- entrambe raggiungibili solo dopo l'auth gate in main.dart
-- (profile == null -> AuthScreen). Nessun percorso anonimo la usa.
-- L'unico effetto pratico del grant anon era abilitare lo scraping
-- dell'intero calendario senza account.
-- ============================================================================

begin;

-- 1) RPC eventi: non piu' chiamata da anon.
revoke execute on function public.get_events_with_stats() from anon;

-- 2) Policy events SELECT: solo authenticated, condizione invariata.
drop policy if exists "events_select_published" on public.events;
create policy "events_select_published" on public.events
  for select to authenticated
  using (status = 'published' and not public.is_blocked_with(host_id));

-- 3) is_blocked_with: dopo il punto 2 nessuna policy/funzione anon-facing la
--    chiama piu' (event_requests INSERT/SELECT e messages SELECT erano gia'
--    authenticated-only dalla 0006). Revoca per coerenza/least privilege.
revoke execute on function public.is_blocked_with(uuid) from anon;

commit;

-- ============================================================================
-- VERIFICA post-apply (SQL Editor, DA ESEGUIRE SENZA i '--' iniziali).
-- L'editor Supabase NON mostra i `raise notice`: l'esito arriva come
-- "errore" finale (raise exception), che rende tutto auto-annullante.
-- Esito atteso: TEST1 OK (0 righe) | TEST2 OK (42501) | TEST3 OK (righe/rpc ok).
-- ============================================================================
-- do $$
-- declare
--   c_events  uuid;
--   r1 text; r2 text; r3a text; r3b text;
-- begin
--   select id into c_events from public.profiles where role = 'cliente' limit 1;
--   if c_events is null then raise exception 'ESITO: nessun cliente in profiles'; end if;
--
--   -- TEST 1: ruolo anon -> select su events pubblicati torna 0 righe
--   --   (RLS filtra silenziosamente, nessun errore).
--   set local role anon;
--   declare n int;
--   begin
--     select count(*) into n from public.events where status = 'published';
--     if n = 0 then r1 := 'OK (0 righe)';
--     else r1 := 'FALLITO: anon vede ' || n || ' righe';
--     end if;
--   end;
--   reset role;
--
--   -- TEST 2: ruolo anon -> rpc get_events_with_stats() deve fallire 42501
--   set local role anon;
--   begin
--     perform public.get_events_with_stats();
--     r2 := 'FALLITO: rpc eseguita da anon';
--   exception
--     when insufficient_privilege then r2 := 'OK (42501)';
--     when others then r2 := 'ANOMALO: ' || sqlerrm;
--   end;
--   reset role;
--
--   -- TEST 3: ruolo authenticated (cliente esistente) -> invariato
--   perform set_config('request.jwt.claims',
--                      json_build_object('sub', c_events, 'role', 'authenticated')::text, true);
--   perform set_config('request.jwt.claim.sub', c_events::text, true);
--   set local role authenticated;
--   begin
--     perform count(*) from public.events where status = 'published';
--     r3a := 'OK (select riuscita)';
--   exception
--     when others then r3a := 'ANOMALO: ' || sqlerrm;
--   end;
--   begin
--     perform public.get_events_with_stats();
--     r3b := 'OK (rpc riuscita)';
--   exception
--     when others then r3b := 'ANOMALO: ' || sqlerrm;
--   end;
--   reset role;
--
--   raise exception
--     'ESITO TEST 7.1 (tutto annullato) -> TEST1 anon select: % | TEST2 anon rpc: % | TEST3 auth select: % | TEST3 auth rpc: %',
--     r1, r2, r3a, r3b;
-- end $$;
--
-- Dump grants/policy (fuori transazione, sola lettura):
--   select routine_name, grantee, privilege_type
--   from information_schema.role_routine_grants
--   where routine_name in ('get_events_with_stats','is_blocked_with');
--   select tablename, policyname, roles, qual
--   from pg_policies where tablename = 'events';
-- Attese: nessuna riga con grantee = anon per le due funzioni;
-- events_select_published con roles = {authenticated}, qual invariata.
-- ============================================================================
