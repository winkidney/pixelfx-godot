# reimagined-from: src/fx/water/splash.js@abb52499d80bcb461a33e8a94f2355dfe90c2bcc
# Splash: A stone drops into still water: a white hit, a crown that tears into droplets arcing out to plink down with rings, a jet that bounces back, foam and drifting mist.
# one-shot, 2.50 s, 176x100 canvas, origin [88.0, 78.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The crown is a canvas shader (fx/water/_crown.gdshader) keyed by the time since the hit with the original's curves,
# phase and finger lengths: the cavity, the far wall, the near wall's see-through sheet (soft), its streaks, lit edges,
# rolled lip and fingers with beads, the lace of foam after, the jet bouncing back and the flat white hit. Rings
# spread from the hit and again as the jet slumps (fx/water/_ring.gdshader, far halves behind, near in front). The
# spray, the beads torn off the fingers, the drops the lip and the falling crown shed, flakes and sparkles are bursts
# that land on the water (a collision floor) where they plink and ring; mist rolls out low (soft); bubbles from the
# sunk stone dome up and pop; light flashes and settles.
extends "res://build/fx/water/_water.gd"

const SY := 0.22
const HIT := 0.16
const G := 820.0
const JET := 0.3
const TEAR := 0.11
const ROCK := ["#141219", "#221f2b", "#34303f", "#4a4558", "#655f74", "#8a8498"]


static func jet_h(v: float) -> float:
	return 26.0 * (out_cubic(v / 0.12) - in_quad(clampf((v - 0.15) / 0.28, 0.0, 1.0)))


func make() -> void:
	ground(2.0)
	var S: int = meta.options.seed
	var R := JsRng.new(S)
	var phi := R.range(0.0, TAU)
	var lens := PackedFloat32Array()
	for k in 12:
		lens.append(R.range(0.2, 0.36))
	var D: float = meta.duration
	var u_keys := [[0.0, -HIT], [D, D - HIT]]

	# the crown, in its layers
	var size := Vector2(72, 64)
	var at := Vector2(0, -22)
	var base := {"pal": C, "sy": SY, "phi": phi, "seed": float(S), "spike_l": lens}
	var layers := [["Cavity", 3.0, true], ["FarWall", 0.0, true], ["Sheet", 1.0, false], ["Crown", 2.0, false]]
	var nodes := {}
	for L in layers:
		var pr := base.duplicate()
		pr.mode = L[1]
		if L[1] == 1.0:
			pr.translucent = true
		nodes[L[0]] = pr
	# the far halves of the rings go between the cavity and the far wall
	var cavity := shape("Cavity", water_shader("crown"), size, nodes.Cavity, {"at": at, "back": true})
	ripple("Ring", HIT, 8.0, 56.0, 2.0, {"n": 2.0, "gap": 3.4, "k": 1.35, "hot": 0.16, "glint": 1.0, "seed": 1})
	ripple("Ring2", HIT + 0.14, 5.0, 38.0, 1.7, {"n": 1.0, "k": 0.9, "seed": 2})
	ripple("Slump", HIT + JET + 0.38, 3.0, 30.0, 1.5, {"n": 2.0, "gap": 2.6, "k": 0.9, "seed": 3})
	var far := shape("FarWall", water_shader("crown"), size, nodes.FarWall, {"at": at, "back": true})
	var sheet := shape("Sheet", water_shader("crown"), size, nodes.Sheet, {"at": at})
	var crown := shape("Crown", water_shader("crown"), size, nodes.Crown, {"at": at})
	for n in [cavity, far, sheet, crown]:
		key(n, "material:shader_parameter/u", u_keys)
		key(n, "material:shader_parameter/now", [[0.0, 0.0], [D, D]])

	# the stone, falling fast with a streak of air off it
	var stone := group("Stone", {"at": Vector2(0, -70)})
	line("Streak", PackedVector2Array([Vector2(0.5, -12), Vector2(0.5, -3)]), {"parent": stone,
		"gradient": gradient([Color(ROCK[4], 0.0), Color(ROCK[4], 0.8)], [0.0, 1.0], true)})
	sprite("Rim", "disc7", {"parent": stone, "modulate": Color(ROCK[0])})
	sprite("Body", "disc5", {"parent": stone, "modulate": Color(ROCK[3])})
	sprite("Lit", "dot2", {"parent": stone, "modulate": Color(ROCK[4]), "at": Vector2(-1, -1)})
	dot("Shine", Color(ROCK[5]), Vector2(-2, -2), {"parent": stone})
	sprite("Shade", "dot2", {"parent": stone, "modulate": Color(ROCK[2]), "at": Vector2(1, 1)})
	for c in ROCK:
		keep_colour(Color(c))
	var sp := []
	for f in 6:
		var t := f / 30.0
		var v := t / HIT
		sp.append([t, Vector2(0, roundf(-70.0 + 70.0 * (0.4 * v + 0.6 * v * v)))])
	key(stone, "position", sp, "nearest")
	show(stone, 0.0, HIT)

	# spray: the first sheet thrown up fast and fine, beads off the fingers, drops the lip and the falling crown shed
	var spray := {"at": Vector2(0, -3), "amount": 15, "lifetime": 0.8, "one_shot": true, "explosiveness": 0.9,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(3, 1)}, "dir": -90, "spread": 38,
		"speed": [170, 290], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[7], C[5]]),
		"collide": {"hide": true, "size": 1}}
	emit(particles("Spray", spray), HIT)
	var heavy := spray.duplicate()
	heavy.merge({"amount": 6, "texture": "streak4", "align": true, "initial": gradient([C[5], C[4]])}, true)
	emit(particles("SprayBeads", heavy), HIT)
	var tear := spray.duplicate()
	tear.merge({"at": Vector2(0, -26), "amount": 12, "lifetime": 0.9, "explosiveness": 1.0, "texture": "dot2",
		"emit": {"box": Vector2(14, 2)}, "spread": 42, "speed": [100, 200], "initial": gradient([C[6], C[5], C[7]]),
		"collide": {"hide": true, "size": 2}}, true)
	var beads := particles("TornBeads", tear)
	emit(beads, HIT + TEAR)
	var tails := tear.duplicate()
	tails.merge({"texture": "streak4", "align": true, "initial": gradient([C[3], C[4]])}, true)
	var tail := particles("TornTails", tails)
	tail.seed = beads.seed
	emit(tail, HIT + TEAR)
	var lipd := spray.duplicate()
	lipd.merge({"at": Vector2(0, -9), "amount": 5, "lifetime": 0.5, "one_shot": false, "explosiveness": 0.0,
		"emit": {"box": Vector2(12, 3)}, "spread": 70, "speed": [20, 55]}, true)
	var lp := particles("LipDrops", lipd)
	emit(lp, HIT + 0.13, HIT + 0.3)
	var fall := spray.duplicate()
	fall.merge({"at": Vector2(0, -5), "amount": 8, "lifetime": 0.5, "explosiveness": 1.0, "emit": {"box": Vector2(13, 2)},
		"spread": 40, "speed": [35, 85]}, true)
	emit(particles("FallDrops", fall), HIT + 0.3)
	var flakes := particles("Flakes", {"at": Vector2(0, -10), "amount": 20, "lifetime": 0.9, "randomness": 0.4,
		"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(9, 4)},
		"dir": -90, "spread": 60, "speed": [30, 100], "damping": [30, 50], "gravity": Vector2(0, 90),
		"initial": gradient([C[7], C[6]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	emit(flakes, HIT + 0.04)
	var stars := particles("Sparkles", {"at": Vector2(0, -13), "amount": 5, "lifetime": 0.4, "one_shot": true,
		"explosiveness": 0.8, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(13, 7)}, "dir": -90,
		"speed": [3, 5], "color": C[6]})
	emit(stars, HIT + 0.04)

	# where drops come down: a white fleck and a little ring
	var land := particles("Plinks", {"at": Vector2(0, 1), "amount": 7, "lifetime": 0.4, "emitting": false,
		"texture": "ripple5x1", "emit": {"box": Vector2(36, 4)}, "scale_curve": [[0, 0.6], [1, 1.4]],
		"ramp": ramp("palette", {"from": 0.57, "to": 0.86, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
	emit(land, HIT + 0.35, HIT + 1.2)
	var fleck := particles("PlinkFlecks", {"at": Vector2(0, 0), "amount": 3, "lifetime": 0.07, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(36, 4)}, "color": C[7]})
	emit(fleck, HIT + 0.35, HIT + 1.2)

	# the jet's tip pinches off into a bead that hangs, then drops back
	var b0 := HIT + JET + 0.12
	var bead := shape("JetBead", water_shader("bead"), Vector2(8, 16), {"pal": C, "style": 0.0})
	var bp := []
	var bv := []
	var bt := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var a := t - b0
		var h := jet_h(0.12) + 1.0 + 55.0 * a - 0.5 * G * a * a
		bv.append([t, a >= 0.0 and h > 0.0])
		bp.append([t, Vector2(0, roundf(0.2 * SY - h))])
		bt.append([t, minf(5.0, absf(55.0 - G * maxf(a, 0.0)) * 0.011)])
	key(bead, "visible", bv, "nearest")
	key(bead, "position", bp, "nearest")
	key(bead, "material:shader_parameter/tail", bt, "nearest")
	bead.visible = false

	# the stone sinks and lets go of its air: bubbles dome up and pop with a ring
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 3:
		var t0: float = HIT + [0.95, 1.2, 1.5][i]
		var x := rng.randf_range(-5, 5)
		var y := rng.randf_range(-6, 6) * SY
		var r := rng.randf_range(1.3, 2.3)
		var dome := ring("Bubble%d" % i, 4, {"radius": 0.0, "thickness": 1.0, "color": C[6], "side": 1.0}, {"at": Vector2(roundf(x), roundf(y))})
		var dr := []
		for f in 7:
			var g := f / 6.0
			dr.append([t0 + g * 0.2, r * (1.0 + 2.70158 * pow(g - 1.0, 3.0) + 1.70158 * pow(g - 1.0, 2.0)) + 0.5])
		key(dome, "material:shader_parameter/radius", dr)
		show(dome, t0, t0 + 0.2)
		ripple("Pop%d" % i, t0 + 0.2, 1.0, 7.0, 0.6, {"n": 1.0, "k": 0.9, "seed": 10 + i, "at": Vector2(roundf(x), roundf(y))})

	# mist rolls out low along the water, more as the jet pinches off and slumps
	# (soft halos on the light layer: the soft layer's eight steps turn faint puffs into grey discs)
	var mist := gradient([Color(C[5], 0.0), Color(C[6], 0.22), Color(C[5], 0.12), Color(C[5], 0.0)], [0.0, 0.12, 0.5, 1.0], true)
	for m in [["MistL", 180.0, HIT, 5, Vector2(0, -4)], ["MistR", 0.0, HIT, 5, Vector2(0, -4)],
			["MistJet", -90.0, b0, 3, Vector2(0, -20)], ["MistSlump", 0.0, HIT + JET + 0.38, 4, Vector2(0, -2)]]:
		var e := particles(m[0], {"layer": "light", "at": m[4], "amount": m[3], "lifetime": 1.2, "randomness": 0.3,
			"one_shot": true, "explosiveness": 0.9, "emitting": false, "texture": "glow32", "emit": {"box": Vector2(6, 2)},
			"dir": m[1], "spread": 25.0 if m[0].begins_with("Mist") and m[1] != 0.0 or m[0] == "MistR" else 180.0,
			"speed": [25, 70] if m[2] == HIT else [5, 25], "damping": [40, 60], "gravity": Vector2(0, -7),
			"scale": [0.3, 0.45], "scale_curve": [[0, 0.6], [1, 1.5]], "ramp": mist})
		emit(e, m[2])

	# light: a flash at the hit, the jet's line of light, the disturbed water keeping a cool light as it settles
	var flash := glow("HitLight", 52, {"radius": 52, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -6)})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0], [HIT, 0.6], [HIT + 0.45, 0.0]])
	var hot := glow("HitWhite", 16, {"radius": 16, "color": C[7], "alpha": 0.0}, {"at": Vector2(0, -4)})
	key(hot, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0], [HIT, 0.5], [HIT + 0.08, 0.0]])
	var spark := glow("SparkLight", 14, {"radius": 14, "color": C[6], "alpha": 0.0}, {"at": Vector2(0, -3)})
	key(spark, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0], [HIT, 0.5], [HIT + 0.07, 0.0]])
	var s1 := glow("Settle", 34, {"radius": 34, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -2)})
	sample(s1, "material:shader_parameter/alpha", func(t: float) -> float:
		var u := t - HIT
		return 0.2 * (1.0 - smooth(0.0, 1.6, u)) if u > 0.0 else 0.0)
	var s2 := glow("SettleWide", 64, {"radius": 64, "color": C[3], "alpha": 0.0}, {"at": Vector2(0, 2)})
	sample(s2, "material:shader_parameter/alpha", func(t: float) -> float:
		var u := t - HIT
		return 0.16 * (1.0 - smooth(0.1, 2.1, u)) if u > 0.0 else 0.0)
	var jl := line("JetLight", PackedVector2Array([Vector2(0, -1), Vector2(0, -1)]), {"layer": "light", "width": 14, "color": Color(C[5], 0.3)})
	var pts := []
	for f in int(roundf(D * 30.0)) + 1:
		var t := f / 30.0
		var h := jet_h(t - HIT - JET) if t - HIT - JET >= 0.0 else 0.0
		pts.append([t, PackedVector2Array([Vector2(0.5, -1), Vector2(0.5, -maxf(h, 1.0))])])
	key(jl, "points", pts, "nearest")
	sample(jl, "visible", func(t: float) -> bool: return t - HIT - JET >= 0.0 and jet_h(t - HIT - JET) >= 0.8, 0.0, -1.0, 30.0, "nearest")
