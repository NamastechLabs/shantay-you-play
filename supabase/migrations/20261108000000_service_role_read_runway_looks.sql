-- =============================================================================
-- Migration: let `service_role` read the runway content
--
-- Used by GET /api/commentary/runway, which hands the current runway (categories,
-- looks, jury looks) to an AI that writes the commentary. Like authenticated,
-- service_role gets no automatic grants on new tables in newer Supabase
-- projects (it skips RLS, but table privileges still apply). Read-only.
-- =============================================================================
begin;

grant usage on schema public to service_role;
grant select on public.runways, public.categories, public.looks, public.jury_looks to service_role;

commit;
