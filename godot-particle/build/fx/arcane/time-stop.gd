# reimagined-from: src/fx/arcane/time-stop.js@c617f57cccb3b6a7b9128179a0506da8b5042086
# Time stop: A clock face springs open, ticks slower and slower, freezes drained of colour, cracks, then shatters into falling shards.
# one-shot, 3.60 s, 196x136 canvas, origin [98.0, 118.0], backdrop ground
# The clock is a canvas shader (fx/arcane/_clock.gdshader: glass, rims, ticks, hands, hub, cracks and the motes circling
# it, a pass behind and a pass in front) whose scale, hands, ramp (colour, drained grey, white) and cracks are keyed
# from the original's beats; the motes run on the clock's own slowing time (integrated as the original does). Ripples
# off each tick are rings keyed on that slowing time, so they drag to a halt and hang there; a ring and a flare spring
# it open and burst it; it shatters into grey shards and chunks that tumble and settle on the floor, sparks, stars
# and a cold vapour (one-shot emitters).
extends "res://build/fx/arcane/_arcane.gd"

const CY := -42.0
const RC := 26.0
const OPEN := 0.3
const FREEZE := 1.75
const CRACK := 2.2
const SHATTER := 2.42
const TICKS := [0.36, 0.46, 0.57, 0.7, 0.85, 1.03, 1.24, 1.49]

var G: PackedColorArray


static func hand(t: float) -> float:
	var a := 0.0
	for tk in TICKS:
		if t > tk:
			a += out_back(clampf((t - tk) / 0.07, 0.0, 1.0), 3.0)
	return -PI / 2 + a * TAU / 12.0


static func flow(t: float) -> float:
	return 1.0 if t < OPEN else pow(maxf(0.0, 1.0 - (t - OPEN) / (FREEZE - OPEN)), 1.6)


static func clock_time(t: float) -> float:
	var s := 0.0
	var u := 0.0
	while u < minf(t, FREEZE):
		s += flow(u) / 120.0
		u += 1.0 / 120.0
	return s


func make() -> void:
	ground()
	G = PackedColorArray()
	for c in C:
		var l := (0.299 * c.r8 + 0.587 * c.g8 + 0.114 * c.b8)
		var g := Color8(int(l * 0.92), int(l * 0.96), mini(255, int(l * 1.06)))
		G.append(g)
		keep_colour(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var D: float = root.duration
	var mote_data := PackedVector4Array()
	var mote_cols := []
	for i in 14:
		mote_data.append(Vector4(rng.randf_range(0, TAU), RC + rng.randf_range(5, 14), rng.randf_range(1.4, 2.6) * (1 if i % 2 else -1), rng.randf_range(-0.5, 0.5)))
		mote_cols.append([Color.WHITE, C[6], C[5]][rng.randi() % 3])

	# the floor lit beneath the clock while it stands
	var fl := glow("FloorLight", 41, {"radius": 40, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -1), "back": true})
	keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.25 * smooth(0.0, OPEN, t) * (1.0 - smooth(SHATTER, SHATTER + 0.5, t)), 0.0, SHATTER + 0.55)
	key(fl, "material:shader_parameter/color", [[0.0, C[4]], [FREEZE, G[5]]], "nearest")

	# the clock: motes behind, the face and the motes in front, their light
	var cracks := crack_walks(rng)
	var clock := group("Clock", {"at": Vector2(0, CY)})
	for pz in [0.0, 1.0]:
		var face := shape("Face" if pz > 0.5 else "MotesBehind", arcane_shader("clock"), Vector2(96, 96), {"pass": pz, "rc": RC,
			"cols": v4(C), "greys": v4(G), "motes": mote_data, "mote_cols": v4(PackedColorArray(mote_cols)), "cracks": cracks, "crack_count": cracks.size()},
			{"parent": clock, "back": pz < 0.5})
		face.material.set_shader_parameter("crack_count", cracks.size())
		keyf(face, "material:shader_parameter/tc", func(t: float): return clock_time(t), 0.0, SHATTER, 30.0)
		keyf(face, "material:shader_parameter/moving", func(t: float): return flow(t), 0.0, SHATTER, 30.0)
		key(face, "material:shader_parameter/cold", [[0.0, 0.0], [FREEZE, 1.0]], "nearest")
		show(face, 0.0, SHATTER)
		if pz > 0.5:
			keyf(face, "material:shader_parameter/s", func(t: float): return out_back(t / OPEN, 2.6) if t < OPEN else 1.0, 0.0, OPEN + 0.04, 30.0)
			keyf(face, "material:shader_parameter/sa", func(t: float): return hand(t) + (sin(t * 70.0) * 0.012 if t >= FREEZE else 0.0), 0.0, SHATTER, 30.0, "nearest")
			keyf(face, "material:shader_parameter/ha", func(t: float): return -PI / 2 + (hand(t) + PI / 2) / 12.0 + 0.9, 0.0, SHATTER, 30.0, "nearest")
			key(face, "material:shader_parameter/pal", [[0.0, 0.0], [FREEZE, 2.0], [FREEZE + 0.06, 1.0], [SHATTER - 0.05, 2.0]], "nearest")
			keyf(face, "material:shader_parameter/cracked", func(t: float): return clampf((t - CRACK) / 0.18, 0.0, 1.0), CRACK - 0.04, CRACK + 0.2, 30.0, "nearest")
	var ml := shape("MoteLight", arcane_shader("clock_light"), Vector2(96, 96), {"motes": mote_data, "color": C[6]}, {"parent": clock})
	keyf(ml, "material:shader_parameter/tc", func(t: float): return clock_time(t), 0.0, SHATTER, 30.0)
	key(ml, "material:shader_parameter/color", [[0.0, C[6]], [FREEZE, G[6]]], "nearest")
	show(ml, 0.0, SHATTER)
	var cg := glow("ClockGlow", RC * 1.9 + 1, {"radius": RC * 1.9, "color": C[4], "alpha": 0.32}, {"parent": clock})
	var rg := glow("RimGlow", RC + 8, {"radius": RC, "thickness": 7, "color": C[5], "alpha": 0.28}, {"parent": clock})
	for g in [[cg, 0.32, G[5]], [rg, 0.28, G[6]]]:
		var k: float = g[1]
		keyf(g[0], "material:shader_parameter/alpha", func(t: float): return k * (out_back(t / OPEN, 2.6) if t < OPEN else 1.0), 0.0, OPEN + 0.04)
		key(g[0], "material:shader_parameter/color", [[0.0, g[0].material.get_shader_parameter("color")], [FREEZE, g[2]]], "nearest")
		show(g[0], 0.0, SHATTER)

	# springing open: a ring thrown out and a flare
	var open_ring := ring("OpenRing", RC * 1.6 + 2, {"radius": RC * 0.4, "thickness": 3, "color": Color.WHITE}, {"parent": clock})
	keyf(open_ring, "material:shader_parameter/radius", func(t: float): return RC * (0.4 + 1.2 * out_cubic(t / 0.35)), 0.0, 0.35)
	keyf(open_ring, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 3.0 * (1.0 - t / 0.35)), 0.0, 0.35)
	keyf(open_ring, "material:shader_parameter/alpha", func(t: float): return clampf(1.2 - t / 0.35, 0.0, 1.0), 0.0, 0.35)
	key(open_ring, "material:shader_parameter/color", [[0.0, Color.WHITE], [0.105, C[6]]], "nearest")
	show(open_ring, 0.0, 0.35)
	var open_flare := flare("OpenFlare", Vector2(0, CY), 28, 1.0)
	keyf(open_flare, "material:shader_parameter/len", func(t: float): return 26.0 * (1.0 - t / 0.175) + 2.0, 0.0, 0.175)
	keyf(open_flare, "material:shader_parameter/k", func(t: float): return 1.0 - t / 0.175, 0.0, 0.175)
	show(open_flare, 0.0, 0.175)

	# a ripple off each tick, on the clock's slowing time: they drag to a halt and hang there, drained
	var i := 0
	for tk in TICKS:
		var tck: float = tk
		var c0 := clock_time(tck)
		var rip := ring("Ripple%d" % i, RC + 28, {"radius": RC + 3, "thickness": 1, "color": C[5], "alpha": 0.0}, {"parent": clock})
		var q := func(t: float) -> float: return (clock_time(t) - c0) / 0.32
		keyf(rip, "material:shader_parameter/radius", func(t: float): return RC + 3.0 + 24.0 * out_cubic(minf(1.0, q.call(t))), tck, SHATTER, 30.0)
		keyf(rip, "material:shader_parameter/alpha", func(t: float):
			var qq: float = q.call(t)
			return 0.0 if qq >= 1.0 else (0.6 if t >= FREEZE else 0.8) * pow(1.0 - qq, 1.6), tck, SHATTER, 30.0)
		key(rip, "material:shader_parameter/color", [[0.0, C[5]], [FREEZE, G[5]]], "nearest")
		show(rip, tck, SHATTER)
		# a spark of light and a few stars off the hand's tip
		var a := hand(tck + 0.1)
		var tip := Vector2(cos(a), sin(a))
		var tl := glow("TickLight%d" % i, 23, {"radius": 22, "color": C[6], "alpha": 0.0}, {"parent": clock, "at": tip * (RC - 4)})
		keyf(tl, "material:shader_parameter/radius", func(t: float): return 22.0 * (0.55 + 0.45 * (1.0 - seg(t, tck, tck + 0.12))), tck, tck + 0.12)
		keyf(tl, "material:shader_parameter/alpha", func(t: float): return 0.6 * pow(1.0 - seg(t, tck, tck + 0.12), 2.0) if t >= tck else 0.0, tck - 0.04, tck + 0.13)
		var st := particles("TickStars%d" % i, {"parent": clock, "at": tip * (RC + 1), "amount": 3, "lifetime": 0.4, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "dot1", "dir": rad_to_deg(a), "spread": 30, "speed": [15, 45], "damping": [20, 40],
			"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
		life_rand(st, 0.5)
		emit(st, tck)
		i += 1

	# light as it freezes and as it bursts
	var lights := [[FREEZE, 70.0, Color.WHITE, 0.7, 0.2], [SHATTER, 80.0, Color.WHITE, 0.8, 0.16], [SHATTER, 100.0, C[5], 0.6, 0.6]]
	for j in lights.size():
		var L: Array = lights[j]
		var t0: float = L[0]
		var r0: float = L[1]
		var kk: float = L[3]
		var life: float = L[4]
		var lg := glow("Light%d" % j, r0 + 1, {"radius": r0, "color": L[2], "alpha": 0.0}, {"parent": clock})
		keyf(lg, "material:shader_parameter/radius", func(t: float): return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0, t0 + life)
		keyf(lg, "material:shader_parameter/alpha", func(t: float): return kk * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 else 0.0, t0 - 0.04, t0 + life + 0.01)

	shatter()


static func v4(cs: PackedColorArray) -> PackedVector4Array:
	var out := PackedVector4Array()
	for c in cs:
		out.append(Vector4(c.r, c.g, c.b, c.a))
	return out


## The cracks: jagged walks out from a point on the face, as the original walks them, flattened into pixels (x, y,
## index along the walk, the walk's length) for the shader.
func crack_walks(rng: RandomNumberGenerator) -> PackedVector4Array:
	var ix := rng.randf_range(-6, 6)
	var iy := rng.randf_range(-6, 6)
	var walks := []
	var walk := func(self_ref: Callable, x: float, y: float, a: float, n: int, depth: int) -> void:
		var pts := [Vector2(x, y)]
		for s in n:
			a += rng.randf_range(-0.55, 0.55)
			x += cos(a) * rng.randf_range(1.6, 2.6)
			y += sin(a) * rng.randf_range(1.6, 2.6)
			if Vector2(x, y).length() > RC - 0.5:
				break
			pts.append(Vector2(x, y))
			if depth < 1 and pts.size() > 3 and rng.randf() < 0.14:
				self_ref.call(self_ref, x, y, a + (1 if rng.randf() < 0.5 else -1) * rng.randf_range(0.6, 1.1), n / 2, depth + 1)
		walks.append(pts)
	for i in 7:
		walk.call(walk, ix, iy, i / 7.0 * TAU + rng.randf_range(-0.3, 0.3), 16, 0)
	var out := PackedVector4Array()
	for pts in walks:
		for k in pts.size():
			if out.size() < 160:
				out.append(Vector4(pts[k].x, pts[k].y, k, pts.size()))
	return out


func shatter() -> void:
	var at := Vector2(0, CY)
	var greys := gradient([G[7], G[6], G[6], G[5]])
	# the face bursts into tumbling grey shards and chunks that land and settle
	var shards := particles("Shards", {"at": at, "amount": 64, "lifetime": 1.15, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"circle": RC}, "dir": -90, "spread": 20, "speed": [40, 120], "damping": [10, 30],
		"gravity": Vector2(0, 855), "angle": [0, 360], "spin": [-1200, 1200], "initial": greys, "alpha_curve": [[0, 1], [0.85, 1], [1, 0]],
		"collide": {"bounce": 0.25, "friction": 0.9, "size": 1}})
	radial_speed(shards, 40, 140)
	life_rand(shards, 0.3)
	emit(shards, SHATTER)
	var chunks := particles("Chunks", {"at": at, "amount": 10, "lifetime": 1.15, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "dot3", "emit": {"circle": RC * 0.6}, "dir": -90, "spread": 15, "speed": [60, 130], "damping": [8, 20],
		"gravity": Vector2(0, 950), "scale": [0.6, 1.0], "angle": [0, 360], "spin": [-800, 800], "initial": gradient([G[3], G[4], G[6], G[7]]),
		"alpha_curve": [[0, 1], [0.85, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.9, "size": 2}})
	radial_speed(chunks, 40, 110)
	life_rand(chunks, 0.2)
	emit(chunks, SHATTER)
	# colour sparks back into the world: motes, stars and sparks
	var cols := gradient([Color.WHITE, C[6], C[5]])
	var motes := particles("Motes", {"at": at, "amount": 13, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "align": true, "spread": 180, "speed": [30, 110], "damping": [15, 40], "initial": cols, "alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	life_rand(motes, 0.5)
	emit(motes, SHATTER)
	var stars := particles("Stars", {"at": at, "amount": 13, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "spread": 180, "speed": [30, 110], "damping": [40, 90], "gravity": Vector2(0, -5), "initial": cols,
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(stars, 0.5)
	emit(stars, SHATTER)
	var sparks := particles("Sparks", {"at": at, "amount": 18, "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak4", "align": true, "spread": 180, "speed": [90, 200], "damping": [200, 350], "gravity": Vector2(0, 428),
		"ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
	life_rand(sparks, 0.55)
	emit(sparks, SHATTER)
	# the stopped time it held lifts away as a cold vapour
	var vap := particles("Vapour", {"layer": "soft", "at": at, "amount": 12, "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "disc9", "emit": {"circle": RC * 0.8}, "dir": -90, "spread": 60, "speed": [10, 30], "damping": [10, 20],
		"scale": [0.7, 1.3], "scale_curve": [[0, 0.7], [1, 1.5]], "initial": gradient([G[5], C[4]]),
		"alpha_curve": [[0, 0.45], [0.5, 0.25], [1, 0]]})
	radial_speed(vap, 10, 35)
	life_rand(vap, 0.4)
	emit(vap, SHATTER)
	# a flare and a white ring as it bursts
	var fl := flare("BurstFlare", at, 36, 1.0)
	keyf(fl, "material:shader_parameter/len", func(t: float): return 34.0 * (1.0 - seg(t, SHATTER, SHATTER + 0.2)) + 2.0, SHATTER, SHATTER + 0.2)
	keyf(fl, "material:shader_parameter/k", func(t: float): return 1.0 - seg(t, SHATTER, SHATTER + 0.2), SHATTER, SHATTER + 0.2)
	show(fl, SHATTER, SHATTER + 0.2)
	var br := ring("BurstRing", RC + 32, {"radius": RC, "thickness": 3, "color": Color.WHITE}, {"at": at})
	keyf(br, "material:shader_parameter/radius", func(t: float): return RC + 30.0 * out_cubic(seg(t, SHATTER, SHATTER + 0.2)), SHATTER, SHATTER + 0.2)
	keyf(br, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 3.0 * (1.0 - seg(t, SHATTER, SHATTER + 0.2))), SHATTER, SHATTER + 0.2)
	keyf(br, "material:shader_parameter/alpha", func(t: float): return clampf(1.2 - seg(t, SHATTER, SHATTER + 0.2), 0.0, 1.0), SHATTER, SHATTER + 0.2)
	show(br, SHATTER, SHATTER + 0.2)
