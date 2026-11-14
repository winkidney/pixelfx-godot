# Shared by the shadow build scripts (not an effect), after src/fx/shadow/_lib.js: the void palette by index as the
# originals use it (C[0] void black .. C[7] white-lilac), keys sampled from the original's formulas, the easings the
# originals lean on, light along a line (glow_line), the lib's halo() (light hugging a black disc, none inside it) and
# ringLight() (a band of light round a circle), and over_light(): the lib's unlight(), a black shape lifted above the
# light layer so every glow drawn before stays off it. Shaders of their own live in fx/shadow/_*.gdshader.
extends "res://addons/pixelfx_particles/core/build.gd"

const SHD := "res://addons/pixelfx_particles/fx/shadow/"
## z_index above the front light layer (2): a node here cuts the light under it, like the original's unlight().
const OVER_LIGHT := 3

var C: PackedColorArray


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.get("palette", PackedColorArray())


func shadow_shader(name: String) -> Shader:
	return load(SHD + "_" + name + ".gdshader")


## The original's unlight(): lift a (black) node above the light layer so the glows under it don't wash it. Particles
## or shapes that the original draws over it afterwards need z_index OVER_LIGHT + 1.
static func over_light(n: CanvasItem, z := OVER_LIGHT) -> CanvasItem:
	n.z_index = z
	return n


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
## Key "material:shader_parameter/a", "/b", "/k", "/alpha" to move or fade it (the box is fixed: give lo/hi in o).
func glow_line(name: String, a: Vector2, b: Vector2, r: float, c: Color, k: float, step: float, o: Dictionary = {}) -> ColorRect:
	var lo: Vector2 = o.get("lo", Vector2(minf(a.x, b.x), minf(a.y, b.y))) - Vector2(r + 2, r + 2)
	var hi: Vector2 = o.get("hi", Vector2(maxf(a.x, b.x), maxf(a.y, b.y))) + Vector2(r + 2, r + 2)
	var oo := {"at": (lo + hi) / 2.0}
	oo.merge(o, true)
	oo.erase("lo")
	oo.erase("hi")
	return shape(name, shadow_shader("glowline"), (hi - lo).ceil(), {"a": a, "b": b, "radius": r, "color": c, "k": k, "step_px": step}, oo)


## The lib's halo(p, x, y, r0, r1, c, k): light k at r0 falling to nothing at r1, none inside r0 (key "r0", "r1", "k",
## "alpha"). `reach` sizes the rect: the largest r1 it will have.
func halo(name: String, at: Vector2, reach: float, r0: float, r1: float, c: Color, k: float, o: Dictionary = {}) -> ColorRect:
	var sq: float = o.get("squash", 1.0)
	var oo := {"at": at}
	oo.merge(o, true)
	oo.erase("squash")
	return shape(name, shadow_shader("halo"), Vector2(ceilf(reach + 2) * 2, ceilf(reach * sq + 2) * 2),
		{"r0": r0, "r1": r1, "color": c, "k": k, "squash": sq}, oo)


## The lib's ringLight(p, x, y, R, w, c, k): light hugging a circle of radius R, (1 - |d - R| / w)^2 * k (core
## ring_light: key "radius", "thickness", "alpha").
func ring_light(name: String, at: Vector2, reach: float, r: float, w: float, c: Color, k: float, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at}
	oo.merge(o, true)
	return glow(name, reach, {"radius": r, "thickness": w, "color": c, "alpha": k, "squash": o.get("squash", 1.0)}, oo)


## Set the radial velocity (px/s away from the emitter, negative: inward).
static func radial_speed(p: GPUParticles2D, lo: float, hi: float) -> void:
	var m: ParticleProcessMaterial = p.process_material
	m.radial_velocity_min = lo
	m.radial_velocity_max = hi


## Lifetime randomness (0..1: a particle lives lifetime * (1 - rand * this)).
static func life_rand(p: GPUParticles2D, r: float) -> void:
	(p.process_material as ParticleProcessMaterial).lifetime_randomness = r


# ------------------------------------------------------------------ easings (core/index.js)

static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_cubic(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 3.0)


static func out_quad(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func in_quad(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.0)


static func in_out_quad(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 2.0 * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0


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
