-- =============================================================================
-- Migration: explicit table privileges for the `authenticated` role
--
-- Newer Supabase projects no longer auto-grant public tables to anon/authenticated,
-- so the API returned "permission denied" even with RLS policies in place.
-- GRANTs decide which operations a role may attempt; RLS still decides which rows.
-- `anon` intentionally gets nothing: the whole app requires sign-in.
-- =============================================================================
begin;

grant usage on schema public to authenticated;

grant select on public.participants, public.categories, public.looks, public.votes to authenticated;

-- Judges manage categories (RLS restricts writes to is_jurado())
grant insert, update, delete on public.categories to authenticated;

-- Judges create/delete looks; updates stay column-limited (image_url, intro) from the init migration
grant insert, delete on public.looks to authenticated;

-- Voters create ballots; updates stay column-limited (top_N_look_id) from the init migration
grant insert on public.votes to authenticated;

-- participants: no insert/delete (handled by the auth trigger); update (name) granted in the init migration

commit;
