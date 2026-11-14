## Summary

<!-- What changes and why, in a few lines. Start the PR title with the Jira key: `DRG-12 Short title`. -->

## Migrations

<!-- A PR that adds a file under supabase/migrations/ must list it here. It must be applied to Supabase BEFORE merging, because merging deploys. -->

- [ ] No migration
- [ ] Migration(s): `…` (applied to Supabase before merging)

## Definition of done

Mark each box, or write `N/A: reason`.

- [ ] Technical docs updated (`docs/<feature>.md` or README) for new or changed features
- [ ] In-app help updated (`app/utils/helpContent.ts`, `app/pages/help.vue`), and help text made wrong by this change fixed
- [ ] `app/types/database.types.ts` updated if the database changed
- [ ] `CHANGELOG.md` has an `Unreleased` line ending with the issue key

## Release (last commit of the PR)

- [ ] Version decided (patch / minor / major) and set in `package.json`
- [ ] `CHANGELOG.md`: `Unreleased` renamed to `## [X.Y.Z] - date` (date of the planned merge)
- [ ] `app/utils/releaseNotes.ts`: entry for this version (every version has one; internal-only releases use `Mejoras y correcciones internas.`), same date as the changelog
- [ ] Jira fix version `X.Y.Z` set on every ticket in the release
- [ ] Not a release yet (say why)

## Test plan

- [ ] …

## After merging

- [ ] Tag the merge commit `vX.Y.Z` and check the deploy
- [ ] Mark the version as released in Jira
