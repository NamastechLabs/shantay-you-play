-- =============================================================================
-- Migration: 'runway-looks' storage bucket + policies
-- Depends on public.is_jurado() from 20261101000000_init_schema.sql
--
-- Object path convention: {category_id}/{participant_id}/{uuid}.webp
-- =============================================================================
begin;

-- Public bucket: images are served from /storage/v1/object/public/runway-looks/...
-- without auth, so <img> tags and CDN caching work. Writes stay locked down by RLS.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'runway-looks',
  'runway-looks',
  true,
  5242880, -- 5 MB hard cap; client-side compression should keep files well below this
  array['image/webp', 'image/jpeg', 'image/png']
)
on conflict (id) do update
set public             = excluded.public,
    file_size_limit    = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- RLS is already enabled on storage.objects in every Supabase project.

-- Listing/reading through the API (also required for upsert) — signed-in users only.
-- Public URL access does not go through this policy.
create policy runway_looks_select_authenticated on storage.objects
  for select to authenticated
  using (bucket_id = 'runway-looks');

-- Only judges upload, and only into a {category_id}/{participant_id}/ folder
create policy runway_looks_insert_jurado on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'runway-looks'
    and (select public.is_jurado())
    and array_length(storage.foldername(name), 1) = 2
  );

create policy runway_looks_update_jurado on storage.objects
  for update to authenticated
  using      (bucket_id = 'runway-looks' and (select public.is_jurado()))
  with check (bucket_id = 'runway-looks' and (select public.is_jurado()));

create policy runway_looks_delete_jurado on storage.objects
  for delete to authenticated
  using (bucket_id = 'runway-looks' and (select public.is_jurado()));

commit;
