-- WebShark Library.AI — Supabase schema
-- Run this in your Supabase project's SQL Editor (Dashboard > SQL Editor > New query)

create extension if not exists "pgcrypto";

create table if not exists resources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  url text not null,
  category text not null,
  description text not null,
  tags text[] not null default '{}',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  votes integer not null default 0,
  created_at timestamptz not null default now()
);

alter table resources enable row level security;

-- Anyone (including logged-out visitors) can see approved resources
create policy "Public can view approved resources"
  on resources for select
  using (status = 'approved');

-- Anyone can submit a new resource, but it must land as 'pending' —
-- this is what stops someone from inserting a row that skips the review queue
create policy "Public can submit new resources"
  on resources for insert
  with check (status = 'pending');

-- Admins table: add a row here (with a real user's id) to grant them admin rights
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table admins enable row level security;

-- Admins can see everything, including pending/rejected submissions
create policy "Admins can view all resources"
  on resources for select
  using (exists (select 1 from admins where admins.user_id = auth.uid()));

-- Admins can approve/reject (i.e. update status)
create policy "Admins can update resource status"
  on resources for update
  using (exists (select 1 from admins where admins.user_id = auth.uid()));

-- Safe upvote function: lets anonymous visitors increment votes on an approved
-- resource WITHOUT giving them direct UPDATE access to the table (which could
-- otherwise be abused to edit titles/urls/etc.)
create or replace function upvote_resource(resource_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update resources set votes = votes + 1
  where id = resource_id and status = 'approved';
end;
$$;

grant execute on function upvote_resource(uuid) to anon;

-- Only admins can see the admins table itself
create policy "Admins can view admin list"
  on admins for select
  using (exists (select 1 from admins a2 where a2.user_id = auth.uid()));
