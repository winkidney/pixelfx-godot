# reimagined-from: src/fx/ice/ice-spikes.js@3dfab7eec367e17d933e0421966ae634b9f2660d
# Ice spikes: a frost line races along the floor and clusters of jagged ice blades burst up behind it in a rising
# wave, glint, flash white together and shatter into toppling shards.
# The frost line is the frost shader (each column grows as the line reaches it and melts oldest first, the original's
# tufts column by column) with a white-hot head of light; the clusters are blade shaders (a big blade leaning into the
# wave, a dimmer one behind, a stub in front) that punch up with the original's overshoot as the line reaches them,
# each with a spray of shards, a puff and a glint (one-shot emitters), shiver, flash white together with a sparkle on
# every tip, and break: their pieces (shard textures drawn here) tumble off with splinters, chunks, ice dust, snow
# and glints, bouncing on a collision floor.
extends "res://build/fx/ice/_ice.gd"

const START := 0.04
const RUN := 0.44
const SHIMMER := 0.74
const TREMBLE := 1.2
const FLASH := 1.36
const SHATTER := 1.42
const MELT := 1.75

var REACH := 172.0
var clusters := []


func front(t: float) -> float:
	return REACH * (1.0 - pow(1.0 - seg(t, START, START + RUN), 1.7))


func reached_at(x: float) -> float:
	return START + RUN * (1.0 - pow(1.0 - clamp01(x / REACH), 1.0 / 1.7))


func make() -> void:
	REACH = meta.options.reach
	var HEIGHT: float = meta.options.height
	var D: float = root.duration
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# the clusters: heights swelling to a crest past the middle and falling off at the end
	var x := 10.0
	while x < REACH - 2.0:
		var q := x / REACH
		var env := 0.28 + 0.72 * exp(-pow((q - 0.64) / 0.3, 2.0))
		var H := HEIGHT * env * rng.randf_range(0.88, 1.06)
		var W := clampf(H * 0.36, 5, 14)
		var lean := H * rng.randf_range(0.2, 0.34)
		var list := [
			{"dx": W * rng.randf_range(0.35, 0.6), "h": H * rng.randf_range(0.5, 0.7), "w": W * 0.7, "lean": H * rng.randf_range(0.4, 0.6), "back": true,
				"delay": rng.randf_range(0.02, 0.05), "jag": rng.randf_range(0.35, 0.6) if rng.randf() < 0.5 else -1.0, "main": false},
			{"dx": 0.0, "h": H, "w": W, "lean": lean, "back": false, "delay": 0.0, "jag": rng.randf_range(0.32, 0.58) if rng.randf() < 0.7 else -1.0, "main": true},
		]
		if H > 14:
			list.append({"dx": -W * rng.randf_range(0.35, 0.55), "h": H * rng.randf_range(0.24, 0.4), "w": W * 0.55, "lean": -H * rng.randf_range(0, 0.12),
				"back": false, "delay": rng.randf_range(0.03, 0.07), "jag": -1.0, "main": false})
		clusters.append({"x": x, "q": q, "H": H, "W": W, "blades": list, "main": list[1], "t0": reached_at(x) + 0.012})
		x += rng.randf_range(20, 26)
	var crest: Dictionary = clusters[0]
	for c in clusters:
		if c.H > crest.H:
			crest = c

	# the frost line, its white-hot head, the cold light the frosted floor gives off
	var frost := shape("Frost", load(ICE + "_frost.gdshader"), Vector2(2 * (REACH + 12), 24), {"kind": 1, "reach": REACH, "start": START, "run": RUN,
		"melt": MELT, "ramp": ramp("palette", {"stops": 8})}, {"at": Vector2(0, 0), "back": true})
	key(frost, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	key(frost, "material:shader_parameter/edge", sample(func(t): return front(t)), "nearest")
	var head := glow("Head", 18, {"radius": 16, "color": C[6], "alpha": 0.0}, {"at": Vector2(0, -2)})
	var hot := glow("HeadHot", 9, {"radius": 7, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -1)})
	key(head, "position", sample(func(t): return Vector2(roundf(front(t)), -2)), "nearest")
	key(hot, "position", sample(func(t): return Vector2(roundf(front(t)), -1)), "nearest")
	var on := func(t): return 0.6 if (t > START and front(t) < REACH) else 0.0
	key(head, "material:shader_parameter/alpha", sample(on), "nearest")
	key(hot, "material:shader_parameter/alpha", sample(on), "nearest")
	for i in 6:
		var g := glow("FloorLight%d" % i, 28, {"radius": 26, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -3)})
		key(g, "position", sample(func(t): return Vector2(roundf(front(t) * (i + 0.5) / 6.0), -3)), "nearest")
		key(g, "material:shader_parameter/alpha", sample(func(t): return 0.15 * (1.0 - smooth(MELT, MELT + 0.9, t)) * smooth(START, START + 0.3, t)), "nearest")
	light_flash("CastLight", Vector2(4, -4), 26, C[5], 0.6, START, 0.25)
	var cast := particles("CastPuff", {"layer": "soft", "at": Vector2(3, -1.5), "amount": 4, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(3, 1.5)}, "dir": -10, "spread": 12, "speed": [10, 60], "damping": [40, 80],
		"scale_curve": [[0, 0.35], [1, 0.65]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	emit(cast, START)

	# the running front throws frost: streaks along the floor, snow, vapour
	var rider := group("Front", {"at": Vector2.ZERO})
	key(rider, "position", sample(func(t): return Vector2(front(t), 0)))
	var fs := particles("FrontStreaks", {"parent": rider, "at": Vector2(-8, -2), "amount": 3, "lifetime": 0.12, "texture": tex("fade6"), "align": true,
		"emit": {"box": Vector2(4, 1)}, "dir": -4, "spread": 5, "speed": [40, 80], "initial": gradient([C[6], Color.WHITE])})
	fs.position = Vector2(-8, -2)
	var ff := particles("FrontSnow", {"parent": rider, "at": Vector2(0, -1), "amount": 3, "lifetime": 0.8, "texture": "dot1", "dir": -70, "spread": 20,
		"speed": [25, 80], "damping": [60, 100], "gravity": Vector2(0, 35), "initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	ff.position = Vector2(0, -1)
	var fv := particles("FrontVapour", {"parent": rider, "layer": "soft", "at": Vector2(0, -1.5), "amount": 2, "lifetime": 0.55, "texture": tex("puff16"),
		"dir": -10, "spread": 10, "speed": [20, 60], "damping": [40, 80], "scale_curve": [[0, 0.3], [1, 0.55]],
		"ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	fv.position = Vector2(0, -1.5)
	emit_all([fs, ff, fv], START, START + RUN - 0.02)

	blades(D)
	bursts(crest)
	shatter(rng)


## The blades: back rows first (dimmer), then the main blades, then the stubs, as the original draws them.
func blades(D: float) -> void:
	var n := int(roundf(D * FPS))
	for pass_ in 3:
		var ci := 0
		for c in clusters:
			for b in c.blades:
				if (pass_ == 0) != b.back or (pass_ == 1) != b.main:
					continue
				var bx: float = c.x + b.dx
				var reach: float = maxf(absf(b.lean), b.h) * 1.15 + b.w + 4.0
				var node := blade("Blade%d%s" % [ci, ["Back", "Main", "Stub"][pass_]], Vector2(bx, 0), Vector2(bx, 0), b.w,
					{"jag": b.jag, "dim": 1.0 if b.back else 0.0, "ymax": 0.0, "reach": reach})
				var kb := []
				var kt := []
				var kw := []
				var kg := []
				var kv := []
				for f in n + 1:
					var t := f / FPS
					var u: float = t - c.t0 - b.delay
					var g := out_back(clamp01(u / 0.09), 2.2) if u > 0.0 else 0.0
					var jx := 0.0
					if t >= TREMBLE and t < FLASH:
						jx = 1.0 if (int(floor(t * 40.0)) + int(roundf(c.x))) % 2 else 0.0
					kb.append([t, Vector2(bx + jx, 0)])
					kt.append([t, Vector2(bx + b.lean * g + jx, -b.h * g)])
					kw.append([t, 1.0 if (u < 0.03 or (t >= FLASH and t < SHATTER)) else 0.0])
					var gl: float = (t - SHIMMER - c.q * 0.34) / 0.2
					kg.append([t, gl if (gl >= 0.0 and gl <= 1.0) else -1.0])
					kv.append([t, u > 0.0 and t < SHATTER])
				key(node, "material:shader_parameter/base", kb, "nearest")
				key(node, "material:shader_parameter/tip", kt, "nearest")
				key(node, "material:shader_parameter/white", kw, "nearest")
				key(node, "material:shader_parameter/glint", kg, "nearest")
				key(node, "visible", kv, "nearest")
			ci += 1
	# light: a pop at the base as each bursts, a cold glow up its length while it stands; a sparkle on every tip as
	# they flash white
	var ci := 0
	for c in clusters:
		var g := glow("Stand%d" % ci, c.H * 0.9 + 12, {"radius": c.H * 0.9 + 10, "color": C[4], "alpha": 0.0}, {"at": Vector2(roundf(c.x + c.main.lean * 0.4), roundf(-c.H * 0.45))})
		var pop := glow("Pop%d" % ci, 15, {"radius": 14, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(roundf(c.x), -2)})
		key(g, "material:shader_parameter/alpha", sample(func(t):
			if t < c.t0 or t >= SHATTER:
				return 0.0
			var p := clamp01(1.0 - (t - c.t0) / 0.15)
			return (0.16 + 0.42 * p + (0.4 if t >= FLASH else 0.0)) * (0.85 + 0.15 * sin(t * 3.0 + c.x))), "nearest")
		key(pop, "material:shader_parameter/alpha", sample(func(t): return 0.55 * clamp01(1.0 - (t - c.t0) / 0.15) if (t >= c.t0 and t < SHATTER) else 0.0), "nearest")
		var sp := sparkle("Sparkle%d" % ci)
		var keys := []
		for f in int(roundf(D * FPS)) + 1:
			var t := f / FPS
			var arm := 6.0 * (1.0 - clamp01((t - FLASH) / 0.16)) if (t >= FLASH and t < SHATTER + 0.1) else 0.0
			keys.append([t, Vector2(c.x + c.main.lean, -c.H), arm, 0.4])
		sparkle_keys(sp, keys)
		ci += 1


## Each cluster bursts up as the line reaches it: shards sprayed forward, a puff, snow, a glint at the tip, light.
func bursts(crest: Dictionary) -> void:
	var ci := 0
	for c in clusters:
		var big: bool = is_same(c, crest)
		var n := 3 + int(roundf(c.H / 8.0))
		var sh := particles("Burst%d" % ci, {"at": Vector2(c.x, -1), "amount": n, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": "streak3", "emit": {"box": Vector2(3, 0.5)}, "dir": -80, "spread": 60, "speed": [60 * (0.45 + c.H / 44.0), 190 * (0.45 + c.H / 44.0)],
			"damping": [50, 90], "gravity": Vector2(0, 760), "angle": [0, 360], "spin": [-1000, 1000], "initial": gradient([C[5], C[6], C[7]]),
			"alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
		sh.process_material.lifetime_randomness = 0.4
		var pf := particles("Puff%d" % ci, {"layer": "soft", "at": Vector2(c.x, -1), "amount": 5 if big else 1, "lifetime": 0.9, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(6 if big else 1, 2)}, "dir": -20, "spread": 40,
			"speed": [10, 50], "damping": [30, 60], "scale_curve": [[0, 0.4 * (0.6 + c.H / 60.0)], [1, 0.75 * (0.6 + c.H / 60.0)]],
			"ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.22), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
		var fl := particles("BurstSnow%d" % ci, {"at": Vector2(c.x, -c.H * 0.25), "amount": 2, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "dot1", "emit": {"box": Vector2(4, c.H * 0.25)}, "dir": -80, "spread": 35, "speed": [20, 60], "damping": [40, 70],
			"gravity": Vector2(0, 35), "initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
		emit_all([sh, pf, fl], c.t0)
		if c.H > 16:
			var st := particles("TipStar%d" % ci, {"at": Vector2(c.x + c.main.lean, -c.H * 0.96), "amount": 1, "lifetime": 0.4, "one_shot": true,
				"explosiveness": 1.0, "emitting": false, "texture": "spark5", "dir": -90, "speed": [4, 4], "color": Color.WHITE,
				"alpha_curve": [[0, 1], [0.3, 0.5], [0.6, 1], [1, 0]]})
			emit(st, c.t0 + 0.08)
		light_flash("BurstLight%d" % ci, Vector2(c.x, -c.H * 0.4), 16 + c.H * 0.6, C[5], 0.5, c.t0, 0.18)
		if big:
			light_flash("CrestLight", Vector2(c.x, -c.H * 0.5), 54, Color.WHITE, 0.5, c.t0, 0.14)
		ci += 1
	# while they stand: glints wink on the blades; they shiver and chips fall
	var gl := particles("Glints", {"at": Vector2(REACH * 0.55, -18), "amount": 1, "lifetime": 0.4, "emitting": false, "texture": "plus3",
		"emit": {"box": Vector2(REACH * 0.4, 14)}, "dir": -90, "speed": [3, 3], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 0], [0.2, 1], [0.5, 0.4], [0.7, 1], [1, 0]]})
	emit(gl, START + RUN, TREMBLE)
	var pts := PackedVector2Array()
	for c in clusters:
		for i in 2:
			pts.append(Vector2(c.x + (i - 0.5) * 4.0, -c.H * (0.3 + 0.4 * i)))
	var chips := particles("Chips", {"at": Vector2.ZERO, "amount": pts.size(), "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"points": pts}, "dir": -90, "spread": 60, "speed": [0, 30], "gravity": Vector2(0, 760), "angle": [0, 360],
		"spin": [-1000, 1000], "initial": gradient([C[5], C[6], C[7]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	emit(chips, TREMBLE)


## All at once: every blade breaks into toppling pieces, splinters and ice dust, light along the line.
func shatter(rng: RandomNumberGenerator) -> void:
	# the pieces: tips and segments of every blade, by size; each emitter throws its pieces from where they were
	var groups := {"shard_tip_l": PackedVector2Array(), "shard_tip_m": PackedVector2Array(), "shard_tip_s": PackedVector2Array(),
		"shard_seg_l": PackedVector2Array(), "shard_seg_m": PackedVector2Array(), "shard_seg_s": PackedVector2Array()}
	var bits := PackedVector2Array()
	for c in clusters:
		for b in c.blades:
			var base := Vector2(c.x + b.dx, 0)
			var tip := base + Vector2(b.lean, -b.h)
			var cuts := [0.0, 1.0]
			if b.h > 9:
				cuts = [0.0, 0.4, 1.0]
			if b.h > 22:
				cuts = [0.0, 0.4, 0.72, 1.0]
			var sz := "l" if b.h > 30 else ("m" if b.h > 14 else "s")
			for i in cuts.size() - 1:
				var u: float = (cuts[i] + cuts[i + 1]) / 2.0
				var kind := "shard_tip_" if i == cuts.size() - 2 else "shard_seg_"
				groups[kind + sz].append(base.lerp(tip, u))
			for i in int(2 + b.h / 7.0):
				bits.append(base.lerp(tip, rng.randf()))
	for k in groups:
		var pts: PackedVector2Array = groups[k]
		if pts.is_empty():
			continue
		var big: bool = String(k).ends_with("l")
		var p := particles("Pieces_" + k, {"at": Vector2.ZERO, "amount": pts.size(), "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": tex(k), "emit": {"points": pts}, "dir": -78, "spread": 32, "speed": [40, 140 if big else 120],
			"damping": [30, 60], "gravity": Vector2(0, 855), "angle": [8, 34], "spin": [-460, 460],
			"alpha_curve": [[0, 1], [0.75, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.9, "size": 0.6}})
		p.process_material.lifetime_randomness = 0.25
		emit(p, SHATTER)
	var spl := particles("Splinters", {"at": Vector2.ZERO, "amount": bits.size(), "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"points": bits}, "dir": -80, "spread": 45, "speed": [60, 230], "damping": [50, 90], "gravity": Vector2(0, 855),
		"angle": [0, 360], "spin": [-1100, 1100], "initial": gradient([C[4], C[5], C[6], C[7]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
	spl.process_material.lifetime_randomness = 0.45
	var pick := PackedVector2Array()
	for i in bits.size():
		if i % 6 == 0:
			pick.append(bits[i])
	var lumps := particles("Lumps", {"at": Vector2.ZERO, "amount": pick.size(), "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": tex("chunk3"), "emit": {"points": pick}, "dir": -80, "spread": 45, "speed": [60, 200], "damping": [50, 90], "gravity": Vector2(0, 855),
		"angle": [0, 360], "spin": [-1100, 1100], "alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.8, "size": 2}})
	lumps.process_material.lifetime_randomness = 0.45
	emit_all([spl, lumps], SHATTER)
	# ice dust, snow and glints off every cluster, light along the line
	var at := PackedVector2Array()
	var high := PackedVector2Array()
	for c in clusters:
		at.append(Vector2(c.x, -3))
		at.append(Vector2(c.x + 4, -5))
		high.append(Vector2(c.x, -c.H * 0.6))
		high.append(Vector2(c.x + 3, -c.H * 0.3))
	var dust := particles("Dust", {"layer": "soft", "at": Vector2.ZERO, "amount": at.size(), "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"points": at}, "dir": -40, "spread": 50, "speed": [10, 50], "damping": [20, 40],
		"scale_curve": [[0, 0.45], [1, 0.9]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.22), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	var haze := lit_copy(dust, "DustHaze", "glow16", Color(C[5], 0.16), [[0, 1], [1, 0]])
	var snow := particles("ShatterSnow", {"at": Vector2.ZERO, "amount": high.size(), "lifetime": 1.4, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "dot1", "emit": {"points": high}, "dir": -75, "spread": 35, "speed": [30, 100], "damping": [60, 100],
		"gravity": Vector2(0, 35), "initial": gradient([Color.WHITE, Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	var stars := particles("ShatterStars", {"at": Vector2.ZERO, "amount": clusters.size(), "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "plus3", "emit": {"points": high}, "dir": -90, "spread": 40, "speed": [6, 20], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.3, 0.5], [0.6, 1], [1, 0]]})
	emit_all([dust, haze, snow, stars], SHATTER)
	var ci := 0
	for c in clusters:
		light_flash("BreakLight%d" % ci, Vector2(c.x, -c.H * 0.5), 22 + c.H, Color.WHITE, 0.45, SHATTER, 0.12)
		ci += 1
	for i in 5:
		light_flash("LineLight%d" % i, Vector2(REACH * (i + 0.5) / 5.0, -18), 40, C[4], 0.4, SHATTER, 0.5)
	# the debris settles: glints wink on it, pieces crumble into ice dust
	var settle := particles("DebrisGlints", {"at": Vector2(REACH * 0.55, -3), "amount": 2, "lifetime": 0.3, "emitting": false, "texture": "plus3",
		"emit": {"box": Vector2(REACH * 0.45, 2)}, "dir": -90, "speed": [3, 3], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.4, 0.4], [0.7, 1], [1, 0]]})
	emit(settle, SHATTER + 0.1, SHATTER + 0.8)
	var crumble := particles("Crumble", {"layer": "soft", "at": Vector2(REACH * 0.55, -1.5), "amount": 6, "lifetime": 0.6, "emitting": false,
		"texture": tex("puff16"), "emit": {"box": Vector2(REACH * 0.45, 1)}, "dir": -90, "spread": 50, "speed": [4, 12],
		"scale_curve": [[0, 0.3], [1, 0.5]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	emit(crumble, SHATTER + 0.3, SHATTER + 1.0)
