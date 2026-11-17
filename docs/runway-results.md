# Runway results: who voted for whom

Status: **implemented** (DRG-3).

## Goal

Once a runway is `closed`, any member can see how each person voted in the Top 3 of the week.

## Behaviour

- The public runway page (`/runways/[id]`) shows a **Resultados** button in the header actions when `runway.status === 'closed'` and the runway has **no group category**. Runways with a group category keep their own "Ver resultados" (`GroupCategoryResult`, band ranking), which is unchanged.
- The button opens an `<AppModal>` with a **cross table**: a row per voter (queen or judge, with avatar, sorted by name) and a column per queen who got at least one vote (avatar and drag name, sorted by points). Each cell shows the place the voter gave (1 to 3, the Top 1 highlighted) or a dot. A footer row adds up the points (Top 1 = 3, Top 2 = 2, Top 3 = 1). The voter column is sticky and the table scrolls sideways if it is wider than the dialog.
- **Phones** (below 48rem) show a card per voter instead, with her Top 1, Top 2 and Top 3 (avatar and name). Both views are rendered and CSS shows one of them.
- Ballots are loaded the first time the dialog opens (`useRunwayBallots.loadBallots`): `votes` by `runway_id`, then the names and avatars from `participants` (explicit columns).

## Why one button per runway, not per category

The Top 3 ballot (`votes`) is stored **per runway**, with `top_1/2/3_participant_id`; there is no ballot per category. A button per category would show the same data, so the page has a single button, shown also when the runway has only one category.

## Data and privacy

No migration. The RLS policy `votes_select` already returns everyone's ballots once the runway is `closed`. **Special guests' ballots are never returned** (anonymous by design, see `20261107000100_runway_guests.sql`), so the dialog only lists non-guest voters and says so.

## Files

- `app/composables/useRunwayBallots.ts`
- `app/components/RunwayBallotsResults.vue`
- `app/pages/runways/[id]/index.vue`
