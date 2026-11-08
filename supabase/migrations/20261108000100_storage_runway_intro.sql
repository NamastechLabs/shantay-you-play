-- =============================================================================
-- Migration: 'runway-intro' storage bucket (the weekly intro video)
-- Depends on public.is_jurado() from 20261101000000_init_schema.sql
--
-- One file, overwritten every week: {bucket}/intro.mp4. No history is kept.
-- Public bucket so the <video> streams from
-- /storage/v1/object/public/runway-intro/intro.mp4 without auth (range requests
-- work, so playback starts before the whole file is downloaded).
-- =============================================================================
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'runway-intro',
  'runway-intro',
  true,
  52428800, -- 50 MB, the free-plan cap per file; aim for ~10 MB
  array['video/mp4']
)
on conflict (id) do update
set public             = excluded.public,
    file_size_limit    = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Only judges write (the Supabase dashboard also works: it bypasses these policies).
-- Public URL reads do not go through RLS, so no select policy is needed.
create policy runway_intro_insert_jurado on storage.objects
  for insert to authenticated
  with check (bucket_id = 'runway-intro' and (select public.is_jurado()));

create policy runway_intro_update_jurado on storage.objects
  for update to authenticated
  using      (bucket_id = 'runway-intro' and (select public.is_jurado()))
  with check (bucket_id = 'runway-intro' and (select public.is_jurado()));

create policy runway_intro_delete_jurado on storage.objects
  for delete to authenticated
  using (bucket_id = 'runway-intro' and (select public.is_jurado()));

commit;
