# Drag Race Game

A Drag Race–style weekly competition for a group of friends. Judges (*jurado*) publish a weekly category and upload each contestant's runway look; then everyone votes for their Top 3.

**Stack:** Nuxt 4 (TypeScript) · Supabase (Postgres, Auth, Storage) · `@nuxtjs/supabase` · Google OAuth · pnpm

---

## Requirements

| Tool | Version | Notes |
|---|---|---|
| Node.js | **24.15.0+** (LTS) | Enforced by `engines` in `package.json` + `engine-strict` in `.npmrc`. `.nvmrc` pins `24.15.0` (`nvm use`). Check with `node -v`. |
| pnpm | **9.15.9** | Pinned in `package.json` → `packageManager`. Run `corepack enable` and Corepack will pick the right version automatically. |
| Supabase account | — | https://supabase.com (free tier is enough) |
| Google Cloud account | — | For the OAuth client used by "Entrar con Google" |

The Supabase CLI does not need a global install; it runs through `pnpm dlx supabase …`.

---

## Quick start

```bash
git clone https://github.com/clorcar/drag-race-game.git
cd drag-race-game
corepack enable          # once per machine, makes pnpm available at the pinned version
pnpm install
cp .env.example .env     # then fill in the values (see below)
pnpm dev                 # http://localhost:3000
```

Before the app works end to end you need to complete the three setup steps below: **Supabase project → migrations → Google OAuth**.

### Scripts

| Command | What it does |
|---|---|
| `pnpm dev` | Start the dev server on http://localhost:3000 |
| `pnpm build` | Production build (`.output/`) |
| `pnpm preview` | Serve the production build locally |
| `pnpm typecheck` | Type-check the whole project with `vue-tsc` |

---

## 1. Supabase project

1. Create a project at https://supabase.com/dashboard. Save the **database password**; the CLI asks for it when pushing migrations.
2. Go to **Project Settings → API Keys** (or **Data API**) and copy:
   - the **Project URL** (`https://<project-ref>.supabase.co`)
   - the **publishable / anon** key (never the secret / `service_role` key)
3. Put them in `.env`:

   ```dotenv
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_KEY=<publishable-or-anon-key>
   ```

`.env` is git-ignored. Never commit real keys.

---

## 2. Database migrations

All schema changes live in [`supabase/migrations/`](supabase/migrations) and are applied in timestamp order:

| Migration | Contents |
|---|---|
| `20261101000000_init_schema.sql` | `participants`, `categories`, `looks`, `votes`, enums, indexes, triggers, RLS policies, auto-create profile on sign-up |
| `20261101000100_storage_runway_looks.sql` | Public `runway-looks` storage bucket + judge-only upload policies |
| `20261101000200_grant_table_privileges.sql` | Explicit table `GRANT`s for the `authenticated` role |
| `20261101000300_add_participants_drag_name.sql` | `participants.drag_name` (unique, case-insensitive) |
| `20261102000000_participants_preregistration.sql` | `participants.user_id`: judges pre-register people by email and the first Google sign-in links to them; ownership rules now go through `current_participant_id()` |

### Apply them with the Supabase CLI (recommended)

```bash
pnpm dlx supabase login                              # opens the browser once
pnpm dlx supabase link --project-ref <project-ref>   # the xxxx in https://xxxx.supabase.co
pnpm dlx supabase db push --dry-run                  # preview what will run
pnpm dlx supabase db push                            # apply (asks for the DB password)
```

The CLI records applied migrations, so `db push` only runs new ones.

### Alternative: SQL Editor

Paste each file, **in order**, into **Dashboard → SQL Editor → New query** and run it. If you later switch to the CLI, mark them as applied so they aren't run twice:

```bash
pnpm dlx supabase migration repair --status applied 20261101000000 20261101000100 20261101000200 20261101000300
```

### Creating a new migration

```bash
pnpm dlx supabase migration new <short_description>   # creates supabase/migrations/<timestamp>_<short_description>.sql
# write the SQL, then:
pnpm dlx supabase db push
```

Conventions (see [CLAUDE.md](CLAUDE.md)): lowercase `snake_case`, `uuid` PKs with `gen_random_uuid()`, `timestamptz`, explicit FKs and indexes, RLS on every table, and an explicit `GRANT` for any new table (this project does **not** auto-grant tables to `anon`/`authenticated`).

### Regenerate TypeScript types

After any schema change, regenerate [`app/types/database.types.ts`](app/types/database.types.ts) so queries stay type-safe:

```bash
pnpm dlx supabase gen types typescript --linked > app/types/database.types.ts
pnpm typecheck
```

---

## 3. Google OAuth

### 3.1 Google Cloud Console

1. Open https://console.cloud.google.com and create (or select) a project.
2. Go to **Google Auth Platform** and click **Get started**:
   - **App information:** app name (e.g. `Drag Race Game`) and support email
   - **Audience:** **External**
   - **Contact information:** your email
   - **Finish:** accept the policy → **Create**
3. **Clients → + Create client:**
   - Application type: **Web application**
   - Authorized JavaScript origins: `http://localhost:3000` (+ your production URL later)
   - Authorized redirect URIs: `https://<project-ref>.supabase.co/auth/v1/callback`
4. Copy the **Client ID** and **Client secret** (the secret may only be shown once).
5. **Audience:** while the app is in *Testing*, only listed **Test users** can sign in. Add your friends' Gmail addresses, or click **Publish app** (no review needed for the basic `email`/`profile`/`openid` scopes).

### 3.2 Supabase dashboard

1. **Authentication → Sign In / Providers → Google:** enable it, paste the Client ID and secret, save.
2. **Authentication → URL Configuration:**
   - **Site URL:** `http://localhost:3000` (your production URL once deployed)
   - **Redirect URLs:** add `http://localhost:3000/confirm` (and `https://<your-domain>/confirm` in production)

Now `http://localhost:3000/login` → **Entrar con Google** should land you on onboarding (drag name) and then the home page.

---

## Roles

Judges register participants (name + Google email, optional drag name) in **/admin/participants** before they ever sign in. The first Google sign-in with that email links the login to the registered record (trigger `handle_new_user`); judges can upload their looks in the meantime. Anyone who signs in with an unregistered email is created as `concursante`.

Judges can't be self-assigned from the app, and a person's role can't be changed after registering them (only at registration time). To promote someone later, use the **SQL Editor**:

```sql
update public.participants set role = 'jurado' where email = 'someone@gmail.com';
```

| Role | Can do |
|---|---|
| `jurado` | Everything a contestant can, plus create/edit categories, change their status, upload looks |
| `concursante` | See non-draft categories and looks, vote Top 3 during `voting` (never for their own look) |

Category lifecycle: `draft` → `runway` → `voting` → `closed`. Votes are visible to everyone once a category is `closed`.

---

## Project structure

```
app/
  pages/          login, confirm (OAuth callback), onboarding (drag name), index
  middleware/     drag-name.global.ts: forces onboarding until drag_name is set
  composables/    useCurrentParticipant, useLookUpload
  utils/          compressImage (client-side resize → WebP), toErrorMessage
  types/          database.types.ts (generated Supabase types)
supabase/
  migrations/     SQL migrations (source of truth for the schema)
  config.toml     Supabase CLI config
nuxt.config.ts    @nuxtjs/supabase config (auth redirects, types path)
```

Runway photos are resized to max 1600px and re-encoded as WebP in the browser before upload, then stored at `runway-looks/{category_id}/{participant_id}/{uuid}.webp`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Unsupported provider: provider is not enabled` | Google provider not enabled in Supabase → step 3.2 |
| Google shows `redirect_uri_mismatch` | The redirect URI in Google must be `https://<project-ref>.supabase.co/auth/v1/callback` |
| Google shows "Access blocked: app has not completed verification" | Add the account under **Audience → Test users**, or publish the app |
| After login you land on the Site URL instead of `/confirm` | Add `http://localhost:3000/confirm` to Supabase **Redirect URLs** |
| `permission denied for table …` | A migration is missing: run `pnpm dlx supabase db push`. New tables need an explicit `GRANT` |
| `Missing NUXT_PUBLIC_SUPABASE_URL` warning | `.env` is missing or empty → section 1 |
| `pnpm: command not found` (e.g. after upgrading Node) | Run `corepack enable` (on Windows, from an admin terminal if it fails with `EPERM`), or prefix commands with `corepack`, e.g. `corepack pnpm dev` |
| `Unsupported engine` error from pnpm | Upgrade Node to 24.15.0+ (`nvm install` reads `.nvmrc`) |
