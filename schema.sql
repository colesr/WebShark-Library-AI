-- WebShark Library.AI — Supabase schema
-- Run this in your Supabase project's SQL Editor (Dashboard > SQL Editor > New query)
-- Safe to re-run: uses IF NOT EXISTS / OR REPLACE where possible.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Resources (community submissions + moderation)
-- ---------------------------------------------------------------------------
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
drop policy if exists "Public can view approved resources" on resources;
create policy "Public can view approved resources"
  on resources for select
  using (status = 'approved');

-- Anyone can submit a new resource, but it must land as 'pending'
drop policy if exists "Public can submit new resources" on resources;
create policy "Public can submit new resources"
  on resources for insert
  with check (status = 'pending');

-- ---------------------------------------------------------------------------
-- Admins
-- ---------------------------------------------------------------------------
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table admins enable row level security;

drop policy if exists "Admins can view all resources" on resources;
create policy "Admins can view all resources"
  on resources for select
  using (exists (select 1 from admins where admins.user_id = auth.uid()));

drop policy if exists "Admins can update resource status" on resources;
create policy "Admins can update resource status"
  on resources for update
  using (exists (select 1 from admins where admins.user_id = auth.uid()));

drop policy if exists "Admins can view admin list" on admins;
create policy "Admins can view admin list"
  on admins for select
  using (exists (select 1 from admins a2 where a2.user_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- Safe upvote (anonymous-friendly; no direct UPDATE on resources)
-- ---------------------------------------------------------------------------
create or replace function upvote_resource(resource_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update resources set votes = votes + 1
  where id = resource_id and status = 'approved';
end;
$$;

grant execute on function upvote_resource(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Profiles (username required for social features)
-- ---------------------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now(),
  constraint username_format check (
    username ~ '^[a-zA-Z0-9_]{3,24}$'
  )
);

alter table profiles enable row level security;

-- Public can read usernames (needed to show who commented)
drop policy if exists "Public can view profiles" on profiles;
create policy "Public can view profiles"
  on profiles for select
  using (true);

-- Users create their own profile at signup
drop policy if exists "Users can insert own profile" on profiles;
create policy "Users can insert own profile"
  on profiles for insert
  with check (auth.uid() = id);

-- Users can update their own profile
drop policy if exists "Users can update own profile" on profiles;
create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- Comments (login + username required; resources remain free without login)
-- resource_key: "base-<n>" for curated items, or the community resource uuid
-- ---------------------------------------------------------------------------
create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  resource_key text not null,
  -- FK to profiles (not only auth.users) so PostgREST can embed usernames
  -- and so only users who chose a username can post.
  user_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists comments_resource_key_idx on comments (resource_key);
create index if not exists comments_created_at_idx on comments (created_at desc);

alter table comments enable row level security;

-- Anyone can read comments (discussion is public; posting is gated)
drop policy if exists "Public can view comments" on comments;
create policy "Public can view comments"
  on comments for select
  using (true);

-- Only authenticated users with a profile can post
drop policy if exists "Logged-in users with profile can comment" on comments;
create policy "Logged-in users with profile can comment"
  on comments for insert
  with check (
    auth.uid() = user_id
    and exists (select 1 from profiles p where p.id = auth.uid())
  );

-- Authors can delete their own comments
drop policy if exists "Users can delete own comments" on comments;
create policy "Users can delete own comments"
  on comments for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Helper: comment counts per resource (optional convenience view)
-- ---------------------------------------------------------------------------
create or replace view comment_counts as
  select resource_key, count(*)::int as count
  from comments
  group by resource_key;

grant select on comment_counts to anon, authenticated;
