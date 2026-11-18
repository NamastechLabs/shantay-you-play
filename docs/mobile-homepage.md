# Mobile homepage and runway page

Status: **implemented** (DRG-13). Designs: Figma `drag-race-game`, frames "Homepage in … status" and "Runway page …" (390 px wide).

## Homepage (`app/pages/index.vue`)

- The week card has, from top to bottom: kicker, date, status badge, title, status text, the Werk Room countdown, the reveal blocks, the action buttons and, last, the category text (`RunwayCategories`). The jury ("El jurado en la pasarela") is a section **below** the card, not inside it.
- On phones (below 48rem) every action is a full-width button, one per row, primary first ("A desfilar", then "Ver la intro de la pasarela"; "Votar a las mejores reinas", then "Ver la pasarela").
- States: no open runway (`La pasarela está en pausa`), Werk Room, Pasarela, Votación and Reveal (Top 3 and band reveal; the category text is hidden on phones while it plays, as before).
- "La semana pasada" shows the winner's photo tall (3:4) with the place ribbon and the crown on phones (`PastRunwayCard` with `featured`).
- On phones the user menu in the top bar takes the width the logo leaves, and the **top bar is pinned** (`position: sticky`) on every page (`_nav.scss`). `--app-nav-height` (4rem on phones, 0 otherwise) is its height, used by whatever sticks under it.

## Werk Room countdown

While the week is in `werk_room`, the card counts down to the runway's `runway_date` (`useCountdown`, ticking once a second on the client only, so server and client markup match). Format (`formatCountdown` in `app/utils/runwayFormat.ts`):

| Time left | Example |
|---|---|
| more than 24 h | `2 días 03:04:05` (`1 día …` for one day) |
| more than 60 min | `03:04:05` |
| more than 1 min | `04:05` |
| otherwise | `05` |

At zero it shows "¡La pasarela está a punto de abrir!" until a jury member opens the runway (the realtime refresh then changes the card).

## Collapsible challenge text

`CollapsibleText` cuts the category text to 3 lines on phones and adds a full-width "Leer reto completo ↓" / "Leer menos ↑" button, shown **only when the text is actually cut**. From 48rem up the whole text is shown and there is no button. Used by `RunwayCategories` (homepage and runway page) and by the per-category intro on the runway page.

## Runway page (`app/pages/runways/[id]/index.vue`)

- The header stacks kicker, status badge and title; "Resultados" / "Votar a las mejores reinas" are full-width buttons on phones.
- With **several categories** and looks, phones get `CategoryTabs` right under the header buttons: a row of pill tabs that scrolls sideways, with a semi-transparent fade on each edge that has more tabs behind it. When it reaches the pinned top bar it sticks under it (`top: var(--app-nav-height)`). Tapping a tab scrolls to that category's section (`#category-<id>`, with `scroll-margin-top` for both bars); the active tab follows the scroll. It is hidden from 48rem up and on single-category runways. The page grid uses `minmax(0, 1fr)` so the tabs can never widen the page.

## Files

`app/pages/index.vue`, `app/pages/runways/[id]/index.vue`, `app/components/{CollapsibleText,CategoryTabs,RunwayCategories,PastRunwayCard}.vue`, `app/composables/useCountdown.ts`, `app/utils/runwayFormat.ts`, `app/assets/scss/components/_nav.scss`.

No migration.
