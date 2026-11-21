# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.17.0] - 2026-11-21

### Added

- Animated voting summary: when a runway moves to voting, the homepage plays a full-screen, video-style summary (title, the bands first when there is a group category, every queen and a closing card that sends people to vote). It starts by itself if the page is open and a **Ver el resumen de la votación** button replays it later. Built with motion-v from live data, themed through the CSS tokens, skippable, and static under reduced motion. No database changes (DRG-23)

## [0.16.1] - 2026-11-20

### Changed

- On phones the admin pages use smaller type, buttons, inputs and spacing on the 8px grid (DRG-22)
- On phones the admin weeks table shows each week as a stacked card, and the participants rows use the full width (DRG-22)
- On phones the runway status steps show in two columns instead of being cut off (DRG-22)
- On phones the category actions put Guardar full width first, with Subcategorías and a red Eliminar side by side below (DRG-22)
- The sub-categories drawer is compact on phones and each queen's pick is a full-width select (DRG-22)
- The profile page on phones has a smaller avatar beside its photo button and a full-width save button (DRG-22)

### Fixed

- On iPhone, tapping a week in the admin table always opened the first week; the whole row is now clickable without an overlay that iOS Safari stretched over the table (DRG-22)
- The admin categories tab no longer scrolls sideways on phones (DRG-22)

## [0.16.0] - 2026-11-20

### Added

- Snackbar for feedback messages: `<AppSnackbar>` and `useSnackbar()` show saved confirmations (e.g. "¡Voto guardado!") and action errors over the content, above the ballot bar on phones, instead of inline text that made the bar taller. Errors stay until dismissed and are announced to screen readers; field validation and page-level states stay inline. Admin actions with no visible result (runway details, status change, category and look saves, export, Top 3 reveal) also confirm with a success message (DRG-20)

## [0.15.1] - 2026-11-20

### Fixed

- On iPhone the winner's photo in the past-week card was painted over the week, title and winner text; the photo now takes its own height so the text stays below it

## [0.15.0] - 2026-11-20

### Changed

- Queens no longer see the sub-categories other queens already took: taken ones disappear from their list and they only see their own once they pick. Judges still see every sub-category and who took it. `subcategory_turn_order` now returns `has_picked`, and the homepage also refreshes every 8 s. Adds a migration: new RLS policies on `category_subcategories` and `category_subcategory_picks` and function `subcategory_visible_to_me`

## [0.14.1] - 2026-11-19

### Changed

- The Werk Room countdown on the homepage is now four flip-clock tiles (days, hours, minutes, seconds) instead of a line of text.

## [0.14.0] - 2026-11-19

### Added

- Sub-categories for individual categories: judges add them from the category ("Subcategorías", at least one per queen when there are any; group categories do not support them) and can assign or free the one of any queen. While the week is in the Werk Room each queen picks one of the remaining sub-categories on the homepage, in the order of the ranking of the previous week's runway (alphabetical by drag name for queens without a place). Each look has a `subcategory` and each category a `subcategories` list in the `GET /api/commentary/runway` response and in the ZIP `runway.json`. Adds a migration: tables `category_subcategories` and `category_subcategory_picks`, functions `subcategory_turn_order`, `pick_subcategory` and `assign_subcategory` (DRG-14)

## [0.13.0] - 2026-11-19

### Added

- Judges can promote a special guest to contestant from Participantes ("Pasar a concursante"), through the new judge-only function `promote_guest_to_contestant`. Only `invitado` → `concursante` is allowed. Her guest invitations (`runway_guests`), jury looks (`jury_looks`, kept as jury looks) and ballots are preserved; her old guest ballots stop being anonymous. Adds a migration (DRG-21)

### Fixed

- "Mis looks" now reads both `looks` and `jury_looks`, and splits them into "Como concursante" and "Como jurado o invitada especial" sections, so the jury looks of a special guest who became a queen are not hidden (DRG-21)

## [0.12.0] - 2026-11-19

### Added

- The app can be installed on the home screen of phones and tablets (PWA): web app manifest with name, icons (including a maskable one and an opaque Apple touch icon) and standalone display, a service worker that only caches the static build files, fonts and icons (pages, Supabase and `/api` always use the network and the theme cookie still renders on the server), automatic updates after each deploy and a Spanish offline page. An "Instalar app" item in the user menus opens the browser's install dialog on Android and Chrome, or the Share steps on iPhone and iPad, and is hidden when the app is already installed. The browser bar color follows the active theme. The help page has a new "Instala la app en tu móvil" section. No migration. Uses `@vite-pwa/nuxt` with the `buildSW` strategy (DRG-18)

### Changed

- Vote page on phones: the kicker ("Semana N · título") has the full width on its own row, with the title and "Ver la pasarela" below it, and the ballot button shows a send icon and "Enviar" instead of "Votar" / "Actualizar", which did not fit (DRG-18)

## [0.11.0] - 2026-11-18

### Changed

- Mobile redesign of the homepage: kicker, date and status badge on separate lines, full-width stacked buttons, the category text after the buttons, the jury below the week card, and a tall winner photo with ribbon and crown in "La semana pasada". On phones the top bar stays pinned to the top on every page. No migration (DRG-13)
- On phones the category challenge text is cut to 3 lines with an inline "… Leer reto completo" link after the ellipsis, on the homepage and on the runway page. The look and jury intros of the runway page end in "… Ver más" (the card opens the full look). The runway page header stacks its status and full-width buttons (DRG-13)
- The release notes page shows the latest 3 versions and keeps the rest under "Versiones anteriores"; versions have a pill badge, the newest a "Nueva" badge, each feature a marker, and there is a sticky row of versions on phones and tablets and a side list on desktop (DRG-13)
- The band voting explanation (`/band-voting`) on phones: a "Tu parte" line by role, the four phases as cards that slide sideways, the example as a card per queen instead of a wide table, the calculation one step per line, formula chips as rounded rectangles, the comparison with the original simulation folded, a sticky row of sections and a "Volver arriba" button; the first mention of the Javis says they are the jury (DRG-13)
- The help page opens with a "Para ti" summary for the reader's role, marks the stages they take part in, has a sticky row of sections on phones and tablets, shows the stage icon next to the title on phones and folds its three longest blocks behind a button on phones (DRG-13)
- A "Volver arriba" button appears on the help and release notes pages on phones and tablets (DRG-13)
- The release notes page moved from `/novedades` to `/release-notes` and the band voting explanation from `/votacion-bandas` to `/band-voting`; the old paths redirect and the page texts stay in Spanish (DRG-13)
- On phones and small tablets (below 48rem) the user menu is split in two panels: the user's avatar (top right) opens, from the right, the user menu (name, "Mi perfil", "Mis looks", "Salir"), and the burger button (top left) opens, from the left, the app menu ("Panel del jurado" and "Participantes" for the jury, "Semanas pasadas", "Ayuda", "Novedades" and the theme picker). Wider screens keep one dropdown with both menus; `AppDrawer` gained `side` and `narrow` options (DRG-13)
- The homepage says whether you already voted while the week is in Votación (a "✓ Votado" or "Pendiente" pill and a matching sentence), and the challenge text is only shown in the Werk Room and the Pasarela (DRG-13)
- The vote page on phones: two queens per row (only the first look, with a "+N" when there are more), a magnifier on each card opens the full look without picking her, your own queen is a thin row, the ballot bar is one short row with a photo and the rank of each pick next to the button, "Ver la pasarela" is a small button on the title line, the button reads "Votar" or "Actualizar" and the instructions are cut after the first sentence with a "Leer más" link (DRG-13)
- The public runway page on phones: two queens per row with the photo and the name only (the intro is in the look dialog), a "✓ Votado" or "Pendiente" pill and "Cambiar mi Top 3" while voting is open, the vote button repeated at the end, a "Volver arriba" button, and the date without the hour (DRG-13)
- On the homepage "La semana pasada" only shows while the week is in the Werk Room (or there is no week), the date and time of the week are only shown in the Werk Room, the jury looks slide sideways on phones as small cards with the photo and the name (the intro is in the look dialog), and photos show the brand "S" on a tinted card while they load (DRG-13)
- From tablet width up, the date and the status badge share a row on the homepage and the runway page (DRG-13)
- The Retro Glam kicker and link colour is darker, to reach the 4.5:1 text contrast (DRG-13)

### Added

- A countdown to the runway's date on the homepage while the week is in the Werk Room (`2 días 03:04:05`, then `03:04:05`, `04:05` and `05`) (DRG-13)
- Category tabs on phones for runways with several categories, under the header buttons: they scroll sideways with a fade on the edges that hide more tabs, stick under the pinned top bar, and tapping one scrolls to it while the active one follows the scroll (DRG-13)

## [0.10.0] - 2026-11-17

### Added

- "Mis looks" now shows the looks and intros of jury members and special guests (read from `jury_looks`, without a place or points). No migration (DRG-11)

## [0.9.0] - 2026-11-17

### Changed

- On phones, the `Ver resultados` modal of a group category shows the final ranking as a card per queen (with avatar) instead of a wide table (DRG-3)

### Added

- A `Resultados` button on the public page of a closed runway without a group category opens a dialog with a cross table of the Top 3 votes (voters in rows, queens in columns, with avatars and total points; a card per voter on phones); special guests' ballots stay anonymous. No migration: it reads `votes`, already readable by everyone once the runway is closed (DRG-3)

## [0.8.1] - 2026-11-17

### Changed

- A runway can no longer mix a group category with other categories: with a group category the new category button is disabled, and a category cannot be saved as grupal while the runway has other categories, with a warning to remove them first (DRG-10)

## [0.8.0] - 2026-11-17

### Changed

- The admin runway Looks tab now follows the runway stage: from Pasarela on, the queens' looks are read-only (with `Editar` while they can still change); in Werk Room they are hidden behind an icon card in each uploaded photo slot, with `Ver los looks` and `Editar` buttons. The Grupos tab works the same way (`Ver las fotos`), with the photos or cards in a 2x2 grid. The Jurados tab also lists the special guests invited to the week (DRG-4)

## [0.7.1] - 2026-11-17

### Changed

- The admin runway page no longer lets a runway move from Werk Room to Pasarela while a group of a group category has no photo, and says which groups are missing one (DRG-9)

## [0.7.0] - 2026-11-15

### Changed

- In a runway with a group category the Top 3 of the week now counts in the final ranking and there is a single absolute winner: `total = 0.5 × group score + 0.5 × Top 3 score`, where the Top 3 score is the queen's points ÷ (3 × ballots actually cast). The podium of the reveal and the closed ranking come from that same ranking, and the results table and the `/votacion-bandas` help gain a "Top 3" column. Runways without a group category are unchanged. Requires migration `20261115000100_group_ranking_includes_top3.sql`

## [0.6.0] - 2026-11-15

### Added

- `GET /api/commentary/runway` and the week ZIP now include each category's `type` (`individual` or `group`) and, for group categories, its `groups` (name, intro, photos and member drag names) plus the `group` of every queen's look. In the ZIP the group photos go to `<category>/grupos/`. Requires migration `20261115000000_service_role_read_groups.sql`

### Changed

- Navigation logo, favicon and app icons updated with a crown

## [0.5.1] - 2026-11-15

### Changed

- Look photo slots are now labelled "Foto 1" to "Foto 4" (formerly Frente, Espalda, Reveal and Extra), like the group photos, in the app, the shared file names (`01-foto-1-…`), the ZIP export and the commentary endpoint; the copy that mentioned "frente" now says the first photo is required

### Fixed

- Photos uploaded from browsers that cannot encode WebP natively (Safari) were stored as JPEG; they are now encoded to WebP with a WASM encoder (new dependency `@jsquash/webp`), keeping JPEG only as a last resort

## [0.5.0] - 2026-11-14

### Added

- "Descargar ZIP de la semana" button in the week summary (`/admin/runways/[id]`): downloads `pasarela-semana-N.zip` with `runway.json` (same content as `GET /api/commentary/runway`, with the path of each photo inside the ZIP) and all the photos, one folder per category (`jury/` for the jury's looks). Built in the browser with the judge's session (new dependency `fflate`), for AI chats that cannot call the endpoint or download the images

## [0.4.0] - 2026-11-14

### Added

- Admin area to upload the weekly runway intro video: always stored as `intro.mp4` in the `runway-intro` bucket, overwriting the previous one; MP4, 9:16, max 50 MB. Requires migration `20261114000200_runway_intro_select_policy.sql` (DRG-6)

### Changed

- Admin home redesign: "Semanas" and "Vídeo de intro" tabs, a weeks table with clickable rows, and a two-column intro video card. Tabs everywhere now use an underline style instead of pills (DRG-6)

## [0.3.2] - 2026-11-14

### Changed

- All pages share the same content width (82rem, formerly 60rem with a `page--wide` modifier on three pages).
- The help page has a two-column layout with a sticky outline of its sections in a left aside (a wrapped list of chips above the content on small screens) that highlights the section being read.
- New "Shantay You Play" logo (pink lettering with a crown, transparent background) in the navigation bar, and a matching crowned "S" favicon and app icons.

## [0.3.1] - 2026-11-14

### Changed

- The vote page no longer asks the jury for a Top 3 when the group category is the only category of the runway: voting the band and ordering the queens is enough. Contestants still vote their Top 3 (DRG-8)
- Group results table: the Regalo column comes before Fase 2, has an info icon explaining it, and the Puesto header is left-aligned (DRG-8)

## [0.3.0] - 2026-11-14

### Added

- Group categories are decided by ranking votes: each queen ranks all the queens of the rival band and each judge ranks all the contestants, with complete ballots submitted through `submit_ranking_ballot`. The final ranking from `category_ranking_result` averages both votes (50/50, normalized so bands of different sizes are comparable) and adds a 0.2 bonus for the band that won the judges' band vote, shown with 3 decimals on the results screen. In the reveal, a runway with a group category first reveals the winning band (same roulette and confetti effect as the Top 3; a draw shows both) and a judge-only button then reveals the Top 3 of the week for everyone, while the winning band slides down below it and takes the full width. The Top 3 and the group ranking stay hidden in the database until then (new `runways.top_three_revealed`, `reveal_runway_top_three`, `runway_results_visible`; requires migration `20261114000100_runway_reveal_stage.sql`). The vote page guides voters through a stepper with free navigation (jury: best band, order of the queens, Top 3 pre-filled from that order; contestants: order of the rival band, Top 3). New help page `/votacion-bandas` explains it with a worked example, linked from the voting and results screens and from the help page. Requires migration `20261114000000_group_ranking_votes.sql` (DRG-8)
- Release notes page at `/novedades` (link "Novedades" in the user menu) with the date and the functional features of each release, from `app/utils/releaseNotes.ts`
- Groups have an intro text, edited by their members from the "Ver grupo" modal in the Werk Room. Requires migration `20261113000000_group_intro.sql`

### Changed

- Queens in a group category get a second button next to "A desfilar" on the homepage while the week is on the runway, "A desfilar con mi banda", which shares the band's name, intro and photos like the look; the jury does not see it (DRG-8)
- On the public runway page, the results of a group category open in a modal from a "Ver resultados" button at the top (instead of showing the table first), the group photos have a "Los grupos" heading, the winning band's photo gets the crown badge like the winning look, and the homepage offers "Ver la pasarela" once the reveal has finished (DRG-8)
- Group photos on the runway and voting pages show the first photo with a photo counter and open all of them in the look dialog when clicked, like the looks (DRG-8)
- Group category voting no longer uses the Top 1 queen vote (`category_queen_votes` and `category_queen_result` stay as legacy and are not migrated); the voting screen now asks for complete rankings (DRG-8)
- Release process: definition of done (docs and help in the same PR), a `release` skill, a pull request template, release notes for every version and the date of the planned merge for the release (CLAUDE.md, `.claude/skills`, `.github`)
- Help page, README and `docs/group-categories.md` describe group categories and group photos

## [0.2.0] - 2026-11-13

### Added

- Group categories: a category can be individual (default) or group, with two groups of queens assigned by the jury from an "Editar grupos" side panel in the admin. Queens see a "Categoría grupal" badge and their teammates' looks in the Werk Room. In voting, only the jury votes for the winning group (a draw makes both win), and each queen votes a Top 1 among the rival group's queens, giving a group winner plus a Top 1 queen. Results appear from the reveal. Each group also has up to 4 landscape photos (16:9 or 5:3) shown together as one picture: members upload them from "Ver grupo" in the Werk Room, judges manage them in a new "Grupos" tab of the admin looks, and they appear on the runway and voting pages. Requires migrations `20261111000000_group_categories.sql` and `20261111000100_group_photos.sql` (DRG-5)

## [0.1.2] - 2026-11-09

### Changed

- App name changed from "Drag Race Game" to "Shantay You Play" in titles, headings, meta tags, help copy and docs, through a single `APP_NAME` constant (`app/utils/brand.ts`). The logo image is unchanged for now

## [0.1.1] - 2026-11-09

### Added

- Themed error page (`app/error.vue`) in Spanish for 403, 404 and unexpected errors (DRG-1)

### Changed

- Project (package and repository) renamed to `shantay-you-play`

### Fixed

- The public runway page answers 403 with a drag-themed message until the runway reaches voting, reveal or closed, for everyone including the jury (DRG-1)
- Looks and jury looks are no longer readable through the API by other participants during the Pasarela stage (RLS migration `20261109000000_looks_hidden_until_voting`) (DRG-1)
