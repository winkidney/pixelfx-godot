# reimagined-from: src/fx/ice/icicle-fall.js@108d204e2082c457a439f08e00fc53cf01e7b5df
# Icicle fall: an icicle drips and trembles, snaps off its frosted root, drops, stabs the floor and bursts into
# skidding shards, splinters and rolling frost.
# The rime it hangs from and the stub it leaves are pixels drawn here (the original's rule, column by column); the
# icicle is a shader (its rippled taper, lit core, rings and glint) keyed through its tremble and its fall (the
# original's gravity), with streaks of air behind it and its shadow gathering on the floor. On impact: a flash of
# light and a sparkle, a ring rolling out along the floor (the band shader), frost splashed across it (the frost
# shader), its pieces (icicle shard textures) and splinters bursting out and bouncing on a collision floor, vapour,
# snow and glints.
extends "res://build/fx/ice/_ice.gd"

const ROOT := -80.0
const LEN := 36.0
const W := 12.0
const DRIP := 0.16
const TREMBLE := 0.3
const SNAP := 0.6
const FREE := SNAP + 0.04
const GRAV := 950.0

var IMPACT := 0.0


func top(t: float) -> float:
	return ROOT + (0.0 if t < FREE else 0.5 * GRAV * pow(t - FREE, 2.0))


func make() -> void:
	var D: float = root.duration
	IMPACT = FREE + sqrt(2.0 * (-ROOT - LEN) / GRAV)
	ground()
	var fade := sample(func(t): return Color(1, 1, 1, 1.0 - smooth(D - 0.7, D - 0.2, t)))

	# its shadow gathers on the floor as it comes down
	var shadow := ring("Shadow", 12, {"radius": 3.0, "squash": 0.1, "color": C[0], "alpha": 0.0, "translucent": true}, {"at": Vector2(0, 1), "back": true})
	var sr := []
	var sa := []
	for f in int(roundf(D * FPS)) + 1:
		var t := f / FPS
		var k := 0.0
		if t > TREMBLE and t < IMPACT + 0.05:
			k = seg(t, TREMBLE, FREE) * 0.35 if t < FREE else 0.35 + 0.65 * seg(t, FREE, IMPACT)
		sr.append([t, 3.0 + 7.0 * k])
		sa.append([t, 0.7 * k])
	key(shadow, "material:shader_parameter/radius", sr, "nearest")
	key(shadow, "material:shader_parameter/alpha", sa, "nearest")

	# frost splashed across the floor where it struck, and the ring rolling out (its far half behind)
	var splash := shape("Splash", load(ICE + "_frost.gdshader"), Vector2(64, 24), {"kind": 2, "x1": 26.0, "a": 0.0, "spread_k": 0.0,
		"ramp": ramp("palette", {"stops": 8})}, {"at": Vector2(0, 0), "back": true})
	key(splash, "material:shader_parameter/spread_k", sample(func(t): return out_cubic(seg(t, IMPACT, IMPACT + 0.25))), "nearest")
	key(splash, "material:shader_parameter/a", sample(func(t): return (1.0 - smooth(IMPACT + 0.8, IMPACT + 1.5, t)) if t >= IMPACT else 0.0), "nearest")
	var band_ramp := gradient([C[3], C[4], C[5], C[6]])
	for side in [1, -1]:
		var band := shape("Band%s" % ("Back" if side > 0 else "Front"), load(ICE + "_band.gdshader"), Vector2(96, 20), {"radius": 6.0, "squash": 0.18,
			"width": 4.0, "side": float(side), "alpha": 0.0, "steps": 4.0, "ramp": band_ramp}, {"at": Vector2(0, 0), "back": side > 0})
		var kr := []
		var kw := []
		var ka := []
		var kh := []
		for f in int(roundf(D * FPS)) + 1:
			var t := f / FPS
			var k := seg(t, IMPACT, IMPACT + 0.35)
			var on := t >= IMPACT and k < 1.0
			kr.append([t, 6.0 + 34.0 * out_cubic(k)])
			kw.append([t, maxf(1.0, 4.0 * (1.0 - k))])
			ka.append([t, (1.1 - k) if on else 0.0])
			kh.append([t, 1.0 if (side < 0 and k < 0.15) else 0.0])
		key(band, "material:shader_parameter/radius", kr, "nearest")
		key(band, "material:shader_parameter/width", kw, "nearest")
		key(band, "material:shader_parameter/alpha", ka, "nearest")
		key(band, "material:shader_parameter/hot", kh, "nearest")

	# the rime it hangs from: a lumpy crust, white on top, little icicles hanging off it; it fades at the end
	var rime := {}
	for x in range(-18, 19):
		var h := jrand([x, 4, 2])
		var d := absf(x) / 18.0
		var rh := 1 + int(roundf((0.6 + h * 1.8) * (1.0 - d * 0.7)))
		var stub := 2 + int(roundf(jrand([x, 5]) * 5.0 * (1.0 - d * 0.5))) if (h < 0.3 and absi(x) > 7) else 0
		for j in rh + 1:
			rime[Vector2i(x, int(ROOT) - 1 - j)] = Color.WHITE if j == rh else (C[6] if j == rh - 1 else (C[3] if j == 0 else C[5]))
		for j in stub:
			rime[Vector2i(x, int(ROOT) + j)] = Color.WHITE if j == stub - 1 else (C[5] if j == 0 else C[4])
		if stub > 4:
			rime[Vector2i(x + 1, int(ROOT))] = C[3]
	var crust := bitmap("Rime", rime)
	key(crust, "modulate", fade)
	var root_glow := glow("RootGlow", 20, {"radius": 18, "color": C[4], "alpha": 0.3}, {"at": Vector2(0, ROOT)})
	key(root_glow, "material:shader_parameter/alpha", sample(func(t): return 0.3 * (1.0 - smooth(D - 0.7, D - 0.2, t))))
	# the snapped root: a jagged stub left behind, its broken ends white for a moment
	for hot in [true, false]:
		var stub := {}
		for x in range(-int(W / 2) + 1, int(W / 2)):
			var L := 1 + int(roundf(jrand([x, 77]) * 2.5))
			for j in L:
				stub[Vector2i(x, int(ROOT) + j)] = (Color.WHITE if hot else C[6]) if j == L - 1 else (C[5] if x < 0 else C[3])
		var node := bitmap("Stub%s" % ("Hot" if hot else ""), stub)
		if hot:
			show(node, SNAP, SNAP + 0.15)
		else:
			show(node, SNAP + 0.15)
			key(node, "modulate", fade)
	var crack := line("Crack", PackedVector2Array([Vector2(-W / 2 - 1, ROOT + 1.5), Vector2(W / 2 + 2, ROOT + 1.5)]), {"color": Color.WHITE})
	show(crack, SNAP, SNAP + 0.12)

	icicle()
	snap_and_fall()
	impact()


## The icicle: trembling before it snaps, then falling with a streak of air behind it; a drop swells at its tip.
func icicle() -> void:
	var tip := shape("Icicle", load(ICE + "_icicle.gdshader"), Vector2(32, 2 * (LEN + 4)), {"span": LEN, "width": W, "ramp": ramp("palette", {"stops": 8})},
		{"at": Vector2(0, ROOT)})
	var halo := glow("IcicleGlow", 22, {"radius": 20, "color": C[4], "alpha": 0.28}, {"at": Vector2(0, ROOT + LEN * 0.5)})
	var kp := []
	var kx := []
	var kw := []
	var kg := []
	var kv := []
	var hp := []
	var streaks := []
	for i in 3:
		var dx: float = [-3.0, 0.5, 4.0][i]
		streaks.append(line("Air%d" % i, PackedVector2Array([Vector2(dx, 0), Vector2(dx, 1)]), {"gradient": gradient([C[3], C[4], C[6]], [0.0, 0.4, 0.75])}))
	var sk := [[], [], []]
	for f in int(roundf(IMPACT * FPS)) + 2:
		var t := f / FPS
		var tp := top(t)
		var jx := 0.0
		if t > TREMBLE and t < SNAP:
			jx = (1.0 if int(floor(t * 36.0)) % 2 else 0.0) * roundf(seg(t, TREMBLE, SNAP) * 1.4 + 0.4)
		kp.append([t, Vector2(0, roundf(tp))])
		kx.append([t, 0.5 + jx])
		kw.append([t, 1.0 if (t >= IMPACT - 0.025 or (t >= SNAP and t < SNAP + 0.03)) else 0.0])
		var gl := (t - 0.04) / 0.3
		kg.append([t, gl if (gl >= 0.0 and gl <= 1.0) else -1.0])
		kv.append([t, t < IMPACT])
		hp.append([t, Vector2(0, roundf(tp + LEN * 0.5))])
		var sp := GRAV * (t - FREE) if t >= FREE else 0.0
		for i in 3:
			var dx: float = [-3.0, 0.5, 4.0][i]
			var k: float = [0.7, 1.0, 0.6][i]
			var L := minf(30.0, sp * 0.07) * k
			if L > 2.0 and t < IMPACT:
				sk[i].append([t, PackedVector2Array([Vector2(floorf(dx) + 0.5, tp - L), Vector2(floorf(dx) + 0.5, tp + 3.0)])])
			else:
				sk[i].append([t, PackedVector2Array()])
	key(tip, "position", kp, "nearest")
	key(tip, "material:shader_parameter/x0", kx, "nearest")
	key(tip, "material:shader_parameter/white", kw, "nearest")
	key(tip, "material:shader_parameter/glint", kg, "nearest")
	key(tip, "visible", kv, "nearest")
	key(halo, "position", hp, "nearest")
	key(halo, "visible", kv, "nearest")
	for i in 3:
		key(streaks[i], "points", sk[i], "nearest")
	# the drop of meltwater swelling at the tip, then falling
	var drop := sprite("Drop", "dot1", {"at": Vector2(0.5, ROOT + LEN + 1.5), "modulate": Color(C[6], 0.0)})
	key(drop, "modulate", sample(func(t): return Color(C[6], seg(t, 0.0, DRIP)), 0.0, DRIP), "nearest")
	show(drop, 0.0, DRIP)
	var drop_hi := sprite("DropHi", "dot1", {"at": Vector2(0.5, ROOT + LEN + 2.5), "modulate": Color.WHITE})
	show(drop_hi, DRIP * 0.6, DRIP)
	var fall := particles("Drip", {"at": Vector2(0.5, ROOT + LEN + 1.5), "amount": 1, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "dot2", "dir": 90, "speed": [20, 20], "gravity": Vector2(0, 855), "color": C[6], "collide": {"hide": true, "size": 0.5}})
	emit(fall, DRIP)


## It snaps: light, chips and a puff burst off the root, frost sifts down while it trembles, motes hang behind it.
func snap_and_fall() -> void:
	var sift := particles("Sift", {"at": Vector2(0, ROOT + 1.5), "amount": 2, "lifetime": 0.85, "emitting": false, "texture": "dot1",
		"emit": {"box": Vector2(6, 1.5)}, "dir": 90, "spread": 30, "speed": [5, 20], "damping": [10, 20], "gravity": Vector2(0, 35),
		"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	emit(sift, TREMBLE, SNAP)
	light_flash("SnapWhite", Vector2(0, ROOT + 4), 24, Color.WHITE, 0.6, SNAP, 0.1)
	light_flash("SnapCold", Vector2(0, ROOT + 4), 32, C[5], 0.4, SNAP, 0.3)
	var chips := particles("Chips", {"at": Vector2(0, ROOT + 2), "amount": 7, "lifetime": 0.9, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 180, "speed": [30, 110], "damping": [40, 70],
		"gravity": Vector2(0, 760), "angle": [0, 360], "spin": [-1100, 1100], "initial": gradient([C[5], C[6], C[7]]),
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	chips.process_material.lifetime_randomness = 0.4
	var puff := particles("SnapPuff", {"layer": "soft", "at": Vector2(0, ROOT + 2), "amount": 3, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(5, 0.5)}, "dir": 0, "spread": 180, "speed": [5, 25], "damping": [20, 40],
		"scale_curve": [[0, 0.3], [1, 0.55]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	var snow := particles("SnapSnow", {"at": Vector2(0, ROOT + 2), "amount": 5, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(6, 0.5)}, "dir": 90, "spread": 180, "speed": [10, 36], "damping": [30, 50], "gravity": Vector2(0, 35),
		"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	emit_all([chips, puff, snow], SNAP)
	# falling: it sheds frost motes that hang in the air behind it
	var rider := group("Falling", {"at": Vector2(0, ROOT)})
	key(rider, "position", sample(func(t): return Vector2(0, top(t) + LEN * 0.3), 0.0, IMPACT + 0.05))
	var motes := particles("Motes", {"parent": rider, "amount": 3, "lifetime": 0.28, "texture": tex("fade4"), "align": true, "emitting": false,
		"emit": {"box": Vector2(3, LEN * 0.3)}, "dir": -90, "spread": 15, "speed": [10, 40], "initial": gradient([C[6], C[5]]),
		"alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	emit(motes, FREE, IMPACT)


## It stabs the floor and bursts.
func impact() -> void:
	light_flash("ImpactWhite", Vector2(0, -16), 46, Color.WHITE, 0.85, IMPACT, 0.12)
	light_flash("ImpactCold", Vector2(0, -16), 58, C[4], 0.5, IMPACT, 0.5)
	var sp := sparkle("ImpactSparkle", {"reach": 30})
	var keys := []
	for f in int(roundf(root.duration * FPS)) + 1:
		var t := f / FPS
		var arm := 10.0 * out_back(minf(1.0, (t - IMPACT) / 0.05)) * (1.0 - (t - IMPACT) / 0.22) if (t >= IMPACT and t < IMPACT + 0.22) else 0.0
		keys.append([t, Vector2(0.5, -3), arm, 0.7])
	sparkle_keys(sp, keys)
	# the icicle in pieces, flung both ways, bouncing and skidding
	for s in [-1, 1]:
		var tag := "L" if s < 0 else "R"
		for k in [["icicle_a", Vector2(0, -31), 1], ["icicle_b", Vector2(0, -20), 1], ["icicle_c", Vector2(0, -10), 1]]:
			var p := particles("Piece%s_%s" % [tag, k[0]], {"at": k[1], "amount": k[2], "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0,
				"emitting": false, "texture": tex(k[0]), "emit": {"box": Vector2(2, 3)}, "dir": -90 + s * 45, "spread": 22,
				"speed": [80, 200 if k[1].y < -20 else 140], "damping": [40, 70], "gravity": Vector2(0, 855), "angle": [-25, 25], "spin": [-690, 690],
				"alpha_curve": [[0, 1], [0.75, 1], [1, 0]], "collide": {"bounce": 0.35, "friction": 0.95, "size": 0.6}})
			p.process_material.lifetime_randomness = 0.25
			emit(p, IMPACT)
	var tipp := particles("Piece_icicle_tip", {"at": Vector2(0, -3), "amount": 1, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("icicle_tip"), "dir": -90, "spread": 40, "speed": [60, 120], "damping": [40, 70], "gravity": Vector2(0, 855),
		"angle": [-25, 25], "spin": [-690, 690], "alpha_curve": [[0, 1], [0.75, 1], [1, 0]], "collide": {"bounce": 0.35, "friction": 0.95, "size": 0.6}})
	emit(tipp, IMPACT)
	var bits := particles("Splinters", {"at": Vector2(0, -5), "amount": 44, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"box": Vector2(3, 4.5)}, "dir": -90, "spread": 72, "speed": [60, 230], "damping": [50, 90], "gravity": Vector2(0, 810),
		"angle": [0, 360], "spin": [-1260, 1260], "initial": gradient([C[4], C[5], C[6], C[7]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"collide": {"bounce": 0.32, "friction": 0.8, "size": 1}})
	bits.process_material.lifetime_randomness = 0.5
	var lumps := particles("Lumps", {"at": Vector2(0, -5), "amount": 8, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": tex("chunk3"), "emit": {"box": Vector2(3, 4.5)}, "dir": -90, "spread": 72, "speed": [60, 200], "damping": [50, 90],
		"gravity": Vector2(0, 810), "angle": [0, 360], "spin": [-1260, 1260], "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"collide": {"bounce": 0.32, "friction": 0.8, "size": 0.5}})
	lumps.process_material.lifetime_randomness = 0.5
	emit_all([bits, lumps], IMPACT)
	for s in [-1, 1]:
		var vap := particles("Vapour%s" % ("L" if s < 0 else "R"), {"layer": "soft", "at": Vector2(s * 4, -3.5), "amount": 5, "lifetime": 1.1,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(4, 2.5)}, "dir": 90 - s * 97,
			"spread": 8, "speed": [25, 90], "damping": [60, 90], "scale_curve": [[0, 0.4], [1, 0.95]],
			"ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.25), Color(C[6], 0.08), Color(C[6], 0.0)], [0.0, 0.4, 0.8, 1.0], true)})
		vap.process_material.lifetime_randomness = 0.4
		var haze := lit_copy(vap, "Haze%s" % ("L" if s < 0 else "R"), "glow16", Color(C[5], 0.16), [[0, 1], [1, 0]])
		emit_all([vap, haze], IMPACT)
	var snow := particles("ImpactSnow", {"at": Vector2(0, -9), "amount": 12, "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(6, 7)}, "dir": -90, "spread": 45, "speed": [40, 120], "damping": [80, 120], "gravity": Vector2(0, 35),
		"initial": gradient([Color.WHITE, Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	snow.process_material.lifetime_randomness = 0.33
	var stars := particles("ImpactStars", {"at": Vector2(0, -19), "amount": 6, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "emit": {"box": Vector2(24, 15)}, "dir": -90, "spread": 40, "speed": [4, 14], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.3, 0.5], [0.6, 1], [1, 0]]})
	stars.process_material.lifetime_randomness = 0.5
	emit_all([snow, stars], IMPACT)
	var settle := particles("DebrisGlints", {"at": Vector2(0, -3), "amount": 1, "lifetime": 0.3, "emitting": false, "texture": "plus3",
		"emit": {"box": Vector2(40, 2)}, "dir": -90, "speed": [3, 3], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.4, 0.4], [0.7, 1], [1, 0]]})
	emit(settle, IMPACT + 0.1, IMPACT + 0.9)
	var crumble := particles("Crumble", {"layer": "soft", "at": Vector2(0, -1.5), "amount": 4, "lifetime": 0.55, "emitting": false,
		"texture": tex("puff16"), "emit": {"box": Vector2(45, 1)}, "dir": -90, "spread": 50, "speed": [4, 12],
		"scale_curve": [[0, 0.3], [1, 0.5]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	emit(crumble, IMPACT + 0.3, IMPACT + 1.1)
