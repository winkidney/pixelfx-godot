# reimagined-from: src/fx/ui/crit-number.js@4c6978bf8a288cb492c58d0680ace623d9d8d567
# Crit number: CRIT 128! slams in huge and white over a jagged starburst with a hard shake and speed lines, cools to fire, holds with a shine, then pops into sparks.
# one-shot, 1.50 s, 152x120 canvas, origin [76, 60], backdrop dark
# ramp palette: #2a0710 #5e0f16 #a3191c #e0401c #ff7b22 #ffb93b #ffe68a #ffffff
# The starburst and the CRIT tag are canvas shaders (fx/ui/_starburst.gdshader, _tag.gdshader: the original's own
# pixel rules), keyed every frame (the burst's boil re-rolls its spikes with the original's hash); 128! and CRIT are
# the drawWord shader (fx/ui/_word.gdshader), their spring, squash, flash and shine keyed every frame. The speed
# lines, rings, sparks, shards, embers and stars (the original's simulation replayed at 120 Hz) and the glint are
# frame-table particles (_ui.gd); every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const FOLD := 0.92
const TAGOUT := 0.98
const POP := 1.06
const SX := 1.3
const NS := 4.0
const NY := 5.0


func make() -> void:
	var W := Color.WHITE
	var seed_: int = int(meta.options.seed)
	var R := JsRng.new(seed_)
	var shadow := scalec(C[0], 0.5)
	var ps := sim_new(R, [C[7], C[6], C[5], C[3]])
	var bits := bits_new()
	var lights := lights_new()
	var num := spell(String(meta.options.text))
	var lab := spell(String(meta.options.label), "mini")
	var tips := []
	for i in 13:
		var ln := R.range(0.86, 1.12)
		tips.append({"len": ln, "dip": R.range(-0.06, 0.06)})
	var lines := []
	for i in 18:
		var a := (i / 18.0) * TAU + R.range(-0.1, 0.1)
		var r := R.range(31, 34)
		lines.append({"a": a, "r": r, "len": R.range(8, 15)})
	var reach := func(v: float, d: float) -> float: return 9.0 if v <= d * 2.2 else -log(1.0 - (d * 2.2) / v) / 2.2
	var end: float = D - 0.05
	var st := {"slammed": false, "stamped": false, "popped": false, "tag_gone": false}
	var size_at := func(t: float) -> float: return NS + 3.0 * exp(-t * 26.0) * cos(t * 38.0)
	var cr := canvas_rect()
	var burst := shape("Burst", ush("starburst"), cr.size, {"C": C}, {"at": cr.get_center()})
	var ga := group("Sparks")
	var nl := glyphs_of(num)
	var wn := word("Number", nl.map(func(L: Dictionary) -> Dictionary: return L.g), "big", {"fill": [C[5], C[6], C[6], C[7]], "edge": W, "under": C[4],
		"outline": C[0], "ow": 2, "shadow": shadow, "glint": C[5]})
	var tag := shape("Tag", ush("tag"), cr.size, {"C": C}, {"at": cr.get_center()})
	var ll := glyphs_of(lab)
	var wl := word("Label", ll.map(func(L: Dictionary) -> Dictionary: return L.g), "mini", {"fill": [C[6], C[7], C[7]], "edge": W, "under": C[5], "shadow": C[1]})
	var gc := group("Glint")

	var upd := func(dt: float) -> void:
		var t := T
		if not st.slammed:
			st.slammed = true
			lights_add(lights, 0, 0, 70, W, 0.9, 0.16)
			lights_add(lights, 0, 0, 60, C[4], 0.45, 0.5)
			for i in 30:
				var an := R.range(0, TAU)
				var sp := R.range(140, 300)
				spawn(ps, SPARK, cos(an) * 8, sin(an) * 6, cos(an) * sp * 1.15, sin(an) * sp - 40.0, minf(R.range(0.12, 0.32), reach.call(sp * 1.15, 40.0)))
			for i in 10:
				var an := R.range(0, TAU)
				var sp := R.range(90, 170)
				var o := {"kind": 0, "x": cos(an) * 10, "y": sin(an) * 7, "vx": cos(an) * sp * 1.15, "vy": sin(an) * sp - 60.0, "g": 0.35, "drag": 1.6}
				o.life = minf(R.range(0.3, 0.5), end - t)
				o.a = R.range(0, TAU)
				o.va = R.range(-24, 24)
				o.s = R.range(2, 3.5)
				o.c = R.pick([C[7], C[6], C[5]])
				bits_add(bits, o)
		if not st.stamped and t >= 0.09:
			st.stamped = true
			lights_add(lights, -4, -20, 30, C[6], 0.5, 0.2)
			for i in 6:
				spawn(ps, STAR, -4.0 + R.range(-16, 16), -20.0 + R.range(-4, 4), R.range(-40, 40), R.range(-30, 10), R.range(0.2, 0.4), C[6], R.range(0.5, 1.4))
		if not st.tag_gone and t >= TAGOUT:
			st.tag_gone = true
			for i in 6:
				spawn(ps, STAR, -10.0 + R.range(-16, 16), -14.0 + R.range(-5, 5), R.range(-50, 50), -R.range(10, 60), minf(R.range(0.25, 0.4), end - t), R.pick([C[7], C[6]]), 0.6 if i else 1.6)
		if t > 0.3 and t < FOLD - 0.1 and R.chance(0.07):
			var an := R.range(0, TAU)
			var sp := R.range(70, 150)
			spawn(ps, SPARK, cos(an) * 30 * SX, sin(an) * 30, cos(an) * sp, sin(an) * sp - 30.0, minf(R.range(0.12, 0.26), reach.call(sp, 14.0)))
		if t > 0.12 and t < FOLD and R.chance(0.16):
			var an := R.range(0, TAU)
			var r := R.range(14, 28)
			spawn(ps, EMBER, cos(an) * r * SX, sin(an) * r, R.range(-10, 10), -R.range(15, 40), minf(R.range(0.5, 0.9), end - t), C[5], R.range(1, 2))
		if not st.popped and t >= POP + 0.05:
			st.popped = true
			lights_add(lights, 0, 0, 44, C[6], 0.7, 0.25)
			for i in 14:
				var an := (i / 14.0) * TAU + R.range(-0.15, 0.15)
				var sp := R.range(60, 130)
				spawn(ps, STAR, cos(an) * 10 * SX, sin(an) * 7, cos(an) * sp * SX, sin(an) * sp - 10.0, minf(R.range(0.3, 0.42), end - t), R.pick([C[7], C[6], C[5]]), 0.6 if i % 3 else R.range(1.3, 2.2))
			for i in 8:
				var an := R.range(0, TAU)
				var sp := R.range(120, 240)
				spawn(ps, SPARK, cos(an) * 6, sin(an) * 4, cos(an) * sp, sin(an) * sp - 30.0, minf(minf(R.range(0.15, 0.3), end - t), reach.call(sp, 40.0)))
		sim_update(ps, dt)
		bits_update(bits, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var s1 := shake(t, 4, 0, 0.32, seed_)
		var s2 := shake(t, 2, 0.09, 0.15, seed_ + 3)
		var sx: float = s1[0]
		var sy: float = s1[1]
		var lx: float = s2[0]
		var ly: float = s2[1]
		var grow := 1.25 if t < 0.04 else 1.0 + 0.1 * exp(-(t - 0.04) * 14.0)
		var fold := 1.0 - in_back(seg(t, FOLD - 0.12, FOLD), 2.4)
		var heat := 1.0 if t < 0.035 else clampf(1.0 - (t - 0.035) / 0.12, 0.0, 1.0)
		var breathe := 1.0 + 0.04 * sin(t * 16.0)
		var bR := 31.0 * grow * fold * breathe
		var on := fold > 0.02 and bR >= 2.0
		fk(burst, "material:shader_parameter/on", on)
		if on:
			var boil := 0.0 if t < 0.2 else floorf(t * 10.0)
			var vr := PackedFloat32Array()
			for i in 26:
				var tp: Dictionary = tips[i >> 1]
				vr.append(bR * (0.6 + tp.dip) if i % 2 else bR * tp.len * (1.0 + 0.14 * (rand([boil, i]) - 0.5)))
			fk(burst, "material:shader_parameter/at", Vector2(sx, sy))
			fk(burst, "material:shader_parameter/R", bR)
			fk(burst, "material:shader_parameter/rot", -PI / 2.0 + 0.25 * t)
			fk(burst, "material:shader_parameter/heat", heat)
			fk(burst, "material:shader_parameter/vr", vr)
		lay = "a"
		var k := t / 0.24
		if k > 0.0 and k < 1.0:
			for l in lines:
				var r0: float = l.r * (1.0 + 0.5 * out_expo(k))
				var r1: float = r0 + l.len * (1.0 - k) + 2.0
				var ca: float = cos(l.a) * 1.2
				var sa: float = sin(l.a) * 0.92
				pline(ca * r0, sa * r0, ca * r1, sa * r1, W if k < 0.3 else [C[6], C[6], W], {"t": [0.5, 0.5], "le": true})
		var rk := t / 0.26
		var rr := 30.0 + 22.0 * out_cubic(rk)
		if rk > 0.0 and rk < 1.0:
			poval(0, 0, rr * SX, rr, W if rk < 0.35 else C[6], 1.0 - 1.6 / rr, 1.2 - rk)
		bits_draw(bits)
		sim_draw(ps)
		var s: float = size_at.call(t)
		var sxN := s
		var syN := s
		var flash := 1.0 if t < 0.035 else (0.5 if t < 0.07 else 0.0)
		var pu := (t - POP) / 0.05
		var tag_on := false
		var lab_items := []
		var num_items := []
		var shine: Variant = null
		var y0 := 0.0
		if pu >= 1.0:
			var kk := (t - POP - 0.05) / 0.22
			if kk > 0.0 and kk < 1.0:
				var q := 6.0 + 22.0 * out_cubic(kk)
				poval(0, 0, q * SX, q, W if kk < 0.4 else C[6], 1.0 - 1.5 / q, 1.3 - kk)
		else:
			var sq := seg(t, POP - 0.07, POP)
			if sq > 0.0 and pu <= 0.0:
				sxN = NS * (1.0 + 0.14 * sq)
				syN = NS * (1.0 - 0.12 * sq)
			if pu > 0.0:
				sxN = NS * (1.0 + 0.25 * pu)
				syN = sxN
				flash = 1.0
			var ww: float = num.w * sxN
			var H := 7.0 * syN
			var x0 := sx - ww / 2.0 - 3.0
			y0 = sy + NY - H / 2.0 - 3.0 * smooth(0.15, FOLD, t)
			for L in nl:
				num_items.append({"x": x0 + L.x * sxN, "y": y0, "sx": sxN, "sy": syN, "slant": 1.0, "flash": flash})
			var sh := seg(t, 0.36, 0.6)
			if sh > 0.0 and sh < 1.0:
				shine = x0 - 10.0 + (ww + 26.0) * in_out_sine(sh)
			if shine != null and shine > x0 and shine < x0 + ww:
				pglow_line(shine, y0, shine + 0.6 * H, y0 + H, 8, C[6], 0.3)
			var lk := t - 0.06
			var lo := seg(t, TAGOUT - 0.05, TAGOUT)
			if lk > 0.0 and t < TAGOUT:
				var ls := 3.0 if lk < 0.035 else (1.8 if lk < 0.07 else 2.0 * (1.0 + 0.15 * lo))
				var LW: float = lab.w * ls
				var lh := 5.0 * ls
				var lxo := sx + lx - 8.0 - LW / 2.0
				var lyo := y0 - 3.0 - lh + ly - 2.0 * lo
				tag_on = true
				fk(tag, "material:shader_parameter/rc", Vector4(lxo - 4.0, lyo - 3.0, LW + 8.0, lh + 5.0))
				fk(tag, "material:shader_parameter/white", lo > 0.5)
				for L in ll:
					lab_items.append({"x": lxo + 1.0 + L.x * ls, "y": lyo, "sx": ls, "sy": ls, "slant": 0.5, "flash": 1.0 if lk < 0.035 else 0.0})
			lay = "c"
			var g := (t - 0.6) / 0.24
			if g > 0.0 and g < 1.0:
				psparkle(x0 + ww - 2.0, y0 + 1.0, 6.0 * sin(g * PI), C[6], C[5], 0.6)
		word_at(wn, num_items, shine, y0)
		fk(tag, "material:shader_parameter/on", tag_on)
		word_at(wl, lab_items)
		var hold := smooth(0, 0.1, t) * (1.0 - smooth(FOLD - 0.1, POP + 0.1, t))
		pglow(sx, sy, 56, C[4], 0.14 * hold * (1.0 + 0.2 * sin(t * 16.0)))
		if t < 0.12:
			pglow(0, 0, 64, W, 0.8 * (1.0 - t / 0.12))
		lights_draw(lights)

	run(upd, drw)
	utable("Sparks", "a", {"parent": ga})
	utable("Glint", "c", {"parent": gc})
	light_table()
	flush_keys()
