-- =============================================================================
-- Migration: participants.drag_name
-- Stage name shown across the app. Null until the user completes onboarding.
-- =============================================================================
begin;

alter table public.participants
  add column drag_name text;

-- 2-50 chars, no leading/trailing whitespace (the client trims before saving)
alter table public.participants
  add constraint participants_drag_name_check check (
    drag_name is null
    or (drag_name = trim(drag_name) and char_length(drag_name) between 2 and 50)
  );

-- No two queens with the same name, regardless of casing
create unique index participants_drag_name_key on public.participants (lower(drag_name));

-- Users set their own drag name (row restricted by participants_update_own)
grant update (drag_name) on public.participants to authenticated;

commit;
