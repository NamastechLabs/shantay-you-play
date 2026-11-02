-- =============================================================================
-- Migration: raise the jury look intro limit from 500 to 1000 characters
--
-- Queens' look intros (looks.intro) have no database limit; the admin form
-- caps both kinds at 1000.
-- =============================================================================
begin;

alter table public.jury_looks drop constraint jury_looks_intro_check;

alter table public.jury_looks
  add constraint jury_looks_intro_check check (char_length(trim(intro)) between 1 and 1000);

commit;
