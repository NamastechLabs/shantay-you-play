---
name: runway-commentary
description: Fetch the current Drag Race Game runway (Pasarela stage) with its categories, every queen's intro and look photos, and the jury's looks, and download the photos so you can write the commentary on the looks. Use when the user asks for comments, critiques or a review of the runway looks.
---

# Runway commentary

Pulls everything needed to comment on the looks of the runway that is currently in the **Pasarela** stage, so the user does not have to paste photos and intros by hand.

## Configuration

Two environment variables (set them in the shell or in `.env.local`; never print the token):

- `DRAG_RACE_API_URL`: base URL of the app, e.g. `http://localhost:3000` or the production URL.
- `NUXT_COMMENTARY_API_TOKEN`: the same token the server was started with.

If either is missing, ask the user for it once and stop.

## Steps

1. Fetch the payload (add `?week=N` to use another week instead of the one in Pasarela):

   ```bash
   curl -sS -H "Authorization: Bearer $NUXT_COMMENTARY_API_TOKEN" "$DRAG_RACE_API_URL/api/commentary/runway" -o <scratchpad>/runway.json
   ```

   - `401`: wrong token. `404`: no runway is in the Pasarela stage (tell the user, offer `?week=N`) or the endpoint is disabled on that server.

2. Download every photo into a scratchpad folder, one subfolder per category, named `<queen>-<label>.<ext>` (`Frente`, `Espalda`, `Reveal`, `Extra`). Photo URLs are public, no auth needed. Keep jury photos in a `jury` subfolder.

3. Read the images (view each file) together with the queen's `intro`.

4. Write the commentary **in Spanish**, in the playful drag tone of the game. Respect this structure: runway week and date → for each category: its `title` and `intro` (the theme the looks must answer to) → for each queen: a comment on her look against the theme, using her intro and what you see in all her photos (front, back, reveal). Refer to queens by `queen` (drag name); the payload does not include real names.

## Payload

```json
{
  "runway": { "week_number": 3, "date": "2026-11-08", "status": "runway" },
  "categories": [{
    "title": "…", "intro": "…",
    "looks": [{ "queen": "…", "intro": "…", "photos": [{ "label": "Frente", "url": "https://…" }] }],
    "jury_looks": [ /* same shape */ ]
  }]
}
```

`intro` may be null when the queen wrote none. Jury looks are not voted on; comment on them only if the user asks.
