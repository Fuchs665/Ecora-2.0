-- ============================================================================
-- Block 6.1b: hygiene follow-up — revoke anon execute su funzioni owner/host-only
-- Run in: Supabase Dashboard -> SQL Editor. Idempotente.
--
-- 0010 ha ripulito il grant implicito PUBLIC, ma il default privilege del
-- progetto Supabase concede comunque execute ad `anon` su ogni nuova
-- funzione in `public`. Per is_gestore()/can_view_gallery() non ha senso:
-- richiedono un auth.uid() reale e per anon collassano a false/null
-- (nessun leak), ma restringiamo comunque per least privilege.
--
-- get_events_with_stats()/is_blocked_with() restano concesse ad anon
-- di proposito (eventi pubblicati visibili anche da anonimi).
-- ============================================================================

revoke execute on function public.is_gestore() from anon;
revoke execute on function public.can_view_gallery(uuid) from anon;
