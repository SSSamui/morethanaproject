-- VideoIQ video tags — paste this WHOLE file into Supabase → SQL Editor → Run (once)
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
