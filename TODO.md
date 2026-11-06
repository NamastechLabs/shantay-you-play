# TODO

## Testing without touching live data

- [ ] **Local test environment to preview any runway status** (e.g. see the jury looks while the live runway is still in Werk Room).
  - Why: friends already use the app on the shared Supabase DB, so changing a runway's status to test affects them. Hardcoding the status in the UI is not enough: the home page only loads jury/my looks when `status === 'runway'`, and RLS policies also depend on status.
  - Plan:
    - Run Supabase locally (`supabase start`, needs Docker Desktop) using the existing `supabase/config.toml` and migrations, and point `.env.local` at it. Alternative: a second free Supabase project as staging.
    - Add `supabase/seed.sql` with a runway in `runway` status, participants (with auth users so `DevImpersonate` works), jury looks with 1–4 photos and contestant looks.
    - Document in the README how to switch `.env` between live and local.
    - Use the admin runway screen to advance the status and test voting, reveal and closing.
