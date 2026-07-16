-- Migration: realtime notifications table.
-- The app subscribes to this table; when the secretary creates/closes a trip
-- the app inserts a row targeted at the relevant user(s) and it pops up
-- instantly on their device (desktop or phone). Safe to re-run.

create table if not exists public.notifications (
  id bigserial primary key,
  user_id uuid references auth.users (id) on delete cascade,
  title text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx on public.notifications (user_id);

-- RLS: a user sees only notifications aimed at them or broadcast (user_id null).
alter table public.notifications enable row level security;

drop policy if exists "Notifications readable by target or broadcast" on public.notifications;
create policy "Notifications readable by target or broadcast"
  on public.notifications for select
  using (user_id is null or user_id = auth.uid());

drop policy if exists "Authenticated can create notifications" on public.notifications;
create policy "Authenticated can create notifications"
  on public.notifications for insert
  with check (auth.uid() is not null);

drop policy if exists "Recipient or admin can delete notifications" on public.notifications;
create policy "Recipient or admin can delete notifications"
  on public.notifications for delete
  using (user_id = auth.uid() or public.is_admin(auth.uid()));

grant select, insert, delete on table public.notifications to authenticated, anon;

-- Stream changes over Realtime.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
