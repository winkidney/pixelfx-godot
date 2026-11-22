# Shared by the holy build scripts (not an effect): the palette by index as the originals use it (C[0] darkest ..
# C[7] white), keys sampled from the original's formulas, the originals' glows along a line, star glints, 8-ray
# flares and the easings they lean on. Shaders of their own live in fx/holy/_*.gdshader.
extends "res://addons/pixelfx_particles/core/build.gd"

const HOLY := "res://addons/pixelfx_particles/fx/holy/"
const FPS := 30.0
## The originals' shared ramps (src/fx/holy/_lib.js).
const GOLD := ["#3b1d2a", "#7a3a2c", "#c4652e", "#f0a040", "#ffd25e", "#fff0a0", "#fffbe0", "#ffffff"]
const GREEN := ["#0e2a24", "#14472f", "#1d6e3a", "#2f9a45", "#5cc654", "#a0e46c", "#dcffb4", "#ffffff"]
const ASH := ["#16131c", "#26222f", "#3a3546", "#524c5e", "#6e6878", "#8c8796"]

var C: PackedColorArray


func begin(effect_id: String) -> void:
	super(effect_id)
	C = fit(root.ramps.palette, 8)


## The original's fit(r, n): a ramp resampled to n steps keeping its ends.
static func fit(r: PackedColorArray, n: int) -> PackedColorArray:
	if r.size() == n:
		return r
	var out := PackedColorArray()
	for i in n:
		out.append(r[int(roundf(i * (r.size() - 1) / float(maxi(1, n - 1))))])
	return out


func holy_shader(name: String) -> Shader:
	return load(HOLY + "_" + name + ".gdshader")


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


## f(t) for every frame of the effect, stepped (the originals draw frame by frame).
func keyn(node: Node, prop: String, f: Callable, t0 := 0.0, t1 := -1.0) -> void:
	keyf(node, prop, f, t0, t1, FPS, "nearest")


## The original's p.glow(x, y, r, c, k) repeated every `step` px from a to b: a soft additive band (light layer).
func glow_line(name: String, a: Vector2, b: Vector2, r: float, c: Color, k: float, step: float, o: Dictionary = {}) -> ColorRect:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r + 2, r + 2)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r + 2, r + 2)
	var oo := {"at": ((lo + hi) / 2.0).round()}
	oo.merge(o, true)
	var sz := (hi - lo).ceil()
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	return shape(name, holy_shader("glowline"), sz, {"a": a, "b": b, "radius": r, "color": c, "k": k, "step_px": step}, oo)


## A glowline over a fixed box (lo..hi) whose ends the caller keys ("material:shader_parameter/a" and "/b").
func glow_path(name: String, lo: Vector2, hi: Vector2, r: float, c: Color, k: float, step: float, o: Dictionary = {}) -> ColorRect:
	var a := lo - Vector2(r + 2, r + 2)
	var b := hi + Vector2(r + 2, r + 2)
	var oo := {"at": ((a + b) / 2.0).round()}
	oo.merge(o, true)
	var sz := (b - a).ceil()
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	return shape(name, holy_shader("glowline"), sz, {"a": lo, "b": lo, "radius": r, "color": c, "k": k, "step_px": step}, oo)


## The original's sparkle(): a star glint whose arms are `arm` px (key "material:shader_parameter/arm"), arms c with
## tips in tip, a white heart. Its light is up to the caller.
func sparkle(name: String, at: Vector2, arm: float, c: Color, tip: Color, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at.floor() + Vector2(0.5, 0.5)}
	oo.merge(o, true)
	return shape(name, holy_shader("sparkle"), Vector2(19, 19), {"arm": arm, "c": c, "tip": tip, "heart": Color.WHITE}, oo)


## The original's flare(): an 8-ray star, white at the heart cooling to c6 then c5 (key "reach" and "k").
func flare(name: String, reach: float, o: Dictionary = {}) -> ColorRect:
	var s := ceilf(reach + 2) * 2
	var oo := o.duplicate()
	oo.at = o.get("at", Vector2.ZERO) + Vector2(0.5, 0.5)
	return shape(name, holy_shader("flare"), Vector2(s + 1, s + 1), {"reach": 0.0, "k": 1.0, "c6": C[6], "c5": C[5]}, oo)


## The original's Lights.add(): a glow that shrinks a little and dies (k * (life left)^2) from t0.
func light_burst(name: String, t0: float, at: Vector2, r0: float, c: Color, k: float, life: float, o: Dictionary = {}) -> ColorRect:
	var lg := glow(name, r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": at, "back": o.get("back", false)})
	keyf(lg, "material:shader_parameter/radius", func(t: float): return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0, t0 + life)
	keyf(lg, "material:shader_parameter/alpha", func(t: float): return k * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 else 0.0, maxf(0.0, t0 - 0.04), t0 + life + 0.01)
	return lg


# ------------------------------------------------------------------ the originals' drawn sprites (_lib.js)

## The original's feather() pointing right (angle 0), drawn into an Image whose centre is the feather's middle (the
## quill sits len/2 left of it): a particle texture or a sprite. R: a ramp, dark to bright (6+ steps). side 1: the
## trailing vane below the shaft (clockwise of it), -1 above. hot > 0.5: the white flash it's born with.
static func feather_image(length: float, wid: float, R: PackedColorArray, side := 1, hot := 0.0, quill := 0.02) -> Image:
	var pad := wid + 1.2
	var w := int(ceilf(length * 1.05)) + 4
	w += w % 2
	var h := int(ceilf(pad)) * 2 + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var x0 := w / 2.0 - length / 2.0
	var y0 := h / 2.0
	var n := R.size()
	var hh := hot > 0.5
	var edge: Color = R[n - 3] if hh else R[n - 5]
	var lead: Color = Color.WHITE if hh else R[n - 2]
	var B: Array = [Color.WHITE, Color.WHITE, R[n - 2]] if hh else [R[n - 2], R[n - 3], R[n - 4]]
	for py in h:
		for px in w:
			var dx := px + 0.5 - x0
			var dy := py + 0.5 - y0
			var u := dx / length
			if u < 0.0 or u > 1.05:
				continue
			var v := dy * side
			var av := absf(v)
			var ww := wid * sqrt(clampf((u - quill) / 0.22, 0.0, 1.0)) * sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, (u - 0.55) / 0.47), 2.0)))
			var lim := ww * 0.42 if v < 0.0 else ww
			var fade := 1.0 if u < 0.72 else 1.0 - (u - 0.72) * 1.6
			var c := Color(0, 0, 0, 0)
			if av < 0.5 and u < 0.9:
				c = Color.WHITE if u < 0.5 else B[0]
			elif av > lim + 0.05 or ww < 0.5:
				continue
			elif lim - av < 1.0:
				c = Color(B[2] if u > 0.85 else edge, fade) if v > 0.0 else lead
			elif u < 0.72:
				c = B[0] if u < 0.38 else B[1]
			else:
				c = Color(B[2], fade)
			c.a = clampf(c.a, 0.0, 1.0)
			img.set_pixel(px, py, c)
	return img


## The original's plus(): a plus sign of light, arm length L (1..4), thickness th (1 or 3), a white heart, arms lit on
## the top and left and shaded on the bottom and right (and a dark outline when thick). An Image centred on its heart.
static func plus_image(L: int, th: int, R: PackedColorArray, glint := false) -> Image:
	var n := R.size()
	var wd := 1 if th > 1 else 0
	var s := 2 * L + 3
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var ins := func(i: int, j: int) -> bool: return (absi(i) <= wd and absi(j) <= L) or (absi(j) <= wd and absi(i) <= L)
	for j in range(-L - 1, L + 2):
		for i in range(-L - 1, L + 2):
			var c: Color
			if not ins.call(i, j):
				if wd and (ins.call(i - 1, j) or ins.call(i + 1, j) or ins.call(i, j - 1) or ins.call(i, j + 1)):
					img.set_pixel(i + L + 1, j + L + 1, R[maxi(0, n - 6)])
				continue
			if not wd:
				c = Color.WHITE if (i == 0 and j == 0) else (R[n - 3] if absi(i) + absi(j) >= L else R[n - 2])
			elif i == 0 and j == 0:
				c = Color.WHITE
			elif i == 0 or j == 0:
				c = R[n - 2] if absi(i) + absi(j) < L else R[n - 3]
			else:
				c = R[n - 3] if (i < 0 or j < 0) else R[n - 5]
			if glint and ((i == 0 and j == -L) or (i == -L and j == 0)):
				c = Color.WHITE
			img.set_pixel(i + L + 1, j + L + 1, c)
	return img


## The original's sparkle() as a strip of `n` frames over a life (frame i drawn at u = (i + 0.5) / n): arm(u) gives
## its arm in px (0: nothing that frame). Arms c, the outer 40% in tip, a white heart, diagonals from 3 px, longer
## ones from 6. Each frame is (2 * most + 1) px square.
static func sparkle_strip(n: int, arm: Callable, c: Color, tip: Color, most := 4) -> Image:
	var s := 2 * most + 1
	var img := Image.create(s * n, s, false, Image.FORMAT_RGBA8)
	for f in n:
		var a := mini(most, int(roundf(float(arm.call((f + 0.5) / n)))))
		if a < 1:
			continue
		var ox := f * s + most
		for d in range(1, a + 1):
			var cc := tip if d > a * 0.6 else c
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixel(ox + v.x * d, most + v.y * d, cc)
		if a >= 3:
			for v in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				img.set_pixel(ox + v.x, most + v.y, c)
		if a >= 6:
			for v in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				img.set_pixel(ox + v.x * 2, most + v.y * 2, tip)
		img.set_pixel(ox, most, Color.WHITE)
	return img


## Make an emitter step through `frames` frames side by side in its texture over each particle's life (fx/holy/
## _flip.gdshader on the colour layer, anim_speed 1). use_alpha: its colour's alpha dithers it too.
func flip(p: GPUParticles2D, frames: int, use_alpha := false) -> void:
	var m := ShaderMaterial.new()
	m.shader = holy_shader("flip")
	m.set_shader_parameter("frames", frames)
	m.set_shader_parameter("use_alpha", 1.0 if use_alpha else 0.0)
	p.material = m
	var pm: Variant = p.process_material
	if pm is ParticleProcessMaterial:
		pm.anim_speed_min = 1.0
		pm.anim_speed_max = 1.0


# ------------------------------------------------------------------ easing (src/core/math.js)

static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


## The original's smooth(e0, e1, x): smoothstep.
static func smooth(a: float, b: float, x: float) -> float:
	var u := seg(x, a, b)
	return u * u * (3.0 - 2.0 * u)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_cubic(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 3.0)


static func out_quad(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func in_quad(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.0)


static func in_out_sine(x: float) -> float:
	return -(cos(PI * clampf(x, 0.0, 1.0)) - 1.0) / 2.0


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * clampf(x, 0.0, 1.0))


static func bump(t: float, a: float, b: float) -> float:
	return 0.0 if (t <= a or t >= b) else sin(PI * seg(t, a, b))
