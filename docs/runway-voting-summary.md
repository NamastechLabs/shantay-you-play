# Runway voting summary

Status: **implemented** (DRG-23), visuals still being tuned.

When a runway opens for voting (`runway` → `voting`), the home page plays a short, animated, video-style summary of the week: [`RunwayVotingSummary`](../app/components/RunwayVotingSummary.vue). Unlike the [intro video](runway-intro-video.md) it is not a file: it is built from components and live data, so it needs no upload and no storage.

## When it plays

- **Automatically**, if the person is on the home page when the status flips `runway` → `voting` (realtime, see `useRunwaysRealtime`). The page content fades out first, then the summary comes in. It does not play if the week has no photos to show.
- **On demand**, with the **Ver el resumen de la votación** button of the hero card, while the featured runway is in `voting`. From `reveal` on the reveal takes over and the button is gone.

## Scenes

1. **Title** ("¡Abre la votación!").
2. **Bands**, only when the runway has a group category: one scene per band with its photos (up to 4, landscape). Bands always come before the queens. Bands without photos are skipped.
3. **Queens**: one scene per queen with the photos of her looks (up to 4) and her drag name. The category title is shown only when the week has more than one individual category. With more than 8 queens every scene is shorter.
4. **Closing card** ("¡Es hora de votar!") with the vote button (**Cambiar mi Top 3** if the person already voted), **Repetir el resumen** and **Cerrar**. It waits for the viewer.

Scenes are defined in the `scenes` computed (title, bands, queens, outro) with their duration in ms, so reordering or retiming them is a small change.

### Photos: the carousel (phones)

On phones (width up to 640px) the photos of a band or a queen are a **carousel**: they slide in one at a time from the right at full size (never cropped, its own proportions) and leave to the left as the next one arrives; the last one stays. A row of dots under the photos lights up the one on screen. Every scene starts its carousel from the first photo. **Every scene lasts the same, whatever its number of photos**: 5 s (4.2 s with more than 8 queens; `CAROUSEL_SCENE_MS`). The first photo arrives after 0.3 s, the last one stays for 1.3 s and the time in between is shared by the photos, so a queen with 1 photo shows it for the whole scene and one with 4 photos changes about every 0.9 s. On bigger screens the photos appear side by side, in a grid.

## Controls

- Progress bar with one segment per scene. **Saltar** closes it (it reads **Cerrar** on the closing card).
- Click or tap on the stage: next scene. Keyboard: `Esc` closes, `→` / `←` move between scenes.
- `prefers-reduced-motion`: nothing moves or advances by itself; every scene is listed one under the other and the content never depends on the animation.

## Implementation notes

- Animations use [motion-v](https://motion.dev/docs/vue) (the `motion-v/nuxt` module in `nuxt.config.ts` auto-imports `<Motion>`) plus SCSS keyframes for the progress bar and the sparkles.
- Colors, fonts, glow and the backdrop come from the theme tokens (`--color-*`, `--glow-*`, `--page-backdrop`); the component never checks which theme is active.
- The data is loaded in [`pages/index.vue`](../app/pages/index.vue) (`loadVotingSummary`) together with the rest of the home data, only while the featured runway is in `voting`, so the status change and the data arrive in the same refresh. Looks and group photos are readable from `voting` on (RLS), so **no migration** is needed. The jury's own looks are not part of the summary.
- All photos are preloaded when the summary opens, so scenes do not pop in half loaded.
- If the runway leaves `voting` while the summary is open, it closes and the page comes back.
