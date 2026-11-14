# reimagined-from: src/fx/shadow/grasping-hands.js@e47ad0b135d79fbaa2bef7e4d88799c180b30ff8
# Grasping hands: Shadow arms burst up out of a dark pool with a splash, clench their hands into claws, strain, and are dragged back under, fingers clawing at the air.
# one-shot, 3.10 s, 200x116 canvas, origin [100.0, 100.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The pool is a canvas shader (fx/shadow/_pool.gdshader) with ripples where things break the surface; each arm with
# its hand is the original's spine marched in a shader (_pool_limb.gdshader, mode 1: body, lit rims, a palm, four
# two-bone fingers and a thumb with pale claws) with its rise, lean, elbow and grip keyed from the original's
# formulas, its choices replayed with the original's Rng; a light pass makes the fist glow. The clench: a ring, a
# light, sparks and a puff of dark breath at the fist. Splashes of ink and the pool's breath are particles.
extends "res://build/fx/shadow/_pool.gd"

const RX := 42.0
const OPEN := 0.32
const SHUT := 2.35


static func rx(tt: float) -> float:
	return RX * out_cubic(clampf(tt / OPEN, 0, 1)) * (1 - in_cubic(clampf((tt - SHUT) / 0.45, 0, 1)))


static func grip_of(A: Dictionary, t: float) -> float:
	var shut := out_back(clampf((t - A.t0 - 0.3) / 0.12, 0, 1), 2.2)
	var splay := smooth(A.td, A.td + 0.12, t)
	return shut * (1 - splay) - 0.35 * splay


static func elbow_of(A: Dictionary, t: float) -> float:
	var d := clampf((t - A.td) / 0.34, 0, 1)
	var strain: float = sin(t * 47 + A.ph) * 0.03 if (t > A.t0 + 0.5 and t < A.td) else 0.0
	return A.bend * (0.3 + 0.7 * grip_of(A, t)) * (1 - d) + strain


static func lean_of(A: Dictionary, t: float) -> float:
	return A.lean + 0.06 * sin(t * 2.2 + A.ph) + clampf((t - A.td) / 0.34, 0, 1) * A.lean * 0.6


static func hidden_of(A: Dictionary, t: float) -> float:
	var e := clampf((t - A.t0) / 0.22, 0, 1)
	var d := clampf((t - A.td) / 0.34, 0, 1)
	return (1 - out_back(e, 1.6) * (1 - in_quad(d))) * A.L


## The arm's tip (position, angle) at t: the shader's own march.
static func tip_of(A: Dictionary, t: float) -> Array:
	var th := -PI / 2 + lean_of(A, t)
	var hidden := hidden_of(A, t)
	var q := Vector2(A.x - cos(th) * hidden, A.y - sin(th) * hidden)
	var n := int(ceil(A.L / 0.5))
	var elbow := elbow_of(A, t)
	for i in n:
		var u: float = i * 0.5 / A.L
		th += 0.5 * (elbow * exp(-pow((u - 0.52) / 0.07, 2)) / (0.07 * sqrt(PI) * A.L) + A.curve / A.L)
		q += Vector2(cos(th), sin(th)) * 0.5
	return [q, th]


func make() -> void:
	ground()
	var R := Rng.new(5)
	var DIM := [C[0], C[0], C[1], C[1], C[3], C[4], C[5], C[6]]
	var FULL := [C[0], C[1], C[2], C[3], C[4], C[5], C[6], C[7]]
	var LAY := [[-20, -2.5, 1], [17, -2.5, -1], [-30, 2.5, 1], [28, 2.5, -1]]
	var arms := []
	for i in LAY.size():
		var y: float = LAY[i][1]
		var toward: float = LAY[i][2]
		var A := {"y": y, "back": y < 0, "curl": toward}
		A.x = LAY[i][0] + R.range(-3, 3)
		A.L = R.range(44, 52) if y < 0 else R.range(36, 44)
		A.W = R.range(3.2, 3.8) if y < 0 else R.range(3.6, 4.2)
		A.lean = -toward * R.range(0.16, 0.3)
		A.bend = toward * R.range(0.35, 0.6)
		A.curve = toward * R.range(0.05, 0.15)
		A.t0 = 0.3 + [1, 3, 0, 2][i] * 0.06 + R.range(0, 0.03)
		A.td = 1.45 + [2, 0, 3, 1][i] * 0.09 + R.range(0, 0.05)
		A.ph = R.range(0, TAU)
		arms.append(A)

	var ripples := []
	for A in arms:
		ripples.append([A.x, A.t0, 0.7, 1.0])
		ripples.append([A.x, A.td + 0.28, 0.7, 1.0])
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	var tt := 0.3
	while tt < SHUT - 0.4:
		ripples.append([rr.randf_range(-0.7, 0.7) * rx(tt), tt, 0.6 if rr.randf() < 0.5 else 0.5, 0.5 if rr.randf() < 0.5 else 0.6])
		tt += rr.randf_range(0.1, 0.35)
	pool(RX, rx, ripples, [[-16, 80.0, C[4], 0.2], [-8, -1.0, C[4], 0.3], [0, -2.0, C[5], 0.16]])
	pool_breath(RX, 0.12, SHUT - 0.4, 8, 12, 6, 0)

	var soot := gradient([Color(C[3].lerp(C[2], 0.55), 0.0), Color(C[3].lerp(C[2], 0.55), 0.6), Color(C[2].lerp(C[1], 0.5), 0.0)], [0.0, 0.15, 1.0], true)
	var i := 0
	for A in arms:
		var keyed := {
			"hidden": func(t: float) -> float: return hidden_of(A, t),
			"bend": func(t: float) -> float: return elbow_of(A, t),
			"lean": func(t: float) -> float: return lean_of(A, t),
			"grip": func(t: float) -> float: return grip_of(A, t),
		}
		var fixed := {"x0": A.x, "surf": A.y, "len": A.L, "wid": A.W, "curl": A.curl, "curve": A.curve, "t0": A.t0}
		limb("Arm%d" % i, 1, fixed, keyed, A.t0, A.td + 0.34, DIM if A.back else FULL, A.back)
		splash("Splash%d" % i, Vector2(A.x, A.y), A.t0, 12, 1.0)
		splash("Sink%d" % i, Vector2(A.x, A.y), A.td + 0.28, 8, 0.7)
		# the clench: a snap of light at the fist, a ring, sparks, a puff of dark breath
		var ts: float = A.t0 + 0.36
		var tip: Array = tip_of(A, ts)
		var snap: Vector2 = tip[0] + Vector2.from_angle(tip[1]) * 4
		var rg := ring("Snap%d" % i, 8, {"radius": 2, "thickness": 1, "color": C[6]}, {"at": snap})
		keyf(rg, "material:shader_parameter/radius", func(t: float): return 2 + 5 * out_cubic((t - ts) / 0.22), ts, ts + 0.22, POOL_HZ)
		key(rg, "material:shader_parameter/color", [[ts, C[6]], [ts + 0.22 * 0.4, C[5]], [ts + 0.22 * 0.7, C[3]]], "nearest")
		show(rg, ts, ts + 0.22)
		var sl := glow("SnapLight%d" % i, 23, {"radius": 22, "color": C[5], "alpha": 0.0}, {"at": tip[0]})
		keyf(sl, "material:shader_parameter/radius", func(t: float): return 22 * (0.6 + 0.4 * (1 - seg(t, ts, ts + 0.2))), ts, ts + 0.2, POOL_HZ)
		keyf(sl, "material:shader_parameter/alpha", func(t: float): return 0.7 * pow(1 - seg(t, ts, ts + 0.2), 2) if t >= ts else 0.0, ts - 1 / POOL_HZ, ts + 0.22, POOL_HZ)
		var sp := particles("SnapSparks%d" % i, {"at": snap, "amount": 6, "lifetime": 0.3, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
			"texture": "streak3", "align": true, "spread": 180, "speed": [60, 130], "gravity": Vector2(0, 427), "drag": 2.2,
			"ramp": gradient([C[7], C[7], C[6], C[5]], [0.0, 0.2, 0.4, 0.7]), "emitting": false})
		emit(sp, ts)
		var pf := particles("SnapPuff%d" % i, {"layer": "soft", "at": snap, "amount": 1, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0,
			"texture": "disc7", "dir": -90, "speed": [12, 12], "gravity": Vector2(0, -18), "scale_curve": [[0, 0.65], [0.4, 1.1], [1, 1.5]], "ramp": soot, "emitting": false})
		emit(pf, ts)
		i += 1
