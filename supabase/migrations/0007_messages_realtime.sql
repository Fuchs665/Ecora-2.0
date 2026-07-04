-- ============================================================================
-- Block 4.1: enable Realtime on messages (event chat)
-- Run in: Supabase Dashboard -> SQL Editor
-- Idempotent: safe to re-run.
--
-- Realtime postgres_changes respects the messages RLS policies (host +
-- approved participants, blocked users filtered), so no new policies needed.
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
