# reimagined-from: src/fx/scifi/warp-in.js@5c9ed185a8cebac8f1182f546db29c524f6fe28b
# Warp in: A beam slams down, rings run down it and a scanline paints the hero in from head to toe, white-hot pixels cooling to their own colors; the beam pinches shut in sparks.
# one-shot, 3.00 s, 192x168 canvas, origin [96.0, 128.0], backdrop ground, stand-in 2
# The original's update() is replayed here at its 120 Hz steps with its own generator: its particles (energy streaks
# gathering, vapour sliding along the floor, the slam's sparks, vapour and stars, light falling down the beam, glints
# at its walls, motes the scanline spits off the body, the set body's glints, the snap's sparks and the motes rising
# where the beam stood) are GPU particles moved by its physics (_ghost.gdshader). Shaders keyed by its clock draw
# the floor (pool, ripples, shockwaves), the rings riding down the beam, the column itself, the guide thread and
# target behind the stand-in, and in front the hero painted in by the scanline, white-hot and cooling to its own
# colours, the rings' and the floor's near halves, the outline's flare, the slam's star
# (fx/scifi/_warp_in.gdshader; light in _warp_in_light.gdshader and keyed flashes). The stand-in shows from the
# moment the body is set.
extends "res://build/fx/scifi/_scifi.gd"

const SLAM := 0.34
const SCAN0 := 0.62
const SCAN1 := 1.4
const COOL := 0.42
const DONE := SCAN1 + COOL
const CLOSE := 1.9
const SNAP := 2.16

var WD := 15.0


func width_at(t: float) -> float:
	if t < SLAM:
		return 0.0
	if t < CLOSE:
		return WD * (1.0 + 0.45 * exp(-(t - SLAM) * 14.0) + 0.03 * sin(t * 31.0))
	return lerpf(WD, 0.7, out_cubic(clampf((t - CLOSE) / (SNAP - CLOSE), 0.0, 1.0)))


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	WD = meta.options.width
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
	var body := []
	var rows := {}
	for my in AH:
		for mx in AW:
			var pc := img.get_pixel(mx, my)
			if pc.a < 0.5:
				continue
			var c := Color(pc.r, pc.g, pc.b)
			keep_colour(mixc(c, C[6], 0.72))
			keep_colour(mixc(c, C[5], 0.38))
			body.append(Vector2(AX + mx, AY + my))
			var r: Array = rows.get(AY + my, [AX + mx, AX + mx])
			rows[AY + my] = [mini(r[0], AX + mx), maxi(r[1], AX + mx)]
	var scan_y := func(t: float) -> float: return lerpf(AY - 2.0, 1.0, in_out_sine(clampf((t - SCAN0) / (SCAN1 - SCAN0), 0.0, 1.0)))

	var R := JsRng.new(S)
	var dt := (1.0 / 30.0) / 4.0
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
	var slammed := false
	var snapped := false
	var next_ring := SLAM + 0.08
	var last_row := AY - 3
	var rings := []
	var lights := []
	var times := [0.0]
	for i in range(1, NF + 1):
		for sub in 4:
			t += dt
			if t < SLAM - 0.04:
				if R.chance(0.8):
					var a := R.range(-PI * 0.95, -PI * 0.05)
					var dd := R.range(30, 64)
					var T := R.range(0.18, 0.28)
					var v := (dd * 3.0) / (exp(3.0 * T) - 1.0)
					var x := cos(a) * dd
					var y := sin(a) * dd * 0.8 - 2.0
					var l := Vector2(x, y + 2.0).length()
					if l == 0.0:
						l = 1.0
					var c: Color = C[6] if R.chance(0.5) else C[5]
					spawn.call(t, STREAK, x, y, (-x / l) * v, (-(y + 2.0) / l) * v, T, c, 1.0, 0.0)
				if R.chance(0.12):
					var s := R.sign()
					var x := s * R.range(30, 56)
					var y := -R.range(0, 2)
					var vx := -s * R.range(40, 70)
					var vy := -R.range(0, 4)
					var life := R.range(0.3, 0.45)
					spawn.call(t, VAPOUR, x, y, vx, vy, life, C[5], R.range(2, 3), 0.0)
			if t >= SLAM and not slammed:
				slammed = true
				lights.append([t - dt, Vector2(0, -40), 120.0, C[4], 1.0, 0.55])
				lights.append([t - dt, Vector2(0, -10), 44.0, Color.WHITE, 0.9, 0.14])
				for k in 34:
					var a := -PI / 2.0 + R.sign() * R.range(0.35, 1.45)
					var sp := R.range(110, 270)
					var x := R.range(-WD, WD) * 0.6
					spawn.call(t, SPARK, x, -1, cos(a) * sp, sin(a) * sp, R.range(0.25, 0.75), Color.WHITE, 1.0, 0.0)
				for k in 18:
					var s := R.sign()
					var x := s * R.range(4, 18)
					var y := -R.range(0, 4)
					var vx := s * R.range(40, 150)
					var vy := -R.range(2, 18)
					var life := R.range(0.5, 0.95)
					var c: Color = C[6] if R.chance(0.6) else C[5]
					spawn.call(t, VAPOUR, x, y, vx, vy, life, c, R.range(3, 6), 0.0)
				for k in 10:
					var x := R.range(-WD, WD) * 1.3
					var y := -R.range(2, 40)
					var vx := R.range(-20, 20)
					var vy := -R.range(10, 40)
					var life := R.range(0.4, 0.8)
					var c: Color = Color.WHITE if R.chance(0.5) else C[6]
					spawn.call(t, STAR, x, y, vx, vy, life, c, R.range(1, 2.2), 0.0)
			if slammed and t < CLOSE:
				if t >= next_ring:
					rings.append(next_ring)
					next_ring += 0.17
				var w := width_at(t)
				if R.chance(0.5):
					var x := R.range(-0.8, 0.8) * w
					var y := TOP + R.range(9, 36)
					var vy := R.range(60, 110)
					var life := R.range(0.3, 0.45)
					var c: Color = Color.WHITE if R.chance(0.5) else C[6]
					spawn.call(t, STREAK, x, y, 0, vy, life, c, 1.0, 0.0)
				if R.chance(0.18):
					var x := R.sign() * w * R.range(0.8, 1.3)
					var y := -R.range(4, 70)
					var vy := -R.range(5, 20)
					var life := R.range(0.3, 0.6)
					spawn.call(t, STAR, x, y, 0, vy, life, C[6], R.range(0.6, 1.8), 0.0)
				if R.chance(0.1):
					var s := R.sign()
					var x := s * R.range(8, 16)
					var y := -R.range(0, 3)
					var vx := s * R.range(20, 50)
					var vy := -R.range(2, 8)
					var life := R.range(0.5, 0.8)
					spawn.call(t, VAPOUR, x, y, vx, vy, life, C[5], R.range(2.5, 4), 0.0)
			if t > SCAN0 and t < SCAN1:
				var y := int(floor(scan_y.call(t)))
				if y != last_row:
					last_row = y
					if rows.has(y) and R.chance(0.7):
						var r: Array = rows[y]
						for e in [[r[0], -1.0], [r[1] + 1, 1.0]]:
							if R.chance(0.6):
								var vx: float = e[1] * R.range(40, 90)
								var vy := R.range(-20, 10)
								var life := R.range(0.15, 0.3)
								var c: Color = Color.WHITE if R.chance(0.5) else C[6]
								spawn.call(t, MOTE, e[0], y, vx, vy, life, c, 0.6, 0.0)
			if t >= DONE and t - dt < DONE:
				for k in 6:
					var b: Vector2 = body[int(floor(R.next() * body.size()))]
					var vx := R.range(-6, 6)
					var vy := -R.range(6, 20)
					var life := R.range(0.4, 0.8)
					var c: Color = Color.WHITE if R.chance(0.5) else C[6]
					spawn.call(t, STAR, b.x + 0.5, b.y + 0.5, vx, vy, life, c, R.range(1, 2), 0.0)
			if t >= SNAP and not snapped:
				snapped = true
				lights.append([t - dt, Vector2(0, -1), 32.0, C[4], 0.5, 0.25])
				lights.append([t - dt, Vector2(0, -1), 10.0, Color.WHITE, 0.5, 0.08])
				for k in 22:
					var a := -PI / 2.0 + R.range(-1.4, 1.4)
					var sp := R.range(90, 260)
					var x := R.range(-2, 2)
					spawn.call(t, SPARK, x, -1, cos(a) * sp, sin(a) * sp, R.range(0.2, 0.6), Color.WHITE, 1.0, 0.0)
				for k in 12:
					var x := R.range(-16, 16)
					var y := -R.range(0, 46)
					var vx := R.range(-10, 10)
					var vy := -R.range(8, 26)
					var life := R.range(0.5, 0.9)
					var c: Color = Color.WHITE if R.chance(0.5) else C[6]
					spawn.call(t, STAR, x, y, vx, vy, life, c, R.range(0.6, 1.8), 0.0)
				for k in 18:
					var kind := STAR if R.chance(0.6) else MOTE
					var x := R.range(-6, 6)
					var y := -R.range(10, 100)
					var vx := R.range(-6, 6)
					var vy := -R.range(14, 40)
					var life := R.range(0.5, 0.75)
					var c: Color
					if R.chance(0.4):
						c = Color.WHITE
					else:
						c = C[6] if R.chance(0.5) else C[5]
					var sz := R.range(0.5, 1.4)
					spawn.call(t, kind, x, y, vx, vy, life, c, sz, R.range(0, 0.25))
		times.append(t)
	var clock_at := func(tt: float) -> float: return times[clampi(int(roundf(tt * 30.0)), 0, NF)]

	var ring_u := PackedFloat32Array(rings)
	while ring_u.size() < 12:
		ring_u.append(-100.0)
	var strands := PackedFloat32Array()
	for s in 5:
		strands.append(rand([S, s]))
	var params := {"t": 0.0, "seed": S, "W": WD, "tex": tex, "pal": C, "rings": ring_u, "ring_count": rings.size(), "strands": strands}
	var p0 := params.duplicate()
	p0.mode = 0
	var back := shape("Beam", sh("warp_in"), canvas, p0, {"at": mid, "back": true})
	ghosts({"only": "back", "back": true, "floor": 0.0, "haze": C[5], "sparks": [Color.WHITE, C[6], C[5], C[3]]})
	var actor := actor_node()
	frames_key(actor, "visible", func(tt: float) -> bool: return clock_at.call(tt) >= DONE)
	var p1 := params.duplicate()
	p1.mode = 1
	var front := shape("Hero", sh("warp_in"), canvas, p1, {"at": mid})
	ghosts({"back": false, "floor": 0.0, "haze": C[5], "sparks": [Color.WHITE, C[6], C[5], C[3]]})
	var lp := params.duplicate()
	lp.erase("strands")
	var lit := shape("Light", sh("warp_in_light"), canvas, lp, {"at": mid})
	for n in [back, front, lit]:
		frames_key(n, "material:shader_parameter/t", func(tt: float) -> float: return clock_at.call(tt))
	var li := 0
	for l in lights:
		light_add("Flash%d" % li, l[1], l[2], l[3], l[4], l[5], l[0])
		li += 1
