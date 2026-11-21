# Runway reveal

Status: **implemented** (DRG-12), mobile first.

When a runway reaches `reveal`, the home page plays a full-screen, spotlight-style reveal: [`RevealStage`](../app/components/RevealStage.vue). It replaces the old roulette. There are two phases, always in this order:

1. **Bands**, only when the runway has a group category (`RevealBand`, from `category_group_result`).
2. **Top 3 queens**, after the jury presses **Revelar el Top 3 de la semana** (`reveal_runway_top_three`, see [group-categories.md](group-categories.md)).

The jury's trigger and the data are unchanged: **no migration**.

## Sequence (about 25 s)

1. **Blackout and spotlights** (2.4 s): the page fades to a near-black stage and CSS-gradient beams sweep over it.
2. **Discovery**: every contender is lit one at a time (3.2 s each) **in random order, without showing the place**, with a random entrance (fade, slide up, slide down, slide from a side, zoom from small to big, spin, flip, curtain, flash). The effect is never the same twice in a row; the name fades in once the photo is in.
3. **Suspense line**: "La reina de la semana es…" (bands: "La banda ganadora es…" / "Las bandas ganadoras son…"), word by word.
4. **Fade to black** with a short flash.
5. **Winner** (7 s): the heading "¡Felicidragues, {name}!" at the top, the winner growing from small to big with a crown, confetti and the winner sound. For the Top 3, second and third come in below after 3.2 s with their places. On a band draw both bands are shown as winners.
6. The stage fades out and the page shows the static result ([`TopThreeReveal`](../app/components/TopThreeReveal.vue) podium, [`BandReveal`](../app/components/BandReveal.vue)).

## When it plays

- **For everyone on the home page at the same time**: the status / `top_three_revealed` change reaches every open page through realtime.
- **On load** if that device has not seen that phase of that runway yet. Seen phases are kept in `localStorage` (`seen-reveals`, `<runwayId>:bands|queens`); skipping counts as seen.
- Until a phase has played, its result is **not on the page** (so nobody sees it early); the jury button for the Top 3 appears once the bands phase is done.
- **Ver la revelación de nuevo** (next to "Ver la pasarela") plays the Top 3 again.

## Controls and accessibility

- **Saltar** (or `Esc`) closes it. The stage is a modal dialog with a polite live region.
- `prefers-reduced-motion`: nothing moves or advances by itself; the result is shown at once with a **Cerrar** button, no flash, confetti or sound.

## Performance (phones)

Only `transform`, `opacity` and `clip-path` are animated; no blur filters, no animation library beyond motion-v (already used by the voting summary). All photos are preloaded when the stage opens.

## Sound

`public/audio/winner.mp3` is **optional**. The composable [`useRevealSound`](../app/composables/useRevealSound.ts) looks for it once (a `HEAD` request; the browser console logs a 404 when it is missing). If it is not there, nothing is loaded or played and the mute button is not shown. Browsers block sound until the person has touched the page, so for those visitors the reveal runs silently. The mute choice is saved in `localStorage` (`reveal-sound-muted`).

## Theming

Colors come from tokens in `app/assets/scss/tokens/_themes.scss`: `--reveal-stage`, `--reveal-text` and `--spotlight-beam`, plus the usual `--glow-*` and `--color-*`. The component never checks the active theme. To use a spotlight image later, replace the beams in `RevealStage.vue` (`.reveal-stage__beams`).

## Tuning

Timings are constants at the top of `RevealStage.vue`; effects are the `EFFECTS` list (add a pose to add an effect).
