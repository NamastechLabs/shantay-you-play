-- =============================================================================
-- Migration: let `service_role` read the groups of a runway
--
-- Used by GET /api/commentary/runway, which now also returns the groups
-- ("bands") of the group categories: name, intro, photos and members. Read-only,
-- like 20261108000000_service_role_read_runway_looks.sql.
-- =============================================================================
begin;

grant select on public.category_groups, public.category_group_members, public.category_group_photos to service_role;

commit;
