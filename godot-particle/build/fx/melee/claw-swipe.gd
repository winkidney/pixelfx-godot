# reimagined-from: src/fx/melee/claw-swipe.js@5db5500b64e9e83c7d4f24f6bd886692f620261f
# Claw swipe: Three claw marks rake down one after another, white-hot, cooling through orange to red, then close up from both ends and leave a dotted scar, with hot flecks and drips.
# one-shot, 0.90 s, 128x96 canvas, origin [36.0, 84.0], backdrop ground, stand-in 2
# Each mark is a lens along the original's swing (fx/melee/_claw.gdshader: sharp at both ends, white-hot in the core,
# cooling outward and with time), torn open on its curve and closed up from both ends, leaving the dotted scar; light
# rides it (fx/melee/_swing_light). As each tears open: a light, hot flecks, motes and drips (the original's spawns,
# replayed on GPU particles by fx/melee/_kinds.gdshader); the claw tip glints.
extends "res://build/fx/melee/_melee.gd"

const RAKE := 0.05
const STAGGER := 0.04
const CLOSE0 := 0.16
const CLOSE := 0.3


func make() -> void:
	var n := C.size()
	var marks := []
	for i in 3:
		var s := through(31 + i * 8, -23 + i * 2, 1.84, 1, 40, 0.84 - i * 0.05, 0.5)
		s.t0 = i * STAGGER
		s.W = 4.2 - i * 0.4
		marks.append(s)
	for i in 3:
		var s: Dictionary = marks[i]
		var S: float = s.span
		var W: float = s.W
		var t0: float = s.t0
		var st := func(t: float) -> Dictionary:
			var u := t - t0
			var head := S * out_expo(clamp01(u / RAKE)) if u >= 0.0 else 0.0
			var c := smooth(CLOSE0, CLOSE0 + CLOSE, u)
			var lo := S / 2.0 * c
			var hi := minf(head, S - S / 2.0 * c)
			var heat := clamp01(1.0 - u / 0.42)
			var k := 0.8 * (1.0 - clamp01((u - CLOSE0 - CLOSE * 0.5) / 0.4))
			var on := u >= 0.0 and hi - lo > 0.02
			return {"lo": lo, "hi": hi if on else lo, "c": c, "heat": heat, "head": head,
				"tr_k": k if (u >= 0.0 and c > 0.05 and k > 0.0) else 0.0, "tr_a": Vector2(0.04 * S, lo), "tr_b": Vector2(S - lo, 0.96 * S),
				"u0": lo, "u1": hi if on else -1.0, "k0": 0.42 * heat * heat if on else 0.0}
		var mark := swing_shape("Mark%d" % i, "claw", s, {"W": W, "S": S, "ramp": _swing_params(s, 0.0).ramp, "n": float(n),
			"tr_r": s.R - W / 2.0, "tr_col": C[2], "lo": 0.0, "hi": 0.0}, W, 2.0)
		keyd(mark, ["lo", "hi", "c", "heat", "head", "tr_k", "tr_a", "tr_b"], st, 0.0, t0 + 0.9)
		var lit := swing_shape("MarkLight%d" % i, "swing_light", s, {"gr": s.R - W / 2.0, "gstep": 0.2, "rad": 11.0, "color": C[4], "lin": 0.0}, W, 12.0)
		keyd(lit, ["u0", "u1", "k0"], st, 0.0, t0 + 0.5)
	for i in 3:
		var s: Dictionary = marks[i]
		var t0: float = s.t0
		var end := travel(s, s.span)
		var ep: Vector2 = end.p
		var ed: Vector2 = end.d
		# the claw tip glints as it tears in
		sparkle("Glint%d" % i, ep, C[6], C[4], func(t: float) -> Array:
			var g := t - t0 - RAKE * 0.4
			return [5.0 * out_back(minf(1.0, g / 0.04)) * (1.0 - g / 0.16), 0.4], t0 + RAKE * 0.4, t0 + RAKE * 0.4 + 0.16)
		# it tears open: a light, hot flecks on along the rake, motes and drips off the wound
		var t_open := t0 + RAKE * 0.7
		light_burst("Light%d" % i, t_open, ep + Vector2(0, -6), 34, C[4], 0.45, 0.3)
		var sparks := []
		for k in 7:
			var a := ed.angle() + R.rf(-0.5, 0.5)
			var v := R.rf(110, 260)
			sparks.append(sp(ep.x, ep.y, cos(a) * v, sin(a) * v, R.rf(0.12, 0.32)))
		burst("Flecks%d" % i, SPARK, t_open, sparks)
		var motes := []
		for k in 5:
			var p := on_swing(s, s.R, s.span * R.rf(0.15, 0.9))
			motes.append(sp(p.x, p.y, R.rf(-60, -10), R.rf(-30, 30), R.rf(0.2, 0.4), C[5] if R.chance(0.5) else C[4], 0.5))
		burst("Motes%d" % i, MOTE, t_open, motes)
		var drips := []
		for k in 2:
			var p := on_swing(s, s.R - 1.0, s.span * R.rf(0.35, 0.75))
			var q := sp(p.x, p.y, R.rf(-8, 8), R.rf(10, 40), 1.2, C[3])
			q.g = 0.55
			drips.append(q)
		burst("Drips%d" % i, DRIP, t_open, drips)
