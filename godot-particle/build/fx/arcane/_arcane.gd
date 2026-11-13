# Shared by the arcane build scripts (not an effect): the palette by index as the originals use it (C[0] darkest ..
# C[7] white), keys sampled from the original's formulas, a run of glows along a line (the light layer), a star glint
# and the few easings the originals lean on. Shaders of their own live in fx/arcane/_*.gdshader.
extends "res://addons/pixelfx_particles/core/build.gd"

const ARC := "res://addons/pixelfx_particles/fx/arcane/"

var C: PackedColorArray


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.palette


func arcane_shader(name: String) -> Shader:
	return load(ARC + "_" + name + ".gdshader")


## Key node.prop from f(t) sampled `hz` times a second over [t0, t1] (t1 < 0: the whole effect). "nearest" keys sit a
## hair before each frame so a capture at exactly that frame's time gets that frame's value.
func keyf(node: Node, prop: String, f: Callable, t0 := 0.0, t1 := -1.0, hz := 30.0, interp := "linear") -> void:
	var end: float = root.duration if t1 < 0.0 else t1
	var keys := []
	var n := int(ceilf((end - t0) * hz - 1e-6))
	for i in n + 1:
		var t := minf(t0 + i / hz, end)
		var at := t
		if interp == "nearest" and t > 0.0:
			at = maxf(0.0, t - 0.002)
		keys.append([at, f.call(t)])
	key(node, prop, keys, interp)


## The original's p.glow(x, y, r, c, k) repeated every `step` px from a to b: a soft additive band (light layer).
func glow_line(name: String, a: Vector2, b: Vector2, r: float, c: Color, k: float, step: float, o: Dictionary = {}) -> ColorRect:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r + 2, r + 2)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r + 2, r + 2)
	var oo := {"at": (lo + hi) / 2.0}
	oo.merge(o, true)
	return shape(name, arcane_shader("glowline"), (hi - lo).ceil(), {"a": a, "b": b, "radius": r, "color": c, "k": k, "step_px": step}, oo)


## The original's sparkle(): a star glint whose arms are `arm` px (key "material:shader_parameter/arm"), arms c with
## tips in tip, a white heart. Its light is up to the caller.
func sparkle(name: String, at: Vector2, arm: float, c: Color, tip: Color, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at.floor() + Vector2(0.5, 0.5)}
	oo.merge(o, true)
	return shape(name, arcane_shader("sparkle"), Vector2(19, 19), {"arm": arm, "c": c, "tip": tip, "heart": Color.WHITE}, oo)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_cubic(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 3.0)


static func out_quad(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func in_quad(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.0)


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func in_out_sine(x: float) -> float:
	return -(cos(PI * clampf(x, 0.0, 1.0)) - 1.0) / 2.0


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := seg(x, a, b)
	return u * u * (3.0 - 2.0 * u)


static func bump(t: float, a: float, b: float) -> float:
	return 0.0 if (t <= a or t >= b) else sin(PI * seg(t, a, b))


## Set the radial velocity (px/s away from the emitter, negative: inward) the helper doesn't expose.
static func radial_speed(p: GPUParticles2D, lo: float, hi: float) -> void:
	var m: ParticleProcessMaterial = p.process_material
	m.radial_velocity_min = lo
	m.radial_velocity_max = hi


## Lifetime randomness (0..1: a particle lives lifetime * (1 - rand * this)).
static func life_rand(p: GPUParticles2D, r: float) -> void:
	(p.process_material as ParticleProcessMaterial).lifetime_randomness = r


## The original's flare(): an 8-ray star `len` px across its long rays (key "material:shader_parameter/len" and "k").
func flare(name: String, at: Vector2, length: float, k: float, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at.floor() + Vector2(0.5, 0.5)}
	oo.merge(o, true)
	return shape(name, arcane_shader("flare"), Vector2(45, 45), {"len": length, "k": k, "white": Color.WHITE, "c_hi": C[6], "c_lo": C[5]}, oo)


## A glowline shader over a fixed box (lo..hi, px from the origin) whose ends the caller keys: a run of light that
## moves (key "material:shader_parameter/a" and "/b").
func glow_path(name: String, lo: Vector2, hi: Vector2, r: float, c: Color, k: float, step: float, o: Dictionary = {}) -> ColorRect:
	var a := lo - Vector2(r + 2, r + 2)
	var b := hi + Vector2(r + 2, r + 2)
	var oo := {"at": ((a + b) / 2.0).round()}
	oo.merge(o, true)
	var sz := (b - a).ceil()
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	return shape(name, arcane_shader("glowline"), sz, {"a": lo, "b": lo, "radius": r, "color": c, "k": k, "step_px": step}, oo)


## One of the original's 5 x 7 sigils (fx/arcane/_sigils.png) centred on `at`, ringed by a 1 px edge: a group whose
## "Body" and "Edge0".."Edge3" sprites carry the colours (key their modulate).
func sigil(name: String, i: int, at: Vector2, body: Color, edge: Color, o: Dictionary = {}) -> Node2D:
	var g := group(name, {"at": at, "parent": o.get("parent")})
	var tex: Texture2D = load(ARC + "_sigils.png")
	var k := 0
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var e := sprite("Edge%d" % k, tex, {"parent": g, "centered": false, "offset": Vector2(-2, -3) + d, "hframes": 8, "modulate": edge})
		e.frame = posmod(i, 8)
		k += 1
	var b := sprite("Body", tex, {"parent": g, "centered": false, "offset": Vector2(-2, -3), "hframes": 8, "modulate": body})
	b.frame = posmod(i, 8)
	keep_colour(body)
	keep_colour(edge)
	return g


func cut_ring(name: String, reach: float, params: Dictionary, o: Dictionary = {}) -> ColorRect:
	var sq: float = params.get("squash", 1.0)
	return shape(name, arcane_shader("cutring"), Vector2(ceilf(reach + 2) * 2, ceilf(reach * sq + 2) * 2), params, o)


## The stand-in's silhouette (fx/arcane/_silhouette.gdshader) over its own pixels: mode 0 squeezed (key "sx"), 1 a
## crackling outline (key "chance", "grain", "hot"), 2 a translucent ghost (key "alpha").
func silhouette(name: String, mode: int, body: Color, edge: Color, o: Dictionary = {}) -> ColorRect:
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	var sz := Vector2(tex.get_width() + 6, tex.get_height() + 4)
	var oo := {"at": Vector2(0, -tex.get_height() / 2.0)}
	oo.merge(o, true)
	return shape(name, arcane_shader("silhouette"), sz, {"tex": tex, "mode": float(mode), "body": body, "edge": edge, "white": Color.WHITE}, oo)


## The original's Lights.add(): a glow that shrinks a little and dies (k * (life left)^2) from t0.
func light_burst(name: String, t0: float, at: Vector2, r0: float, c: Color, k: float, life: float) -> void:
	var lg := glow(name + "Light", r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": at})
	keyf(lg, "material:shader_parameter/radius", func(t: float): return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0, t0 + life)
	keyf(lg, "material:shader_parameter/alpha", func(t: float): return k * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 else 0.0, t0 - 0.04, t0 + life + 0.01)


## A ring rolling out across the floor (the original's band(), 4 -> 34 px over 0.5 s), white at its rim: the far half
## behind, the near half in front.
func ring_out(t0: float) -> void:
	for half in [[1.0, true, "RingBack"], [-1.0, false, "RingFront"]]:
		for layer in [["Rim", Color.WHITE, 0.0], ["Band", C[6], 1.0]]:
			var rr := ring(half[2] + layer[0], 36, {"radius": 4, "thickness": 1, "squash": 0.2, "color": layer[1], "side": half[0]}, {"back": half[1]})
			var inset: float = layer[2]
			keyf(rr, "material:shader_parameter/radius", func(t: float): return 4.0 + 30.0 * out_cubic((t - t0) / 0.5) - inset, t0, t0 + 0.5)
			keyf(rr, "material:shader_parameter/thickness", func(t: float): return 1.0 if inset == 0.0 else maxf(0.6, 3.0 * (1.0 - (t - t0) / 0.5) - 1.0), t0, t0 + 0.5)
			keyf(rr, "material:shader_parameter/alpha", func(t: float): return clampf(1.15 - (t - t0) / 0.5, 0.0, 1.0) * (1.0 if inset == 0.0 else (1.0 if 3.0 * (1.0 - (t - t0) / 0.5) > 1.6 else 0.0)), t0, t0 + 0.5)
			show(rr, t0, t0 + 0.5)
