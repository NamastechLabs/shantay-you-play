-- =============================================================================
-- Migration: judges can manage looks during 'werk_room'
--
-- Looks and jury looks are written in 'draft', 'werk_room' and 'runway'.
-- Reading is unchanged: they only become visible to everyone at 'runway'
-- (judges always see them).
-- =============================================================================
begin;

-- looks ------------------------------------------------------------------------
drop policy looks_insert_jurado on public.looks;
drop policy looks_update_jurado on public.looks;
drop policy looks_delete_jurado on public.looks;

create policy looks_insert_jurado on public.looks
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and uploaded_by = (select public.current_participant_id())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
    and exists (
      select 1
      from public.participants p
      where p.id = looks.participant_id
        and p.role = 'concursante'
    )
  );

create policy looks_update_jurado on public.looks
  for update to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
  )
  with check (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
  );

create policy looks_delete_jurado on public.looks
  for delete to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
  );

-- jury_looks -------------------------------------------------------------------
drop policy jury_looks_insert_jurado on public.jury_looks;
drop policy jury_looks_update_jurado on public.jury_looks;
drop policy jury_looks_delete_jurado on public.jury_looks;

create policy jury_looks_insert_jurado on public.jury_looks
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and uploaded_by = (select public.current_participant_id())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
    and exists (
      select 1
      from public.participants p
      where p.id = jury_looks.participant_id
        and p.role = 'jurado'
    )
  );

create policy jury_looks_update_jurado on public.jury_looks
  for update to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
  )
  with check (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
  );

create policy jury_looks_delete_jurado on public.jury_looks
  for delete to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.category_status[])
  );

commit;
