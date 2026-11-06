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
[how the port works](#how-the-port-works) · [the original JS](https://github.com/patch-gg/pixelfx)

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
