# reimagined-from: src/fx/explosions/nuke.js@b06c5b836f1eab8d1a5c4cb7842223221ba1b0b8
# Nuke: a blinding white frame, then a fireball lifts on a thin stem into a wide rolling cap that glows from inside;
# a white skirt flashes and a dust surge sweeps the floor.
# The cap is a shader of its own (_nuke_plume.gdshader: the original's vortex-ring Plume, 50 cel-shaded lobes from a
# data texture, glowing from inside as it cools, all driven by one keyed clock); the stem is GPU particles drawn as
# the same lobes (_nuke_lobe.gdshader), the fire puffs as the original's fire balls. The condensation veil and bell
# are soft particles riding groups keyed to the cap's shape; the hollow under the cap, the white-hot sphere, the shock
# shell and the ground band are ring shaders keyed from the original's curves; the white frame and its light are
# keyed glows; sparks, embers, grit and the dust surge are bursts at the lift; the rim frays into puffs late on.
extends "res://addons/pixelfx_particles/core/build.gd"

const FLASH := 0.05
const LIFT := 0.07
const SKIRT := [0.55, 1.75]
const CAP := ["#a0918c", "#7c6f6e", "#5f5458", "#40373f", "#271f27"]
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const LOBE := "res://addons/pixelfx_particles/fx/explosions/_nuke_lobe.gdshader"
const PL := {"x": 0.0, "y": -26.0, "rise": 152.0, "tau": 1.7, "drift": 3.0, "tube": [14.0, 26.0], "ring": [4.0, 46.0], "grow": 1.6,
	"n": 50, "size": [9.5, 14.5], "swell": 0.45, "spin": 2.4, "spin_tau": 2.4, "heat": 1.25, "cool": 0.42, "under": 0.6, "tilt": 0.16,
	"squash": 0.48, "fade": [6.0, 8.3], "spread": 26.0}

var F: PackedColorArray
var FR: PackedColorArray
var DUST: PackedColorArray
var rng := RandomNumberGenerator.new()


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## The cap's centre and radii at effect time t: Vector4(y, tube, ring, g).
func shape_at(t: float) -> Vector4:
	var u := maxf(0.0, t - LIFT)
	var g := 1.0 - exp(-u / PL.grow)
	return Vector4(PL.y - PL.rise * (1.0 - exp(-u / PL.tau)) - PL.drift * u, PL.tube[0] + (PL.tube[1] - PL.tube[0]) * g,
		PL.ring[0] + (PL.ring[1] - PL.ring[0]) * g, g)


func hot_at(t: float) -> float:
	return clampf(PL.heat - PL.cool * maxf(0.0, t - LIFT) + 0.3, 0.0, 1.0)


func ember_at(t: float) -> float:
	return clampf((PL.heat - PL.cool * maxf(0.0, t - LIFT) + 1.0) / 1.1, 0.0, 1.0)


func sample(node: Node, prop: String, f: Callable, t0: float, t1: float, interp := "linear", hz := 30.0) -> void:
	var keys := []
	var n := int(ceil((t1 - t0) * hz))
	for i in n + 1:
		var t := minf(t1, t0 + i / hz)
		keys.append([t, f.call(t)])
	key(node, prop, keys, interp)


## A smooth gradient that carries data (heat, glow, opacity) to a particle shader, not colours: kept off the palette.
func data(points: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for p in points:
		offs.append(p[0])
		cs.append(p[1])
	g.offsets = offs
	g.colors = cs
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


func lobe_mat(mode: float, soft_layer: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(LOBE)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("style", 1.0)
	m.set_shader_parameter("fr", FR)
	m.set_shader_parameter("sm", DUST)
	m.set_shader_parameter("translucent", soft_layer)
	return m


func puffs(name: String, radius: Array, o: Dictionary) -> GPUParticles2D:
	var heat := []
	for i in 9:
		var a := i / 8.0
		var al := 1.0 if a < 0.667 else clampf((1.0 - a) * 3.0, 0.0, 1.0)
		heat.append([a, Color(minf(0.999, pow(a, 0.62)), 1, 1, al)])
	var oo := {"texture": "dot4", "one_shot": true, "explosiveness": 1.0, "scale": [2.7 * radius[0] / 4.0, 2.7 * radius[1] / 4.0],
		"scale_curve": [[0, 0.55], [0.14, 0.92], [0.5, 0.72], [1, 0.45]], "ramp": data(heat), "emitting": false}
	oo.merge(o, true)
	var p := particles(name, oo)
	p.material = lobe_mat(1.0, true)
	return p


func directed(p: GPUParticles2D, r: Vector2, from_a := 0.0, to_a := TAU, n := 48) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in n:
		var a := from_a + (to_a - from_a) * (i + 0.5) / n
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
		nor.append(Vector2(cos(a), sin(a)))
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(pts)
	m.emission_normal_texture = _points_texture(nor)
	m.emission_point_count = n
	m.direction = Vector3(1, 0, 0)


func make() -> void:
	F = root.ramps.palette
	FR = PackedColorArray([F[7], F[6], F[5], F[4], F[3], F[2], F[1], F[1].lerp(F[0], 0.5), F[0]])
	var dust := Color(meta.options.dust)
	DUST = PackedColorArray([dust.lerp(Color.WHITE, 0.22), dust, dust.lerp(Color("#3a3040"), 0.35), dust.lerp(Color("#2a2330"), 0.6),
		dust.lerp(Color("#1c1720"), 0.8)])
	for c in CAP + SMOKE_RAMP:
		keep_colour(Color(c))
	for c in DUST:
		keep_colour(c)
	keep_colour(FR[7])
	rng.seed = 5
	ground()

	# ---- behind: the band's far half, the dust surge, the skirt's far half, the cap, its hollow, the stem
	_band(true)
	_surge()
	_skirt(true)
	_plume()
	_hollow()
	_stem()
	_skirt(false)

	# ---- in front: the band's near half, the white-hot sphere, fire, sparks, embers, grit, the shock, the light
	_band(false)
	_sphere()
	_burst()
	_shock()
	_light()
	# smoke and dust sit behind the cap and the stem, as the original draws them
	for n in root.get_children():
		if n is GPUParticles2D and n.material == soft and n.z_index == -2:
			n.z_index = -3


func _band(far: bool) -> void:
	var parts := [[0.0, 0.15, F[7]], [0.15, 0.4, F[5]], [0.4, 0.7, DUST[0]], [0.7, 1.0, DUST[2]]]
	for i in parts.size():
		var pr: Array = parts[i]
		var b := ring("Band%s%d" % ["Far" if far else "Near", i], 198, {"radius": 4.0, "thickness": 1.0, "squash": 0.16, "color": pr[2],
			"side": 1.0 if far else -1.0}, {"back": far})
		var u0: float = pr[0]
		var u1: float = pr[1]
		sample(b, "material:shader_parameter/radius", func(t: float):
			var k := (t - LIFT) / 0.8
			return maxf(0.5, 196.0 * out_cubic(k) - maxf(1.0, 5.0 * (1.0 - k)) * u0), LIFT, LIFT + 0.8)
		sample(b, "material:shader_parameter/thickness", func(t: float):
			return maxf(0.6, maxf(1.0, 5.0 * (1.0 - (t - LIFT) / 0.8)) * (u1 - u0)), LIFT, LIFT + 0.8)
		sample(b, "material:shader_parameter/alpha", func(t: float):
			return clampf((1.15 - (t - LIFT) / 0.8) * (1.2 if u0 < 0.4 else 1.15 - u0), 0.0, 1.0), LIFT, LIFT + 0.8)
		show(b, LIFT, LIFT + 0.8)


func _surge() -> void:
	# the base surge: dust thrown out along the floor both ways, racing to the edges, a slower ring behind it
	var roll := gradient([Color(DUST[1], 0.0), Color(DUST[1], 0.5), Color(DUST[1].lerp(Color(SMOKE_RAMP[1]), 0.4), 0.38),
		Color(Color(SMOKE_RAMP[2]).lerp(DUST[1], 0.3), 0.22), Color(SMOKE_RAMP[3], 0.0)], [0.0, 0.05, 0.3, 0.6, 0.9])
	for s in [-1, 1]:
		var side := "L" if s < 0 else "R"
		var fast := particles("Surge" + side, {"layer": "soft", "back": true, "at": Vector2(s * 8, -5), "amount": 34, "lifetime": 1.9,
			"one_shot": true, "explosiveness": 0.9, "randomness": 0.5, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(6, 4)},
			"dir": 90 - s * 97, "spread": 8, "speed": [90, 270], "damping": [190, 250], "gravity": Vector2(0, -34),
			"scale": [5.0 / 6.5, 9.0 / 6.5], "scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": roll})
		emit(fast, LIFT + 0.05)
		var slow := particles("SurgeSlow" + side, {"layer": "soft", "back": true, "at": Vector2(s * 8, -5), "amount": 14, "lifetime": 2.2,
			"one_shot": true, "explosiveness": 0.9, "randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(6, 2.5)},
			"dir": 90 - s * 100, "spread": 8, "speed": [60, 130], "damping": [80, 110], "gravity": Vector2(0, -16),
			"scale": [8.0 / 6.5, 11.0 / 6.5], "scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": roll})
		emit(slow, LIFT + 0.1)
		# afterwinds: dust drawn back in along the floor toward the stem
		var vap := gradient([Color(DUST[1], 0.0), Color(DUST[1], 0.25), Color(DUST[1], 0.12), Color(DUST[1], 0.0)], [0.0, 0.15, 0.6, 0.97])
		var w := particles("Afterwind" + side, {"layer": "soft", "back": true, "at": Vector2(s * 105, -4), "amount": 6, "lifetime": 1.8,
			"randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(55, 2)}, "dir": 90 + s * 90, "spread": 6,
			"speed": [20, 45], "scale": [5.0 / 6.5, 8.0 / 6.5], "scale_curve": [[0, 0.6], [1, 1.5]], "ramp": vap})
		emit(w, 0.9, 4.6)
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 40, "lifetime": 2.0, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(12, 0.5)}, "dir": -90, "spread": rad_to_deg(0.7), "speed": [150, 380],
		"gravity": Vector2(0, 950), "initial": gradient([DUST[0], DUST[1], DUST[2]]), "alpha_curve": [[0, 1], [0.85, 1], [1, 0]],
		"collide": {"bounce": 0.2, "friction": 0.9}})
	emit(grit, LIFT)


func _plume() -> void:
	var n: int = PL.n
	var img := Image.create(n, 3, false, Image.FORMAT_RGBAF)
	for i in n:
		var th := TAU * fposmod(i * 0.618034 + rng.randf_range(-0.08, 0.08), 1.0)
		var ph := TAU * (i + rng.randf_range(-0.35, 0.35)) / n
		img.set_pixel(i, 0, Color(th, ph, rng.randf_range(-0.55, 0.12), rng.randf_range(PL.size[0], PL.size[1])))
		img.set_pixel(i, 1, Color(rng.randf_range(-0.22, 0.08), rng.randf_range(-1, 1), rng.randf_range(-1, 0.4), rng.randf_range(-0.9, 0.5)))
		img.set_pixel(i, 2, Color(rng.randf_range(0.55, 1.15), 0, 0, 1))
	var D: float = meta.duration
	var pl := shape("Cap", load("res://addons/pixelfx_particles/fx/explosions/_nuke_plume.gdshader"), Vector2(300, 270),
		{"lobes": ImageTexture.create_from_image(img), "count": n, "at": Vector2(PL.x, PL.y), "rise": PL.rise, "tau": PL.tau,
		"drift": PL.drift, "tube": Vector2(PL.tube[0], PL.tube[1]), "ring": Vector2(PL.ring[0], PL.ring[1]), "grow": PL.grow,
		"swell": PL.swell, "spin": PL.spin, "spin_tau": PL.spin_tau, "heat": PL.heat, "cool": PL.cool, "under": PL.under, "tilt": PL.tilt,
		"squash": PL.squash, "fade": Vector2(PL.fade[0], PL.fade[1]), "spread": PL.spread, "style": 1.0, "inner": true, "hollow": true,
		"fr": FR, "sm": PackedColorArray(CAP.map(func(c): return Color(c))), "translucent": true}, {"at": Vector2(0, -140), "back": true})
	# core shape() hands colour arrays over as PackedVector4Array, which the scene saves as null: set them back as colours
	pl.material.set_shader_parameter("fr", FR)
	pl.material.set_shader_parameter("sm", PackedColorArray(CAP.map(func(c): return Color(c))))
	key(pl, "material:shader_parameter/pt", [[0.0, 0.0], [LIFT, 0.0], [D, D - LIFT]])
	show(pl, LIFT)
	# its light: the hot heart, the fire in its lobes, and the glow lingering inside as it cools
	var heart := glow("CapGlow", 170, {"radius": 60, "color": FR[3], "alpha": 0.0})
	var fire := glow("CapFire", 120, {"radius": 40, "color": FR[2], "alpha": 0.0})
	var inner := glow("CapInner", 120, {"radius": 40, "color": FR[4], "alpha": 0.0})
	for g in [heart, fire]:
		sample(g, "position", func(t: float): return Vector2(0, shape_at(t).x), LIFT, 4.5)
	sample(inner, "position", func(t: float):
		var S := shape_at(t)
		return Vector2(0, S.x + S.y * 0.3), LIFT, 6.0)
	sample(heart, "material:shader_parameter/radius", func(t: float):
		var S := shape_at(t)
		return (S.y + S.z) * 1.8 + 14.0, LIFT, 4.5)
	sample(fire, "material:shader_parameter/radius", func(t: float):
		var S := shape_at(t)
		return (S.y + S.z) * 1.05 + 10.0, LIFT, 4.5)
	sample(inner, "material:shader_parameter/radius", func(t: float):
		var S := shape_at(t)
		return (S.y + S.z) * (0.5 + 0.7 * ember_at(t)) + 8.0, LIFT, 6.0)
	sample(heart, "material:shader_parameter/alpha", func(t: float): return 0.32 * hot_at(t) if t >= LIFT else 0.0, 0.0, 4.5)
	sample(fire, "material:shader_parameter/alpha", func(t: float):
		var base: float = PL.heat - PL.cool * maxf(0.0, t - LIFT)
		return 0.35 * clampf((base - 0.2) / 0.75, 0.0, 1.0) if t >= LIFT else 0.0, 0.0, 4.5)
	sample(inner, "material:shader_parameter/alpha", func(t: float):
		var e := ember_at(t)
		return 0.22 * e * e if t >= LIFT else 0.0, 0.0, 6.0)
	# the cap sheds embers while it's hot
	var shed := particles("Shed", {"amount": 30, "lifetime": 2.6, "randomness": 0.5, "emitting": false, "texture": "dot1",
		"emit": {"box": Vector2(50, 8)}, "dir": -90, "spread": 80, "speed": [30, 80], "damping": [25, 45], "gravity": Vector2(0, -20),
		"ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.97])})
	emit(shed, 0.3, 3.4)
	sample(shed, "position", func(t: float): return Vector2(0, shape_at(t).x), 0.3, 3.4)
	sample(shed, "amount_ratio", func(t: float): return hot_at(t), 0.3, 3.4)
	# late on, the rim frays: small puffs drift off it and thin
	var fray_c := gradient([Color(CAP[0], 0.0), Color(CAP[0], 0.55), Color(Color(CAP[1]).lerp(Color(SMOKE_RAMP[1]), 0.4), 0.4),
		Color(SMOKE_RAMP[2], 0.2), Color(SMOKE_RAMP[3], 0.0)], [0.0, 0.08, 0.4, 0.75, 0.97])
	var fray := particles("Fray", {"layer": "soft", "back": true, "amount": 40, "lifetime": 1.7, "randomness": 0.4, "emitting": false,
		"texture": "disc13", "speed": [8, 24], "damping": [4, 8], "gravity": Vector2(0, -6), "scale": [4.0 / 6.5, 6.5 / 6.5],
		"scale_curve": [[0, 0.65], [0.4, 1.2], [1, 1.5]], "ramp": fray_c})
	directed(fray, Vector2(62, 13))
	emit(fray, 4.0, 6.4)
	sample(fray, "position", func(t: float): return Vector2(0, shape_at(t).x), 4.0, 6.4)
	sample(fray, "amount_ratio", func(t: float): return smooth(4.0, 5.0, t), 4.0, 6.4)
	# the floor lit under it
	var pool := glow("Pool", 142, {"radius": 140, "squash": 16.0 / 140.0, "color": F[3]}, {"at": Vector2(0, 1)})
	sample(pool, "material:shader_parameter/alpha", func(t: float): return 0.3 * hot_at(t) if t >= LIFT else 0.0, 0.0, 4.5)


func _hollow() -> void:
	# the dark hollow under the cap where the stem goes in, its heart still warm while the inside glows
	var C4 := Color(CAP[4])
	var parts := [["Hollow", 1.0, 0.22, false, 0.0], ["HollowMid", 0.85, 0.36, false, 0.0], ["HollowCore", 0.6, 0.6, false, 0.0],
		["HollowWarm", 0.55, 0.6, true, 6.0], ["HollowHot", 0.3, 0.7, true, 5.0]]
	for pr in parts:
		var h := ring(pr[0], 90, {"radius": 10.0, "squash": 0.4, "color": C4, "translucent": true}, {"back": true})
		var f: float = pr[1]
		var a: float = pr[2]
		var warm: bool = pr[3]
		var fi: int = int(pr[4])
		sample(h, "position", func(t: float):
			var S := shape_at(t)
			return Vector2(0, S.x + S.y * 0.42), LIFT, 8.0)
		sample(h, "material:shader_parameter/radius", func(t: float):
			var S := shape_at(t)
			return (S.z * 0.7 + 5.0) * f * (ember_at(t) if warm else 1.0), LIFT, 8.0)
		sample(h, "material:shader_parameter/squash", func(t: float):
			var S := shape_at(t)
			return (S.y * 0.28 + 2.0) / (S.z * 0.7 + 5.0), LIFT, 8.0)
		sample(h, "material:shader_parameter/alpha", func(t: float):
			var gone := smooth(PL.fade[0], PL.fade[1] - 0.6, t - LIFT)
			return a * (1.0 - gone), LIFT, 8.0)
		if warm:
			sample(h, "material:shader_parameter/color", func(t: float): return C4.lerp(FR[fi], 0.75 * ember_at(t)), LIFT, 8.0)
		show(h, LIFT)


func _stem() -> void:
	# a thin stem that keeps feeding the cap, then breaks up from the bottom
	var mat := lobe_mat(0.0, true)
	var lob := data([[0.0, Color(1.1, 0, 1, 0)], [0.1, Color(1.0, 0, 1, 0.85)], [0.5, Color(0.65, 0.0, 1, 0.9)], [0.51, Color(0.64, 0.01, 0, 0.9)],
		[0.75, Color(0.43, 0.5, 0, 0.9)], [0.85, Color(0.33, 0.85, 0, 0.9)], [1.0, Color(0.2, 1.0, 0, 0.0)]])
	var windows := [[0.35, 0.8, 0.6], [0.8, 1.5, 0.85], [1.5, 2.5, 1.1], [2.5, 4.9, 1.35]]
	var first: GPUParticles2D = null
	var i := 0
	for L in windows:
		var lt: float = L[2]
		var p := particles("Stem%d" % i, {"back": true, "at": Vector2(0, -2), "amount": int(84.0 * 125.0 / (125.0 * lt)) + 6, "lifetime": lt,
			"randomness": 0.15, "emitting": false, "texture": "dot4", "emit": {"box": Vector2(1.5, 1)}, "dir": -90, "spread": 1.5,
			"speed": [110, 135], "scale": [5.5 / 2.0, 7.0 / 2.0],
			"scale_curve": [[0, 0.3], [0.06, 1.2], [0.25, 0.98], [0.5, 0.96], [1, 1.1]], "ramp": lob})
		p.material = mat
		emit(p, L[0], L[1])
		if first == null:
			first = p
		i += 1
	var foot := data([[0.0, Color(1.1, 0, 1, 0)], [0.25, Color(1.05, 0, 1, 0.85)], [1.0, Color(1.0, 0, 1, 0.0)]])
	var ft := particles("StemFoot", {"back": true, "at": Vector2(0, -4), "amount": 14, "lifetime": 0.5, "randomness": 0.3, "emitting": false,
		"texture": "dot4", "emit": {"box": Vector2(8, 1)}, "dir": -90, "spread": 10, "speed": [20, 45], "scale": [6.0 / 2.0, 8.0 / 2.0],
		"scale_curve": [[0, 0.4], [0.3, 1.2], [1, 1.1]], "ramp": foot})
	ft.material = mat
	emit(ft, 0.35, 4.9)
	# the material is shared: keyed through the first stem emitter, it heats and lights every lobe
	sample(first, "material:shader_parameter/fire", func(t: float): return clampf(1.0 - t / 1.8, 0.0, 1.0), 0.0, 1.8)
	sample(first, "material:shader_parameter/glow", func(t: float): return ember_at(t) * 0.8, 0.0, 6.4)


func _skirt(far: bool) -> void:
	# the condensation skirt: a veil arching over the cap and a bell flaring round the stem, white, then evaporating
	var ref_t := 1.0
	var S0 := shape_at(ref_t)
	var capR0 := (S0.z + S0.y) * 1.1
	var veil_h0 := S0.y * 1.15 + 6.0
	var y00 := S0.x + S0.y * 0.3
	var y10 := S0.x * 0.55
	var life: float = SKIRT[1] - SKIRT[0]
	var al := []
	for i in 13:
		var u := i / 12.0
		al.append([u, minf(1.0, u / 0.06) * pow(1.0 - u, 1.5)])
	var white := func(k: float) -> GradientTexture1D:
		var cs := []
		var offs := []
		for p in al:
			cs.append(Color(1, 1, 1, p[1] * k))
			offs.append(p[0])
		return gradient(cs, offs, true)
	if not far:
		var veil := group("Veil")
		var pts := PackedVector2Array()
		for i in 72:
			var a := -PI * ((i + rng.randf_range(0.2, 0.8)) / 72.0)
			var w := rng.randf_range(0.97, 1.06)
			pts.append(Vector2(cos(a) * capR0 * w, sin(a) * veil_h0 * w))
		var vp := particles("VeilPuffs", {"layer": "soft", "parent": veil, "local": true, "amount": 72, "lifetime": life, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "disc13", "emit": {"points": pts}, "spread": 180, "speed": [0, 10],
			"scale": [12.0 / 13.0, 20.0 / 13.0], "scale_curve": [[0, 1.0], [1, 0.5]], "ramp": white.call(0.6 * 0.38 * 1.6)})
		vp.z_index = -2
		emit(vp, SKIRT[0])
		sample(veil, "position", func(t: float): return Vector2(0, shape_at(t).x), SKIRT[0], SKIRT[1])
		sample(veil, "scale", func(t: float):
			var S := shape_at(t)
			return Vector2((S.z + S.y) * 1.1 / capR0, (S.y * 1.15 + 6.0) / veil_h0), SKIRT[0], SKIRT[1])
		show(veil, SKIRT[0], SKIRT[1])
	var bell := group("Bell" + ("Far" if far else "Near"))
	var bp := PackedVector2Array()
	for i in 110:
		var ph := rng.randf_range(0, TAU)
		var v := rng.randf_range(0, 1)
		var w := rng.randf_range(0.9, 1.06)
		var z := sin(ph)
		if (z < 0.0) != far:
			continue
		var R := lerpf(capR0 * 0.82, 13.0, pow(v, 0.6)) * w
		bp.append(Vector2(cos(ph) * R, lerpf(y00, y10, v) - y10 + z * R * 0.18))
	var sp := particles("BellPuffs", {"layer": "soft", "parent": bell, "local": true, "amount": bp.size(), "lifetime": life, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "disc13", "emit": {"points": bp}, "spread": 180, "speed": [0, 10],
		"scale": [10.0 / 13.0, 18.0 / 13.0], "scale_curve": [[0, 1.0], [1, 0.45]], "ramp": white.call(0.6 * (0.3 if far else 0.55) * 1.4)})
	sp.z_index = -2
	emit(sp, SKIRT[0])
	sample(bell, "position", func(t: float): return Vector2(0, shape_at(t).x * 0.55), SKIRT[0], SKIRT[1])
	sample(bell, "scale", func(t: float):
		var S := shape_at(t)
		var h := (S.x + S.y * 0.3) - S.x * 0.55
		return Vector2((S.z + S.y) * 1.1 / capR0, h / (y00 - y10)), SKIRT[0], SKIRT[1])
	show(bell, SKIRT[0], SKIRT[1])
	# the bell's crisp lower edge, dithering away as it evaporates
	var edge := ring("BellEdge" + ("Far" if far else "Near"), 30, {"radius": 16.25, "thickness": 1.0, "squash": 0.22, "color": Color.WHITE,
		"side": 1.0 if far else -1.0, "ragged": 0.5}, {"back": true})
	sample(edge, "position", func(t: float): return Vector2(0, shape_at(t).x * 0.55 + 2.0), SKIRT[0], SKIRT[0] + life * 0.7)
	sample(edge, "material:shader_parameter/radius", func(t: float): return 16.25 * (1.0 + (t - SKIRT[0]) / life * 0.6), SKIRT[0], SKIRT[0] + life * 0.7)
	sample(edge, "material:shader_parameter/alpha", func(t: float):
		return (1.0 - (t - SKIRT[0]) / life / 0.7) * (0.6 if far else 1.0), SKIRT[0], SKIRT[0] + life * 0.7)
	show(edge, SKIRT[0], SKIRT[0] + life * 0.7)


func _sphere() -> void:
	# the blinding frame's white-hot core, then a crisp white-hot sphere cooling into the fireball
	var core := ring("Frame", 66, {"radius": 64, "color": Color.WHITE}, {"at": Vector2(0, -40)})
	show(core, 0.0, FLASH)
	var parts := [["SphereRim", 1.0, F[6], F[5]], ["SphereCore", 0.62, Color.WHITE, F[6]]]
	for pr in parts:
		var params := {"radius": 22.0 * pr[1], "color": pr[2]}
		if pr[0] == "SphereRim":
			params.edge = 1.5
			params.edge_color = F[2]
		var s := ring(pr[0], 34, params, {"at": Vector2(0, -26)})
		var f: float = pr[1]
		var hot: Color = pr[2]
		var cool: Color = pr[3]
		sample(s, "material:shader_parameter/radius", func(t: float): return (22.0 + 8.0 * (t - FLASH) / 0.13) * f, FLASH, FLASH + 0.13, "nearest")
		sample(s, "material:shader_parameter/color", func(t: float): return hot if (t - FLASH) / 0.13 < 0.5 else cool, FLASH, FLASH + 0.13, "nearest")
		show(s, FLASH, FLASH + 0.13)


func _burst() -> void:
	var at := Vector2(0, -26)
	var fire := puffs("Fire", [7.0, 12.0], {"at": at, "amount": 26, "lifetime": 1.1, "randomness": 0.4, "emit": {"circle": 14},
		"dir": -90, "spread": 90, "speed": [40, 160], "gravity": Vector2(0, -95), "damping": [400, 700]})
	emit(fire, LIFT)
	# fire boiling up the stem early on
	var cf := puffs("StemFire", [3.5, 6.0], {"back": true, "at": Vector2(0, -6), "amount": 8, "lifetime": 0.45, "one_shot": false,
		"explosiveness": 0.0, "randomness": 0.4, "emit": {"box": Vector2(3, 3)}, "dir": -90, "spread": 4, "speed": [60, 110],
		"gravity": Vector2(0, -95), "damping": [60, 120]})
	emit(cf, 0.3, 1.1)
	var sparks := particles("Sparks", {"at": at, "amount": 90, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "randomness": 0.6,
		"emitting": false, "texture": "streak6", "align": true, "speed": [200, 420], "damping": [300, 520], "gravity": Vector2(0, 430),
		"ramp": gradient([F[6], F[5], F[3], F[2]], [0.0, 0.4, 0.7, 0.85])})
	directed(sparks, Vector2(18, 18), -PI - 0.3, 0.3)
	emit(sparks, LIFT)
	var spark_light := particles("SparkLight", {"layer": "light", "at": at, "amount": 90, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "emitting": false, "texture": "glow8", "modulate": Color(1, 1, 1, 0.35)})
	spark_light.process_material = sparks.process_material
	spark_light.seed = sparks.seed
	emit(spark_light, LIFT)
	var embers := particles("Embers", {"at": at, "amount": 40, "lifetime": 2.6, "one_shot": true, "explosiveness": 1.0, "randomness": 0.5,
		"emitting": false, "texture": "dot1", "speed": [30, 140], "damping": [40, 80], "gravity": Vector2(0, -30),
		"ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.97]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})
	directed(embers, Vector2(20, 20), -PI, 0.0)
	emit(embers, LIFT)


func _shock() -> void:
	# the shock in the air: a thin bright shell racing out from the fireball, cut off at the floor
	var sh := ring("Shock", 282, {"radius": 30, "thickness": 2.5, "color": Color.WHITE, "side": 1.0}, {"at": Vector2(0, -26)})
	sample(sh, "material:shader_parameter/radius", func(t: float): return 30.0 + 250.0 * out_cubic((t - FLASH) / 0.7), FLASH, FLASH + 0.7)
	sample(sh, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 2.5 * (1.0 - (t - FLASH) / 0.7)), FLASH, FLASH + 0.7)
	sample(sh, "material:shader_parameter/alpha", func(t: float): return minf(1.0, 1.1 - (t - FLASH) / 0.7), FLASH, FLASH + 0.7)
	sample(sh, "material:shader_parameter/color", func(t: float): return Color.WHITE if (t - FLASH) / 0.7 < 0.3 else F[6], FLASH, FLASH + 0.7, "nearest")
	show(sh, FLASH, FLASH + 0.7)
	var dome := glow("ShockLight", 290, {"radius": 30, "thickness": 7, "color": F[5], "alpha": 0.3}, {"at": Vector2(0, -26)})
	sample(dome, "material:shader_parameter/radius", func(t: float): return 30.0 + 250.0 * out_cubic((t - FLASH) / 0.7), FLASH, FLASH + 0.7)
	sample(dome, "material:shader_parameter/alpha", func(t: float): return 0.3 * (1.0 - (t - FLASH) / 0.7), FLASH, FLASH + 0.7)
	show(dome, FLASH, FLASH + 0.7)


func _light() -> void:
	# the light of it: everything washed white, falling away fast, then the fireball's own warm light
	var wash := glow("Wash", 240, {"radius": 236, "color": Color.WHITE, "alpha": 1.6, "squash": 1.0}, {"at": Vector2(0, -40)})
	sample(wash, "material:shader_parameter/alpha", func(t: float):
		return 2.4 if t < FLASH else 1.35 * exp(-(t - FLASH) / 0.13), 0.0, 0.7)
	show(wash, 0.0, 0.7)
	var warm := glow("Warm", 152, {"radius": 150, "color": F[4], "alpha": 0.0}, {"at": Vector2(0, -60)})
	sample(warm, "material:shader_parameter/radius", func(t: float): return 150.0 * (0.55 + 0.45 * clampf(1.0 - (t - LIFT) / 1.6, 0.0, 1.0)), LIFT, LIFT + 1.6)
	sample(warm, "material:shader_parameter/alpha", func(t: float):
		var k := 1.0 - (t - LIFT) / 1.6
		return 0.7 * k * k if t >= LIFT and k > 0.0 else 0.0, 0.0, LIFT + 1.6)
