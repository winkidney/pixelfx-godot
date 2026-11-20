# reimagined-from: src/fx/pickups/crystal-shard.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Crystal shard: A broken amber shard hovers and sways: chipped uneven faces, its top sheared off, light pulsing up through glowing cracks and flaring out of the break; splinters orbit it.
# loop, 3.20 s, 64x76 canvas, origin [32, 68], backdrop ground
# ramp palette: #1a0a04 #3e1606 #702a08 #a8480c #e07818 #ffa838 #ffd890 #ffffff
# The shard is a canvas shader ray-casting the original's broken solid facet by facet (fx/pickups/_gem.gdshader: an
# uneven prism, a sheared top, chipped corners), its hover and sway keyed every frame. The cracks are particles:
# each sample of the original's crack lines that lands on the shard (the same ray cast, at build time), lit by the
# pulse climbing them, with their glows. The splinters orbiting it (far half behind, near half in front), their
# glints, the flare out of the break and the embers it throws up are particles placed frame by frame where the
# original draws them; the shadow, the pool, the ring of light and the inner light are keyed.
extends "res://build/fx/pickups/_pickups.gd"

const HALF := 6.0
const TILT := 0.18
const LEAN := 0.2
const HOVER := 27.0
const RX := 15.0
const RY := 3.8
const CRACKS := [
	[[0.5, -9, 0.3], [-0.8, -5, 0.5], [0.6, -1, 0.2], [-0.4, 3, 0.6], [1.4, 6.5, 0.4], [2.2, 8.5, 0.6]],
	[[0.6, -1, 0.2], [2.4, 1.5, 1], [3.4, 4.2, 1.2]],
	[[-0.4, 3, 0.6], [-2, 6.5, 0.4], [-2.6, 10.5, 0.2], [-2.4, 14.5, 0.1]],
	[[-0.8, -5, 0.5], [-2.8, -3, 0.8]],
]


static func roll(p: Array) -> Array:
	return [p[0] * cos(LEAN) - p[1] * sin(LEAN), p[0] * sin(LEAN) + p[1] * cos(LEAN), p[2]]


static func unit(x: float, y: float, z: float) -> Array:
	var l := sqrt(x * x + y * y + z * z)
	return [x / l, y / l, z / l]


static func solid() -> Dictionary:
	var planes := []
	var deg := PI / 180.0
	var jit := [0, 8, -6, 4, -9, 5]
	var rr := [1, 0.86, 1.08, 0.94, 0.82, 1.04]
	var low := [6.5, 5.5, 7, 6, 5, 6.8]
	var raw := []
	for k in 6:
		var a: float = (k * 60 + jit[k]) * deg
		var r: float = 4.8 * rr[k]
		var ct := atan2(13.0, r)
		var cb := atan2(float(low[k]), r)
		raw.append([[cos(a), 0.0, sin(a)], r, 6])
		raw.append([[sin(ct) * cos(a), cos(ct), sin(ct) * sin(a)], sin(ct) * r + cos(ct) * HALF, 7])
		raw.append([[sin(cb) * cos(a), -cos(cb), sin(cb) * sin(a)], sin(cb) * r + cos(cb) * HALF, 8])
	var shear := unit(0.7, 0.62, 0.34)
	raw.append([shear, shear[1] * 7.2 + shear[0] * -0.6, 9])
	for q in [[unit(-0.7, -0.25, 0.65), 4.0], [unit(0.75, 0.15, 0.6), 3.9], [unit(-0.55, 0.5, 0.3), 6.8]]:
		raw.append([q[0], q[1], 10])
	for q in raw:
		var n := roll(q[0])
		planes.append({"n": Vector3(n[0], n[1], n[2]), "d": q[1], "kind": q[2]})
	return {"planes": planes, "r": 8.0, "top": HALF + 13.0, "bottom": HALF + 8.0}


func pose(ph: float) -> Dictionary:
	return {"y": -HOVER - 1.8 * sin(ph * TAU), "spin": 0.3 + 0.62 * sin(ph * TAU)}


static func climb(ph: float) -> float:
	return fmod(ph * 2.0, 1.0) * 1.7 - 0.3


static func project(pt: Array, spin: float, cy: float) -> Vector2:
	var p := roll(pt)
	var xr: float = p[0] * cos(spin) - p[2] * sin(spin)
	var zr: float = p[0] * sin(spin) + p[2] * cos(spin)
	return Vector2(xr, cy - (p[1] * cos(TILT) - zr * sin(TILT)))


## the splinters on their tilted ring at phase ph: back the far half, else the near half; each [entry, glint or null]
func splinters(ph: float, cy: float, back: bool) -> Array:
	var out := []
	for i in 3:
		var a := ph * TAU + (i * TAU) / 3.0
		var s := sin(a)
		if (s < 0.0) != back:
			out.append([null, null])
			continue
		var x := cos(a) * RX
		var y := cy + 1.0 + s * RY - cos(a) * 1.5
		var near := (s + 1.0) / 2.0
		var ang := a * 2.0 + i * 1.7
		var e := {"x": jround(x), "y": jround(y), "c": 4, "reach": 8.0, "e": [3.0 + 1.6 * near, cos(ang), sin(ang), 1.0 if back else 0.0],
			"lp": Vector2(x, y), "lr": 6.0 + 3.0 * near, "lc": C[5], "lk": (0.18 if back else 0.32) * (0.6 + 0.4 * near)}
		out.append([e, glint_e(x - 1.0, y - 1.0, (2.5 * (s - 0.92)) / 0.08, 8, 0.4) if (not back and s > 0.92) else null])
	return out


func make() -> void:
	var seed_ := 8
	var g := solid()
	shadow("Shadow", func(i: int, t: float) -> Array: return [0.0, 6.0, 0.75])
	var back := []
	for i in NF:
		var ph := ft(i) / D
		var r := []
		for s in splinters(ph, pose(ph).y, true):
			r.append(s[0])
		back.append(r)
	table("SplintersBack", K_SPLINTER, back, {"back": true})
	glows("Glow", func(i: int, t: float) -> Array:
		var ph := t / D
		var q := pose(ph)
		var y: float = q.y
		var s0 := climb(ph)
		var inside := exp(-pow((s0 - 0.45) / 0.45, 2.0))
		var l := [{"t": G_POOL, "c": C[4], "p": Vector2(0, 0.5), "r": 20.0, "ry": 3.5, "k": 0.3},
			{"t": G_RING, "c": C[4], "p": Vector2(0, y), "r": 7.0, "w": 20.0, "k": 0.22},
			{"c": C[5], "p": Vector2(0, y), "r": 10.0, "k": 0.2 * inside}]
		var out := clampf(1.0 - absf(s0 - 1.05) / 0.18, 0.0, 1.0)
		if out > 0.0:
			l.append({"c": C[5], "p": project([1.8, 8.4, 0.9], q.spin, y), "r": 12.0, "k": 0.4 * out})
		return l)
	gem_body("Shard", g, func(i: int, t: float) -> Array:
		var q := pose(t / D)
		return [0.0, q.y, q.spin], {"tilt": TILT, "gain": 0.6})
	# the cracks: light running up them, brightest where the pulse is
	var cracks := []
	var front := []
	var glints := []
	var flare := []
	for i in NF:
		var t := ft(i)
		var ph := t / D
		var q := pose(ph)
		var y: float = q.y
		var spin: float = q.spin
		var s0 := climb(ph)
		var r := []
		for crack in CRACKS:
			for k in range(1, crack.size()):
				var p0 := project(crack[k - 1], spin, y)
				var p1 := project(crack[k], spin, y)
				var n := int(ceilf(p0.distance_to(p1) * 2.0))
				for j in n + 1:
					var u := j / float(n)
					var x := p0.x + (p1.x - p0.x) * u
					var yy := p0.y + (p1.y - p0.y) * u
					if gem_hit_at(g, 0.0, y, spin, TILT, floorf(x), floorf(yy)) < 0:
						continue
					var h: float = crack[k - 1][1] + (crack[k][1] - crack[k - 1][1]) * u
					var b := 0.3 + exp(-pow(((h + 9.0) / 22.0 - s0) / 0.14, 2.0))
					var gl := [x + 0.5, yy + 0.5, 2.0 + 3.0 * b, C[5], 0.16 * b] if (j % 4 == 0 and b > 0.5) else []
					r.append(dot_e(x, yy, 8 if b > 0.9 else (6 if b > 0.55 else 5), 1.0, gl))
		cracks.append(r)
		var fr := []
		var gr := []
		for s in splinters(ph, y, false):
			fr.append(s[0])
			gr.append(s[1])
		front.append(fr)
		glints.append(gr)
		# when the pulse reaches the break it flares out of the sheared face and throws up embers
		var fp := project([1.8, 8.4, 0.9], spin, y)
		var out := clampf(1.0 - absf(s0 - 1.05) / 0.18, 0.0, 1.0)
		var fl := [glint_e(fp.x, fp.y, 3.5 * out, 8, 0.55 * out) if out > 0.0 else null]
		var P2 := D / 2.0
		var burst := ((1.05 + 0.3) / 1.7) * P2
		for j in 7:
			var born := burst + rand([j, seed_, 1]) * 0.12
			var at_ := jmod(t - born, P2)
			var life := 0.6 + rand([j, seed_, 2]) * 0.45
			if at_ > life:
				fl.append(null)
				continue
			var k := 1.0 - at_ / life
			var x := fp.x + (rand([j, seed_, 3]) - 0.5) * 4.0 + sin(at_ * 5.0 + j) * 2.0 * (at_ / life)
			var yy := fp.y - at_ * (14.0 + rand([j, seed_, 4]) * 14.0)
			fl.append(dot_e(x, yy, 8 if k > 0.6 else (6 if k > 0.3 else 5), 1.0, [x + 0.5, yy + 0.5, 3.0, C[5], 0.35 * k]))
		flare.append(fl)
	table("Cracks", K_DOT, cracks)
	table("Splinters", K_SPLINTER, front)
	table("SplinterGlints", K_GLINT, glints)
	_flare_tables(flare)


## the flare's glint (slot 0) and the embers (dots) after it, drawn in the original's order
func _flare_tables(rows: Array) -> void:
	var gl := []
	var em := []
	for r in rows:
		gl.append([r[0]])
		em.append(r.slice(1))
	table("FlareGlint", K_GLINT, gl)
	table("Embers", K_DOT, em)
