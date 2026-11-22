# reimagined-from: src/fx/critters/flying-skull.js
# Flying skull: A cracked bone skull bobs in the air, jaw chattering, eyes burning, a fire roaring off its crown that
# sheds flame puffs, embers and smoke and throws warm light.
# loop, 2.40 s, 96x132 canvas, origin [48, 120], backdrop ground
# The skull is the original's own body cells (critter()). The crown of fire is a canvas shader running the original's
# flame tongues layer by layer off the keyed clock (fx/critters/_skull_fire.gdshader), one behind the skull and one
# over its crown. The smoke, the flame puffs, the licks, the gout breathed out, the embers and the sparks skipping on
# the floor are particles placed frame by frame on the original's own cycles and flights, each drawn as the original
# draws its kind (soft discs, flame balls, pixels, streaks) with its glow; the burning eyes are pixels on the same
# clock; the warm light (the pool, the core, the eyes, the mouth, the lit floor) keyed lights; the shadow a keyed soft
# ellipse.
extends "res://build/fx/critters/_critters.gd"

const HOVER := 40.0
const SMOKE_R := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]

var F: PackedColorArray
var HEAT := []


func at(t: float) -> Dictionary:
	var a := (t / D) * TAU
	return {"x": 3.0 * sin(a), "y": -HOVER + 3.0 * sin(2.0 * a + 0.5), "vx": (3.0 * TAU * cos(a)) / D, "vy": (6.0 * TAU * cos(2.0 * a + 0.5)) / D}


func sbump(t: float, a: float, b: float) -> float:
	return 0.0 if (t <= a or t >= b) else pow(sin(PI * ((t - a) / (b - a))), 0.5)


func jaw(t: float) -> float:
	var ch := maxf(0.0, sin((t / D) * TAU * 22.0))
	var b := maxf(sbump(t, 0.15, 0.75), sbump(t, 1.3, 1.95))
	return jround(maxf(ch * 2.4 * b, sbump(t, 1.95, 2.3) * 3.4))


func flick(t: float) -> float:
	return 0.74 + 0.16 * lnoise(t, D, 18, 0.0, 1.0) + 0.1 * lnoise(t, D, 46, 0.0, 2.0)


static func top_y(x: float) -> float:
	return -6.0 - 10.5 * sqrt(maxf(0.0, 1.0 - (x / 11.0) ** 2))


func crown() -> Array:
	var out := []
	for x in range(-10, 11, 2):
		out.append({"x": float(x), "h": 13.0 + 13.0 * (1.0 - (x / 11.0) ** 2), "w": 2.3 + rand([x + 20, 1, 3]) * 0.8, "n": 37.0 + x * 3 + 11, "front": false})
	for s in [-1, 1]:
		out.append({"x": s * 11.0, "y": -5.0, "h": 10.0, "w": 1.8, "n": 61.0 + s * 13 + 5, "front": false})
	for i in 5:
		var x := -5.0 + 2.5 * i
		out.append({"x": x, "h": 5.0 + 3.0 * rand([x * 4.0 + 20.0, 1, 5]), "w": 1.6, "n": 91.0 + x * 5.0 + 7.0, "front": true})
	return stable_sort(out, func(a: Dictionary, b: Dictionary) -> bool: return absf(a.x) > absf(b.x))


func fire(name: String, tongues: Array, front: bool) -> ColorRect:
	var tg := PackedVector4Array()
	var tn := PackedFloat32Array()
	for f in tongues:
		if f.front != front:
			continue
		var y: float = (top_y(f.x) + 1.5) if front else float(f.get("y", top_y(f.x) + 3.0))
		tg.append(Vector4(f.x, y, f.h, f.w))
		tn.append(f.n)
	while tg.size() < 16:
		tg.append(Vector4.ZERO)
		tn.append(0.0)
	var heat := PackedColorArray(HEAT)
	var s := shape(name, csh("skull_fire"), Vector2(96, 96), {"period": D, "hover": HOVER, "front": front, "tg": tg, "tn": tn,
		"count": tongues.filter(func(f: Dictionary) -> bool: return f.front == front).size(), "heat": heat},
		{"at": Vector2(0, -72.0)})
	per_frame(s, "material:shader_parameter/t", func(i: int, t: float) -> float: return t)
	per_frame(s, "material:shader_parameter/X", func(i: int, t: float) -> float: return jround(at(t).x))
	per_frame(s, "material:shader_parameter/Y", func(i: int, t: float) -> float: return jround(at(t).y))
	return s


func make() -> void:
	F = root.ramps.palette
	for i in F.size():
		HEAT.append(F[F.size() - 1 - i])
	var S3: Array = [F[7], F[6], F[4], F[2]]   # the swarm's sparks: head .. tail
	var smoke_col := mixc(Color("#5b5566"), F[2], 0.3)
	# a table holds 16 colours: the smoke's colour walks from its own towards the smoke ramp as it ages, so take the
	# middle of each of the ramp's five age bands, and the lit cap of the youngest
	var smokes := []
	for ri in 5:
		smokes.append(mixc(smoke_col, Color(SMOKE_R[ri]), (ri + 0.5) / 5.0))
	smokes.append(mixc(mixc(smoke_col, Color(SMOKE_R[0]), 0.1), Color.WHITE, 0.12))
	var tongues := crown()
	blob("Shadow", 0.0, 1.6, Color("#0d0a12"), 14.0, func(i: int, t: float) -> Array: return [at(t).x, 9.0, 0.6])
	fire("FireBack", tongues, false)
	# the smoke off the tips, born where the skull was: three soft discs each, a body, a low core, a lit cap
	var smoke := []
	var eyes := []
	var breath := []
	var puffs := []
	var licks := []
	var sparks := []
	for f in NF:
		var t := ft(f)
		var S := at(t)
		var X := jround(S.x)
		var Y := jround(S.y)
		var row := []
		cycle(t, D, 15, 8, func(g: JsRng) -> float: return g.range(1.7, 2.5), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var x0: float = S0.x + r.range(-6, 6)
			var y0: float = S0.y - 22.0 - r.range(0, 8)
			var vx0 := r.range(-5, 5)
			var p := fly(x0, y0, vx0, -r.range(16, 26), age, -12.0, 1.2)
			var x := p.x + sin(age * 1.3 + r.next() * 6.0) * 3.0 * age
			var size := r.range(2.8, 4.4)
			var k := (L - age) / L
			var ag := 1.0 - k
			var rr := size * (0.65 + minf(1.0, ag * 2.5) * 0.45 + ag * 0.5)
			var a := minf(1.0, ag * 12.0) * minf(1.0, k * 2.4) * 0.7
			var ri := clampi(int(floorf(ag * 5.0)), 0, 4)
			var c := nearest(mixc(smoke_col, Color(SMOKE_R[ri]), ag), smokes)
			row.append(disc_e(x, p.y, rr, c, a * 0.45))
			row.append(disc_e(x + rr * 0.05, p.y + rr * 0.06, rr * 0.74, c, a * 0.62))
			if ag < 0.5:
				row.append(disc_e(x - rr * 0.22, p.y - rr * 0.3, rr * 0.5, nearest(mixc(c, Color.WHITE, 0.12), smokes), a * 0.4 * (1.0 - ag * 2.0))))
		smoke.append(row)
		# the burning eyes
		var er := []
		for s in [-1, 1]:
			var ex: float = X + s * 5.1 - 0.5
			var ey := Y - 2.4
			var fl := 0.75 + 0.25 * lnoise(t, D, 30, s * 9.0, 12.0)
			er.append(dot_e(ex, ey, HEAT[0]))
			er.append(dot_e(ex + 1.0, ey, HEAT[1]))
			er.append(dot_e(ex, ey + 1.0, HEAT[2]))
			er.append(dot_e(ex + 1.0, ey + 1.0, HEAT[3]))
			er.append(dot_e(ex, ey - 1.0, HEAT[3]) if fl > 0.8 else null)
			er.append(dot_e(ex + 1.0, ey - 1.0, HEAT[5]) if fl > 0.8 else null)
		eyes.append(er)
		# the gout of flame breathed out at the end of the gape
		var br := []
		for i in 9:
			var r := rng([1, i, 21])
			var born := 1.98 + i * 0.03
			var age := jmod(t - born, D)
			var L := r.range(0.25, 0.45)
			if age >= L:
				continue
			var S0 := at(born)
			var bx: float = S0.x + r.range(-3, 3)
			var bvx := r.range(-22, 22)
			var p := fly(bx, S0.y + 11.0, bvx, r.range(40, 75), age, -70.0, 3.5)
			var sz := r.range(1.1, 2.0)
			br.append_array(fire_puff_es(p.x, p.y, 1.0 - age / L, sz, r.next() * 100.0, HEAT))
		breath.append(br)
		# flame puffs off the tongue tips, cooling down the ramp as they rise
		var pr := []
		cycle(t, D, 40, 9, func(g: JsRng) -> float: return g.range(0.18, 0.36), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var side := r.chance(0.3)
			var a := 0.0
			if side:
				var sg := r.sign()
				a = sg * r.range(0.9, 1.45)
			else:
				a = r.range(-0.8, 0.8)
			var x0: float = S0.x + sin(a) * 10.5
			var y0: float = S0.y - 6.0 - cos(a) * 10.0 - (0.0 if side else r.range(2, 10))
			var vx0 := r.range(-6, 6) + sin(a) * 6.0
			var p := fly(x0, y0, vx0, -r.range(18, 34), age, -95.0, 3.2)
			var x := p.x + sin(age * 17.0 + r.next() * 6.0) * 0.8
			var sz := r.range(1.0, 2.2)
			pr.append_array(fire_puff_es(x, p.y, 1.0 - age / L, sz, r.next() * 100.0, HEAT)))
		puffs.append(pr)
		# licks: little blobs of flame breaking off the tips
		var lr := []
		cycle(t, D, 18, 10, 0.26, func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var fx := r.range(-10, 10)
			var x0: float = S0.x + fx
			var y0: float = S0.y + top_y(fx) - r.range(4, 16) * (1.0 - absf(fx) / 14.0)
			var kk := 1.0 - age / L
			var x := x0 + r.range(-3, 3) * age
			var y := y0 - r.range(12, 20) * age
			var rr := r.range(0.9, 1.7) * (0.4 + 0.6 * kk)
			lr.append(disc_e(x, y, rr + 0.6, HEAT[5] if kk > 0.5 else HEAT[6]))
			if kk > 0.35:
				lr.append(disc_e(x, y - 0.3, rr * 0.6, HEAT[2] if kk > 0.7 else HEAT[4])))
		licks.append(lr)
		# embers wander up and cool, then the sparks that pop out, fall and skip along the floor
		var sr := []
		cycle(t, D, 24, 11, func(g: JsRng) -> float: return g.range(1.0, 2.4), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var x0: float = S0.x + r.range(-11, 11)
			var y0: float = S0.y - r.range(6, 24)
			var s := r.next() * 100.0
			var vx0 := r.range(-22, 22)
			var p := fly(x0, y0, vx0, -r.range(25, 70), age, -20.0, 1.6)
			var x := p.x + sin(age * 2.3 + s) * 4.0 * minf(1.0, age)
			var size := 2.0 if r.chance(0.3) else 1.0
			var kk := (L - age) / L
			var c: Color = S3[0] if kk > 0.6 else (S3[1] if kk > 0.3 else S3[2])
			if kk < 0.25 and sin(t * 40.0 + s) < 0.0:
				return
			sr.append(dot_e(x, p.y, c, 1.0, [x, p.y, 3.0 + size, c, 0.35 * kk]))
			if size > 1.5:
				sr.append(dot_e(x, p.y + 1.0, S3[3])))
		cycle(t, D, 5, 12, func(g: JsRng) -> float: return g.range(0.9, 1.4), func(age: float, L: float, r: JsRng, _i: int) -> void:
			var S0 := at(jmod(t - age, D))
			var bx: float = S0.x + r.range(-6, 6)
			var by: float = S0.y - r.range(10, 18)
			var bvx := r.range(-28, 28)
			var b := bounce(bx, by, bvx, -r.range(50, 110), age, 430.0, -0.5, 0.42)
			var vx: float = 0.1 if b.rest else b.vx
			var vy: float = 0.0 if b.rest else b.vy
			var kk := (L - age) / L
			var sp := sqrt(vx * vx + vy * vy)
			if sp == 0.0:
				sp = 1.0
			var ux := vx / sp
			var uy := vy / sp
			var head: Color = S3[0] if kk > 0.6 else (S3[1] if kk > 0.3 else S3[2])
			var ln := minf(9.0, 1.0 + sp * 0.022)
			var x: float = b.x
			var y: float = b.y
			sr.append(line_e(x - ux * ln, y - uy * ln, x - ux * ln * 0.4, y - uy * ln * 0.4, head if kk > 0.5 else S3[3]))
			var e := line_e(x - ux * ln * 0.45, y - uy * ln * 0.45, x, y, head)
			e.lp = Vector2(x, y)
			e.lr = 3.0
			e.lc = head
			e.lk = 0.45 * kk
			sr.append(e))
		sparks.append(sr)
	table("Smoke", K_DISC, smoke, {"soft": true, "extra": smokes, "light": false})
	critter()
	table("Eyes", K_DOT, eyes, {"light": false})
	var bp := soft_split(breath)
	table("BreathDying", K_DISC, bp[1], {"soft": true, "light": false})
	table("Breath", K_DISC, bp[0])
	fire("FireFront", tongues, true)
	var pp := soft_split(puffs)
	table("PuffsDying", K_DISC, pp[1], {"soft": true, "light": false})
	table("Puffs", K_DISC, pp[0])
	table("Licks", K_DISC, licks, {"light": false})
	table("Embers", K_LINE, sparks)
	var warm := mixc(F[4], F[5], 0.5)
	glows("Light", func(i: int, t: float) -> Array:
		var S := at(t)
		var X := jround(S.x)
		var Y := jround(S.y)
		var k := flick(t)
		var lean := clampf(-S.vx / 60.0, -0.8, 0.8)
		var out := []
		for s in [-1, 1]:
			var ex: float = X + s * 5.1 - 0.5
			var ey := Y - 2.4
			var fl := 0.75 + 0.25 * lnoise(t, D, 30, s * 9.0, 12.0)
			out.append({"c": F[5], "p": Vector2(ex + 1.0, ey + 1.0), "r": 6.0, "k": 0.45 * fl})
			out.append({"c": F[7], "p": Vector2(ex + 1.0, ey + 0.5), "r": 3.0, "k": 0.5 * fl})
		var op := jaw(t)
		out.append({"c": F[5], "p": Vector2(X, Y + 8.0 + op * 0.5), "r": 4.0 + op * 2.0, "k": 0.25 * op} if op > 0.0 else null)
		var brr := 0.92 + 0.08 * sin((t / D) * TAU * 2.0)
		out.append({"c": warm, "p": Vector2(X + lean * 4.0, Y - 20.0), "r": 74.0 * brr * (0.9 + 0.1 * k), "k": 0.48 * k})
		out.append({"c": F[6], "p": Vector2(X, Y - 21.0), "r": 24.0, "k": 0.3 * k})
		out.append({"c": F[8], "p": Vector2(X, Y - 15.0), "r": 9.0, "k": 0.16 * k})
		return out)
	glows("FloorLight", func(i: int, t: float) -> Array:
		var S := at(t)
		var k := flick(t)
		var out := []
		for x in range(-30, 31, 6):
			out.append({"c": warm, "p": Vector2(S.x + x, -1.0), "r": 20.0, "k": 0.15 * k * (1.0 - absf(x) / 40.0)})
		return out)
