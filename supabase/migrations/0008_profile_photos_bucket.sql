-- ============================================================================
-- Block 4.2a: bucket privato per le gallerie foto profilo + RLS
-- Run in: Supabase Dashboard -> SQL Editor. Idempotente.
--
-- Bucket PRIVATO: le foto profilo non hanno mai URL pubblici; l'app le
-- serve via signed URL, e la creazione della signed URL passa dalla
-- policy SELECT qui sotto.
--
-- Path convention: <owner_uid>/<timestamp>_<filename>. La cartella radice
-- identifica il proprietario ed e' vincolata dalla policy INSERT.
--
-- Semantica privacy (decisa col Block 4.2):
--   owner            -> vede sempre le proprie foto
--   privacy 'visible'-> galleria visibile a ogni utente autenticato non bloccato
--   privacy 'ghost'  -> visibile SOLO ai gestori dei cui eventi il proprietario
--                       ha richiesto la partecipazione (qualsiasi stato richiesta)
--   utenti bloccati  -> mai, in entrambe le direzioni (is_blocked_with, 0006)
--
-- L'helper e' SECURITY DEFINER: dentro una policy su storage.objects le
-- subquery su event_requests/profiles verrebbero altrimenti filtrate dalle
-- RLS del chiamante, rendendo la semantica dipendente da policy di altre
-- tabelle. Cosi' la regola e' autocontenuta e deterministica.
-- ============================================================================

-- 1) BUCKET (privato, solo immagini, max 5 MB)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile_photos', 'profile_photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- 2) HELPER VISIBILITA' GALLERIA
create or replace function public.can_view_gallery(gallery_owner uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    gallery_owner = auth.uid()
    or (
      auth.uid() is not null
      and not public.is_blocked_with(gallery_owner)
      and (
        exists (select 1 from public.profiles p
                where p.id = gallery_owner
                  and coalesce(p.privacy_level, 'visible') = 'visible')
        or exists (select 1
                   from public.event_requests r
                   join public.events e on e.id = r.event_id
                   where r.user_id = gallery_owner
                     and e.host_id = auth.uid())
      )
    );
$$;
grant execute on function public.can_view_gallery(uuid) to authenticated;

-- 3) POLICY SUL BUCKET
drop policy if exists "profile_photos_select" on storage.objects;
drop policy if exists "profile_photos_insert_own" on storage.objects;
drop policy if exists "profile_photos_update_own" on storage.objects;
drop policy if exists "profile_photos_delete_own" on storage.objects;

-- Lettura secondo la semantica privacy (nessun accesso anon: bucket privato
-- e policy solo per authenticated).
create policy "profile_photos_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile_photos'
    and public.can_view_gallery(((storage.foldername(name))[1])::uuid)
  );

-- Caricamento solo nella PROPRIA cartella radice.
create policy "profile_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Modifica/eliminazione solo dei propri file (vincolo via path, piu'
-- robusto della colonna owner deprecata).
create policy "profile_photos_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "profile_photos_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
