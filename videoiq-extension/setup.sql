-- VideoIQ database setup — paste this WHOLE file into Supabase → SQL Editor → Run

-- ── Accounts: one profile per user (display name is unique, case-insensitive)
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 30),
  color        text not null default '#4f9eff' check (color ~ '^#[0-9a-fA-F]{6}$'),
  created_at   timestamptz not null default now()
);
create unique index profiles_name_unique on public.profiles (lower(display_name));

-- ── Danmu: one row per danmu, from every user, on every video
create table public.danmu (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  client_id   bigint not null,                       -- the note's id inside the extension
  video_id    text not null check (char_length(video_id) between 1 and 20),
  video_title text check (char_length(video_title) <= 300),
  time_sec    integer not null check (time_sec >= 0),
  text        text not null check (char_length(text) between 1 and 500),
  style       jsonb,                                 -- font / size / color / position
  is_summary  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, client_id)
);
create index danmu_video_idx on public.danmu (video_id);

-- ── Security: anyone can read; users can only write their OWN rows
alter table public.profiles enable row level security;
alter table public.danmu    enable row level security;

create policy "profiles are readable"  on public.profiles for select using (true);
create policy "edit own profile"       on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

create policy "danmu are readable"     on public.danmu for select using (true);
create policy "add own danmu"          on public.danmu for insert with check (auth.uid() = user_id);
create policy "edit own danmu"         on public.danmu for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "delete own danmu"       on public.danmu for delete using (auth.uid() = user_id);

grant select on public.profiles, public.danmu to anon, authenticated;
grant update (display_name, color) on public.profiles to authenticated;
grant insert, update, delete on public.danmu to authenticated;

-- ── Create the profile automatically when someone signs up
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, color)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1)),
    case when (new.raw_user_meta_data ->> 'color') ~ '^#[0-9a-fA-F]{6}$'
         then new.raw_user_meta_data ->> 'color' else '#4f9eff' end
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Keep updated_at current on edits
create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;

create trigger danmu_touch before update on public.danmu
  for each row execute function public.touch_updated_at();

-- ── Privacy (hidden names / name visible to one person)
--
-- Lets a writer hide their name on a danmu from everyone, or show it to ONE chosen
-- person only. After this, nobody can read who wrote a hidden-name danmu — not even
-- by querying the database directly — except the writer and the chosen person.

-- Who (besides the writer) may see the writer's name on a hidden-name danmu
alter table public.danmu add column if not exists name_visible_to uuid[];

-- Public reading now goes through this view, which leaves out the author of hidden-name
-- danmu for everyone who isn't allowed to see it.
create or replace view public.danmu_public with (security_barrier = true) as
select d.client_id, d.video_id, d.video_title, d.time_sec, d.text, d.style, d.is_summary,
       d.created_at, d.updated_at,
       case when s.shown then d.user_id end        as user_id,
       case when s.shown then p.display_name end   as display_name,
       case when s.shown then p.color end          as color,
       not s.shown                                  as name_hidden,
       (s.anon and s.shown and not s.mine)          as name_revealed,   -- hidden from others, shown to you
       case when s.mine then d.name_visible_to end  as name_visible_to  -- only the writer sees their choice
from public.danmu d
join public.profiles p on p.id = d.user_id
cross join lateral (
  select coalesce((d.style ->> 'anon')::boolean, false) as anon,
         coalesce(d.user_id = auth.uid(), false)          as mine
) a
cross join lateral (
  select a.anon, a.mine,
         (not a.anon) or a.mine or coalesce(auth.uid() = any (d.name_visible_to), false) as shown
) s;

grant select on public.danmu_public to anon, authenticated;

-- The table itself: each user can now only read their OWN rows (needed to edit/delete)
drop policy if exists "danmu are readable" on public.danmu;
drop policy if exists "read own danmu" on public.danmu;
create policy "read own danmu" on public.danmu for select using (auth.uid() = user_id);

-- ── Video tags
--
-- Tags describe what a video is about (puppy, survivor, sports…). A video can have
-- many tags. Everyone can read them; signed-in users can add tags and remove the
-- ones they added. (Comment tags like "emotion" need no database change.)

create table if not exists public.video_tags (
  id          bigint generated always as identity primary key,
  video_id    text not null check (char_length(video_id) between 1 and 20),
  video_title text check (char_length(video_title) <= 300),
  tag         text not null check (char_length(trim(tag)) between 1 and 30),
  added_by    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);
create unique index if not exists video_tags_unique on public.video_tags (video_id, lower(tag));
create index if not exists video_tags_tag on public.video_tags (lower(tag));

alter table public.video_tags enable row level security;
drop policy if exists "video tags are readable" on public.video_tags;
drop policy if exists "add video tags"           on public.video_tags;
drop policy if exists "remove own video tags"    on public.video_tags;
create policy "video tags are readable" on public.video_tags for select using (true);
create policy "add video tags"           on public.video_tags for insert with check (auth.uid() = added_by);
create policy "remove own video tags"    on public.video_tags for delete using (auth.uid() = added_by);

grant select on public.video_tags to anon, authenticated;
grant insert, delete on public.video_tags to authenticated;
