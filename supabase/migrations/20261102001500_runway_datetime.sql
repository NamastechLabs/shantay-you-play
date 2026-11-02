-- =============================================================================
-- Migration: runways.runway_date becomes a timestamp (date + time of the runway)
--
-- Existing rows keep their day at 00:00 (session time zone, UTC on Supabase);
-- the jurado can set the real time from the admin screen.
-- =============================================================================
begin;

alter table public.runways
  alter column runway_date drop default,
  alter column runway_date type timestamptz using runway_date::timestamptz,
  alter column runway_date set default now();

commit;
