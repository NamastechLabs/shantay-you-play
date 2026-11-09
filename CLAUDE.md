# Claude Code Guidelines & Postgres Architecture

## Project Stack

- **Framework:** Nuxt 4 (Node.js)
- **Database:** PostgreSQL (Supabase / Remote Postgres)
- **ORM / Client:** Supabase JS Client
- **Styling:** Plain CSS via SCSS (`sass`). No Tailwind, no Nuxt UI.

## Language & Copy

- **The website is in Spanish.** All user-facing copy (headings, buttons, labels, placeholders, errors, empty states, badges, footer, meta tags) must be written in Spanish.
- The Figma designs use English placeholder copy. When implementing a design, translate every string to Spanish, **except the brand name "Drag Race Game", which stays as is** (never translate it).
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
- **Branches:** `feature/DRG-12-short-slug` (also `fix/`, `chore/`), created from an up-to-date `main`.
- **Commits & PR titles:** start with the key, in English: `DRG-12 Filter runways by week`.
- **Tickets:** titles in English; description and acceptance criteria may be in English or Spanish. Exact UI copy is given in Spanish.
- **Changelog:** `CHANGELOG.md` follows Keep a Changelog, in English, with an `Unreleased` section. Add an entry for every user-visible change, ending with the issue key.
- **Releases:** merging to `main` deploys, so the version is decided in the PR, never in a later commit on `main`. Use semantic versioning (patch = fix, minor = feature, major = breaking). The PR's last commit renames `Unreleased` to `## [X.Y.Z] - date` in `CHANGELOG.md`, adds a fresh `Unreleased` and sets `version` in `package.json`. After merging, tag the merge commit `vX.Y.Z`.
- **Migrations:** a PR that adds a migration under `supabase/migrations/` must say so, and the migration is applied to Supabase before the PR is merged.
- **When asked to work on a ticket** ("work on DRG-12"), use the `work-on-ticket` skill (`.claude/skills/work-on-ticket/`).
- **Never** push, open a PR, comment on a ticket or change its status without being asked.
