# TODO

## Testing without touching live data

- [x] **Local test environment to preview any runway status.** Done: see "Local test database" in the README (`pnpm db:start`, `pnpm dev:local`, `supabase/seed.sql`).

## Commentary endpoint security

- [ ] **Investigate a more secure way to provide tokens per user, with expiration.** Today `GET /api/commentary/runway` uses one shared static bearer token (`NUXT_COMMENTARY_API_TOKEN`) and reads with the service-role key, which bypasses RLS. Look into per-user tokens that expire and can be revoked (e.g. a tokens table with hashed values and `expires_at`, or short-lived signed tokens issued to a signed-in judge), and into reading with the user's own permissions instead of the service role.

- [ ] **Restore the Pasarela stage check in the commentary endpoint.** It was removed temporarily (commit `483cdeb`): `GET /api/commentary/runway` now returns the latest week whatever its status. To roll back, in `server/api/commentary/runway.get.ts` change `runwayQuery.order('week_number', { ascending: false })` back to `runwayQuery.eq('status', 'runway').order('week_number', { ascending: false })`, and restore the 404 message `No runway is in the "runway" (Pasarela) stage`.
