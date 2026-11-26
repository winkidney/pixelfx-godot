<p align="center">
  <img src="docs/readme/montage.gif" width="800" alt="A grid of pixel art effects playing at once: a campfire, a burning skull, a waterfall, a plasma ball, a portal, a tornado and more.">
</p>

# pixelfx for Godot

**244 pixel art effects and animations for Godot 4, every one a small piece of GDScript.** Fire, explosions, magic,
weather, UI, pickups, critters and more. Every effect that involves a character is acted out: he winds up, lets go,
freezes on contact and recovers, and a target takes the hit.

This is a Godot port of [pixelfx](https://github.com/patch-gg/pixelfx) by [Patch](https://patch.gg). Every effect is
ported line for line from the JavaScript original, and checked against it frame by frame: same pixels, same light, same
random numbers. A Claude Code skill comes with it. It uses the library, and makes new effects the way a picky pixel artist
would: draft, render, look, refine.

[catalog](godot/docs/CATALOG.md) · [use it](#use-it) · [make your own](#make-your-own) · [the skill](#the-skill) ·
[native particles](#a-second-port-native-particles) · [sound](#sound) · [how the port works](#how-the-port-works) ·
[the original JS](https://github.com/patch-gg/pixelfx)

## use it

Copy `godot/addons/pixelfx` into your project's `res://addons/` and enable **pixelfx** under Project Settings > Plugins.
Then:

```gdscript
var fx := PixelFx2D.new()
fx.effect = "ice/frost-nova"        # any id from the catalog
fx.palette_preset = "fire"          # recolor with any ramp: fire ice poison holy arcane shadow gold neon ...
fx.flip = hero.facing < 0
fx.free_when_done = true
fx.position = hero.position         # the effect's origin: feet, point of impact, base of a torch
add_child(fx)
```

`PixelFx2D` can play an effect in two modes:
- **BAKED** (the default) renders each frame once and replays it for free, shared by every node with the same options.
- **LIVE** renders on the CPU every frame.

Either way, pixels stay crisp and light goes on an additive layer, so glow brightens whatever is behind it.

`PixelFxAct2D` plays the whole act: the stock character, the straw target, the freeze on contact and the shake. It
emits `hit` at each contact.

**With your own character**, read the timing: `PixelFxAct2D.timing("melee/sword-slash")` gives `windup`, `recovery`,
and `hits` with `t` and `freeze`. Start your attack animation `windup` seconds before the effect, and freeze everything
for `freeze` seconds at each hit.

**SpriteFrames and sprite sheets**: run `cd godot && ./pfx sheets fire --spriteframes`. It writes a transparent PNG
sheet, an Aseprite-style JSON (fps, loop, pivot, act timing) and a ready `SpriteFrames` for an `AnimatedSprite2D`. In the
editor, Project > Tools > *pixelfx: Bake selected PixelFx2D* does the same for a node.

Open `godot/` in Godot and press F5 for the gallery: every effect by category, recolored, reseeded, flipped, acted out.

## make your own

```bash
cd godot
./pfx new arcane/my-spell          # a working starting point (--loop for a loop, --sim for particles)
./pfx render arcane/my-spell       # records/arcane/my-spell/contact.png: look at it
./pfx act arcane/my-spell          # if a character is in it: consecutive 12 fps steps
./pfx check arcane/my-spell        # spills, seams, unseeded randomness, slow frames, act mistakes
./pfx index                        # list it in the registry and the catalog
```

`pfx` runs Godot headless (set `GODOT` if it isn't on your PATH). [godot/docs/AUTHORING.md](godot/docs/AUTHORING.md)
has the contract, the drawing API and the quality bar.

## the skill

The `pixelfx-godot` skill teaches Claude Code to find, use, bake and make effects in Godot, and to port upstream changes.
Install it as a plugin:

```
/plugin marketplace add winkidney/pixelfx-godot
/plugin install pixelfx-godot@pixelfx-godot
```

You can also copy `godot/skills/pixelfx-godot` into `~/.claude/skills/`. Then ask for what you want:

- "Add a frost nova to my Godot mage's ultimate, in purple."
- "Bake the fire and explosions categories to SpriteFrames."
- "This hit effect feels floaty. Make it punchier."
- "Make five takes on a coin pickup sparkle and show me the best two."
- "Merge the latest pixelfx and port whatever changed."

## a second port: native particles

`godot-particle/` is a separate Godot project where the same 244 effects are rebuilt from Godot's own tools: GPU
particles first, then canvas shaders, lines, sprites and an AnimationPlayer for what particles can't do. Each effect is
an ordinary scene (`addons/pixelfx_particles/fx/<category>/<name>.tscn`) you can open and tweak in the editor, and it
runs on the GPU in the Compatibility renderer (desktop, mobile, web). It keeps the pixel look: colours snap to the
effect's own ramps, alpha dithers, light adds.

It isn't a pixel copy. It is judged against the original frame by frame (`./pfxp compare`: how much it covers, where,
in which colours, moving how) and by eye, side by side. The knight, the straw target, critters and still props reuse
the original's pixels; fire, smoke, light, magic, rings, slashes, bolts and weather are made here.

```gdscript
var fx := PixelFxParticles2D.new()
fx.effect = "ice/frost-nova"
fx.palette_preset = "arcane"
fx.position = hero.position
add_child(fx)
```

`PixelFxParticlesAct2D` plays the acted-out version. [godot-particle/docs/AUTHORING.md](godot-particle/docs/AUTHORING.md)
explains how an effect is built; `cd godot-particle && ./pfxp help` lists the tools.

How close and how fast, on an RTX 4070 SUPER with a Ryzen 9 7900X3D (Compatibility renderer, 1280×720, vsync off,
median of two runs; `./pfx perf`, `./pfxp perf`, `python3 godot-particle/port/perf_report.py`):

| | pixel LIVE | pixel BAKED | particles |
|---|---|---|---|
| similarity to the original (`./pfxp compare`) | 1.0 | 1.0 | 0.954 effects, 0.920 acts |
| one effect, ms a frame (mean of 244) | 9.75 | 0.28 | 0.42 |
| 64 at once, ms a frame | 997 | 0.45 | 52.7 |

Particles run about 20 times faster than LIVE (geometric mean: ×21.0 for one, ×20.3 for 64), and stay live: they
recolour, flip and react while they play. BAKED replays textures and is cheaper still at runtime, but it renders every
frame on first show (about 2 s of extra work per effect over its first play) and keeps every frame in video memory.
With 64 at once, 6 short impacts and UI effects run slower as particles than LIVE: each instance renders into its own
pixel view.

## sound

The particle port comes with 8-bit sound for every effect, synthesized in code the way the effects are drawn, and
timed to each effect's own beats. 179 effects have sound. 65 are silent on purpose: a torch burning, an idle pickup
or a status glow makes no noise of its own.

- Hits sound like what they hit: water, stone, wood, flesh, metal, ice, energy. Only explosions boom.
- There is no music, and one-shots end clean.
- In Godot, `PixelFxParticles2D` plays an effect's sound with it (`sound = true`). `play_sound("hit")` plays a single
  phase.
- `cd godot-particle && ./pfxp sfx` regenerates and exports all of it in one go. Add `--out DIR --format wav` to
  export for another engine.

Using the sound: [godot-particle/addons/pixelfx_particles/sfx/README.md](godot-particle/addons/pixelfx_particles/sfx/README.md).
Making it: [godot-particle/port/sfx/README.md](godot-particle/port/sfx/README.md). The rules behind it are in the
skill: [references/sound.md](godot/skills/pixelfx-godot/references/sound.md).

## how the port works

- **The original stays, untouched.** The JavaScript library (`src/`, `tools/`, `docs/`, `gallery/`, `skills/pixelfx/`) is
  kept exactly as upstream has it. It is the reference, and `git merge upstream/main` keeps it current.
  Everything Godot lives in `godot/`.
- **One file, one file.**
  - `src/core/*.js` is ported to `godot/addons/pixelfx/core/*.gd`.
  - `src/fx/<cat>/<name>.js` is ported to `godot/addons/pixelfx/fx/<cat>/<name>.gd`, with the same names and the same
    expressions.
  - Each `.gd` records the git blob of the JS it came from. `node godot/port/sync.mjs` lists what an upstream merge left
    stale or missing. [godot/docs/UPSTREAM.md](godot/docs/UPSTREAM.md) has the procedure, and
    [godot/docs/PORTING.md](godot/docs/PORTING.md) the rules.
- **Proven, not eyeballed.** `./pfx parity` renders every effect in eight variants (as is, flipped, rotated, recolored,
  reseeded, short palette, dimmed, stopped mid-loop) and compares each frame with the JavaScript's.
  - It compares the color buffer, the light buffer and every random number drawn.
  - `./pfx parity --acts` does the same for the acted-out versions: character, target, freezes and shakes.
  - `./pfx test` checks the core against fixtures from the JS core.
  - The only differences allowed are the last-bit ones between V8's and the C library's `sin`, `cos` and `atan2`, where they move
    a pixel.
- **Two buffers, as in the original.** `color` holds pixels: opaque, dithered, or truly translucent. `light` holds
  additive glow. Both are `PackedInt32Array`s with the same bytes as the JS `Uint32Array`s, so a frame is an
  `Image.FORMAT_RGBA8` away from the screen.
- **Seeded everything.** Every random number comes from the effect's seed, so frame 40 is the same every time.
- **Speed.** GDScript is far slower than V8's JIT. Most effects cost 0.2 to 20 ms a frame when played LIVE, and a few
  full-screen ones more. BAKED mode and SpriteFrames make that a one-time cost.

The method is [Hugo Duprez](https://x.com/HugoDuprez)'s, from [How to make (good) pixel art effects with
Claude](https://www.spritefusion.com/blog/how-to-make-good-pixel-art-effects-with-claude). His [open-source
effects](https://www.spritefusion.com/pixel-art-vfx) at Sprite Fusion set the bar.

## license

MIT, code and effects, like the original. Parts are adapted from Hugo Duprez's MIT effects and from Hollow Crown's MIT
source. The Patch Pixel font in `gallery/fonts` is Patch's own and not covered: see [NOTICE.md](NOTICE.md).

pixelfx is made by [Patch](https://patch.gg). The Godot port is by [winkidney](https://github.com/winkidney).
