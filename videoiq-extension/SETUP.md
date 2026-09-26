# VideoIQ — Online Setup (one database for everyone)

Everyone's danmu are saved in **one Supabase database**. People create an
account (email + password) inside the extension. Only the extension's owner
does the steps below, **once**. Users just install the extension and sign in.

## 1. Create a free Supabase project
1. Go to https://supabase.com → **Start your project** → sign in (GitHub or email).
2. **New project** → give it a name (e.g. `videoiq`), set a database password
   (save it somewhere; the extension doesn't need it), pick a region near your users → **Create**.
3. Wait about 1 minute until the project is ready.

## 2. Create the tables (copy, paste, Run)
Left sidebar → **SQL Editor** → **New query** → paste everything below → **Run**.
It should say *Success. No rows returned*.

```sql
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
```

## 3. Email confirmation (choose one)
**Authentication** → **Sign In / Providers** → **Email**:
- **Confirm email ON** (default, recommended for public use): new users get a
  confirmation email and must click it before signing in. The free plan's
  built-in mailer only sends a few emails per hour. For real traffic, set up your own
  SMTP under **Authentication → Emails → SMTP Settings**.
- **Confirm email OFF**: people are signed in right after creating an account.
  Easiest for testing and small groups.

## 4. Put your project keys into the extension
**Project Settings** → **API Keys** (or **Data API**):
- **Project URL**, e.g. `https://abcdefghijkl.supabase.co`
- **Publishable key** (`sb_publishable_…`) or the legacy **anon public** key (`eyJ…`)

Open `config.js` and replace the placeholders:
```js
const VIQ_CONFIG = {
  supabaseUrl:  'https://abcdefghijkl.supabase.co',
  supabaseKey:  'sb_publishable_xxxxxxxx'
};
```
These two values are **meant to be public**. The security rules above decide what
anyone can do. **Never** put the `service_role` / secret key in the extension.

Reload the extension at `chrome://extensions`. The panel header now shows **👤 Sign in**.

## Where to see the data
Supabase → **Table Editor** → `danmu` (all danmu from everyone) and `profiles`
(all users). **Authentication → Users** lists the accounts.
