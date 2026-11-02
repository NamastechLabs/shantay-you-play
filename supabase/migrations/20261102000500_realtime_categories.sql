-- =============================================================================
-- Migration: realtime category changes
--
-- Clients subscribe to categories so the homepage and runway update the moment
-- the jurado changes a status (e.g. voting -> reveal -> closed). Realtime
-- respects RLS, so drafts are never broadcast to contestants. Events only act
-- as a "something changed" signal: clients refetch, which also recomputes the
-- Top 3 / ranking from every vote.
-- =============================================================================
begin;

alter publication supabase_realtime add table public.categories;

commit;
