# Special guest invitations (future work)

Status: **planned, not implemented.** This document records the analysis and the decisions taken, so the feature can be built later without redoing the discussion.

## Goal

Special guests can attend some runways as voters without registering on the site. A judge creates an invitation link that expires after a few hours. The guest can only see the **current** category, nothing from past categories, and casts a Top 3 ballot like any participant.

## Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | Statuses the guest can see | `runway`, `voting` and `reveal` (Top 3 included). Never `closed` data or past categories. |
| 2 | Vote weight | Same as everyone else (3/2/1 points). Scoring functions stay untouched. |
| 3 | Link reuse | Reusable until it expires or is revoked. |
| 4 | Changing the vote | Yes, while the category is in `voting` and the invitation has not expired. |
| 5 | Guest role | Voter only. No look or intro on the runway. |
| 6 | Ballot visibility | Anonymous. The admin never sees which guest cast which ballot. |

## Design

### Identity: the invitation row, not a user

A guest has no `auth.users` row and no `participants` row. The invitation is their identity.

New table `guest_invitations`:

- `id uuid` primary key (`gen_random_uuid()`)
- `category_id uuid not null` references `categories` (on delete cascade), indexed
- `label text not null`: an admin-only note to tell invitations apart (e.g. "Special guest week 4"). It is never shown next to a ballot (decision 6).
- `token_hash text not null unique`: SHA-256 of the token; the raw token is never stored
- `expires_at timestamptz not null`
- `revoked_at timestamptz`
- `created_by uuid` references `participants` (on delete set null), default `current_participant_id()`
- `created_at`, `updated_at` as in the other tables

RLS is enabled with **no policies** for `anon` or `authenticated`, and privileges are revoked, so only the service role reads or writes it.

### Ballots

Changes to `votes`:

- `voter_id` becomes nullable.
- New `guest_invitation_id uuid` references `guest_invitations` (on delete cascade), indexed.
- `check ((voter_id is null) <> (guest_invitation_id is null))`: exactly one voter type.
- Unique `(category_id, guest_invitation_id)`: one ballot per guest per category.

Existing policies filter on `voter_id = current_participant_id()`, so guest rows are invisible to members while voting. `category_top_three` and `category_ranking` union over `votes`, so guest ballots are counted without changes.

### Anonymity (decision 6)

- The admin UI lists invitations (label, category, expiry, status, and whether the link was used) but never joins them to ballots.
- Guest ballots must not be exposed with their invitation id through any client-readable query. `votes_select` opens all ballots at `closed`, so if the app ever shows per-voter ballots, guest rows must be shown without identity.
- Caveat: the link between a ballot and an invitation still exists in the database and is readable with the service role. This is enough to keep guests anonymous in the product. If true unlinkability is required, the ballot would have to be stored without the invitation id, tracking "has voted" separately. That is a stricter option, not recommended for now because it breaks "change my vote".

### Access path: server routes with the service role

The guest has no Supabase session and every RLS policy is `to authenticated`, so guests go through Nuxt server routes. This is the project's first server code (`server/` is empty today).

- New private runtime config `SUPABASE_SERVICE_KEY`, also added to `.env.example`. It must never reach the client bundle.
- Guest URL: `/guest/<token>`. The server hashes the token, checks it exists, is not revoked and is not expired, then sets an **httpOnly, secure, sameSite=lax** cookie holding a signed reference to the invitation, and redirects to the guest category page.
- The invitation id always comes from the cookie, never from the request body. The cookie's own `maxAge` matches `expires_at`.
- Expiry is re-checked on **every** request, including the vote write.
- The server validates that the three picks belong to the invitation's category, that they are distinct, and that the category status is `voting`.
- Read routes only return data for the invitation's category and only while its status is `runway`, `voting` or `reveal`. A guest whose category moves to `closed` gets a "this runway has ended" screen.

Suggested routes:

| Route | Who | Purpose |
|-------|-----|---------|
| `GET /guest/[token]` (page) / `POST /api/guest/redeem` | guest | Validate token, set cookie |
| `GET /api/guest/category` | guest | Category, looks, jury looks, own ballot, Top 3 at `reveal` |
| `PUT /api/guest/ballot` | guest | Create or update the guest's ballot |
| `GET/POST /api/admin/guest-invitations`, `POST .../[id]/revoke` | judge | List, create, revoke (checks `is_jurado` from the caller's session) |

Creating an invitation returns the raw link once. It cannot be shown again because only the hash is stored.

### App changes

- `nuxt.config.ts`: add `/guest/**` to `supabase.redirectOptions.exclude`, otherwise the global guard sends guests to `/login`.
- `app/middleware/drag-name.global.ts` already returns early when there is no user; verify it still does.
- Extract the Top 3 picker from `app/pages/categories/[id]/vote.vue` into a shared component that takes `looks`, an initial ballot and a `save` callback. Members and guests then share it. For guests there is no "own look" restriction.
- New guest pages with a minimal layout (no `AppNav`, nothing else to navigate to), reusing the existing look gallery, jury looks and `TopThreeReveal`.
- Admin: an "Invitar a un invitado" action on `app/pages/admin/categories/[id].vue` using `<AppModal>`, with a duration selector (e.g. 2, 4 or 6 hours), a copy-link step, and a list with revoke.
- All user-facing copy in Spanish, in the central strings place.
- Realtime: `useCategoriesRealtime` needs a Supabase JWT, which guests do not have. The guest page should poll a lightweight status endpoint (or re-fetch on focus) so it notices `voting` and `reveal` transitions.
- Regenerate `app/types/database.types.ts` after the migration.

## Implementation order

1. Migration: `guest_invitations`, `votes` changes, privileges and RLS. Regenerate types.
2. Server utilities: service-role client, token generate/hash, invitation validation (`not revoked`, `not expired`, category status).
3. Guest routes: redeem, category, ballot.
4. Extract the shared ballot picker component.
5. Guest pages.
6. Admin invitation management.
7. Tests/manual checks for the cases below.

## Cases to verify

- Expired, revoked and unknown tokens are rejected, including mid-session.
- A guest cannot read or vote on any category other than the invitation's.
- A guest cannot vote outside `voting`, cannot vote for looks of another category, and cannot send duplicate picks.
- A guest changing their vote updates the same ballot (no second row).
- Guest points appear in `category_top_three` and `category_ranking` with the same weight as members.
- The service-role key is absent from the client bundle.
- Images load for a guest (check whether the `runway-looks` bucket is public; if not, the server must return signed URLs).
- No member-facing or admin query reveals which invitation cast which ballot.
