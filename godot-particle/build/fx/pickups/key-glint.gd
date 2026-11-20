# reimagined-from: src/fx/pickups/key-glint.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Key glint: An ornate silver key hovering and rocking; a glint runs from its bow down the shaft to the teeth and bursts off the tip as falling sparks.
# loop, 2.00 s, 72x60 canvas, origin [36, 54], backdrop ground
# ramp palette: #0e1018 #222838 #3c4660 #5e6d8e #8c9cbc #bccae2 #e6eeff #ffffff
# The key is a canvas shader running the original's key pixel by pixel (fx/pickups/_key.gdshader): bow, collar, shaft
# and bit shaded by which way the metal faces, the glint's white band running down it; its bob, rock and the band
# keyed every frame. Its cool light, the light along it and the light riding the glint are keyed lights. The idle
# twinkles, the star bursting off the tip and the sparks arcing away and falling are particles placed frame by frame
# where the original draws them (the sparks as short 1 px streaks), each with its glow.
extends "res://build/fx/pickups/_pickups.gd"

const HOVER := 19.0
const MID := 8.0
const TIP := 17.5
const G0 := 0.18
const G1 := 0.5


func pose(ph: float) -> Dictionary:
	return {"y": -HOVER - 1.6 * sin(ph * TAU), "a": 0.42 + 0.11 * sin(ph * TAU + 0.9)}


static func to_world(u: float, v: float, cx: float, cy: float, a: float) -> Vector2:
	return Vector2(cx + (u - MID) * cos(a) - v * sin(a), cy + (u - MID) * sin(a) + v * cos(a))


func glint_q(ph: float) -> float:
	return (ph - G0) / (G1 - G0)


func glint_u(ph: float) -> float:
	var q := glint_q(ph)
	return -5.0 + (TIP + 7.0) * in_out_sine(q) if q > 0.0 and q < 1.0 else -100.0


func make() -> void:
	var seed_ := 7
	shadow("Shadow", func(i: int, t: float) -> Array:
		var y: float = pose(t / D).y
		return [0.0, 10.0, 0.8 - (-y - HOVER + 1.6) * 0.06], {"span": 14})
	glows("Glow", func(i: int, t: float) -> Array:
		var ph := t / D
		var q := pose(ph)
		var y: float = q.y
		var a: float = q.a
		var l := [{"c": C[4], "p": Vector2(0, y), "r": 24.0, "k": 0.3},
			{"t": G_LINE, "c": C[5], "p": to_world(0, 0, 0, y, a), "q": to_world(TIP, 0, 0, y, a), "r": 7.0, "k": 0.16}]
		var gu := glint_u(ph)
		if gu > -6.0:
			l.append({"c": C[6], "p": to_world(clampf(gu, 0.0, TIP), 0, 0, y, a), "r": 10.0, "k": 0.45 * sin(glint_q(ph) * PI)})
		return l)
	var key_ := body("Key", "key")
	per_frame(key_, "material:shader_parameter/cy", func(i: int, t: float) -> float: return pose(t / D).y)
	per_frame(key_, "material:shader_parameter/ca", func(i: int, t: float) -> float: return cos(pose(t / D).a))
	per_frame(key_, "material:shader_parameter/sa", func(i: int, t: float) -> float: return sin(pose(t / D).a))
	per_frame(key_, "material:shader_parameter/gu", func(i: int, t: float) -> float: return glint_u(t / D))
	var twinkles := []
	var tips := []
	var sparks := []
	for i in NF:
		var t := ft(i)
		var ph := t / D
		var q := pose(ph)
		var y: float = q.y
		var a: float = q.a
		# a few idle twinkles round it, one after another
		var r := []
		for j in 4:
			var life := 0.4
			var age := jmod(t - ((j + 0.6) / 4.0) * D, D)
			if age > life:
				r.append(null)
				continue
			var an := rand([j, seed_, 8]) * TAU
			var d := 9.0 + rand([j, seed_, 9]) * 6.0
			var k := sin((age / life) * PI)
			r.append(glint_e(cos(an) * d, y + sin(an) * d * 0.8 - age * 6.0, jround(1.8 * k), 6 if j % 2 else 8, 0.35 * k))
		twinkles.append(r)
		# as the glint leaves the tip: a star, and sparks that arc away and fall
		var tp := to_world(TIP, 0, 0, y, a)
		var at_ := (ph - G1 + 0.02) * D
		tips.append([glint_e(tp.x, tp.y, 4.5 * (1.0 - at_ / 0.3), 6, 0.6 * (1.0 - at_ / 0.3)) if at_ > 0.0 and at_ < 0.3 else null])
		r = []
		for j in 9:
			var life := 0.32 + rand([j, seed_, 4]) * 0.3
			var age := at_ - rand([j, seed_, 5]) * 0.05
			if age < 0.0 or age > life:
				r.append(null)
				continue
			var sp := 25.0 + rand([j, seed_, 1]) * 45.0
			var an := a + (rand([j, seed_, 2]) - 0.5) * 2.2
			var v0 := Vector2(cos(an) * sp, sin(an) * sp - 25.0)
			var f := (1.0 - exp(-2.5 * age)) / 2.5
			var vt := 380.0 / 2.5
			var x := tp.x + v0.x * f
			var yy := tp.y + vt * age + (v0.y - vt) * f
			var e := exp(-2.5 * age)
			var vx := v0.x * e
			var vy := vt + (v0.y - vt) * e
			if yy > -0.5:
				r.append(null)
				continue
			var s := sqrt(vx * vx + vy * vy)
			if s == 0.0:
				s = 1.0
			var l2 := minf(4.0, 1.0 + s * 0.03)
			var k := 1.0 - age / life
			var x0 := floorf(x - (vx / s) * l2)
			var y0 := floorf(yy - (vy / s) * l2)
			r.append({"x": x0, "y": y0, "c": 5, "c2": 8, "a": k * 1.6, "e": [floorf(x) - x0, floorf(yy) - y0, 0.6, 0],
				"lp": Vector2(x, yy), "lr": 3.0, "lc": C[5], "lk": 0.4 * k})
		sparks.append(r)
	table("Twinkles", K_GLINT, twinkles)
	table("TipStar", K_GLINT, tips)
	table("Sparks", K_LINE, sparks)
