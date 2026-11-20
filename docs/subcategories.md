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
| Visibility | Judges always see every sub-category and who took it. From `werk_room` on, a queen sees only the free sub-categories and her own: the ones other queens took are hidden (RLS on `category_subcategories` via `subcategory_visible_to_me`, and on `category_subcategory_picks`: own pick only). Everyone sees the pick order and who has already picked (`has_picked` of `subcategory_turn_order`), not what they took. Migration `20261120000000_hide_subcategory_picks.sql`. |

## Where

- Admin: `AdminCategorySubcategories.vue` ("Subcategorías" button of an individual category in `/admin/runways/[id]/categories`): edit the list, assign and free.
- Homepage (Werk Room): `CategorySubcategories.vue` (`#subcategorias-<category id>`).
  - While a queen has not picked (and the category has sub-categories) the week card hides the status text, the countdown and the "Ya tienes tu look, súbelo" button, so the picker is what she sees. On her turn she taps a free row and confirms right under it (no browser dialog, and modals are full screen on phones).
  - A queen still waiting sees how many queens pick before her; one who has picked sees only her sub-category.
  - Judges see taken rows with the queen's avatar and name. Queens never see what the others took: taken sub-categories disappear from their list, and once a queen has hers only her sub-category is shown. The pick order ("Orden de elección") only says who has already picked.
- `useCategorySubcategories` loads the data and refetches on realtime changes and every 8 s (queens cannot read other queens' picks, so realtime alone would not tell them whose turn it is; `category_subcategories` and `category_subcategory_picks` are in the `supabase_realtime` publication with `replica identity full`).
- Werk Room page (`/semana/[week]/werk-room`): the queen's own sub-category is shown in her look card, between the photos and the intro (`LookEditRow` prop `subcategory`).
