-- =============================================================================
-- Migration: up to 4 photos per queen look
--
-- image_url stays the main photo (front, required). Three optional photos are
-- added next to it: back, rebuild and one spare. Only queens' looks get them;
-- jury_looks keeps a single photo.
-- =============================================================================
begin;

alter table public.looks
  add column image2_url text,
  add column image3_url text,
  add column image4_url text;

-- Updates stay column-limited (see the init migration); judges may edit the new columns too
grant update (image2_url, image3_url, image4_url) on public.looks to authenticated;

commit;
