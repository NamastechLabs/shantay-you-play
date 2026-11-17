# My looks page (DRG-11)

`/my-looks` (`app/pages/my-looks.vue`) lists the signed-in participant's own looks, newest week first, with a gallery dialog for every photo and the intro.

- **Queens** (`concursante`): read from `looks`, with their place and points once the runway reaches `reveal` (Top 3) or `closed` (full ranking, via `runway_top_three` / `runway_ranking`).
- **Jury and special guests** (`jurado`, `invitado`): read from `jury_looks` (filtered by `participant_id`). They are never ranked, so no place or points are shown, and the card only links to the runway.

Each card links to its runway. The empty state differs by role.

No database change: the existing `jury_looks_select` RLS policy already lets a judge or guest read their own rows.

## Guests and the invitation window

A guest only reads a runway (and their own `jury_looks` rows in it) while their invitation is active, until midnight (Europe/Madrid) at the end of the runway day (`is_active_runway_guest`). After that, the looks of that week no longer appear in "Mis looks" for the guest. Inviting them to the runway again restores access. Judges are not affected.
