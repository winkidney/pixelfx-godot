# reimagined-from: src/fx/nature/quake.js@6fc162d3ec14caca1b85916579ee36b633ad3383
# Quake: The ground jolts three times: a rift tears out along the floor glowing deep inside, slabs of floor heave up
# and drop back askew, pebbles hop and dust bursts out of the split.
# The rift is a shader of its own (fx/nature/_rift.gdshader: the original's jagged split, lit lip, dark gap with a
# glow deep inside, closing to a scar) with a light-layer twin for its glow, uniforms keyed frame by frame from the
# original's curves (opening, gap, heat, the shake of each jolt). The slabs are faceted stones drawn the way the
# original draws them (build-time textures) whose hops are the original's little physics replayed into keys. Each jolt
# is a set of bursts along the open rift (grit, stones on a collision floor, sparks, billowing dust on the soft
# layer) and a flash of light; between jolts the split breathes grit, embers and wisps (emitters that widen with it).
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const E := preload("res://build/fx/nature/_lib_earth.gd")
const JOLTS := [0.06, 0.5, 0.92]
const CLOSE := 2.2

var REACH := 118.0


func open_at(t: float) -> float:
	return N.out_cubic((t - JOLTS[0]) / 0.45) * REACH * (0.55 + 0.45 * N.smooth(JOLTS[1], JOLTS[1] + 0.3, t))


func gapk(t: float) -> float:
	return (1.0 - N.smooth(CLOSE, CLOSE + 0.5, t)) * (0.6 + 0.4 * N.smooth(JOLTS[1], JOLTS[2] + 0.2, t))


func heat(t: float) -> float:
	return N.smooth(0, 0.3, t) * (1.0 - N.smooth(1.4, CLOSE + 0.3, t)) * (0.8 + 0.2 * sin(t * 17.0))


func shake(t: float) -> float:
	var s := 0.0
	for i in JOLTS.size():
		var tj: float = JOLTS[i]
		if t > tj:
			s += exp(-(t - tj) * 9.0) * sin((t - tj) * 80.0) * (1.6 - i * 0.3)
	return s


## keys at the original's frames (30 a second) of fn(t), held, only where the value changes, from 0
func frames_key(node: Node, prop: String, fn: Callable, t1 := -1.0) -> void:
	var keys := []
	var last: Variant = null
	for i in int(roundf((meta.duration if t1 < 0.0 else t1) * 30.0)) + 1:
		var t := i / 30.0
		var v: Variant = fn.call(t)
		if last == null or v != last:
			keys.append([t, v])
			last = v
	key(node, prop, keys, "nearest")


func light_at(name: String, at: Vector2, r: float, c: Color, k: float, t0: float, life: float) -> void:
	var g := glow(name, r + 2, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	var al := [[0.0, 0.0], [maxf(0.0, t0 - 0.001), 0.0]]
	var rad := []
	for i in 7:
		var q := 1.0 - i / 6.0
		al.append([t0 + life * i / 6.0, k * q * q])
		rad.append([t0 + life * i / 6.0, r * (0.55 + 0.45 * q)])
	key(g, "material:shader_parameter/alpha", al)
	key(g, "material:shader_parameter/radius", rad)


func burst(name: String, at: Vector2, t0: float, o: Dictionary) -> GPUParticles2D:
	var oo := {"at": at, "one_shot": true, "explosiveness": 1.0, "emitting": false}
	oo.merge(o, true)
	var p := particles(name, oo)
	if o.has("life_random"):
		p.process_material.lifetime_randomness = o.life_random
	emit(p, t0)
	return p


func make() -> void:
	ground()
	var S: PackedColorArray = root.ramps.palette
	var GL: PackedColorArray = root.ramps.glow
	REACH = meta.options.reach
	var D: float = meta.duration
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var dust := S[6].lerp(Color("#8c8494"), 0.4)
	var dust2 := S[5].lerp(Color("#6c6474"), 0.35)

	# the rift: its points, out both ways from the middle
	var rift := PackedVector2Array()
	var x := -REACH
	while x <= REACH:
		rift.append(Vector2(x, rng.randi_range(0, 2)))
		x += rng.randf_range(2.5, 5)
	assert(rift.size() <= 80)
	var pts := rift.duplicate()
	pts.resize(80)
	var body := shape("Rift", load("res://addons/pixelfx_particles/fx/nature/_rift.gdshader"), Vector2(REACH * 2 + 16, 16),
		{"stone": ramp("palette", {"stops": 8}), "glow_ramp": ramp("glow", {"stops": 5}), "rift": pts, "rift_count": float(rift.size()),
		"reach": REACH, "open": 0.0, "gapk": 0.0, "heat": 0.0, "jx": 0.0}, {"at": Vector2(0, 4), "back": true})
	var lit := shape("RiftLight", load("res://addons/pixelfx_particles/fx/nature/_rift_light.gdshader"), Vector2(REACH * 2 + 32, 24),
		{"color": GL[2], "rift": pts, "rift_count": float(rift.size()), "reach": REACH, "open": 0.0, "heat": 0.0, "jx": 0.0},
		{"at": Vector2(0, 1)})
	var u := "material:shader_parameter/"
	for n in [body, lit]:
		frames_key(n, u + "open", func(t: float) -> float: return open_at(t) if t > JOLTS[0] else -1.0)
		frames_key(n, u + "heat", func(t: float) -> float: return heat(t))
		frames_key(n, u + "jx", func(t: float) -> float: return shake(t))
	frames_key(body, u + "gapk", func(t: float) -> float: return gapk(t))
	frames_key(body, u + "flicker", func(t: float) -> float: return floorf(t * 12.0))
	key(body, u + "alpha", [[0.0, 1.0], [CLOSE + 0.3, 1.0], [CLOSE + 0.5, 0.5], [CLOSE + 0.7, 0.0]])

	# the slabs: the original's hops replayed (each jolt kicks the ones the rift has reached)
	var slabs := []
	x = -REACH + 8
	while x < REACH - 6:
		slabs.append({"x": x + rng.randf_range(-2, 2), "y": 0.0, "vy": 0.0, "a": 0.0, "va": 0.0, "rest": true, "moved": false,
			"s": rng.randf_range(4.5, 6), "side": -1.0 if rng.randf() < 0.5 else 1.0, "keys": [], "rot": [], "on": -1.0})
		x += rng.randf_range(12, 17)
	var quad := [[-1, -0.38], [1, -0.42], [1.02, 0.4], [-0.98, 0.38]]
	var dt := 1.0 / 120.0
	var j := 0
	var step := 0
	var t := 0.0
	while t <= D + 1e-6:
		if step % 4 == 0:
			var sink := N.smooth(CLOSE, CLOSE + 0.6, t)
			for s in slabs:
				if s.moved:
					s.keys.append([t, Vector2(roundf(s.x + shake(t)), roundf(s.y - 1.5 + sink * 4.0))])
					s.rot.append([t, s.a])
		t += dt
		step += 1
		while j < JOLTS.size() and t >= JOLTS[j]:
			var k := 1.0 - j * 0.2
			var L := open_at(t) + 10.0
			j += 1
			for s in slabs:
				var d: float = absf(s.x) / REACH
				if absf(s.x) > L or rng.randf() < 0.25 + d * 0.3:
					continue
				s.rest = false
				if not s.moved:
					s.moved = true
					s.on = ceilf(t * 30.0) / 30.0
				s.vy = -rng.randf_range(70, 170) * k * (1.0 - d * 0.5)
				s.va = s.side * rng.randf_range(3, 8)
		for s in slabs:
			if s.rest:
				continue
			s.vy += 950.0 * dt
			s.y += s.vy * dt
			s.a += s.va * dt
			if s.y >= 0.0 and s.vy > 0.0:
				s.y = 0.0
				s.a = clampf(s.a, -0.45, 0.45)
				if s.vy > 160.0:
					s.vy *= -0.25
					s.va *= -0.4
				else:
					s.rest = true
	var i := 0
	for s in slabs:
		if not s.moved:
			continue
		var slab := sprite("Slab%d" % i, E.rock_from(quad, s.s, 0.0, S), {"at": Vector2(s.x, -1.5)})
		key(slab, "position", s.keys, "nearest")
		key(slab, "rotation", s.rot, "nearest")
		show(slab, s.on, CLOSE + 0.6)
		key(slab, "modulate:a", [[0.0, 1.0], [CLOSE, 1.0], [CLOSE + 0.6, 0.0]])
		i += 1

	# each jolt: light, grit, stones, dust billowing out of the split, sparks
	var cloud := gradient([Color(dust, 0.0), Color(dust, 0.7), Color(dust.lerp(Color("#5d5660"), 0.35), 0.55),
		Color(dust2.lerp(Color("#433d48"), 0.5), 0.4), Color(Color("#433d48"), 0.2), Color(Color("#433d48"), 0.0)],
		[0.0, 0.05, 0.3, 0.55, 0.8, 0.95])
	for jj in JOLTS.size():
		var tj: float = JOLTS[jj]
		var k := 1.0 - jj * 0.2
		var L := open_at(tj + 0.001) + 10.0
		var n := "Jolt%d" % jj
		light_at(n + "Warm", Vector2(0, -2), 60, GL[2], 0.5 * k, tj, 0.5)
		light_at(n + "Flash", Vector2(0, -2), 26, Color.WHITE, 0.4 * k, tj, 0.07)
		for g in [["Grit", "dot1", 0.65], ["Gravel", "dot2", 0.35]]:
			burst(n + g[0], Vector2(0, -1), tj, {"amount": int(70 * k * g[2]), "lifetime": 1.0, "life_random": 0.4, "texture": g[1],
				"emit": {"box": Vector2(L, 0.5)}, "dir": -90, "spread": 34, "speed": [40 * k, 200 * k], "gravity": Vector2(0, 950),
				"initial": gradient([S[7], S[6], S[5], S[4]]), "collide": {"bounce": 0.15, "friction": 1.0}})
		var nc := int(ceil(8 * k))
		for c in 2:
			burst(n + "Stones%d" % c, Vector2(0, -2), tj, {"amount": int(ceil(nc / 2.0)), "lifetime": 1.5, "life_random": 0.3,
				"texture": N.rock(jj * 13 + c * 5 + 2, [1.9, 2.8][c], S), "emit": {"box": Vector2(L * 0.8, 0.5)}, "dir": -90,
				"spread": 52, "speed": [100 * k, 230 * k], "gravity": Vector2(0, 950), "damping": [30, 60], "angle": [0, 360],
				"spin": [-800, 800], "alpha_curve": [[0, 1], [0.75, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
		var smoke := burst(n + "Dust", Vector2(0, -3), tj, {"layer": "soft", "amount": int(ceil(14 * k)), "lifetime": 1.6,
			"life_random": 0.35, "explosiveness": 0.85, "texture": "disc11", "emit": {"box": Vector2(L * 0.9, 1.5)}, "dir": -90,
			"spread": 40, "speed": [15 * k, 55 * k], "damping": [15, 30], "gravity": Vector2(0, -18),
			"scale": [0.8 * k, 1.3 * k], "scale_curve": [[0, 0.6], [0.3, 1.0], [1, 1.5]], "ramp": cloud})
		burst(n + "Sparks", Vector2(0, -1), tj, {"amount": int(ceil(10 * k)), "lifetime": 0.3, "life_random": 0.5,
			"texture": "streak6", "align": true, "emit": {"box": Vector2(L * 0.7, 0.5)}, "dir": -90, "spread": 57,
			"speed": [120, 300], "damping": [250, 400], "gravity": Vector2(0, 430), "ramp": gradient([GL[4], GL[3], GL[2], GL[1]])})

	# between jolts the split breathes grit, embers and wisps of dust: emitters that widen as it opens
	var breath := [
		particles("Breath", {"at": Vector2(0, -1), "amount": 22, "lifetime": 0.65, "texture": "dot1", "emitting": false,
			"emit": {"box": Vector2(1, 0.5)}, "dir": -90, "spread": 20, "speed": [20, 70], "gravity": Vector2(0, 950),
			"initial": gradient([S[6], S[5]]), "collide": {"bounce": 0.1, "friction": 1.0}}),
		particles("Embers", {"at": Vector2(0, -1), "amount": 10, "lifetime": 0.9, "texture": "dot1", "emitting": false,
			"emit": {"box": Vector2(1, 0.5)}, "dir": -90, "spread": 20, "speed": [20, 45], "damping": [15, 30],
			"gravity": Vector2(0, -20), "ramp": gradient([GL[4], GL[3], GL[2]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
			"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}}),
		particles("Wisps", {"layer": "soft", "at": Vector2(0, -1), "amount": 5, "lifetime": 0.65, "texture": "disc5", "emitting": false,
			"emit": {"box": Vector2(1, 0.5)}, "dir": -90, "spread": 40, "speed": [4, 14], "damping": [10, 20],
			"scale_curve": [[0, 0.6], [1, 1.3]], "ramp": gradient([Color(dust2, 0.6), Color(dust2, 0.4), Color(dust2, 0.2)])}),
	]
	# the embers' light: the same emitter (same seed, so the same particles) on the light layer
	var ember_light := particles("EmberLight", {"layer": "light", "at": Vector2(0, -1), "amount": 10, "lifetime": 0.9, "texture": "glow8",
		"emitting": false, "emit": {"box": Vector2(1, 0.5)}, "dir": -90, "spread": 20, "speed": [20, 45], "damping": [15, 30],
		"gravity": Vector2(0, -20), "color": Color(GL[3], 0.5), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	ember_light.seed = breath[1].seed
	breath.append(ember_light)
	for b in breath:
		emit(b, JOLTS[0], CLOSE)
		var ext := []
		for f in int(CLOSE * 15.0) + 1:
			var tt := f / 15.0
			ext.append([tt, Vector3(maxf(1.0, open_at(tt)), 0.5, 0)])
		key(b, "process_material:emission_box_extents", ext)
	# slabs and stones landing kick up a little dust
	var settle := particles("Settle", {"layer": "soft", "at": Vector2(0, -1), "amount": 12, "lifetime": 0.55, "emitting": false,
		"texture": "disc5", "emit": {"box": Vector2(REACH * 0.9, 0.5)}, "dir": -90, "spread": 80, "speed": [10, 40],
		"damping": [30, 60], "scale_curve": [[0, 0.6], [1, 1.2]], "ramp": gradient([Color(dust2, 0.6), Color(dust2, 0.4), Color(dust2, 0.2)])})
	emit(settle, 0.3, 1.9)
