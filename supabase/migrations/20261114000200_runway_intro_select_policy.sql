-- =============================================================================
-- Migration: let judges overwrite the runway intro video (upsert)
-- Depends on 20261108000100_storage_runway_intro.sql
--
-- Uploading with upsert (INSERT ... ON CONFLICT DO UPDATE) also needs a SELECT
-- policy, otherwise Postgres rejects it with "new row violates row-level
-- security policy". Public URL reads do not go through RLS, so only judges
-- get it.
-- =============================================================================
begin;

create policy runway_intro_select_jurado on storage.objects
  for select to authenticated
  using (bucket_id = 'runway-intro' and (select public.is_jurado()));

commit;
