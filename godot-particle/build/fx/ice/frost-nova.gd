# reimagined-from: src/fx/ice/frost-nova.js@ed3ad0e118a720f167f779bb81d5cb2b2623aab2
# Frost nova: frost spirals into a spinning snowflake, then a wave blooms three rings of ice crystals round the caster;
# snow drifts, frost creeps, and the ice melts back into the floor.
# Streaks spiral in to a snowflake (the snowflake shader) beating at the caster's chest; it bursts in a flare and
# flashes of light, throwing shards (bouncing on a collision floor) and snow. A band rolls out along the floor (the
# band shader, its far half behind the caster), frost creeps after it (the frost shader, the original's tufts column
# by column) and, as it passes each site, crystals punch up white with a spray of shards and vapour (emitters riding
# the wave) and glint while they stand: 32 crystal shaders laid out as the original's three rings, the back rows
# dimmer and behind. Then they sink and melt: drips and vapour, the frost fades, the cold light goes.
extends "res://build/fx/ice/_ice.gd"

const CHARGE := 0.42
const SPREAD := 0.62
const HOLD := 1.95
const MELT := 0.7
const CORE_Y := -24.0
const RINGS := [
	{"q": [0.15, 0.24], "h": [24, 32], "w": [10, 13], "n": 2, "kids": 2},
	{"q": [0.36, 0.52], "h": [13, 19], "w": [7, 9], "n": 3, "kids": 1},
	{"q": [0.62, 0.9], "h": [5, 10], "w": [4, 6], "n": 4, "kids": 0},
]

var REACH := 104.0


func front(t: float) -> float:
	return 0.0 if t < CHARGE else REACH * (1.0 - pow(1.0 - clamp01((t - CHARGE) / SPREAD), 3.0))


func reached_at(d: float) -> float:
	return CHARGE + SPREAD * (1.0 - pow(1.0 - minf(1.0, d / REACH), 1.0 / 3.0))


func make() -> void:
	REACH = meta.options.reach
	var D: float = root.duration
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var dim := gradient([C[0], C[0], C[1], C[2], C[3], C[4], C[5], C[6]])

	# frost creeping over the floor behind the wave, and the cold light it gives off
	var frost := shape("Frost", load(ICE + "_frost.gdshader"), Vector2(2 * (REACH + 20), 24), {"kind": 0, "reach": REACH,
		"ramp": ramp("palette", {"stops": 8})}, {"at": Vector2(0, 0), "back": true})
	key(frost, "material:shader_parameter/x1", sample(func(t): return maxf(12.0, front(t) + 1.0)), "nearest")
	key(frost, "material:shader_parameter/edge", sample(func(t): return front(t)), "nearest")
	key(frost, "material:shader_parameter/a", sample(func(t): return (1.0 - smooth(HOLD + 0.2, HOLD + MELT + 0.6, t)) if t > CHARGE else 0.0), "nearest")
	for i in range(-3, 4):
		var g := glow("FloorLight%d" % (i + 3), 28, {"radius": 26, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -4)})
		key(g, "position", sample(func(t): return Vector2(roundf(i / 3.5 * front(t)), -4)), "nearest")
		key(g, "material:shader_parameter/alpha", sample(func(t): return 0.16 * (1.0 - smooth(HOLD, HOLD + MELT + 0.3, t)) * (0.85 + 0.15 * sin(t * 2.4)) if t > CHARGE else 0.0), "nearest")

	# the band rolling out along the floor: its far half behind the caster, its near half in front
	for side in [1, -1]:
		var band := shape("Band%s" % ("Back" if side > 0 else "Front"), load(ICE + "_band.gdshader"), Vector2(2 * (REACH + 8), 2 * (0.16 * (REACH + 8) + 4)),
			{"radius": 2.0, "squash": 0.16, "width": 10.0, "side": float(side), "alpha": 0.0, "ramp": ramp("palette", {"stops": 8})},
			{"at": Vector2(0, 0), "back": side > 0})
		var keys := {"r": [], "w": [], "a": [], "hot": []}
		for f in int(roundf(D * FPS)) + 1:
			var t := f / FPS
			var u := clamp01((t - CHARGE) / (SPREAD + 0.15))
			var on := t >= CHARGE and u < 1.0
			keys.r.append([t, front(t) + 2.0])
			keys.w.append([t, maxf(2.0, 10.0 * pow(1.0 - u, 0.7))])
			keys.a.append([t, ((1.0 if u < 0.75 else (1.0 - u) / 0.25)) if on else 0.0])
			keys.hot.append([t, 1.0 if t - CHARGE < 0.1 else 0.0])
		key(band, "material:shader_parameter/radius", keys.r, "nearest")
		key(band, "material:shader_parameter/width", keys.w, "nearest")
		key(band, "material:shader_parameter/alpha", keys.a, "nearest")
		key(band, "material:shader_parameter/hot", keys.hot, "nearest")
	for s in [-1, 1]:
		var g := glow("FrontLight%s" % ("L" if s < 0 else "R"), 24, {"radius": 22, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -2)})
		key(g, "position", sample(func(t): return Vector2(roundf(s * (front(t) + 2.0)), -2)), "nearest")
		key(g, "material:shader_parameter/alpha", sample(func(t): return 0.55 * (1.0 - clamp01((t - CHARGE) / (SPREAD + 0.15))) if t >= CHARGE else 0.0), "nearest")

	crystals(rng, dim)
	charge()
	release()
	wave()
	hold_and_melt()


## The crystals: both sides, three rings, alternating back and front rows; each punches up as the wave reaches it.
func crystals(rng: RandomNumberGenerator, dim: GradientTexture1D) -> void:
	var D: float = root.duration
	var n := 0
	for side in [-1, 1]:
		for ri in RINGS.size():
			var rg: Dictionary = RINGS[ri]
			for i in int(rg.n):
				var q: float = rg.q[0] + ((rg.q[1] - rg.q[0]) * (i + rng.randf_range(0.2, 0.8))) / rg.n
				var h := rng.randf_range(rg.h[0], rg.h[1])
				var w := rng.randf_range(rg.w[0], rg.w[1])
				var parts := [{"dx": 0.0, "h": h, "w": w, "lean": side * h * rng.randf_range(0.1, 0.28)}]
				for k in int(rg.kids):
					var s: int = -side if k % 2 else side
					var kh := h * rng.randf_range(0.4, 0.62)
					parts.push_front({"dx": s * rng.randf_range(0.3, 0.5) * w, "h": kh, "w": w * 0.62, "lean": s * kh * rng.randf_range(0.35, 0.6)})
				var x: float = side * q * REACH
				var back := (i + ri + (1 if side > 0 else 0)) % 2 == 1
				var t0 := reached_at(q * REACH) + rng.randf_range(0, 0.03)
				var phase := rng.randf()
				for pt in parts:
					var bx: float = x + pt.dx
					var base := -1.0 if back else 0.0
					var reach := ceilf(w / 2.0 + absf(pt.lean) + 4.0)
					var node := shape("Crystal%d" % n, load(ICE + "_spike.gdshader"), Vector2(2 * reach, 2 * ceilf(h + 6)),
						{"x": bx, "base": base, "h": 0.0, "w": pt.w, "lean": 0.0, "ramp": dim if back else ramp("palette", {"stops": 8})},
						{"at": Vector2(roundf(bx), -ceilf(h + 6) + 2), "back": back})
					var kh := []
					var kw := []
					var kl := []
					var kwh := []
					var kg := []
					for f in int(roundf(D * FPS)) + 1:
						var t := f / FPS
						var m := smooth(HOLD, HOLD + MELT, t)
						var up := t >= t0 and m < 1.0
						var g := out_back(clamp01((t - t0) / 0.1), 2.6) if t >= t0 else 0.0
						var sw := fmod((t - t0) * 0.7 + phase * 3.0, 1.6) / 0.5
						kh.append([t, pt.h * g * (1.0 - m) if up else 0.0])
						kw.append([t, pt.w * (1.0 - m * 0.3)])
						kl.append([t, pt.lean * g * (1.0 - m)])
						kwh.append([t, 1.0 if t < t0 + 0.03 else 0.0])
						kg.append([t, sw if sw <= 1.0 else -1.0])
					key(node, "material:shader_parameter/h", kh, "nearest")
					key(node, "material:shader_parameter/w", kw, "nearest")
					key(node, "material:shader_parameter/lean", kl, "nearest")
					key(node, "material:shader_parameter/white", kwh, "nearest")
					key(node, "material:shader_parameter/glint", kg, "nearest")
					n += 1


## The cold gathers: streaks spiral in, vapour slides in along the floor, a snowflake spins up at the chest, beating.
func charge() -> void:
	var streaks := particles("Gather", {"at": Vector2(0, CORE_Y), "amount": 14, "lifetime": 0.25, "texture": tex("fade6"), "align": true,
		"emit": {"ring": [58, 26]}, "radial": [-500, -500], "initial": gradient([C[6], C[5]])})
	streaks.process_material.radial_velocity_min = -130.0
	streaks.process_material.radial_velocity_max = -100.0
	var gl := lit_copy(streaks, "GatherLight", "glow8", Color(C[5], 0.4))
	emit_all([streaks, gl], 0.0, CHARGE - 0.06)
	for s in [-1, 1]:
		var vap := particles("Slide%s" % ("L" if s < 0 else "R"), {"layer": "soft", "at": Vector2(s * 44, -1), "amount": 1, "lifetime": 0.42,
			"texture": tex("puff16"), "emit": {"box": Vector2(16, 1)}, "dir": 90 + s * 90, "speed": [35, 70], "damping": [40, 60],
			"scale_curve": [[0, 0.3], [1, 0.55]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
		emit(vap, 0.0, CHARGE - 0.06)
	var flake := shape("Snowflake", load(ICE + "_flake.gdshader"), Vector2(33, 33), {"r": 2.0, "branches": Vector4(0.6, 0.35, 0, 0), "nb": 1.0,
		"c6": C[6], "c5": C[5]}, {"at": cell(Vector2(0, CORE_Y))})
	var halo := glow("SnowflakeGlow", 40, {"radius": 10, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, CORE_Y)})
	var kr := []
	var kh := []
	var gr := []
	var ga := []
	var kv := []
	for f in int(roundf(CHARGE * FPS)) + 2:
		var t := f / FPS
		var k := t / CHARGE
		var beat := 1.0 + 0.25 * exp(-pow(t - CHARGE * 0.55, 2.0) / 0.002) + 0.3 * exp(-pow(t - CHARGE * 0.85, 2.0) / 0.002)
		var L := (2.0 + 5.5 * k * k) * beat
		kr.append([t, L])
		kh.append([t, 1.0 if k > 0.5 else 0.0])
		gr.append([t, 10.0 + L * 3.0])
		ga.append([t, (0.35 + 0.5 * k) if t < CHARGE else 0.0])
		kv.append([t, t < CHARGE])
	key(flake, "material:shader_parameter/r", kr, "nearest")
	key(flake, "material:shader_parameter/hot", kh, "nearest")
	key(flake, "material:shader_parameter/rot", sample(func(t): return t * 4.0, 0.0, CHARGE + 0.04), "nearest")
	key(flake, "visible", kv, "nearest")
	key(halo, "material:shader_parameter/radius", gr, "nearest")
	key(halo, "material:shader_parameter/alpha", ga, "nearest")


## The burst: a flare and flashes of light, shards and snow thrown out.
func release() -> void:
	light_flash("ReleaseCold", Vector2(0, CORE_Y), 84, C[4], 0.8, CHARGE, 0.55)
	light_flash("ReleaseWhite", Vector2(0, CORE_Y), 45, Color.WHITE, 0.7, CHARGE, 0.12)
	var fl := flare("Flare", Vector2(0, CORE_Y), 40)
	key(fl, "material:shader_parameter/len", sample(func(t): return 36.0 * pow(1.0 - (t - CHARGE) / 0.22, 1.5) if (t >= CHARGE and t < CHARGE + 0.22) else 0.0, 0.0, CHARGE + 0.3), "nearest")
	key(fl, "material:shader_parameter/k", sample(func(t): return 1.0 - (t - CHARGE) / 0.22, CHARGE, CHARGE + 0.3), "nearest")
	var white := glow("FlareLight", 48, {"radius": 46, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, CORE_Y)})
	key(white, "material:shader_parameter/alpha", sample(func(t): return 0.6 * (1.0 - (t - CHARGE) / 0.22) if (t >= CHARGE and t < CHARGE + 0.22) else 0.0, 0.0, CHARGE + 0.3), "nearest")
	var shards := particles("Shards", {"at": Vector2(0, CORE_Y), "amount": 22, "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0,
		"texture": "streak3", "emit": {"box": Vector2(3, 0.5)}, "dir": -84, "spread": 96, "speed": [110, 280], "damping": [60, 110],
		"gravity": Vector2(0, 665), "angle": [0, 360], "spin": [-1100, 1100], "initial": gradient([C[7], C[6], C[5]]),
		"alpha_curve": [[0, 1], [0.75, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
	shards.process_material.lifetime_randomness = 0.4
	emit(shards, CHARGE)
	var snow := particles("Snow", {"at": Vector2(0, CORE_Y), "amount": 14, "lifetime": 1.8, "one_shot": true, "explosiveness": 1.0,
		"texture": "dot1", "dir": -90, "spread": 90, "speed": [40, 160], "damping": [110, 160], "gravity": Vector2(0, 35),
		"initial": gradient([Color.WHITE, Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]],
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	snow.process_material.lifetime_randomness = 0.33
	emit(snow, CHARGE)


## The wave's front, both ways: vapour rolling off it, snow kicked up, crystals punching up with sprays of shards.
func wave() -> void:
	for s in [-1, 1]:
		var tag := "L" if s < 0 else "R"
		var rider := group("Front%s" % tag, {"at": Vector2(0, 0)})
		key(rider, "position", sample(func(t): return Vector2(s * front(t), 0)))
		var vap := particles("Vapour%s" % tag, {"parent": rider, "layer": "soft", "back": true, "at": Vector2(0, -2), "amount": 19, "lifetime": 0.8,
			"texture": tex("puff16"), "emit": {"box": Vector2(2, 2.5)}, "dir": 90 - s * 98, "spread": 12, "speed": [16, 76], "damping": [50, 80],
			"scale_curve": [[0, 0.45], [1, 1.0]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.3), Color(C[6], 0.12), Color(C[6], 0.0)], [0.0, 0.35, 0.7, 1.0], true)})
		vap.position = Vector2(0, -2)
		vap.process_material.lifetime_randomness = 0.4
		lit_copy(vap, "Haze%s" % tag, "glow16", Color(C[5], 0.16), [[0, 1], [1, 0]])
		var kick := particles("Kick%s" % tag, {"parent": rider, "at": Vector2(0, -2), "amount": 9, "lifetime": 1.5, "texture": "dot1",
			"dir": -90 + s * 30, "spread": 25, "speed": [30, 90], "damping": [100, 140], "gravity": Vector2(0, 35),
			"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
		kick.position = Vector2(0, -2)
		kick.process_material.lifetime_randomness = 0.3
		var spray := particles("Spray%s" % tag, {"parent": rider, "at": Vector2(0, -1), "amount": 32, "lifetime": 1.25, "texture": "streak3",
			"emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 74, "speed": [40, 170], "damping": [60, 100], "gravity": Vector2(0, 760),
			"angle": [0, 360], "spin": [-1000, 1000], "initial": gradient([C[7], C[6], C[5]]), "alpha_curve": [[0, 1], [0.75, 1], [1, 0]],
			"collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
		spray.position = Vector2(0, -1)
		spray.process_material.lifetime_randomness = 0.3
		emit_all([vap, root.get_node("Front%s/Haze%s" % [tag, tag]), kick], CHARGE, CHARGE + SPREAD)
		emit(spray, CHARGE + 0.06, CHARGE + SPREAD * 0.75)


## While it holds: glints wink on the crystals, snow drifts down. Melting: drips run off, vapour lifts.
func hold_and_melt() -> void:
	var glints := particles("Glints", {"at": Vector2(0, -14), "amount": 3, "lifetime": 0.45, "texture": "plus3", "emitting": false,
		"emit": {"box": Vector2(88, 12)}, "dir": -90, "speed": [3, 3], "initial": gradient([C[6], C[6], Color.WHITE]),
		"alpha_curve": [[0, 0], [0.15, 1], [0.4, 0.4], [0.6, 1], [0.85, 0.5], [1, 0]]})
	var hearts: GPUParticles2D = glints.duplicate()
	hearts.name = "GlintHearts"
	root.add_child(hearts)
	hearts.texture = texture("dot1")
	hearts.modulate = Color(2, 2, 2, 1)
	hearts.seed = glints.seed
	emit_all([glints, hearts], CHARGE + 0.2, HOLD + 0.2)
	var drift := particles("Drift", {"at": Vector2(0, -65), "amount": 3, "lifetime": 1.3, "texture": "dot1", "emitting": false,
		"emit": {"box": Vector2(70, 25)}, "dir": 90, "spread": 30, "speed": [3, 10], "gravity": Vector2(0, 20),
		"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	emit(drift, CHARGE + 0.2, HOLD - 0.3)
	var drips := particles("Drips", {"at": Vector2(0, -8), "amount": 6, "lifetime": 0.35, "texture": tex("fade4"), "align": true, "emitting": false,
		"emit": {"box": Vector2(80, 5)}, "dir": 90, "speed": [10, 10], "gravity": Vector2(0, 570), "color": C[5],
		"collide": {"hide": true, "size": 1}})
	emit(drips, HOLD, HOLD + MELT)
	var steam := particles("Steam", {"layer": "soft", "back": true, "at": Vector2(0, -2), "amount": 8, "lifetime": 0.75, "texture": tex("puff16"),
		"emitting": false, "emit": {"box": Vector2(83, 1.5)}, "dir": -90, "spread": 35, "speed": [6, 16], "damping": [5, 10],
		"scale_curve": [[0, 0.6], [1, 1.1]], "ramp": gradient([Color(C[5], 0.5), Color(C[5], 0.3), Color(C[5], 0.0)], [0.0, 0.5, 1.0], true)})
	lit_copy(steam, "SteamHaze", "glow16", Color(C[5], 0.16), [[0, 1], [1, 0]])
	emit_all([steam, root.get_node("SteamHaze")], HOLD, HOLD + MELT - 0.1)
