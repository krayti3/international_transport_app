-- Migration: create chat_messages table for internal team chat.
-- Safe to re-run: all objects are guarded with if not exists / drop if exists.

create table if not exists public.chat_messages (
  id bigserial primary key,
  sender_id uuid not null references auth.users (id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_messages_created_at
  on public.chat_messages (created_at desc);

alter table public.chat_messages enable row level security;

drop policy if exists "All authenticated can read chat" on public.chat_messages;
create policy "All authenticated can read chat"
  on public.chat_messages for select
  using (auth.role() = 'authenticated');

drop policy if exists "Authenticated can send chat" on public.chat_messages;
create policy "Authenticated can send chat"
  on public.chat_messages for insert
  with check (auth.uid() is not null and sender_id = auth.uid());

grant select, insert on table public.chat_messages to authenticated, anon;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end $$;
