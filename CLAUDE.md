# Claude Code Guidelines & Postgres Architecture

## Project Stack

- **Framework:** Nuxt 4 (Node.js)
- **Database:** PostgreSQL (Supabase / Remote Postgres)
- **ORM / Client:** Supabase JS Client
- **Styling:** Plain CSS via SCSS (`sass`). No Tailwind, no Nuxt UI.

## Language & Copy

- **The website is in Spanish.** All user-facing copy (headings, buttons, labels, placeholders, errors, empty states, badges, footer, meta tags) must be written in Spanish.
- The Figma designs use English placeholder copy. When implementing a design, translate every string to Spanish, **except the brand name "Shantay You Play", which stays as is** (never translate it).
- Set `<html lang="es">`. Prefer a central place for strings (e.g. an i18n file or constants) over hardcoding text in components, so a future language is possible.
- Code, identifiers, CSS classes, database names and commit messages stay in English.
- Use a natural, neutral Spanish with the playful drag tone (e.g. "Pre-register" → "Preinscríbete", "Every look. Every queen." → "Cada look. Cada reina."). Use Spanish typographic conventions (¿…?, ¡…!).

## Design & Theming

- **Figma file:** `drag-race-game` — https://www.figma.com/design/c04WKHtm4bzVWADZjqQQT8
- **Default theme: Y2K camp** (`y2k-camp`): light lilac-ice page, bubblegum pink, aqua and yellow accents, Poppins, very rounded shapes. It is the `:root` fallback and the default cookie value.
- **Other themes** (implemented; the UI switches between all three with `<ThemeSwitcher>` and the `theme` cookie):
  - **Retro glam** (`retro-glam`): light and dusty: blush pink, sage mint, rose and champagne (inspired by the Natasha Denona Retro Glam palette); Playfair Display + DM Sans.
  - **Neon nightclub** (`neon-nightclub`): black background with neon magenta, orange, yellow, blue and purple (from a neon eyeshadow palette); Bungee + Inter.
- **Code layout:** theme values live in `app/assets/scss/tokens/_themes.scss` (one Sass map per theme, emitted as CSS custom properties). Shared classes (`.btn`, `.badge`, `.field`, `.card`, `.row`, `.modal`, `.stepper`) are in `app/assets/scss/components/`. Theme state lives in `app/utils/themes.ts` and `app/composables/useTheme.ts`. To add a theme: add a map, a `[data-theme]` block, and an entry in `THEMES` / `THEME_LABELS`.
- **UI pattern:** list screens keep their list and add a primary button that opens `<AppModal>` for create/edit; editing a runway (week) and its categories is its own screen (`/admin/runways/[id]`). Modals are bottom sheets on phones.
- **Brand heading and eyebrow colors** are separate tokens (`--color-title`, `--color-kicker`) because `--color-highlight`/`--color-accent` are not readable as text on every theme (e.g. yellow on the light Y2K page).
- **Theming architecture:**
  - Never hardcode colors, fonts, radii, shadows or spacing in components. Use semantic CSS custom properties (e.g. `--color-surface`, `--color-primary`, `--color-accent`, `--color-highlight`, `--font-display`, `--font-body`, `--radius-md`, `--shadow-card`, `--glow-primary`).
  - Each theme only redefines those variables, scoped by `[data-theme="retro-glam" | "neon-nightclub" | "y2k-camp"]` on `<html>`. Components must not know which theme is active.
  - Keep SCSS partials split: `tokens/` (per-theme variable sets), `base/`, `components/`.
  - In Figma, one `Theme` collection has one mode per theme (`Retro Glam`, `Neon Nightclub`, `Y2K Camp`), with semantic variable names matching the CSS (`color/primary` → `var(--color-primary)`). Raw palettes live in `Primitives`; spacing in `Spacing`. Screens in Figma are bound to `Theme` and currently show Retro Glam (the code default is Y2K Camp); switch a frame's mode to preview another theme.
  - Theme-specific decoration (sparkles, crowns, glow, chrome) should be driven by variables or a theme-scoped class, not by branching in component logic.
- Persist the user's theme choice (e.g. cookie / profile) and apply it server-side to avoid a flash of the wrong theme.

## Database & PostgreSQL Guidelines

- **Naming Conventions:** Use lowercase `snake_case` for all table names, columns, foreign keys, and constraints.
- **Data Types:**
  - Use `UUID` for primary keys (`gen_random_uuid()`).
  - Use `TIMESTAMPTZ` for all date/time fields.
  - Use `JSONB` sparingly, only for non-relational or highly dynamic payload data.
- **Integrity & Indexes:** Always define explicit foreign key constraints, `NOT NULL` rules, and indexes on foreign keys or frequently queried columns.
- **Security & Queries:**
  - Write parameterized queries to prevent SQL Injection.
  - Never use `SELECT *` in production code; select explicit columns.
  - Use multi-step operations wrapped inside database transactions (`BEGIN ... COMMIT`).
  - Implement Row Level Security (RLS) policies where applicable.

## Coding Style & Outputs

- Provide production-ready, clean TypeScript / SQL code.
- Keep responses concise and focused on the code changes.
- When modifying schemas, highlight the diff or provide the complete updated file if short.

## Jira & Git Workflow

- **Jira project key:** `DRG` (issue keys look like `DRG-12`). The repo is linked to Jira, so the key must appear in branch names, commits and PR titles for the Development panel to pick them up (case-sensitive).
- **Branches:** only create a branch when working on a Jira ticket: `feature/DRG-12-short-slug` (also `fix/`), from an up-to-date `main`. Everything else (docs, skills, CLAUDE.md, chores, small tweaks) is done directly on `main`, with no branch. Never create a branch without a ticket key.
- **Review before committing:** never commit on your own, on a branch or on `main`. Leave the changes in the working tree, summarize them (`git status --short`, `git diff --stat`) and wait for the user to review and say to commit; they may want to change something first. This applies to every change, including docs, skills and CLAUDE.md, and to the release commit. Once they approve, commit following the rule below.
- **Commits & PR titles:** start with the key, in English: `DRG-12 Filter runways by week`. Commits made directly on `main` without a ticket have no key.
- **Tickets:** titles in English; description and acceptance criteria may be in English or Spanish. Exact UI copy is given in Spanish.
- **Changelog:** `CHANGELOG.md` follows Keep a Changelog, in English, with an `Unreleased` section. Add an entry for every user-visible change, ending with the issue key.
- **Definition of done:** a change is not ready for review until the table below is satisfied **in the same PR as the change**, never after merging. If a row does not apply, say `N/A: reason` in the PR (the PR template has the checklist).

  | If the PR... | It must also update |
  |---|---|
  | adds or changes a feature or a user flow | the technical docs (`docs/<feature>.md`, or the README for small things) **and** the in-app help (`app/utils/helpContent.ts`, `app/pages/help.vue`); fix any help text the change makes wrong |
  | changes the database | the migration, `app/types/database.types.ts` and the docs; the PR says it adds a migration |
  | has user-visible or developer-visible effect | an `Unreleased` line in `CHANGELOG.md`, ending with the issue key |
  | is the release (last commit) | `CHANGELOG.md` version, `package.json`, `app/utils/releaseNotes.ts` and the Jira fix version, through the `release` skill |

- **Releases:** merging to `main` deploys, so the version is decided in the PR, never in a later commit on `main`. Use semantic versioning (patch = fix, minor = feature, major = breaking). Releases are prepared with the `release` skill (`.claude/skills/release/`), which `work-on-ticket` also uses for its last commit. The release commit does all of this together:
  1. Renames `Unreleased` to `## [X.Y.Z] - date` in `CHANGELOG.md`, adds a fresh `Unreleased` and sets `version` in `package.json`. The date is the day the release is planned to be **merged**; if the merge happens another day, fix the date in `CHANGELOG.md` and `releaseNotes.ts` before merging.
  2. Adds the release to the in-app release notes (see below).
  3. Names the Jira fix version after the version (see below).

  After merging, tag the merge commit `vX.Y.Z`. Changes made directly on `main` (docs, skills, chores) that need a release go through a `chore/release-X.Y.Z` PR, never a version bump committed on `main`.
- **Jira fix version:** every release has a Jira version named exactly like the semantic version (`0.2.0`, no `v`), and every ticket shipped in it gets that fix version, so the Jira Releases view mirrors the changelog. The Atlassian MCP cannot create versions: ask the user to create the version in Jira (project `DRG` → Releases) if it does not exist, then set `fixVersions` on each ticket with `editJiraIssue`. Marking the version as released in Jira happens after the merge is deployed and is the user's call, like any other status change.
- **Release notes in the app:** users see what is new at `/novedades` (link "Novedades" in the user menu). The content lives in `app/utils/releaseNotes.ts`, newest first, and **contains every version**: one entry per release with the version, the date it went live (`YYYY-MM-DD`, equal to the changelog date), a short title and one sentence per **functional** feature users will notice (what they can now do, in Spanish, no technical terms). A release with nothing users can see still gets an entry, with the single feature `Mejoras y correcciones internas.`. Technical details stay in `CHANGELOG.md`.
- **Migrations:** a PR that adds a migration under `supabase/migrations/` must say so, and the migration is applied to Supabase before the PR is merged.
- **When asked to work on a ticket** ("work on DRG-12"), use the `work-on-ticket` skill (`.claude/skills/work-on-ticket/`).
- **Never** commit, push, open a PR, comment on a ticket or change its status without being asked.
