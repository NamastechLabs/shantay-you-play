-- =============================================================================
-- Migration: up to 4 photos per jury look
--
-- Same shape as the queens' looks (see 20261103000000_look_extra_images.sql):
-- image_url stays the main photo (front, required) and three optional photos are
-- added next to it: back, rebuild and one spare.
-- =============================================================================
begin;

alter table public.jury_looks
  add column image2_url text,
  add column image3_url text,
  add column image4_url text;

-- Updates stay column-limited (see 20261102000600_jury_looks.sql)
grant update (image2_url, image3_url, image4_url) on public.jury_looks to authenticated;

commit;
