# reimagined-from: src/fx/transitions/slash-wipe.js@f8d811858b6a43e03eefddb36ea52799d4108406
# Slash wipe: A white-hot blade edge slices across the screen, light ahead of it and sparks spraying back over the cover; a second cut flashes through and the cover splits apart.
# one-shot, 1.70 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# One screen shader (fx/transitions/_slash.gdshader) draws the cover behind the sweeping blade edge with its cooling
# smear, the second cut's smear and trace, and the two halves of the cover slipping along the cut and flying apart
# with white-hot cut faces; the edge, the halves and the cut are keyed every frame from the original's curves (on its
# own clock), the cut's line and the halves' shapes rolled from its seed. Its light twin lights the edge, the faces and
# the seam. The sparks and shavings (bursts where the edge bites, the spray off the cut's end, the split) are the
# original's particles replayed from its generator (scifi ghosts); the sparkle at the cut's end and the light riding
# its head are frame-table particles (marks()); its flashes are Lights.
extends "res://build/fx/transitions/_transitions.gd"

const SL := 0.55
const T0 := 0.06
const SWEEP := 0.62
const CUT := 0.84
const CSW := 0.07
const CHOLD := 0.05
const CTRAIL := 0.12
const SLIP := CUT + 0.12
const SPLIT := CUT + CSW + CHOLD + CTRAIL

var E0 := -(SHH / 2.0) * SL - 4.0
var E1 := SW + (SHH / 2.0) * SL + 24.0


func edge_at(t: float) -> float:
	return E0 + (E1 - E0) * out_cubic(clampf((t - T0) / SWEEP, 0.0, 1.0))


func speed_at(t: float) -> float:
	return 0.0 if (t < T0 or t > T0 + SWEEP) else ((E1 - E0) * 3.0 * pow(1.0 - (t - T0) / SWEEP, 2.0)) / SWEEP


static func half_plane(pts: Array, cx: float, cy: float, nx: float, ny: float) -> Array:
	var out := []
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var sa := (a.x - cx) * nx + (a.y - cy) * ny
		var sb := (b.x - cx) * nx + (b.y - cy) * ny
		if sa >= 0.0:
			out.append(a)
		if (sa >= 0.0) != (sb >= 0.0):
			var k := sa / (sa - sb)
			out.append(Vector2(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k))
	return out


func make() -> void:
	var o: Dictionary = meta.options
	var R := JsRng.new(int(o.seed))
	var sparks := []
	for h in o.sparks:
		sparks.append(Color(h))
	var th := R.range(0.42, 0.56)
	var ux := cos(th)
	var uy := sin(th)
	var nx := uy
	var ny := -ux
	var cx := SW / 2.0 + R.range(-24, 24)
	var cy := SHH / 2.0 + R.range(-10, 10)
	var area := [Vector2(-24, -24), Vector2(SW + 24, -24), Vector2(SW + 24, SHH + 24), Vector2(-24, SHH + 24)]
	var ends := []
	for s in [-1.0, 1.0]:
		var lo := 0.0
		var hi := 400.0
		for k in 30:
			var m := (lo + hi) / 2.0
			var x: float = cx + s * ux * m
			var y: float = cy + s * uy * m
			if x >= 0.0 and x <= SW and y >= 0.0 and y <= SHH:
				lo = m
			else:
				hi = m
		ends.append(Vector2(cx + s * ux * lo, cy + s * uy * lo))
	var A: Vector2 = ends[0]
	var B: Vector2 = ends[1]
	var LC := A.distance_to(B)
	var halves := []
	for s in [1.0, -1.0]:
		var pts := half_plane(area, cx, cy, s * nx, s * ny)
		var mc := Vector2.ZERO
		for p in pts:
			mc += p / pts.size()
		halves.append({"s": s, "pts": pts, "m": mc, "spin": s * R.range(0.5, 0.9)})
	var end: float = D - 0.05

	var lights := []
	var st := {"acc": 0.0, "entered": false, "tipped": false, "split": false}
	ghosts_begin(0.0)
	var step := func(t: float, dt: float) -> void:
		var sp := speed_at(t)
		var e := edge_at(t)
		if not st.entered and t >= T0:
			st.entered = true
			lights.append([t, Vector2(4, 4), 60.0, C[5], 0.6, 0.25])
		st.acc += sp * dt * 0.035
		while st.acc > 1.0:
			var y := R.range(4, SHH - 4)
			var x := e + (SHH / 2.0 - y) * SL - 1.0
			var a0 := PI + R.range(-0.1, 0.6)
			var n := R.int_(5, 10)
			if x >= 0.0 and x < SW:
				for i in n:
					var a := a0 + R.range(-0.75, 0.75)
					var v := R.range(0.2, 1) * (140.0 + 0.22 * sp)
					var yy := y + R.range(-2, 2)
					spawn(R, t, SPARK, x, yy, cos(a) * v, sin(a) * v, R.range(0.15, 0.4))
					if R.chance(0.4):
						var life := R.range(0.2, 0.5)
						var col: Color = C[6] if R.chance(0.5) else C[5]
						spawn(R, t, MOTE, x, y, cos(a) * v * 0.45, sin(a) * v * 0.45 - 20.0, life, col, 0.7)
				lights.append([t, Vector2(x, y), R.range(30, 46), C[5], 0.35, 0.14])
			st.acc -= 1.0
		if not st.tipped and t >= CUT + CSW:
			st.tipped = true
			for i in 12:
				var a := atan2(uy, ux) + R.range(-0.5, 0.5)
				var v := R.range(150, 400)
				spawn(R, t, SPARK, B.x - ux * 2.0, B.y - uy * 2.0, cos(a) * v, sin(a) * v, R.range(0.12, 0.35))
			for i in 18:
				var k := R.range(0.1, 1)
				var x := A.x + (B.x - A.x) * k
				var y := A.y + (B.y - A.y) * k
				var s := R.sign()
				var v := R.range(30, 100)
				var life := R.range(0.25, 0.55)
				var col: Color = C[5] if R.chance(0.5) else C[4]
				spawn(R, t, MOTE, x, y, s * nx * v + ux * 20.0, s * ny * v - 10.0, life, col, 0.6)
			for i in 5:
				lights.append([t, A + (B - A) * (i + 0.5) / 5.0, 46.0, C[5], 0.45, 0.3])
		if not st.split and t >= SPLIT:
			st.split = true
			for i in 46:
				var k := R.range(0, 1)
				var x := A.x + (B.x - A.x) * k
				var y := A.y + (B.y - A.y) * k
				var s := R.sign()
				var v := R.range(80, 320)
				var a := atan2(s * ny, s * nx) + R.range(-0.7, 0.7)
				spawn(R, t, SPARK, x, y, cos(a) * v, sin(a) * v, minf(R.range(0.15, 0.45), end - t))
			for i in 6:
				lights.append([t, A + (B - A) * (i + 0.5) / 6.0, 56.0, C[5], 0.5, 0.35])
	var clocks := replay(step)

	# what each frame draws
	var ks := {}
	for nm in ["sw_on", "e", "sp", "h_on", "heat", "hp", "hc", "ha", "hb", "hm", "deep", "sep", "sm_on", "tr_on", "head", "tail", "age", "wc"]:
		ks[nm] = []
	var rows := []
	for i in NF:
		var t: float = clocks[i]
		var tt := i / 30.0
		var v := {}
		v.sw_on = 1.0 if (t < CUT + CSW + CHOLD + 0.02 or t < SLIP) else 0.0
		v.e = edge_at(t)
		v.sp = speed_at(t)
		v.h_on = 1.0 if t >= SLIP else 0.0
		v.heat = 1.0 - clampf((t - CUT - 0.05) / 0.5, 0.0, 1.0)
		var hp := PackedVector2Array()
		var hcv := Vector2.ZERO
		var hav := PackedVector2Array()
		var hbv := PackedVector2Array()
		var hmv := PackedVector2Array()
		var dpv := Vector2.ONE
		var spv := Vector2.ZERO
		for k in 2:
			var hf: Dictionary = halves[k]
			var slip := 5.0 * out_cubic(clampf((t - SLIP) / 0.12, 0.0, 1.0)) * (1.0 if hf.s > 0.0 else -0.4)
			var u := maxf(0.0, t - SPLIT)
			var sepv := 30.0 * u + 0.5 * 1500.0 * u * u
			var rot: float = hf.spin * u * u
			var dd := Vector2(ux * slip + hf.s * nx * sepv, uy * slip + hf.s * ny * sepv)
			var c := cos(rot)
			var sn := sin(rot)
			var mv := func(p: Vector2) -> Vector2:
				var l: Vector2 = p - hf.m
				return Vector2(hf.m.x + l.x * c - l.y * sn + dd.x, hf.m.y + l.x * sn + l.y * c + dd.y)
			var pts: Array = hf.pts
			for j in 6:
				hp.append(mv.call(pts[j]) if j < pts.size() else Vector2.ZERO)
			hcv[k] = pts.size()
			hav.append(mv.call(A))
			hbv.append(mv.call(B))
			hmv.append(Vector2(hf.s * (nx * c - ny * sn), hf.s * (nx * sn + ny * c)))
			dpv[k] = clampf(1.0 + sepv * 0.5, 1.0, 4.0)
			spv[k] = sepv
		v.hp = hp
		v.hc = hcv
		v.ha = hav
		v.hb = hbv
		v.hm = hmv
		v.deep = dpv
		v.sep = spv
		var u := t - CUT
		var cut_on := u >= 0.0 and u < CSW + CHOLD + CTRAIL + 0.25
		var head := LC * out_expo(clampf(u / CSW, 0.0, 1.0))
		var tail := LC * smooth(CSW + CHOLD, CSW + CHOLD + CTRAIL, u)
		v.head = head
		v.tail = tail
		v.age = clampf(u / (CSW + CHOLD + CTRAIL), 0.0, 1.0)
		v.wc = 3.6 * (1.0 - (tail / LC) * 0.55)
		v.sm_on = 1.0 if (cut_on and head - tail > 1.0 and tail < LC - 1.0 and t < SPLIT) else 0.0
		v.tr_on = 1.0 if (cut_on and tail > 2.0 and t < SPLIT) else 0.0
		for nm in ks:
			ks[nm].append([tt, v[nm]])
		var out := []
		if cut_on:
			if u < 0.3:
				var hx := A + Vector2(ux, uy) * head
				out.append({"k": M_NONE, "x": hx.x, "y": hx.y, "lc": 4, "lp": hx, "lr": 46.0, "lk": 0.55 * (1.0 - u / 0.3)})
			var g := u - CSW * 0.6
			if g > 0.0 and g < 0.24:
				out.append(sparkle_m(B.x - ux * 3.0, B.y - uy * 3.0, 11.0 * out_back(minf(1.0, g / 0.05)) * (1.0 - g / 0.24), 6, 4, 0.7))
		rows.append(out)
	var p := {"A": A, "B": B, "U": Vector2(ux, uy), "NR": Vector2(nx, ny), "LC": LC}
	for nd in [screen("Cover", "slash", p), screen("Light", "slash_light", p)]:
		for nm in ks:
			key(nd, "material:shader_parameter/" + nm, ks[nm], "nearest")
	marks("Glints", rows)
	ghosts({"sparks": sparks})
	var li := 0
	for l in lights:
		light_at("Flash%d" % li, l[0], l[1], l[2], l[3], l[4], l[5], clocks)
		li += 1
