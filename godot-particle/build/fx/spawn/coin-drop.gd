# reimagined-from: src/fx/spawn/coin-drop.js@82bdaf0e54c7d35a6f400ce69839830121e82415
# Coin drop: An enemy goes up in a soft poof and gold coins spin out of it, bounce with a glint on each hit, settle on the floor, twinkle, and wink out one by one.
# one-shot, 3.00 s, 160x88 canvas, origin [80.0, 78.0], backdrop ground
# ramp palette: #2a1606 #5c3208 #9a5a0c #d48c14 #f5b82a #ffe066 #fff6c4 #ffffff
# ramp smoke: #3a3450 #6c6688 #a8a2c0 #dcd8ea
# The original's own update() runs here with its seeded draws. The poof's ten smoke balls are tracked GPU particles
# drawn in three passes (fx/spawn/_ball.gdshader); the coins are tracked particles drawn as the original draws them
# (fx/spawn/_coin.gdshader: spinning, flat on the floor with a glint, winking out with a star and a ring) with their
# light (_coin_light); the stars, the tinks and dust at each bounce are the original's Particles, tracked (_parts);
# the lights it adds at each bounce and wink are tracked (_lamps), the pop's keyed glows.
extends "res://build/fx/spawn/_spawn.gd"

const CY := -16.0


func make() -> void:
	var SM: PackedColorArray = root.ramps.smoke
	var W := Color.WHITE
	R = JsRng.new(int(meta.options.seed))
	var ps := new_parts()
	ps.ground = 0.0
	var lm := new_lamps()
	var balls := []
	for i in 10:
		var a := (i / 10.0) * TAU + R.range(-0.25, 0.25)
		var sp := R.range(60, 100)
		var life := R.range(0.55, 0.85)
		var r := R.range(4, 6)
		balls.append({"x": cos(a) * 2, "y": CY + sin(a) * 2, "vx": cos(a) * sp, "vy": sin(a) * sp * 0.7 - 10, "r": r, "life": life, "max": life, "dead": false})
	var coins := []
	var n: int = int(meta.options.coins)
	for i in n:
		var u := i / float(n - 1) - 0.5 if n > 1 else 0.0
		var a := -PI / 2 + u * 1.6 + R.range(-0.1, 0.1)
		var sp := R.range(230, 300)
		var x := R.range(-3, 3)
		var ph := R.range(0, TAU)
		var w := R.range(9, 15)
		w *= R.sign()
		var out := 2.15 + i * 0.07 + R.range(0, 0.1)
		var glint := R.range(1.2, 1.9)
		var born := R.range(0.04, 0.12)
		coins.append({"x": x, "y": CY, "vx": cos(a) * sp * 0.4, "vy": sin(a) * sp, "ph": ph, "w": w, "rest": false, "hits": 0, "out": out,
			"glint": glint, "born": born, "gone": false, "rest_at": 0.0})
	for i in 8:
		var a := R.range(0, TAU)
		var sp := R.range(50, 120)
		var life := R.range(0.3, 0.6)
		var col: Color = R.pick([W, C[6], C[5]])
		var sz := R.range(0.8, 1.8)
		ps.spawn(STAR, 0, CY, cos(a) * sp, sin(a) * sp - 20, life, col, sz)
	# the pop's two lights are there from the first frame (a frame particles can't show): keyed glows

	var bt := new_track(3)
	var ct := new_track(2)
	var clock := [0.0]
	var step := func(dt: float) -> void:
		clock[0] += dt
		var t: float = clock[0]
		for i in range(balls.size() - 1, -1, -1):
			var b: Dictionary = balls[i]
			if b.dead:
				continue
			b.life -= dt
			if b.life <= 0:
				b.dead = true
				continue
			b.vx -= b.vx * 7 * dt
			b.vy -= b.vy * 7 * dt + 26 * dt
			b.x += b.vx * dt
			b.y += b.vy * dt
		for c in coins:
			# a coin winks out with a little burst of gold
			if not c.gone and t >= c.out:
				c.gone = true
				for j in 5:
					var a := R.range(-PI, 0)
					var sp := R.range(25, 60)
					var life := R.range(0.3, 0.55)
					var col: Color = R.pick([W, C[6], C[5]])
					var sz := R.range(0.7, 1.4)
					ps.spawn(STAR, c.x, -3, cos(a) * sp, sin(a) * sp, life, col, sz)
				lm.add(c.x, -3, 14, C[5], 0.6, 0.2)
			if t < c.born or t > c.out or c.rest:
				continue
			c.vy += 820 * dt
			c.vx -= c.vx * 0.4 * dt
			c.x += c.vx * dt
			c.y += c.vy * dt
			c.ph += c.w * dt
			if c.y >= -1.5 and c.vy > 0:
				c.y = -1.5
				c.hits += 1
				# a tink of light and a puff of dust at each hit
				ps.spawn(STAR, c.x, -3, 0, -8, 0.25, W, 2.2 if c.hits == 1 else 1.4)
				for j in 2:
					var x: float = c.x + R.range(-1, 1)
					var s := R.sign()
					var vx := s * R.range(8, 24)
					var vy := -R.range(2, 8)
					var life := R.range(0.25, 0.45)
					var sz := R.range(1, 1.8)
					ps.spawn(DUST, x, -0.5, vx, vy, life, SM[1], sz)
				lm.add(c.x, -3, 12, C[5], 0.5, 0.15)
				if c.vy > 110:
					c.vy *= -0.45
					c.vx *= 0.7
					c.w = c.w * 0.8 + R.range(-2, 2)
				else:
					c.rest = true
					c.vx = 0.0
					c.vy = 0.0
					c.rest_at = t
		ps.update(dt)
		lm.step(dt)
	var rec := func(s: int) -> void:
		var t: float = clock[0]
		for i in balls.size():
			var b: Dictionary = balls[i]
			if b.dead:
				continue
			var age: float = b.max - b.life
			var k: float = b.life / b.max
			var r: float = b.r * (0.6 + 0.6 * out_cubic(clamp01(age / 0.2))) * (k / 0.35 if k < 0.35 else 1.0)
			if r < 0.6:
				continue
			bt.put(i, s, 0, Color(b.x, b.y, 1.0, r))
			bt.put(i, s, 1, Color(1, 1 if b.y > CY + 2 else 2, 3 if b.y < CY + 2 else -1, 1.0))
		for i in coins.size():
			var c: Dictionary = coins[i]
			if t < c.born or t > c.out + 0.12:
				continue
			if t > c.out:
				# a coin winks out with a last flash and a ring
				var k: float = (t - c.out) / 0.12
				ct.put(i, s, 0, Color(c.x, c.y, 1.0, 3.0))
				ct.put(i, s, 1, Color(roundf(5 * (1 - k)), 2 + 5 * out_cubic(k), clampf(1.1 - k, 0.0, 1.0), 0))
			elif c.rest:
				# flat on the floor; now and then a glint runs over it
				var g: float = fmod(t - c.rest_at + c.glint, 0.95) / 0.95
				ct.put(i, s, 0, Color(c.x, c.y, 1.0, 2.0))
				ct.put(i, s, 1, Color(roundf(3 * sin((g / 0.2) * PI)) if g < 0.2 else 0.0, 0, 0, 0))
			else:
				ct.put(i, s, 0, Color(c.x, c.y, 1.0, 1.0))
				ct.put(i, s, 1, Color(cos(c.ph), 1.0 if absf(cos(c.ph)) > 0.96 else 0.0, 0, 0))
		ps.record(s)
		lm.record(s)
	run(step, rec)

	# the poof: soft, top-lit balls (every shade, then every body, then the caps)
	var pal := [SM[0], SM[1], SM[2], SM[3], SM[3], SM[3], SM[3], SM[3]]
	for layer in [["BallShade", 0], ["BallBody", 1], ["BallCap", 2]]:
		track(layer[0], bt, ssh("ball"), 15, {"layer": layer[1], "pal": pal, "shade_d": Vector3(0.15, 0.2, 1.0), "body_d": Vector3(-0.06, -0.08, 0.86),
			"cap_d": Vector3(-0.28, -0.34, 0.4), "alphas": Vector3(0.8, 0.85, 0.85)}, {"layer": "soft"})
	# the pop: a white ball in a pale one and an 8-ray flare, for its first three frames
	var outer := ring("PopOuter", 11, {"radius": 8, "color": C[6]}, {"at": Vector2(0, CY)})
	var inner := ring("PopInner", 9, {"radius": 6, "color": W}, {"at": Vector2(0, CY)})
	var fl := shape("PopFlare", load("res://addons/pixelfx_particles/fx/arcane/_flare.gdshader"), Vector2(45, 45),
		{"len": 16, "k": 1.0, "white": W, "c_hi": C[6], "c_lo": C[5]}, {"at": Vector2(0.5, CY + 0.5)})
	keyf(outer, "material:shader_parameter/radius", func(t: float) -> float: return 8.0 + 2.0 * t / 0.07, 0.0, 0.07, 30.0, "nearest")
	keyf(inner, "material:shader_parameter/radius", func(t: float) -> float: return 6.0 + 2.0 * t / 0.07, 0.0, 0.07, 30.0, "nearest")
	keyf(fl, "material:shader_parameter/len", func(t: float) -> float: return 16.0 * (1.0 - t / 0.07 * 0.5), 0.0, 0.07, 30.0, "nearest")
	keyf(fl, "material:shader_parameter/k", func(t: float) -> float: return 1.0 - t / 0.07, 0.0, 0.07, 30.0, "nearest")
	for nd in [outer, inner, fl]:
		steps(nd, "visible", [[0.0, true], [0.07, false]])
	# the coins and their light
	var cpal := []
	for i in 8:
		cpal.append(C[i])
	track("Coins", ct, ssh("coin"), 21, {"pal": cpal, "white": W})
	track("CoinsLight", ct, ssh("coin_light"), 33, {"pal": cpal, "white": W}, {"layer": "light"})
	# the stars, the tinks, the dust
	parts("Parts", ps, {"sparks": [W, C[6], C[5], C[3]]})
	light_add("PopLight", Vector2(0, CY), 44, C[4], 0.7, 0.4)
	light_add("PopHot", Vector2(0, CY), 20, W, 0.7, 0.1)
	lamps("Lights", lm)
