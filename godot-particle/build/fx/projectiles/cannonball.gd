# reimagined-from: src/fx/projectiles/cannonball.js@d68a7c99e5b0b158bf7b162c76d004afabc1530a
# Cannon shot: A cannon fires from a muzzle `height` px above the floor (the origin): a white flash, a tongue of flame, the ball arcing off trailing smoke, a big gunsmoke cloud rolling out.
# one-shot, 3.80 s, 208x116 canvas, origin [48.0, 102.0], backdrop ground
# Everything the original spawns comes from its own Rng in its own order (projectiles/_projectiles.gd Rng), its
# update replayed at 120 Hz: the flash is its lobes (flash(): a white ball with a tongue of flame, then a cooler,
# bigger burst, three frames) under a white disc; the sparks, burning wadding and embers are GPU particles with its
# physics (_muzzle.gd bits(), bouncing on the floor, with points of light); the gunsmoke is its puffs as GPU
# particles (smoke_puffs(): a great shove out of the bore that slows, rolls over itself, swells and lifts, lit warm
# by the flash, and the thin wisp the ball leaves off its hot skin, each puff born where the ball was); the ball is
# a small iron sprite (drawn at build time: dark iron, a lit crescent, a hot glint) keyed along its arc, glowing
# while the flash still burns on it; the flash's lights die away and the floor catches the pop.
extends "res://build/fx/projectiles/_muzzle.gd"

const ANG := -0.32
const F1 := 1.0 / 30.0


func ball_tex(file: String, IR: PackedColorArray, glint: Color) -> Texture2D:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 9:
			var p := Vector2(x - 4 + 0.5, y - 4 + 0.5) - Vector2(0.5, 0.5)
			if p.length() <= 3.2:
				img.set_pixel(x, y, IR[0])
			if p.length() <= 2.6:
				img.set_pixel(x, y, IR[1])
			if (p - Vector2(-0.7, -0.7)).length() <= 1.8:
				img.set_pixel(x, y, IR[2])
	img.set_pixel(3, 2, IR[3])
	img.set_pixel(2, 3, IR[3])
	img.set_pixel(5, 5, glint)
	return asset(file, img)


func burst_light(name: String, at: Vector2, r: float, c: Color, k: float, life: float) -> void:
	var g := light_at(name, at, r, c, k)
	var n := int(ceilf(life * 30.0)) + 1
	key_frames(g, "material:shader_parameter/radius", n, func(t: float) -> float: return r * (0.55 + 0.45 * maxf(0.0, 1.0 - t / life)))
	key_frames(g, "material:shader_parameter/alpha", n, func(t: float) -> float: return k * pow(maxf(0.0, 1.0 - t / life), 2.0))


func make() -> void:
	var F := pal("palette")
	var SM := pal("smoke")
	var IR := pal("iron")
	var D: float = root.duration
	var H: float = meta.options.height
	var MY := -H
	var R := Rng.new(int(meta.options.seed))
	var ca := cos(ANG)
	var sa := sin(ANG)
	var right := float(root.canvas_size.x - root.origin.x - 3)
	var top := -float(root.origin.y) + 3.0
	var ball := {"x": 4.0, "y": MY, "vx": ca * 330.0, "vy": sa * 330.0, "out": false}
	var jit := []
	for i in 16:
		jit.append(R.next())
	var bl := []
	for i in 22:
		var a := ANG + R.range(-0.45, 0.45)
		var sp := R.range(140, 380)
		spawn(bl, R, SPARK, 6, MY, cos(a) * sp, sin(a) * sp, R.range(0.1, 0.4))
	for i in 10:
		var a := ANG + R.range(-0.3, 0.3)
		var sp := R.range(70, 170)
		spawn(bl, R, SPARK, 6, MY, cos(a) * sp, sin(a) * sp, R.range(0.5, 0.9))
	for i in 8:
		var a := ANG + R.range(-0.5, 0.3)
		var sp := R.range(40, 110)
		spawn(bl, R, EMBER, 8, MY, cos(a) * sp, sin(a) * sp, R.range(0.7, 1.4), 2.0)
	var sl := []
	for i in 34:
		var a := ANG + R.range(-0.4, 0.35)
		var sp := R.range(40, 260) * (1.1 if i < 12 else 0.75)
		var q := {}
		q.x = 6.0 + R.range(0, 6)
		q.y = MY + R.range(-2, 2)
		q.vx = cos(a) * sp
		q.vy = sin(a) * sp
		q.r0 = R.range(3, 4.5)
		q.r1 = R.range(9, 16)
		q.life = R.range(2.7, 3.5)
		q.a = R.range(0.6, 0.75)
		q.b = R.range(0.9, 1)
		q.drag = R.range(2.2, 3.2)
		q.rise = R.range(7, 13)
		q.grow = R.range(1.5, 2.4)
		q.curl = R.range(-1.2, 0.4)
		q.warm = 1.0
		q.delay = R.range(0, 0.05)
		smoke_add(sl, R, q)
	# the flight at 120 Hz: the ball's arc, and the wisp it leaves, one puff every two pixels
	var path := {}
	var t := 0.0
	var wisp := 0.0
	var dt := 1.0 / 120.0
	var out_t := D
	for step in int(D * 120.0) + 1:
		path[step] = Vector2(ball.x, ball.y)
		if ball.out:
			break
		var pt := t
		t += dt
		var x0: float = ball.x
		var y0: float = ball.y
		ball.vy += 260.0 * dt
		ball.x += ball.vx * dt
		ball.y += ball.vy * dt
		wisp += Vector2(ball.x - x0, ball.y - y0).length() / 2.0
		while wisp > 1.0:
			var f := R.next()
			var x: float = x0 + (ball.x - x0) * f
			var y: float = y0 + (ball.y - y0) * f
			if x < right - 8 and x > 24 and t < 0.6:
				var q := {"x": x - 3.0, "y": y, "vx": -ball.vx * 0.04, "vy": -ball.vy * 0.04, "r0": 1.0}
				q.r1 = R.range(2.5, 3.6) * (1.0 - t)
				q.life = R.range(0.7, 1.1)
				q.a = 0.5 * (1.0 - t)
				q.b = 0.95
				q.drag = 2.0
				q.rise = 5.0
				q.grow = 2.0
				q.delay = pt
				smoke_add(sl, R, q)
			wisp -= 1.0
		if ball.x > right or ball.y < top:
			ball.out = true
			out_t = t
	var pos := func(tt: float) -> Vector2:
		var s := clampi(int(roundf(tt * 120.0)), 0, path.size() - 1)
		return path[s]

	var pop := func(tt: float) -> float: return exp(-(tt + 0.008) / 0.06)
	var WR := PackedColorArray([SM[0], mixc(F[1], SM[1], 0.5), mixc(F[2], SM[2], 0.45), F[3], F[4], F[6], F[7]])
	var smoke := smoke_puffs("Smoke", sl, SM, WR, {"dens": 1.35, "max": 0.86, "lit": 1.3})
	key_frames(smoke, "process_material:shader_parameter/wmul", 24, func(tt: float) -> float: return 0.2 + pop.call(tt) * 1.3)

	bits("Bits", bl, [F[7], F[6], F[4], F[3]])

	# the ball: dark iron, a lit crescent, a hot glint where the flash still burns on it
	var nf := int(ceilf(out_t * 30.0))
	for hot in [true, false]:
		var b := sprite("BallHot" if hot else "Ball", ball_tex("ball_hot" if hot else "ball", IR, F[5] if hot else IR[2]), {"layer": "prop", "centered": false, "offset": Vector2(-4, -4)})
		key_frames(b, "position", nf + 1, func(tt: float) -> Vector2: return (pos.call(tt) as Vector2).round())
		var h: bool = hot
		b.visible = hot
		key_frames(b, "visible", nf + 1, func(tt: float) -> bool: return tt < out_t - 1e-4 and (tt < 0.3) == h)
	var bg := light_at("BallGlow", Vector2(4, MY), 6, F[4], 0.45)
	key_frames(bg, "position", nf + 1, func(tt: float) -> Vector2: return pos.call(tt))
	key_frames(bg, "material:shader_parameter/alpha", nf + 1, func(tt: float) -> float: return 0.45 * clampf(1.0 - tt / 0.5, 0.0, 1.0) if tt < out_t - 1e-4 else 0.0)

	# the flash: a white ball with a tongue of flame for a frame, then a cooler, bigger burst as the gas spills
	var cols := [[Color.WHITE, F[7], F[6], F[3]], [F[7], F[6], F[4], F[2]], [F[5], F[4], F[3], F[1]]]
	for f in [1, 2, 3]:
		var k := (1.0 if f == 1 else 1.15 if f == 2 else 0.8) * 1.3
		var L := [{"off": 0.0, "a": 0.0, "len": 12.0 * k, "wid": 5.0 * k, "core": 0.55}, {"off": 2.0, "a": 0.0, "len": (24.0 + jit[0] * 8.0) * k, "wid": 2.2 * k, "core": 0.4}]
		for i in 6:
			var a: float = (-1.0 if i < 3 else 1.0) * (0.4 + (i % 3) * 0.45 + jit[i + 1] * 0.2)
			var down := sin(ANG + a)
			var ln: float = (8.0 + jit[i + 7] * 7.0) * k * (0.7 if f == 3 else 1.0)
			if down > 0.1:
				ln = minf(ln, (H - 3.0) / down)
			L.append({"off": 2.0, "a": a, "len": ln, "wid": 1.6 * k, "core": 0.25})
		var fl := flash("Flash%d" % f, Vector2(4, MY), ANG, L, cols[f - 1], f)
		var ff: int = f
		fl.visible = f == 1
		key_frames(fl, "visible", 6, func(tt: float) -> bool: return tt < 3 * F1 and (1 if tt < F1 else 2 if tt < 2 * F1 else 3) == ff)
	var disc := ring("FlashBall", 8, {"radius": 6.5, "color": Color.WHITE, "edge": 1.0, "edge_color": F[7]}, {"at": Vector2(7, MY - 1)})
	key_frames(disc, "visible", 3, func(tt: float) -> bool: return tt < F1)

	# light: the flash's warm burst and white heart dying away, the floor catching the pop
	burst_light("Burst", Vector2(12, MY - 2), 44, Color("#ffb060"), 1.0, 0.35)
	burst_light("Heart", Vector2(6, MY), 18, Color.WHITE, 0.9, 0.08)
	pop_light("FloorPop", Vector2(14, 0), 22, F[4], 0.25, pop, 0.0, 0.6)
