# reimagined-from: src/fx/fire/campfire.js
# Campfire: crossed logs on a bed of coals and a lively fire: tongues that lick and leap, popping sparks, embers
# drifting up, smoke curling off, a warm pool of light.
# The logs and the dark of the coal bed are the original's pixels (port/props.py, split into the far ends behind the
# flames and the near halves in front); the coals and the cracks in the charred wood breathe in a small shader
# (fx/fire/_campfire_bed.gdshader). The fire is eleven layered tongues (fire/_fire.gd), flame puffs licking up off
# the wood, puffs and licks torn off the tips, a thick smoke plume curling off with the draught, embers, pops that
# throw sparks bouncing on the floor, and the fire's breathing light on the wall and the floor.
extends "res://build/fx/fire/_fire.gd"

const S := 3
const HC := 22.0
const TONGUES := [
	[-7.5, -7, 0.42, 1.8, 1], [7.5, -7, 0.46, 1.8, 1], [-3, -9, 0.78, 2.0, 1], [3.2, -9, 0.82, 2.0, 1],
	[-12, -3, 0.14, 1.3, 0], [12.5, -3, 0.16, 1.3, 0], [-9.5, -4.5, 0.3, 1.9, 0], [9.5, -4.5, 0.34, 1.9, 0],
	[-5, -6, 0.6, 2.6, 0], [5.2, -6, 0.66, 2.6, 0], [0, -7, 1, 3.4, 0],
]
const BED := "res://addons/pixelfx_particles/fx/fire/_campfire_bed.gdshader"
## a leaner tongue than the shared one: the original's campfire tongues end in thin leaping tips
const LEAN_TAPER := [[0.0, 0.55], [0.08, 1.0], [0.25, 0.68], [0.5, 0.4], [0.75, 0.2], [1.0, 0.06]]


func tongue(name: String, at: Vector2, h: float, w: float, o: Dictionary = {}) -> Array:
	# one layer at a time so each gets its own taper, floored at a pixel: tiny discs only speckle
	var layers: Array = o.get("layers", BIG_LAYERS if w > 2.2 else LAYERS)
	var out := []
	var k := 0
	for L in layers:
		var m := 1.15 / (2.0 * maxf(0.5, w * L[0]) + 1.0)
		var taper := []
		for q in LEAN_TAPER:
			taper.append([q[0], maxf(q[1], m)])
		var oo := o.duplicate()
		oo.layers = [L]
		oo.taper = taper
		oo.density = 1.3
		out += super.tongue("%s_%d" % [name, k], at, h * 1.12, w, oo)
		k += 1
	return out


func make() -> void:
	fire_begin()
	ground()
	var GLOW := glow_colour()
	var bed_cols := {"c_yellow": H[2], "c_gold": H[3], "c_orange": H[4], "c_red": H[5]}

	# light: a pool on the floor
	fire_glow("FloorLight", Vector2(0, 0.5), 48, GLOW, 0.3, S, 8.0 / 48.0)

	# smoke curling off the top, behind everything, bent over by the draught as it rises
	var smoke_col := SMOKE1.lerp(H[6], 0.25)
	var smoke := particles("Smoke", {"layer": "soft", "at": Vector2(0, -HC * 0.8 - 4), "amount": 40, "lifetime": 2.6, "randomness": 0.3,
		"texture": "disc9", "emit": {"box": Vector2(4, 4)}, "dir": -90, "spread": 6, "speed": [16, 24], "damping": [1, 2],
		"gravity": Vector2(4, -10), "scale": [0.5, 0.85], "scale_curve": [[0, 0.75], [0.4, 1.0], [1, 1.3]],
		"ramp": gradient([Color(smoke_col, 0.0), Color(smoke_col, 0.42), Color(smoke_col.lerp(Color("#5d5660"), 0.4), 0.36),
			Color(Color("#5d5660"), 0.22), Color(Color("#433d48"), 0.0)], [0.0, 0.08, 0.4, 0.75, 0.97]),
		"turbulence": {"strength": 1.5, "scale": 3.0}})
	key(smoke, "position", sampled(func(t): return Vector2(N(t, 0.8, S + 60) * 2.0, -HC * 0.8 - 4)))

	# the coal bed and the logs' far ends, behind the flames
	var coals := shape("Coals", load(BED), Vector2(32, 8), bed_cols.merged({"mode": 0.0}), {"at": Vector2(0, -1)})
	loop_t(coals)
	sprite("PropBack", load("res://addons/pixelfx_particles/fx/fire/campfire/prop_back.png"), {"centered": false,
		"at": -Vector2(root.origin), "layer": "prop"})
	var TT := flames(Vector2.ZERO, TONGUES, HC, {"seed": S, "lean": 0.12, "life": 0.36})
	# flames licking up off the burning wood
	particles("WoodFlames", {"at": Vector2(0, -5.5), "amount": 9, "lifetime": 0.24, "randomness": 0.4, "texture": "disc3",
		"emit": {"box": Vector2(10, 2.5)}, "dir": -90, "spread": 10, "speed": [20, 40], "gravity": Vector2(0, -95), "damping": [10, 20],
		"scale": [0.7, 1.1], "scale_curve": [[0, 0.7], [0.15, 1.0], [1, 0.5]],
		"ramp": gradient([H[1], H[2], H[3], H[4], H[5], H[6]], [0.0, 0.12, 0.3, 0.5, 0.7, 0.88])})
	tip_bits(Vector2.ZERO, TT, {"puffs": 8, "licks": 4, "size": 0.85})
	# the logs' near halves over the fire, the embers in their charred cracks under them
	var cracks := shape("Cracks", load(BED), Vector2(20, 12), bed_cols.merged({"mode": 1.0}), {"at": Vector2(0, -3)})
	loop_t(cracks)
	prop({"back": false})

	# pops: a crack, a flash, and a fistful of sparks thrown up out of the wood that bounce on the floor
	var rng := RandomNumberGenerator.new()
	rng.seed = S * 31 + 4
	for i in 4:
		var at := Vector2(rng.randf_range(-9, 9), -rng.randf_range(4, 9))
		var t0: float = (i + rng.randf_range(0.1, 0.8)) * root.duration / 4.0
		var pop := particles("Pop%d" % i, {"at": at, "amount": rng.randi_range(3, 5), "lifetime": 0.6, "one_shot": true,
			"explosiveness": 1.0, "randomness": 0.5, "texture": "streak3", "align": true, "dir": -90, "spread": 46,
			"speed": [110, 220], "damping": [60, 110], "gravity": Vector2(0, 427),
			"ramp": gradient([H[1], H[2], H[4], H[5]], [0.0, 0.3, 0.6, 0.85]), "collide": {"bounce": 0.45, "friction": 0.3}})
		emit(pop, t0)
		var flash := glow("PopLight%d" % i, 12, {"radius": 12, "color": H[1], "alpha": 0.0}, {"at": at})
		key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [t0 - 0.01, 0.0], [t0, 0.7], [t0 + 0.08, 0.0]])
		var spot := rect("PopFlash%d" % i, Rect2(at.floor(), Vector2.ONE), Color.WHITE)
		show(spot, t0, t0 + 0.07)

	# embers carried up by the heat, wandering and cooling; a few big ones
	particles("Embers", {"at": Vector2(0, -13), "amount": 32, "lifetime": 2.4, "randomness": 0.4, "texture": "dot1",
		"emit": {"box": Vector2(7, 5)}, "dir": -90, "spread": 28, "speed": [28, 50], "damping": [2, 5],
		"ramp": ember_ramp(), "turbulence": {"strength": 4.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	particles("BigEmbers", {"at": Vector2(0, -13), "amount": 4, "lifetime": 1.8, "randomness": 0.45, "texture": "plus3",
		"emit": {"box": Vector2(7, 5)}, "dir": -90, "spread": 25, "speed": [18, 34], "damping": [2, 5],
		"ramp": gradient([H[2], H[4], H[5], H[6], Color(H[6], 0.0)], [0.0, 0.4, 0.65, 0.85, 0.97]),
		"turbulence": {"strength": 4.0, "scale": 3.0, "influence": [0.02, 0.03]}})

	# light: a big warm room light, lights on the flames, a hot heart, all breathing with the flames
	fire_glow("RoomLight", Vector2(0, -8), 74, GLOW, 0.3, S)
	for L in [[-6, -17, 0.85], [0, -21, 1.0], [6, -17, 0.85]]:
		fire_glow("FlameLight%d" % L[0], Vector2(L[0], L[1]), 46, GLOW, 0.3 * L[2], S)
		fire_glow("HeartLight%d" % L[0], Vector2(L[0] * 0.6, L[1] + 13), 15, H[2], 0.16 * L[2], S)
	fire_glow("Root", Vector2(0, -3), 9, H[0], 0.16, S)


# ------------------------------------------------------------------ the original's own noise (src/core/math.js hash,
# fire/_lib.js noiseFor), so the flame leaps, sways and flickers on the reference's beats

static func _mul32(a: int, b: int) -> int:
	return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


static func _jhash(a: int, b: int) -> int:
	var h := 0x9e3779b9
	for n in [a, b]:
		h = _mul32(h ^ (n & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = _mul32(h, 0xc2b2ae35)
		h ^= h >> 16
	return h


func N(t: float, rate: float, s: int, off := 0.0) -> float:
	var D: float = root.duration
	var P := maxi(1, roundi(rate * D))
	var x := t / D * P + off
	var i := floori(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	var a := _jhash(posmod(i, P), s) / 4294967296.0
	var b := _jhash(posmod(i + 1, P), s) / 4294967296.0
	return (a + (b - a) * u) * 2.0 - 1.0
