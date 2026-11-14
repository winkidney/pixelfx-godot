# reimagined-from: src/fx/fire/fire-tornado.js@0f9ab2b138afd733a34503395505b37f34ea68a7
# Fire tornado: a spinning funnel of fire: spiral bands turning round it, licks flung off its sides, a ring of flame
# whirling at its foot, embers orbiting it in and out of view.
# The funnel is a per-pixel field in the original and a canvas shader here (fx/fire/_fire-tornado_funnel.gdshader:
# its snaking spine, spiral streaks, torn strands at the top and flickering edge licks, all off the loop's clock).
# Everything round it is particles: the foot's ring of little tongues (layered emitters on the far and near halves of
# an ellipse, the far half behind the funnel and a step cooler), flame puffs flung off its sides, embers orbiting
# (orbit velocity in squashed groups, the near half of each orbit in front of the funnel and the far half behind it),
# smoke spiralling off the top, and the column's flickering light.
extends "res://build/fx/fire/_fire.gd"

const S := 4
const HT := 80.0
const D := 2.0


func cx(v: float, t: float) -> float:
	var ph := t / D
	return 3.2 * sin(v * 4.2 - ph * TAU * 2.0) * v + 2.0 * sin(ph * TAU) * v


func rad(v: float) -> float:
	return 3.5 + 15.0 * pow(v, 1.35)


func fl(t: float) -> float:
	return 0.85 + 0.15 * N(t, 7.0, S + 1)


## Little tongues standing on the points of an ellipse round the foot: layered emitters sharing a seed so their
## layers nest per site.
func foot_ring(name: String, pts: PackedVector2Array, h: float, layers: Array, back: bool) -> void:
	var life := 0.2
	var k := 0
	for L in layers:
		var lw: float = L[0]
		var lh: float = L[1]
		var half := maxf(0.5, 1.6 * lw)
		var tex := "disc5" if half > 1.2 else "disc3"
		var tsize := 5.0 if tex == "disc5" else 3.0
		var sc := (2.0 * half + 1.0) / tsize
		var v := h * lh / life
		var p := particles("%s_%d" % [name, k], {"back": back, "amount": 40, "lifetime": life, "texture": tex,
			"emit": {"points": pts}, "dir": -90, "spread": 8, "speed": [v * 0.6, v * 1.1], "scale": [sc * 0.9, sc * 1.1],
			"scale_curve": TAPER, "color": H[L[2]]})
		p.seed = 4040 + (1 if back else 0)
		k += 1


## Embers orbiting the column at height v: a squashed group (the orbit's ellipse) with two emitters, one sweeping the
## near half right to left in front of the funnel, one the far half left to right behind it.
func orbit_band(i: int, v: float) -> void:
	var y := -v * HT
	for front in [true, false]:
		var g := group("Orbit%d%s" % [i, "F" if front else "B"], {"at": Vector2(0, y)})
		g.scale = Vector2(1, 0.28)
		g.z_index = 0
		var pts := PackedVector2Array()
		var R0 := rad(minf(1.0, v))
		for r in [4.0, 6.0, 8.0, 10.0, 12.0]:
			pts.append(Vector2((R0 + r) * (1.0 if front else -1.0), 0))
		var p := particles("Embers", {"parent": g, "local": true, "back": not front, "amount": 2, "lifetime": 0.55,
			"randomness": 0.4, "texture": "streak4", "align": true, "scale": [1.4, 1.4], "emit": {"points": pts}, "orbit": [-1.0, -0.8], "speed": [0, 0],
			"ramp": gradient([H[1], H[2], H[4], Color(H[4], 0.0)] if front else [H[4], H[5], H[6], Color(H[7], 0.0)], [0.0, 0.35, 0.7, 0.95])})
		p.z_index = 1 if front else -2
		p.seed = 7100 + i * 2 + (0 if front else 1)
		# its light: the same particles (same seed, amount, life and points) as small additive glows
		var lit := particles("Light", {"parent": g, "local": true, "layer": "light", "amount": 2, "lifetime": 0.55,
			"randomness": 0.4, "texture": "glow8", "emit": {"points": pts}, "orbit": [-1.0, -0.8], "speed": [0, 0],
			"color": Color(H[2], 0.6 if front else 0.2), "alpha_curve": [[0, 1], [0.7, 0.6], [1, 0]]})
		lit.seed = p.seed
		lit.z_index = 2 if front else -1
		key(g, "position", sampled(func(t: float) -> Vector2: return Vector2(cx(minf(1.0, v), t), y)))


func make() -> void:
	fire_begin()
	var GLOW := glow_colour()
	var SMOKE := SMOKE1.lerp(H[6], 0.25)

	# smoke spiralling off the top
	particles("Smoke", {"layer": "soft", "at": Vector2(0, -HT - 2), "amount": 13, "lifetime": 1.6, "randomness": 0.3,
		"texture": "disc9", "emit": {"box": Vector2(15, 3)}, "dir": -90, "spread": 35, "speed": [12, 22], "damping": [2, 4],
		"scale": [0.75, 1.1], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.3]], "ramp": smoke_ramp(SMOKE, 0.3),
		"turbulence": {"strength": 1.0, "scale": 3.0}})
	col_light("FloorLight", Vector2(0, 0.5), 40, GLOW, 0.4, 8.0 / 40.0)

	# the foot's ring: its far half behind the funnel, a step cooler
	var far := PackedVector2Array()
	var near := PackedVector2Array()
	for i in 8:
		var a := PI + PI * (i + 0.5) / 8.0
		far.append(Vector2(cos(a) * 12.0, sin(a) * 3.0))
		near.append(Vector2(cos(a - PI) * 12.0, sin(a - PI) * 3.0))
	foot_ring("RingBack", far, 6.0, BACK_LAYERS, true)

	for i in 9:
		orbit_band(i, 0.05 + i * 0.1)

	# the funnel
	var funnel := shape("Funnel", load("res://addons/pixelfx_particles/fx/fire/_fire-tornado_funnel.gdshader"), Vector2(84, 104),
		{"height": HT, "seed": float(S), "heat_ramp": gradient([H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]])},
		{"at": Vector2(0, -48)})
	loop_t(funnel)
	key(funnel, "material:shader_parameter/fl", sampled(fl))

	# flame flung off the spinning sides, cooling as it flies
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for j in 12:
			var v := 0.05 + 0.9 * j / 11.0
			pts.append(Vector2(side * rad(v), -v * HT))
		var fling := particles("Flung%s" % ("L" if side < 0 else "R"), {"amount": 9, "lifetime": 0.4, "randomness": 0.4,
			"texture": "disc3", "emit": {"points": pts}, "dir": -31.0 if side > 0 else -149.0, "spread": 18, "speed": [20, 50],
			"damping": [40, 80], "gravity": Vector2(0, -60), "scale": [0.6, 1.0], "scale_curve": [[0, 0.7], [0.15, 1.0], [1, 0.6]],
			"ramp": gradient([H[2], H[4], H[5], H[6], Color(H[7], 0.6)], [0.0, 0.1, 0.3, 0.6, 0.88])})
		key(fling, "position", sampled(func(t: float) -> Vector2: return Vector2(cx(0.5, t), 0)))

	foot_ring("RingFront", near, 7.5, LAYERS, false)

	# light: along the column, a wash round it and a hot foot
	for j in 9:
		var y := -10.0 * j
		var v := -y / HT
		var g := col_light("Column%d" % j, Vector2(0, y), rad(v) * 2.0 + 8.0, GLOW, 0.22)
		key(g, "position", sampled(func(t: float) -> Vector2: return Vector2(cx(v, t), y)))
	col_light("Wash", Vector2(0, -HT * 0.5), 80, GLOW, 0.28)
	col_light("Foot", Vector2(0, -6), 18, H[2], 0.3)


## A glow flickering with the column (the original's fl).
func col_light(name: String, at: Vector2, r: float, c: Color, k: float, squash := 1.0) -> ColorRect:
	var g := glow(name, r, {"radius": r, "color": c, "alpha": k, "squash": squash}, {"at": at})
	key(g, "material:shader_parameter/alpha", sampled(func(t: float) -> float: return k * fl(t)))
	return g
