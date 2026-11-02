-- =============================================================================
-- Migration: participants.avatar_url + 'participant-avatars' storage bucket
--
-- Optional profile picture, edited by each participant from their profile page.
-- Object path convention: {participant_id}/{uuid}.webp
-- =============================================================================
begin;

alter table public.participants
  add column avatar_url text;

alter table public.participants
  add constraint participants_avatar_url_check check (
    avatar_url is null or char_length(avatar_url) between 1 and 2048
  );

-- Participants set their own picture (row restricted by participants_update_own)
grant update (avatar_url) on public.participants to authenticated;

-- -----------------------------------------------------------------------------
-- Storage: public bucket (served without auth); writes limited to the owner's folder
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'participant-avatars',
  'participant-avatars',
  true,
  2097152, -- 2 MB hard cap; the client resizes avatars to a few dozen KB
  array['image/webp', 'image/jpeg', 'image/png']
)
on conflict (id) do update
set public             = excluded.public,
    file_size_limit    = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy participant_avatars_select_authenticated on storage.objects
  for select to authenticated
  using (bucket_id = 'participant-avatars');

create policy participant_avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'participant-avatars'
    and array_length(storage.foldername(name), 1) = 1
    and (storage.foldername(name))[1] = (select public.current_participant_id())::text
  );

create policy participant_avatars_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'participant-avatars'
    and (storage.foldername(name))[1] = (select public.current_participant_id())::text
  )
  with check (
    bucket_id = 'participant-avatars'
    and (storage.foldername(name))[1] = (select public.current_participant_id())::text
  );

create policy participant_avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'participant-avatars'
    and (storage.foldername(name))[1] = (select public.current_participant_id())::text
  );

commit;
