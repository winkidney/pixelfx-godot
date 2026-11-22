# reimagined-from: src/fx/ui/combo-counter.js@2aaf9f4d38a5d88e4eddd76a317b23399b34299e
# Combo counter: x5 COMBO rockets in on streaming speed lines, smearing, and slams to a stop: a white flash, a ring, sparks; it pulses while a timer bar drains, then whooshes out.
# one-shot, 1.45 s, 208x100 canvas, origin [104, 50], backdrop dark
# ramp palette: #1a0516 #3d0a33 #701560 #b0228f #f53cd1 #ff86e6 #ffd2f6 #ffffff
# The words are the drawWord shader (fx/ui/_word.gdshader: the original's big font, italic, bevel, a 2 px outline,
# shadow and shine), its two smeared afterimages two more, every letter keyed every frame from the original's flight,
# stretch and pulse. The speed lines (re-thrown every frame from the original's own hash), the slam's spiky star and
# ring, the sparks, stars and motes (its simulation replayed at 120 Hz), the timer bar and the glint are frame-table
# particles (_ui.gd); every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const HIT := 0.1
const BEAT := 0.5
const OUT := 1.1
const BS := 4.0
const LS := 2.0
const BASE := 12.0


func make() -> void:
	var seed_: int = int(meta.options.seed)
	var R := JsRng.new(seed_)
	var shadow := scalec(C[0], 0.5)
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]])
	var lights := lights_new()
	var big := spell("x" + str(int(roundf(float(meta.options.count)))))
	var lab := spell(String(meta.options.label))
	var WW: float = big.w * BS + 4.0 + lab.w * LS
	var X0 := -WW / 2.0
	var spikes := []
	for i in 10:
		var an := (i / 10.0) * TAU + R.range(-0.15, 0.15)
		spikes.append([an, R.range(14, 24)])
	var st := {"hit": false, "out": false}
	var x_at := func(t: float) -> float:
		t = maxf(0.0, t)
		if t < HIT:
			return -32.0 * pow(1.0 - t / HIT, 2.0)
		if t < OUT:
			return 7.0 * exp(-(t - HIT) * 18.0) * sin((t - HIT) * 34.0)
		var u := seg(t, OUT, OUT + 0.2)
		return -4.0 * out_quad(u / 0.3) if u < 0.3 else -4.0 + 24.0 * in_quad((u - 0.3) / 0.7)
	var bl := glyphs_of(big)
	var ll := glyphs_of(lab)
	var gl := (bl + ll).map(func(L: Dictionary) -> Dictionary: return L.g)
	var glines := group("SpeedLines")
	var gfx := group("Slam")
	var gps := group("Particles")
	var after := []
	for c in [C[2], C[3]]:
		after.append(word("Smear%d" % after.size(), gl, "big", {"fill": [c], "edge": c, "under": c}))
	var main := word("Combo", gl, "big", {"fill": [C[4], C[5], C[6], C[7]], "edge": Color.WHITE, "under": C[3], "outline": C[0], "ow": 2,
		"shadow": shadow, "glint": C[6]})
	var gtop := group("Timer")

	var layout := func(dx: float, stretch: float, pulse: float, flash: float, a: float, dy: float) -> Array:
		var bs := BS * (1.0 + 0.12 * pulse)
		var items := []
		var bx: float = X0 + dx - (big.w * BS * (stretch - 1.0)) / 2.0
		var by := BASE - 7.0 * bs
		for L in bl:
			items.append({"x": bx + L.x * BS * stretch, "y": by + dy, "sx": BS * stretch, "sy": bs, "slant": 1.0, "flash": flash, "a": a})
		var lx: float = X0 + dx + big.w * BS * stretch + 4.0
		for L in ll:
			items.append({"x": lx + L.x * LS * stretch, "y": BASE - 7.0 * LS + dy, "sx": LS * stretch, "sy": LS, "slant": 0.5, "flash": flash, "a": a})
		return items

	var upd := func(dt: float) -> void:
		var t := T
		if not st.hit and t >= HIT:
			st.hit = true
			lights_add(lights, 0, 0, 70, C[5], 0.7, 0.4)
			lights_add(lights, -20, 0, 34, Color.WHITE, 0.8, 0.1)
			for i in 26:
				var an := R.range(-1.2, 1.2) + (PI if R.chance(0.3) else 0.0)
				var sp := R.range(120, 300)
				spawn(ps, SPARK, R.range(-20, 20), R.range(-8, 8), cos(an) * sp, sin(an) * sp * 0.6 - 20, R.range(0.12, 0.3))
		if t > BEAT and t < OUT and R.chance(0.1):
			var x: float = X0 + R.range(0, big.w * BS)
			var y := BASE - R.range(0, 30)
			spawn(ps, STAR, x, y, R.range(-10, 10), -R.range(5, 20), R.range(0.25, 0.45), R.pick([C[7], C[6]]), 1.6 if R.chance(0.3) else 0.6)
		if not st.out and t >= OUT + 0.06:
			st.out = true
			for i in 10:
				spawn(ps, MOTE, R.range(-50, 30), R.range(-14, 10), R.range(220, 320), R.range(-10, 10), R.range(0.06, 0.14), R.pick([C[7], C[6]]), 1)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var sh2 := shake(t, 3, HIT, 0.25, seed_)
		var sx: float = sh2[0]
		var sy: float = sh2[1]
		# speed lines
		lay = "lines"
		var k := 1.0 if t < HIT else (maxf(0.0, 1.0 - (t - HIT) / 0.35) * 0.9 if t < OUT else seg(t, OUT + 0.04, OUT + 0.12) * (1.0 - seg(t, OUT + 0.18, OUT + 0.3)))
		var rev := t >= OUT
		if k > 0.02:
			var fr := floorf(t * 30.0)
			for i in 18:
				if rand([fr, i, 3]) > k:
					continue
				var y := jround((rand([fr, i, 1]) - 0.5) * 60.0)
				var L := 16.0 + rand([fr, i, 2]) * 50.0
				var x := (rand([fr, i, 4]) - 0.5) * 190.0
				pline(maxf(-100.0, x - L / 2.0), y, minf(100.0, x + L / 2.0), y, [C[4], C[6], Color.WHITE], {"t": [0.35, 0.75], "le": true, "rev": rev, "al": [0.25, 0.6, 0.0, 1.0, 0.0]})
		# the slam
		lay = "slam"
		var hk := t - HIT
		if hk >= 0.0 and hk < 0.07:
			var cx: float = X0 + (big.w * BS) / 2.0
			var kk := 1.0 if hk < 0.035 else 1.3
			for s in spikes:
				var ca: float = cos(s[0]) * 1.4
				var sa: float = sin(s[0])
				var L: float = s[1]
				if kk == 1.0:
					pbeam(cx, 0, cx + ca * L, sa * L, 3, [Color.WHITE, C[6]], 1.0, {"t": [0.5, 2.0]})
				else:
					pline(cx + ca * L * 0.5, sa * L * 0.5, cx + ca * L * kk, sa * L * kk, C[5])
		var rk := (t - HIT) / 0.32
		if rk > 0.0 and rk < 1.0:
			var r := 20.0 + 34.0 * out_cubic(rk)
			poval(sx, sy, r * 1.5, r * 0.75, Color.WHITE if rk < 0.3 else C[5], 1.0 - 1.5 / (r * 0.75), 1.25 - rk)
		lay = "ps"
		sim_draw(ps)
		# the words
		var x: float = x_at.call(t)
		var moving := t < HIT or t > OUT + 0.06
		var stretch := (1.22 if t < HIT else 1.12) if moving else 1.0
		var pulse := exp(-pow((t - BEAT) / 0.05, 2.0))
		var flash := 1.0 if ((t >= HIT and t < HIT + 0.07) or pulse > 0.6) else 0.0
		var a := 1.0 - seg(t, OUT + 0.08, OUT + 0.2) if t > OUT else (0.5 if t < 0.035 else 1.0)
		for j in 2:
			var lag: float = [0.03, 0.015][j]
			if moving and a > 0.0:
				word_at(after[j], layout.call(float(x_at.call(t - (lag if t < HIT else -lag))) + sx, stretch, pulse, 0.0, a, 0.0))
			else:
				word_at(after[j], [])
		lay = "top"
		if a > 0.0:
			var sh := seg(t, 0.62, 0.86)
			var shine: Variant = X0 - 10.0 + (WW + 24.0) * sh if (sh > 0.0 and sh < 1.0) else null
			word_at(main, layout.call(x + sx, stretch, pulse, flash, a, sy), shine, BASE - 28.0)
			var bk := seg(t, HIT + 0.1, HIT + 0.2) * (0.0 if t > OUT else 1.0)
			if bk > 0.0:
				var bw := WW * bk
				var left := 1.0 - seg(t, HIT + 0.2, OUT)
				var bx := X0 + x + sx
				var by := BASE + 5.0 + sy
				prect(bx - 1.0, by - 1.0, bw + 2.0, 4.0, C[0])
				prect(bx, by, bw, 2.0, C[1])
				if left > 0.0:
					prect(bx, by, bw * left, 2.0, C[5])
					prect(bx, by, bw * left, 1.0, C[6])
					pdot(bx + bw * left - 1.0, by, Color.WHITE)
		else:
			word_at(main, [])
		pglow(sx - 20.0, 0, 60, C[4], 0.2 * a + (0.5 * (1.0 - (t - HIT) / 0.15) if (t >= HIT and t < HIT + 0.15) else 0.0) + 0.25 * pulse)
		var g := (t - 0.86) / 0.22
		if g > 0.0 and g < 1.0:
			psparkle(X0 + WW - 2.0, BASE - 14.0, 6.0 * sin(g * PI), C[7], C[5], 0.5)
		lights_draw(lights)

	run(upd, drw)
	utable("SpeedLines", "lines", {"parent": glines})
	utable("Slam", "slam", {"parent": gfx})
	utable("Particles", "ps", {"parent": gps})
	utable("Timer", "top", {"parent": gtop})
	light_table()
	flush_keys()
