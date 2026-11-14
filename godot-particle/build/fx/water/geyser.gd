# reimagined-from: src/fx/water/geyser.js@2840d89db09c6745a055d6dcc9238617dcc27953
# Geyser: A pool heaves and burbles faster and faster, then blasts a white column of water skyward with a churning foam head; it rains back down in drops and steam, slumps and sputters out.
# one-shot, 5.00 s, 184x168 canvas, origin [92.0, 146.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The geyser is a canvas shader (fx/water/_geyser.gdshader) on the original's own clock and noise, keyed only by the
# time: the pool growing round it (soft), the heaving mound beating faster, the spurts, the blast's white burst and
# ring, the column with its strands running up in jet time, the billows boiling at its foot, the churning head with
# its umbrella of streaks, the lace on the pool, and their light. The water it throws is emitters landing on the pool
# (a collision floor) where they plink and ring: the blast, the rain shed off the head and its collapse, the spurts'
# drops and the burbles' pops; steam (soft light), flakes and sparkles; rings spread over the pool while it holds.
extends "res://build/fx/water/_water.gd"

const SY := 0.22
const G := 820.0
const ERUPT := 1.15
const FALL := 2.6
const GONE := 3.3
const SPURTS := [[0.46, 7.0], [0.72, 12.0], [0.92, 9.0], [1.04, 15.0], [GONE + 0.15, 15.0], [GONE + 0.55, 8.0]]

var HMAX := 100.0
var S := 4


## The original's noise(x, seed), exactly (for the column's height).
static func jsnoise(x: float, s: int) -> float:
	var i := floorf(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(jsrand([int(i), s]), jsrand([int(i) + 1, s]), u) * 2.0 - 1.0


func top(t: float) -> float:
	if t < ERUPT or t > GONE:
		return 0.0
	return HMAX * out_cubic((t - ERUPT) / 0.3) * (0.93 + 0.07 * jsnoise(t * 2.2, S)) * (1.0 - in_quad(clampf((t - FALL) / (GONE - FALL), 0.0, 1.0)))


func head(t: float) -> float:
	return smooth(ERUPT + 0.08, ERUPT + 0.3, t) * (1.0 - smooth(FALL + 0.1, FALL + 0.45, t))


func pool_r(t: float) -> float:
	return (12.0 + 7.0 * smooth(0.0, 1.0, t) + 15.0 * out_cubic((t - ERUPT) / 1.2)) * (1.0 - 0.25 * smooth(GONE, 4.6, t))


func make() -> void:
	HMAX = meta.options.height
	S = meta.options.seed
	var D: float = meta.duration
	ground(1.5)
	var base := {"pal": C, "hmax": HMAX, "seed": float(S), "sy": SY}
	var big := Vector2(120, HMAX + 40.0)
	var at := Vector2(0, -HMAX / 2.0 - 10.0)
	var nodes := []
	for m in [["Pool", 0.0, true, true], ["PoolRim", 3.0, true, true], ["Behind", 1.0, true, false], ["Geyser", 2.0, false, false]]:
		var pr := base.duplicate()
		pr.mode = m[1]
		if m[3]:
			pr.translucent = true
		nodes.append(shape(m[0], water_shader("geyser"), Vector2(84, 24) if m[3] else big, pr, {"at": Vector2.ZERO if m[3] else at, "back": m[2]}))
	nodes.append(shape("Light", water_shader("geyser_light"), Vector2(184, 168), base, {"at": Vector2(0, -146 + 84)}))
	for n in nodes:
		key(n, "material:shader_parameter/now", [[0.0, 0.0], [D, D]])

	# while it builds: bubbles burst on the heaving mound, faster and faster, throwing up drops; steam lifts
	var build := func(t: float) -> float: return clampf((1.5 + 9.0 * pow(t / ERUPT, 2.0)) / 10.5, 0.0, 1.0) if t < ERUPT else 0.0
	var pops := particles("Pops", {"at": Vector2(0, -2), "amount": 2, "lifetime": 0.12, "texture": "plus3",
		"emit": {"box": Vector2(6, 1.5)}, "color": C[6], "scale_curve": [[0, 0.6], [1, 1.4]], "alpha_curve": [[0, 1], [1, 0.2]]})
	var pop_rings := particles("PopRings", {"at": Vector2(0, 0), "amount": 6, "lifetime": 0.55, "texture": "ripple7x3",
		"emit": {"box": Vector2(6, 1)}, "scale_curve": [[0, 0.5], [1, 1.2]],
		"ramp": ramp("palette", {"from": 0.57, "to": 0.86, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
	var pop_drops := particles("PopDrops", {"at": Vector2(0, -2), "amount": 4, "lifetime": 0.4, "texture": "dot1",
		"emit": {"box": Vector2(6, 1)}, "dir": -90, "spread": 20, "speed": [50, 120], "gravity": Vector2(0, G),
		"initial": gradient([C[6], C[5]]), "collide": {"hide": true, "size": 1}})
	for p in [pops, pop_rings, pop_drops]:
		sample(p, "amount_ratio", build, 0.0, ERUPT + 0.1)
		emit(p, 0.0, ERUPT)
	var steam := gradient([Color(C[6], 0.0), Color(C[6], 0.22), Color(C[6], 0.12), Color(C[6], 0.0)], [0.0, 0.12, 0.5, 1.0], true)
	var lift := particles("Steam", {"layer": "light", "at": Vector2(0, -3), "amount": 9, "lifetime": 1.2, "randomness": 0.3,
		"texture": "glow32", "emit": {"box": Vector2(8, 2)}, "dir": -90, "spread": 30, "speed": [8, 18], "damping": [4, 8],
		"scale": [0.2, 0.3], "scale_curve": [[0, 0.5], [1, 1.5]], "ramp": steam})
	sample(lift, "amount_ratio", func(t: float) -> float: return clampf((3.0 + 7.0 * t / ERUPT) / 10.0, 0.0, 1.0), 0.0, ERUPT + 0.1)
	emit(lift, 0.0, ERUPT)

	# the spurts' drops
	for i in SPURTS.size():
		var s: Array = SPURTS[i]
		var sp := particles("SpurtDrops%d" % i, {"at": Vector2(0, -s[1] * 0.8), "amount": 3 + int(roundf(s[1] / 4.0)),
			"lifetime": 0.6, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "dot1", "dir": -90,
			"spread": 50, "speed": [25, 90], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[7]]),
			"collide": {"hide": true, "size": 1}})
		emit(sp, s[0] + 0.08)

	# the blast: water flung high, steam rolling out, sparkles up the column
	var blast := {"at": Vector2(0, -6), "amount": 30, "lifetime": 1.2, "one_shot": true, "explosiveness": 0.85,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(3, 4)}, "dir": -90, "spread": 22,
		"speed": [180, 400], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[7], C[5]]),
		"collide": {"hide": true, "size": 1}}
	emit(particles("Blast", blast), ERUPT)
	var beads := blast.duplicate()
	beads.merge({"amount": 14, "texture": "dot2", "initial": gradient([C[6], C[5]])}, true)
	var bb := particles("BlastBeads", beads)
	emit(bb, ERUPT)
	var bt := twin("BlastTails", bb, beads, {"texture": "streak4", "align": true, "initial": null, "color": C[3]})
	emit(bt, ERUPT)
	for side in [[-1.0, "BlastSteamL"], [1.0, "BlastSteamR"]]:
		var e := particles(side[1], {"layer": "light", "at": Vector2(side[0] * 6.0, -4), "amount": 6, "lifetime": 1.6,
			"randomness": 0.3, "one_shot": true, "explosiveness": 0.9, "emitting": false, "texture": "glow32",
			"emit": {"box": Vector2(3, 2)}, "dir": 90.0 - side[0] * 98.0, "spread": 14, "speed": [30, 80], "damping": [40, 60],
			"gravity": Vector2(0, -7), "scale": [0.35, 0.5], "scale_curve": [[0, 0.5], [1, 1.4]], "ramp": steam})
		emit(e, ERUPT)
	var stars := particles("Sparkles", {"at": Vector2(0, -44), "amount": 14, "lifetime": 0.5, "randomness": 0.4,
		"one_shot": true, "explosiveness": 0.4, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(16, 36)},
		"dir": -90, "speed": [4, 8], "initial": gradient([C[7], C[6]])})
	emit(stars, ERUPT + 0.05)

	# holding: the head sheds drops that rain back down, spray and flakes hang off the column, steam pours off the top
	var hold := func(t: float) -> float: return head(t)
	var top_at := func(t: float) -> Vector2: return Vector2(0, -maxf(top(t), 8.0))
	var rain := {"at": Vector2(0, -HMAX), "amount": 30, "lifetime": 0.9, "texture": "dot1", "emit": {"box": Vector2(9, 4)},
		"dir": -90, "spread": 95, "speed": [15, 70], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[6], C[7]]),
		"collide": {"hide": true, "size": 1}, "emitting": false}
	var shed := particles("HeadRain", rain)
	var heavy := rain.duplicate()
	heavy.merge({"amount": 10, "texture": "dot2", "initial": gradient([C[6], C[5]])}, true)
	var shed2 := particles("HeadBeads", heavy)
	for p in [shed, shed2]:
		sample(p, "position", top_at, ERUPT, FALL + 0.5)
		sample(p, "amount_ratio", hold, ERUPT, FALL + 0.5)
		emit(p, ERUPT + 0.08, FALL + 0.45)
	var crash := rain.duplicate()
	crash.merge({"amount": 40, "one_shot": true, "explosiveness": 0.7, "at": Vector2(0, -top(FALL + 0.12))}, true)
	emit(particles("Collapse", crash), FALL + 0.12)
	var flakes := particles("Flakes", {"at": Vector2(0, -HMAX * 0.5), "amount": 36, "lifetime": 0.9, "randomness": 0.3,
		"texture": "dot1", "emit": {"box": Vector2(7, HMAX * 0.45)}, "dir": 0, "spread": 180, "speed": [10, 45],
		"gravity": Vector2(0, 30), "initial": gradient([C[7], C[6]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "emitting": false})
	sample(flakes, "amount_ratio", hold, ERUPT, FALL + 0.5)
	emit(flakes, ERUPT + 0.08, FALL + 0.45)
	var glints := particles("Glints", {"at": Vector2(0, -HMAX * 0.5), "amount": 4, "lifetime": 0.4, "texture": "plus3",
		"emit": {"box": Vector2(14, HMAX * 0.5)}, "dir": -90, "speed": [3, 5], "initial": gradient([C[7], C[6], C[6]]), "emitting": false})
	sample(glints, "amount_ratio", hold, ERUPT, FALL + 0.5)
	emit(glints, ERUPT + 0.08, FALL + 0.45)
	var top_steam := particles("HeadSteam", {"layer": "light", "at": Vector2(0, -HMAX), "amount": 11, "lifetime": 1.15,
		"texture": "glow32", "emit": {"box": Vector2(8, 4)}, "dir": -90, "spread": 50, "speed": [15, 40], "damping": [30, 40],
		"gravity": Vector2(0, -7), "scale": [0.3, 0.45], "scale_curve": [[0, 0.6], [1, 1.4]], "ramp": steam, "emitting": false})
	sample(top_steam, "position", top_at, ERUPT, FALL + 0.5)
	sample(top_steam, "amount_ratio", hold, ERUPT, FALL + 0.5)
	emit(top_steam, ERUPT + 0.08, FALL + 0.45)
	var foot_steam := particles("FootSteam", {"layer": "light", "at": Vector2(0, -4), "amount": 7, "lifetime": 1.3,
		"texture": "glow32", "emit": {"box": Vector2(8, 2)}, "dir": 0, "spread": 180, "speed": [20, 50], "damping": [30, 40],
		"gravity": Vector2(0, -5), "scale": [0.3, 0.4], "scale_curve": [[0, 0.6], [1, 1.4]], "ramp": steam, "emitting": false})
	sample(foot_steam, "amount_ratio", hold, ERUPT, FALL + 0.5)
	emit(foot_steam, ERUPT + 0.08, FALL + 0.45)
	var fall_steam := particles("CollapseSteam", {"layer": "light", "at": Vector2(0, -top(FALL + 0.12)), "amount": 6,
		"lifetime": 1.0, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "glow32", "emit": {"box": Vector2(8, 6)},
		"dir": -90, "spread": 60, "speed": [10, 34], "damping": [30, 40], "scale": [0.35, 0.45], "ramp": steam})
	emit(fall_steam, FALL + 0.12)

	# where the water comes down: plinks and little rings over the pool and round it
	var land := particles("Plinks", {"at": Vector2(0, 1), "amount": 9, "lifetime": 0.4, "texture": "ripple5x1",
		"emit": {"box": Vector2(40, 5)}, "scale_curve": [[0, 0.6], [1, 1.5]], "emitting": false,
		"ramp": ramp("palette", {"from": 0.57, "to": 0.86, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
	emit(land, ERUPT + 0.3, GONE + 0.9)
	var fl := particles("PlinkFlecks", {"at": Vector2(0, 0), "amount": 3, "lifetime": 0.07, "texture": "dot1",
		"emit": {"box": Vector2(30, 4)}, "color": C[7], "emitting": false})
	emit(fl, ERUPT + 0.3, GONE + 0.9)
	# rings spreading over the pool while it holds
	for j in 4:
		var starts := []
		var t0 := ERUPT + 0.3 + j * 0.25
		while t0 < FALL + 0.3:
			starts.append(t0)
			t0 += 1.0
		for side in [-1.0, 1.0]:
			var rg := water_ring("PoolRing%d%s" % [j, "Far" if side < 0.0 else "Near"], 40, {"sy": SY, "n": 1.0, "side": side,
				"seed": float(20 + j)}, {"back": side < 0.0})
			var reach := 0.7 + 0.3 * jsrand([j, S + 30])
			sample_shader(rg, func(t: float) -> Dictionary:
				for s0 in starts:
					var a: float = t - s0
					if a >= 0.0 and a < 0.9:
						var q := a / 0.9
						return {"r": 4.0 + (pool_r(t) * reach - 4.0) * (1.0 - pow(1.0 - q, 2.6)), "k": 0.8 * pow(1.0 - q, 1.7),
							"gap": 3.0 * (0.55 + 0.6 * q), "hot": a < 0.1}
				return {"r": 4.0, "k": 0.0, "gap": 3.0, "hot": false})
