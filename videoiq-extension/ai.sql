-- VideoIQ AI update — paste this WHOLE file into Supabase → SQL Editor → Run (once)
--
-- Lets a danmu be visible to chosen people only (used by ✨ AI social cues: only you
-- and K see them). It also includes the privacy update (privacy.sql), so you don't need
-- to run that one separately. Safe to run again.

-- Who (besides the writer) may read the danmu at all. Empty (null) = everyone.
alter table public.danmu add column if not exists visible_to uuid[];

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
       case when s.mine then d.name_visible_to end  as name_visible_to, -- only the writer sees their choice
       case when s.mine then d.visible_to end       as visible_to        -- only the writer sees who can read it
from public.danmu d
join public.profiles p on p.id = d.user_id
cross join lateral (
  select coalesce((d.style ->> 'anon')::boolean, false) as anon,
         coalesce(d.user_id = auth.uid(), false)          as mine
) a
cross join lateral (
  select a.anon, a.mine,
         (not a.anon) or a.mine or coalesce(auth.uid() = any (d.name_visible_to), false) as shown
) s
-- A danmu with visible_to set can only be read by its writer and those people
where d.visible_to is null
   or coalesce(d.user_id = auth.uid(), false)
   or coalesce(auth.uid() = any (d.visible_to), false);

grant select on public.danmu_public to anon, authenticated;

-- The table itself: each user can now only read their OWN rows (needed to edit/delete)
drop policy if exists "danmu are readable" on public.danmu;
drop policy if exists "read own danmu" on public.danmu;
create policy "read own danmu" on public.danmu for select using (auth.uid() = user_id);
