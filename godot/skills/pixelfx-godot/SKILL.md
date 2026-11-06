---
name: pixelfx-godot
description: Pixel art effects and sprite animations for Godot 4 with the pixelfx library, ported to GDScript. It has 244 ready-made code-drawn effects (fire, explosions, water, ice, lightning, sci-fi, melee, impacts, projectiles, spawn and death, arcane, holy, shadow, status, nature, weather, UI, pickups, transitions, critters), and the ones with a character are acted out by one who winds up, freezes on contact and recovers. Covers playing effects with PixelFx2D or PixelFxAct2D nodes, recoloring, baking to SpriteFrames and sprite sheets, writing new effects in GDScript (draft, render, look, refine until they look hand-animated), and porting pixelfx effects or upstream updates from JS to GDScript. Use when someone wants pixel art VFX, game juice, hit effects or sprite animations in a Godot game, a specific effect ("a frost nova for my Godot mage", "a coin pickup sparkle"), SpriteFrames for an AnimatedSprite2D, or wants their Godot pixel effects to look better.
license: MIT
compatibility: Godot 4.4 or newer (tested on 4.7). Node 18+ is optional (only for parity checks against the upstream JS). ffmpeg is optional (GIF/MP4 previews).
---

# pixelfx for Godot

Pixel art effects as code. Each effect is one GDScript file, `addons/pixelfx/fx/<category>/<name>.gd`, that draws into
two buffers:
- **color**: pixels, opaque, dithered or truly translucent;
- **light**: additive glow.

There are no images, so an effect can be played live, recolored, mirrored, reseeded and baked to SpriteFrames. Every
effect is a line-for-line port of [pixelfx](https://github.com/patch-gg/pixelfx) and draws the same pixels as the
original.

The method is Hugo Duprez's ([How to make (good) pixel art effects with
Claude](https://www.spritefusion.com/blog/how-to-make-good-pixel-art-effects-with-claude)): code is clay, trust your
eyes, feed your references. One-shot prompts make mediocre effects. Drafts you render, look at and refine make good ones.

## Before anything

1. **Find a pixelfx-godot checkout.** Look for a `godot/pfx` script, or an `addons/pixelfx/` folder in the game. If there
   is none, clone one next to the project: `git clone https://github.com/winkidney/pixelfx-godot`.
   - The tools run inside its `godot/` project.
   - The game only needs the addon: copy `pixelfx-godot/godot/addons/pixelfx` to the game's `res://addons/pixelfx` and
     enable it in Project Settings > Plugins. Enabling it registers the `PixelFx2D` and `PixelFxAct2D` classes.
2. **Check it runs:** `cd pixelfx-godot/godot && ./pfx render fire/torch` writes `godot/records/fire/torch/contact.png`.
   - `pfx` finds Godot as `$GODOT`, `godot` or `godot4` on PATH, or `~/.local/bin/godot`.
   - Open that PNG with your image-reading tool. The contact sheet is how you see every effect from now on.

All commands below run from `pixelfx-godot/godot/`. `./pfx help` lists them.

## 1. Look for an existing effect first

`./pfx list <words>` searches ids, names, tags and descriptions (`./pfx list frost`, `./pfx list slash`).
`godot/docs/CATALOG.md` lists everything by category. Render the candidates and look at them before choosing.

Most requests are an existing effect with different options:

- **`palette`:** the main ramp, dark to bright. Use any `Px.PAL` ramp (fire ember lava smoke dust ice water electric volt
  poison holy heal arcane shadow blood earth stone gold leaf wood metal bone neon cyber matrix candy night) or your own
  colors. A blue fire is `palette_preset = "ice"` on the node, or `{"palette": Px.PAL.ice}` in code.
- **Variations:**
  - `seed` gives a different but equivalent take;
  - `flip` faces it left;
  - `fx_angle` rotates it on the pixel grid;
  - `light` (0..1+) sets the glow strength.
- **The effect's own knobs** are in its `meta.options` (size, count, radius, text, height...). Open its `.gd` to see them.
- **Try options without code:** `./pfx render fire/torch --opts '{"palette":["#102","#215","#43a","#8cf","#fff"]}'`.

## 2. Put it in the game

**The node** (the usual way):
- `PixelFx2D`: set `effect` (the id, with autocomplete in the inspector), `palette_preset` or `palette`, `seed`, `flip`
  and `options`.
- Its position is the effect's origin: the feet, the point of impact, the base of a torch.
- Pixels stay crisp because filtering is nearest.
- Light is drawn on an additive layer, so glow brightens whatever is behind it.

```gdscript
var fx := PixelFx2D.new()
fx.effect = "ice/frost-nova"
fx.palette_preset = "fire"          # optional recolor
fx.flip = hero.facing < 0
fx.free_when_done = true            # one-shots clean up after themselves
fx.position = hero.position
add_child(fx)                       # autoplay; fx.finished fires at the end; fx.stop() fades a loop out
```

- **Modes:**
  - `BAKED` (the default) renders each frame once, the first time it shows, and every node with the same effect and
    options shares the frames. Call `PixelFx2D.prebake("ice/frost-nova", opts)` at load time to make even the first play
    free.
  - `LIVE` renders every frame on the CPU at the game's frame rate. GDScript is much slower than JS: most effects cost
    0.2 to 20 ms a frame, and a few full-screen ones more. `./pfx check <id>` warns over 25 ms. Use LIVE for a handful of
    effects at a time, or for ones that must react while they play.
- **Behind and in front:** for something that wraps a character (a ring on the floor, an aura), use two nodes, one with
  `layer = BACK` under the character and one with `layer = FRONT` over it.

**SpriteFrames for an AnimatedSprite2D** (zero runtime cost, or for engines and tools that want images):
- `./pfx sheets <ids|category> --spriteframes` writes, under `godot/records/sheets/`:
  - `<id>.png`, a transparent sprite sheet;
  - `<id>.json`, Aseprite-style, whose `meta.pixelfx` holds fps, loop, frame size, columns, the pivot and act timing;
  - `<id>.res`, a ready SpriteFrames.
- In the editor, select a `PixelFx2D` and use Project > Tools > "pixelfx: Bake selected PixelFx2D to SpriteFrames".
- On the AnimatedSprite2D:
  - set `centered = false` and `offset = -pivot`;
  - set `texture_filter` to nearest;
  - play at the baked fps.

  Glow is baked in as color with alpha, which reads as additive over dark scenes.
- From code: `Baker.bake(mod, opts)` then `Baker.save_sprite_frames(...)`, with
  `const Baker := preload("res://addons/pixelfx/bake/baker.gd")`.

**Straight from code:** draw into your own buffers. This suits a custom renderer, a SubViewport, or effects composed
into one texture.

```gdscript
const Px := preload("res://addons/pixelfx/core/px.gd")
var frame := Px.createFrame(320, 180)                       # your pixel resolution
var inst := Px.createFx(load("res://addons/pixelfx/fx/ice/frost-nova.gd"), {"x": 160.0, "y": 140.0})
# every tick:
inst.update(delta)
frame.clear()
inst.draw(frame, "back")                 # behind characters
inst.draw(frame, "front")
var rgba := Px.composite(frame, PackedByteArray(), null)   # RGBA8 bytes: Image.create_from_data(320, 180, false, Image.FORMAT_RGBA8, rgba)
```

**A hit needs a body behind it.** An effect alone looks like a sticker. Effects with a character carry an `act`: when
the body winds up, when to freeze, how the target reacts.

- **With the stock character:** `PixelFxAct2D` (`effect = "melee/sword-slash"`) plays the character, the straw target,
  the freeze and the shake.
  - It emits `hit(info)` at each contact.
  - It shakes `shake_node` (a Camera2D), or itself.
  - `./pfx act <id> --sheet` bakes the whole act, character included, to a sprite sheet.
- **With the game's own character:** read the timing with `PixelFxAct2D.timing("melee/sword-slash")`. It gives
  `windup`, `recovery`, and `hits` with `t` and `freeze` (also in a sheet's JSON, under `meta.pixelfx.act`).
  - Start the attack animation `windup` seconds before the effect.
  - At each hit, stop updating the attacker, the target and the effect for `freeze` seconds. Hit-stop is the game's job
    and works with any effect:

```gdscript
func hit_stop(freeze: float, nodes: Array) -> void:     # e.g. [hero_anim, enemy_anim, fx]
	for n in nodes: n.speed_scale = 0.0                # AnimatedSprite2D, AnimationPlayer and PixelFx2D all have speed_scale
	await get_tree().create_timer(freeze, true, false, true).timeout
	for n in nodes: n.speed_scale = 1.0
```

`fx/moves/` has whole attacks chained from the effects, wind-up to recovery. Start there when someone asks for a move
rather than an effect.

## 3. Make a new one

Read `godot/docs/AUTHORING.md` first. It is the contract and covers:
- `static var meta`;
- `static func draw(p, t, o)` for pure effects, or a script extending `core/effect.gd` with `create/update/draw` for
  simulated ones;
- local coordinates, seamless loops, ending empty;
- the toolkit, the painter API and the quality bar.

Then:

1. **Say it in one line**, with art direction: what it is, how it moves, its palette, its timing. "A frost nova:
   crystals erupt in a ring from the feet outward, a white flash at the center, shards spin off, the floor stays frosted
   and fades."
2. **Find references** in the library.
   - `./pfx list <words>`, then read the two or three closest `.gd` files and borrow their techniques:
     - `Px.Particles` and `Px.Bits` for sparks, smoke and debris;
     - `p.disc` for translucent volumes;
     - `Px.cycle` for seamless particles;
     - `Px.tileFbm` scrolls for flames and water.
   - Look at the closest of [Hugo Duprez's effects](https://www.spritefusion.com/pixel-art-vfx) too: they are the quality
     bar.
3. **Draft.** `./pfx new <category>/<name>` gives a working file (`--loop` for a loop, `--sim` for particles). When the
   direction is open, write 3 to 5 genuinely different drafts (`<name>-a` .. `-e`), render them all
   (`./pfx render "<category>/<name>-*"`) and look at every contact sheet before choosing. If the user is around, show
   them the strongest two or three (`--gif`).
4. **Look, judge, fix.** Render, open `godot/records/<id>/contact.png`, and judge like a picky pixel artist. Fix the
   worst thing and render again. Three rounds minimum; a showpiece takes more. `--all` shows every frame, `--mp4` shows
   motion.
5. **Act it out** if a character is involved: add `static var act` (see "Acts" in AUTHORING.md) with a wind-up before
   t = 0, a pose change on the release frame, a freeze on contact and a recovery. `./pfx act <id>` shows consecutive
   12 fps steps. Judge motion from those and from `--mp4`.
6. **Check.** Run `./pfx check <id>` and fix until it passes clean. It catches:
   - drawing outside the canvas;
   - one-shots that don't end empty;
   - loop seams;
   - unseeded randomness;
   - slow frames;
   - act mistakes.

   Then `./pfx index` adds it to the registry and catalog. Delete the drafts you didn't keep.

GDScript traps the project turns into errors on purpose:
- integer division (write `/ 2.0`);
- assigning to a variable a lambda captured (lambdas capture by value: keep the state in a member or an Array);
- `var x := dict.key` (Variant inference: write `var x: float = dict.key`).

Use `Px.round` instead of `round` and `fmod` for float `%`. Never `randf()`: use `Px.Rng.new(o.seed)`, `Px.rng(seed, i)`
or `Px.cycle`.

What to look for, and the usual fix:

| you see | fix |
|---|---|
| it reads as mush at 1x | fewer colors, a clear silhouette, one focal point, bigger shapes |
| speckle: lone noise pixels inside shapes | threshold noise less, quantize with `Px.at()`, no noise on small shapes |
| floaty, no punch | fast in, slow out (`Px.Ease.outQuart`/`outExpo`), a 1 to 2 frame white hero frame, shorter total time |
| stiff or mechanical | vary every particle (size, speed, delay, life), add secondary motion (sparks, smoke, debris) |
| washed out | less glow (k 0.2 to 0.5), darker edge steps, keep white for the hottest core only |
| flat | light from one side: brighter top-left, darker bottom-right step; a darker ramp step at the base |
| smooth gradients, vector look | hard ramp steps in color; softness only in light and in translucent smoke |
| a checkerboard where smoke should be | `P.SMOKE`, `P.VAPOUR` or `P.DUST` particles, or `p.disc`: truly translucent, lit on top |
| seam when a loop wraps | `Px.cycle`, `Px.loopNoise(phase)`, whole-cell `Px.tileNoise` scrolls, `sin(phase * TAU * n)` |
| a one-shot that pops off | let it shrink, dither out or fall away before t = duration |
| a great effect on a dead character | give it an act: wind-up, release pose, freeze on contact, a target that reacts, recovery |
| the act feels weightless | a wind-up the opposite way to the blow, a longer freeze (up to 0.2 s), a bigger silhouette change, shake |
| the hit lands out of sync | move the hit key to the effect's own constant, not to a time you eyeballed |
| he holds the weapon badly | keep a bend in the elbow, shafts in front of the chest; on a swing the blade lags the hand; arms reach about 15 px, so step the body in |
| too slow in LIVE mode | play it BAKED; or precompute per-effect tables once (static vars), avoid allocating Arrays per pixel |

**Effect rules:**
- Directional effects face right.
- Ground effects stand on y = 0.
- Actor effects wrap `o.actor`, a 24 x 38 stock character's mask and pixels.
- Generic motifs are fine. Never recreate a specific game's sprites, characters or logos.

## 4. Port from upstream, or port an upstream change

The JS original sits in the same repo (`src/fx/<category>/<name>.js`), and each `.gd` names the JS blob it was ported
from. To bring in upstream work, follow `godot/docs/UPSTREAM.md`:
`git fetch upstream && git merge upstream/main`, then `node godot/port/sync.mjs`, which lists stale and missing ports.

For each file it lists:

1. **Read `godot/docs/PORTING.md`.** It is the contract. The port is line for line: same names, same expression shapes,
   same order of random draws. Each rule in it broke a port once.
2. **Port it.**
   - A stale file: apply `git diff <old-blob> <new-blob>` (printed by `sync.mjs`) to the `.gd`.
   - A new file: port it whole, next to its closest existing port.
3. **Prove it:** `./pfx parity <id> --full` (plus `--acts` when it has an act).
   - `ok` means identical; `ok~` means a few pixels off, within tolerance.
   - `FAIL` names the first differing frame and whether the random streams diverged, and writes a JS | GODOT | DIFF
     sheet under `godot/records/parity/`. Open it.
   - Fix the first difference; the rest usually follow.
4. **Stamp it:** `node godot/port/sync.mjs --stamp <id>`. Then `./pfx index`, and commit.

The core (`addons/pixelfx/core/*.gd`) ports `src/core/*.js` the same way. `./pfx test` checks it against fixtures from
`node godot/port/ref.mjs --fixtures`.
