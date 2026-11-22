# reimagined-from: src/fx/transitions/burn-away.js@3b2f70286158e1a568f0dd1f84a0592abc9a0077
# Burn away: The screen burns in from its edges behind a ragged ember line of licking flames, embers and smoke; then the black smoulders and burns open from the middle.
# one-shot, 3.00 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The original's two burn fields (where the fire reaches when, rolled from its seed), its per-pixel heat, flicker,
# flecks, char rim and crack web are worked out at build time into textures, and its create()/update() replayed at
# its 120 Hz steps with its own generator. One screen shader burns the cover in and out at the keyed front with the
# original's shadeAt() (fx/transitions/_burn.gdshader: the white-hot line cooling into char, glowing flecks, the
# smouldering cracks), the scorch ahead of it on the soft layer and its warm light as a light twin. The flames on the
# line are frame-table particles (one tongue each, _tongue.gdshader), as are the smoke puffs, shaded by the
# firelight as the original's drawSmoke() shades them (_smoke.gdshader); the fire puffs, embers, ash and sparks the
# front sheds are the original's particles (scifi ghosts); its flickers of light and the pop are Lights.
extends "res://build/fx/transitions/_transitions.gd"

const CLOSE := 1.18
const COVER := 1.35
const SMOULDER := 1.5
const POP := 1.8
const OPEN := 2.62
const SC := 90.0
const HALO := 24.0
const POOL := 48.0
const ASH := ["#a39cab", "#7b7484", "#5c5664", "#433e4b"]
const RATE_IN := [0.006, 0.0014, 0.0006, 0.0024, 0.0012, 0.0004]
const RATE_OUT := [0.006, 0.0005, 0.0004, 0.0012, 0.0004, 0.0004]

const NW := 320
const NH := 180


## _lib.js field(): values (float32, as its Float32Array), 1 / gradient, the gradient's vertical share, lo, hi, order
static func field(fn: Callable) -> Dictionary:
	var f := PackedFloat32Array()
	f.resize(NW * NH)
	var lo := INF
	var hi := -INF
	for y in NH:
		for x in NW:
			var v: float = fn.call(x + 0.5, y + 0.5)
			f[y * NW + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var g := PackedFloat32Array()
	g.resize(NW * NH)
	var ny := PackedFloat32Array()
	ny.resize(NW * NH)
	for y in NH:
		for x in NW:
			var xa := maxi(0, x - 1)
			var xb := mini(NW - 1, x + 1)
			var ya := maxi(0, y - 1)
			var yb := mini(NH - 1, y + 1)
			var gx := (float(f[y * NW + xb]) - f[y * NW + xa]) / (xb - xa)
			var gy := (float(f[yb * NW + x]) - f[ya * NW + x]) / (yb - ya)
			var L := sqrt(gx * gx + gy * gy)
			g[y * NW + x] = 1.0 / clampf(L, 0.45, 3.0)
			ny[y * NW + x] = gy / L if L > 1e-6 else 0.0
	var order := range(NW * NH)
	order.sort_custom(func(a: int, b: int) -> bool: return f[a] < f[b] or (f[a] == f[b] and a < b))
	var sorted := PackedFloat32Array()
	for i in order:
		sorted.append(f[i])
	return {"f": f, "g": g, "ny": ny, "lo": lo, "hi": hi, "order": PackedInt32Array(order), "sorted": sorted}


static func _hyp(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


## how many of the field's values are below v
static func below(F: Dictionary, v: float) -> int:
	var s: PackedFloat32Array = F.sorted
	var a := 0
	var b := s.size()
	while a < b:
		var m := (a + b) >> 1
		if s[m] < v:
			a = m + 1
		else:
			b = m
	return a


func make() -> void:
	var o: Dictionary = meta.options
	var F: PackedColorArray = C
	var R := JsRng.new(int(o.seed))
	var seed: int = int(o.seed) * 13
	var WARM := mixc(F[4], F[5], 0.4)
	var CHAR := mixc(ink, F[0], 0.45)
	var SCORCH := mixc(ink, Color("#3a2216"), 0.6)
	var SMK := mixc(Color("#8a7276"), F[2], 0.2)
	var LIT := mixc(Color("#8a7276"), F[3], 0.25)
	var DIM := Color(SMOKE_RAMP[3])
	var SR2 := Color(SMOKE_RAMP[2])

	# ---- the fields
	var A := field(func(x: float, y: float) -> float:
		var ux := (x - SW / 2.0) / (SW / 2.0)
		var uy := (y - SHH / 2.0) / (SHH / 2.0)
		var m := pow(pow(ux, 4.0) + pow(uy, 4.0), 0.25)
		return (1.0 - m) * SC + 14.0 * fbm(x / 44.0, y / 44.0, seed, 3) + 2.4 * fbm(x / 7.0, y / 7.0, seed + 9, 2) + 7.0 * (0.5 - y / SHH))
	var RB := JsRng.new((seed + 1) * 31 + 5)
	var ox := SW / 2.0 + RB.range(-26, 26)
	var oy := SHH / 2.0 + RB.range(-14, 6)
	var sats := []
	for s in [-1.0, 1.0]:
		var sx: float = ox + s * RB.range(70, 110)
		var sy := oy + RB.range(-40, 40)
		sats.append({"x": sx, "y": sy, "z": RB.range(30, 44)})
	var B := field(func(x: float, y: float) -> float:
		# in doubles (a Vector2 is single precision: ties in the field's order would fall differently)
		var v := _hyp((x - ox) / (SW / 2.0), (y - oy) / (SHH / 2.0)) * SC
		for s in sats:
			v = minf(v, s.z + _hyp((x - s.x) / (SW / 2.0), (y - s.y) / (SHH / 2.0)) * SC * 1.15)
		return v + 13.0 * fbm(x / 40.0, y / 40.0, seed + 22, 3) + 2.4 * fbm(x / 7.0, y / 7.0, seed + 34, 2))
	var heat := PackedFloat32Array()
	heat.resize(NW * NH)
	var ph := PackedByteArray()
	ph.resize(NW * NH)
	var img_a := Image.create(NW, NH, false, Image.FORMAT_RGBAF)
	var img_b := Image.create(NW, NH, false, Image.FORMAT_RGBAF)
	var img_c := Image.create(NW, NH, false, Image.FORMAT_RF)
	for i in NW * NH:
		var x := i % NW
		var y := i / NW
		heat[i] = 0.5 + 0.5 * noise2(x / 13.0, y / 13.0, seed + 41)
		ph[i] = mini(63, int(floorf((0.5 + 0.5 * noise2(x / 23.0, y / 23.0, seed + 43)) * 64.0)))
		var fl := (9.0 + 22.0 * rand([x, y, seed + 47])) if rand([x, y, seed + 45]) < 0.04 else 0.0
		var jit := (rand([x, y, seed + 49]) - 0.5) * 1.5
		var rx := x * 0.8 + y * 0.6
		var ry := y * 0.8 - x * 0.6
		var vein := minf(absf(noise2(rx / 11.0, ry / 9.0, seed + 61)), absf(noise2(ry / 5.5, rx / 5.0, seed + 63)) * 1.5)
		img_a.set_pixel(x, y, Color(A.f[i], A.g[i], B.f[i], B.g[i]))
		img_b.set_pixel(x, y, Color(heat[i], ph[i], fl, jit))
		img_c.set_pixel(x, y, Color(vein, 0, 0))

	var kin := func(t: float) -> float: return A.lo - 8.0 + (A.hi - A.lo + 8.0) * pow(maxf(0.0, t) / CLOSE, 1.25)
	var kout := func(t: float) -> float:
		if t < POP:
			return B.lo - 24.0 + 24.0 * in_quad(clampf((t - SMOULDER) / (POP - SMOULDER), 0.0, 1.0))
		return B.lo + (B.hi - B.lo + 16.0) * out_quad(clampf((t - POP) / (OPEN - POP), 0.0, 1.0))

	# ---- create() / update()
	var end: float = D - 0.05
	var lights := []
	var smoke := []   # the smoke puffs in ps.list order: {x, y, vx, vy, life, max, size, seed, delay, n}
	var st := {"pin": 0, "pout": 0, "closed": false, "popped": false, "n": 0}
	var ash_specs := []
	ghosts_begin(0.0)
	var pspawn := func(t: float, k: int, x: float, y: float, vx: float, vy: float, life: float, col: Variant, size: float, delay: float) -> void:
		if k == SMOKE:
			var sd := R.next() * 100.0
			smoke.append({"x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "size": size, "seed": sd, "delay": delay})
		else:
			spawn(R, t, k, x, y, vx, vy, life, col, size, delay)
	var shed := func(t: float, i: int, in_a: bool) -> void:
		var rate: Array = RATE_IN if in_a else RATE_OUT
		var x := (i % NW) + 0.5
		var y := (i / NW) + 0.5
		var e2 := POP + 0.1 if in_a else D - 0.05
		var r := R.next()
		r -= rate[0]
		if r < 0.0:
			var life := minf(R.range(0.18, 0.4), e2 - t)
			if life > 0.08:
				var vx := R.range(-8, 8)
				var vy := -R.range(25, 50)
				pspawn.call(t, FIRE, x, y - 3.0, vx, vy, life, null, R.range(0.8, 1.7), 0.0)
			return
		r -= rate[1]
		if r < 0.0:
			var life := minf(R.range(0.6, 1.3) if in_a else R.range(0.5, 1), e2 - t)
			if life > 0.2:
				var vx := R.range(-30, 30)
				var vy := -R.range(40, 100)
				pspawn.call(t, EMBER, x, y - 2.0, vx, vy, life, Color.WHITE, 2.0 if R.chance(0.25) else 1.0, 0.0)
			return
		r -= rate[2] + rate[3] * heat[i] * heat[i]
		if r < 0.0:
			var n := R.int_(4, 6)
			var vx := R.range(-6, 6)
			var up: bool = (A if in_a else B).ny[i] < -0.25
			for j in n:
				var life := minf(R.range(0.8, 1.3) if up else R.range(0.35, 0.65), e2 - (t + j * 0.05))
				if life > 0.4:
					var px := x + R.range(-3.5, 3.5)
					var vv := vx + R.range(-3, 3)
					var vy := -R.range(18, 34)
					pspawn.call(t, SMOKE, px, y - 4.0 - j * 1.2, vv, vy, life, SMK, R.range(2.8, 4.8), j * 0.05)
			return
		r -= rate[4]
		if r < 0.0:
			var life := minf(R.range(0.9, 1.6), e2 - t)
			if life > 0.3:
				var vx := R.range(-18, 18)
				var vy := -R.range(25, 60)
				var sd := R.next() * 100.0
				ash_specs.append([t, x, y - 2.0, vx, vy, life, sd])
			return
		r -= rate[5]
		if r < 0.0:
			var rr := R.range(20, 32)
			var kk := R.range(0.14, 0.26)
			lights.append([t, Vector2(x, y - 4.0), rr, WARM, kk, R.range(0.18, 0.4)])
	var ps_t := [0.0]
	var step := func(t: float, dt: float) -> void:
		if t < COVER:
			var k: float = kin.call(t)
			while st.pin < NW * NH and A.f[A.order[st.pin]] <= k:
				shed.call(t, A.order[st.pin], true)
				st.pin += 1
			if not st.closed and t >= CLOSE:
				st.closed = true
				var i: int = A.order[NW * NH - 1]
				var x := float(i % NW)
				var y := float(i / NW)
				lights.append([t, Vector2(x, y), 64.0, WARM, 0.5, 0.4])
				for j in 12:
					var px := x + R.range(-6, 6)
					var py := y + R.range(-3, 3)
					var vx := R.range(-50, 50)
					var vy := -R.range(40, 120)
					var life := R.range(0.5, 0.75)
					pspawn.call(t, EMBER, px, py, vx, vy, life, Color.WHITE, 2.0 if R.chance(0.3) else 1.0, 0.0)
				for j in 5:
					var px := x + R.range(-8, 8)
					var py := y + R.range(-4, 2)
					var vx := R.range(-10, 10)
					var vy := -R.range(12, 28)
					var life := R.range(1.1, 1.6)
					var sz := R.range(3.5, 5.5)
					pspawn.call(t, SMOKE, px, py, vx, vy, life, SMK, sz, R.range(0, 0.15))
		if t >= SMOULDER and t < POP and R.chance(0.1):
			var i: int = B.order[R.int_(0, 400)]
			var x := (i % NW) + 0.5
			var y := (i / NW) + 0.5
			if R.chance(0.6):
				var vx := R.range(-4, 4)
				var vy := -R.range(8, 16)
				var life := minf(R.range(0.9, 1.4), D - 0.05 - t)
				pspawn.call(t, SMOKE, x, y, vx, vy, life, SMK, R.range(2, 3.5), 0.0)
			else:
				var vx := R.range(-12, 12)
				var vy := -R.range(15, 40)
				pspawn.call(t, EMBER, x, y, vx, vy, R.range(0.4, 0.8), Color.WHITE, 1.0, 0.0)
		if not st.popped and t >= POP:
			st.popped = true
			lights.append([t, Vector2(ox, oy), 90.0, WARM, 0.6, 0.45])
			lights.append([t, Vector2(ox, oy), 34.0, F[7], 0.7, 0.12])
			for j in 12:
				var a := R.range(0, TAU)
				var sp := R.range(50, 150)
				var life := R.range(0.4, 0.9)
				pspawn.call(t, EMBER, ox + cos(a) * 3.0, oy + sin(a) * 2.0, cos(a) * sp, sin(a) * sp * 0.7 - 40.0, life, Color.WHITE, 2.0 if R.chance(0.3) else 1.0, 0.0)
			for j in 10:
				var a := R.range(0, TAU)
				var sp := R.range(120, 260)
				pspawn.call(t, SPARK, ox, oy, cos(a) * sp, sin(a) * sp - 50.0, R.range(0.15, 0.35), Color.WHITE, 1.0, 0.0)
		if t >= POP and t < OPEN + 0.2:
			var k: float = kout.call(t)
			while st.pout < NW * NH and B.f[B.order[st.pout]] <= k:
				shed.call(t, B.order[st.pout], false)
				st.pout += 1
		# ps.update for the smoke (the rest move in their emitters)
		ps_t[0] += dt
		var pt: float = ps_t[0]
		for j in range(smoke.size() - 1, -1, -1):
			var q: Dictionary = smoke[j]
			if q.delay > 0.0:
				q.delay -= dt
				continue
			q.life -= dt
			if q.life <= 0.0:
				smoke.remove_at(j)
				continue
			q.vy -= 16.0 * dt
			q.vx += sin(pt * 1.3 + q.seed) * 8.0 * dt
			q.vx -= q.vx * 1.6 * dt
			q.vy -= q.vy * 1.2 * dt
			q.x += q.vx * dt
			q.y += q.vy * dt

	# per frame: the front, the flames on the line, the smoke as drawSmoke() shades it
	var ks := {"mode": [], "inp": [], "k": [], "fade": [], "sk": [], "sr": [], "hi": []}
	var tongue_rows := []
	var smoke_rows := []
	var frame := func(fi: int, t: float) -> void:
		var tt := fi / 30.0
		var in_p := t < COVER
		var k: float = kin.call(t) if in_p else kout.call(t)
		var mode := 1.0 if (t >= COVER and t < SMOULDER) else (2.0 if t < OPEN + 0.25 else 0.0)
		var fade := (1.0 - smooth(COVER - 0.15, COVER, t)) if in_p else 1.0
		var su := clampf((t - SMOULDER) / (POP - SMOULDER), 0.0, 1.0)
		var SR := 5.0 + 17.0 * su
		var sk := 0.0 if (in_p or t < SMOULDER) else ((0.3 + 0.7 * su) if t < POP else 1.0 - (t - POP) / 0.3)
		var hiv := maxf(k + (POOL if in_p else 33.0), B.lo + SR if sk > 0.0 else -1e9)
		ks.mode.append([tt, mode])
		ks.inp.append([tt, 1.0 if in_p else 0.0])
		ks.k.append([tt, k])
		ks.fade.append([tt, fade])
		ks.sk.append([tt, sk])
		ks.sr.append([tt, SR])
		ks.hi.append([tt, hiv])
		var tr := []
		if mode == 2.0:
			var Fd: Dictionary = A if in_p else B
			# the white-hot line: pixels just behind the front (u < 0.9), in the field's order
			var a0 := below(Fd, k - 4.0) if in_p else below(Fd, k)
			var a1 := below(Fd, k + 1e-4) if in_p else below(Fd, k + 4.0)
			var a_lo := below(Fd, k - (33.0 if in_p else POOL))
			var a_hi := below(Fd, hiv)
			a0 = maxi(a0, a_lo)
			a1 = mini(a1, a_hi)
			for j in range(a0, a1):
				var i: int = Fd.order[j]
				var f: float = Fd.f[i]
				var e := k - f if in_p else f - k
				if e < 0.0:
					continue
				var q := ph[i] / 63.0
				var hv := clampf(heat[i] + 0.3 * sin(t * 5.5 + q * 11.0), 0.0, 1.0)
				var u: float = e * Fd.g[i] / (0.6 + 0.6 * hv)
				if u >= 0.9:
					continue
				var x := i % NW
				var y := i / NW
				var dn: float = -Fd.ny[i] if in_p else Fd.ny[i]
				if rand([x, y >> 3, seed + 51]) > 0.12 + 0.6 * maxf(0.0, dn):
					continue
				var n := (x * 7 + (y >> 4) * 131) % 977
				var hh: float = heat[i]
				var leap := 1.0 + maxf(0.0, noise1(t * 2.6 + n * 3.1, n + 70) - 0.5) * 1.8
				var h := (5.0 + 7.0 * rand([x, 1, seed + 53])) * (0.6 + 0.4 * noise1(t * 3.3 + n * 1.7, n)) * (0.6 + 0.6 * hh) * leap * fade * ((0.65 + 0.5 * dn) if dn > 0.0 else 0.5)
				if h >= 1.5:
					tr.append([x, y + 1, h, (1.1 + 0.7 * hh) * (0.8 + h / 16.0), noise1(t * 2.2 + n, n + 40) * 1.5, n])
		tongue_rows.append(tr)
		var sr := []
		var open := t >= SMOULDER and t < OPEN + 0.25
		var fk: PackedFloat32Array = A.f if in_p else B.f
		for q in smoke:
			if q.delay > 0.0:
				continue
			var kk: float = q.life / q.max
			var age := 1.0 - kk
			var r: float = q.size * (0.65 + minf(1.0, age * 2.5) * 0.45 + age * 0.4)
			var i := clampi(int(floorf(q.y)), 0, NH - 1) * NW + clampi(int(floorf(q.x)), 0, NW - 1)
			var e: float = ((k - fk[i]) if in_p else (fk[i] - k)) if (in_p or open) else 99.0
			var lit := clampf(1.0 - absf(e) / 30.0, 0.0, 1.0)
			var a := minf(1.0, age * 12.0) * minf(1.0, kk * 2.4) * 0.58 * ((0.05 + 0.95 * lit) if e > 0.0 else (1.0 if in_p else 0.2 + 0.8 * lit))
			if a < 0.04:
				continue
			var c := mixc(mixc(DIM, LIT, lit), SR2, age * 0.5)
			sr.append([q.x, q.y, r, a, c, mixc(c, Color.WHITE, 0.15), (a * 0.4 * (1.0 - age * 2.0)) if age < 0.5 else 0.0])
		smoke_rows.append(sr)
	var clocks := replay(step, frame)

	# ---- nodes, in the original's draw order
	var pp := {"fa": asset("_fa", img_a), "fb": asset("_fb", img_b), "fc": asset("_fc", img_c), "F": F, "charc": CHAR,
		"scorch": SCORCH, "warm": WARM}
	var nodes := [screen("Cover", "burn", pp), screen("Scorch", "burn_scorch", pp, {"layer": "soft"}), screen("Light", "burn_light", pp)]
	for nd in nodes:
		for nm in ks:
			key(nd, "material:shader_parameter/" + nm, ks[nm], "nearest")
		key(nd, "material:shader_parameter/blo", [[0.0, B.lo]])
		per_frame(nd, "material:shader_parameter/t", func(i: int, _t: float) -> float: return clocks[i])
	_table("Flames", "tongue", tongue_rows, func(e: Array) -> Array:
		return [Color(e[0], e[1], 0, 0), Color(0, 0, 0, 1), Color(e[2], e[3], e[4], e[5]), Color()], 40, {"F": F}, clocks)
	_table("Smoke", "smoke", smoke_rows, func(e: Array) -> Array:
		var X := floorf(e[0])
		var Y := floorf(e[1])
		var c: Color = e[4]
		var c2: Color = e[5]
		return [Color(X, Y, 0, 0), Color(c.r, c.g, c.b, 1), Color(e[0] - X, e[1] - Y, e[2], e[3]), Color(c2.r, c2.g, c2.b, e[6])], 10, {}, clocks)
	var ash_cols := []
	for h in ASH:
		ash_cols.append(Color(h))
	var rest := _gh
	_gh = []
	for a in ash_specs:
		ghost(a[0] - SUB + 1e-4, EMBER, a[1], a[2], a[3], a[4], a[5], Color.WHITE, 1.0, 0, {"seed": a[6]})
	ghosts({"sparks": ash_cols, "prefix": "Ash", "back": false})
	_gh = rest
	ghosts({"sparks": [F[7], F[6], F[4], F[2]], "back": false})
	for c in [WARM, CHAR, SCORCH]:
		keep_colour(c)
	var li := 0
	for l in lights:
		light_at("Flash%d" % li, l[0], l[1], l[2], l[3], l[4], l[5], clocks)
		li += 1


## A frame table of rows[f] (entries turned into their 4 data rows by pack(e)), placed by fx/pickups/_ftp.gdshader
## and drawn by fx/transitions/_<shader>.gdshader on a quad reaching `reach` px round its cell.
func _table(name: String, shader: String, rows: Array, pack: Callable, reach: int, params: Dictionary, clocks: PackedFloat64Array) -> GPUParticles2D:
	var slots := 1
	for r in rows:
		slots = maxi(slots, r.size())
	var img := Image.create(slots, NF * 4, false, Image.FORMAT_RGBAF)
	for f in NF:
		var r: Array = rows[f]
		for j in r.size():
			var px: Array = pack.call(r[j])
			for k in 4:
				img.set_pixel(j, f * 4 + k, px[k])
	var data := asset("_" + name.to_snake_case(), img)
	var q := reach * 2 + 1
	var p := particles(name, {"amount": slots, "lifetime": D + 0.04, "one_shot": true, "explosiveness": 1.0, "local": true,
		"texture": _oquad(q), "process_shader": psh("ftp"), "process_params": {"data": data, "nframes": NF, "looped": false}, "preprocess": 0.0})
	p.interpolate = false
	p.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var m := ShaderMaterial.new()
	m.shader = tsh(shader)
	m.set_shader_parameter("data", data)
	m.set_shader_parameter("quad", float(q))
	for k in params:
		m.set_shader_parameter(k, params[k])
	m.resource_name = name
	p.material = m
	var ks := []
	for i in NF:
		ks.append([i / 30.0, clocks[i]])
	key(p, "material:shader_parameter/t", ks, "nearest")
	return p
