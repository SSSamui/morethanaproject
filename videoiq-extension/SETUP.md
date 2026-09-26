# VideoIQ — Supabase Setup (no accounts needed!)

## 1. Create a free Supabase project
Go to https://supabase.com → New Project → copy your Project URL and anon key.

## 2. Run this SQL in the Supabase SQL Editor

```sql
-- Public danmu posts (no user accounts required)
create table public.danmu_posts (
  id          bigint generated always as identity primary key,
  video_id    text not null,
  video_title text,
  author_name text not null default 'Anonymous',
  color       text not null default '#4f9eff',
  notes       jsonb not null,           -- array of note objects
  posted_at   timestamptz default now(),
  is_public   boolean default true
);

create index danmu_posts_video_idx on public.danmu_posts(video_id);

-- Anyone can read public posts
alter table public.danmu_posts enable row level security;

create policy "Anyone can read public posts" on public.danmu_posts
  for select using (is_public = true);

create policy "Anyone can insert" on public.danmu_posts
  for insert with check (true);
```

## 3. Add your credentials to config.js
Edit `config.js` and replace the placeholder values.
