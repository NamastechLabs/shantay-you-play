# Sub-categories

Status: **implemented** (DRG-14). Migration: `20261119000100_category_subcategories.sql`.

## Goal

The winner of the previous week sets sub-categories for the week's category and the admin enters them. While the runway is in the Werk Room each queen picks one, in ranking order. The picks reach the jury AI through `GET /api/commentary/runway` and the ZIP (`docs/runway-export.md`).

## Rules

| Topic | Rule |
|---|---|
| Where | Individual categories only. Group categories do not support sub-categories (trigger `enforce_individual_category`; a category with sub-categories cannot become a group one). |
| Optional | A category may have none. If it has any, the admin UI requires at least one per contestant (`role = 'concursante'`). This is checked in the UI, not in the database. |
| Order | `subcategory_turn_order(category_id)`: queens ranked in the previous week's runway (highest `week_number` below this one, status `closed`, using `runway_standings`) first, by place; the rest after them, alphabetically by drag name. |
| Pick | `pick_subcategory(subcategory_id)`: only in `werk_room`, only on her turn (the first queen in the order without a pick), once, and only a free sub-category. Picks cannot be inserted directly (no insert grant). |
| Admin | `assign_subcategory(subcategory_id, participant_id)` (judges, any status) replaces the queen's pick; it fails if another queen has that sub-category (free it first). Judges free a pick by deleting it. |
| Visibility | Readable from `werk_room` on (judges always): the list, who took what and the order. |

## Where

- Admin: `AdminCategorySubcategories.vue` ("Subcategorías" button of an individual category in `/admin/runways/[id]/categories`): edit the list, assign and free.
- Homepage (Werk Room): `CategorySubcategories.vue` (`#subcategorias-<category id>`).
  - While a queen has not picked (and the category has sub-categories) the week card hides the status text, the countdown and the "Ya tienes tu look, súbelo" button, so the picker is what she sees. On her turn she taps a free row and confirms right under it (no browser dialog, and modals are full screen on phones).
  - A queen still waiting sees how many queens pick before her; one who has picked sees her sub-category with the full list folded.
  - Taken rows show the queen's avatar and name. The pick order is behind "Orden de elección".
- `useCategorySubcategories` loads the data and refetches on realtime changes (`category_subcategories` and `category_subcategory_picks` are in the `supabase_realtime` publication with `replica identity full`).
- Werk Room page (`/semana/[week]/werk-room`): the queen's own sub-category is shown in her look card, between the photos and the intro (`LookEditRow` prop `subcategory`).
