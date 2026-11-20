# reimagined-from: src/fx/transitions/blinds.js@44a8b6d24b636bf1ace8fd91b584a2987aa41de7
# Blinds: Slats catch the light edge-on, then tilt shut top to bottom, lit rims glinting as warm light squeezes through the closing gaps with dust in it; then they tilt open and fade.
# one-shot, 2.00 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The slats are one screen shader (fx/transitions/_blinds.gdshader) turning each slat by the original's curves on its
# own clock, row by row with its rim, face and shadowed underside; its light twin (_blinds_light.gdshader) lights the
# rims and pours light through the closing gaps. The dust is the original's embers, replayed from its generator at its
# 120 Hz steps and drawn as it draws them (a speck, now and then a twinkling cross, only where a gap shows it), and
# the glints running along the turning rims, are frame-table particles (marks()).
extends "res://build/fx/transitions/_transitions.gd"

const N := 12
const SH := 15.0
const SHUT0 := 0.08
const OPEN0 := 1.02
const STEP := 0.038
const TURN := 0.42
const OSTEP := 0.03
const OTURN := 0.4
const FADE0 := 1.72


static func out_back_g(x: float, s: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0))


static func angle(i: int, t: float) -> float:
	if t < OPEN0:
		return (PI / 2.0) * out_back_g(clampf((t - SHUT0 - i * STEP) / TURN, 0.0, 1.0), 1.6)
	return (PI / 2.0) * (1.0 - in_out_cubic(clampf((t - OPEN0 - i * OSTEP) / OTURN, 0.0, 1.0)))


func make() -> void:
	var R := JsRng.new(int(meta.options.seed))
	var end: float = D - 0.05
	var dust := []   # the original's ps.list: {x, y, vx, vy, life, max, seed}
	var rows := []
	var glints := []
	var pst := [0.0]
	var step := func(t: float, dt: float) -> void:
		if t < FADE0 and R.chance(0.8):
			var i := R.int_(0, N - 1)
			var th := angle(i, t)
			if th > 0.2 and th < 1.45:
				var x := R.range(0, SW)
				var y := (i + 1) * SH + R.range(-2, 2)
				var vx := R.range(-8, 8)
				var vy := -R.range(2, 8)
				var life := minf(R.range(0.5, 1), end - t)
				var sd := R.next() * 100.0
				dust.append({"x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "seed": sd})
		pst[0] += dt
		var pt: float = pst[0]
		for j in range(dust.size() - 1, -1, -1):
			var q: Dictionary = dust[j]
			q.life -= dt
			if q.life <= 0.0:
				dust.remove_at(j)
				continue
			q.vy += (-30.0 + sin(pt * 3.0 + q.seed) * 20.0) * dt
			q.vx += cos(pt * 2.3 + q.seed) * 45.0 * dt
			q.vx -= q.vx * 1.6 * dt
			q.vy -= q.vy * 1.6 * dt
			q.x += q.vx * dt
			q.y += q.vy * dt
	var frame := func(_i: int, t: float) -> void:
		# which rows show through: not covered by any slat
		var open := PackedByteArray()
		open.resize(int(SHH))
		open.fill(1)
		for i in N:
			var h := maxf(1.0, (SH + 1.0) * absf(sin(angle(i, t))))
			var yc := (i + 0.5) * SH
			for y in range(maxi(0, int(ceilf(yc - h / 2.0 - 0.5))), mini(int(SHH) - 1, int(floorf(yc + h / 2.0 - 0.5))) + 1):
				open[y] = 0
		var out := []
		for q in dust:
			var y := int(floorf(q.y))
			var k: float = q.life / q.max
			if y < 0 or y >= int(SHH) or not open[y] or q.x < 0.0 or q.x >= SW:
				continue
			var tw: bool = fmod(q.seed, 1.0) < 0.3 and sin(t * 14.0 + q.seed) > 0.0
			var c: int = 8 if (tw or k > 0.5) else 5
			out.append({"x": q.x, "y": y, "c": c, "lc": 6, "lp": Vector2(q.x, y), "lr": 0.0, "lk": (0.7 if tw else 0.4) * k})
			if tw:
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var yy: int = y + dd.y
					if yy >= 0 and yy < int(SHH) and open[yy]:
						out.append({"x": q.x + dd.x, "y": yy, "c": 6})
		rows.append(out)
		# a glint runs along each lit rim as its slat turns
		var gl := []
		for i in N:
			var th := angle(i, t)
			var h := maxf(1.0, (SH + 1.0) * absf(sin(th)))
			if h < 2.5:
				continue
			var lit := 0.0 if th > PI / 2.0 else cos(th)
			var y0 := maxf(0.0, ceilf((i + 0.5) * SH - h / 2.0 - 0.5))
			var u := clampf((t - SHUT0 - i * STEP) / TURN, 0.0, 1.0) if t < OPEN0 else clampf((t - OPEN0 - i * OSTEP) / OTURN, 0.0, 1.0)
			if lit > 0.3 and u > 0.05 and u < 0.95:
				gl.append(glint_m(SW * (u if t < OPEN0 else 1.0 - u), y0, 6.0 * sin(PI * u), u * 3.0, 6, 5))
		glints.append(gl)
	var clocks := replay(step, frame)

	# the dust is behind the slats: drawn first, so a slat's edge row covers it as in the original
	marks("Dust", rows)
	screen("Slats", "blinds", {}, {"clock": clocks})
	screen("Light", "blinds_light", {}, {"clock": clocks})
	marks("Glints", glints)
