-- =============================================================================
-- Migration: new category stage 'reveal' (between 'voting' and 'closed')
--
-- Kept in its own migration: a new enum value cannot be used (policies,
-- functions) in the same transaction that adds it.
-- =============================================================================
alter type public.category_status add value if not exists 'reveal' before 'closed';
