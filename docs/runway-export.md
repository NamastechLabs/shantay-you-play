# Runway export for AI commentary

The week summary (`/admin/runways/[id]`, judges only) has a "Comentarios con IA" section with a **Descargar ZIP de la semana** button. It exists for AI chats that cannot call `GET /api/commentary/runway` nor download the photo URLs.

## What it downloads

`pasarela-semana-N.zip`:

```
runway.json
<category-slug>/<queen>-frente.webp
<category-slug>/<queen>-espalda.webp
<category-slug>/jury/<queen>-frente.webp
```

`runway.json` has the same shape as the endpoint (`runway`, `categories[].{title, intro, looks, jury_looks}`), except each photo has `file` (path inside the ZIP) instead of `url`.

## How it works

- `app/composables/useRunwayExport.ts` reads the runway, categories, looks and jury looks with the signed-in judge's Supabase client (RLS applies; judges can read everything), fetches the public photo URLs and zips them in the browser with [`fflate`](https://github.com/101arrowz/fflate) (loaded on demand; photos are stored, not deflated).
- No commentary token and no service role are involved. Any week can be downloaded, whatever its status.
- No database changes.
