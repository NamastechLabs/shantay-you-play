# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Groups have an intro text, edited by their members from the "Ver grupo" modal in the Werk Room. Requires migration `20261113000000_group_intro.sql`

### Changed

- Help page, README and `docs/group-categories.md` describe group categories and group photos

## [0.2.0] - 2026-11-11

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
