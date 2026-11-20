# reimagined-from: src/fx/ui/quest-complete.js@7d83738756ff4ee17a7d4e80e9fd28fff9246e41
# Quest complete: A stitched ribbon unrolls from the middle, QUEST COMPLETE types on letter by letter, a gold seal stamps down and ticks, stars pop; then it all rolls away.
# one-shot, 2.60 s, 204x92 canvas, origin [102, 46], backdrop dark
# ramp palette: #2a1405 #5c3008 #9a5a0e #d48e18 #f5b92c #ffde5e #fff4bc #ffffff
# ramp ribbon: #1e0608 #45101a #7a1a26 #ad2632 #d8433f #f27a5e #ffb79a
# The ribbon and the seal are canvas shaders (fx/ui/_ribbon.gdshader, _seal.gdshader: the original's own pixel rules)
# keyed every frame from its unroll, stamp and squash; the title is the drawWord shader (fx/ui/_word.gdshader), each
# letter typed on, popped white and clipped as the original does it. The shine, the seal's shadow, its check mark
# (beams), the ring, the sparkles and the stars (the original's simulation replayed at 120 Hz) are frame-table
# particles (_ui.gd); every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const L := 66.0
const BH := 8.0
const OPEN := 0.32
const TYPE := 0.2
const STEP_ := 0.036
const STAMP := 0.95
const SX := 64.0
const SY := 4.0
const POPSEAL := 2.0
const ROLL := 2.08


func make() -> void:
	var W := Color.WHITE
	var G := C
	var Rb: PackedColorArray = root.ramps.ribbon
	var seed_: int = int(meta.options.seed)
	var R := JsRng.new(seed_)
	var ps := sim_new(R, [G[7], G[6], G[5], G[3]])
	var lights := lights_new()
	var wd := spell(String(meta.options.text), "mini")
	var TS := 2.0
	var TW: float = wd.w * TS
	var TX := -TW / 2.0 - 4.0
	var TY := -5.0
	var gl := glyphs_of(wd)
	var sats := []
	for i in 7:
		var s := {"x": (i / 6.0 - 0.5) * 140.0 + R.range(-6, 6)}
		s.y = (1.0 if i % 2 else -1.0) * R.range(15, 22)
		s.t0 = STAMP + 0.12 + i * 0.12 + R.range(0, 0.04)
		s.dur = R.range(0.3, 0.45)
		s.L = R.range(3, 6)
		sats.append(s)
	var st := {"stamped": false, "popped": false}
	var end: float = D - 0.05
	var cr := canvas_rect()
	var rib := shape("Ribbon", ush("ribbon"), cr.size, {"Rb": Rb, "stitch": G[3]}, {"at": cr.get_center()})
	var gshine := group("Shine")
	var wt := word("Title", gl.map(func(Lt: Dictionary) -> Dictionary: return Lt.g), "mini", {"fill": [G[4], G[5], G[6], G[7]], "edge": W, "under": G[3],
		"outline": Rb[0], "shadow": Rb[1]})
	var gshadow := group("SealShadow")
	var seal := shape("Seal", ush("seal"), cr.size, {"G": G}, {"at": cr.get_center()})
	var gpost := group("Stars")

	var upd := func(dt: float) -> void:
		var t := T
		if not st.stamped and t >= STAMP:
			st.stamped = true
			lights_add(lights, SX, SY, 40, G[5], 0.7, 0.35)
			lights_add(lights, SX, SY, 18, W, 0.7, 0.1)
			for i in 12:
				var an := (i / 12.0) * TAU + R.range(-0.2, 0.2)
				var sp := R.range(40, 80) * (0.6 if cos(an) > 0.0 else 1.0)
				spawn(ps, STAR, SX + cos(an) * 11, SY + sin(an) * 11, cos(an) * sp, sin(an) * sp * 0.7, R.range(0.25, 0.45), R.pick([G[7], G[6], G[5]]), 0.6 if i % 3 else R.range(1.2, 1.8))
		if t > STAMP and t < POPSEAL and R.chance(0.08):
			spawn(ps, STAR, R.range(-L, L), R.range(-BH, BH), R.range(-5, 5), -R.range(8, 20), minf(R.range(0.4, 0.8), end - t), R.pick([G[6], G[5]]), 0.6)
		if not st.popped and t >= POPSEAL + 0.05:
			st.popped = true
			lights_add(lights, SX, SY, 30, G[6], 0.6, 0.2)
			for i in 8:
				var an := R.range(0, TAU)
				var sp := R.range(40, 90)
				spawn(ps, STAR, SX + cos(an) * 6, SY + sin(an) * 6, cos(an) * sp, sin(an) * sp, minf(R.range(0.25, 0.4), end - t), R.pick([G[7], G[6]]), 0.6 if i % 2 else 1.5)
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		var sh2 := shake(t, 2, STAMP, 0.18, seed_)
		var jx: float = sh2[0]
		var jy: float = sh2[1]
		var l := L * (out_cubic(seg(t, 0, OPEN)) if t < ROLL else 1.0 - in_cubic(seg(t, ROLL, ROLL + 0.26)))
		var tails := seg(t, OPEN - 0.02, OPEN + 0.12) * (1.0 if t < ROLL else 0.0)
		var sh := seg(t, 1.2, 1.5)
		fk(rib, "material:shader_parameter/l", l)
		fk(rib, "material:shader_parameter/tails", out_back(tails, 2))
		lay = "shine"
		if sh > 0.0 and sh < 1.0 and l >= 1.0:
			var shine := -L - 10.0 + (2.0 * L + 20.0) * sh
			for y in range(int(-BH + 1.0), int(BH)):
				var x := shine + (y + BH) * 0.6
				if absf(x) < l - 2.0:
					pdot(x, y, Rb[6])
					pdot(x + 1.0, y, Rb[5])
		var items := []
		for i in gl.size():
			var Lt: Dictionary = gl[i]
			var u := t - (TYPE + i * STEP_)
			var x: float = TX + Lt.x * TS + jx
			if u < 0.0 or absf(x + Lt.w) > l - 3.0:
				items.append(null)
				continue
			var s := 2.6 if u < 0.035 else TS
			items.append({"x": x - ((s - TS) * Lt.w) / 2.0, "y": TY + jy - ((s - TS) * 5.0) / 2.0, "sx": s, "sy": s, "flash": 1.0 if u < 0.07 else 0.0})
		word_at(wt, items)
		var dk := seg(t, STAMP - 0.12, STAMP)
		var pk := t - POPSEAL
		var seal_on := false
		lay = "shadow"
		if dk > 0.0 and pk < 0.08:
			var fall := 1.0 - in_quad(dk)
			var sq := exp(-(t - STAMP) * 30.0) * (1.0 if t >= STAMP else 0.0)
			var s := 1.0 + 0.8 * fall
			var sx := s * (1.0 + 0.2 * sq)
			var sy := s * (1.0 - 0.2 * sq)
			if pk > 0.0:
				sx = 1.0 + 0.3 * (pk / 0.08)
				sy = sx
			var white := (t >= STAMP and t < STAMP + 0.05) or pk > 0.0
			if dk < 1.0:
				poval(SX, SY + 12.0, 10.0 * (1.0 - 0.3 * fall), 2, Rb[0], -1.0, 0.5 * dk)
			seal_on = true
			var x := SX + jx
			var y := SY - 14.0 * fall + jy
			fk(seal, "material:shader_parameter/at", Vector2(x, y))
			fk(seal, "material:shader_parameter/sc", Vector2(sx, sy))
			fk(seal, "material:shader_parameter/white", white)
			lay = "post"
			var k := seg(t, STAMP + 0.08, STAMP + 0.24)
			if not white and k > 0.0:
				var p0: Array = [x - 5.0 * sx, y + 0.0 * sy]
				var p1: Array = [x - 1.5 * sx, y + 3.5 * sy]
				var p2: Array = [x + 5.5 * sx, y - 4.5 * sy]
				var len1 := sqrt(pow(p1[0] - p0[0], 2.0) + pow(p1[1] - p0[1], 2.0))
				var len2 := sqrt(pow(p2[0] - p1[0], 2.0) + pow(p2[1] - p1[1], 2.0))
				var done := k * (len1 + len2)
				var segs := [[p0, p1, minf(1.0, done / len1)], [p1, p2, clampf((done - len1) / len2, 0.0, 1.0)]]
				for wc in [[4.2, G[0]], [2.4, W]]:
					for sg in segs:
						var a: Array = sg[0]
						var b: Array = sg[1]
						var u: float = sg[2]
						if u > 0.0:
							pbeam(a[0], a[1], a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, wc[0], wc[1])
			pglow(SX, SY, 22, G[5], 0.3 + (0.4 if white else 0.0))
		fk(seal, "material:shader_parameter/on", seal_on)
		lay = "post"
		var rk := (t - STAMP) / 0.3
		var rr := 12.0 + 13.0 * out_cubic(rk)
		if rk > 0.0 and rk < 1.0:
			poval(SX, SY, rr * 1.15, rr, W if rk < 0.3 else G[5], 1.0 - 1.4 / rr, 1.2 - rk)
		for s in sats:
			var u: float = (t - s.t0) / s.dur
			if u > 0.0 and u < 1.0:
				psparkle(s.x, s.y, s.L * pow(sin(u * PI), 0.7), G[6], G[5], 0.5)
		sim_draw(ps)
		pglow(0, 0, 76, G[4], 0.2 * seg(t, 0.2, 0.5) * (1.0 - seg(t, ROLL, ROLL + 0.2)))
		lights_draw(lights)

	run(upd, drw)
	utable("Shine", "shine", {"parent": gshine})
	utable("SealShadow", "shadow", {"parent": gshadow})
	utable("Stars", "post", {"parent": gpost})
	light_table()
	flush_keys()
