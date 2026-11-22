# Shared by the weather build scripts (not an effect). The originals (src/fx/weather/*.js) are loops drawn as pure
# functions of t from seeded hashes (_lib.js trips(), field(), rand()), so the ports are too:
#   - bodies(): a GPUParticles2D whose process shader (fx/weather/_<name>.gdshader, ending with
#     _wx_place.gdshaderinc) places every one of the original's falling, drifting or wandering things from the keyed
#     clock `t` with the original's own hashes, drawn by a canvas shader (_wx_draw.gdshaderinc) on whole pixel cells;
#     body_light() is its light twin (same process material: the very same bodies).
#   - sky(): a canvas shader over the whole canvas for the original's per-pixel passes (hazes, drifts, fog, rays).
#   - field_tex(): _lib.js field() baked exactly, for fsample() in the shaders.
#   - the original's randomness (rand, JsRng) and colour maths (mixc), from build/fx/scifi/_scifi.gd.
extends "res://addons/pixelfx_particles/core/build.gd"

const DIR := "res://addons/pixelfx_particles/fx/weather/"


func sh(name: String) -> Shader:
	return load(DIR + "_" + name + ".gdshader")


## color.js fit(): ramp `name` resampled to n steps, its ends kept.
func fitc(name: String, n: int) -> PackedColorArray:
	var r: PackedColorArray = root.ramps[name]
	if r.size() == n:
		return r
	var out := PackedColorArray()
	for i in n:
		out.append(r[int(roundf(i * (r.size() - 1) / float(maxi(1, n - 1))))])
	return out


# ------------------------------------------------------------------ the original's randomness (src/core/math.js)

static func _mul(a: int, b: int) -> int:
	a &= 0xffffffff
	b &= 0xffffffff
	return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


class JsRng:
	var s := 1

	func _init(seed_: int = 1) -> void:
		s = seed_ & 0xffffffff
		if s == 0:
			s = 1

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = _m(t ^ (t >> 15), t | 1)
		t = t ^ ((t + _m(t ^ (t >> 7), t | 61)) & 0xffffffff)
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	static func _m(a: int, b: int) -> int:
		a &= 0xffffffff
		b &= 0xffffffff
		return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	func chance(p: float) -> bool:
		return next() < p

	func sign() -> float:
		return -1.0 if next() < 0.5 else 1.0


static func hash_(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		var f := float(n)
		var i := (int(f) if absf(f) < 9.0e18 else 0) & 0xffffffff
		h = _mul(h ^ i, 0x85ebca6b)
		h ^= h >> 13
		h = _mul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & 0xffffffff


static func rand(ns: Array) -> float:
	return hash_(ns) / 4294967296.0


static func wrapi_(x: int, m: int) -> int:
	return ((x % m) + m) % m


static func smooth(e0: float, e1: float, x: float) -> float:
	var u := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## color.js mix(): truncated like the original's rgb()
static func mixc(a: Color, b: Color, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	return Color8(int(a.r8 + (b.r8 - a.r8) * t) & 255, int(a.g8 + (b.g8 - a.g8) * t) & 255, int(a.b8 + (b.b8 - a.b8) * t) & 255)


# ------------------------------------------------------------------ fields (src/fx/weather/_lib.js field())

static var _fields := {}


## _lib.js field(seed, w, h, cells) as values (PackedFloat32Array, w * h)
static func field_data(seed: int, w := 256, h := 128, cells := [4, 8, 16, 32]) -> PackedFloat32Array:
	var key := "%d|%d|%d|%s" % [seed, w, h, str(cells)]
	if _fields.has(key):
		return _fields[key]
	var d := PackedFloat32Array()
	d.resize(w * h)
	var acc := []
	acc.resize(w * h)
	acc.fill(0.0)
	var amp := 0.5
	var total := 0.0
	for n in cells:
		var cs := w / float(n)
		var rows_ := maxi(1, int(roundf(h / cs)))
		var lat := {}
		for y in h:
			var gy := (y / float(h)) * rows_
			var iy := int(floor(gy))
			var v := gy - iy
			var sv := v * v * (3.0 - 2.0 * v)
			for x in w:
				var gx := x / cs
				var ix := int(floor(gx))
				var u := gx - ix
				var su := u * u * (3.0 - 2.0 * u)
				var a00 := _lat(lat, ix, iy, n, rows_, seed)
				var a10 := _lat(lat, ix + 1, iy, n, rows_, seed)
				var a01 := _lat(lat, ix, iy + 1, n, rows_, seed)
				var a11 := _lat(lat, ix + 1, iy + 1, n, rows_, seed)
				var top := a00 + (a10 - a00) * su
				var bot := a01 + (a11 - a01) * su
				acc[y * w + x] += (top + (bot - top) * sv) * amp
		total += amp
		amp *= 0.5
	for i in w * h:
		d[i] = acc[i] / total
	_fields[key] = d
	return d


static func _lat(lat: Dictionary, a: int, b: int, n: int, rows_: int, seed: int) -> float:
	var k := Vector2i(wrapi_(a, n), wrapi_(b, rows_))
	if not lat.has(k):
		lat[k] = rand([k.x, k.y, seed, n])
	return lat[k]


## _lib.js sample(F, u, v) on field_data()
static func fsample(d: PackedFloat32Array, w: int, h: int, u: float, v: float) -> float:
	var x := int(floor(u))
	var y := int(floor(v))
	var fx := u - x
	var fy := v - y
	var m := w - 1
	var n := h - 1
	var x0 := x & m
	var x1 := (x + 1) & m
	var y0 := (y & n) * w
	var y1 := ((y + 1) & n) * w
	var a := d[y0 + x0]
	var b := d[y0 + x1]
	var c := d[y1 + x0]
	var e := d[y1 + x1]
	return a + (b - a) * fx + (c - a + (a - b - c + e) * fx) * fy


## The field as an R float texture beside the scene (fsample() in _wx.gdshaderinc reads it exactly).
func field_tex(seed: int, w := 256, h := 128, cells := [4, 8, 16, 32]) -> Texture2D:
	var d := field_data(seed, w, h, cells)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RF, d.to_byte_array())
	return asset("_field_%d_%d" % [seed, cells.size() * 100 + int(cells[0])], img)


# ------------------------------------------------------------------ nodes

## The canvas: a shader over all of it (local pixel centres from `center` and `size`, as fog.gdshader does), keyed
## with the clock `t` in seconds. o: layer ("color", "soft": translucent, "light": additive), back.
func sky(name: String, shader: String, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var size := Vector2(root.canvas_size)
	var at := -Vector2(root.origin) + size / 2.0
	var pr := params.duplicate()
	if o.get("layer", "color") == "soft":
		pr.translucent = true
	var oo := {"at": at}
	oo.merge(o, true)
	var r := shape(name, sh(shader), size, pr, oo)
	clock(r)
	return r


## Key a shader's `t` to the effect's own seconds.
func clock(node: Node, prop := "material:shader_parameter/t") -> void:
	key(node, prop, [[0.0, 0.0], [root.duration, root.duration]])


## A plain n x n quad for the particles: the draw shaders never sample it, only its size matters, so it's a
## procedural white texture (a few bytes in the scene, not n x n pixels on disk).
func _quad(n: int) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0])
	g.colors = PackedColorArray([Color.WHITE])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = n
	tex.height = n
	return tex


func _params(m: ShaderMaterial, params: Dictionary, lit := false) -> void:
	var types := {}
	for u in m.shader.get_shader_uniform_list():
		types[u.name] = u.type
	for k in params:
		if not types.has(k):
			continue
		var v: Variant = params[k]
		if v is int and types[k] == TYPE_FLOAT:
			v = float(v)
		if v is PackedColorArray or (v is Array and v.size() and v.all(func(c): return c is Color)):
			var hinted: bool = types[k] == TYPE_PACKED_COLOR_ARRAY
			var arr: Variant = PackedColorArray() if hinted else PackedVector4Array()
			for c in v:
				arr.append(c if hinted else Vector4(c.r, c.g, c.b, c.a))
				if not lit:
					keep_colour(c)
			v = arr
		elif v is Color and not lit:
			keep_colour(v)
		m.set_shader_parameter(k, v)


## n bodies placed by process shader `proc` (fx/weather/_<proc>.gdshader) and drawn by `draw` on a quad of `quad`
## px. params go to both shaders (each takes the uniforms it has). o: layer ("color" | "soft"), back.
func bodies(name: String, n: int, proc: String, draw: String, quad: int, params: Dictionary = {}, o: Dictionary = {}) -> GPUParticles2D:
	var po := {"amount": n, "lifetime": root.duration, "explosiveness": 1.0, "local": true, "texture": _quad(quad),
		"layer": o.get("layer", "color"), "back": o.get("back", false), "process_shader": sh(proc), "preprocess": 0.0}
	var p := particles(name, po)
	p.interpolate = false
	p.draw_order = GPUParticles2D.DRAW_ORDER_INDEX   # the original draws its bodies in order: later ones on top
	p.preprocess = 1.0 / 60.0   # placed from the keyed clock: nothing to warm up
	var pm: ShaderMaterial = p.process_material
	_params(pm, params)
	clock(p, "process_material:shader_parameter/t")
	var m := ShaderMaterial.new()
	m.shader = sh(draw)
	m.resource_name = name
	var pr := params.duplicate()
	pr.quad = Vector2(quad, quad)
	if o.get("layer", "color") == "soft":
		pr.translucent = true
	_params(m, pr)
	p.material = m
	return p


## The light twin of bodies p: the same process material (the same bodies), drawn by `draw` (blend_add) on a quad
## of `quad` px.
func body_light(p: GPUParticles2D, draw: String, quad: int, params: Dictionary = {}) -> GPUParticles2D:
	var lp := particles(String(p.name) + "Light", {"amount": p.amount, "lifetime": root.duration, "explosiveness": 1.0, "local": true,
		"texture": _quad(quad), "layer": "light", "back": p.z_index < 0, "preprocess": 0.0})
	lp.interpolate = false
	lp.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	lp.preprocess = p.preprocess
	lp.seed = p.seed
	lp.process_material = p.process_material
	var m := ShaderMaterial.new()
	m.shader = sh(draw)
	var pr := params.duplicate()
	pr.quad = Vector2(quad, quad)
	_params(m, pr, true)
	lp.material = m
	return lp


## Colours a translucent mix may land on, kept out of the palette snap: steps of a -> b.
func keep_mix(a: Color, b: Color, steps := 8) -> void:
	for i in steps + 1:
		keep_colour(mixc(a, b, i / float(steps)))
