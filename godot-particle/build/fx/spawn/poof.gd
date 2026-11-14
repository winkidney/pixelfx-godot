# reimagined-from: src/fx/spawn/poof.js@21beaeee7a5b83d79bae533862b967f901312956
# Poof: A cartoon death poof: a white pop, a ring of soft round smoke balls bursting out between speed lines, little stars spinning off, and the cloud lifting and thinning away.
# one-shot, 1.60 s, 112x92 canvas, origin [56.0, 80.0], backdrop ground
# ramp palette: #2a2440 #5e5878 #9a94b4 #cdc8e0 #f2f0fa #ffffff
# ramp stars: #ffd84a #fff3a6 #ffffff
# The original's own update() runs here with its seeded draws: the 21 smoke balls (thrown out, stopped by drag,
# swelling, breathing and shrinking ball by ball) are tracked GPU particles drawn in three passes (shade, body, cap:
# fx/spawn/_ball.gdshader) so they merge into one lumpy cloud; the 12 speed lines are tracked particles too (a 1 px
# line, fx/spawn/_seg.gdshader, with its light). The stars and the pip each ball leaves, and the dust skidding off
# the feet, are the original's Particles, tracked (_parts). The pop (two discs and a flare), the ring and
# the lights are keyed on the original's frames.
extends "res://build/fx/spawn/_spawn.gd"

const CY := -17.0


func radius(b: Dictionary) -> float:
	var age: float = b.max - b.life
	var u: float = age / b.max
	var grow: float = b.r0 + (b.r1 - b.r0) * out_back(clamp01(age / 0.22), 2.0)
	var breathe := 1.0 + 0.06 * sin(age * 14.0 + b.r1)
	return grow * breathe * (1.0 if u < 0.62 else 1.0 - in_back(clamp01((u - 0.62) / 0.38), 1.4))


func make() -> void:
	var S: PackedColorArray = root.ramps.stars
	var W := Color.WHITE
	R = JsRng.new(int(meta.options.seed))
	var ps := new_parts()
	ps.ground = 0.0
	var balls := []
	for i in 9:
		var a := (i / 9.0) * TAU + R.range(-0.2, 0.2)
		var sp := R.range(95, 140)
		var r := R.range(5, 7)
		var life := R.range(0.7, 1.05)
		var delay := R.range(0, 0.03)
		balls.append({"x": cos(a) * 3, "y": CY + sin(a) * 3, "vx": cos(a) * sp, "vy": sin(a) * sp * 0.8 - 12, "r0": r * 0.5, "r1": r, "life": life, "delay": delay})
	for i in 5:
		var a := R.range(0, TAU)
		var sp := R.range(20, 60)
		var r1 := R.range(6.5, 8.5)
		var life := R.range(0.85, 1.2)
		var delay := R.range(0.02, 0.06)
		balls.append({"x": cos(a) * 2, "y": CY + sin(a) * 2, "vx": cos(a) * sp, "vy": sin(a) * sp - 16, "r0": 4.0, "r1": r1, "life": life, "delay": delay})
	for i in 7:
		var a := R.range(0, TAU)
		var sp := R.range(170, 240)
		var r := R.range(2.2, 3.6)
		var life := R.range(0.32, 0.5)
		var delay := R.range(0.01, 0.04)
		balls.append({"x": cos(a) * 4, "y": CY + sin(a) * 4, "vx": cos(a) * sp, "vy": sin(a) * sp * 0.75 - 10, "r0": r * 0.6, "r1": r, "life": life, "delay": delay})
	for b in balls:
		b.max = b.life
		b.dead = false
	var lines := []
	for i in 12:
		var a := (i / 12.0) * TAU + R.range(-0.12, 0.12) + 0.13
		var sa := sin(a)
		var r1 := minf(R.range(24, 34), (-2.0 - CY) / sa if sa > 0.1 else 99.0)
		lines.append({"a": a, "r1": r1, "d": R.range(0, 0.04)})
	for i in 7:
		var a := R.range(-PI, 0.3)
		var sp := R.range(70, 125)
		var life := R.range(0.55, 0.95)
		var col: Color = R.pick([S[2], S[1], S[1], S[0]])
		var sz := R.range(1.3, 2.4)
		var dl := R.range(0.02, 0.1)
		ps.spawn(STAR, cos(a) * 6, CY + sin(a) * 6, cos(a) * sp, sin(a) * sp - 30, life, col, sz, dl)
	for i in 10:
		var a := R.range(0, TAU)
		var sp := R.range(40, 110)
		var life := R.range(0.3, 0.6)
		var col: Color = R.pick([W, S[1]])
		var dl := R.range(0, 0.08)
		ps.spawn(STAR, cos(a) * 5, CY + sin(a) * 5, cos(a) * sp, sin(a) * sp - 20, life, col, 0.6, dl)
	for i in 6:
		var s := R.sign()
		var x := s * R.range(1, 6)
		var vx := s * R.range(25, 70)
		var vy := -R.range(2, 10)
		var life := R.range(0.4, 0.7)
		var sz := R.range(1.6, 3)
		var dl := R.range(0.02, 0.08)
		ps.spawn(DUST, x, -1, vx, vy, life, C[2], sz, dl)

	# the original's update(), recorded 60 times a second
	var bt := new_track(3)
	var lt := new_track(2)
	var clock := [0.0]
	var step := func(dt: float) -> void:
		clock[0] += dt
		for i in range(balls.size() - 1, -1, -1):
			var b: Dictionary = balls[i]
			if b.dead:
				continue
			if b.delay > 0:
				b.delay -= dt
				continue
			b.life -= dt
			if b.life <= 0:
				# each ball goes with a pip of light
				if b.r1 > 4:
					ps.spawn(STAR, b.x, b.y, 0, -8, 0.22, W, 0.6)
				b.dead = true
				continue
			b.vx -= b.vx * 7 * dt
			b.vy -= b.vy * 7 * dt + 30 * dt
			b.x += b.vx * dt
			b.y = minf(b.y + b.vy * dt, -radius(b) * 0.7)
		ps.update(dt)
	var rec := func(s: int) -> void:
		var t: float = clock[0]
		ps.record(s)
		for i in balls.size():
			var b: Dictionary = balls[i]
			if b.dead or b.delay > 0:
				continue
			var age: float = b.max - b.life
			var r := radius(b)
			if r < 0.6:
				continue
			var a := minf(1.0, age * 20.0)
			var lit := age < 0.12
			var hy: float = (b.y - CY + 6) / 14.0
			var lo := hy > 0.4
			var hi := hy < -0.3
			var cap := -1.0
			if not lo or lit:
				cap = 6.0 if (lit or hi) else 4.0
			bt.put(i, s, 0, Color(b.x, b.y, 1.0, r))
			bt.put(i, s, 1, Color(3.0 if lit else 1.0 if lo else 2.0, 4.0 if lit else 2.0 if lo else 3.0, cap, a))
			bt.put(i, s, 2, Color(0.9 * a * (1.0 - age / 0.25) if (age < 0.25 and cap >= 0.0) else 0.0, 0, 0, 0))
		for i in lines.size():
			var l: Dictionary = lines[i]
			var u: float = (t - l.d) / 0.2
			if u <= 0.0 or u >= 1.0:
				continue
			var head: float = 8.0 + (l.r1 - 8.0) * out_expo(clamp01(u / 0.6))
			var tail: float = 8.0 + (l.r1 - 8.0) * in_cubic(u)
			var dir := Vector2(cos(l.a), sin(l.a))
			lt.put(i, s, 0, Color(0, CY, 1.0, 1.0))
			lt.put(i, s, 1, Color(dir.x * tail, dir.y * tail, dir.x * head, dir.y * head))
	run(step, rec)

	# behind: the light of the pop on the floor where the body stood, the dust skidding off the feet
	glow_fn("FloorLight", Vector2(0, -1), 26, C[4], func(t: float) -> float: return 0.25 * (1.0 - smooth(0.1, 0.9, t)), 0.0, 0.92)
	# the cloud: every shade, then every body, then the caps
	var pal := [C[0], C[1], C[2], C[3], C[4], C[5], W, W]
	for layer in [["BallShade", 0], ["BallBody", 1], ["BallCap", 2]]:
		track(layer[0], bt, ssh("ball"), 27, {"layer": layer[1], "pal": pal, "hl_color": W}, {"layer": "soft"})
	# the pop: a white ball in a pale one and an 8-ray flare, for its first three frames
	var outer := ring("PopOuter", 13, {"radius": 9, "color": C[4]}, {"at": Vector2(0, CY)})
	var inner := ring("PopInner", 11, {"radius": 7, "color": W}, {"at": Vector2(0, CY)})
	var fl := shape("PopFlare", load("res://addons/pixelfx_particles/fx/arcane/_flare.gdshader"), Vector2(45, 45),
		{"len": 20, "k": 1.0, "white": W, "c_hi": C[4], "c_lo": C[3]}, {"at": Vector2(0.5, CY + 0.5)})
	keyf(outer, "material:shader_parameter/radius", func(t: float) -> float: return 9.0 + 3.0 * t / 0.07, 0.0, 0.07, 30.0, "nearest")
	keyf(inner, "material:shader_parameter/radius", func(t: float) -> float: return 7.0 + 3.0 * t / 0.07, 0.0, 0.07, 30.0, "nearest")
	keyf(fl, "material:shader_parameter/len", func(t: float) -> float: return 20.0 * (1.0 - t / 0.07 * 0.5), 0.0, 0.07, 30.0, "nearest")
	keyf(fl, "material:shader_parameter/k", func(t: float) -> float: return 1.0 - t / 0.07, 0.0, 0.07, 30.0, "nearest")
	for n in [outer, inner, fl]:
		steps(n, "visible", [[0.0, true], [0.07, false]])
	# then a ring rolling out, white at first, dithering away
	var rg := ring("PopRing", 27, {"radius": 8, "thickness": 2.5, "color": W, "alpha": 0.0}, {"at": Vector2(0, CY)})
	var rk := func(t: float) -> float: return (t - 0.03) / 0.2
	keyf(rg, "material:shader_parameter/radius", func(t: float) -> float: return 8.0 + 18.0 * out_cubic(rk.call(t)), 0.0, 0.3, 30.0, "nearest")
	keyf(rg, "material:shader_parameter/thickness", func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - rk.call(t))), 0.0, 0.3, 30.0, "nearest")
	keyf(rg, "material:shader_parameter/color", func(t: float) -> Color: return W if rk.call(t) < 0.3 else C[4], 0.0, 0.3, 30.0, "nearest")
	keyf(rg, "material:shader_parameter/alpha", func(t: float) -> float: return clampf(1.1 - rk.call(t), 0.0, 1.0) if (rk.call(t) > 0.0 and rk.call(t) < 1.0) else 0.0, 0.0, 0.3, 30.0, "nearest")
	# the speed lines flicked out between the balls, and their light
	track("SpeedLines", lt, ssh("seg"), 73, {"tail_c": C[4], "head_c": W, "split": 0.6})
	track("SpeedLinesLight", lt, ssh("seg_light"), 81, {"color": C[4], "radius": 3.0, "k": 0.25}, {"layer": "light"})
	# the stars, the pips, the dust
	parts("Parts", ps, {"sparks": [W, S[1], S[0], C[2]]})
	light_add("PopLight", Vector2(0, CY), 46, C[4], 0.8, 0.4)
	light_add("PopHot", Vector2(0, CY), 22, W, 0.8, 0.1)
