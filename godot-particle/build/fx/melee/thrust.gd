# reimagined-from: src/fx/melee/thrust.js@9714b58585b79ece12a4be3cb170e2d31f435d63
# Thrust: A piercing stab: a bundle of streaks shoots out from the hand to a point, a long four-point star flares at the tip with a pierce ring, sparks and speed lines.
# one-shot, 0.75 s, 196x76 canvas, origin [34.0, 62.0], backdrop ground, stand-in 2
# The bundle is fx/melee/_bundle.gdshader running the original's streaks off the effect's clock (out, hold, drawn in),
# with a glow along it (fx/melee/_glowline); dotted speed lines race beside it (fx/melee/_lines); the long star at the
# point is fx/melee/_longstar.gdshader on the original's pop-and-wobble curve, a pierce ring of dots sheds off it
# (fx/melee/_dotring); sparks, motes and twinkles are the original's spawns replayed on GPU particles
# (fx/melee/_kinds.gdshader); lights flare and die.
extends "res://build/fx/melee/_melee.gd"

const OUT := 0.07
const HOLD := 0.06
const PULL := 0.2
const HX := 9.0
const HY := -20.0


func make() -> void:
	var reach: float = meta.options.reach
	var TX := HX + reach
	var TY := HY
	var tip := Vector2(TX, TY)
	var streaks := []
	for off in [-7, -4, -2, 0, 2, 4, 7]:
		streaks.append({"off": off, "x0": HX + 1 + R.rf(0, 5) + absf(off) * 0.6, "t0": R.rf(0, 0.02) + absf(off) * 0.003, "hot": off == 0, "len": R.rf(0.75, 1)})

	# the point catches the light before it goes
	sparkle("Ready", Vector2(HX + 2, HY), C[5], C[3], func(t: float) -> Array: return [5.0 * (1.0 - t / 0.05) + 1.0, 0.4], 0.0, 0.05)
	# speed lines race forward beside the bundle while it shoots out and just after (the original's 120 Hz chances)
	var lines := []
	var t := 0.0
	while t < OUT + 0.08 - 1e-6:
		t += 1.0 / 120.0
		if t < OUT + 0.08 and R.chance(0.5) and lines.size() < 16:
			var s := R.sgn()
			var v := R.rf(200, 340)
			lines.append([HX + R.rf(0, reach * 0.6) + v / 120.0, HY + s * R.rf(7, 17), v, 0.0, t, 0.24, R.rf(18, 42), 0.6])
	speed_lines("SpeedLines", lines, Vector2(-30, HY - 20), Vector2(TX + 100, HY + 20), 0.4, C[5], C[3])
	# the bundle
	var sa := PackedVector4Array()
	var sb := PackedVector4Array()
	for s in streaks:
		sa.append(Vector4(s.x0, HY + s.off, s.len, s.t0))
		sb.append(Vector4(1.0 if s.hot else 0.0, 0, 0, 0))
	var lo := Vector2(HX - 2, HY - 12)
	var hi := Vector2(TX + 4, HY + 12)
	var bd := shape("Bundle", mel_shader("bundle"), hi - lo, {"sa": sa, "sb": sb, "count": float(streaks.size()), "t": 0.0, "OUT": OUT,
		"HOLD": HOLD, "PULL": PULL, "tip": tip, "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6]}, {"at": (lo + hi) / 2.0})
	key(bd, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	var gl := shape("BundleLight", mel_shader("glowline"), Vector2(reach + 30, 30), {"a": Vector2(HX, HY), "b": Vector2(HX, HY), "radius": 6.0,
		"color": C[4], "k": 0.0}, {"at": Vector2(roundf((HX + TX) / 2.0), HY)})
	keyd(gl, ["a", "b", "k"], func(tt: float) -> Dictionary:
		var pull := smooth(OUT + HOLD, OUT + HOLD + PULL, tt)
		return {"a": Vector2(HX + (TX - HX) * pull, HY), "b": Vector2(HX + (TX - HX) * out_expo(clamp01(tt / OUT)), TY),
			"k": 0.22 * (1.0 - pull) if tt < OUT + HOLD + PULL else 0.0}, 0.0, OUT + HOLD + PULL + 0.02)

	# the long star at the point, and a pierce ring shed from it
	var star_l := func(tt: float) -> float:
		var q := tt - OUT
		var g := out_back(clamp01(q / 0.04), 2.4) * (1.0 - smooth(0.08, 0.4, q)) * (1.0 + 0.12 * sin(q * 70.0))
		return 24.0 * g
	var ls := shape("LongStar", mel_shader("longstar"), Vector2(65, 65), {"frac_": tip - tip.floor(), "L": 0.0, "c4": C[4], "c5": C[5]},
		{"at": tip.floor() + Vector2(0.5, 0.5)})
	keyf_window(ls, "material:shader_parameter/L", star_l, OUT, OUT + 0.4)
	glow_path("StarLight", 40, C[4], func(tt: float) -> Array:
		var L: float = star_l.call(tt)
		return [tip, 6.0 + L * 1.3, 0.35 * (1.0 - (tt - OUT) / 0.4) if L >= 1.0 else 0.0], OUT, OUT + 0.4)
	glow_path("StarWhite", 14, Color.WHITE, func(tt: float) -> Array:
		var L: float = star_l.call(tt)
		return [tip, 3.0 + L * 0.4, 0.3 * (1.0 - (tt - OUT) / 0.4) if L >= 1.0 else 0.0], OUT, OUT + 0.4)
	dot_ring("Pierce", tip, 26, func(tt: float) -> Array:
		var k := (tt - OUT) / 0.2
		return [1.0, 0.0, Color.WHITE if k < 0.3 else C[5], 1.15 - k, Vector2(4.0 + 10.0 * k, 0.0)], OUT, OUT + 0.2, {"astep": 0.05})
	# keyed per frame: the ring's radii
	var pr: ColorRect = root.get_node("Pierce")
	keyf(pr, "material:shader_parameter/rx_k", func(tt: float) -> float: return 2.0 + 7.0 * out_cubic((tt - OUT) / 0.2), OUT, OUT + 0.2)
	keyf(pr, "material:shader_parameter/ry_k", func(tt: float) -> float: return 4.0 + 12.0 * out_cubic((tt - OUT) / 0.2), OUT, OUT + 0.2)

	# the point strikes: light, sparks forward, motes, twinkles
	light_burst("Flash", OUT, tip, 44, C[4], 0.45, 0.3)
	light_burst("White", OUT, tip, 14, Color.WHITE, 0.6, 0.06)
	var sparks := []
	for i in 12:
		var a := R.rf(-0.55, 0.45)
		var v := R.rf(150, 330)
		sparks.append(sp(TX, TY, cos(a) * v, sin(a) * v - 30.0, R.rf(0.12, 0.35)))
	burst("Sparks", SPARK, OUT, sparks)
	var motes := []
	for i in 10:
		var a := R.rf(-0.9, 0.9) + (PI if R.chance(0.3) else 0.0)
		var v := R.rf(40, 120)
		motes.append(sp(TX + R.rf(-6, 2), TY + R.rf(-2, 2), cos(a) * v, sin(a) * v, R.rf(0.25, 0.5), C[5] if R.chance(0.5) else C[4], 0.6))
	burst("Motes", MOTE, OUT, motes)
	var stars := []
	for i in 4:
		stars.append(sp(TX + R.rf(-10, 8), TY + R.rf(-9, 9), 0, -3, R.rf(0.2, 0.4), C[5] if R.chance(0.5) else Color.WHITE, R.rf(1, 2), R.rf(0.06, 0.2)))
	burst("Stars", STAR, OUT, stars)
