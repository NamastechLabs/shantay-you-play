# Admin looks tab (DRG-4)

Page: `app/pages/admin/runways/[id]/looks.vue`. Tabs: Reinas, Grupos, Jurados.

## Reinas (queens' looks)

`queensMode` (`hidden` | `view` | `edit`) starts from the runway status and resets when the status changes:

| Status | Default | Buttons |
|---|---|---|
| `draft` | `edit` | none |
| `werk_room` | `hidden`: the same rows and photo slots as always (`LookEditRow` with `concealed`), but each uploaded photo is replaced by a card with the icon (`/icon-192.png`) centred; empty slots keep their placeholder and the intro is not shown | `Ver los looks` (read-only, all uploaded looks), `Editar` |
| `runway` | `view` (read-only) | `Editar`, then `Terminar de editar` |
| `voting`, `reveal`, `closed` | `view` | none (looks are frozen, `canEditLooks`) |

Pasting an image (Ctrl+V) only works while the tab being shown is editable.

## Grupos (groups' photos)

`groupsMode` follows the same table as `queensMode`, independently: in `werk_room` the photo slots of each group (`GroupPhotosEditor` with `concealed`) show an icon card (`/icon-192.png`) in place of every uploaded photo, with `Ver las fotos` and `Editar`; from `runway` on the four photos are shown read-only in a 2x2 flex grid (`display="grid"`) with `Editar` while photos can still change.

## Jurados

Lists the participants with role `jurado` plus the special guests invited to the runway (`runway_guests`). Guests' looks are stored in `jury_looks` like the jury's. Editing follows `canEditLooks`, in every status.

No database change.
