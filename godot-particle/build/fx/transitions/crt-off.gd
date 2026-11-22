# reimagined-from: src/fx/transitions/crt-off.js@7320aea552f34cb932908078583ad52d4a1a94b5
# CRT off: The picture squeezes into a white-hot glowing line, the line into a dot that lingers as a fading afterglow; then it switches back on, dot to line to picture, with a warm-up glow.
# one-shot, 2.00 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# One screen shader (fx/transitions/_crt.gdshader) closes the inks in on the strip and draws the humming line with the
# original's noise and static, its light twin (_crt_light.gdshader) the brightening strip, the line's glow and the
# warm-up wash with its refresh band; the strip's height, the line's length and the flicker are keyed every frame
# from the original's curves. The dot (its glint, the phosphor smear, its afterglow) and the pop as it switches on are
# frame-table particles (marks()).
extends "res://build/fx/transitions/_transitions.gd"

const YC := 90.0
const XC := 160.0
const SQ0 := 0.06
const SQ1 := 0.34
const LN1 := 0.56
const DOT1 := 0.86
const ON0 := 1.06
const ON1 := 1.16
const OPEN1 := 1.42


static func shape_at(t: float) -> Vector2:
	if t < SQ0:
		return Vector2(SHH, XC)
	if t < SQ1:
		return Vector2(maxf(1.0, SHH * (1.0 - in_cubic((t - SQ0) / (SQ1 - SQ0)))), XC)
	if t < LN1:
		return Vector2(1.0, XC * (1.0 - in_quad((t - SQ1) / (LN1 - SQ1))))
	if t < ON0:
		return Vector2(0.0, 0.0)
	if t < ON1:
		return Vector2(1.0, XC * out_expo((t - ON0) / (ON1 - ON0)))
	return Vector2(maxf(1.0, SHH * out_cubic(clampf((t - ON1) / (OPEN1 - ON1), 0.0, 1.0))), XC)


func make() -> void:
	var seed: int = meta.options.seed
	var nodes := [screen("Screen", "crt", {"seed": seed}), screen("Light", "crt_light", {"seed": seed})]
	for n in nodes:
		# shape() works in doubles: the strip's rows and the line's ends land where the original's do
		per_frame(n, "material:shader_parameter/h", func(_i: int, t: float) -> float: return shape_at(t).x)
		per_frame(n, "material:shader_parameter/w", func(_i: int, t: float) -> float: return shape_at(t).y)
		per_frame(n, "material:shader_parameter/fl", func(_i: int, t: float) -> float: return 0.85 + 0.15 * rand([floorf(t * 30.0), 7, seed]))
		per_frame(n, "material:shader_parameter/fr", func(_i: int, t: float) -> float: return floorf(t * 30.0))

	# the dot: a glint that holds a moment, then the phosphor cooling and smearing sideways; the pop switching on
	var rows := frame_rows(func(_i: int, t: float) -> Array:
		var out := []
		if t >= LN1 and t < ON0:
			var u := (t - LN1) / (DOT1 - LN1)
			out.append(glint_m(XC, YC, 10.0 * (1.0 - u / 0.35) + 3.0, 0.2 + u * 2.0, 6, 5) if u < 0.35 else null)
			if u < 1.0:
				out.append({"x": XC, "y": YC, "c": 8 if u < 0.5 else (6 if u < 0.75 else 4), "lc": 5, "lp": Vector2(XC, YC),
					"lr": 22.0 * (1.0 - u * 0.5), "lk": 0.55 * pow(1.0 - u, 1.5)})
				out.append({"x": XC - 1.0, "y": YC, "c": 6 if u < 0.4 else 4})
				var sm := jr(9.0 * (1.0 - u))
				for k in range(2, int(sm) + 1):
					var a := 1.0 - k / (sm + 1.0)
					out.append({"x": XC - k, "y": YC, "c": 4, "a": a})
					out.append({"x": XC + k - 1.0, "y": YC, "c": 4, "a": a})
		var s := t - ON0
		if s >= 0.0 and s < 0.14:
			var g: Dictionary = glint_m(XC, YC, 12.0 * (1.0 - s / 0.14) + 2.0, 0.4 + s * 6.0, 6, 5)
			g.lc = 8
			g.lp = Vector2(XC, YC)
			g.lr = 40.0
			g.lk = 0.5 * (1.0 - s / 0.14)
			out.append(g)
		return out)
	marks("Dot", rows)
