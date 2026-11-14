# reimagined-from: src/fx/water/wave-crash.js@4a22114c1c405fd0c905b5bdad91eb2418808004
# Wave crash: A swell rolls in and steepens, its lip throws forward and curls over a dark barrel, then crashes into a burst of white foam and spray that surges on and fades to lace.
# one-shot, 3.20 s, 224x104 canvas, origin [112.0, 86.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The wave is a canvas shader (fx/water/_wave.gdshader) on the original's curves and noise, keyed only by the time:
# the sea's lit line and the dark water under it, the swell's body column by column steepening as it rolls in, the
# lip thrown off its crest (white along its outer edge, dark beneath) and the glint at its tip, the white burst where
# it lands, the lace left behind the surge, and their light. Wind tears flakes off the crest and the tip sheds drops;
# at the crash spray and a plume of spit fly up, foam billows burst and roll on with the surge, flakes, sparkles and
# mist hang over it, a ring spreads (fx/water/_ring.gdshader) and drops plink back down (emitters).
extends "res://build/fx/water/_water.gd"

const SY := 0.22
const G := 820.0
const CRASH := 1.2
const LIP0 := 0.62


static func in_out_sine(x: float) -> float:
	return -(cos(PI * x) - 1.0) / 2.0


static func crest_x(t: float) -> float:
	return -80.0 + 72.0 * in_out_sine(t / CRASH) if t < CRASH else -8.0 + 30.0 * out_cubic((t - CRASH) / 1.4)


static func crest_h(t: float) -> float:
	if t < CRASH:
		return 5.0 + 33.0 * in_out_sine(clampf(t / (CRASH * 0.92), 0.0, 1.0))
	return 38.0 * (1.0 - out_cubic((t - CRASH) / 0.45)) + 5.0 * (1.0 - smooth(CRASH, CRASH + 1.6, t))


static func lip_tip(t: float) -> Vector2:
	var k := clampf((t - LIP0) / (CRASH - LIP0), 0.0, 1.0)
	var A := crest_h(t)
	return Vector2(crest_x(t) + 1.0 + 30.0 * pow(k, 0.8), -A + A * k * k * 0.98)


func billows(name: String, o: Dictionary) -> Array:
	# a billow of foam (the original's billow()): a shadowed underside, a white body, a lit cap; three emitters, one seed
	var under := o.duplicate()
	under.merge({"texture": "disc7", "color": C[4]}, true)
	var a := particles(name, under)
	var body := o.duplicate()
	body.merge({"texture": "disc5", "color": C[6], "at": o.get("at", Vector2.ZERO) + Vector2(-0.5, -1)}, true)
	var b := twin(name + "Body", a, body, {})
	var cap := o.duplicate()
	cap.merge({"texture": "dot2", "color": C[7], "at": o.get("at", Vector2.ZERO) + Vector2(-1.5, -2)}, true)
	var c := twin(name + "Cap", a, cap, {})
	return [a, b, c]


func make() -> void:
	var D: float = meta.duration
	var S: int = meta.options.seed
	ground(0.5)
	var base := {"pal": C, "dur": D, "seed": float(S)}
	var nodes := []
	for m in [["Sea", 0.0, true, false], ["Deep", 3.0, true, true], ["Wave", 1.0, false, false]]:
		var pr := base.duplicate()
		pr.mode = m[1]
		if m[3]:
			pr.translucent = true
		nodes.append(shape(m[0], water_shader("wave"), Vector2(224, 104), pr, {"at": Vector2(0, -34), "back": m[2]}))
	nodes.append(shape("Light", water_shader("wave_light"), Vector2(224, 104), base, {"at": Vector2(0, -34)}))
	for n in nodes:
		key(n, "material:shader_parameter/now", [[0.0, 0.0], [D, D]])
	var x0 := lip_tip(CRASH - 0.001).x

	# wind tears flakes off the crest as it stands; the lip's tip sheds drops as it throws
	var flakes := particles("CrestSpray", {"at": Vector2(crest_x(0.4), -crest_h(0.4)), "amount": 24, "lifetime": 0.7,
		"randomness": 0.3, "texture": "dot1", "emit": {"box": Vector2(3, 1)}, "dir": -150, "spread": 22,
		"speed": [25, 70], "damping": [1.5, 2.5], "drag": true, "gravity": Vector2(0, 20), "emitting": false,
		"initial": gradient([C[7], C[6]]), "alpha_curve": [[0, 1], [0.75, 1], [1, 0]]})
	sample(flakes, "position", func(t: float) -> Vector2: return Vector2(crest_x(t) - 0.5, -crest_h(t) - 1.0), 0.0, CRASH)
	emit(flakes, 0.42, CRASH)
	var tip := particles("TipDrops", {"at": lip_tip(0.8), "amount": 10, "lifetime": 0.5, "texture": "dot1", "dir": -8,
		"spread": 30, "speed": [30, 95], "gravity": Vector2(0, G), "emitting": false, "initial": gradient([C[6], C[5], C[7]]),
		"collide": {"hide": true, "size": 1}})
	sample(tip, "position", lip_tip, 0.0, CRASH)
	emit(tip, 0.8, CRASH)

	# the crash: spray thrown up and forward, the spit shot straight up, foam bursting and rolling on
	var spray := {"at": Vector2(x0 + 2.0, -4), "amount": 32, "lifetime": 1.0, "one_shot": true, "explosiveness": 0.85,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(6, 3)}, "dir": -86, "spread": 30,
		"speed": [120, 330], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[7], C[5]]),
		"collide": {"hide": true, "size": 1}}
	emit(particles("Spray", spray), CRASH)
	var beads := spray.duplicate()
	beads.merge({"amount": 14, "texture": "dot2", "initial": gradient([C[6], C[5]])}, true)
	var bb := particles("SprayBeads", beads)
	emit(bb, CRASH)
	emit(twin("SprayTails", bb, beads, {"texture": "streak4", "align": true, "initial": null, "color": C[3]}), CRASH)
	var spit := spray.duplicate()
	spit.merge({"at": Vector2(x0 + 1.0, -4), "amount": 14, "explosiveness": 0.6, "emit": {"box": Vector2(3, 2)}, "dir": -88,
		"spread": 5, "speed": [220, 300]}, true)
	emit(particles("Spit", spit), CRASH + 0.04)
	for b in billows("Burst", {"at": Vector2(x0, -7), "amount": 34, "lifetime": 0.7, "randomness": 0.3, "one_shot": true,
			"explosiveness": 0.85, "emitting": false, "emit": {"box": Vector2(9, 5)}, "dir": -68, "spread": 34,
			"speed": [80, 185], "damping": [130, 160], "gravity": Vector2(0, 160), "scale": [0.6, 1.2],
			"scale_curve": [[0, 0.4], [0.35, 1.0], [0.7, 1.0], [1, 0.0]], "collide": {"bounce": 0.0, "friction": 1.0, "size": 2}}):
		emit(b, CRASH)
	var surge_at := func(t: float) -> Vector2: return Vector2(crest_x(t) + 4.0, -2.5)
	for b in billows("Surge", {"at": Vector2(x0, -2.5), "amount": 22, "lifetime": 0.6, "randomness": 0.3, "emitting": false,
			"emit": {"box": Vector2(10, 1.5)}, "dir": -40, "spread": 30, "speed": [12, 45], "damping": [2.5, 2.5], "drag": true,
			"gravity": Vector2(0, 160), "scale": [0.5, 1.0], "scale_curve": [[0, 0.4], [0.35, 1.0], [0.7, 1.0], [1, 0.0]],
			"collide": {"bounce": 0.0, "friction": 1.0, "size": 2}}):
		sample(b, "position", surge_at, CRASH, CRASH + 1.2)
		sample(b, "amount_ratio", func(t: float) -> float: return clampf(1.0 - (t - CRASH) / 1.1, 0.0, 1.0), CRASH, CRASH + 1.2)
		emit(b, CRASH + 0.03, CRASH + 1.1)
	# fine spray, sparkles and mist hang over the burst
	var fine := particles("Fine", {"at": Vector2(x0, -9), "amount": 34, "lifetime": 0.95, "randomness": 0.35, "one_shot": true,
		"explosiveness": 0.9, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(8, 5)}, "dir": -80, "spread": 80,
		"speed": [40, 160], "damping": [1.5, 2.5], "drag": true, "gravity": Vector2(0, 60), "initial": gradient([C[7], C[6]]),
		"alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	emit(fine, CRASH)
	var stars := particles("Sparkles", {"at": Vector2(x0 + 2.0, -23), "amount": 10, "lifetime": 0.45, "one_shot": true,
		"explosiveness": 0.5, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(22, 17)}, "dir": -90,
		"speed": [4, 6], "color": C[6]})
	emit(stars, CRASH + 0.05)
	var mist := gradient([Color(C[6], 0.0), Color(C[6], 0.26), Color(C[6], 0.14), Color(C[6], 0.0)], [0.0, 0.12, 0.5, 1.0], true)
	var cloud := particles("Mist", {"layer": "light", "at": Vector2(x0 + 2.0, -10), "amount": 12, "lifetime": 1.4,
		"randomness": 0.3, "one_shot": true, "explosiveness": 0.85, "emitting": false, "texture": "glow32",
		"emit": {"box": Vector2(12, 6)}, "dir": -45, "spread": 50, "speed": [15, 70], "damping": [2.4, 2.4], "drag": true,
		"gravity": Vector2(0, -7), "scale": [0.4, 0.55], "scale_curve": [[0, 0.5], [1, 1.4]], "ramp": mist})
	emit(cloud, CRASH)
	var trail := particles("SurgeMist", {"layer": "light", "at": Vector2(x0, -4), "amount": 4, "lifetime": 1.0,
		"texture": "glow32", "emit": {"box": Vector2(8, 2)}, "dir": -20, "spread": 25, "speed": [10, 40], "emitting": false,
		"damping": [2.4, 2.4], "drag": true, "scale": [0.35, 0.45], "scale_curve": [[0, 0.6], [1, 1.3]], "ramp": mist})
	sample(trail, "position", surge_at, CRASH, CRASH + 0.9)
	emit(trail, CRASH + 0.03, CRASH + 0.8)

	# a ring spreads from where it lands; drops plink back down
	ripple("Ring", CRASH, 6.0, 40.0, 1.2, {"n": 2.0, "gap": 3.0, "k": 1.1, "hot": 0.12, "seed": 1, "at": Vector2(roundf(x0), 0), "sy": SY})
	var plinks := particles("Plinks", {"at": Vector2(x0 + 8.0, 0.5), "amount": 8, "lifetime": 0.35, "texture": "ripple5x1",
		"emit": {"box": Vector2(40, 1)}, "scale_curve": [[0, 0.6], [1, 1.5]], "emitting": false,
		"ramp": ramp("palette", {"from": 0.57, "to": 0.86, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
	emit(plinks, CRASH + 0.3, CRASH + 1.4)
	var flecks := particles("PlinkFlecks", {"at": Vector2(x0 + 8.0, 0), "amount": 3, "lifetime": 0.06, "texture": "dot1",
		"emit": {"box": Vector2(40, 0.5)}, "color": C[7], "emitting": false})
	emit(flecks, CRASH + 0.3, CRASH + 1.4)
