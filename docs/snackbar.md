# Snackbar (feedback messages)

Status: **implemented** (DRG-20).

Success, info and error messages are shown in one small message over the content (a snackbar), the same in every screen, instead of inline text that takes space or gets lost.

## Usage

```ts
const snackbar = useSnackbar()

snackbar.success('¡Voto guardado!')
snackbar.error(toErrorMessage(error))
snackbar.info('Texto copiado.')
snackbar.show({ message: '…', type: 'error', duration: 8000 }) // full form
snackbar.dismiss()
```

`<AppSnackbar>` is mounted once in `app/app.vue`; pages and components only call the composable. The copy is Spanish and comes from the caller.

## Behaviour

| | |
|---|---|
| **Queue** | **Replace**: a new message replaces the current one, so there is never more than one snackbar and no backlog of stale messages. |
| **Closing** | `success` and `info` close after 4 s (`SNACKBAR_DURATION`). `error` stays until dismissed with its close button (or replaced by the next message). `duration` overrides it. |
| **Position** | Phones: bottom center. Desktop (from 48rem): bottom left. `max-width: 28rem`, clear of the safe area (`env(safe-area-inset-bottom)`). |
| **Pinned bars** | `useSnackbarOffset(el)` keeps it above a pinned element: the vote page passes the ballot bar, and the offset follows its height (`--snackbar-offset`). |
| **Modals** | A modal `<dialog>` makes everything outside it inert, so while one is open `AppSnackbar` moves its element inside the dialog (and back to `<body>` when it closes). Errors raised from a form in a modal are therefore visible and dismissible. |
| **Accessibility** | Two persistent live regions: `role="status"` (polite) for success and info, `role="alert"` for errors. Focus is never moved. `prefers-reduced-motion`: fade only, no slide. |
| **Theming** | `app/assets/scss/components/_snackbar.scss`, tokens only (`--color-success`, `--color-danger`, `--color-surface-raised`, `--color-text`, `--radius-*`, `--shadow-raised`). Classes: `.snackbar`, `.snackbar--success`, `.snackbar--error`, `.snackbar__icon`, `.snackbar__text`, `.snackbar__close`. |

## What uses it and what stays inline

**Snackbar:** save confirmations (vote, group vote, profile, group intro, intro video) and success messages for admin actions that change nothing visible on screen (runway details, status change, category save, look and group photo saves, pasted photo, export, reveal Top 3), the "extra photos ignored" and "text copied" info, and errors from saving, uploading, voting, reveal, sharing, sign-in and admin actions (runways, participants, guests, categories, groups, sub-categories, looks).

**Inline, on purpose:** errors that belong to a field or to a form rule (e.g. the sub-category name checks), page-level blocking states (e.g. "Tu correo no está en la lista de participantes", "faltan fotos de grupo"), page load errors that leave the screen without data, and empty states.

No success message on purpose where the screen already shows the result: creating or deleting items, inviting guests, and panels that close when saved.

`DevImpersonate` (development only) keeps its own inline error.
