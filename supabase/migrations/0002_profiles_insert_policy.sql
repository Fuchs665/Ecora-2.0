-- ============================================================================
-- Block 1.3: profiles INSERT policy
-- Without this, RLS silently rejects the profile row created at registration
-- (the table had SELECT/UPDATE policies but no INSERT policy).
-- Run in: Supabase Dashboard -> SQL Editor. Idempotent.
-- ============================================================================

drop policy if exists "Ogni utente crea solo il proprio profilo" on public.profiles;

create policy "Ogni utente crea solo il proprio profilo"
on public.profiles for insert to authenticated
with check (auth.uid() = id);
