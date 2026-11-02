# Claude Code Guidelines & Postgres Architecture

## Project Stack

- **Framework:** Nuxt 4 (Node.js)
- **Database:** PostgreSQL (Supabase / Remote Postgres)
- **ORM / Client:** Supabase JS Client
- **Styling:** Plain CSS via SCSS (`sass`). No Tailwind, no Nuxt UI.

## Design & Theming

- **Figma file:** `drag-race-game` — https://www.figma.com/design/c04WKHtm4bzVWADZjqQQT8
- **Theme v1 (default): Retro-glam pageant.** Deep magenta, gold and cream, with sparkle and crown motifs. Classic and glamorous.
- **Planned alternative themes** (the UI must be able to switch between all three):
  - **Neon nightclub:** near-black background, hot pink and electric purple glow, spotlight runway feel.
  - **Y2K camp:** chrome, glitter, bubblegum gradients, bold sticker-style shapes.
- **Theming architecture:**
  - Never hardcode colors, fonts, radii, shadows or spacing in components. Use semantic CSS custom properties (e.g. `--color-surface`, `--color-primary`, `--color-accent`, `--color-highlight`, `--font-display`, `--font-body`, `--radius-md`, `--shadow-glow`).
  - Each theme only redefines those variables, scoped by `[data-theme="retro-glam" | "neon-nightclub" | "y2k-camp"]` on `<html>`. Components must not know which theme is active.
  - Keep SCSS partials split: `tokens/` (per-theme variable sets), `base/`, `components/`.
  - In Figma, mirror this with one variable collection and one mode per theme, using the same semantic variable names as the CSS.
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
