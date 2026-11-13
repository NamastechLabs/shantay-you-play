# Group categories

Status: **implemented** (DRG-5, released in 0.2.0). Migrations: `20261111000000_group_categories.sql` and `20261111000100_group_photos.sql`.

## Goal

Some weeks have a category that is played by teams. The queens are spread in two groups that compete collectively, on top of the usual runway Top 3.

## Rules

| Topic | Rule |
|---|---|
| Category type | `categories.kind`: `individual` (default) or `group`. |
| Groups | A group category has exactly two groups (position 1 and 2). Judges name them and assign `concursante`s; a queen is in one group per category. |
| Group vote | Only judges vote, one group each. The group(s) with the most votes win; **on a draw both groups win**. |
| Queen vote | Each queen votes **one** Top 1 among the queens of the **rival** group. The most voted queen(s) win; on a tie they share the win. |
| Results | A group winner plus a Top 1 queen per group category. Public from `reveal`; individual ballots stay private until `closed`. |
| Runway Top 3 | Unchanged. Group votes are separate tables and do not add points. |

A group category cannot go back to `individual` while it has groups (trigger `protect_category_kind`).

## Group photos

Each group has up to 4 landscape photos (**16:9 or 5:3**, with a 3% tolerance) shown together as one picture.

- Stored in the `runway-looks` bucket at `{category_id}/{group_id}/{uuid}.webp`, row in `category_group_photos` (one row per group, four nullable URL columns).
- Members of the group upload and replace them while the runway is in `werk_room`; judges until voting opens (`draft`, `werk_room`, `runway`).
- Visibility follows the looks: the group's members and judges see them while preparing, everyone else from `voting`.
- The ratio is checked in the browser (`assertGroupPhotoRatio` in `app/utils/groupPhotos.ts`) before compressing; the database does not enforce it.
- Deleting the groups or the category removes the files from Storage (`useParticipantFiles`).

## Schema

- `categories.kind` (`category_kind` enum).
- `category_groups`: `category_id`, `position` (1 or 2), `name`. Only allowed on group categories (trigger `enforce_group_category`).
- `category_group_members`: `category_id`, `group_id`, `participant_id`, unique per category and participant. Only `concursante`s.
- `category_group_votes` (jury) and `category_queen_votes` (queens): one ballot per voter and category, editable while `voting`.
- `category_group_photos`: see above.
- Helpers (`SECURITY DEFINER`): `participant_group_id`, `are_teammates`, `are_rivals`.
- Results: `category_group_result(category_id)` and `category_queen_result(category_id)`, empty before `reveal`.
- `looks_select` also lets teammates read each other's looks during `werk_room`.

## Where it lives in the app

| Area | Files |
|---|---|
| Admin: type selector | `app/pages/admin/runways/[id]/categories.vue` |
| Admin: groups side panel | `app/components/AdminCategoryGroups.vue`, `app/components/AppDrawer.vue` |
| Admin: "Grupos" tab (photos) | `app/pages/admin/runways/[id]/looks.vue`, `app/components/GroupPhotosEditor.vue` |
| Werk Room: badge, "Ver grupo", teammates' looks | `app/pages/semana/[week]/werk-room.vue` |
| Voting | `app/components/GroupCategoryVote.vue`, used by `app/pages/runways/[id]/vote.vue` |
| Results | `app/components/GroupCategoryResult.vue`, used by `app/pages/runways/[id]/index.vue` |
| Photos on runway and voting pages | `app/components/CategoryGroupPhotos.vue`, `app/components/GroupPhotosCollage.vue` |
| Upload logic | `app/composables/useGroupPhotos.ts`, `app/utils/groupPhotos.ts` |
| Look viewer (shared with the look dialog) | `app/components/LookGallery.vue` |

## Known limitations

- Saving the groups side panel runs several calls in a row, not one transaction; if it fails halfway, the panel reloads what was stored and shows the error.
- Database errors raised by the triggers (e.g. making a category individual while it has groups) are shown in English.
