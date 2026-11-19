# Mobile homepage and runway page

Status: **implemented** (DRG-13). Designs: Figma `drag-race-game`, frames "Homepage in … status" and "Runway page …" (390 px wide).

## Homepage (`app/pages/index.vue`)

- The week card has, from top to bottom: kicker, date, status badge, title, status text, the Werk Room countdown, the reveal blocks, the action buttons and, last, the category text (`RunwayCategories`). The jury ("El jurado en la pasarela") is a section **below** the card, not inside it.
- From 48rem up the kicker has its own line and the date and the status badge share the next one (the runway page header does the same).
- On phones (below 48rem) every action is a full-width button, one per row, primary first ("A desfilar", then "Ver la intro de la pasarela"; "Votar a las mejores reinas", then "Ver la pasarela").
- States: no open runway (`La pasarela está en pausa`), Werk Room, Pasarela, Votación and Reveal (Top 3 and band reveal; the category text is hidden on phones while it plays, as before).
- While the week is in Votación the status line starts with a "✓ Votado" or "Pendiente" pill (from `votedRunwayIds`) and says whether the ballot can be changed. The category text (`RunwayCategories`) is only shown in the Werk Room and the Pasarela.
- "La semana pasada" only shows while the week is in the Werk Room (or there is no open week); from the runway on it is hidden and not even loaded. The date and time of the week are shown only in the Werk Room (they are the countdown's target), later only "Semana N".
- The jury looks (`JuryLooks`) slide sideways on phones as small cards (about two and a bit in view), photo on top and only the name below (the intro is in the look dialog, one tap away); from 48rem up they are a grid with the photo on the left.
- While a look, jury or winner photo loads, the card shows the brand "S" (`/icon-192.png`) on a tinted background; it is the `background` of the `<img>`, so the opaque photo simply covers it (no script).
- "La semana pasada" shows the winner's photo tall (3:4) with the place ribbon and the crown on phones (`PastRunwayCard` with `featured`).
- Below 48rem the menu is split in two `AppDrawer` panels: the **user's avatar** (top right, or their initial) opens the **user menu** from the right (the user's name, "Mi perfil", "Mis looks", "Salir"; `userItems` in `AppNav.vue`) and the **burger button** (top left, next to the logo) opens the **app menu** from the left ("Panel del jurado" and "Participantes" for the jury, "Semanas pasadas", "Ayuda", "Novedades" and the theme picker; `appItems`). Links and "Salir" close the panel; Escape and a tap on the backdrop do too. From 48rem up one dropdown with the user's name holds both lists (separated), and the theme picker is in the top bar. The **top bar is pinned**

## Werk Room countdown

While the week is in `werk_room`, the card counts down to the runway's `runway_date` (`useCountdown`, ticking once a second on the client only, so server and client markup match). Format (`formatCountdown` in `app/utils/runwayFormat.ts`):

| Time left | Example |
|---|---|
| more than 24 h | `2 días 03:04:05` (`1 día …` for one day) |
| more than 60 min | `03:04:05` |
| more than 1 min | `04:05` |
| otherwise | `05` |

At zero it shows "¡La pasarela está a punto de abrir!" until a jury member opens the runway (the realtime refresh then changes the card).

## Collapsible text

`CollapsibleText` cuts a text to a number of lines and puts a link **right after the ellipsis**, at the end of the last line ("… Leer reto completo"). It measures where to cut (binary search on a hidden copy of the text, never in the middle of a word), so it works on any background; before it is measured (server render) a plain CSS clamp is used. It re-measures when the width changes.

- **Challenge text** (`RunwayCategories` on the homepage and the runway page, and the category intro on the runway page): cut to 3 lines on phones only, link "Leer reto completo" that expands the text ("Leer menos" collapses it). From 48rem up the whole text is shown.
- **Texts inside a clickable card** (`inert`: a look card's intro on the runway page, cut to 2 lines, and a jury member's intro, cut to 5 lines; at every width): the link is only a hint, "… Ver más", because a link inside a button is invalid; tapping the card opens the full look in the dialog.

## Runway page (`app/pages/runways/[id]/index.vue`)

- The header stacks kicker, status badge and title; "Resultados" / "Votar a las mejores reinas" are full-width buttons on phones.
- With **several categories** and looks, phones get `SectionTabs` (id prefix `category-`) right under the header buttons: a row of pill tabs that scrolls sideways, with a semi-transparent fade on each edge that has more tabs behind it. The fades carry a small arrow (‹ ›, hidden from screen readers). When it reaches the pinned top bar it sticks under it (`top: var(--app-nav-height)`, same surface colour as the bar). Tapping a tab scrolls to that category's section (`#category-<id>`, below both bars thanks to `scroll-padding-top`) and moves focus to its heading; the active tab follows the scroll. It is hidden from 48rem up and on single-category runways. The page grid uses `minmax(0, 1fr)` so the tabs can never widen the page.

## Public runway page (`/runways/[id]`)

- On phones the queens are **two per row** (`runway-gallery`): photo, rank ribbon / winner crown and name; the intro text is hidden there because the look dialog (tap a card) shows it in full. From 48rem up the cards keep the intro with "… Ver más".
- While voting is open the header shows a "✓ Votado" or "Pendiente" pill next to the status (the person's own ballot is read from `votes`, which RLS only returns to its owner) and the button reads "Cambiar mi Top 3" or "Votar a las mejores reinas". The same button is repeated at the end of the page.
- The kicker shows the day (`formatRunwayLongDate`), not the hour. `BackToTop` is on this page too.

## Vote page (`/runways/[id]/vote`)

- On phones the queens are **two per row** (`vote-gallery`); a queen with several looks shows the first one with a "+N" badge. A **magnifier button** on each card (a sibling of the card button, never nested in it) opens `LookGalleryDialog` with all her photos and intro without changing the ballot; with several looks, the arrows step through them. Your own queen is a thin row ("eres tú, no puedes votarte"); from 48rem up the full (disabled) card is kept.
- The **ballot bar** is one short row on phones: three small slots (photo and rank number, or the dashed rank number when empty) next to the button. The queen's name and "Top N" stay for screen readers. From 48rem up it keeps the three named boxes.
- On phones the kicker ("Semana N · título") has the full width on its own row, and the title and the small "Ver la pasarela" button share the row below; from 48rem up the kicker sits above the title with the button on the right. The save button reads "Votar" (first vote) or "Actualizar" from tablets up; on phones it shows a "send" icon and the short text "Enviar" (the real label stays for screen readers). The instructions show only their first sentence followed by "Leer más" on phones (`ReadMoreText`, done in CSS; from 48rem up the whole text). The ballot bar stays above the magnifier buttons (`z-index`).
- Looks selected for the page now include `image2_url`–`image4_url` and `intro` (same table, no migration).

## Long pages: Help and Release notes

Both pages are long (about 10,000 px for the help on a phone), so they share some pieces:

- **`SectionTabs`** (generalised from the runway's category tabs): sticky row of pill tabs with the sideways scroll fades. `until="phone"` (runway categories) or `until="desktop"` (help, release notes and band voting: shown up to 64rem, where the pages have a side list or are short). At the very bottom of the page the last tab becomes the active one. It emits `navigate` before scrolling so a page can open a collapsed block first. Sections inside something collapsed are never the active one.
- **`BackToTop`**: floating button after 800 px of scroll, below 64rem.
- **`useActiveSection`**: which section is being read, for the side lists (IntersectionObserver).

**Help (`/help`)**
- A "Para ti" card by role (`HELP_COPY.forYou`: concursante, jurado, invitado) opens the page, and the stages the person takes part in (`HelpStage.roles`) carry a "Para ti" badge.
- On phones the icon of a stage card sits next to its title so the text uses the full width, and the three longest blocks (stages, group categories, security) are behind a "Ver…" button (`PhoneCollapse`, done in CSS so there is no layout jump; from 48rem up they are always shown).

**Release notes (`/release-notes`)**
- The latest 3 versions are open; the rest are behind "Versiones anteriores (N)" (`<details>`). Tapping an older version in the tabs or the side list, or arriving with `/release-notes#v0.2.0`, opens it first.
- Each card (`ReleaseNoteCard`) has the version as a pill, a "Nueva" badge on the newest, the date, and a ✦ marker per feature.
- From 64rem a sticky side list of versions (with the current one highlighted) replaces the tabs.

## Files

`app/pages/index.vue`, `app/pages/runways/[id]/index.vue`, `app/components/{CollapsibleText,SectionTabs,RunwayCategories,PastRunwayCard}.vue`, `app/composables/useCountdown.ts`, `app/utils/runwayFormat.ts`, `app/assets/scss/components/_nav.scss`, `app/components/{BackToTop,PhoneCollapse,ReleaseNoteCard}.vue`, `app/composables/useActiveSection.ts`, `app/pages/{help,release-notes}.vue`, `app/utils/helpContent.ts`.

No migration.
