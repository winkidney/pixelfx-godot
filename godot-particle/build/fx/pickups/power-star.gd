# reimagined-from: src/fx/pickups/power-star.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Power star: A fat bevelled star rocks side to side and swells on each beat, rays of light turning slowly behind it, sparks spinning off its points.
# loop, 1.60 s, 88x84 canvas, origin [44, 76], backdrop ground
# ramp palette: #2a1604 #5e3208 #a05c0c #e09414 #ffc626 #ffe866 #fff8c4 #ffffff
# The star is a canvas shader running the original's bevelled five-armed star (fx/pickups/_star.gdshader), its rock,
# swell and hover keyed every frame; the rays turning behind it are a light shader on the same keys, with the fine
# bright line down each long ray drawn as particles (1 px lines placed frame by frame). The sparks spinning off its
# points on each beat, the specks winking round it, the small stars popping and the glint on its top arm are
# particles placed frame by frame where the original draws them, each glint with its glow.
extends "res://build/fx/pickups/_pickups.gd"

const HOVER := 25.0
const RO := 11.5
const RAYS := 10
const BEATS := [0.25, 0.75]


static func swell(ph: float) -> float:
	var s := 0.0
	for b in BEATS:
		var u := jmod(ph - b, 1.0)
		s += exp(-u * 14.0) * (1.0 if 1.0 - u * 2.5 > 0.0 else 0.0)
	return s


func hover(t: float) -> float:
	return -HOVER - 1.5 * sin((t / D) * TAU * 2.0)


static func fly(x: float, y: float, vx: float, vy: float, t: float, g: float, drag: float) -> Vector2:
	var f := (1.0 - exp(-drag * t)) / drag
	var vt := g / drag
	return Vector2(x + vx * f, y + vt * t + (vy - vt) * f)


func make() -> void:
	var seed_ := 9
	shadow("Shadow", func(i: int, t: float) -> Array: return [0.0, 9.0 + 2.0 * swell(t / D), 0.7], {"span": 16})
	# the rays turning behind it, and the fine bright line down each long one (clipped at the floor)
	var cr := canvas_rect()
	var rays := shape("Rays", psh("star_rays_light"), cr.size, {"c5": C[5], "c6": C[6], "canvas": canvas_v4()},
		{"at": cr.position + cr.size / 2.0})
	per_frame(rays, "material:shader_parameter/cy", func(i: int, t: float) -> float: return hover(t))
	per_frame(rays, "material:shader_parameter/spin", func(i: int, t: float) -> float: return (t / D) * ((TAU / RAYS) * 2.0))
	per_frame(rays, "material:shader_parameter/sw", func(i: int, t: float) -> float: return swell(t / D))
	var lines := []
	for i in NF:
		var t := ft(i)
		var ph := t / D
		var y := hover(t)
		var sw := swell(ph)
		var spin := ph * ((TAU / RAYS) * 2.0)
		var r := []
		for j in range(0, RAYS, 2):
			var a := spin + (j * TAU) / RAYS
			var ln := 34.0 * (1.0 + 0.18 * sw)
			var ca := cos(a)
			var sa := sin(a)
			var d0 := RO + 3.0
			var d1 := minf(ln * 0.88, (-2.0 - y) / sa if sa > 0.05 else INF)
			if d1 <= d0:
				r.append(null)
				continue
			var x0 := floorf(ca * d0)
			var y0 := floorf(y + sa * d0)
			r.append({"x": x0, "y": y0, "c": 6, "c2": 5, "a": 0.75 + 0.35 * sw,
				"e": [floorf(ca * d1) - x0, floorf(y + sa * d1) - y0, 0.35, 3]})
		lines.append(r)
	table("RayLines", K_LINE, lines, {"back": true})
	glows("Glow", func(i: int, t: float) -> Array:
		var y := hover(t)
		var sw := swell(t / D)
		var sc := 1.0 + 0.13 * sw
		return [{"t": G_RING, "c": C[4], "p": Vector2(0, y), "r": RO * sc + 3.0, "w": 13.0, "k": 0.32 + 0.25 * sw},
			{"c": C[6], "p": Vector2(0, y), "r": 6.0, "k": 0.12 + 0.2 * sw}])
	var star := body("Star", "star", {"ink": Color("#1a0e04")})
	per_frame(star, "material:shader_parameter/cy", func(i: int, t: float) -> float: return hover(t))
	per_frame(star, "material:shader_parameter/rot", func(i: int, t: float) -> float: return 0.22 * sin((t / D) * TAU))
	per_frame(star, "material:shader_parameter/sc", func(i: int, t: float) -> float: return 1.0 + 0.13 * swell(t / D))
	var sparks := []
	var specks := []
	var pops := []
	for i in NF:
		var t := ft(i)
		var ph := t / D
		var y := hover(t)
		var sw := swell(ph)
		var rot := 0.22 * sin(ph * TAU)
		var sc := 1.0 + 0.13 * sw
		# on each beat a spark spins off every point
		var r := []
		for b in BEATS:
			var age := jmod(ph - b, 1.0) * D
			for j in 5:
				if age > 0.45:
					r.append(null)
					continue
				var a := rot + (j * TAU) / 5.0 - PI / 2.0
				var sp := 70.0 + rand([j, b * 10.0, 3]) * 30.0
				var tan_ := 35.0
				var vx := cos(a) * sp - sin(a) * tan_
				var vy := sin(a) * sp + cos(a) * tan_
				var p := fly(cos(a) * RO * sc, y + sin(a) * RO * sc, vx, vy, age, 60.0, 4.0)
				var k := 1.0 - age / 0.45
				r.append(glint_e(p.x, p.y, jround(2.0 * k), 8 if k > 0.5 else 6, 0.45 * k))
		sparks.append(r)
		# specks of light winking round it
		var f := floorf(ph * 24.0)
		r = []
		for j in 18:
			if rand([f + j * 3, j, seed_]) > 0.32:
				r.append(null)
				continue
			var a := rand([j, 1, seed_]) * TAU
			var d := 13.0 + rand([j, 2, seed_]) * 20.0
			var sy := y + sin(a) * d * 0.85
			r.append(dot_e(cos(a) * d, sy, 8 if rand([f, j, 5]) < 0.5 else 6) if sy < -2.0 else null)
		specks.append(r)
		# small stars popping one after another, and a glint on the top arm now and then
		r = []
		for j in 4:
			var life := 0.3
			var age := jmod(t - ((j + 0.3) / 4.0) * D, D)
			if age > life:
				r.append(null)
				continue
			var a := rand([j, 7, seed_]) * TAU
			var d := 15.0 + rand([j, 8, seed_]) * 12.0
			var k := sin((age / life) * PI)
			r.append(glint_e(cos(a) * d, y + sin(a) * d * 0.85, jround(2.5 * k), 6 if j % 2 else 8, 0.4 * k))
		var g := jmod(ph + 0.1, 0.5) / 0.5
		r.append(glint_e(-2.0 + rot * 4.0, y - 6.0, 3.0 * sin((g / 0.14) * PI), 8, 0.5) if g < 0.14 else null)
		pops.append(r)
	table("Sparks", K_GLINT, sparks)
	table("Specks", K_DOT, specks)
	table("Pops", K_GLINT, pops)
