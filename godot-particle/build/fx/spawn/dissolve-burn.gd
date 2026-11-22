# reimagined-from: src/fx/spawn/dissolve-burn.js@22b57740bdec7b747ad75baf7ab3c24e16154739
# Dissolve burn: An ember seam lights at the feet and climbs the body: above it the body scorches and smoulders, at it flames lick up, below it there's only falling ash, embers and smoke.
# one-shot, 3.60 s, 96x112 canvas, origin [48.0, 100.0], backdrop ground, stand-in 2
# ramp ash: #3a3436 #6a6266 #a39a9c
# ramp palette: #1a0806 #4a160c #8a2a10 #d0541a #ff8a2a #ffc23d #ffe680 #ffffff
# The original's own update() runs here with its seeded draws, its Particles included (fx/spawn/_spawn.gd Parts: the
# grit that may skip off the floor and the fire that leaves smoke draw from its generator too). The body is drawn in
# place of the stand-in from its own pixels (fx/spawn/_burn_body.gdshader: the seam climbing from the feet, white-hot,
# charred and browned above it, with its tongues of flame on the original's noise). Every pixel the seam passes goes
# to ash, an ember, a lick of fire or smoke, and the seam throws off smoke, fire and embers as it climbs: hundreds of
# tracked GPU particles drawn as the original draws each kind (fx/spawn/_parts.gdshader, with their light). The
# seam's light, the floor's glow and the ignition's light are keyed on the original's formulas.
extends "res://build/fx/spawn/_spawn.gd"

const IGNITE := 0.15
const BURN := 1.9
const CHAR := [Color8(0x10, 0x09, 0x08), Color8(0x22, 0x13, 0x0e), Color8(0x3a, 0x20, 0x16)]


static func front(t: float) -> float:
	return -0.04 + 1.1 * in_out_sine(clamp01((t - IGNITE) / BURN))


func make() -> void:
	var A: PackedColorArray = root.ramps.ash
	R = JsRng.new(int(meta.options.seed))
	var body := body_of(C)
	var H: float = body.h
	var by: float = body.y
	var keymap := Image.create(body.w, body.h, false, Image.FORMAT_RGBAF)
	for b in body.list:
		b.key = (body.h - 1 - b.my) / H + 0.08 * (rand([b.mx, b.my, 3]) - 0.5) + 0.06 * noise(b.mx * 0.35, 4) - (0.02 if b.edge else 0.0)
		b.gone = false
		keymap.set_pixel(b.mx, b.my, Color(b.key, 0, 0, 1))
	var ps := new_parts(30.0)
	ps.ground = 0.0
	var lm := new_lamps()
	var clock := [0.0]
	var dur: float = root.duration
	var left := func(a: float, b: float) -> float: return maxf(0.05, minf(R.range(a, b), dur - 0.1 - clock[0]))
	var tongues := []
	for i in 6:
		tongues.append(Vector3(-9 + i * 3.6 + rand([i, 1]) * 1.5, 6 + rand([i, 2]) * 6, i * 13))

	var step := func(dt: float) -> void:
		clock[0] += dt
		var t: float = clock[0]
		var f := front(t)
		for b in body.list:
			if b.gone or b.key >= f:
				continue
			b.gone = true
			# a burnt pixel goes to ash that sifts down, an ember that rises, or a lick of flame
			var r := R.next()
			if r < 0.2:
				if b.y > -7:
					var vx := R.range(-12, 12)
					var vy := R.range(-20, 0)
					var life: float = left.call(0.6, 1.2)
					var col: Color = R.pick(Array(A))
					ps.spawn(GRIT, b.x, b.y, vx, vy, life, col, 1)
				else:
					var vx := R.range(-10, 10)
					var vy := R.range(-8, 4)
					var life: float = left.call(0.5, minf(1.5, -b.y / 18.0))
					var col: Color = R.pick(Array(A))
					var sz := 1.4 if R.chance(0.2) else 1.0
					ps.spawn(FLAKE, b.x, b.y, vx, vy, life, col, sz)
			elif r < 0.32:
				var vx := R.range(-12, 12)
				var vy := -R.range(15, 45)
				var life: float = left.call(0.6, 1.4)
				var sz := R.range(1, 1.6)
				ps.spawn(EMBER, b.x, b.y, vx, vy, life, C[5], sz)
			elif r < 0.46:
				var vx := R.range(-6, 6)
				var vy := -R.range(14, 30)
				var life := R.range(0.2, 0.42)
				var sz := R.range(1.2, 2.2)
				var fl := SMOKES if R.chance(0.5) else 0
				ps.spawn(FIRE, b.x, b.y, vx, vy, life, null, sz, 0, fl)
			elif r < 0.5:
				var vx := R.range(-5, 5)
				var vy := -R.range(14, 26)
				var life: float = left.call(1.2, 2)
				var sz := R.range(2, 3.4)
				ps.spawn(SMOKE, b.x, b.y - 2, vx, vy, life, mixc(A[1], C[1], 0.3), sz)
		# the feet catch with a spit of sparks and a puff of light
		if t >= IGNITE and t - dt < IGNITE:
			lm.add(0, -4, 34, C[4], 0.8, 0.4)
			for i in 10:
				var x := R.range(-8, 8)
				var vx := R.range(-80, 80)
				var vy := -R.range(40, 150)
				var life := R.range(0.2, 0.5)
				ps.spawn(SPARK, x, -1, vx, vy, life)
		# while it burns: steady embers and smoke off the front
		if f > 0 and f < 1.02:
			var fy := by + (1 - clamp01(f)) * H
			if R.chance(0.34):
				var x := R.range(-7, 7)
				var vx := R.range(-6, 6)
				var vy := -R.range(16, 30)
				var life: float = left.call(1.4, 2.4)
				var sz := R.range(2.6, 4.2)
				ps.spawn(SMOKE, x, fy - 5, vx, vy, life, mixc(A[1], C[3], 0.35), sz)
			if R.chance(0.5):
				var x := R.range(-9, 9)
				var vx := R.range(-6, 6)
				var vy := -R.range(18, 34)
				var life := R.range(0.18, 0.36)
				var sz := R.range(1.2, 2.4)
				var fl := SMOKES if R.chance(0.35) else 0
				ps.spawn(FIRE, x, fy, vx, vy, life, null, sz, 0, fl)
			if R.chance(0.15):
				var x := R.range(-9, 9)
				var vx := R.range(-15, 15)
				var vy := -R.range(30, 70)
				var life: float = left.call(0.8, 1.6)
				ps.spawn(EMBER, x, fy, vx, vy, life, C[5], 1.4)
		ps.update(dt)
		lm.step(dt)
	var rec := func(s: int) -> void:
		ps.record(s)
		lm.record(s)
	run(step, rec)

	# warm light on the floor while the body burns down to it
	var u := "material:shader_parameter/"
	var floor_light := glow_path("FloorLight", Vector2(0, -1), Vector2(0, -1), 30, C[4])
	keyf(floor_light, u + "k", func(t: float) -> float:
		var tt := jt(t)
		return 0.3 * smooth(0, IGNITE + 0.2, tt) * (1.0 - smooth(IGNITE + BURN * 0.6, IGNITE + BURN + 0.4, tt)))
	# the body, burning from the feet up, and its tongues of flame (the stand-in itself never shows)
	var actor := actor_node()
	steps(actor, "visible", [[0.0, false]])
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	var pal := []
	for i in 8:
		pal.append(C[i])
	var top := by - 18.0
	var bd := shape("Body", ssh("burn_body"), Vector2(body.w + 6, -top + 1), {"tex": tex, "keys": asset("_keys", keymap),
		"origin": Vector2(body.x, by), "pal": pal, "char_c": CHAR, "white": Color.WHITE, "tongues": PackedVector3Array(tongues)},
		{"at": Vector2(0, (top + 1) / 2.0)})
	key(bd, u + "t", [[0.0, 0.0], [root.duration, root.duration]])
	keyf(bd, u + "front", func(t: float) -> float: return front(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(bd, u + "frame", func(t: float) -> float: return float(floori(jt(t) * 30)), 0.0, -1.0, 60.0, "nearest")
	# light along the seam
	var fy := func(t: float) -> float: return by + (1.0 - clamp01(front(jt(t)))) * H
	var sk := func(t: float) -> float:
		var f := front(jt(t))
		return (1.0 - smooth(0.95, 1.05, f)) if (f > -0.02 and f < 1.05) else 0.0
	var fl := func(t: float) -> float: return 0.85 + 0.15 * noise(jt(t) * 11, 9)
	var seam := glow_path("SeamLine", Vector2(-11, by), Vector2(11, 0), 9, C[4])
	keyf(seam, u + "a", func(t: float) -> Vector2: return Vector2(-11, fy.call(t)))
	keyf(seam, u + "b", func(t: float) -> Vector2: return Vector2(11, fy.call(t)))
	keyf(seam, u + "k", func(t: float) -> float: return 0.45 * sk.call(t))
	for g in [["SeamGlow", 6.0, 56.0, C[4], 0.38], ["SeamHot", 2.0, 18.0, C[5], 0.28]]:
		var gl := glow_path(g[0], Vector2(0, by - g[1]), Vector2(0, -g[1]), g[2], g[3])
		var up: float = g[1]
		var kk: float = g[4]
		keyf(gl, u + "a", func(t: float) -> Vector2: return Vector2(0, fy.call(t) - up))
		keyf(gl, u + "b", func(t: float) -> Vector2: return Vector2(0, fy.call(t) - up))
		keyf(gl, u + "k", func(t: float) -> float: return kk * sk.call(t) * fl.call(t))
	# the ash, embers, fire, smoke and sparks; the ignition's light
	parts("Parts", ps, {"sparks": [C[6], C[5], C[4], C[3]]})
	lamps("Lights", lm)
