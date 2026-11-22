# Shared by the ice build scripts (not an effect: ./pfxp only builds ids it finds in port/meta.json). The ice ramp
# as C (dark to bright, the original's fit(palette, 8)), the original's sparkle() as a keyed shader, light copies of
# emitters (each particle carries its own glow), polygons, and the little sums the originals use (ease, smooth, seg).
extends "res://addons/pixelfx_particles/core/build.gd"

const ICE := "res://addons/pixelfx_particles/fx/ice/"
const FPS := 30.0

var C: PackedColorArray
var rng := RandomNumberGenerator.new()


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.palette


# ------------------------------------------------------------------ maths from the originals

static func clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func out_back(x: float, s := 1.70158) -> float:
	var u := x - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u


static func _imul(a: int, b: int) -> int:
	return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


## The originals' rand(...ns): a 32-bit hash of integers as a number in [0, 1), bit for bit.
static func jrand(ns: Array) -> float:
	var h := 0x9e3779b9
	for n in ns:
		h = _imul(h ^ (int(n) & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = _imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h / 4294967296.0


## A pixel's centre: where the original's p.px / p.line put a point (x, y).
static func cell(p: Vector2) -> Vector2:
	return p.floor() + Vector2(0.5, 0.5)


# ------------------------------------------------------------------ nodes

## One of the ice textures (fx/ice/_tex/<name>.png): fadeN, streaks fading from a bright head (bottom) to the tail.
func tex(name: String) -> Texture2D:
	return load(ICE + "_tex/" + name + ".png")


## A Polygon2D (colour layer unless o.layer says otherwise): o.at, o.back, o.color, o.parent.
func poly(name: String, pts: PackedVector2Array, o: Dictionary = {}) -> Polygon2D:
	var n := Polygon2D.new()
	n.name = name
	n.polygon = pts
	n.antialiased = false
	_place(n, o, o.get("parent"))
	if o.has("color"):
		n.color = o.color
		keep_colour(o.color)
	return n


## Pixels drawn here, the original's p.px / p.dot: {Vector2i(x, y): Color (its alpha dithers on the colour layer)}
## as a Sprite2D (an image built by the script, not lifted). o: layer, back, parent.
func bitmap(name: String, px: Dictionary, o: Dictionary = {}) -> Sprite2D:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for q in px:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var img := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for q in px:
		var c: Color = px[q]
		img.set_pixel(q.x - lo.x, q.y - lo.y, c)
		keep_colour(c)
	var oo := {"at": Vector2(lo), "centered": false}
	oo.merge(o, true)
	return sprite(name, ImageTexture.create_from_image(img), oo)


## The original's sparkle(): a shader cross keyed by `arm` and a glow under it (4 + 2 * arm px). Returns
## [cross, glow]; key them with sparkle_keys().
func sparkle(name: String, o: Dictionary = {}) -> Array:
	var col: Color = o.get("color", C[6])
	var tip: Color = o.get("tip", C[4])
	var s := shape(name, load(ICE + "_sparkle.gdshader"), Vector2(o.get("size", 25), o.get("size", 25)),
		{"arm": 0.0, "color": col, "tip": tip, "heart": Color.WHITE}, {"at": o.get("at", Vector2(0.5, 0.5)), "back": o.get("back", false)})
	keep_colour(Color.WHITE)
	var g := glow(name + "Glow", float(o.get("reach", 26)), {"radius": 8.0, "color": col, "alpha": 0.0}, {"at": o.get("at", Vector2(0.5, 0.5))})
	return [s, g]


## keys: [[t, position, arm, glow alpha], ...] (arm 0: hidden). Positions are snapped to the pixel the original uses.
func sparkle_keys(sp: Array, keys: Array) -> void:
	var pos := []
	var arm := []
	var rad := []
	var al := []
	for k in keys:
		var n := roundf(float(k[2]))
		pos.append([k[0], cell(k[1])])
		arm.append([k[0], n])
		rad.append([k[0], 4.0 + 2.0 * n])
		al.append([k[0], float(k[3]) if n >= 1.0 else 0.0])
	key(sp[0], "position", pos, "nearest")
	key(sp[0], "material:shader_parameter/arm", arm, "nearest")
	key(sp[1], "position", pos, "nearest")
	key(sp[1], "material:shader_parameter/radius", rad, "nearest")
	key(sp[1], "material:shader_parameter/alpha", al, "nearest")


## A copy of emitter p on the light layer (same seed, same process material but for its alpha over life, so the
## same particles): every particle carries a glow. tex: the glow's texture (glow8, glow16...). col: its colour and
## strength (alpha); an emitter with a colour ramp keeps it (dropping it would change Godot's random draws) and is
## only scaled by col.a.
func lit_copy(p: GPUParticles2D, name: String, tex: String, col: Color, alpha_curve: Array = []) -> GPUParticles2D:
	var q: GPUParticles2D = p.duplicate()
	q.name = name
	p.get_parent().add_child(q)
	q.material = light
	q.z_index = -1 if p.z_index < 0 else 2
	q.texture = texture(tex)
	var m: ParticleProcessMaterial = p.process_material.duplicate()
	if m.color_ramp == null and m.color_initial_ramp == null:
		m.color = col
	else:
		q.modulate = Color(1, 1, 1, col.a)
	if alpha_curve.size():
		m.alpha_curve = curve(alpha_curve)
	q.process_material = m
	q.seed = p.seed
	return q


## A GPUParticles2D run by one of the ice particle process shaders (fx/ice/_<shader>.gdshader): each particle is
## placed by the original's formulas from its index and the loop's time `t` (keyed 0 -> duration here), so it loops
## exactly. All are emitted at once and live as long as the scene. params: the shader's uniforms. o: amount, texture,
## layer, back, at, parent.
func formula(name: String, shader: String, params: Dictionary, o: Dictionary = {}) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = name
	_place(p, o, o.get("parent"))
	p.amount = o.get("amount", 16)
	p.lifetime = 600.0
	p.explosiveness = 1.0
	p.preprocess = 0.05
	p.local_coords = true
	p.fixed_fps = 60
	p.interpolate = false
	p.use_fixed_seed = true
	_count += 1
	p.seed = absi(hash(id + "/" + name)) % 1000003 + _count
	p.texture = texture(o.get("texture", "dot1"))
	p.visibility_rect = Rect2(-1024, -1024, 2048, 2048)
	var m := ShaderMaterial.new()
	m.shader = load(ICE + "_" + shader + ".gdshader")
	for k in params:
		var v: Variant = params[k]
		m.set_shader_parameter(k, v)
	p.process_material = m
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	return p


## Squash an emitter's particles in y (or x): for emitters inside a parent scaled flat, so dots stay 1 px.
func stretch(p: GPUParticles2D, sx: float, sy: float) -> void:
	var tex := CurveXYZTexture.new()
	var cx := Curve.new()
	cx.max_value = maxf(1.0, sx)
	cx.add_point(Vector2(0, sx))
	cx.add_point(Vector2(1, sx))
	var cy := Curve.new()
	cy.max_value = maxf(1.0, sy)
	cy.add_point(Vector2(0, sy))
	cy.add_point(Vector2(1, sy))
	var cz := Curve.new()
	cz.add_point(Vector2(0, 1))
	cz.add_point(Vector2(1, 1))
	tex.curve_x = cx
	tex.curve_y = cy
	tex.curve_z = cz
	(p.process_material as ParticleProcessMaterial).scale_curve = tex


## The original's glowLine(a, b, r, c, k): light round a segment (light layer). Key alpha / a / b.
func glow_line(name: String, a: Vector2, b: Vector2, r: float, col: Color, k: float, o: Dictionary = {}) -> ColorRect:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r + 2, r + 2)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r + 2, r + 2)
	if o.has("box"):
		lo = o.box.position
		hi = o.box.end
	var mid := ((lo + hi) / 2.0).round()
	var sz := ((hi - lo) / 2.0).ceil() * 2.0
	return shape(name, load(ICE + "_glowline.gdshader"), sz, {"a": a, "b": b, "radius": r, "color": col, "alpha": k}, {"at": mid})


## A blade (fx/ice/_blade.gdshader) standing on base with its tip at tip; o: width, jag, glint, white, dim, alpha,
## reach (how far the rect reaches round the base, for blades that grow), back.
func blade(name: String, base: Vector2, tip: Vector2, w: float, o: Dictionary = {}) -> ColorRect:
	var reach: float = o.get("reach", maxf(absf(tip.x - base.x), absf(tip.y - base.y)) + w + 4.0)
	var at := base.round()
	var sz := Vector2(ceilf(reach + 2.0) * 2.0, ceilf(reach + 2.0) * 2.0)
	return shape(name, load(ICE + "_blade.gdshader"), sz, {"base": base, "tip": tip, "width": w, "jag": o.get("jag", -1.0),
		"glint": o.get("glint", -1.0), "white": o.get("white", 0.0), "dim": o.get("dim", 0.0), "ymax": o.get("ymax", maxf(base.y, tip.y)),
		"alpha": o.get("alpha", 1.0), "ramp": ramp("palette", {"stops": 8})}, {"at": at, "back": o.get("back", false)})


## The original's Lights.add(x, y, r, c, k, life) at time t0: a glow that shrinks to 0.55 of r and fades as k * f^2.
func light_flash(name: String, at: Vector2, r: float, col: Color, k: float, t0: float, life: float) -> ColorRect:
	var g := glow(name, r + 1.0, {"radius": r, "color": col, "alpha": 0.0}, {"at": at})
	var rad := [[0.0, r]]
	var al := [[0.0, 0.0]]
	if t0 > 0.002:
		al.append([t0 - 0.001, 0.0])
	var n := int(ceilf(life * FPS))
	for i in n + 1:
		var t := t0 + i / FPS
		var f := clampf(1.0 - (t - t0) / life, 0.0, 1.0)
		rad.append([t, r * (0.55 + 0.45 * f)])
		al.append([t, k * f * f])
	key(g, "material:shader_parameter/radius", rad)
	key(g, "material:shader_parameter/alpha", al)
	return g


## The original's flare() (fx/ice/_flare.gdshader) at `at`: key its len and k with flare_keys.
func flare(name: String, at: Vector2, reach := 40) -> ColorRect:
	return shape(name, load(ICE + "_flare.gdshader"), Vector2(reach * 2 + 1, reach * 2 + 1), {"len": 0.0, "k": 1.0, "c6": C[6], "c5": C[5]},
		{"at": cell(at)})


## Panes tumbling end over end (the originals' Panes): the particle's height squashes as |cos| of a turn that goes
## `turns` times round over its life from `phase`, never quite flat. (Every particle of the emitter tumbles in step;
## their own random angles hide it.)
func tumble(p: GPUParticles2D, turns: float, phase: float) -> void:
	var tex := CurveXYZTexture.new()
	var cx := Curve.new()
	cx.add_point(Vector2(0, 1))
	cx.add_point(Vector2(1, 1))
	var cy := Curve.new()
	for i in 33:
		var u := i / 32.0
		cy.add_point(Vector2(u, maxf(0.18, absf(cos(phase + u * turns * TAU)))), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	var cz := Curve.new()
	cz.add_point(Vector2(0, 1))
	cz.add_point(Vector2(1, 1))
	tex.curve_x = cx
	tex.curve_y = cy
	tex.curve_z = cz
	(p.process_material as ParticleProcessMaterial).scale_curve = tex


## Emitter on/off for several emitters at once.
func emit_all(ps: Array, on: float, off := -1.0) -> void:
	for p in ps:
		emit(p, on, off)


## Keys sampled from fn(t) every frame (30 fps) from t0 to t1: [[t, fn(t)], ...].
func sample(fn: Callable, t0 := 0.0, t1 := -1.0, fps := FPS) -> Array:
	var end: float = root.duration if t1 < 0.0 else t1
	var out := []
	var n := int(roundf((end - t0) * fps))
	for i in n + 1:
		var t := t0 + i / fps
		out.append([t, fn.call(t)])
	return out


# ------------------------------------------------------------------ polygons and cracks

static func in_poly(pts: Array, q: Vector2) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if (a.y > q.y) != (b.y > q.y) and q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


## The original's polygon cut along the line through (x, y) at angle a: the pieces with three corners or more.
static func split_poly(pts: Array, x: float, y: float, a: float) -> Array:
	var nx := -sin(a)
	var ny := cos(a)
	var L := []
	var R := []
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		var sp := (p.x - x) * nx + (p.y - y) * ny
		var sq := (q.x - x) * nx + (q.y - y) * ny
		(L if sp >= 0.0 else R).append(p)
		if (sp >= 0.0) != (sq >= 0.0):
			var u := sp / (sp - sq)
			var m := p.lerp(q, u)
			L.append(m)
			R.append(m)
	return [L, R].filter(func(s): return s.size() >= 3)


static func centroid(pts: Array) -> Vector3:
	var a := 0.0
	var c := Vector2.ZERO
	var j := pts.size() - 1
	for i in pts.size():
		var p0: Vector2 = pts[j]
		var p1: Vector2 = pts[i]
		var k := p0.x * p1.y - p1.x * p0.y
		a += k
		c += (p0 + p1) * k
		j = i
	if absf(a) < 1e-6:
		var s := Vector2.ZERO
		for p in pts:
			s += p
		s /= pts.size()
		return Vector3(s.x, s.y, 0.0)
	c /= 3.0 * a
	return Vector3(c.x, c.y, absf(a) / 2.0)


## The original's fractures(): n jagged lines from at that wander, fork now and then and stop at the edge of the
## polygon shape_pts (rng draws them).
## Each point carries its distance from the start: [Vector3(x, y, d), ...].
func fractures(shape_pts: Array, at: Vector2, n: int, length: int, a0: float, spread: float, fork: float) -> Array:
	var out := []
	for i in n:
		walk(shape_pts, out, at.x, at.y, 0.0, a0 + (float(i) / n) * spread + rng.randf_range(-0.3, 0.3) * minf(1.0, spread / TAU), length, 0, fork)
	return out


func walk(shape_pts: Array, out: Array, x: float, y: float, d: float, a: float, length: int, depth: int, fork: float) -> void:
	var pts := [Vector3(x, y, d)]
	for s in length:
		a += rng.randf_range(-0.55, 0.55)
		var st := rng.randf_range(1.6, 2.6)
		var nx := x + cos(a) * st
		var ny := y + sin(a) * st
		if not in_poly(shape_pts, Vector2(nx, ny)):
			break
		x = nx
		y = ny
		d += st
		pts.append(Vector3(x, y, d))
		if depth < 2 and pts.size() > 2 and rng.randf() < fork:
			walk(shape_pts, out, x, y, d, a + (1 if rng.randf() < 0.5 else -1) * rng.randf_range(0.6, 1.2), int(ceil(length * 0.5)), depth + 1, fork)
	if pts.size() > 1:
		out.append(pts)


## A crack grown out to (t - t0) * speed px along its line (keyed until `until`): a dark groove a pixel lower, a pale line over it, a white
## tip and its light while it runs.
func grow_crack(name: String, pts: Array, t0: float, speed: float, parent: Node, until: float) -> void:
	var dark := line(name + "Groove", PackedVector2Array(), {"color": C[2], "parent": parent})
	var pale := line(name, PackedVector2Array(), {"color": C[6], "parent": parent})
	var hot := line(name + "Tip", PackedVector2Array(), {"color": Color.WHITE, "parent": parent})
	var lit := glow(name + "Light", 6, {"radius": 5, "color": C[5], "alpha": 0.0}, {"at": Vector2(pts[0].x, pts[0].y), "parent": parent})
	keep_colour(C[2])
	var kd := []
	var kp := []
	var kh := []
	var kl := []
	var ka := []
	var total: float = pts[-1].z
	for f in int(roundf(until * FPS)) + 1:
		var t := f / FPS
		var reach := (t - t0) * speed
		var a := PackedVector2Array()
		var b := PackedVector2Array()
		var tip := PackedVector2Array()
		var end := Vector2(pts[0].x, pts[0].y)
		if reach > 0.0:
			for i in range(1, pts.size()):
				var p0: Vector3 = pts[i - 1]
				var p1: Vector3 = pts[i]
				if p0.z >= reach:
					break
				var u := minf(1.0, (reach - p0.z) / maxf(0.01, p1.z - p0.z))
				var q0 := cell(Vector2(p0.x, p0.y))
				var q1 := cell(Vector2(p0.x, p0.y).lerp(Vector2(p1.x, p1.y), u))
				if b.is_empty():
					b.append(q0)
					a.append(q0 + Vector2(0, 1))
				b.append(q1)
				a.append(q1 + Vector2(0, 1))
				if reach - p1.z < 3.0:
					if tip.is_empty():
						tip.append(q0)
					tip.append(q1)
				end = q1
		kd.append([t, a])
		kp.append([t, b])
		kh.append([t, tip])
		kl.append([t, end])
		ka.append([t, 0.5 if tip.size() > 0 else 0.0])
	key(dark, "points", kd, "nearest")
	key(pale, "points", kp, "nearest")
	key(hot, "points", kh, "nearest")
	key(lit, "position", kl, "nearest")
	key(lit, "material:shader_parameter/alpha", ka, "nearest")
