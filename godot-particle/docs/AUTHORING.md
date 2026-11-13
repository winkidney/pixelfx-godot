# Authoring a particle effect

Each of the 244 pixelfx effects is reimagined here with Godot's own tools: GPU particles first, then shaders, lines,
sprites and an AnimationPlayer for everything particles can't do. It isn't a pixel copy of the original (that's the
pixel port in `../godot/`). It is the same effect: same timing, same colours, same size and place, same motion, the
same beats. You judge it against the original, frame by frame.

## The loop

```bash
cd godot-particle
./pfxp new fire/brazier          # build/fx/fire/brazier.gd: a build script with the original's ramps and timing
# read src/fx/fire/brazier.js (the original) and look at the reference: ../godot/records/gallery/fire/brazier/anim.webp
./pfxp build fire/brazier        # -> addons/pixelfx_particles/fx/fire/brazier.tscn
./pfxp check fire/brazier        # loads, meta matches, timeline sane, seeds fixed, nothing the renderer can't do
./pfxp compare fire/brazier      # renders it (xvfb-run), scores it against the reference
# look at records/compare/fire/brazier/sheet.png (REF above PARTICLE, 10 frames) and side.webp (both, playing)
# fix the worst thing; build, compare, look again
```

`./pfxp list [words]` searches the effects. `python3 -I port/compare.py <ids> --no-render` rescores without
rendering. Renders go to `records/render/<id>/`, comparisons to `records/compare/<id>/` (git-ignored).

**Done** means: `check` passes, the score is at least 0.6 (aim for 0.75), and you have looked at the sheet and the
side-by-side and they read as the same effect. Both sides are measured against the same backdrop (the original's,
pixel for pixel), so a stand-in or a still prop counts the same on both. The score is a triage signal, not the judge:
your eyes decide.

## What a scene is

`build/fx/<cat>/<name>.gd` extends `res://addons/pixelfx_particles/core/build.gd` and describes the effect in
`make()`. `./pfxp build` runs it and saves `addons/pixelfx_particles/fx/<cat>/<name>.tscn`, an ordinary scene:

- The root is a `PfxEffect` (`core/pfx_effect.gd`), at the effect's **origin** (the original's `meta.origin`: feet,
  point of impact, base of a torch; for screen effects the top-left). It carries the original's meta (duration, loop,
  canvas, origin, backdrop, stand-in, colour ramps, source) from `port/meta.json`; `check` holds it to that.
- An `AnimationPlayer` with one animation, `fx`, as long as the effect and looping when it does, drives everything
  that changes over time: emitters on and off, `amount_ratio`, shader uniforms, positions, visibility, scale.
- **Coordinates** are px on the original's canvas, relative to the origin, y down. `-Vector2(root.origin)` is the
  canvas's top-left; `root.canvas_size` its size. Angles are degrees, 0 right, 90 down, -90 up.
- **Layers** (the `layer` option of every helper):
  - `"color"` (default): the dither material, on/off alpha through a Bayer matrix, colours snapped to the effect's
    palette. Most things.
  - `"soft"`: real translucency in 8 steps, snapped. Smoke, dust, mist, haze, washes.
  - `"light"`: additive, the original's light buffer: glows, shines, flashes of light. Drawn over the colour layers.
  - `"prop"`: exactly as drawn, for the original's own pixels (props, frames).
  - `back: true` puts a node behind the stand-in character (the original's `drawBack`), otherwise it's in front.
- **Determinism**: every emitter has a fixed seed (the helpers do it). Shaders never read `TIME`: they take a uniform
  the animation keys (`loop_t(node)` keys `t` from 0 to 1 over the effect). A freeze sets `speed` to 0 and everything
  stops; a render is the same every time.

## The helpers (core/build.gd)

| helper | makes |
|---|---|
| `particles(name, o)` | a GPUParticles2D. o: `at`, `back`, `layer`, `amount`, `lifetime`, `one_shot`, `explosiveness`, `randomness`, `preprocess`, `emitting`, `texture`, `align` (texture along velocity), `emit` (point, `{"box": v}`, `{"circle": r}`, `{"ring": [r, inner]}`, `{"points": PackedVector2Array}`), `dir`, `spread`, `speed`, `gravity`, `damping`, `radial` (acceleration), `radial_speed`, `life_random`, `tangential`, `orbit`, `angle`, `spin`, `scale`, `scale_curve`, `alpha_curve`, `color`, `ramp`, `initial`, `turbulence`, `local`, `collide` |
| `ramp(name, o)` | a stepped gradient from the original's colour ramp option `name`: `from`, `to` (part of it), `reverse` (brightest first: cooling over a life), `alpha` curve, `stops`. Recolouring follows it. |
| `gradient(colors, offsets)`, `color(name, u)`, `curve(points)` | explicit gradients, a colour along a ramp, curves |
| `sprite(name, tex, o)`, `rect(name, Rect2, color, o)`, `group(name, o)` | plain nodes |
| `ring(name, reach, params, o)` | disc / ring / ellipse on the floor (shaders/ring.gdshader): flashes, shock rings, bands, novas, sigils, scorches |
| `glow(name, reach, params, o)` | soft additive disc or band (light layer) |
| `arc(name, reach, params, o)` | crescent smear on a tilted ellipse (shaders/arc.gdshader): slashes, swipes, sweeps |
| `fog(name, size, params, o)` | noise banks scrolling with the loop (shaders/fog.gdshader): mist, fog, haze, cloud, smoke sheets |
| `shape(name, shader, size, params, o)` | any canvas shader on a rect centred on `at` (your own `.gdshader` under `fx/<cat>/`); colour arrays become `vec4[]` uniforms and join the palette |
| `bolt(name, a, b, o)` | a jagged line re-rolled off the effect's clock (core/bolt.gd): lightning, arcs, crackles, tendrils |
| `line(name, points, o)` | a Line2D; `soft` gives it a glowing cross-section; with a `gradient` it gets a point every pixel so stepped colours stay stepped |
| `text(name, s, o)` | a word in the original's pixel fonts, drawn as its UI words are (core/pixel_text.gd): fill ramp, bevel, outline, shadow, flash, squash |
| `ground(y)` | a floor particles can land on, bounce off or vanish into (`collide`) |
| `actor_node()` | the stand-in as the effect's own node, with a flash and tint you can key (status effects) |
| `actor_points(edge)` | the stand-in's silhouette (or outline) as emission points: flames, frost, poison on the body |
| `prop(o)` | the original's still pixels (see below) |
| `frames(name, o)` | the original's frames for a body that isn't an effect (see below) |
| `key(node, prop, [[t, v], ...], interp)` | keys on `fx`: `"position"`, `"modulate:a"`, `"material:shader_parameter/radius"`, `"amount_ratio"`... interp `"linear"`, `"nearest"` (steps, on/off), `"cubic"` |
| `emit(p, on, off)`, `show(n, on, off)`, `loop_t(n)` | emitters and visibility over time; a shader's `t` over the loop |
| `keep_colour(c)` | keep a colour that isn't in any ramp out of the palette snap (gradients, rects, text and shape colours do it themselves) |

Textures (`addons/pixelfx_particles/textures/`): `dot1`-`dot4`, `disc3`-`disc13`, `ring5`-`ring13`, `plus3`,
`spark5`, `spark7`, `star5`, `streak3`-`streak12` (with `align`), `ripple5x1`-`ripple15x5`, `glow8`-`glow64` (soft,
for the light layer), `beam8`, `beam16`, noise (`noise256x64`, `noise128`, `noise128soft`, `noise64grain`).

## What reuses the original's pixels, and what never does

Props and bodies aren't effects; effects are.

- **Props**: a torch's bracket, a brazier, a fountain's basin, a rain scene's haze and wet floor. `python3 -I
  port/props.py <id>` lifts the pixels that hold one colour through most of the effect (`--share 0.3` when something
  keeps passing over them, `--box x0,y0,x1,y1` to keep only part) from its colour layer (no light), into
  `fx/<cat>/<name>/prop.png`; `prop()` puts it in place. Light over a prop is your glow, as in the original.
- **Bodies**: critters, and solid objects that move or turn as a whole (a coin, a gem, a chest, a key, a potion).
  `python3 -I port/frames.py <id>` lifts the original's frames into `fx/<cat>/<name>/frames.png`; `frames()` steps
  through them. Use it only for the body: the sparkle, the glint, the trail, the light are yours.
- **Everything else is made here**: fire, smoke, sparks, embers, magic, light, rings, slashes, bolts, beams, wipes,
  splashes, weather. If you lift an effect's frames you haven't ported it.

After adding a PNG, run `./pfxp import` (it locks; other shells wait).

## From the original's techniques

| the original | here |
|---|---|
| `Particles` / `Bits` / `Blazes` / sparks, embers, motes, smoke puffs, debris | `particles()`: one emitter per kind, `one_shot` + `explosiveness` for bursts; `ground()` + `collide` for landing and bouncing |
| `p.glow`, `Lights` | `glow()`, or a `sprite` of `glowNN` on the light layer; key its alpha |
| `p.circle`, `p.ring`, `band` | `ring()` (`side` for the halves behind and in front of a character) |
| crescents, swipes | `arc()` |
| `p.line` bolts, chains, arcs | `bolt()`; straight beams: `line()` + a soft light copy |
| `p.shade(fn)` per-pixel fields: flames, fog, auroras, water, wipes, portals | a canvas shader (`shape()`); start from `fog`, `ring`, `iris` or `arc`; include `pixel.gdshaderinc` and end with `pfx_pixel()` |
| text, numbers | `text()` |
| `o.actor` silhouettes | `actor_points()` emitters; `actor_node()` for flashes and tints on the body |
| timings and curves (`ease`, `smooth`, a little physics) | compute them in the build script with the original's formula and key them every frame (or at 60 Hz): the iris radius, the damage number's arc, the slash's head and tail |
| `rand`, `Rng` choices made once | a `RandomNumberGenerator` with a fixed seed in the build script |
| loops (exact repeats) | emitters with `preprocess` (no empty first frame) and keys equal at 0 and the end; particles repeat statistically, not exactly |

## Things that will bite

- **Compatibility renderer**: no sub-emitters, no particle trails (`check` fails them). A splash where drops land
  is an emitter of its own along the floor; a fire where a brand lands is one that starts when it lands; a trail is
  a second emitter (or `streak` textures with `align`).
- **Turbulence**: `influence` above about 0.03 eats a particle's speed (a flame that should rise 20 px rises 5). Keep
  it 0.005..0.03; the default is 0.01..0.02. For licking flames, sway the emitter's `position` with keys instead.
- **Light goes on top**: the light layer draws over the colour layers (that's how the original composites). Bright
  additive glow over a flame washes it white: keep glows dim and warm, measure them against the reference.
- **Palette snap**: colours on the colour and soft layers snap to the effect's ramps plus `palette_extra`. Helpers
  keep their own colours; a colour you set by hand on a node or material needs `keep_colour()`. Props and frames
  use the prop layer and never snap.
- **GDScript**: `:=` can't infer from a Dictionary value or an untyped expression (`var k: float = ...`). Don't name
  things after built-ins (`floor`, `round`, `Font`).
- **One-shots** must be done by their duration (`check` warns when particles outlive it). **Loops** need
  `preprocess` on their continuous emitters.
- **Screen effects** (320 x 180, origin at the top-left) cover the canvas: weather, transitions.

## Examples

The pilots show each technique: `build/fx/fire/torch.gd` (props, a flame from emitters, a measured glow),
`explosions/small-explosion.gd` (bursts, rings, a collision floor, soft smoke), `weather/rain.gd` (layers of
aligned streaks, a fog band, a lifted haze), `transitions/iris.gd` (a shader whose radius follows the original's curve),
`critters/bat.gd` (frames), `status/burning.gd` (the stand-in flashed and tinted, emitters on its body),
`melee/sword-slash.gd` (the arc shader keyed from the original's sweep), `ui/damage-number.gd` (text and replayed
physics), `lightning/lightning-strike.gd` (bolts on the original's beats).
