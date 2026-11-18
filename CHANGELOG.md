# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- Mobile redesign of the homepage: kicker, date and status badge on separate lines, full-width stacked buttons, the category text after the buttons, the jury below the week card, a tall winner photo with ribbon and crown in "La semana pasada" and a wider user menu in the top bar. On phones the top bar stays pinned to the top on every page. No migration (DRG-13)
- On phones the category challenge text is cut to 3 lines with a "Leer reto completo" button, on the homepage and on the runway page. The runway page header stacks its status and full-width buttons (DRG-13)

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
