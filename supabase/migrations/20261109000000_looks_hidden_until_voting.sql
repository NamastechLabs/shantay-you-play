-- =============================================================================
-- Migration: keep every look hidden until voting opens (DRG-1)
--
-- During the last runway some participants opened the public runway page while
-- the week was still in the 'runway' (Pasarela) stage and saw the looks early.
-- The page is now blocked in the app, and this migration closes the same hole
-- in the database so the looks cannot be read straight from the API either.
--
-- Looks and jury looks are readable by contestants/guests only from 'voting'
-- on. Judges keep full access (admin screens) and everyone keeps access to
-- their own looks (my looks / guest upload). The rest of each policy is
-- unchanged from 20261107000100_runway_guests.sql.
-- =============================================================================
begin;

drop policy looks_select on public.looks;

create policy looks_select on public.looks
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or participant_id = (select public.current_participant_id())
      or public.category_has_status(category_id, array['voting', 'reveal', 'closed']::public.runway_status[])
    )
    and public.can_access_category(category_id)
  );

drop policy jury_looks_select on public.jury_looks;

create policy jury_looks_select on public.jury_looks
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or participant_id = (select public.current_participant_id())
      or public.category_has_status(category_id, array['voting', 'reveal', 'closed']::public.runway_status[])
    )
    and public.can_access_category(category_id)
  );

commit;
