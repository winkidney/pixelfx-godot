# reimagined-from: src/fx/shadow/shadow-tendrils.js@52783a8329acb2f00707bda6c349cf7876ce0266
# Shadow tendrils: A dark pool opens on the floor; tentacles with lit rims and hooked tips lash up out of it with a splash, writhe, and sink back as it closes.
# one-shot, 3.20 s, 208x130 canvas, origin [104.0, 106.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The pool is a canvas shader (fx/shadow/_pool.gdshader, the lib's floorPool with ripples where things break the
# surface); each tentacle is the original's spine marched in a shader (_pool_limb.gdshader, mode 0: body, lit rims,
# suckers, the pulse of light, the hooked tip, the collar of ink) with its rise, lean, whip, writhe and hook keyed
# from the original's formulas, its own choices replayed with the original's Rng; a light pass rides it. Splashes of
# ink drops and a light where each breaks the surface and sinks, sparks as it lashes, glints on the rims, and the
# pool's breath (wisps, vapour, motes, embers) are particles.
extends "res://build/fx/shadow/_pool.gd"

const RX := 40.0
const OPEN := 0.34
const SHUT := 2.5
const SINK := 0.5


static func rx(tt: float) -> float:
	return RX * out_cubic(clampf(tt / OPEN, 0, 1)) * (1 - in_cubic(clampf((tt - SHUT) / 0.45, 0, 1)))


func make() -> void:
	ground()
	var R := Rng.new(3)
	var DIM := [C[0], C[0], C[1], C[1], C[3], C[4], C[5], C[6]]
	var FULL := [C[0], C[1], C[2], C[3], C[4], C[5], C[6], C[7]]
	var rows := [[-22, -2.5], [-8, -3], [7, -3], [21, -2.5], [-28, 2.5], [-1, 3], [27, 2.5]]
	var order := [3, 0, 5, 2, 4, 1, 6]
	var last := [1, 5, 0, 6, 3, 2, 4]
	var tents := []
	for i in rows.size():
		var x: float = rows[i][0]
		var y: float = rows[i][1]
		var back := y < 0
		var sx := signf(x) if x != 0 else 1.0
		var T := {"y": y, "back": back}
		T.x = x + R.range(-3, 3)
		T.L = R.range(46, 62) if back else R.range(32, 46)
		T.W = R.range(3.2, 4) if back else R.range(3.8, 4.6)
		T.lean = sx * (0.06 + absf(x) / 120) + R.range(-0.06, 0.06)
		T.curl = -sx if R.chance(0.75) else sx
		T.lam = R.range(36, 50)
		T.om = R.range(4.5, 7)
		T.om *= R.sign()
		T.ph = R.range(0, TAU)
		T.A = R.range(0.06, 0.085)
		T.H = R.range(0.15, 0.32)
		T.t0 = 0.3 + order[i] * 0.045 + R.range(0, 0.03)
		T.t1 = 1.5 + last[i] * 0.1 + R.range(0, 0.05)
		T.whip = null
		if R.chance(0.45):
			var wt := R.range(0.9, 1.5)
			var wa := R.range(0.28, 0.45)
			T.whip = [wt, wa * R.sign()]
		tents.append(T)

	# ripples: where each tentacle breaks the surface and where it goes under, and the pool's own
	var ripples := []
	for T in tents:
		ripples.append([T.x, T.t0, 0.7, 1.0])
		ripples.append([T.x, T.t1 + SINK * 0.8, 0.7, 1.0])
	var rr := RandomNumberGenerator.new()
	rr.seed = 3
	var tt := 0.3
	while tt < SHUT - 0.4:
		ripples.append([rr.randf_range(-0.7, 0.7) * rx(tt), tt, 0.6 if rr.randf() < 0.5 else 0.5, 0.5 if rr.randf() < 0.5 else 0.6])
		tt += rr.randf_range(0.08, 0.3)
	var pl := pool(RX, rx, ripples, [[-16, 86.0, C[4], 0.22], [-8, -1.0, C[4], 0.32], [0, -2.0, C[5], 0.18]])
	pool_breath(RX, 0.12, SHUT - 0.4, 9, 16, 7, 5)

	var i := 0
	for T in tents:
		var t0: float = T.t0
		var t1: float = T.t1
		var L: float = T.L
		var s1 := func(t: float) -> float: return clampf((t - t1) / SINK, 0, 1)
		var keyed := {
			"hidden": func(t: float) -> float:
				var e := clampf((t - t0) / 0.2, 0, 1)
				var q: float = s1.call(t)
				var lift := 0.07 * sin(PI * clampf(q / 0.3, 0, 1))
				var down := in_out_cubic(clampf((q - 0.12) / 0.88, 0, 1))
				return (1 - out_back(e, 1.8) * (1 + lift) * (1 - down)) * L,
			"bend": func(t: float) -> float: return T.A * (0.25 + 0.75 * smooth(t0 + 0.08, t0 + 0.5, t)),
			"hook": func(t: float) -> float: return (0.04 + T.H * out_back(clampf((t - t0 - 0.1) / 0.32, 0, 1), 2.5)) * (1 + 0.5 * s1.call(t)) * (1 + 0.18 * sin(t * 2.3 + T.ph)),
			"lean": func(t: float) -> float:
				var l: float = T.lean + 0.12 * sin(t * 1.6 + T.ph)
				if T.whip != null:
					l += T.whip[1] * exp(-pow((t - T.whip[0]) / 0.14, 2))
				return l,
		}
		var fixed := {"x0": T.x, "surf": T.y, "len": L, "wid": T.W, "lam": T.lam, "om": T.om, "ph": T.ph, "curl": T.curl, "t0": t0}
		limb("Tentacle%d" % i, 0, fixed, keyed, t0, t1 + SINK, DIM if T.back else FULL, T.back)
		splash("Splash%d" % i, Vector2(T.x, T.y), t0, 12, 1.0)
		splash("Sink%d" % i, Vector2(T.x, T.y), t1 + SINK * 0.8, 6, 0.6)
		var sp := particles("Lash%d" % i, {"at": Vector2(T.x, T.y - 2), "amount": 4, "lifetime": 0.45, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
			"texture": "streak4", "align": true, "dir": -90, "spread": 22, "speed": [120, 260], "gravity": Vector2(0, 427), "drag": 2.2,
			"ramp": gradient([C[7], C[7], C[6], C[5]], [0.0, 0.2, 0.4, 0.7]), "emitting": false})
		emit(sp, t0)
		# glints on the rims while it stands
		var gl := particles("Glints%d" % i, {"at": Vector2(T.x + T.lean * L * 0.6, T.y - L * 0.55), "amount": 2, "lifetime": 0.4, "life_random": 0.4, "texture": "plus3",
			"emit": {"box": Vector2(6, L * 0.3)}, "dir": -90, "speed": [4, 4], "color": C[6], "scale_curve": [[0, 0.4], [0.5, 1], [1, 0.4]], "emitting": false})
		emit(gl, t0 + 0.25, t1)
		i += 1
