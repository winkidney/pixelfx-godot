# Shared by the transitions build scripts (not an effect). The originals (src/fx/transitions/*.js) are 320 x 180
# screen wipes drawn through _lib.js: a mask covering the screen in o.color, lit rims and light, glints (_lib.js
# glint), and particles from sim.js. Here:
#   - the mask and its light are canvas shaders over the whole screen (fx/transitions/_<name>.gdshader and
#     _<name>_light.gdshader) running the original's per-pixel rules on the clock the reference draws at (screen());
#   - small marks the original draws on its own beats (glints, sparkles, flares, specks, dashes, block outlines) are
#     frame-table particles (marks(): fx/pickups/_ftp.gdshader places them, _marks.gdshader draws them, with a light
#     twin);
#   - the original's sim.js particles are replayed from its own generator at its 120 Hz steps (replay(), spawn()) and
#     become emitters through the scifi ghosts (fx/scifi/_ghost.gdshader: the original's physics from each birth);
#   - Lights.add flashes are light_add() glows.
# Extends the pickups helpers (frame clock ft(), per_frame(), _ftp) and through them the scifi ones (JsRng, rand,
# easings, ghost()).
extends "res://build/fx/pickups/_pickups.gd"

const TR := "res://addons/pixelfx_particles/fx/transitions/"
const SW := 320.0
const SHH := 180.0
# marks() kinds (_marks.gdshader)
const M_PX := 0
const M_CROSS := 1
const M_RECT := 2
const M_FRAME := 3
const M_GLINT := 4
const M_SPARKLE := 5
const M_FLARE := 6
const M_LINE := 7
const M_NONE := 9   # light only
const NONE := 15   # a colour index that draws nothing (M_FRAME's fill or rim)

var ink: Color
var NSUB := 4
var SUB := (1.0 / 30.0) / 4.0


func begin(effect_id: String) -> void:
	super(effect_id)
	ink = Color(meta.options.color)
	keep_colour(ink)


func tsh(name: String) -> Shader:
	return load(TR + "_" + name + ".gdshader")


## A shader over the whole screen, with the palette as `C` and the cover colour as `ink`, its `t` keyed on every frame
## to the time the reference draws it at (stepped). o: as shape() (layer is the shader's own; back), clock (the
## effect's own clock at each frame, from replay(): for originals that draw on the time their update() adds up).
func screen(name: String, shader: String, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var pr := {"C": C, "ink": ink}
	pr.merge(params, true)
	var oo := {"at": Vector2(SW / 2.0, SHH / 2.0)}
	oo.merge(o, true)
	var r := shape(name, tsh(shader), Vector2(SW, SHH), pr, oo)
	var ck: PackedFloat64Array = o.get("clock", PackedFloat64Array())
	per_frame(r, "material:shader_parameter/t", func(i: int, t: float) -> float: return ck[i] if i < ck.size() else t)
	return r


## The original's create()/update() clock: frame 0 at t = 0, then each frame 4 updates of 1/120 s. step(t, dt) is
## called every substep (t already advanced, as the original's update sees it); frame(i, t) once each frame is done
## (i = 0 before any update). Returns the effect's own clock at each frame.
func replay(step: Callable, frame: Callable = Callable()) -> PackedFloat64Array:
	var out := PackedFloat64Array([0.0])
	var t := 0.0
	if frame.is_valid():
		frame.call(0, 0.0)
	for i in range(1, NF):
		for s in NSUB:
			t += SUB
			step.call(t, SUB)
		out.append(t)
		if frame.is_valid():
			frame.call(i, t)
	return out


## sim.js Particles.spawn at substep time t, its seed drawn from R after the caller's own arguments (as JS evaluates
## them): born when it first moves (a delay holds it). Collect with ghosts_begin(0.0) first; ghosts() makes emitters.
func spawn(R: JsRng, t: float, k: int, x: float, y: float, vx: float, vy: float, life: float, col: Variant = Color.WHITE, size := 1.0, delay := 0.0, flag := 0) -> void:
	var sd := R.next() * 100.0
	var n := 0
	var dl := delay
	while dl > 0.0:
		dl -= SUB
		n += 1
	# (a hair late: a frame drawn on the very substep before its birth doesn't show it)
	ghost(t + (n - 1) * SUB + 1e-4, k, x, y, vx, vy, life, col, size, flag, {"seed": sd})


## Lights.add(x, y, r, c, k, life) at substep time t (it starts dying in that same substep), keyed on every frame from
## the effect's clock at that frame (clocks, from replay()): a glow shrinking to 55% and dying as (life left)^2.
func light_at(name: String, t: float, at: Vector2, r: float, c: Color, k: float, life: float, clocks: PackedFloat64Array) -> ColorRect:
	var g := glow(name, r + 1.0, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	var ka := []
	var kr := []
	for i in NF:
		var left := life - (clocks[i] - (t - SUB))
		var on := clocks[i] >= t - 1e-9 and left > 1e-9
		var kk := left / life if on else 0.0
		ka.append([i / 30.0, k * kk * kk if on else 0.0])
		kr.append([i / 30.0, r * (0.55 + 0.45 * kk) if on else r])
	key(g, "material:shader_parameter/alpha", ka, "nearest")
	key(g, "material:shader_parameter/radius", kr, "nearest")
	return g


## Frame-table marks (fx/transitions/_marks.gdshader): rows[i] is what the original draws at frame i, an Array of
## entries (null: the slot is empty), slot j of every frame one particle, drawn in slot order. An entry (Dictionary):
##   k (kind, M_*), x, y (where: its cell is floor(x), floor(y)), a (alpha, dithered), c, c2 (Colors or indices into
##   the palette: C, then white at C.size(), then o.extra), and by kind: L, ang (glint), arm (sparkle), L, fk (flare),
##   w, h (rect, frame), dx, dy (line); its light: lc, lp (Vector2), lr (radius; < 1: its own cell), lk.
## A glint's two lights and a sparkle's glow come from its kind (give lk for a sparkle). o: light (false: no twin),
## extra (colours after white), back.
func marks(name: String, rows: Array, o: Dictionary = {}) -> GPUParticles2D:
	var slots := 1
	for r in rows:
		slots = maxi(slots, (r as Array).size())
	var pal := Array(C)
	pal.append(Color.WHITE)
	for c in o.get("extra", []):
		pal.append(c)
	var img := Image.create(slots, NF * 4, false, Image.FORMAT_RGBAF)
	var reach := 1.0
	var lreach := 0.0
	for f in mini(NF, rows.size()):
		var r: Array = rows[f]
		for s in r.size():
			var e: Variant = r[s]
			if e == null:
				continue
			var x: float = e.x
			var y: float = e.y
			var X := floorf(x)
			var Y := floorf(y)
			var kd: int = e.get("k", M_PX)
			var cv: Variant = e.get("c", C.size())
			var c2v: Variant = e.get("c2", cv)
			var ci := NONE if cv == null else _pal_index(pal, cv)
			var c2 := NONE if c2v == null else _pal_index(pal, c2v)
			var lv: Variant = e.get("lc", cv)
			var lc := 0 if lv == null else _pal_index(pal, lv)
			var p0 := 0.0
			var p1 := 0.0
			match kd:
				M_GLINT:
					p0 = e.L
					p1 = e.ang
					reach = maxf(reach, p0 + 2.0)
					lreach = maxf(lreach, 4.0 + p0 * 1.4 + 1.0)
				M_SPARKLE:
					p0 = e.arm
					reach = maxf(reach, roundf(p0) + 1.0)
				M_FLARE:
					p0 = e.L
					p1 = e.fk
					reach = maxf(reach, p0 + 2.0)
				M_RECT, M_FRAME:
					p0 = e.w
					p1 = e.get("h", e.w)
					reach = maxf(reach, maxf(p0, p1) + 1.0)
				M_LINE:
					p0 = e.dx
					p1 = e.dy
					reach = maxf(reach, maxf(absf(p0), absf(p1)) + 1.0)
				M_CROSS:
					reach = maxf(reach, 2.0)
			img.set_pixel(s, f * 4, Color(X, Y, float(e.get("a", 1.0)), float(kd)))
			img.set_pixel(s, f * 4 + 1, Color(ci, c2, lc, 1.0))
			# where in its cell, from the doubles (a float32 x of 59.99999 would land in the next cell)
			img.set_pixel(s, f * 4 + 2, Color(minf(x - X, 0.9999), minf(y - Y, 0.9999), p0, p1))
			var lk: float = e.get("lk", 0.0)
			var lr: float = e.get("lr", 0.0)
			var lp: Vector2 = e.get("lp", Vector2(x, y))
			img.set_pixel(s, f * 4 + 3, Color(lp.x, lp.y, lr, lk))
			if lk > 0.004:
				lreach = maxf(lreach, maxf(absf(lp.x - X - 0.5), absf(lp.y - Y - 0.5)) + maxf(lr, 1.0) + 1.0)
	for c in pal:
		keep_colour(c)
	var full := PackedColorArray(pal)
	assert(full.size() <= NONE, "%s: too many colours" % name)
	while full.size() < 16:
		full.append(Color(0, 0, 0, 0))
	var data := asset("_" + name.to_snake_case(), img)
	var q := int(ceilf(reach)) * 2 + 1
	var pp := {"data": data, "nframes": NF, "looped": false}
	var po := {"amount": slots, "lifetime": D + 0.04, "one_shot": true, "explosiveness": 1.0, "local": true,
		"texture": _oquad(q), "layer": "color", "back": o.get("back", false), "process_shader": psh("ftp"), "process_params": pp,
		"preprocess": 0.0}
	var p := particles(name, po)
	p.interpolate = false
	p.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var m := ShaderMaterial.new()
	m.shader = tsh("marks")
	m.set_shader_parameter("data", data)
	m.set_shader_parameter("quad", float(q))
	m.set_shader_parameter("pal", full)
	m.resource_name = name
	p.material = m
	if o.get("light", true) and lreach > 0.0:
		var lq := int(ceilf(lreach)) * 2 + 1
		var lp := particles(name + "Light", {"amount": slots, "lifetime": po.lifetime, "one_shot": true, "explosiveness": 1.0,
			"local": true, "texture": _oquad(lq), "layer": "light", "preprocess": 0.0})
		lp.interpolate = false
		lp.seed = p.seed
		lp.process_material = p.process_material
		var lm := ShaderMaterial.new()
		lm.shader = tsh("marks_light")
		lm.set_shader_parameter("data", data)
		lm.set_shader_parameter("quad", float(lq))
		lm.set_shader_parameter("pal", full)
		lm.resource_name = name + "Light"
		lp.material = lm
	return p


## _lib.js glint(p, x, y, L, ang, c1, c2, a) as a marks() entry (null when the original draws nothing).
static func glint_m(x: float, y: float, L: float, ang: float, c1: Variant, c2: Variant, a := 1.0) -> Variant:
	if L < 0.8 or a <= 0.0:
		return null
	return {"k": M_GLINT, "x": x, "y": y, "L": L, "ang": ang, "c": c1, "c2": c2, "a": a}


## sim.js sparkle(p, x, y, arm, c, tip, k) as a marks() entry.
static func sparkle_m(x: float, y: float, arm: float, c: Variant, tip: Variant, k := 0.6) -> Variant:
	var n := roundf(arm)
	if n < 1.0:
		return null
	return {"k": M_SPARKLE, "x": x, "y": y, "arm": arm, "c": c, "c2": tip, "lc": c, "lp": Vector2(x, y), "lr": 4.0 + n * 2.0, "lk": k}


## A frame-by-frame list of entries from f(i, t) (an Array of entries for frame i at the reference's time t), with
## each entry kept in its own slot by the slot index it carries ("s"), so a mark stays one particle frame to frame.
func frame_rows(f: Callable) -> Array:
	var rows := []
	for i in NF:
		var l: Array = f.call(i, ft(i))
		rows.append(l)
	return rows


## JS Math.round
static func jr(x: float) -> float:
	return floorf(x + 0.5)


static func in_out_cubic(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func in_out_quad(x: float) -> float:
	return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0


static func out_quart(x: float) -> float:
	return 1.0 - pow(1.0 - x, 4.0)


static func in_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return (s + 1.0) * x * x * x - s * x * x


## math.js noise(x, seed)
static func noise1(x: float, seed: int) -> float:
	var i := floorf(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(rand([i, seed]), rand([i + 1.0, seed]), u) * 2.0 - 1.0


## math.js noise2(x, y, seed)
static func noise2(x: float, y: float, seed: int) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var a := rand([ix, iy, seed])
	var b := rand([ix + 1.0, iy, seed])
	var c := rand([ix, iy + 1.0, seed])
	var d := rand([ix + 1.0, iy + 1.0, seed])
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


## math.js fbm(x, y, seed, octaves)
static func fbm(x: float, y: float, seed: int, octaves := 3) -> float:
	var s := 0.0
	var a := 0.5
	var n := 0.0
	for o in octaves:
		s += noise2(x, y, seed + o * 101) * a
		n += a
		x *= 2.03
		y *= 2.03
		a *= 0.5
	return s / n
