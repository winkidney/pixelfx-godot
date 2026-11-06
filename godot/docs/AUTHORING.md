# Writing an effect (Godot)

An effect is one GDScript file, `godot/addons/pixelfx/fx/<category>/<name>.gd` (kebab-case, like its id
`<category>/<name>`). It draws pixel art over time into two buffers. It has no images and no dependencies beyond
`addons/pixelfx/core`, so it can be played live, recolored, mirrored, baked to SpriteFrames and rendered to a sprite
sheet.

The quality bar is Sprite Fusion's open-source pixel art VFX by Hugo Duprez
([spritefusion.com/pixel-art-vfx](https://www.spritefusion.com/pixel-art-vfx), MIT). Every effect should hold up next
to his at the same size on screen: as much detail, as much light, as much life. `core/sim_*.gd` is adapted from his code.
Read the three references written to that bar first: `fx/melee/sword-slash.gd`, `fx/ice/frost-nova.gd`,
`fx/explosions/small-explosion.gd`.

Effects ported from upstream JS follow [PORTING.md](PORTING.md) to the letter. Effects you write yourself follow this
file. Keep the same shape, so anyone can read either.

## Two kinds of effect

**Simulated** (most one-shots: impacts, explosions, spells, anything with debris, sparks, smoke or fire). The script
*is* the effect's state:
- extend `core/effect.gd`;
- keep state in member variables;
- spawn particles, debris and lights in `create(o)` and `update(dt)`;
- draw from state in `draw(p)` and `drawBack(p)`.

The runtime steps it at 120 Hz or finer, so physics looks the same at any frame rate. Use the seeded `Px.Rng` from
`o.seed` for every random number.

```gdscript
extends "../../core/effect.gd"

const Px := preload("../../core/px.gd")
const P := Px.P

static var meta := {"name": "Spark pop", "desc": "...", "tags": ["impact"], "size": [96, 72], "origin": [48, 56],
	"duration": 1.2, "loop": false, "fps": 30, "bg": "ground", "options": {"palette": Px.PAL.volt, "seed": 1}}

var C: Array
var R: Px.Rng
var ps: Px.Particles
var lights: Px.Lights
var t := 0.0

func create(o: Dictionary) -> void:
	C = Px.fit(o.palette, 7)
	R = Px.Rng.new(o.seed)
	ps = Px.Particles.new({"rng": R, "ground": func(_x): return 0.0})
	lights = Px.Lights.new()
	lights.add(0, -12, 40, C[4], 0.7, 0.4)
	for i in 40:
		var a := R.range(0.0, TAU)
		var sp := R.range(80.0, 260.0)
		ps.spawn(P.SPARK, 0, -12, cos(a) * sp, sin(a) * sp - 60.0, R.range(0.2, 0.6))

func update(dt: float) -> void:
	t += dt
	ps.update(dt)
	lights.update(dt)

func draw(p: Px.Painter) -> void:
	if t < 0.12:
		Px.sparkle(p, 0, -12, 9.0 * (1.0 - t / 0.12), C[5], C[3])
	ps.draw(p)
	lights.draw(p)
```

**Pure** (loops, and shapes that are a function of time: auras, portals, waterfalls, beams, critters).
`extends RefCounted` and write `static func draw(p: Px.Painter, t: float, o: Dictionary) -> void`, plus `drawBack` if
needed. It draws the frame at `t` from `t` alone, so it loops with no seam:
- particles that loop come from `Px.cycle`;
- motion comes from `Px.fly`;
- noise comes from `Px.loopNoise` or `Px.tileFbm`.

## The contract

- **Scale.** The stock character is 24 x 38 px (`"actor": 2`), and every effect is drawn at that scale, with detail at
  the 1 px level. Canvases are as big as the effect needs, often 96 to 320 px wide. Transitions are 320 x 180.
- **Local coordinates.** (0, 0) is the anchor: the feet of the character, the point of impact, the base of a torch, the
  muzzle.
  - x is right, y is down, and 1 unit = 1 px.
  - The painter places, mirrors (`flip`) and rotates (`angle`), so directional effects face right.
  - Ground effects stand on y = 0, the floor. Floor rings, cracks, scorch marks and puddles may draw a little below it, as
    perspective.
- **Time.** One-shots run from 0 to duration and draw **nothing at t = duration**: make the duration long enough for the
  last smoke to clear. Loops are seamless.
- **Options** `o` are `meta.options` merged with the caller's options. Whole numbers arrive as floats.
  - Honour `o.palette` (the main ramp, dark to bright). Use `Px.fit(o.palette, n)` so any length works.
  - Honour `o.seed`.
  - Other color-ramp options are resampled too.
  - `x`, `y`, `flip`, `angle` and `light` are reserved.
- **Deterministic.** Never use `randf`, `randi`, `RandomNumberGenerator` or `Time`. `./pfx check` catches them.
- **Layers.** `drawBack` is for what goes behind a character or the far half of a ring. `draw` is for the rest.
- **Actor effects** (`"actor": 2`) get `o.actor`:
  `{ mask: { w, h, data: PackedByteArray, id }, pixels: PackedInt32Array, x, y, w, h, head, chest }`. That is the
  character's silhouette and its own colors in local space, feet at (0, 0).
  - Recolor `pixels` for frozen, poisoned or stone.
  - Outline `mask` for auras.
  - Write `static func actorAlpha(t, o) -> float` (0..1) when the character should vanish or appear; previews follow it.
- **Acts** (`static var act := {...}`) say what the body does around the effect. Any effect with a character should have
  one; see below.
- **Credit.** If you adapt a specific recipe from one of Hugo's files, put a two-line credit at the top of yours:
  `# ... adapted from Sprite Fusion's open-source <name> (https://www.spritefusion.com/pixel-art-vfx/<name>),`
  `# MIT License, Copyright (c) 2026 Hugo Duprez.`

## Acts

An effect shows what the magic does; its act shows what the character does. Without one, the best effect looks like a
sticker on a mannequin.

```gdscript
static var GUARD := Px.merge(Px.READY, {"weapon": "sword", "fx": 12, "fy": -19, "sa": -0.75})
static var COCK := Px.merge(GUARD, {"crouch": 4, "lean": -4, "fx": -9, "fy": -33, "sa": -2.7, "bx": 9, "by": -22, "armsFront": true})
static var CUT := Px.merge(GUARD, {"crouch": 4, "lean": 5, "fx": 24, "fy": -19, "sa": 0.6, "ffx": 13, "fbx": -10, "ghost": 1})

static var act := {
	"target": {"x": 58},                              # or "targets": [{"x": 58}, {"x": 104}]
	"poses": [[-0.5, GUARD], [-0.2, COCK], [0.06, CUT, "snap"], [0.7, GUARD]],
	"hits": [{"t": 0.06, "stop": 0.14, "shake": 0.18, "amp": 2, "push": 2.8, "straw": 18, "skin": "char"}],
	"dust": [{"t": 0.06, "x": 12, "n": 6, "dir": 1}],
}
```

- **Time** is the effect's own. t = 0 is its first frame, so a negative key is a wind-up. A one-shot's act runs to its
  last key, which may come after the effect has ended. A loop's keys run from 0 to `duration` and match at both ends.
- **Poses** only say what differs from standing easy. `core/poses.gd` and `src/core/poses.js` list every field and
  explain how the body works.
  - Hands and feet are placed where they should end up, in px from the feet, and the skeleton solves the rest.
  - Between keys, limbs step at 12 fps.
  - How a key is reached: `"snap"` holds the last pose and jumps on the key, `"out"` arrives fast and settles, `"in"`
    starts slow, and `"line"` keeps a steady speed.
- **Hits** freeze everything for `stop` seconds and shake it by `amp` px for `shake` seconds. The target takes:
  - `push` (negative rocks it towards the caster);
  - `straw`, `flash` and `shiver`;
  - a `skin`: char, ice, shock, holy, shadow, red or poison; `null` clears it.

  `at` picks one of several targets, and `"target": false` leaves them out of it.
- **Weapons:** `sword greatsword dagger spear hammer scythe claw bow pistol launcher handle`. `"two": true` puts both
  hands on it.
- **`"onBody": true`** when the effect reads `o.actor`. Draw against the standing body as usual: frost, poison and scan
  lines follow the pose.
- **What sells it:** a wind-up in the opposite direction to the blow, a big silhouette change on the release frame, a
  freeze on contact (0.03 to 0.2 s), and a follow-through that overshoots.

Judge acts by their motion. `./pfx act <id>` shows consecutive 12 fps steps, and `--mp4` plays them. `./pfx check`
catches keys out of order, unknown pose fields, loop seams and hands that teleport.

**Moves** (`fx/moves/`) are effects made of effects. `Px.chain` plays other effects as cues. A projectile is an effect
whose `x` is a function of time.

```gdscript
const Charge := preload("../arcane/spell-charge.gd")
const Fireball := preload("../fire/fireball.gd")
static var CHAIN := Px.chain([
	{"fx": Charge, "t": 0.08, "until": THROW, "palette": Px.PAL.fire},
	{"fx": Fireball, "t": THROW, "until": HIT, "x": func(t): return 28.0 + (t - THROW) * SPEED, "y": -22.0},
])
static func create(o: Dictionary): return CHAIN.create(o)
```

## The toolkit

Everything is `Px.<name>`. Constants and kinds are `Px.P`, `Px.PF` and `Px.B`.

- **Particles:** `Px.Particles.new({"rng": R, "ground": func(x): return floor_y, "sparks": [...], "haze": c, "onLand": func(x, y): ...})`.
  - Spawn with `ps.spawn(kind, x, y, vx, vy, life, color, size, delay, flags)`, then call `ps.update(dt)` and
    `ps.draw(p, "back"|"front")`.
  - The kinds are `SPARK MOTE STREAK FLAKE VAPOUR DUST SMOKE FIRE BRAND GRIT EMBER STAR`. `src/core/sim.js` and
    `core/sim_particles.gd` describe each.
- **Debris:** `Px.Bits.new({"ground": f})`, then `bits.add({"kind": Px.B.SHARD, "x": .., "y": .., "vx": .., "vy": .., "a": .., "va": .., "s": .., "c": .., "life": ..})`.
  Debris tumbles, bounces and settles.
- **Lights:** `Px.Lights.new()`, then `lights.add(x, y, r, color, k, life)`. Lights flare and die.
- **Blazes:** `Px.Blazes.new(ps)`, then `blazes.add(x, y, life, power)`. Small fires that keep feeding flame where
  something landed.
- **Drawing helpers:**
  - `Px.sparkle(p, x, y, arm, c, tip, k)`: a star glint.
  - `Px.flare(p, x, y, L, k, ramp)`: an 8-ray flare.
  - `Px.band(p, cx, cy, r, sy, thick, alpha, ramp, keep, hot)`: a ring on a tilted plane.
  - `Px.crystal(p, x, base, h, w, lean, ramp, {"a": .., "white": .., "glint": ..})`: a faceted crystal spike.
- **Units.** `Px.GRAVITY` is 950 px/s². Hugo's code uses world units (2 per px), so halve his speeds, distances and
  gravity.

## Painter API

Coordinates are local, and floats are fine. `c` is a color int (`Px.hex("#ff8800")`, a ramp step, `Px.WHITE`). `a` is
alpha 0..1, dithered unless noted.

| call | draws |
|---|---|
| `p.px(x, y, c)` / `p.dot(x, y, c, a)` | one pixel, solid / dithered |
| `p.blend(x, y, c, a)` | one pixel, truly translucent |
| `p.disc(x, y, r, c, a)` | translucent disc (smoke, vapour, mist); c, a may be `func(d, angle)` |
| `p.line(x0, y0, x1, y1, c, a)` | 1 px line; c, a may be `func(u)` |
| `p.polyline(pts, c, a)`, `p.beam(x0, y0, x1, y1, w, c, a)` | lines through points; thick capsule |
| `p.circle`, `p.ellipse`, `p.ring`, `p.rect`, `p.poly`, `p.tri` | filled shapes; c, a may be Callables of the shape's coordinates |
| `p.arc(x, y, r, w, a0, a1, c, a)` | band of a ring, `w` may taper (`func(u)`) |
| `p.shade(x0, y0, x1, y1, func(x, y, out): ...)` | per-pixel shader: return a color or set `out.c out.a out.l out.k` |
| `p.glow(x, y, r, c, k)`, `p.glowLine`, `p.glowRing`, `p.light(x, y, c, k)` | additive light |
| `p.sprite(rows, pal, x, y, {"scale": 2, "a": 1, "flip": true, "flipY": false, "tint": c})` | sprite from strings |
| `p.text(str, x, y, c, {"font": "mini"\|"big", "scale": 2, "align": "center", "outline": c, "shadow": c, "a": 1})`, `p.measure` | pixel text |
| `p.mask(m, x, y, c, a)`, `p.outline(m, x, y, c, a)`, `p.getc(x, y)` | silhouettes; read back a pixel |

## The bar

What makes Sprite Fusion's effects good, and what every effect here must do:

1. **Lines and light, not fills.** Build with 1 px rims, rings, trails and sparks, and let light carry the brightness.
   White-hot cores and edges, tinted middles, deep color only in shadow.
2. **Light everywhere.** A big soft pool at low k, a tight hot one at the core, a light on every spark and glint,
   `Lights` that flare at impact and fall away, light along arcs and beams, a pool on the floor.
3. **Translucent volumes.** Smoke, vapour, dust and mist are soft (`SMOKE`, `VAPOUR`, `DUST`, `p.disc`), lit on top,
   swelling and thinning. Never use a dithered checkerboard for smoke.
4. **Real motion.** Sparks stretch with speed, fall and bounce. Debris tumbles and settles. Fire rises and cools into
   smoke. Things that land kick up dust. Fast burst, slow drift.
5. **Choreography in phases.** Anticipation, then release (a 1 to 2 frame white hero frame), then spread, hold, break,
   and a long decay. Many small events, each varied.
6. **Depth.** Rings on the floor are flat ellipses: the far half goes behind the character, the near half in front. Back
   rows are dimmer.
7. **Timing.** Fast attack, slow release. Big effects linger 2 to 4 s; hits are snappy (0.3 to 0.8 s) but follow
   through.
8. **Reads at 1x**, with a clear focal point and no speckle noise inside shapes.
9. **Original.** Generic motifs are fine. Never a specific game's sprite, character or logo.
10. **Clean.** It fits its canvas, ends empty or loops clean, and is deterministic. `./pfx check` passes.

## The method

Hugo Duprez's method ([How to make (good) pixel art effects with
Claude](https://www.spritefusion.com/blog/how-to-make-good-pixel-art-effects-with-claude)): code is clay, trust your
eyes, feed your references.

1. **Reference first.** Find the closest effect in the library (`./pfx list <words>`) and the closest of
   [his](https://www.spritefusion.com/pixel-art-vfx).
2. **Say it in one line** with the art direction, then draft: `./pfx new <category>/<name>` (`--loop`, `--sim`).
3. **Render and look.** `./pfx render <id> --zoom 3` writes `records/<id>/contact.png`. `--all` shows every frame,
   `--gif` and `--mp4` show the motion.
4. **Fix the worst thing, render again.** Three rounds minimum; showpieces take more.
5. **Act it out** if there's a character: `./pfx act <id>`.
6. **Check:** run `./pfx check <id>` until it passes clean, then `./pfx index` to list it in the registry and catalog.
