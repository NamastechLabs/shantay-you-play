# Runway voting summary

Status: **implemented** (DRG-23), visuals still being tuned.

When a runway opens for voting (`runway` → `voting`), the home page plays a short, animated, video-style summary of the week: [`RunwayVotingSummary`](../app/components/RunwayVotingSummary.vue). Unlike the [intro video](runway-intro-video.md) it is not a file: it is built from components and live data, so it needs no upload and no storage.

## When it plays

- **Automatically**, if the person is on the home page when the status flips `runway` → `voting` (realtime, see `useRunwaysRealtime`). The page content fades out first, then the summary comes in. It does not play if the week has no photos to show.
- **On demand**, with the **Ver el resumen de la votación** button of the hero card, while the featured runway is in `voting`. From `reveal` on the reveal takes over and the button is gone.

## Scenes

1. **Title** ("¡Abre la votación!").
2. **Bands**, only when the runway has a group category: one scene per band with its **first photo** (landscape) and its name. Bands always come before the queens. Bands without photos are skipped.
3. **Queens**: one scene per queen with the **first photo of her first look** and her drag name. The category title is shown only when the week has more than one individual category.
4. **Closing card** ("¡Es hora de votar!") with the vote button (**Cambiar mi Top 3** if the person already voted), **Repetir el resumen** and **Cerrar**. It waits for the viewer.

Only one photo per band and queen is shown on purpose: with several photos each one went by too fast, and all the looks are on the vote page and on the runway.

Scenes are defined in the `scenes` computed (title, bands, queens, outro) with their duration in ms, so reordering or retiming them is a small change.

### Photos: time and random effects

- **Every band and queen scene lasts 5 s** (`PHOTO_SCENE_MS`), the same on phones and on bigger screens. The title card lasts 3.2 s.
- The photo comes in (0.55 s), stays, and goes out (0.55 s). The **way in and the way out are drawn at random**, each from its own list (`IN_EFFECTS`, `OUT_EFFECTS`): it slides from or to the left or right, rises or falls (a bit tilted), zooms from or to a dot, spins, flips like a card, or comes from or goes past the camera. Adding an effect is adding a pose (what changes from the resting one) to a list.
- The photo is one animation of four keyframes (out of place and invisible, in place, in place, out of place and invisible), so it is already gone when the next scene starts. The name stays hidden while the photo comes in, fades in right after the entrance ends (`NAME_FADE_IN_S`) and fades out with the photo.
- The draw is made once per scene and kept until **Repetir el resumen**, which draws again; the screen refreshing meanwhile does not change the effect.
- The photo keeps its own proportions (never cropped) in a box of fixed size, so the name does not move.

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
