# reimagined-from: src/fx/explosions/dirt-explosion.js@98730262d42acee9259c349636706e9bc9dd6012
# Dirt explosion: a buried charge goes off: a flash under the floor, a V of dirt clods and grit thrown high, a brown
# dust plume that billows and settles, and a crater left behind.
# The flash is a squat white-hot dome (ring shader, upper half) with a pop of light and a pool on the floor; a band
# rolls out along the floor (ring halves behind and in front). The crater is a shader of its own
# (_dirt-explosion_crater: the original's pit, lit far rim, heaped lip and scatter) keyed open. Grit and clods are
# emitters landing on a collision floor (clods are three twin emitters sharing one material and seed: a dark rim, a
# body and a lit heart); the dust is soft puffs drawn crisp at any size (_dirt-explosion_puff), a plume punched up,
# two lobes riding the V, a skirt rolling out and dark soil; dust and crumbs kick up along the floor as the clods land.
extends "res://addons/pixelfx_particles/core/build.gd"

const OUTLINE := Color("#1a1422")
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]

var puff_mat: ShaderMaterial


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func smoothstep_(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## The original's SMOKE colour over a big puff's life: its own colour sinking into the smoke ramp, fading in fast
## and out over the last 40%.
func smoke_ramp(col: Color, strength := 0.7) -> GradientTexture1D:
	var cs := []
	var offs := []
	var n := 10
	for i in n:
		var age := (i + 0.5) / n
		var k := 1.0 - age
		var sm := Color(SMOKE_RAMP[clampi(int(floor(age * 1.05 * 5.0)), 0, 4)])
		var c := col.lerp(sm, age)
		c.a = minf(1.0, age * 12.0) * minf(1.0, k * 2.4) * strength
		cs.append(c)
		offs.append(i / float(n))
	return gradient(cs, offs)


## Soft dust puffs, drawn crisp at any size by the puff shader. size: the original's puff size (radius at birth is
## 0.65 of it, swelling to 1.6).
func puffs(name: String, o: Dictionary, size: Array) -> GPUParticles2D:
	var oo := {"layer": "soft", "back": true, "texture": "glow16", "scale": [size[0] * 2.0 / 16.0, size[1] * 2.0 / 16.0],
		"scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "one_shot": true, "explosiveness": 0.9, "randomness": 0.4}
	oo.merge(o, true)
	var p := particles(name, oo)
	p.material = puff_mat
	return p


## The original's drag (speed falling as exp(-k t)) and lift (rising on at `drift` px/s once slowed): Godot's damping
## is a constant deceleration, so instead the speed is capped by a velocity limit that decays as the drag would.
func drag(p: GPUParticles2D, v0: float, k: float, drift: float) -> void:
	var m: ParticleProcessMaterial = p.process_material
	var pts := []
	for i in 13:
		var u := i / 12.0
		pts.append([u, v0 * exp(-k * u * p.lifetime) + drift])
	m.velocity_limit_curve = curve(pts, v0 + drift)
	m.damping_min = 0.0
	m.damping_max = 0.0


func make() -> void:
	var E: PackedColorArray = root.ramps.palette
	var F: PackedColorArray = root.ramps.fire
	var grey := func(c: Color, g: Color, k: float) -> Color: return c.lerp(g, k)
	var DUST: Color = grey.call(E[4], Color8(150, 140, 150), 0.2)
	var SOIL: Color = grey.call(E[3], Color8(90, 80, 90), 0.2)
	var DARK: Color = grey.call(E[2], Color8(60, 52, 60), 0.3)
	puff_mat = ShaderMaterial.new()
	puff_mat.shader = load("res://addons/pixelfx_particles/fx/explosions/_dirt-explosion_puff.gdshader")
	puff_mat.resource_name = "Puff"
	puff_mat.set_shader_parameter("translucent", true)
	ground()

	# the crater, opening in a blink and fading at the very end
	var crater := shape("Crater", load("res://addons/pixelfx_particles/fx/explosions/_dirt-explosion_crater.gdshader"),
		Vector2(180, 20), {"reach": 28.0, "open": 0.0, "e0": E[0], "e1": E[1], "e2": E[2], "e3": E[3], "e5": E[5]},
		{"at": Vector2(0, 2), "back": true})
	var ck := []
	for i in 9:
		var t := i * 0.12 / 8.0
		ck.append([t, out_cubic(t / 0.12)])
	key(crater, "material:shader_parameter/open", ck)
	var D: float = meta.duration
	var fade := []
	for i in 7:
		var t := D - 0.7 + i * 0.1
		fade.append([t, 1.0 - smoothstep_(D - 0.7, D - 0.1, t)])
	key(crater, "material:shader_parameter/alpha", fade)

	# light: an orange pop, a white blink, a pool on the floor
	var pop := glow("Pop", 58, {"radius": 56, "color": F[4], "alpha": 0.7}, {"at": Vector2(0, -10)})
	var pk := []
	var pr := []
	for i in 12:
		var t := i * 0.22 / 11.0
		var k := 1.0 - t / 0.22
		pk.append([t, 0.7 * k * k])
		pr.append([t, 56.0 * (0.55 + 0.45 * k)])
	key(pop, "material:shader_parameter/alpha", pk)
	key(pop, "material:shader_parameter/radius", pr)
	var blink := glow("Blink", 28, {"radius": 26, "color": Color.WHITE, "alpha": 0.6}, {"at": Vector2(0, -4)})
	key(blink, "material:shader_parameter/alpha", [[0.0, 0.6], [0.03, 0.15], [0.06, 0.0]])
	var pool := glow("Pool", 62, {"radius": 60, "squash": 10.0 / 60.0, "color": F[3], "alpha": 0.5}, {"at": Vector2(0, 1)})
	key(pool, "material:shader_parameter/alpha", [[0.0, 0.5], [0.3, 0.0]])

	# the band rolling out along the floor, its far half behind and its near half in front
	for side in [[1.0, true, "BandBack"], [-1.0, false, "BandFront"]]:
		var band := ring(side[2], 92, {"radius": 2, "thickness": 3, "squash": 0.16, "color": E[5], "side": side[0]},
			{"back": side[1], "at": Vector2(0, 0.5)})
		var rk := []
		var tk := []
		var ak := []
		for i in 15:
			var t := i * 0.45 / 14.0
			var k := t / 0.45
			rk.append([t, maxf(1.0, 90.0 * out_cubic(k))])
			tk.append([t, maxf(1.0, 3.0 * (1.0 - k))])
			ak.append([t, minf(1.0, (1.1 - k) * 1.3)])
		key(band, "material:shader_parameter/radius", rk)
		key(band, "material:shader_parameter/thickness", tk)
		key(band, "material:shader_parameter/alpha", ak)
		key(band, "material:shader_parameter/color", [[0.0, E[6]], [0.15, E[5]], [0.3, E[4]]], "nearest")
		show(band, 0.0, 0.45)

	# the flash out of the ground: a squat dome of white-hot air for a frame or two
	var dome := ring("Dome", 17, {"radius": 15, "color": F[6], "edge": 1.4, "edge_color": F[2], "side": 1.0})
	var heart := ring("DomeHeart", 13, {"radius": 12, "color": Color.WHITE, "side": 1.0})
	var dr := []
	var hr := []
	for i in 7:
		var t := i * 0.09 / 6.0
		var r := 15.0 * (1.0 - t * 3.0)
		dr.append([t, r])
		hr.append([t, r * (0.8 if t < 0.05 else 0.5)])
	key(dome, "material:shader_parameter/radius", dr)
	key(heart, "material:shader_parameter/radius", hr)
	key(dome, "material:shader_parameter/color", [[0.0, F[6]], [0.05, F[5]]], "nearest")
	show(dome, 0.0, 0.09)
	show(heart, 0.0, 0.09)

	# the dust: a plume punched straight up, two lobes riding the V, a skirt rolling out, dark soil thrown up low
	for c in [[SOIL, 13, "Soil"], [DUST, 9, "Dust"]]:
		var pl := puffs("Plume" + c[2], {"at": Vector2(0, -7), "amount": c[1], "lifetime": 2.4, "emit": {"box": Vector2(7, 5)},
			"dir": -90, "spread": 12, "speed": [70, 180], "gravity": Vector2(0, -10), "randomness": 0.3, "ramp": smoke_ramp(c[0]),
			"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.005, 0.015]}}, [9, 14])
		drag(pl, 170.0, 1.2, 19.0)
	for side in [-1, 1]:
		var nm := "L" if side < 0 else "R"
		var lobe := puffs("Lobe" + nm, {"at": Vector2(side * 5, -5), "amount": 7, "lifetime": 2.4, "emit": {"box": Vector2(3, 3)},
			"dir": -90 + side * 22, "spread": 7, "speed": [110, 200], "gravity": Vector2(0, -10), "randomness": 0.2,
			"ramp": smoke_ramp(SOIL.lerp(DUST, 0.5))}, [8, 12])
		drag(lobe, 190.0, 1.3, 19.0)
		puffs("Skirt" + nm, {"at": Vector2(side * 10, -3), "amount": 8, "lifetime": 2.2, "emit": {"box": Vector2(6, 2)},
			"dir": 90 - side * 90, "spread": 4, "speed": [70, 200], "damping": [80, 130], "gravity": Vector2(0, -6),
			"ramp": smoke_ramp(DUST)}, [6, 9])
	puffs("DarkSoil", {"at": Vector2(0, -5), "amount": 8, "lifetime": 1.8, "emit": {"box": Vector2(8, 3)}, "dir": -90, "spread": 22,
		"speed": [40, 110], "damping": [60, 90], "ramp": smoke_ramp(DARK, 0.58), "scale_curve": [[0, 0.65], [0.4, 1.2], [1, 1.45]]}, [6, 9])

	# the charge: sparks out of the hole
	particles("Sparks", {"at": Vector2(0, -2), "amount": 14, "lifetime": 0.35, "one_shot": true, "explosiveness": 1.0, "randomness": 0.5,
		"texture": "streak3", "align": true, "dir": -90, "spread": 40, "speed": [160, 320], "damping": [250, 400],
		"gravity": Vector2(0, 430), "ramp": gradient([F[6], F[5], F[3], F[2]], [0.0, 0.4, 0.7, 0.85])})

	# the fountain: grit in a V, landing and lying a while
	var earth := gradient([E[1], E[2], E[2], E[3], E[3], E[4], E[5]])
	for g in [["Grit", 165, "dot1"], ["Grit2", 135, "dot2"]]:
		particles(g[0], {"at": Vector2(0, -1), "amount": g[1], "lifetime": 2.2, "one_shot": true, "explosiveness": 0.97, "randomness": 0.45,
			"texture": g[2], "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 35, "speed": [150, 440], "damping": [80, 160],
			"gravity": Vector2(0, 950), "initial": earth, "alpha_curve": [[0, 1], [0.75, 1], [1, 0]],
			"collide": {"bounce": 0.15, "friction": 1.0, "size": 1}})

	# clods thrown high, tumbling down, thudding and lying: a dark rim, an earth body, a lit heart (twins: the same
	# particles drawn three times)
	for c in [["Clod", 12, ["disc7", "disc5", "dot2"], 3], ["Pebble", 18, ["disc5", "disc3", "dot1"], 2]]:
		var tex: Array = c[2]
		var base := particles(c[0] + "Rim", {"at": Vector2(0, -2), "amount": c[1], "lifetime": 3.0, "one_shot": true, "explosiveness": 1.0,
			"randomness": 0.25, "texture": tex[0], "emit": {"box": Vector2(5, 0.5)}, "dir": -90, "spread": 34, "speed": [200, 430],
			"damping": [50, 90], "gravity": Vector2(0, 950), "modulate": OUTLINE, "alpha_curve": [[0, 1], [0.86, 1], [1, 0]],
			"scale_curve": [[0, 1.0], [0.24, 1.0], [0.3, 0.6], [1, 0.6]],
			"collide": {"bounce": 0.25, "friction": 0.9, "size": c[3]}})
		keep_colour(OUTLINE)
		var cols := [E[4], E[5]]
		for j in 2:
			var tw := particles(c[0] + ["Body", "Lit"][j], {"amount": c[1], "lifetime": 3.0, "one_shot": true, "explosiveness": 1.0,
				"randomness": 0.25, "texture": tex[j + 1], "at": Vector2(0, -2), "modulate": cols[j]})
			tw.process_material = base.process_material
			tw.seed = base.seed
			tw.collision_base_size = base.collision_base_size

	# where the clods land: dust kicked up along the floor and a spray of crumbs
	for side in [-1, 1]:
		var nm := "L" if side < 0 else "R"
		var thud := particles("Thud" + nm, {"layer": "soft", "back": true, "at": Vector2(side * 62, -1), "amount": 14, "lifetime": 0.7,
			"randomness": 0.4, "emitting": false, "texture": "disc5", "emit": {"box": Vector2(46, 0.5)}, "dir": -90, "spread": 80,
			"speed": [15, 55], "damping": [60, 100], "scale": [0.8, 1.4],
			"ramp": gradient([Color(DUST, 0.6), Color(DUST, 0.45), Color(DUST, 0.3), Color(DUST, 0.12)]),
			"scale_curve": [[0, 0.8], [1, 1.6]]})
		emit(thud, 0.45, 1.25)
		key(thud, "amount_ratio", [[0.45, 0.4], [0.65, 1.0], [1.0, 0.6], [1.25, 0.2]])
		var crumbs := particles("Crumbs" + nm, {"at": Vector2(side * 62, -1), "amount": 40, "lifetime": 1.2, "randomness": 0.4,
			"emitting": false, "texture": "dot1", "emit": {"box": Vector2(46, 0.5)}, "dir": -90, "spread": 30, "speed": [40, 140],
			"gravity": Vector2(0, 950), "initial": gradient([E[2], E[3], E[4]]), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
			"collide": {"bounce": 0.1, "friction": 1.0, "size": 1}})
		emit(crumbs, 0.45, 1.25)
