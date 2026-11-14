# reimagined-from: src/fx/spawn/disintegrate.js@adaf697b58c9a48d8f6ea83157dccda897e824c6
# Disintegrate: The character crackles with light, flashes white, then peels away from the head down: each pixel flares white-hot and streams off on the wind as a cooling mote of light.
# one-shot, 3.40 s, 176x100 canvas, origin [48.0, 86.0], backdrop ground, stand-in 2
# ramp accent: #7a3ae4 #b682ff #ecd2ff
# ramp palette: #120a26 #2a1658 #3d2f9c #3f68d4 #3fa8ec #86e0ff #d6f8ff #ffffff
# The original's own update() runs here with its seeded draws. The stand-in is the effect's Actor until the shudder;
# from then the body is drawn over its own pixels (fx/spawn/_dis_body.gdshader: shudder, white flash, the peel front
# heating each pixel white-hot), with the charge's crackling outline rolled each frame on the original's hash. Every
# pixel the front passes lets go as the original's mote (or a star): ~500 tracked GPU particles carried on its gusting
# wind and swirl (fx/spawn/_mote.gdshader, cooling down their ramps, tails when quick, with their light). The
# charge's streaks rushing in and the stars are the original's Particles, tracked (_parts); the floor band, the
# impacts' band shader; glows keyed on the original's formulas, its lights tracked (_lamps).
extends "res://build/fx/spawn/_spawn.gd"

const FLASH := 0.42
const WHITE_T := 0.07
const P0 := FLASH + WHITE_T
const PEEL := 1.2
const CORE_Y := -20.0


static func front(t: float) -> float:
	return -0.06 + 1.14 * in_out_sine(clamp01((t - P0) / PEEL))


static func gust(t: float) -> float:
	return 0.7 + 0.5 * (noise(t * 1.6, 11) * 0.5 + 0.5)


func make() -> void:
	var A: PackedColorArray = root.ramps.accent
	var W := Color.WHITE
	var wind: float = float(meta.options.wind)
	R = JsRng.new(int(meta.options.seed))
	var COOL := [[C[6], C[5], C[5], C[4]], [A[2], A[1], A[1], A[0]], [W, C[6], C[5], C[5]]]
	var body := body_of(C)
	var top: float = body.y
	var H: float = body.h
	var keymap := Image.create(body.w, body.h, false, Image.FORMAT_RGBAF)
	for b in body.list:
		var u: float = (b.y - top) / H
		b.key = u + 0.14 * (rand([b.mx, b.my, 3]) - 0.5) + 0.05 * noise(b.mx * 0.45, 7) - (0.03 if b.edge else 0.0)
		b.gone = false
		keymap.set_pixel(b.mx, b.my, Color(b.key, 1.0 if b.edge else 0.0, 0, 1))
	var lm := new_lamps()
	var ps := new_parts()
	ps.ground = 0.0
	ps.single = true
	var motes := []
	var flashed := [false]
	var clock := [0.0]

	var let_go := func(b: Dictionary) -> void:
		b.gone = true
		var lo: bool = b.y > -9 and R.chance(0.22)
		var kind := 2 if lo else (1 if R.chance(0.42) else (3 if R.chance(0.07) else 0))
		if kind == 3:
			var vx := R.range(-6, 14) * wind
			var vy := R.range(-26, -8)
			var life := R.range(0.6, 1.1)
			var col: Color = C[6] if R.chance(0.5) else W
			var sz := R.range(1, 2.2)
			ps.spawn(STAR, b.x, b.y, vx, vy, life, col, sz)
			return
		var life := R.range(0.7, 1.2) if kind == 2 else (R.range(0.25, 0.5) if kind == 1 else R.range(0.9, 1.7))
		# a pop off the body, outward from its middle and up, before the wind takes it
		var out: float = (b.x + 0.5) * R.range(2, 6)
		var vx: float = (out + R.range(-6, 16)) * (0.4 if kind == 2 else 1.0)
		var vy := R.range(-30, -8) if kind == 2 else R.range(-46, -8)
		var lift := R.range(0.4, 1.4)
		var cool: Array = COOL[1 if R.chance(0.3) else (2 if R.chance(0.3) else 0)]
		var own := R.chance(0.2)
		var sd := R.range(0, 100)
		motes.append({"i": motes.size(), "x": b.x + 0.5, "y": b.y + 0.5, "vx": vx, "vy": vy, "life": life, "max": life, "c": b.c, "kind": kind,
			"lift": lift, "cool": cool, "own": own, "rest": false, "seed": sd, "on": true})

	var step := func(dt: float) -> void:
		clock[0] += dt
		var t: float = clock[0]
		# the charge: light gathers into the body in streaks
		if t < FLASH - 0.05 and R.chance(0.55):
			var a := R.range(0, TAU)
			var D := R.range(22, 44)
			var T := R.range(0.16, 0.26)
			var v := (D * 3) / (exp(3 * T) - 1)
			var x := cos(a) * D
			var y := minf(CORE_Y + sin(a) * D * 0.9, -3)
			var l := Vector2(x, y - CORE_Y).length()
			if l == 0.0:
				l = 1.0
			var col: Color = C[6] if R.chance(0.5) else C[5]
			ps.spawn(STREAK, x, y, (-x / l) * v, ((CORE_Y - y) / l) * v, T, col)
		if not flashed[0] and t >= FLASH:
			flashed[0] = true
			lm.add(0, CORE_Y, 64, C[4], 0.85, 0.6)
			lm.add(0, CORE_Y, 30, W, 0.8, 0.14)
			for i in 14:
				var a := R.range(0, TAU)
				var sp := R.range(50, 150)
				var x := R.range(-6, 6)
				var y := CORE_Y + R.range(-10, 10)
				var life := R.range(0.35, 0.8)
				var col: Color = R.pick([W, C[6], C[5]])
				var sz := R.range(0.6, 1.8)
				ps.spawn(STAR, x, y, cos(a) * sp, sin(a) * sp * 0.7 - 25, life, col, sz)
		# the peel front eats the body
		if t >= P0:
			var f := front(t)
			for b in body.list:
				if not b.gone and b.key < f:
					let_go.call(b)
		# the wind drops once the body is gone, and the last motes hang in the air
		var g := gust(t) * (1.0 - 0.55 * smooth(P0 + PEEL, P0 + PEEL + 1.2, t))
		for i in range(motes.size() - 1, -1, -1):
			var m: Dictionary = motes[i]
			if not m.on:
				continue
			m.life -= dt
			if m.life <= 0:
				m.on = false
				continue
			if m.kind == 2:
				# heavier ash: drifts a little, falls, settles on the floor and glows out
				if m.rest:
					continue
				m.vx += (wind * 30 * g - m.vx * 1.2) * dt
				m.vy += 260 * dt - m.vy * 1.2 * dt
				m.x += m.vx * dt
				var ny: float = m.y + m.vy * dt
				if m.vy > 0 and ny >= -0.5:
					if m.vy > 50:
						m.vy *= -0.35
						m.vx *= 0.6
						m.y = -0.6
					else:
						m.rest = true
						m.y = -0.5
				else:
					m.y = ny
				continue
			var age: float = m.max - m.life
			var k := minf(1.0, age / 0.15)
			var fx: float = wind * (100 * g + 30 * noise2(m.x * 0.07, m.y * 0.07 - t * 0.8, 3)) * k
			var fy: float = (-30 * m.lift + 42 * noise2(m.x * 0.06 + 40, m.y * 0.06 - t * 1.1, 5)) * k
			var drag := 3.0 if m.kind == 1 else 1.5
			m.vx += (fx - m.vx * drag) * dt
			m.vy += (fy - m.vy * drag) * dt
			m.x += m.vx * dt
			m.y += m.vy * dt
		ps.update(dt)
		lm.step(dt)

	var mt := new_track(2, 30.0)
	var tab := Palette.new()
	var rec := func(s: int) -> void:
		var t: float = clock[0]
		for m in motes:
			if not m.on:
				continue
			var age: float = m.max - m.life
			var k2: float = m.life / m.max
			var a := k2 / 0.35 if k2 < 0.35 else 1.0
			var c: Color
			if age < 0.034:
				c = mixc(m.c, W, 0.55)
			elif age < 0.06:
				c = W
			elif age < 0.15:
				c = m.cool[0]
			else:
				var u: float = (age - 0.15) / maxf(0.05, m.max - 0.15)
				var cc: Color = m.cool[1 + mini(2, floori(u * 3))]
				c = mixc(m.c, cc, 0.55) if (m.own and u < 0.5) else cc
				if m.kind == 0 and sin(t * 21 + m.seed) > 0.8:
					c = m.cool[0]
			var gk := 0.0
			if m.kind == 2:
				gk = 0.3 * k2
			elif k2 > 0.15:
				gk = (0.16 if m.kind == 1 else 0.11) * k2
			mt.put(m.i, s, 0, Color(m.x, m.y, 1.0 + a, gk))
			mt.put(m.i, s, 1, Color(m.vx, m.vy, tab.index(c), m.kind))
		ps.record(s)
		lm.record(s)
	run(step, rec)

	# behind: the floor band's far half, a cold pool of light while the body burns away
	band_half("BandBack", 1.0, true)
	var pool := glow_path("Pool", Vector2(0, -1), Vector2(0, -1), 30, C[4])
	keyf(pool, "material:shader_parameter/k", func(t: float) -> float:
		var tt := jt(t)
		return 0.22 * smooth(0.1, FLASH, tt) * (1.0 - smooth(P0 + PEEL * 0.8, P0 + PEEL + 0.6, tt)))

	# the stand-in, until the shudder; then the body drawn by us, with the crackle round it
	var actor := actor_node()
	steps(actor, "visible", [[0.0, true], [FLASH - 0.1, false]])
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	var bd := shape("Body", ssh("dis_body"), Vector2(body.w + 4, body.h + 2), {"tex": tex, "keys": asset("_keys", keymap),
		"origin": Vector2(body.x, body.y), "c4": C[4], "c5": C[5], "c6": C[6], "white": W},
		{"at": Vector2(body.x - 2 + (body.w + 4) / 2.0, body.y - 1 + (body.h + 2) / 2.0)})
	var u := "material:shader_parameter/"
	keyf(bd, u + "phase", func(t: float) -> float:
		var tt := jt(t)
		return 0.0 if tt < FLASH - 0.1 else 1.0 if tt < FLASH else 2.0 if tt < P0 else 3.0, 0.0, -1.0, 60.0, "nearest")
	keyf(bd, u + "shift", func(t: float) -> float: return 0.0 if floori(jt(t) * 60) % 2 == 1 else -1.0, FLASH - 0.12, FLASH + 0.02, 60.0, "nearest")
	keyf(bd, u + "front", func(t: float) -> float: return front(jt(t)), P0 - 0.02, P0 + PEEL + 0.1, 60.0, "nearest")
	keyf(bd, u + "ck", func(t: float) -> float: return jt(t) / FLASH if jt(t) < FLASH else -1.0, 0.0, FLASH + 0.04, 60.0, "nearest")
	keyf(bd, u + "frame", func(t: float) -> float: return float(floori(jt(t) * 30)), 0.0, FLASH + 0.04, 60.0, "nearest")
	# the charge's light
	var cg1 := glow_path("ChargeLight", Vector2(0, CORE_Y), Vector2(0, CORE_Y), 26, C[4])
	keyf(cg1, u + "k", func(t: float) -> float: return 0.42 * jt(t) / FLASH if jt(t) < FLASH else 0.0, 0.0, FLASH + 0.04)
	var cg2 := glow_path("ChargeHot", Vector2(0, CORE_Y), Vector2(0, CORE_Y), 12, C[6])
	keyf(cg2, u + "k", func(t: float) -> float: return 0.25 * pow(jt(t) / FLASH, 2.0) if jt(t) < FLASH else 0.0, 0.0, FLASH + 0.04)
	# the white flash: a glow and a star glint over the chest
	var wg := glow_path("FlashLight", Vector2(0, CORE_Y), Vector2(0, CORE_Y), 34, C[5])
	var white_on := func(t: float) -> bool: return jt(t) >= FLASH and jt(t) < P0
	keyf(wg, u + "k", func(t: float) -> float: return 0.7 if white_on.call(t) else 0.0, 0.0, P0 + 0.04, 60.0, "nearest")
	var spk := shape("FlashGlint", load("res://addons/pixelfx_particles/fx/arcane/_sparkle.gdshader"), Vector2(19, 19),
		{"arm": 9, "c": C[6], "tip": C[4], "heart": W}, {"at": Vector2(0.5, CORE_Y - 3 + 0.5)})
	keyf(spk, "visible", func(t: float) -> bool: return white_on.call(t), 0.0, P0 + 0.04, 60.0, "nearest")
	var sg := glow_path("FlashGlintLight", Vector2(0, CORE_Y - 3), Vector2(0, CORE_Y - 3), 22, C[6])
	keyf(sg, u + "k", func(t: float) -> float: return 0.5 if white_on.call(t) else 0.0, 0.0, P0 + 0.04, 60.0, "nearest")
	# light rides the peel front down the body
	var fl := glow_path("FrontLine", Vector2(-10, top), Vector2(10, 0), 8, C[5])
	var fg := glow_path("FrontGlow", Vector2(0, top), Vector2(0, 0), 22, C[4])
	var fy := func(t: float) -> float: return top + clamp01(front(jt(t))) * H
	var fk := func(t: float) -> float: return (1.0 - smooth(0.85, 1.05, front(jt(t)))) if (jt(t) >= P0 and front(jt(t)) < 1.05) else 0.0
	keyf(fl, u + "a", func(t: float) -> Vector2: return Vector2(-10, fy.call(t)))
	keyf(fl, u + "b", func(t: float) -> Vector2: return Vector2(10, fy.call(t)))
	keyf(fl, u + "k", func(t: float) -> float: return 0.32 * fk.call(t))
	keyf(fg, u + "a", func(t: float) -> Vector2: return Vector2(0, fy.call(t)))
	keyf(fg, u + "b", func(t: float) -> Vector2: return Vector2(0, fy.call(t)))
	keyf(fg, u + "k", func(t: float) -> float: return 0.2 * fk.call(t))
	# the floor band's near half
	band_half("BandFront", -1.0, false)
	# the motes and their light
	var cols := tab.padded(128)
	track("Motes", mt, ssh("mote"), 7, {"cols": cols})
	track("MotesLight", mt, ssh("mote_light"), 9, {"cols": cols, "ash": C[5]}, {"layer": "light"})
	# the streaks, the stars, the lights
	parts("Parts", ps, {"sparks": [C[7], C[6], C[5], C[3]], "front": true})
	lamps("Lights", lm)


## The floor band from the flash (band(): 6 -> 36 px over 0.5 s), side 1 the far half (behind), -1 the near half.
func band_half(name: String, side: float, back: bool) -> void:
	var b := shape(name, sh("band"), Vector2(84, 20), {"mid": Vector2(0, 0), "radius": 6.0, "th": 3.5, "squash": 0.18, "side": side,
		"c0": C[4], "c1": C[5], "c2": C[6], "c3": C[7], "alpha": 0.0}, {"at": Vector2(0, 0), "back": back})
	var kk := func(t: float) -> float: return (jt(t) - FLASH) / 0.5
	var u := "material:shader_parameter/"
	keyf(b, u + "radius", func(t: float) -> float: return 6.0 + 30.0 * out_cubic(kk.call(t)), FLASH - 0.04, FLASH + 0.54)
	keyf(b, u + "th", func(t: float) -> float: return maxf(1.0, 3.5 * (1.0 - kk.call(t))), FLASH - 0.04, FLASH + 0.54)
	keyf(b, u + "alpha", func(t: float) -> float: return (1.15 - kk.call(t)) if (kk.call(t) > 0.0 and kk.call(t) < 1.0) else 0.0, 0.0, FLASH + 0.54, 60.0, "nearest")
	keyf(b, u + "c3", func(t: float) -> Color: return Color.WHITE if kk.call(t) < 0.12 else C[7], FLASH - 0.04, FLASH + 0.54, 60.0, "nearest")
