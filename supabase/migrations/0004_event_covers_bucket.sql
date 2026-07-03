-- ============================================================================
-- Block 3.5: bucket di storage per le copertine eventi
-- Run in: Supabase Dashboard -> SQL Editor.
--
-- Contesto: EcoraDataService.uploadEventImage() (Block 3.4) carica su un
-- bucket 'event_covers' che non esiste ancora (il vecchio 'event_images'
-- risulta anch'esso assente). Senza bucket, ogni upload fallisce.
-- Il codice chiama getPublicUrl(), quindi il bucket deve essere pubblico
-- in lettura. I path caricati sono "<timestamp>_<filename>", senza alcuna
-- struttura per-evento: le policy di scrittura non possono quindi vincolare
-- il singolo evento via path e si basano su is_gestore() (migration 0003)
-- e sulla colonna owner che Supabase Storage popola automaticamente.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('event_covers', 'event_covers', true)
on conflict (id) do nothing;

drop policy if exists "event_covers_read_public"     on storage.objects;
drop policy if exists "event_covers_insert_gestore"  on storage.objects;
drop policy if exists "event_covers_update_own"      on storage.objects;
drop policy if exists "event_covers_delete_own"      on storage.objects;

-- Lettura pubblica (le copertine eventi sono visibili anche da anonimi,
-- coerente con la policy events_select_published della migration 0003).
create policy "event_covers_read_public" on storage.objects
  for select to public
  using (bucket_id = 'event_covers');

-- Scrittura solo ai gestori (qualunque gestore, non solo il proprietario
-- dell'evento: il path non lo consente da solo; sufficiente per v1).
create policy "event_covers_insert_gestore" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'event_covers' and public.is_gestore());

-- Modifica/eliminazione solo dei propri file caricati.
create policy "event_covers_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'event_covers' and owner = auth.uid())
  with check (bucket_id = 'event_covers' and owner = auth.uid());
create policy "event_covers_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'event_covers' and owner = auth.uid());
