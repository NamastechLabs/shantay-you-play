-- =============================================================================
-- Migration: queens upload their own looks during 'werk_room'
--
-- While a runway is in 'werk_room', a contestant can create, edit and delete
-- THEIR OWN look in each of its categories (rows in public.looks, plus the files
-- in the 'runway-looks' bucket under {category_id}/{their participant id}/).
-- Judges keep managing every look through the existing *_jurado policies.
-- Policies are permissive, so both sets apply side by side.
-- =============================================================================
begin;

-- looks: a queen can always read her own looks (everyone else sees them from 'runway')
drop policy looks_select on public.looks;

create policy looks_select on public.looks
  for select to authenticated
  using (
    (select public.is_jurado())
    or participant_id = (select public.current_participant_id())
    or public.category_has_status(category_id, array['runway', 'voting', 'reveal', 'closed']::public.runway_status[])
  );

create policy looks_insert_own on public.looks
  for insert to authenticated
  with check (
    participant_id = (select public.current_participant_id())
    and uploaded_by = (select public.current_participant_id())
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
    and exists (
      select 1
      from public.participants p
      where p.id = looks.participant_id
        and p.role = 'concursante'
    )
  );

create policy looks_update_own on public.looks
  for update to authenticated
  using (
    participant_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
  )
  with check (
    participant_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
  );

create policy looks_delete_own on public.looks
  for delete to authenticated
  using (
    participant_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
  );

-- storage: the same, for the files in {category_id}/{participant_id}/
-- A malformed folder name fails the uuid cast, which rejects the request.
create policy runway_looks_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2] = (select public.current_participant_id())::text
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room']::public.runway_status[])
  );

create policy runway_looks_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2] = (select public.current_participant_id())::text
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room']::public.runway_status[])
  );

commit;
