# Claude Code Guidelines & Postgres Architecture

## Project Stack

- **Framework:** Nuxt 4 (Node.js)
- **Database:** PostgreSQL (Supabase / Remote Postgres)
- **ORM / Client:** Supabase JS Client

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
