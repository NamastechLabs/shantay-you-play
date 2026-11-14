# Runway intro video

The weekly intro video is played full screen when a runway goes from `werk_room` to `runway` (see [`RunwayIntro`](../app/components/RunwayIntro.vue)).

## Uploading (judges)

`/admin` has two tabs, **Semanas** and **Vídeo de intro**; the second one holds the **Vídeo de introducción** section ([`AdminIntroVideo`](../app/components/AdminIntroVideo.vue)) as a card: the preview of the current video on one side and, on the other, its status (Configurado / Sin vídeo), the format limits and the upload button.

- The file is always stored as `intro.mp4` in the public `runway-intro` bucket with `upsert: true`, so each upload **overwrites** the previous video. Only one video is kept, to stay within the free Supabase storage plan.
- Checked in the browser before uploading: MIME type `video/mp4`, size at most 50 MB (the bucket's `file_size_limit`) and vertical 9:16 (width/height within ±0.03 of 0.5625, read from the video metadata).
- Upload is allowed by the storage policies of `20261108000100_storage_runway_intro.sql` (judges only) plus `20261114000200_runway_intro_select_policy.sql`: overwriting uses upsert, which also needs a select policy.
- The upload sets `cacheControl: 60`; the home page adds `?v=<week number>` to the URL.
