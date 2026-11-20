# Shared by the pickups build scripts (not an effect). The originals (src/fx/pickups/*.js) draw a solid body (a coin, a
# gem, a heart, a key...) pixel by pixel through _lib.js's Layer (a shading function per pixel, then a 1 px dark
# outline), with glints, twinkles, motes and sparks round it on their own beats. Here:
#   - the body is a canvas shader (fx/pickups/_<name>.gdshader) running the original's own pixel function and outline
#     on the effect's canvas, its pose (place, turn, squash) keyed every frame from the original's formulas;
#   - glints, twinkles, motes, sparks and flecks are particles (table()): each slot one of the original's, its cell,
#     size, colours and light worked out at build time for every frame the original draws (at the reference's own
#     clock) and placed from the keyed clock by fx/pickups/_ftp.gdshader, drawn by _bits.gdshader with a light twin
#     (_bits_light.gdshader) for each one's glow;
#   - the big lights (halos, pools, rings of light, glow lines) are one canvas-wide light shader (glows()) whose
#     lights are keyed every frame;
#   - the floor shadow is _lib.js blobShadow as a keyed shader (shadow()).
# Extends the scifi helpers for the original's randomness (JsRng, rand), easings and its frame clock (frame_t).
extends "res://build/fx/scifi/_scifi.gd"

const PK := "res://addons/pixelfx_particles/fx/pickups/"
const INK := Color("#0b0814")
# what _bits.gdshader draws
const K_DOT := 0
const K_GLINT := 1
const K_LINE := 2
const K_MINI := 3
const K_SPLINTER := 5
const K_COIN := 6
const K_GEMLET := 7
const K_SPARKLE := 8
const K_DISC := 9
const K_RING := 10
# what glows() adds
const G_GLOW := 0
const G_RING := 1
const G_POOL := 2
const G_LINE := 3

var D := 0.0
var NF := 0
var _ft := PackedFloat64Array()


func begin(effect_id: String) -> void:
	super(effect_id)
	D = root.duration
	NF = int(roundf(D * 30.0)) + (0 if root.loop else 1)
	var t := 0.0
	for i in NF:
		_ft.append(fmod(t, D) if root.loop else minf(t, D))
		t += 1.0 / 30.0


func psh(name: String) -> Shader:
	return load(PK + "_" + name + ".gdshader")


## The time the original draws frame i at (the reference adds 1/30 a frame; a loop wraps it).
func ft(i: int) -> float:
	return _ft[i]


## JS Math.round
static func jround(x: float) -> float:
	return floorf(x + 0.5)


## JS ((x % m) + m) % m
static func jmod(x: float, m: float) -> float:
	return fmod(fmod(x, m) + m, m)


## The canvas as a rect in the effect's px: top-left, size.
func canvas_rect() -> Rect2:
	return Rect2(-Vector2(root.origin), Vector2(root.canvas_size))


func canvas_v4() -> Vector4:
	var r := canvas_rect()
	return Vector4(r.position.x, r.position.y, r.size.x, r.size.y)


## Key node.prop to f(i, t) on every frame the original draws (stepped: each frame shows its own value).
func per_frame(node: Node, prop: String, f: Callable) -> void:
	var keys := []
	for i in NF:
		keys.append([i / 30.0, f.call(i, ft(i))])
	key(node, prop, keys, "nearest")


## A canvas shader over the whole canvas (the body), with the palette as `C` and params as uniforms.
func body(name: String, shader: String, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var r := canvas_rect()
	var pr := {"C": C}
	pr.merge(params, true)
	var oo := {"at": r.position + r.size / 2.0}
	oo.merge(o, true)
	return shape(name, psh(shader), r.size, pr, oo)


## _lib.js blobShadow on the floor (y), keyed every frame: f(i, t) -> [x, rx, k].
func shadow(name: String, f: Callable, o: Dictionary = {}) -> ColorRect:
	var y: float = o.get("y", 0.0)
	var span: float = o.get("span", 32.0)
	var s := shape(name, psh("shadow"), Vector2(span * 2.0, 4.0), {"x": 0.0, "rx": 0.0, "k": 0.0, "y": y, "ink": INK},
		{"at": Vector2(0, y + 1.0), "back": o.get("back", true)})
	var xs := []
	var rs := []
	var ks := []
	for i in NF:
		var v: Array = f.call(i, ft(i))
		xs.append([i / 30.0, float(v[0])])
		rs.append([i / 30.0, float(v[1])])
		ks.append([i / 30.0, float(v[2])])
	key(s, "material:shader_parameter/x", xs, "nearest")
	key(s, "material:shader_parameter/rx", rs, "nearest")
	key(s, "material:shader_parameter/k", ks, "nearest")
	return s


## The original's big lights as one canvas-wide light shader (fx/pickups/_glows.gdshader). f(i, t) -> an Array of
## lights for that frame, each [type, colour, a: Vector4] (G_GLOW: x, y, r, k | G_RING: x, y, R, k + "w" r |
## G_POOL: x, y, rx, k + "ry" | G_LINE: x0, y0, x1, y1 + r, k) given as dictionaries:
## {"t": G_GLOW, "c": colour, "p": Vector2, "r": radius, "k": k, "w": ring width, "ry": pool's ry, "ymin": pool's first
## lit row, "q": line's end}.
## Slot j of every frame is one light: keep a light's slot fixed across frames (null for none).
func glows(name: String, f: Callable, o: Dictionary = {}) -> ColorRect:
	var frames := []
	var n := 0
	for i in NF:
		var l: Array = f.call(i, ft(i))
		frames.append(l)
		n = maxi(n, l.size())
	n = maxi(1, n)
	assert(n <= 12, "%s: at most 12 lights" % name)
	# a light keeps its colour (recolourable) and type; its place and strength are keyed
	var cols := PackedColorArray()
	for j in 12:
		cols.append(Color.BLACK)
	for l in frames:
		for j in l.size():
			if l[j] != null:
				cols[j] = l[j].c
	var r := canvas_rect()
	var g := shape(name, psh("glows"), r.size, {"gc": cols, "canvas": canvas_v4(), "count": n},
		{"at": r.position + r.size / 2.0})
	var k_a := []
	var k_b := []
	for i in NF:
		var a := PackedVector4Array()
		var b := PackedVector4Array()
		var l: Array = frames[i]
		for j in 12:
			var e: Variant = l[j] if j < l.size() else null
			if e == null:
				a.append(Vector4(0, 0, 0, 0))
				b.append(Vector4(-1, 0, 0, 0))
				continue
			var p: Vector2 = e.get("p", Vector2.ZERO)
			var tp: int = e.get("t", G_GLOW)
			a.append(Vector4(p.x, p.y, e.get("r", 0.0), e.get("k", 0.0)))
			var q: Vector2 = e.get("q", Vector2.ZERO)
			b.append(Vector4(tp, e.get("w", e.get("ry", q.x)), e.get("ymin", -1e9) if tp == G_POOL else q.y, 0))
		k_a.append([i / 30.0, a])
		k_b.append([i / 30.0, b])
	key(g, "material:shader_parameter/gl", k_a, "nearest")
	key(g, "material:shader_parameter/gx", k_b, "nearest")
	return g


func _oquad(n: int) -> Texture2D:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return asset("_quad%d" % n, img)


static func _pal_index(pal: Array, c: Variant) -> int:
	if c is int:
		return c
	var cc: Color = c
	for i in pal.size():
		if pal[i].is_equal_approx(cc):
			return i
	assert(pal.size() < 16, "more than 16 colours in a table")
	pal.append(cc)
	return pal.size() - 1


## Particles keyed frame by frame (fx/pickups/_ftp.gdshader): rows[i] is what the original draws at frame i, an
## Array of entries (Dictionaries; null leaves a slot empty), slot j of every frame one particle, drawn in slot order
## as the original draws them. An entry: x, y (where; its cell is floor(x), floor(y)), s (size: a glint's arms...),
## a (alpha, dithered; 1 opaque), c, c2 (colours: Color or an index into C, 8 = white), lc, lp, lr, lk (its glow:
## colour, centre, radius, strength), e (up to 4 extras), reach (px it draws round its cell).
## o: back (the colour behind; its light is always added over everything, as the original's light buffer is), light
## (false: no light twin), reach (the least reach), extra (colours put in `pal` after C and white, in order: a
## gem's ramp at 9..), soft (translucent, for discs the original blends).
func table(name: String, kind: int, rows: Array, o: Dictionary = {}) -> GPUParticles2D:
	var slots := 1
	for r in rows:
		slots = maxi(slots, (r as Array).size())
	var pal := Array(C)
	pal.append(Color.WHITE)
	for c in o.get("extra", []):
		pal.append(c)
	var img := Image.create(slots, NF * 4, false, Image.FORMAT_RGBAF)
	var reach: float = o.get("reach", 1.0)
	var lreach := 0.0
	var tips := {}
	for f in mini(NF, rows.size()):
		var r: Array = rows[f]
		for s in r.size():
			var e: Variant = r[s]
			if e == null:
				continue
			var x := floorf(float(e.x))
			var y := floorf(float(e.y))
			var c: Variant = e.get("c", 8)
			var ci := _pal_index(pal, c)
			var c2 := _pal_index(pal, e.get("c2", c))
			var lc := _pal_index(pal, e.get("lc", c))
			if kind == K_GLINT or kind == K_SPARKLE:
				tips[ci] = true
			img.set_pixel(s, f * 4, Color(x, y, float(e.get("s", 0.0)), float(e.get("a", 1.0))))
			img.set_pixel(s, f * 4 + 1, Color(ci, c2, lc, 1.0))
			var lk: float = e.get("lk", 0.0)
			var lr: float = e.get("lr", 0.0)
			var lp: Vector2 = e.get("lp", Vector2(x + 0.5, y + 0.5))
			img.set_pixel(s, f * 4 + 2, Color(lp.x, lp.y, lr, lk))
			var ex: Array = e.get("e", [])
			var ev := [0.0, 0.0, 0.0, 0.0]
			for k in mini(4, ex.size()):
				ev[k] = float(ex[k])
			img.set_pixel(s, f * 4 + 3, Color(ev[0], ev[1], ev[2], ev[3]))
			var rc: float = e.get("reach", 0.0)
			if kind == K_GLINT:
				rc = maxf(rc, float(e.get("s", 0.0)))
			elif kind == K_LINE:
				rc = maxf(rc, maxf(absf(ev[0]), absf(ev[1])))
			reach = maxf(reach, rc)
			if lk > 0.004 and lr >= 1.0:
				lreach = maxf(lreach, maxf(absf(lp.x - x - 0.5), absf(lp.y - y - 0.5)) + lr)
	for ci in tips:
		keep_colour(scalec(pal[ci], 0.75 if kind == K_SPARKLE else 0.8))
	for c in pal:
		keep_colour(c)
	var full := PackedColorArray(pal)
	while full.size() < 16:
		full.append(Color(0, 0, 0, 0))
	var data := asset("_" + name.to_snake_case(), img)
	var loop_: bool = root.loop
	var q := int(ceilf(reach)) * 2 + 1
	var pp := {"data": data, "nframes": NF, "looped": loop_}
	var po := {"amount": slots, "lifetime": D if loop_ else D + 0.04, "one_shot": not loop_, "explosiveness": 1.0, "local": true,
		"texture": _oquad(q), "layer": "color", "back": o.get("back", false), "process_shader": psh("ftp"), "process_params": pp,
		"preprocess": 0.0}
	var p := particles(name, po)
	p.interpolate = false
	p.preprocess = 1.0 / 60.0 if loop_ else 0.0
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var m := ShaderMaterial.new()
	m.shader = psh("bits")
	m.set_shader_parameter("data", data)
	m.set_shader_parameter("kind", float(kind))
	m.set_shader_parameter("quad", float(q))
	m.set_shader_parameter("pal", full)
	if o.get("soft", false):
		# translucent in 32 steps, as the original blends its soft discs
		m.set_shader_parameter("translucent", true)
	m.resource_name = name
	p.material = m
	if o.get("light", true) and lreach > 0.0:
		var lq := int(ceilf(lreach)) * 2 + 1
		var lp := particles(name + "Light", {"amount": slots, "lifetime": po.lifetime, "one_shot": not loop_, "explosiveness": 1.0,
			"local": true, "texture": _oquad(lq), "layer": "light", "preprocess": 0.0})
		lp.interpolate = false
		lp.preprocess = p.preprocess
		lp.seed = p.seed
		lp.process_material = p.process_material
		var lm := ShaderMaterial.new()
		lm.shader = psh("bits_light")
		lm.set_shader_parameter("data", data)
		lm.set_shader_parameter("quad", float(lq))
		lm.set_shader_parameter("pal", full)
		lm.set_shader_parameter("canvas", canvas_v4())
		lm.resource_name = name + "Light"
		lp.material = lm
	return p


# ------------------------------------------------------------------ entries the originals draw

## _lib.js glint(p, x, y, arm, c, k): arms of round(arm) px in c, dimmer tips, a white heart, its own light. null when
## the original draws nothing (arm rounds below 0).
static func glint_e(x: float, y: float, arm: float, c: Variant, k: float) -> Variant:
	var n := jround(arm)
	if n < 0.0:
		return null
	var X := floorf(x)
	var Y := floorf(y)
	return {"x": X, "y": Y, "s": n, "c": c, "lc": c, "lp": Vector2(X + 0.5, Y + 0.5), "lr": 3.0 + n * 2.5, "lk": k}


## painter.js dot(x, y, c, a) (a 1: px), with an optional glow.
static func dot_e(x: float, y: float, c: Variant, a: float = 1.0, glow: Array = []) -> Variant:
	if a <= 0.0 and glow.is_empty():
		return null
	var e := {"x": x, "y": y, "c": c, "a": a}
	if glow.size():
		# [x, y, r, colour, k]
		e.lp = Vector2(glow[0], glow[1])
		e.lr = glow[2]
		e.lc = glow[3]
		e.lk = glow[4]
	return e


# ------------------------------------------------------------------ gems (_lib.js brilliant, prism, drawGem)

## _lib.js brilliant(): a round brilliant as facet planes [{n: Vector3, d, kind}], with its girdle radius r and the
## heights of its top and bottom.
static func brilliant(o: Dictionary = {}) -> Dictionary:
	var r: float = o.get("r", 7.5)
	var crown: float = o.get("crown", 3.6)
	var tbl: float = o.get("table", 0.52)
	var pavilion: float = o.get("pavilion", 8.0)
	var girdle: float = o.get("girdle", 0.8)
	var n: int = o.get("n", 8)
	var planes := [{"n": Vector3(0, 1, 0), "d": crown + girdle / 2.0, "kind": 0}]
	var cs := atan2(crown, r * (1.0 - tbl))
	var ps := atan2(pavilion, r)
	for i in n * 2:
		var a := i * PI / n
		var half := i % 2
		var c := minf(1.45, cs + 0.22) if half else cs
		var pv := ps - 0.1 if half else ps
		planes.append({"n": Vector3(sin(c) * cos(a), cos(c), sin(c) * sin(a)), "d": r * sin(c) * (1.012 if half else 1.0) + (girdle / 2.0) * cos(c), "kind": 2 if half else 1})
		planes.append({"n": Vector3(cos(a), 0, sin(a)), "d": r, "kind": 3})
		planes.append({"n": Vector3(sin(pv) * cos(a), -cos(pv), sin(pv) * sin(a)), "d": r * sin(pv) * (1.03 if half else 1.0) + (girdle / 2.0) * cos(pv), "kind": 5 if half else 4})
	return {"planes": planes, "r": r, "top": crown + girdle / 2.0, "bottom": pavilion + girdle / 2.0}


## A gem body (fx/pickups/_gem.gdshader) for solid g; pose(i, t) -> [x, y, spin] keyed every frame. o: tilt, gain,
## edges, shader (another body shader that includes _gem.gdshaderinc), params.
func gem_body(name: String, g: Dictionary, pose: Callable, o: Dictionary = {}) -> ColorRect:
	var pl := PackedVector4Array()
	var kd := PackedFloat32Array()
	for q in g.planes:
		pl.append(Vector4(q.n.x, q.n.y, q.n.z, q.d))
		kd.append(float(q.kind))
	var tilt: float = o.get("tilt", 0.32)
	var box := Vector3(ceilf(g.r) + 2.0, ceilf(g.top + 2.0), ceilf(g.bottom + 2.0))
	var pr := {"planes": pl, "kinds": kd, "count": pl.size(), "box": box, "tilt_c": cos(tilt), "tilt_s": sin(tilt),
		"gain": float(o.get("gain", 1.0)), "edges": o.get("edges", true)}
	pr.merge(o.get("params", {}), true)
	var b := body(name, o.get("shader", "gem"), pr)
	var ks := {"gx": [], "gy": [], "cs": [], "sn": []}
	for i in NF:
		var v: Array = pose.call(i, ft(i))
		var tt := i / 30.0
		ks.gx.append([tt, jround(v[0])])
		ks.gy.append([tt, jround(v[1])])
		ks.cs.append([tt, cos(v[2])])
		ks.sn.append([tt, sin(v[2])])
	for k in ks:
		key(b, "material:shader_parameter/" + k, ks[k], "nearest")
	return b


## drawGem()'s ray cast at build time (doubles): the facet of solid g (centred on (x, y), turned by spin, seen at
## tilt) the pixel cell (cx, cy) shows, or -1 (outside the Layer's fill box, or off the gem).
static func gem_hit_at(g: Dictionary, x: float, y: float, spin: float, tilt: float, cx: float, cy: float) -> int:
	var X := jround(x)
	var Y := jround(y)
	if cx < X - (ceilf(g.r) + 2.0) or cx > X + ceilf(g.r) + 2.0 or cy < Y - ceilf(g.top + 2.0) or cy > Y + ceilf(g.bottom + 2.0):
		return -1
	var cs := cos(spin)
	var sn := sin(spin)
	var ct := cos(tilt)
	var st := sin(tilt)
	var sx := cx + 0.5 - X
	var sy := -(cy + 0.5 - Y)
	var o := [sx, sy * ct, -sy * st]
	var dv := [0.0, -st, -ct]
	var t0 := -1e9
	var t1 := 1e9
	var hit := -1
	for i in g.planes.size():
		var q: Dictionary = g.planes[i]
		var n0: float = q.n.x * cs - q.n.z * sn
		var n1: float = q.n.y
		var n2: float = q.n.x * sn + q.n.z * cs
		var nd: float = n0 * dv[0] + n1 * dv[1] + n2 * dv[2]
		var no: float = n0 * o[0] + n1 * o[1] + n2 * o[2]
		if absf(nd) < 1e-6:
			if no > q.d:
				return -1
			continue
		var tt: float = (q.d - no) / nd
		if nd < 0.0:
			if tt > t0:
				t0 = tt
				hit = i
		elif tt < t1:
			t1 = tt
	return -1 if (hit < 0 or t0 > t1) else hit
