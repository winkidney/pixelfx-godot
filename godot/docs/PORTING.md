# Porting an effect from JS to GDScript

Every effect in `src/fx/<cat>/<name>.js` has a twin at `godot/addons/pixelfx/fx/<cat>/<name>.gd`. Each `_lib.js` has one too
(`_lib.gd`). The port is **line for line**: same names, same order, same expressions. That keeps upstream diffs easy to
apply, and it gives identical pixels. `./pfx parity` checks this: the Godot frames must match the JS frames, hash for hash,
in eight variants (default, flip, angle, 4-step palette, recolor, seed, light, stop).

Look at `fx/melee/sword-slash.gd` next to `src/fx/melee/sword-slash.js` before you start. It is the reference.

## The loop

```bash
cd godot
./pfx parity melee/sword-slash          # quick: default, flip, pal4, seed7
./pfx parity melee --full               # every variant, every effect of the category
```

- `ok` means identical.
- `ok~` means a few pixels differ, within tolerance. That's fine.
- `FAIL` prints which frames differ and where the RNG streams split. It also writes a JS | GODOT | DIFF sheet to
  `records/parity/<cat>-<name>.<variant>.png`. Open it.

The reference data is produced by `node port/ref.mjs` from the upstream JS. The parity command runs it by itself when it's
missing or stale.

When the RNG trace differs, the effect drew random numbers in a different order or a different number of times. Look for:
- a reordered expression;
- a `for` loop with a different count;
- an `if` that went the other way.

Fix the first frame that differs. The rest usually follow.

## File shape

```gdscript
# <the JS file's header comment, kept>
# port-of: src/fx/<cat>/<name>.js@<git hash-object of that file>
extends RefCounted                 # pure effect;  extends "../../core/effect.gd" for a simulated one

const Px := preload("../../core/px.gd")
const Lib := preload("_lib.gd")    # the category's helpers, if the JS imports ./_lib.js
const P := Px.P                    # optional aliases for what the JS imports by name

static var meta := { "name": ..., "desc": ..., "tags": [...], "size": [w, h], "origin": [x, y],
	"duration": 1.2, "loop": false, "fps": 30, "bg": "ground", "options": { "palette": [...], "seed": 1 } }
static var act := { ... }          # if the JS exports act
```

- **Pure effect** (JS `export function draw(p, t, o)`):
  `static func draw(p: Px.Painter, t: float, o: Dictionary) -> void`, plus `static func drawBack(...)` if the JS has one.
  JS `actorAlpha(t, o)` becomes `static func actorAlpha(t: float, o: Dictionary) -> float`.
- **Simulated effect** (JS `export function create(o)` returning `{ update, draw, drawBack }`): the script is the state.
  - Use `extends "../../core/effect.gd"`.
  - Every local of `create()` that a returned function reads becomes a member `var`.
  - The body of `create` goes in `func create(o: Dictionary) -> void`.
  - The returned functions become `func update(dt: float) -> void`, `func draw(p: Px.Painter) -> void` and
    `func drawBack(p: Px.Painter) -> void`.
  - Locals only `create` itself uses stay locals.
- **Move** (JS `export const create = chain([...])`):
  `static var CHAIN := Px.chain([...cues as Dictionaries...])` and
  `static func create(o: Dictionary): return CHAIN.create(o)`. Another effect is imported as
  `const Fireball := preload("../fire/fireball.gd")` and used as `"fx": Fireball` in a cue.
- **Module-level code:**
  - JS `function`s become `static func`, with the same name and parameters.
  - `const` holding a literal or a pure expression becomes `const` when GDScript accepts it, otherwise `static var`.
  - Caches (`let x = null`, `new Map()`, `new WeakMap()`) become `static var x := {}` or similar.
  - Static vars initialise in file order.
- **`_lib.gd`:**
  - `export function` becomes `static func`.
  - `export const` becomes `const` or `static var`.
  - `export class X` becomes an inner `class X extends RefCounted:`. To subclass the painter, write
    `class Clipped extends Px.Painter:` and override `put/add/blendPx` with the same signatures. Inner classes do
    **not** see their script's static funcs or vars. Add `const Self := preload("_lib.gd")` at the top and call
    `Self.helper()`. Consts (like `Px`) they do see.
  - A painter wrapper made with `Object.create(p)` (weather's `clip`) becomes such a subclass, built over `p.frame`
    and given p's placement (`tx ty fx cs sn fade lightK layer`).

## The core, from GDScript

Everything the JS imports from `core/index.js` is `Px.<same name>`:

| JS | GDScript |
|---|---|
| `clamp lerp seg smooth bump fract wrap invLerp remap dist angleTo` | `Px.clamp(x)`, etc. (defaults as in JS) |
| `ease.outExpo(t)` | `Px.Ease.outExpo(t)` |
| `Math.round(x)`, `Math.hypot(a, b)`, `Math.sign(x)` | `Px.round(x)`, `Px.hypot(a, b)`, `Px.sign(x)` (JS-exact; `Px.roundi` for an int) |
| `TAU`, `Math.PI` | `TAU`, `PI` (built in) |
| `rand(a, b, c)`, `rng(a, b)`, `hash(...)`, `new Rng(s)` | `Px.rand(a, b, c)`, `Px.rng(a, b)`, `Px.hash(...)`, `Px.Rng.new(s)` (1 to 6 args) |
| `R.range R.chance R.pick R.sign R.next R.gauss`, `R.int(a, b)` | the same, but **`R.int_(a, b)`** |
| `noise noise2 fbm tileNoise tileFbm loopNoise` | `Px.noise(...)`, etc. |
| `fly(...)`, `flyV(...)` | `Px.fly(...)`, which returns `[x, y]` |
| `burst cycle stream` | `Px.cycle(t, period, n, seed, life, func(age, life, r, i): ...)` (the lambda may take fewer args) |
| `bolt forks star ngon trail` | `Px.bolt(r, x0, y0, x1, y1, {"jag": 0.3})`, etc. |
| `PAL RAMP ramp fit at blend mix scale hex rgb luma toHex WHITE BLACK INK` | `Px.PAL.fire`, `Px.fit(o.palette, 7)`, `Px.WHITE`, etc. |
| `red green blue`, `c >>> 24` | `Px.red(c)` …, `Px.alpha(c)` or `(c >> 24) & 255` |
| `Particles P PF Bits B Lights Blazes GRAVITY FIRE_RAMP SMOKE_RAMP` | `Px.Particles.new({...})`, `Px.P.SPARK`, `Px.PF.BACK`, `Px.Bits.new({"ground": f})`, `Px.B.SHARD`, `Px.Lights.new()`, `Px.Blazes.new(ps)` |
| `sparkle flare band crystal` | `Px.sparkle(p, ...)`, etc. (a `keep` for `band` is a lambda) |
| `createFrame clearFrame painterFor composite`, `new Painter(f)` | `Px.createFrame(w, h)`, `f.clear()`, `Px.painterFor(f)`, `Px.Painter.new(f)` |
| `FONTS textWidth`, `rasterText` | `Px.fonts()`, `Px.textWidth(s, font)`, `Px.PixelFont.rasterText(s, font, func(x, y): ...)` |
| `stockActor drawActor` | `Px.stockActor(2)`, `Px.drawActor(p, actor, a)` |
| `READY chain shiftKeys shiftHits` | `Px.READY`, `Px.chain([...])`, `Px.shiftKeys(keys, dt, {"dx": 3})`, `Px.shiftHits(...)` |
| `{ ...A, x: 1 }` | `Px.merge(A, {"x": 1})` |
| `Array.from({ length: n }, (_, i) => f(i))` | `Px.arr(n, func(i): return f(i))` |
| `list.sort((a, b) => a.z - b.z)` | `Px.sort(list, func(a, b): return a.z - b.z)` (stable, like JS; never `sort_custom`) |

The painter keeps every JS method and member name, with one rename: `p.get(x, y)` is **`p.getc(x, y)`**. Arguments are the
same:
- A color or alpha that is a JS function is a lambda: `p.circle(x, y, r, func(d, ang): return Px.at(R, 1.0 - d))`. It may
  declare fewer parameters than the painter passes.
- `p.shade(x0, y0, x1, y1, func(x, y, out): ...)` sets `out.c`, `out.a`, `out.l` and `out.k`, or returns a color.
- `p.text(str, x, y, c, {"font": "big", "scale": 2, "align": "center", "outline": col})`.
- `p.sprite(rows, pal, x, y, {"flip": true})`.
- Raw writes are `p.put(sx, sy, c, a)`, `p.add(sx, sy, c, k)`, `p.blendPx(...)` and `p.each(x0, y0, x1, y1, func(lx, ly, sx, sy): ...)`.
- The buffers are `p.C` and `p.L`, and the placement is `p.tx p.ty p.fx p.cs p.sn p.ox p.oy p.w p.h`.

`o.actor` is
`{ "mask": { "w", "h", "data": PackedByteArray, "id" }, "pixels": PackedInt32Array, "x", "y", "w", "h", "k", "head", "chest", "eyes" }`.
Key caches by `a.mask.id`, not by the mask itself.

## Rules (each one has broken a port)

**Numbers**
1. **Division.** `/` between two ints truncates in GDScript. Write float literals (`/ 2.0`), or wrap one side in `float()`.
   Options come in as floats: `resolveOptions` turns whole numbers into floats. Literals in your own data don't, so write
   numbers you divide or scale as floats (`"W": 12.0`).
2. **Float `%` is `fmod(a, b)`.** GDScript `%` is for ints only. `(x % m + m) % m` is `fmod(fmod(x, m) + m, m)` or
   `Px.wrap(x, m)`.
3. **`Math.round` is `Px.round`** (halves go up). GDScript's `round()` rounds halves away from zero.
   `Math.floor/ceil/abs/min/max` are `floorf/ceilf/absf/minf/maxf` on floats. Use `floori` when you need an index.
4. **Indices must be ints.** Write `R[int(x)]` and `R[floori(t * n)]`. A float index errors.
   - `arr[-1]` is *undefined* in JS but the last element in GDScript. Guard it the way the JS behaves.
   - Out of bounds is undefined in JS but an error here. Guard it.
5. **Bit ops need ints.**
   - JS truncates the operands: `x & 3` is `int(x) & 3`.
   - `x | 0` is `Px.i32(x)`, or `int(x)` when it's small.
   - `x >>> 0` is `Px.u32(x)`.
   - `c >>> 24` is `(c >> 24) & 255`.
   - `Math.imul` is `Px.imul`.
6. **Keep the expression shape.** `a * b * c` is `(a * b) * c` on both sides. Don't simplify, factor or reorder floating
   point math: one ulp is a different pixel.
7. **Random draws stay in the same order.** GDScript evaluates arguments and operands left to right, like JS. Never hoist
   or reorder `R.range(...)` calls, and keep loop counts identical.
8. **Never use Vector2/Vector3 for math.** They are 32-bit. Use floats, and `[x, y]` arrays where the JS returns arrays.
9. **Typed vars from Variants.** `var x := dict.key` is an error (Variant inference). Write `var x: float = dict.key`, or an
   untyped `var x = dict.key`.

**Values and truthiness**
10. **`a || b` as a value** is `a if a else b`. **`a && b` as a value** is `b if a else a`. GDScript `or` and `and` return
    bools. Color `0` means "nothing", so `fn() || out.c` matters.
11. **`a ?? b`** is `a if a != null else b`. For an option, write `o.get("k", d)` when null is never passed explicitly.
    **`x?.y`** is `x.y if x != null else null`. `typeof f === "function"` is `f is Callable`.
12. **Colors.**
    - `Px.hex`, `Px.rgb` and the ramps give *signed* ints, as in JS.
    - A JS `Uint32Array` read is unsigned. When you read a pixel from `p.C`, `p.L`, `o.actor.pixels` or a buffer of your
      own and **compare it or use it as a key**, mask it: `p.C[i] & 0xFFFFFFFF`.
    - Writes need nothing.

**Closures**
13. **GDScript lambdas capture locals by value.**
    - A lambda that assigns to a captured local changes its own copy. Strict warnings turn that into an error.
    - Keep that state in a member, a Dictionary, or a one-element Array.
    - A lambda may *read* captured locals and call methods. Watch for JS closures that read a variable assigned *after*
      the closure was made: `onLand` using `blazes` in small-explosion. Make it a member and assign it before it's used.
14. **A local arrow function** becomes a lambda you call with `.call(...)`, or a `static func` taking what it captured.
    Recursive ones must be `static func`.

**Collections**

| JS | GDScript |
|---|---|
| `arr.length` | `.size()` |
| `push(a, b)` | two `append`s |
| `splice(i, 1)` | `remove_at(i)` |
| `pop()` / `shift()` | `pop_back()` / `pop_front()` |
| `slice(a, b)` | `slice(a, b)` |
| `indexOf` / `includes` | `find` / `in` |
| `concat` | `+` |
| `map(f)` | `map(f)` — **the lambda gets the value only**; index-using maps become loops |
| `forEach((v, i) => …)` | `for i in arr.size()` |
| `filter` | `filter` |
| `reduce((acc, v) => …, init)` | `reduce(func(acc, v): …, init)` |
| `some` / `every` | `any` / `all` |
| `Math.max(...arr)` | `arr.max()` |
| `reverse()` | `reverse()` — returns nothing; copy first if the JS uses the result |

- **Typed arrays:**

  | JS | GDScript |
  |---|---|
  | `Float32Array` | `PackedFloat32Array` (keeps the float32 rounding) |
  | `Float64Array` | `PackedFloat64Array` |
  | `Uint8Array` | `PackedByteArray` |
  | `Int8Array`, `Int16Array`, `Uint32Array` | `PackedInt32Array` (see rule 12) |

  Set the size with `resize(n)`. Fill with `fill(v)`.
- **`Map`** becomes a `Dictionary`, which keeps insertion order as Map does. **`Set`** becomes a `Dictionary` of `true`.
- **Objects** (particles, records) stay Dictionaries with string keys. `d.key` reads and writes them, and `d.newKey = v`
  works.
- **Template-literal keys** become `"%d,%d" % [x, y]` or `str(x) + "," + str(y)`.

**Control flow**
15. **Float loops become `while` loops.** `for (let d = 0; d <= L; d += 0.5)` becomes
    `var d := 0.0` / `while d <= L:` / `...` / `d += 0.5`. Put the increment wherever a `continue` would skip it.
    `for (let i = 0; i < n; i++)` becomes `for i in n` when n is a whole number, otherwise a `while`.
16. **`switch` becomes `match`.** There is no fallthrough: combine cases (`1, 2:`). A `break` inside a `for`-in-`switch`
    becomes `continue` when it ends the iteration.
17. **Comma expressions** `(a = 1), (b = 2)` and `x = i++` become separate statements, in the same order.
18. **Callbacks into the core** must take the arguments the JS passes, or fewer:
    - painter color and alpha;
    - `cycle`, `stream` and `burst`;
    - `Particles` `ground` and `onLand`;
    - `Bits` `ground`.

    Callbacks between your own functions must match exactly: GDScript rejects extra arguments.

## Before you call it done

- `./pfx parity <cat> --full` shows `ok` or `ok~` for every effect.
- Any `FAIL` you can't fix is explained in your report: the first differing frame, what the diff sheet shows, and why
  you think it's not the port (for example libm `sin` ulps flipping a branch). Only the lead adds entries to
  `port/parity-allow.json`.
- Every file starts with its `port-of:` line. Get the hash with `git hash-object src/fx/<cat>/<name>.js`.
- Nothing outside `addons/pixelfx/fx/<your category>/` is changed. If the core is wrong or missing something, say
  exactly what (file, function, JS line) and port around nothing. The lead fixes the core and re-runs.
