# reimagined-from: src/fx/ui/countdown.js@6cb827c32e483e0d1eb69e428d59f48c0a43e64c
# Countdown: 3, 2, 1 slam into a timer ring that drains like a burning fuse, throwing sparks; then GO! bursts out as the ring blows into a shockwave with rays.
# one-shot, 3.10 s, 152x136 canvas, origin [76, 68], backdrop dark
# ramp palette: #0a1030 #142a66 #1f4fae #2f86e6 #5cc4ff #a8e8ff #e6fbff #ffffff
# ramp go: #0b2410 #16501c #22882a #3cc23a #7ee84c #c4ff8a #f0ffd6 #ffffff
# The timer's socket and its burning fuse are a canvas shader (fx/ui/_timer.gdshader) keyed every frame from the
# original's beat; the digits and GO! are the drawWord shader (fx/ui/_word.gdshader), their spring, flash, throb and
# shine keyed every frame. The dial's turning dots and ticks, the shock rings, the rays and the sparks, cinders and
# stars (both of the original's particle systems replayed at its 120 Hz steps) are frame-table particles (_ui.gd);
# every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const STEP := 0.62
const RR := 30.0
const TOP := -PI / 2.0


func make() -> void:
	var W := Color.WHITE
	var G: PackedColorArray = root.ramps.go
	var seed_: int = int(meta.options.seed)
	var Rg := JsRng.new(seed_)
	var n := clampi(int(roundf(float(meta.options.from))), 1, 3)
	var ps := sim_new(Rg, [C[7], C[6], C[5], C[3]])
	var gs := sim_new(Rg, [G[7], G[6], G[5], G[3]])
	var lights := lights_new()
	var GO := n * STEP
	var OUT := GO + 0.78
	var end: float = D - 0.05
	var digits := []
	for i in n:
		digits.append(spell(str(n - i)))
	var wd := spell(String(meta.options.word))
	var rays := []
	for i in 18:
		var a := (i / 18.0) * TAU + Rg.range(-0.06, 0.06)
		rays.append({"a": a, "L": Rg.range(10, 16) if i % 2 else Rg.range(22, 30)})
	var size_at := func(u: float, base: float, bg: float) -> float: return base + bg * exp(-u * 26.0) * cos(u * 38.0)
	var reach := func(v: float, d: float) -> float: return 9.0 if v <= d * 2.2 else -log(1.0 - (d * 2.2) / v) / 2.2
	var st := {"beat": -1, "went": false, "popped": false}
	var cr := canvas_rect()
	var gpre := group("Rings")
	var dial := shape("Dial", ush("timer"), cr.size, {"C": C, "part": 0}, {"at": cr.get_center()})
	var gmarks := group("DialMarks")
	var fuse := shape("Fuse", ush("timer"), cr.size, {"C": C, "part": 1}, {"at": cr.get_center()})
	var gmid := group("Flash")
	var dw := []
	for i in n:
		var gl: Array = glyphs_of(digits[i]).map(func(L: Dictionary) -> Dictionary: return L.g)
		dw.append(word("Digit%d" % (n - i), gl, "big", {"fill": [C[4], C[5], C[6], C[7]], "edge": W, "under": C[3], "outline": C[0], "ow": 2,
			"shadow": scalec(C[0], 0.5)}))
	var wl := glyphs_of(wd)
	var gow := word("Go", wl.map(func(L: Dictionary) -> Dictionary: return L.g), "big", {"fill": [G[4], G[5], G[6], G[7]], "edge": W, "under": G[3],
		"outline": G[0], "ow": 2, "shadow": scalec(G[0], 0.5), "glint": G[6]})
	var gpost := group("PopRing")
	var gps := group("Particles")

	var upd := func(dt: float) -> void:
		var t := T
		var i := int(floorf(t / STEP))
		if t < GO and i != st.beat:
			st.beat = i
			lights_add(lights, 0, 0, 54, C[5], 0.6, 0.35)
			for j in 14:
				var an := (j / 14.0) * TAU + Rg.range(-0.1, 0.1)
				var sp := Rg.range(90, 200)
				spawn(ps, SPARK, cos(an) * (RR + 2.0), sin(an) * (RR + 2.0), cos(an) * sp, sin(an) * sp, minf(Rg.range(0.12, 0.3), reach.call(sp, 26.0)))
		if t < GO:
			var k := fmod(t, STEP) / STEP
			var f := 1.0 - seg(k, 0.06, 0.97)
			var head := TOP + TAU * (1.0 - f)
			if f > 0.01 and f < 0.99 and Rg.chance(0.7):
				var hx := cos(head) * RR
				var hy := sin(head) * RR
				var tx := -sin(head)
				var ty := cos(head)
				var out := Rg.range(-0.4, 1)
				var sp := Rg.range(60, 150)
				spawn(ps, SPARK, hx, hy, (-tx * 0.8 + cos(head) * out) * sp, (-ty * 0.8 + sin(head) * out) * sp - 20.0, Rg.range(0.12, 0.28))
				if Rg.chance(0.15):
					spawn(ps, EMBER, hx, hy, cos(head) * Rg.range(5, 20), sin(head) * Rg.range(5, 20), Rg.range(0.4, 0.8), C[5], 1)
		if not st.went and t >= GO:
			st.went = true
			lights_add(lights, 0, 0, 70, W, 0.9, 0.18)
			lights_add(lights, 0, 0, 64, G[5], 0.7, 0.8)
			for j in 36:
				var an := Rg.range(0, TAU)
				var sp := Rg.range(120, 300)
				spawn(gs, SPARK, cos(an) * RR, sin(an) * RR, cos(an) * sp, sin(an) * sp - 40.0, minf(Rg.range(0.18, 0.36), reach.call(sp, 24.0)))
			for j in 18:
				var an := Rg.range(0, TAU)
				var sp := Rg.range(30, 80)
				var r := Rg.range(10, 28)
				spawn(gs, STAR, cos(an) * r, sin(an) * r, cos(an) * sp, sin(an) * sp - 10.0, Rg.range(0.5, 1), Rg.pick([G[7], G[6], G[5]]), Rg.range(1.5, 2.5) if Rg.chance(0.4) else 0.6)
		if t > GO + 0.2 and t < OUT - 0.1 and Rg.chance(0.12):
			var an := Rg.range(0, TAU)
			var r := Rg.range(30, 46)
			spawn(gs, STAR, cos(an) * r, sin(an) * r * 0.8, 0, -Rg.range(4, 12), Rg.range(0.3, 0.6), Rg.pick([G[7], G[6]]), 1.6 if Rg.chance(0.3) else 0.6)
		if not st.popped and t >= OUT + 0.05:
			st.popped = true
			lights_add(lights, 0, 0, 40, G[6], 0.6, 0.25)
			for j in 14:
				var an := (j / 14.0) * TAU + Rg.range(-0.15, 0.15)
				var sp := Rg.range(60, 130)
				spawn(gs, STAR, cos(an) * 12, sin(an) * 8, cos(an) * sp, sin(an) * sp * 0.8 - 10.0, minf(Rg.range(0.3, 0.45), end - t), Rg.pick([G[7], G[6], G[5]]), 0.6 if j % 3 else Rg.range(1.3, 2))
		sim_update(ps, dt)
		sim_update(gs, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var dial_on := false
		var fuse_on := false
		var shown := -1
		if t < GO:
			var i := int(floorf(t / STEP))
			var u := t - i * STEP
			var k := u / STEP
			var sh2 := shake(t, 3, i * STEP, 0.22, seed_ + i)
			var sx: float = sh2[0]
			var sy: float = sh2[1]
			var f := 1.0 - seg(k, 0.06, 0.97)
			var flash := u < 0.07
			lay = "pre"
			var rk := u / 0.3
			if rk < 1.0:
				pring(sx, sy, RR + 6.0 + 22.0 * out_cubic(rk), 1.5 * (1.0 - rk) + 1.0, W if rk < 0.3 else C[5], 1.3 * (1.0 - rk))
			# timer()
			dial_on = true
			fk(dial, "material:shader_parameter/at", Vector2(sx, sy))
			lay = "marks"
			for j in 40:
				var an := (j / 40.0) * TAU + t * 0.6
				pdot(sx + cos(an) * (RR - 6.0), sy + sin(an) * (RR - 6.0), C[2] if j % 5 else C[4], 1.0)
			var head := TOP + TAU * (1.0 - f)
			for j in 12:
				var an := TOP + (j * TAU) / 12.0
				var lit := an >= head - 1e-6 or f >= 0.999
				var near := absf(an - head) < 0.2 and f < 0.999
				var ca := cos(an)
				var sa := sin(an)
				pline(sx + ca * (RR + 6.0), sy + sa * (RR + 6.0), sx + ca * (RR + 8.0), sy + sa * (RR + 8.0), W if (flash or near) else (C[5] if lit else C[2]))
			lay = "mid"
			if f > 0.002:
				fuse_on = true
				fk(fuse, "material:shader_parameter/at", Vector2(sx, sy))
				fk(fuse, "material:shader_parameter/head", head)
				fk(fuse, "material:shader_parameter/f", f)
				fk(fuse, "material:shader_parameter/flash", flash)
				var an := head + 0.25
				while an < TOP + TAU:
					pglow(sx + cos(an) * (RR - 0.5), sy + sin(an) * (RR - 0.5), 9, C[4], 0.12)
					an += 0.55
				var hx := sx + cos(head) * (RR - 0.5)
				var hy := sy + sin(head) * (RR - 0.5)
				pglow(hx, hy, 14, C[5], 0.5)
				if not flash:
					psparkle(hx, hy, 2.0 + 1.5 * (0.5 + 0.5 * sin(t * 40.0)), C[6], C[5], 0.4)
			if u < 0.035:
				pcircle(sx, sy, RR - 3.0, W)
			elif u < 0.07:
				pring(sx, sy, RR - 3.0, 3, C[6])
			var s: float = size_at.call(u, 5.0, 2.0)
			var dg: Dictionary = digits[i]
			var ww: float = dg.w * s
			var x0 := sx - ww / 2.0
			var y0 := sy - 7.0 * s / 2.0
			var items := []
			for L in glyphs_of(dg):
				items.append({"x": x0 + L.x * s, "y": y0, "sx": s, "sy": s, "flash": 1.0 if u < 0.035 else (0.4 if u < 0.07 else 0.0)})
			shown = i
			word_at(dw[i], items)
			pglow(sx, sy, 30, C[4], 0.22 + (0.6 * (1.0 - u / 0.12) if u < 0.12 else 0.0))
			pglow(sx, sy, RR + 8.0, C[3], 0.2 * (1.0 - k) + 0.08)
			word_at(gow, [])
		else:
			var u := t - GO
			var sh2 := shake(t, 4, GO, 0.3, seed_ + 9)
			var sx: float = sh2[0]
			var sy: float = sh2[1]
			lay = "pre"
			var bk := u / 0.4
			if bk < 1.0:
				var r := RR + 4.0 + 30.0 * out_cubic(bk)
				var w := maxf(1.0, 7.0 * (1.0 - bk))
				pring(0, 0, r, w, W if bk < 0.2 else [G[6], G[6], W], 1.4 * (1.0 - bk), {"t": [0.6, 0.6], "le": true})
				pglow_ring(0, 0, r - w / 2.0, 8, G[5], 0.5 * (1.0 - bk))
			var ik := (u - 0.05) / 0.3
			if ik > 0.0 and ik < 1.0:
				pring(0, 0, RR + 22.0 * out_cubic(ik), 1, G[5], 1.2 * (1.0 - ik))
			var rk := out_expo(clampf(u / 0.18, 0.0, 1.0)) * (1.0 - in_quad(seg(t, OUT - 0.25, OUT + 0.05)))
			for ry in rays:
				if rk <= 0.02:
					break
				var an: float = ry.a + u * 0.35
				var ca := cos(an)
				var sa := sin(an)
				var r0 := 1.0 / sqrt(pow(ca / 40.0, 2.0) + pow(sa / 23.0, 2.0)) + 3.0 * rk
				var r1: float = r0 + ry.L * 0.7 * rk
				pline(ca * r0, sa * r0, ca * r1, sa * r1, [W, G[6], G[5]], {"t": [0.3, 0.65], "al": [0.6, 1.3, 0.0, 3.25, -3.25]})
			var pu := (t - OUT) / 0.06
			lay = "post"
			if pu < 1.0:
				var s: float = size_at.call(u, 5.0, 3.5)
				var flash := 1.0 if u < 0.035 else (0.4 if u < 0.07 else 0.0)
				var throb := maxf(0.0, sin((u - 0.25) * 9.0)) * smooth(0.25, 0.35, u)
				if pu > 0.0:
					s = 5.0 * (1.0 + 0.25 * pu)
					flash = 1.0
				var ww: float = wd.w * s
				var x0 := sx - ww / 2.0
				var y0 := sy - 7.0 * s / 2.0
				var items := []
				for L in wl:
					items.append({"x": x0 + L.x * s, "y": y0, "sx": s, "sy": s, "slant": 1.0, "flash": flash})
				var sh := seg(u, 0.32, 0.56)
				var shine: Variant = x0 - 8.0 + (ww + 22.0) * in_out_sine(sh) if (sh > 0.0 and sh < 1.0) else null
				word_at(gow, items, shine, y0)
				pglow(sx, sy, 46, G[5], 0.25 + 0.15 * throb + (0.7 * (1.0 - u / 0.12) if u < 0.12 else 0.0))
			else:
				word_at(gow, [])
				var k := (t - OUT - 0.06) / 0.22
				if k > 0.0 and k < 1.0:
					pring(0, 0, 8.0 + 26.0 * out_cubic(k), 1, W if k < 0.4 else G[6], 1.3 * (1.0 - k))
		for j in n:
			if j != shown:
				word_at(dw[j], [])
		fk(dial, "material:shader_parameter/on", dial_on)
		fk(fuse, "material:shader_parameter/on", fuse_on)
		lay = "ps"
		sim_draw(ps)
		sim_draw(gs)
		lights_draw(lights)

	run(upd, drw)
	utable("Rings", "pre", {"parent": gpre})
	utable("DialMarks", "marks", {"parent": gmarks})
	utable("Flash", "mid", {"parent": gmid})
	utable("PopRing", "post", {"parent": gpost})
	utable("Particles", "ps", {"parent": gps})
	light_table()
	flush_keys()
