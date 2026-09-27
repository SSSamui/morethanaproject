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
