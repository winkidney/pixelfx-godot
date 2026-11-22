# reimagined-from: src/fx/scifi/warp-out.js@11d867a9736ea97afe05593cbe613bc402480c36
# Warp out: The hero's outline flickers on, they flash white and break into light from the head down, streaming up a beam that lifts off the floor and pinches shut.
# one-shot, 2.60 s, 128x168 canvas, origin [64.0, 128.0], backdrop ground, stand-in 2
# The original's create() and update() are replayed here at its 120 Hz steps with its own generator. The stand-in is
# the effect's Actor until the flash; then a shader holds the body together in light (each pixel's own shading under
# the beam's colour, a rolling scanline) until the moment the original lets that pixel go (fx/scifi/_warp_out.gdshader,
# with the floor target closing in, the outline flickering on and the beam lifting off and pinching shut). Every
# body pixel let go is a particle hauled up the beam by the original's own pull (_ghost.gdshader BIT: a streak or a
# spark); the gathering streaks, the flash's and the lift's stars and sparks are its Particles. Light:
# _warp_out_light.gdshader and keyed flashes.
extends "res://build/fx/scifi/_scifi.gd"

const FLASH := 0.42
const BREAK0 := 0.5
const BREAK1 := 1.1
const LIFT := 1.3


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var TOP: float = -meta.origin[1]
	var NF := int(round(D * 30.0))
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var tex: Texture2D = load(EFFECT.STAND_INS[2])
	var img := tex.get_image()
	var AW := img.get_width()
	var AH := img.get_height()
	var AX := -int(floor(AW / 2.0))
	var AY := -AH
	var on := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < AW and y < AH and img.get_pixel(x, y).a > 0.5
	var R := JsRng.new(S)
	var dt := (1.0 / 30.0) / 4.0

	# the body: every pixel, when it lets go (head first), its own roll
	var bits := []
	var bimg := Image.create(AW, AH, false, Image.FORMAT_RGBAF)
	for my in range(-1, AH + 1):
		for mx in range(-1, AW + 1):
			if on.call(mx, my):
				var tr := BREAK0 + (float(my) / AH) * (BREAK1 - BREAK0 - 0.12) + R.range(0, 0.12)
				var j := R.next()
				var rim: bool = not on.call(mx - 1, my) or not on.call(mx + 1, my) or not on.call(mx, my - 1) or not on.call(mx, my + 1)
				bits.append({"x": float(AX + mx), "y": float(AY + my), "tr": tr, "j": j, "free": false})
				bimg.set_pixel(mx, my, Color(tr, 1.0 if rim else 0.0, 0, 0))
				var pc := img.get_pixel(mx, my)
				var c := Color(pc.r, pc.g, pc.b)
				keep_colour(mixc(c, C[6], 0.6))
				keep_colour(mixc(c, C[5], 0.45))
	var btex := asset("_hold", bimg)

	ghosts_begin(0.0)
	var spawn := func(t: float, k: int, x: float, y: float, vx: float, vy: float, life: float, col: Variant, size: float, delay: float) -> void:
		var sd := R.next() * 100.0
		var n := 0
		var dl := delay
		while dl > 0.0:
			dl -= dt
			n += 1
		ghost(t + (n - 1) * dt, k, x, y, vx, vy, life, col, size, 0, {"seed": sd})
	var t := 0.0
	var flashed := false
	var lifted := false
	var lights := []
	var times := [0.0]
	var bit_specs := []
	for i in range(1, NF + 1):
		for sub in 4:
			t += dt
			if t < FLASH - 0.05 and R.chance(0.7):
				var a := R.range(0, TAU)
				var dd := R.range(26, 48)
				var T := R.range(0.16, 0.26)
				var v := (dd * 3.0) / (exp(3.0 * T) - 1.0)
				var c: Color = C[6] if R.chance(0.5) else C[5]
				spawn.call(t, STREAK, cos(a) * dd, -19.0 + sin(a) * dd * 0.8, -cos(a) * v, -sin(a) * v * 0.8, T, c, 1.0, 0.0)
			if t >= FLASH and not flashed:
				flashed = true
				lights.append([t - dt, Vector2(0, -20), 80.0, C[4], 0.9, 0.5])
				lights.append([t - dt, Vector2(0, -20), 30.0, Color.WHITE, 0.8, 0.12])
				for k in 14:
					var x := R.range(-14, 14)
					var y := -R.range(2, 40)
					var vx := R.range(-20, 20)
					var vy := -R.range(10, 40)
					var life := R.range(0.3, 0.6)
					var c: Color = Color.WHITE if R.chance(0.5) else C[6]
					spawn.call(t, STAR, x, y, vx, vy, life, c, R.range(0.8, 1.8), 0.0)
			for bi in range(bits.size() - 1, -1, -1):
				var b: Dictionary = bits[bi]
				if t < b.tr or b.free:
					continue
				b.free = true
				var ox: float = b.x + 0.5
				var oy: float = b.y + 19.0
				var vx := ox * R.range(1.5, 4) + R.range(-10, 10)
				var vy := oy * R.range(0.5, 1.5) - R.range(10, 40)
				# how long it lasts: hauled up until it passes the top
				var q := {"x": b.x, "y": b.y, "vx": vx, "vy": vy}
				var m := 0
				while true:
					q.vy -= 560.0 * dt
					q.vx += (-(q.x + 0.5) * 14.0 - q.vx * 3.0) * dt
					q.x += q.vx * dt
					q.y += q.vy * dt
					m += 1
					if q.y < TOP + 2.0 or m > 2000:
						break
				bit_specs.append([t - dt, b.x, b.y, vx, vy, (m - 0.5) * dt, b.j])
			if t >= LIFT and not lifted:
				lifted = true
				lights.append([t - dt, Vector2(0, -2), 40.0, C[4], 0.7, 0.3])
				for k in 22:
					var a := -PI / 2.0 + R.range(-1.4, 1.4)
					var sp := R.range(80, 220)
					var x := R.range(-3, 3)
					spawn.call(t, SPARK, x, -1, cos(a) * sp, sin(a) * sp, R.range(0.2, 0.55), Color.WHITE, 1.0, 0.0)
				for k in 16:
					var x := R.range(-10, 10)
					var y := -R.range(4, 70)
					var vx := R.range(-6, 6)
					var vy := -R.range(10, 30)
					var life := R.range(0.5, 0.95)
					var c: Color = Color.WHITE if R.chance(0.4) else C[6]
					var sz := R.range(0.6, 1.6)
					spawn.call(t, STAR, x, y, vx, vy, life, c, sz, R.range(0, 0.3))
		times.append(t)
	var clock_at := func(tt: float) -> float: return times[clampi(int(roundf(tt * 30.0)), 0, NF)]

	# behind the stand-in: the floor target's far half, the beam
	var back := shape("Beam", sh("warp_out"), canvas, {"mode": 0, "t": 0.0, "tex": tex, "bits": btex, "pal": C}, {"at": mid, "back": true})
	var body := actor_node()
	frames_key(body, "visible", func(tt: float) -> bool: return clock_at.call(tt) < FLASH)
	var front := shape("Body", sh("warp_out"), canvas, {"mode": 1, "t": 0.0, "tex": tex, "bits": btex, "pal": C}, {"at": mid})
	var rest := _gh
	_gh = []
	for b in bit_specs:
		ghost(b[0], BIT, b[1], b[2], b[3], b[4], b[5], Color.WHITE, 1.0, 0, {"frames": b[6], "seed": 0.0})
	ghosts({"back": false, "box": [-1e9, TOP, 1e9, 1e9], "bit_colours": [Color.WHITE, C[6], C[5], C[3]]})
	var star := shape("Flash", sh("warp_out"), canvas, {"mode": 2, "t": 0.0, "tex": tex, "bits": btex, "pal": C}, {"at": mid})
	_gh = rest
	ghosts({"back": false, "floor": 0.0, "sparks": [Color.WHITE, C[6], C[5], C[4]]})
	var lit := shape("Light", sh("warp_out_light"), canvas, {"t": 0.0, "pal": C}, {"at": mid})
	for n in [back, front, star, lit]:
		frames_key(n, "material:shader_parameter/t", func(tt: float) -> float: return clock_at.call(tt))
	var li := 0
	for l in lights:
		light_add("Flash%d" % li, l[1], l[2], l[3], l[4], l[5], l[0])
		li += 1
