-- =============================================================================
-- Migration: let `service_role` read participants
--
-- Like authenticated, service_role gets no automatic grants on new tables in newer
-- Supabase projects (it skips RLS, but table privileges still apply). Only the
-- local "impersonate" debugging routes (server/api/dev) use it: they list the
-- participants and look up an email.
-- =============================================================================
begin;

grant usage on schema public to service_role;
grant select on public.participants to service_role;

commit;
