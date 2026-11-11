-- =============================================================================
-- Migration: group photos (DRG-5)
--
-- Each group of a group category has up to 4 landscape photos (16:9 or 5:3) that
-- are shown together as one picture. Members of the group upload them while the
-- runway is in 'werk_room'; judges manage them until voting opens.
--
-- Files live in the existing 'runway-looks' bucket under
-- {category_id}/{group_id}/{uuid}.webp
--
-- Visibility follows the looks: the group's own members (and judges) see them
-- while preparing, everyone else from 'voting' on.
-- =============================================================================
begin;

create table public.category_group_photos (
  group_id     uuid        primary key,
  category_id  uuid        not null,
  image_url    text        check (image_url  is null or char_length(image_url)  between 1 and 2048),
  image2_url   text        check (image2_url is null or char_length(image2_url) between 1 and 2048),
  image3_url   text        check (image3_url is null or char_length(image3_url) between 1 and 2048),
  image4_url   text        check (image4_url is null or char_length(image4_url) between 1 and 2048),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint category_group_photos_group_fkey foreign key (group_id, category_id)
    references public.category_groups (id, category_id) on delete cascade
);

create index category_group_photos_category_id_idx on public.category_group_photos (category_id);

create trigger category_group_photos_set_updated_at before update on public.category_group_photos
  for each row execute function public.set_updated_at();

revoke all on public.category_group_photos from anon, authenticated;
grant select, insert, update, delete on public.category_group_photos to authenticated;

alter table public.category_group_photos enable row level security;

create policy category_group_photos_select on public.category_group_photos
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or public.participant_group_id(category_id, (select public.current_participant_id())) = group_id
      or public.category_has_status(category_id, array['voting', 'reveal', 'closed']::public.runway_status[])
    )
    and public.can_access_category(category_id)
  );

-- Judges: until voting opens (same window as the looks)
create policy category_group_photos_insert_jurado on public.category_group_photos
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.runway_status[])
  );

create policy category_group_photos_update_jurado on public.category_group_photos
  for update to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.runway_status[])
  )
  with check (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.runway_status[])
  );

create policy category_group_photos_delete_jurado on public.category_group_photos
  for delete to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'werk_room', 'runway']::public.runway_status[])
  );

-- Members of the group: only their own group, only during 'werk_room'
create policy category_group_photos_insert_member on public.category_group_photos
  for insert to authenticated
  with check (
    public.participant_group_id(category_id, (select public.current_participant_id())) = group_id
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
  );

create policy category_group_photos_update_member on public.category_group_photos
  for update to authenticated
  using (
    public.participant_group_id(category_id, (select public.current_participant_id())) = group_id
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
  )
  with check (
    public.participant_group_id(category_id, (select public.current_participant_id())) = group_id
    and public.category_has_status(category_id, array['werk_room']::public.runway_status[])
  );

-- -----------------------------------------------------------------------------
-- Storage: members of a group upload and delete files in {category_id}/{group_id}/
-- (judges already can, through the runway_looks_*_jurado policies). A malformed
-- folder name fails the uuid cast, which rejects the request.
-- -----------------------------------------------------------------------------
create policy runway_looks_insert_group on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and public.participant_group_id(
      ((storage.foldername(name))[1])::uuid,
      (select public.current_participant_id())
    ) = ((storage.foldername(name))[2])::uuid
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room']::public.runway_status[])
  );

create policy runway_looks_delete_group on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and public.participant_group_id(
      ((storage.foldername(name))[1])::uuid,
      (select public.current_participant_id())
    ) = ((storage.foldername(name))[2])::uuid
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room']::public.runway_status[])
  );

commit;
