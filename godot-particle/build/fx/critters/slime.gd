# reimagined-from: src/fx/critters/slime.js
# Slime: A glossy slime hops in place: it squashes to wind up, stretches into the jump, rounds out in the air, splats
# down flinging droplets that creep back, then wobbles and blinks.
# loop, 1.80 s, 112x88 canvas, origin [56, 72], backdrop ground
# The slime is the original's own body cells (critter()). The puddle it sits in is a canvas shader (fx/critters/
# _puddle.gdshader: the goo dome, its glints sliding on the original's loop noise) keyed to the original's splash;
# the bubbles swelling and popping in it, the droplets flung off the splat (in flight, then creeping home with a wet
# trail), the goo string it pulls off the floor and the drip when it snaps, the bubble popping out of its top, the
# drips off its underside, the spores drifting up and the glint at the top of the hop are particles placed frame by
# frame from the original's formulas, each with its glow; the light it throws a keyed light shader.
extends "res://build/fx/critters/_critters.gd"

const T_SQ := 0.5
const T_UP := 0.84
const T_LIFT := 0.9
const T_LAND := 1.44
const SNAP := 0.965
const W0 := 30.0
const H0 := 22.0
const VC := 0.4
const GR := 640.0
const NDROP := 12
const HOPH := 24.0
const POP := 0.4
const DRIPS := [[1.02, -4.0], [1.18, 3.0]]


## _lib.js curve(): smoothstep between keyframes, held flat outside
static func kcurve(x: float, list: Array) -> float:
	if x <= list[0][0]:
		return list[0][1]
	for i in range(1, list.size()):
		var a: Array = list[i - 1]
		var b: Array = list[i]
		if x <= b[0]:
			var u: float = (x - a[0]) / (b[0] - a[0]) if b[0] != a[0] else (x - a[0])
			return a[1] + (b[1] - a[1]) * u * u * (3.0 - 2.0 * u)
	return list[-1][1]


func pose(t: float) -> Dictionary:
	var age := jmod(t - T_LAND, D)
	var s := 0.0
	var by := 0.0
	var lean := 0.0
	var rnd := 0.1
	var q := -1.0
	if t >= T_LIFT and t < T_LAND:
		q = (t - T_LIFT) / (T_LAND - T_LIFT)
		by = -HOPH * 4.0 * q * (1.0 - q)
		s = kcurve(q, [[0.0, 0.36], [0.4, 0.02], [0.55, -0.05], [0.85, 0.08], [1.0, 0.16]])
		rnd = 0.1 + 0.8 * smoothx(0.0, 0.16, q) * (1.0 - smoothx(0.86, 1.0, q))
	elif t >= T_UP and t < T_LIFT:
		s = lerpf(-0.3, 0.36, out_cubic(seg(t, T_UP, T_LIFT)))
	elif t >= T_SQ and t < T_UP:
		var u := seg(t, T_SQ, T_UP)
		s = -0.3 * in_out_sine(u) + 0.018 * sin(t * TAU * 16.0) * smoothx(0.55, 1.0, u)
	else:
		s = -0.46 if age < 0.06 else -0.46 * spring(age - 0.06, 2.1, 4.6)
		lean = 0.07 * exp(-age * 4.0) * sin(age * TAU * 1.9)
		if t < T_SQ:
			s += 0.02 * sin((t / T_SQ) * TAU)
	return {"s": s, "by": by, "lean": lean, "round": rnd, "q": q, "age": age, "W": W0 / sqrt(1.0 + s), "H": H0 * (1.0 + s)}


static func half_w(v: float, P: Dictionary) -> float:
	if v < 0.0 or v > 1.0:
		return -1.0
	var W: float = P.W
	var H: float = P.H
	if v >= VC:
		var q := (v - VC) / (1.0 - VC)
		return (W / 2.0) * sqrt(1.0 - q * q)
	var q2 := (VC - v) / VC
	var hb := v * H
	var rc := 3.0
	var hw := (W / 2.0) * sqrt(maxf(0.0, 1.0 - P.round * q2 * q2))
	if hb < rc:
		hw -= rc - sqrt(rc * rc - (rc - hb) ** 2)
	return hw


static func inside(P: Dictionary, x: float, y: float) -> bool:
	var v: float = (P.by - 1.0 - y) / P.H
	var hw := half_w(v, P)
	return hw >= 0.0 and absf(x - P.lean * v * P.H) <= hw


func droplet(i: int, age: float) -> Dictionary:
	var r := rng([1, i, 7])
	var a := -PI / 2.0 + r.range(-1.2, 1.2)
	var sp := r.range(60, 118)
	var size := 1 if r.chance(0.35) else (2 if r.chance(0.7) else 3)
	var fa := a + PI / 2.0
	var x0 := sin(fa) * 21.0
	var y0 := -1.0 - cos(fa) * 12.5
	var f := toss(x0, y0, cos(a) * sp * 0.75, sin(a) * sp, age, GR, -1.0)
	f.size = size
	if f.landed:
		var lx: float = f.lx
		var home := (signf(lx) if lx != 0.0 else 1.0) * (W0 / 2.0 - 2.0)
		var dur := minf(0.55, 0.22 + absf(lx - home) / 60.0)
		var u := seg(age - f.at - 0.14, 0.0, dur)
		f.x = lerpf(lx, home, in_out_sine(u))
		f.k = 1.0 - u
		f.gone = u >= 1.0
		f.splat = clampf(1.0 - (age - f.at) / 0.14, 0.0, 1.0)
	return f


func puddle_r(t: float, P: Dictionary) -> float:
	if P.q >= 0.0:
		return (W0 / sqrt(1.36) / 2.0 + 3.0) * (1.0 - 0.22 * P.q)
	return P.W / 2.0 + 3.0 + 9.0 * exp(-P.age * 5.0) * (1.0 - exp(-P.age * 40.0)) * (1.0 if (t >= T_LAND or t < T_SQ) else 0.0)


func make() -> void:
	# behind: the puddle, its bubbles, the landed droplets creeping home, the goo string
	var pd := shape("Puddle", csh("puddle"), Vector2(84, 8), {"period": D, "pal": C, "R": 18.0, "hp": 2.0}, {"at": Vector2(0, -2), "back": true})
	per_frame(pd, "material:shader_parameter/t", func(i: int, t: float) -> float: return t)
	per_frame(pd, "material:shader_parameter/R", func(i: int, t: float) -> float: return puddle_r(t, pose(t)))
	per_frame(pd, "material:shader_parameter/hp", func(i: int, t: float) -> float: return minf(2.4, 0.9 + puddle_r(t, pose(t)) * 0.06))
	var fill := []
	var back := []
	var front := []
	var spores := []
	for fi in NF:
		var t := ft(fi)
		var P := pose(t)
		var yb: float = P.by - 1.0
		var age: float = P.age
		var R := puddle_r(t, P)
		var hp := minf(2.4, 0.9 + R * 0.06)
		var fr := []
		var br := []
		cycle(t, D, 4, 20, func(g: JsRng) -> float: return g.range(0.45, 0.75), func(ag: float, L: float, r: JsRng, _i: int) -> void:
			var x := r.range(-0.85, 0.85) * R
			var k := ag / L
			var rb := r.range(1.4, 2.6) * (0.3 + 0.7 * out_cubic(minf(1.0, k * 1.25)))
			if absf(x) < P.W / 2.0 + 1.0 and P.q < 0.0:
				return
			var sy := -1.0 - jround(sqrt(maxf(0.0, 1.0 - (x / R) ** 2)) * hp)
			if k < 0.85:
				for y in range(int(floorf(sy - rb)), int(sy) + 1):
					for xx in range(int(floorf(x - rb - 1.0)), int(ceilf(x + rb + 1.0)) + 1):
						var dx := xx + 0.5 - x
						var dy := y + 0.5 - sy
						var dd := sqrt(dx * dx + dy * dy)
						if dd > rb + 0.5:
							continue
						if dd > rb - 0.7:
							br.append(dot_e(xx, y, C[6] if (dx < 0.0 and dy < -rb * 0.3) else C[4]))
						else:
							fr.append(dot_e(xx, y, C[5], 0.3))
				br.append(dot_e(x, sy, C[4], 0.0, [x, sy - rb * 0.5, rb * 2.0 + 3.0, C[5], 0.2]))
			else:
				var q := (k - 0.85) / 0.15
				for dv in [[1.0, 0.0], [-1.0, 0.0], [0.6, -0.7], [-0.6, -0.7], [0.0, -1.0]]:
					br.append(dot_e(x + dv[0] * (2.0 + 3.0 * q), sy + dv[1] * (2.0 + 3.0 * q), C[6], 1.2 - q)))
		for i in NDROP:
			var f := droplet(i, age)
			if not f.landed or f.gone:
				continue
			var x := jround(f.x)
			var w: int = int(f.size) + (1 if f.splat > 0.0 else 0)
			for j in w:
				br.append(dot_e(x - (w >> 1) + j, -1.0, C[5] if j == 0 else C[4], 1.0, [x, -1.0, 5.0, C[4], 0.25 * f.k + 0.1] if j == 0 else []))
			if f.size >= 2 and f.splat <= 0.0:
				br.append(dot_e(x, -2.0, C[5]))
				br.append(dot_e(x - 1.0, -2.0, C[4]))
			br.append(dot_e(x, 0.0, C[3]))
			var dir := signf(f.lx - f.x)
			var j := 1
			while j < minf(8.0, absf(f.lx - f.x)):
				br.append(dot_e(x + dir * j, 0.0, C[2], 0.7 - j * 0.08))
				j += 1
		if t >= T_LIFT and t < SNAP:
			var bot: float = P.by - 1.0
			var u := (t - T_LIFT) / (SNAP - T_LIFT)
			for y in range(int(floorf(bot)), 0):
				var m := sin(((y - bot) / -bot) * PI)
				br.append(dot_e(-1.0, y, C[4]))
				if m * u < 0.45:
					br.append(dot_e(0.0, y, C[3]))
		elif t >= SNAP and t < SNAP + 0.3:
			var a2 := t - SNAP
			var ys: float = pose(SNAP).by - 1.0
			var f := toss(-1.0, ys * 0.45, 0.0, 0.0, a2, GR * 1.3, -2.0)
			if not f.landed:
				br.append(dot_e(-1.0, f.y, C[5]))
				br.append(dot_e(-1.0, f.y - 1.0, C[3]))
			var nub := 3.0 * (1.0 - a2 / 0.12)
			var j := 0
			while j < nub:
				br.append(dot_e(-1.0, P.by + j, C[3] if j == 0 else C[4]))
				j += 1
		fill.append(fr)
		back.append(br)
		# in front: the bubble popping out of its top, droplets in flight, drips, the glint
		var ff := []
		if t >= POP and t < POP + 0.16:
			var k := (t - POP) / 0.16
			var x: float = P.lean * P.H - half_w(0.86, P) * 0.05
			var y: float = yb - P.H - 0.5
			var a := 0.0
			ff.append(dot_e(x, y, C[6], 0.0, [x, y, 6.0, C[5], 0.4 * (1.0 - k)]))
			while a < TAU:
				ff.append(dot_e(x + cos(a) * (1.0 + k * 3.0), y + sin(a) * (1.0 + k * 3.0) * 0.7, C[6], 1.2 - k))
				a += 0.6
			for s in [-1.0, 1.0]:
				ff.append(dot_e(x + s * (1.0 + k * 4.0), y - 1.0 - k * 6.0 + k * k * 4.0, C[5], 1.3 - k))
		for i in NDROP:
			var f := droplet(i, age)
			if f.landed or inside(P, f.x, f.y):
				continue
			var x: float = f.x
			var y: float = f.y
			var sv := sqrt(f.vx * f.vx + f.vy * f.vy)
			if sv == 0.0:
				sv = 1.0
			var ux: float = f.vx / sv
			var uy: float = f.vy / sv
			var L := minf(2.5, sv / 50.0)
			ff.append(line_e(x - ux * L, y - uy * L, x, y, C[3]))
			if f.size >= 2:
				ff.append(dot_e(x - 1.0, y, C[4]))
				ff.append(dot_e(x - 1.0, y + 1.0, C[3]))
				ff.append(dot_e(x, y + 1.0, C[2]))
			if f.size >= 3:
				ff.append(dot_e(x + 1.0, y, C[3]))
				ff.append(dot_e(x - 1.0, y - 1.0, C[4]))
				ff.append(dot_e(x, y - 1.0, C[5]))
			ff.append(dot_e(x, y, C[6] if f.size >= 2 else C[5], 1.0, [x, y, 5.0 + f.size, C[4], 0.32]))
		for dr in DRIPS:
			var t0: float = dr[0]
			var dx: float = dr[1]
			var a2 := jmod(t - t0, D)
			if a2 > 0.6:
				continue
			var P0 := pose(t0)
			var f := toss(dx, P0.by - 0.5, 0.0, 12.0, a2, GR, -1.0)
			if not f.landed:
				ff.append(dot_e(dx, f.y, C[5], 1.0, [dx, f.y, 4.0, C[4], 0.3]))
				ff.append(dot_e(dx, f.y - 1.0, C[4]))
			elif a2 - f.at < 0.14:
				var k: float = (a2 - f.at) / 0.14
				for s2 in [-1.0, 1.0]:
					ff.append(dot_e(dx + s2 * (1.0 + k * 3.0), -2.0 - k * 3.0 + k * k * 3.0, C[5], 1.2 - k))
		if P.q > 0.4 and P.q < 0.64:
			var k := sin(PI * seg(P.q, 0.4, 0.64))
			ff.append_array(sparkle_es(P.lean * 0.8 * P.H - P.W * 0.21, yb - P.H * 0.8, 1.0 + 2.5 * k, 6, 5, 0.5 * k, 4))
		front.append(ff)
		# spores drifting up out of the puddle, glowing
		var sr := []
		cycle(t, D, 7, 14, func(g: JsRng) -> float: return g.range(1.2, 1.8), func(ag: float, L: float, r: JsRng, i: int) -> void:
			var k := ag / L
			var x := r.range(-24, 24) + sin(ag * 2.1 + i * 1.7) * 3.0
			var y := -2.0 - r.range(9, 17) * ag - 5.0 * ag * ag
			var a := minf(1.0, k * 4.0) * minf(1.0, (1.0 - k) * 2.5)
			var tw := 0.6 + 0.4 * sin(ag * 7.0 + i * 2.3)
			var big := r.chance(0.35)
			sr.append(dot_e(x, y, C[6] if tw > 0.8 else C[5], a, [x, y, 9.0 if big else 6.0, C[5], (0.45 if big else 0.32) * a * tw]))
			if big:
				sr.append(dot_e(x + 1.0, y, C[5], a))
				sr.append(dot_e(x, y + 1.0, C[4], a))
				sr.append(dot_e(x + 1.0, y + 1.0, C[4], a * 0.6)))
		spores.append(sr)
	table("BubbleFill", K_DOT, fill, {"back": true, "soft": true, "light": false})
	table("Goo", K_DOT, back, {"back": true})
	critter()
	table("Bits", K_LINE, front)
	table("Spores", K_DOT, spores)
	glows("Light", func(i: int, t: float) -> Array:
		var P := pose(t)
		var yb: float = P.by - 1.0
		var cx: float = P.lean * P.H * 0.4
		var cy: float = yb - P.H * 0.45
		var near := clampf(1.0 + P.by / (HOPH * 1.1), 0.0, 1.0)
		var R := puddle_r(t, P)
		var br := 0.9 + 0.1 * sin((t / D) * TAU * 2.0)
		return [{"c": C[3], "p": Vector2(cx * 0.5, -14.0), "r": 64.0, "k": 0.3 * br},
			{"c": C[4], "p": Vector2(cx, cy), "r": 30.0 + P.W * 0.3, "k": 0.2},
			{"c": C[5], "p": Vector2(cx, cy + 3.0), "r": 14.0, "k": 0.16},
			{"c": C[4], "p": Vector2(0.0, -2.0), "r": R * 1.3 + 6.0, "k": 0.12 + 0.08 * near},
			{"c": C[5], "p": Vector2(0.0, -3.0), "r": 40.0, "k": 0.42 * exp(-P.age * 9.0)} if (t >= T_LAND or t < T_SQ) else null])
