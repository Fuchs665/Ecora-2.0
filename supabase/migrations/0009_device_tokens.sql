-- ============================================================================
-- Block 4.3a: tabella token FCM per le notifiche push
-- Run in: Supabase Dashboard -> SQL Editor. Idempotente.
--
-- Ogni riga = un device di un utente. La Edge Function (Block 4.3b) leggera'
-- questa tabella con service_role per inviare le push; dal client valgono
-- solo le proprie righe (own-rows RLS).
-- ============================================================================

create table if not exists public.device_tokens (
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_select_own" on public.device_tokens;
drop policy if exists "device_tokens_insert_own" on public.device_tokens;
drop policy if exists "device_tokens_update_own" on public.device_tokens;
drop policy if exists "device_tokens_delete_own" on public.device_tokens;

create policy "device_tokens_select_own" on public.device_tokens
  for select to authenticated using (auth.uid() = user_id);
create policy "device_tokens_insert_own" on public.device_tokens
  for insert to authenticated with check (auth.uid() = user_id);
create policy "device_tokens_update_own" on public.device_tokens
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "device_tokens_delete_own" on public.device_tokens
  for delete to authenticated using (auth.uid() = user_id);
