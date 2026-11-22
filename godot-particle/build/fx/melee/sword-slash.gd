# reimagined-from: src/fx/melee/sword-slash.js@8e9258f474a2461b85a2992d4d58c354f27054da
# Sword slash: a tilted crescent whips round in two frames, cools from white to deep blue down a dithered tail; the
# tip glints, sparks and shavings fly off the edge.
# The smear and its thinner echo are the slash shader (fx/melee/_slash.gdshader: the original's crescent profile and
# the dotted trace of the blade's path it leaves), their head and tail keyed from the original's sweep / hold / trail;
# light rides each (fx/melee/_swing_light); a big glow rides the head; sparks off the tip and shavings off the arc are
# the original's own spawns replayed on GPU particles (fx/melee/_kinds.gdshader) as the edge lands; a star glint at
# the tip.
extends "res://build/fx/melee/_melee.gd"


func make() -> void:
	var R0: float = meta.options.radius
	var A := swing({"cx": 6.0, "cy": -26.0, "R": R0, "sy": 0.6, "rot": -0.38, "a0": -2.55, "dir": 1.0, "span": 3.5, "W": 12.0,
		"t0": 0.0, "sweep": 0.06, "hold": 0.06, "trail": 0.24, "ramp": C})
	var E := swing({"cx": 6.0, "cy": -26.0, "R": R0 * 33.0 / 42.0, "sy": 0.6, "rot": -0.38, "a0": -2.55 + 0.35, "dir": 1.0,
		"span": 3.0, "W": R0 * 4.5 / 42.0, "t0": 0.017, "sweep": 0.06, "hold": 0.03, "trail": 0.2, "ramp": C.slice(0, 6)})
	slash("Echo", E, 0.0, {"trace": 1})
	slash("Smear", A, 0.0, {"trace": 1})

	var tip := on_swing(A, A.R - A.W * 0.3, A.span)
	var tip_d := (on_swing(A, A.R - A.W * 0.3, A.span + 0.05) - tip).normalized()
	# the tip glints as the edge arrives
	sparkle("Glint", tip, C[5], C[3], func(t: float) -> Array:
		var g: float = t - A.sweep * 0.6
		return [9.0 * out_back(minf(1.0, g / 0.05)) * (1.0 - g / 0.22), 0.6], A.sweep * 0.6, A.sweep * 0.6 + 0.22)
	# light rides the head of the swing
	glow_path("Shine", 41, C[3], func(t: float) -> Array:
		return [on_swing(A, A.R - 4.0, A.span * out_expo(clamp01(t / A.sweep))), 40.0, 0.5 * (1.0 - t / 0.3)], 0.0, 0.3)

	# as the edge lands: sparks off the tip, bright shavings flung off the arc
	var land := 0.0625
	var sparks := []
	for i in 10:
		var a := tip_d.angle() + R.rf(-0.5, 0.5)
		var v := R.rf(150, 400)
		sparks.append(sp(tip.x, tip.y, cos(a) * v, sin(a) * v, R.rf(0.12, 0.35)))
	burst("Sparks", SPARK, land, sparks)
	var shav := []
	for i in 16:
		var p := on_swing(A, A.R, A.span * R.rf(0.3, 1.0))
		var o := (p - Vector2(A.cx, A.cy)).normalized()
		var v := R.rf(30, 100)
		shav.append(sp(p.x, p.y, o.x * v, o.y * v - 10.0, R.rf(0.25, 0.55), C[4 + R.ri(0, 1)], 0.6))
	burst("Shavings", MOTE, land, shav)
