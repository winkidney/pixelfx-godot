# reimagined-from: src/fx/arcane/spell-charge.js@c59d187dbba27d6926385f9977b1758587605eb0
# Spell charge: Energy gathers in the caster's hand: streaks and motes spiral in, rings collapse into a swelling orb that crackles with arcs, ready to fire.
# loop, 1.60 s, 120x86 canvas, origin [44.0, 80.0], backdrop ground, stand-in 2
# The orb in the hand is four discs (ring shader) whose radius follows the original's pulse and swell, shivering a pixel
# as each ring lands, with flickering rays (lines re-keyed every frame) and filaments crackling through it (bolts);
# four tilted rings collapse onto it (fx/arcane/_tiltring.gdshader, cut at the floor); streaks and motes spiral in
# (emitters pulling inward and swirling, a light copy of the streaks); arcs crackle off it (bolts on fresh angles
# every other frame); glints wink round it; light pools round the hand and on the floor.
extends "res://build/fx/arcane/_arcane.gd"

const D := 1.6
const HX := 15.0
const HY := -22.0
const RINGS := 4
const RT := 0.5
const SHAPES := [[1.0, 0.0], [0.38, 0.55], [1.0, 0.0], [0.42, -0.7]]


static func since_last(t: float) -> float:
	var m := 1e9
	for k in RINGS:
		var l := k * D / RINGS + RT
		m = minf(m, fposmod(t - l, D))
	return m


static func swell(t: float) -> float:
	var s := since_last(t)
	return exp(-pow(s / 0.07, 2.0)) + 0.5 * exp(-pow(s / 0.18, 2.0))


static func radius(t: float) -> float:
	return 6.1 + 0.5 * sin(t / D * TAU * 4) + 1.4 * swell(t)


static func pulse(t: float) -> float:
	return 0.85 + 0.15 * sin(t / D * TAU * 4) + 0.2 * swell(t)


static func jit(t: float) -> float:
	var f := int(floorf(t * 30.0 + 0.001))
	return (1.0 if f % 2 else -1.0) if swell(t) > 0.4 else 0.0


func make() -> void:
	# light: a wide pool that lights the caster, the floor beneath the hand
	var pool := glow("Pool", 47, {"radius": 46, "color": C[4], "alpha": 0.26}, {"at": Vector2(HX, HY)})
	keyf(pool, "material:shader_parameter/alpha", func(t: float): return 0.26 * pulse(t))
	var floor_light := glow("FloorLight", 23, {"radius": 22, "color": C[5], "alpha": 0.16}, {"at": Vector2(HX, -1)})
	keyf(floor_light, "material:shader_parameter/alpha", func(t: float): return 0.16 * pulse(t))

	# streaks spiralling in from the left, above and the upper right, and slower motes on the same swirl
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var far_pts := PackedVector2Array()
	var near_pts := PackedVector2Array()
	for i in 160:
		var a := rng.randf_range(2.8, 5.75)
		var d := rng.randf_range(20, 52) + 6.0
		far_pts.append(Vector2(cos(a) * d, sin(a) * d * 0.92))
		var a2 := rng.randf_range(2.6, 5.2)
		var d2 := rng.randf_range(12, 32) + 6.0
		near_pts.append(Vector2(cos(a2) * d2, sin(a2) * d2))
	var so := {"at": Vector2(HX, HY), "amount": 20, "lifetime": 0.34, "texture": "streak6", "align": true, "emit": {"points": far_pts},
		"radial": [-700, -420], "tangential": [60, 160], "initial": gradient([C[6], C[5]], [0.0, 0.55]),
		"alpha_curve": [[0, 0], [0.25, 1], [0.9, 1], [1, 0]]}
	var streaks := particles("Streaks", so)
	life_rand(streaks, 0.41)
	var sl := so.duplicate()
	sl.layer = "light"
	sl.texture = "glow8"
	sl.align = false
	sl.erase("initial")
	sl.color = Color(C[5], 0.35)
	sl.alpha_curve = [[0, 0], [0.25, 1], [0.6, 1], [0.9, 0]]
	var streak_light := particles("StreakLight", sl)
	life_rand(streak_light, 0.41)
	streak_light.seed = streaks.seed
	var motes := particles("Motes", {"at": Vector2(HX, HY), "amount": 19, "lifetime": 0.7, "texture": "streak3", "align": true,
		"emit": {"points": near_pts}, "radial": [-120, -60], "orbit": [0.25, 0.5], "initial": gradient([C[5], C[6], C[6], Color.WHITE]),
		"alpha_curve": [[0, 0], [0.33, 1], [0.9, 1], [1, 0]]})
	life_rand(motes, 0.43)

	# rings collapsing onto the orb, each tilted its own way, cut at the floor
	for k in RINGS:
		var t0 := k * D / RINGS
		var sh: Array = SHAPES[k]
		var rr := shape("Ring%d" % k, arcane_shader("tiltring"), Vector2(70, 70), {"radius": 30, "squash": sh[0], "rot": sh[1],
			"color": C[5], "cut_y": -0.5, "alpha": 0.0}, {"at": Vector2(HX, HY)})
		var q := func(t: float) -> float: return fposmod(t - t0, D) / RT
		keyf(rr, "material:shader_parameter/radius", func(t: float):
			var qq: float = q.call(t)
			return radius(t) + 1.5 + 22.0 * (1.0 - qq * qq) if qq < 1.0 else 1.0, 0.0, -1.0, 30.0, "nearest")
		keyf(rr, "material:shader_parameter/alpha", func(t: float):
			var qq: float = q.call(t)
			return minf(1.0, qq * 3.0) if qq < 1.0 else 0.0, 0.0, -1.0, 30.0, "nearest")
		keyf(rr, "material:shader_parameter/color", func(t: float):
			var qq: float = q.call(t)
			return Color.WHITE if qq > 0.85 else C[6] if qq > 0.55 else C[5], 0.0, -1.0, 30.0, "nearest")
		keyf(rr, "position", func(t: float): return Vector2(HX + jit(t), HY), 0.0, -1.0, 30.0, "nearest")

	# the orb: rays, a violet rim, a bright body lit from the top left, a white heart, filaments, a glint
	var orb := group("Orb", {"at": Vector2(HX, HY)})
	keyf(orb, "position", func(t: float): return Vector2(HX + jit(t), HY), 0.0, -1.0, 30.0, "nearest")
	var nrng := RandomNumberGenerator.new()
	nrng.seed = 55
	for i in 8:
		var ii := i
		var p0 := nrng.randf() * TAU
		var p1 := nrng.randf() * TAU
		var ray := line("Ray%d" % i, PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]), {"parent": orb,
			"gradient": gradient([C[6], C[4] if i % 2 else C[5], Color(C[4] if i % 2 else C[5], 0.6)], [0.0, 0.4, 0.75])})
		keyf(ray, "points", func(t: float):
			var ph := t / D
			var a := ii / 8.0 * TAU + ph * TAU / 8.0 * 3.0
			var n := absf(0.6 * sin(ph * TAU * 3 + p0) + 0.4 * sin(ph * TAU * 5 + p1))
			var l := (1.5 + 4.5 * n) * (0.7 if ii % 2 else 1.0)
			var dir := Vector2(cos(a), sin(a))
			var r0 := radius(t) + 1.2
			var out := PackedVector2Array()
			var m := maxi(2, int(ceilf(l)) + 1)
			for j in m:
				out.append(dir * (r0 + l * j / float(m - 1)))
			return out, 0.0, -1.0, 30.0, "nearest")
	var discs := [[1.3, 1.0, C[4], Vector2.ZERO], [0.3, 1.0, C[5], Vector2.ZERO], [0.0, 0.8, C[6], Vector2(-0.12, -0.12)], [0.0, 0.5, Color.WHITE, Vector2.ZERO]]
	for i in discs.size():
		var dd: Array = discs[i]
		var disc := ring("Disc%d" % i, 12, {"radius": 6, "color": dd[2]}, {"parent": orb})
		keyf(disc, "material:shader_parameter/radius", func(t: float): return radius(t) * dd[1] + dd[0], 0.0, -1.0, 30.0, "nearest")
		if dd[3] != Vector2.ZERO:
			keyf(disc, "position", func(t: float): return dd[3] * radius(t), 0.0, -1.0, 30.0, "nearest")
	for i in 3:
		var fil := bolt("Filament%d" % i, Vector2(2, 0), Vector2(6, 0), {"parent": orb, "width": 1, "color": Color.WHITE, "jag": 1.2,
			"segments": 3, "rate": 30, "seed": 300 + i, "gradient": gradient([Color.WHITE, C[6]], [0.0, 0.6])})
		var frng := RandomNumberGenerator.new()
		frng.seed = 900 + i
		var angs := []
		for s in 25:
			angs.append([frng.randf() * TAU, frng.randf_range(-0.6, 0.6)])
		keyf(fil, "from", func(t: float):
			var A: Array = angs[int(floorf(t * 15.0 + 0.001)) % angs.size()]
			return Vector2(cos(A[0]), sin(A[0])) * radius(t) * 0.4, 0.0, -1.0, 30.0, "nearest")
		keyf(fil, "to", func(t: float):
			var A: Array = angs[int(floorf(t * 15.0 + 0.001)) % angs.size()]
			return Vector2(cos(A[0] + A[1]), sin(A[0] + A[1])) * (radius(t) + 0.6), 0.0, -1.0, 30.0, "nearest")
	var gl := rect("Glint", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": orb})
	keyf(gl, "position", func(t: float): return Vector2(-radius(t) * 0.5, -radius(t) * 0.62).floor(), 0.0, -1.0, 30.0, "nearest")
	var heart := glow("HeartLight", 9, {"radius": 7, "color": C[6], "alpha": 0.12}, {"parent": orb})
	keyf(heart, "material:shader_parameter/radius", func(t: float): return radius(t))
	var rim := glow("RimLight", 22, {"radius": 9, "thickness": 8, "color": C[5], "alpha": 0.3}, {"parent": orb})
	keyf(rim, "material:shader_parameter/radius", func(t: float): return radius(t) + 3.0)
	keyf(rim, "material:shader_parameter/alpha", func(t: float): return 0.3 * pulse(t))
	# the sparkle as each ring lands
	var land := sparkle("Land", Vector2.ZERO, 4, C[6], C[5], {"parent": orb})
	keyf(land, "material:shader_parameter/arm", func(t: float): return 4.0 + 6.0 * (1.0 - since_last(t) / 0.07) if since_last(t) < 0.07 else 0.0, 0.0, -1.0, 30.0, "nearest")

	# arcs crackling off it, on fresh angles every other frame
	var arng := RandomNumberGenerator.new()
	arng.seed = 77
	var arcs := []
	for w in 25:
		var list := []
		for i in 2:
			var a := arng.randf() * TAU
			list.append([a, arng.randf_range(5, 10), a + arng.randf_range(-0.5, 0.5), arng.randf() < 0.6])
		arcs.append(list)
	for i in 2:
		var ii := i
		var spec := func(t: float) -> Array:
			var w := int(floorf(t * 15.0 + 0.001)) % arcs.size()
			return arcs[w][ii]
		var on := func(t: float) -> bool:
			var sp: Array = spec.call(t)
			return (sp[3] if ii == 0 else swell(t) > 0.3)
		var ends := func(t: float) -> Array:
			var sp: Array = spec.call(t)
			var r := radius(t)
			var x0 := Vector2(cos(sp[0]), sin(sp[0])) * (r + 0.5)
			var L: float = sp[1] * (1.0 + swell(t) * 0.4)
			var x1 := x0 + Vector2(cos(sp[2]), sin(sp[2])) * L
			x1.y = minf(-2.0 - HY, x1.y)
			return [x0, x1]
		for layer in [["Body", C[5], 2.0], ["Core", Color.WHITE, 1.0]]:
			var b := bolt("Arc%d%s" % [i, layer[0]], Vector2.ZERO, Vector2(8, 0), {"parent": orb, "width": layer[2], "color": layer[1],
				"jag": 1.6, "segments": 4, "rate": 30, "seed": 500 + i, "branches": 1 if i == 0 else 0, "branch_length": 0.4})
			keyf(b, "from", func(t: float): return ends.call(t)[0], 0.0, -1.0, 30.0, "nearest")
			keyf(b, "to", func(t: float): return ends.call(t)[1], 0.0, -1.0, 30.0, "nearest")
			keyf(b, "visible", func(t: float): return on.call(t), 0.0, -1.0, 30.0, "nearest")
		var al := glow("ArcLight%d" % i, 9, {"radius": 7, "color": C[5], "alpha": 0.25}, {"parent": orb})
		keyf(al, "position", func(t: float): return (ends.call(t)[0] + ends.call(t)[1]) / 2.0, 0.0, -1.0, 30.0, "nearest")
		keyf(al, "visible", func(t: float): return on.call(t), 0.0, -1.0, 30.0, "nearest")

	# glints winking round it
	particles("Glints", {"at": Vector2(HX, HY), "amount": 2, "lifetime": 0.22, "texture": "spark7", "emit": {"ring": [16, 11]},
		"color": C[6], "scale_curve": [[0, 0.3], [0.5, 1.0], [1, 0.3]]})
