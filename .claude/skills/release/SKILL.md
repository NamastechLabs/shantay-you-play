---
name: release
description: Prepare a release of Shantay You Play (project key DRG). Use when the user says "release", "prepare the release", "create version 0.3.0", or invokes /release. Picks the semantic version, dates and closes the changelog, adds the in-app release notes entry, bumps package.json, sets the Jira fix version on every shipped ticket and lists what must happen before and after merging. Also used by work-on-ticket for its final commit. Leaves the edits uncommitted for review. Never commits, pushes, opens a PR, tags or releases the Jira version without being asked.
---

# Prepare a release

Merging to `main` deploys, so the version is decided **before** merging and is never edited on `main` afterwards. This skill is the single place where a release is prepared: a ticket (`work-on-ticket` step 7) or a batch of changes (several tickets, or changes already on `main`) both end here.

Argument (optional): the version (`0.3.0`). If none is given, pick it in step 2.

## 1. Collect what is shipping

- Read the `## [Unreleased]` section of `CHANGELOG.md`: that is the content of the release. If it is empty, stop: there is nothing to release.
- List the ticket keys at the end of its lines (`DRG-12`). Lines without a key came from work done directly on `main`: say so in the report.
- Check where you are:
  - On a ticket branch: the release commit goes last on that branch (`DRG-12 Release vX.Y.Z`), after the user has approved and committed the feature work.
  - For a batch with no PR yet: ask the user where to prepare it (a `chore/release-X.Y.Z` PR is the default, because `main` deploys on every merge). Never commit a version bump straight to `main` unless the user says so.
- Run the checklist of the "Definition of done" in CLAUDE.md against everything in `Unreleased` (docs, help, migrations). Report what is missing; fix it in the same PR if the user agrees.

## 2. Pick the version

[Semantic versioning](https://semver.org), counted from the version in `package.json`:

- **patch**: only fixes.
- **minor**: any new feature.
- **major**: breaking changes (data or behavior people relied on).

Ask if unsure. The tag, the Jira fix version, the changelog heading and `package.json` all use the same number (`0.3.0`; the tag adds a `v`).

## 3. Date

Use the day the release is planned to be **merged**, not necessarily today, in `YYYY-MM-DD`. The same date goes in `CHANGELOG.md` and `app/utils/releaseNotes.ts`. If the merge happens on another day, update both dates before merging and tell the user.

## 4. Edit the files

1. `CHANGELOG.md`: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` and add a new empty `## [Unreleased]` above it.
2. `package.json`: set `"version": "X.Y.Z"`.
3. `app/utils/releaseNotes.ts`: add an entry at the top, **always**: `/novedades` must contain every version.
   - `version`, `date` (same as the changelog), a short Spanish `title`.
   - `features`: one Spanish sentence per functional change users will notice (what they can now do), no technical terms.
   - A release with nothing users can see (fixes, internal work) still gets an entry, with the single feature `Mejoras y correcciones internas.`
4. Check that the versions in `package.json`, the top of `CHANGELOG.md` and the first entry of `releaseNotes.ts` match.

**Do not commit yet.** Leave the edits in the working tree and show them (`git status --short`, `git diff --stat`) so the user can review and change them. Once the user approves, commit as `DRG-12 Release vX.Y.Z` on a ticket branch, or `Release vX.Y.Z` when there is no single ticket (several keys may be listed in the body).

## 5. Jira fix version

- The Jira version must be named exactly `X.Y.Z` (no `v`). The Atlassian MCP cannot create versions: if it does not exist, ask the user to create it (project `DRG` → Releases).
- Then set `fixVersions` to that version on **every** ticket listed in step 1, with `editJiraIssue`. This is the only Jira write done without asking.
- Never comment on a ticket, transition it or mark the Jira version as released unless the user asks.

## 6. Report

Say plainly what was done and what is left:

- Version, date and the tickets in it.
- **Migrations:** if any file under `supabase/migrations/` is part of this release, list it. It must be applied to Supabase **before** merging.
- **Not done, on purpose:** commit (until the user reviews the diff), push, PR, tag, marking the Jira version as released.
- **After merging:** tag the merge commit (`git tag vX.Y.Z <merge commit> && git push origin vX.Y.Z`), check the deploy, and mark the version as released in Jira. Offer to do the tag; do it only if asked.
