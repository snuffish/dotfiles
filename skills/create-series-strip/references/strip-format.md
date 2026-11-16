# Strip JSON format

The input of `scripts/render.py`. One file per strip, saved as `strip.json` in the strip folder.

```json
{
  "title": "Veckans strip",
  "subtitle": "12–16 nov 2026 · GR.PRIIS",
  "seed": 4242,
  "panels": [
    {
      "scene": "a messy desk exploding with error lights and sparks",
      "setting": "chaos",
      "actors": [
        { "text": "{tiger} screaming, pulling his cap with both hands, sweat drops, panic", "pos": "left" },
        { "text": "{robot} calmly typing on a laptop", "pos": "right" }
      ],
      "labels": [{ "text": "!19066 ABANDONED", "pos": "top-right", "color": "red" }],
      "captions": [{ "text": "Fredag. 34 commits senare.", "pos": "bottom-left" }],
      "bubbles": [
        { "text": "VAD ÄR ENS KÄNSLIGT?!", "pos": "top-left", "style": "shout", "tail": "down" },
        { "text": "Seed 1. Batch 7. Lita på mig.", "pos": "bottom-left", "tail": "right" }
      ]
    }
  ]
}
```

## Strip fields

| Field | Required | Meaning |
| --- | --- | --- |
| `title` | no | Title bar text, default `Veckans strip` |
| `subtitle` | no | Line under the title: the window and the repo |
| `seed` | no | Base seed, default 1234 (`../scripts/render.py:488`); panel N paints with `seed + N` unless the panel sets its own |
| `refs` | no | File names in `~/.local/share/series-strip/refs/` that steer the background's look; default all of them |
| `panels` | yes | 1–6 panels; 4 lays out 2×2, 3, 5 and 6 lay out three per row (`../scripts/render.py:422`) |

## Panel fields

| Field | Required | Meaning |
| --- | --- | --- |
| `scene` | yes | English prompt for the place. With `actors` it is painted empty, so name no characters in it. Without `actors` it is the whole picture, and `{tiger}`, `{robot}`, `{monster}`, `{monsters}` expand to the cast in `assets/cast.json`. Never words, signs or numbers: the painter cannot spell |
| `setting` | no | A key of `settings` in `assets/cast.json`: `desk`, `chaos`, `deploy`, `chill`, `meadow`, `hug` |
| `actors` | no | Characters painted one by one, cut out and pasted in front of the scene, in list order. Use it whenever a panel holds two or more of the cast: in one prompt they blend into each other |
| `negative` | no | Extra terms to keep out of this panel |
| `seed` | no | Pins this panel's seed; change it to repaint a bad panel. Actor N uses `seed + 100·N` (`../scripts/render.py:520`) |
| `labels` | no | Neon screen boxes for tech facts (`!19061 → Pull Request`); `color`: `green`, `magenta`, `cyan`, `orange`, `red` |
| `captions` | no | Yellow narration boxes, flush to the panel edge |
| `bubbles` | no | Speech bubbles; `style: "shout"` draws a yellow burst; `tail`: `left`, `right`, `down`, `none` (default points away from the panel edge the bubble sits on) |

## Actor fields

| Field | Required | Meaning |
| --- | --- | --- |
| `text` | yes | One character and what it does: `{tiger} grinning, fist raised high`. Exactly one cast placeholder; its crops in `refs/<name>/` steer the look |
| `pos` | no | `left` (default), `center` or `right` |
| `height` | no | Share of the panel height, default `0.82` (`../scripts/render.py:293`) |
| `flip` | no | `true` mirrors the actor so it faces the other way |

Actors are recomposed on every run, so a changed `pos`, `height` or `flip` needs only `--relayout`.

## Text fields

Every `labels`, `captions` and `bubbles` entry takes `text` (wraps by itself; `\n` forces a break), `pos` and an optional `size` in px.

`pos` is `<top|middle|bottom>-<left|center|right>`, for example `top-left`. Bubbles default to `top-left`, labels to `top-right`, captions to `bottom-left`. Two entries on the same `pos` overlap; give each its own corner. Actors fill the lower part of the panel, so keep bubbles and labels in the top half where you can.

The fonts lack a few symbols; `→ ✓ ♥ ★` fall back to DejaVu Sans Bold (`../scripts/render.py:61`). Emoji do not render.
