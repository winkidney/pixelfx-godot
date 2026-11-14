# reimagined-from: src/fx/status/rage.js@171b95ca44b8303b29e172f9ad24058948b2b731
# Rage: Seething: the body judders on every heartbeat, an anger mark throbs at the temple, eyes burn, steam jets off the head, stress lines flash out and the floor cracks hot underfoot.
# loop, 1.20 s, 80x80 canvas, origin [40.0, 70.0], backdrop ground, stand-in 2
# ramp heat: #5a0a0a #c8281a #ff7a2a #ffd27a
# ramp palette: #1a0208 #4a0612 #8a0c1c #c81828 #ff3040 #ff7a7a #ffc8c8 #ffffff
# The stand-in is the effect's own Actor, keyed a pixel aside (and up on the lub) while each beat lands; its burning
# eyes, brows and the anger mark ride on it (the mark a two-frame strip, big on the beats). Steam jets off the head
# after each beat as soft GPU particles (a white heart in each puff while young); jagged stress lines (small textures
# drawn here) flash out round the head; the floor's cracks (a strip of their colourings as the stamp cools) glow hot
# on each stamp and spit embers and grit (GPU bursts); a dark-red shimmer rises behind; red light pulses with the beat.
extends "res://build/fx/status/_status.gd"

const D := 1.2
const LUB := 0.05
const DUB := 0.29
const G := 760.0
const STEAM_LIFE := 0.34

var C: PackedColorArray
var Hh: PackedColorArray


static func pulse(t: float, at: float, w := 0.06) -> float:
	var d := fposmod(t - at + D / 2.0, D) - D / 2.0
	return exp(-pow(d / w, 2.0))


static func beat(t: float) -> float:
	return pulse(t, LUB) + 0.65 * pulse(t, DUB)


static func since(t: float, at: float) -> float:
	return fposmod(t - at, D)


static func shaking(t: float) -> bool:
	return since(t, LUB - 0.02) < 0.13 or since(t, DUB - 0.02) < 0.09


## the painter's line(): Bresenham between the cells of two points, [[Vector2i, u], ...]
static func bres(x0: float, y0: float, x1: float, y1: float) -> Array:
	var sx := int(floorf(x0))
	var sy := int(floorf(y0))
	var ex := int(floorf(x1))
	var ey := int(floorf(y1))
	var dx := absi(ex - sx)
	var dy := -absi(ey - sy)
	var stx := 1 if sx < ex else -1
	var sty := 1 if sy < ey else -1
	var n := maxi(dx, -dy)
	if n == 0:
		n = 1
	var err := dx + dy
	var i := 0
	var out := []
	while true:
		out.append([Vector2i(sx, sy), i / float(n)])
		i += 1
		if sx == ex and sy == ey:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			sx += stx
		if e2 <= dx:
			err += dx
			sy += sty
	return out


func make() -> void:
	C = fit("palette", 8)
	Hh = fit("heat", 4)
	var seed_: int = int(meta.options.seed)
	var steam := Color(meta.options.steam)
	keep_colour(steam)
	keep_colour(WHITE)
	keep_colour(INK)
	var grey := Color("#6a5e72")
	keep_colour(grey)
	var times := frame_times()
	var S := shape_of()

	# ---------------------------------------------------------------- behind
	# dark-red heat shimmering up round the body: short wavy dotted dashes
	var dash := Image.create(11, 3, false, Image.FORMAT_RGBA8)
	dash.fill(Color(0, 0, 0, 0))
	for d in 11:
		var a := 1.0 - absf(d / 11.0 - 0.5) * 1.4
		var c: Color = C[1] if d % 3 == 0 else C[2]
		dash.set_pixel(d, 1 + int(jround(sin(d * 0.9) * 0.8)), Color(c, a))
	particles("Shimmer", {"back": true, "at": Vector2(0, AY + 25), "amount": 8, "lifetime": 1.1, "life_random": 0.35,
		"texture": asset("shimmer", dash), "emit": {"box": Vector2(16, 15)}, "dir": -90, "speed": [14, 22],
		"alpha_curve": [[0, 0], [0.25, 0.4], [0.5, 0.55], [0.75, 0.4], [1, 0]]})
	# red light pooling on the floor with each beat
	var pool := glow("FloorLight", 30, {"radius": 28, "squash": 4.5 / 28.0, "color": C[3], "alpha": 0.2}, {"at": Vector2(0, 0.5), "back": true})
	sample(pool, "material:shader_parameter/alpha", func(t: float) -> float: return 0.2 + 0.3 * beat(t), "linear")
	# the cracks under the feet: hot on the stamp, cooling between (a strip of their colourings)
	var R := Rng.new(seed_ * 31 + 7)
	var rows: Array = S.rows
	var fl: int = rows[AH - 1][0]
	var fr: int = rows[AH - 1][1]
	var cracks := []
	for st in [[AX + fl + 2.0, -1.0], [AX + fr - 1.0, 1.0], [AX + (fl + fr) / 2.0, -1.0], [AX + (fl + fr) / 2.0 + 1.0, 1.0]]:
		var x: float = st[0]
		var dir: float = st[1]
		var y := 0.5
		var pts := [Vector2(x, y)]
		var n := R.integer(5, 9)
		for i in n:
			x += dir * R.range(1.2, 2.4)
			y = clampf(y + R.range(-0.9, 0.9), 0.0, 2.5)
			pts.append(Vector2(x, y))
			if i > 1 and R.chance(0.3):
				var bx := x + dir * R.range(1, 2)
				var by := clampf(y + R.sgn() * R.range(0.6, 1.4), 0.0, 3.0)
				cracks.append([Vector2(x, y), Vector2(bx, by)])
		cracks.append(pts)
	var heat_of := func(t: float) -> float: return 0.25 + 0.75 * exp(-since(t, LUB) / 0.18)
	var crack_frames := []
	var crack_index := {}
	var crack_keys := []
	var lo := Vector2i(-40, -2)
	for t in times:
		var heat: float = heat_of.call(t)
		var img := Image.create(80, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for pts in cracks:
			for i in range(1, pts.size()):
				var far := i / float(pts.size())
				var c: Color = Hh[3] if heat * (1.0 - far * 0.6) > 0.6 else (Hh[2] if heat * (1.0 - far * 0.5) > 0.35 else Hh[1])
				for q in bres(pts[i - 1].x, pts[i - 1].y, pts[i].x, pts[i].y):
					var pp: Vector2i = q[0] - lo
					img.set_pixel(pp.x, pp.y, c)
		var k := img.get_data()
		if not crack_index.has(k):
			crack_index[k] = crack_frames.size()
			crack_frames.append(img)
		crack_keys.append([t, crack_index[k]])
	var strip := Image.create(80 * crack_frames.size(), 8, false, Image.FORMAT_RGBA8)
	for i in crack_frames.size():
		strip.blit_rect(crack_frames[i], Rect2i(0, 0, 80, 8), Vector2i(i * 80, 0))
	keep_image_colours(strip)
	var crack_sprite := sprite("Cracks", asset("cracks", strip), {"back": true, "centered": false, "at": Vector2(lo), "hframes": crack_frames.size()})
	key(crack_sprite, "frame", crack_keys, "nearest")
	# their glow: along every other segment
	var gi := 0
	for pts in cracks:
		for i in range(1, pts.size()):
			if i % 2 == 0:
				continue
			var far := i / float(pts.size())
			var g := glow("CrackGlow%d" % gi, 6, {"radius": 4, "color": Hh[2], "alpha": 0.0}, {"at": pts[i]})
			sample(g, "material:shader_parameter/alpha", func(t: float) -> float: return 0.25 * heat_of.call(t) * (1.0 - far * 0.5), "linear")
			gi += 1

	# ---------------------------------------------------------------- the body
	var body := actor_node()
	sample(body, "position", func(t: float) -> Vector2:
		if not shaking(t):
			return Vector2.ZERO
		var dx := 1.0 if int(floorf(t * 60.0 + 1e-6)) % 2 else -1.0
		var dy := -1.0 if since(t, LUB - 0.02) < 0.06 else 0.0
		return Vector2(dx, dy))
	# burning eyes under angry brows, riding the body
	var px := {}
	for e in eyes():
		var inner := 1 if (e.x0 + e.x1) / 2.0 < AW / 2.0 else -1
		for q in e.px:
			px[Vector2i(AX, AY) + q] = C[7] if q.y == e.y0 else (C[6] if q.y == e.y0 + 1 else C[4])
		var xi: int = e.x1 if inner > 0 else e.x0
		var xo: int = e.x0 if inner > 0 else e.x1
		px[Vector2i(AX + xo - inner, AY + e.y0 - 2)] = INK
		px[Vector2i(AX + xo, AY + e.y0 - 2)] = INK
		px[Vector2i(AX + xi, AY + e.y0 - 1)] = INK
	pixels("Eyes", px, {"parent": body})
	for e in eyes():
		var g := glow("EyeGlow%d" % e.x0, 7, {"radius": 5, "color": C[5], "alpha": 0.35},
			{"at": Vector2(AX + (e.x0 + e.x1 + 1) / 2.0, AY + e.y0 + 1), "parent": body})
		sample(g, "material:shader_parameter/alpha", func(t: float) -> float: return 0.35 + 0.35 * beat(t), "linear")
	# the anger mark at the temple: big on the lub, smaller on the dub
	var marks := [
		bitmap(["..#.#..", "..#.#..", "##...##", ".......", "##...##", "..#.#..", "..#.#.."]),
		bitmap(["...#.#...", "...#.#...", "..##.##..", "###...###", ".........", "###...###", "..##.##..", "...#.#...", "...#.#..."]),
	]
	var mimgs := []
	for b in 2:
		var img := icon_image(marks[b], 5, [C[0], C[3], C[4], C[5]])
		var g := 4 if b else 3
		img.set_pixel(6 - g, 6 - (3 if b else 2), C[6])
		mimgs.append(img)
	var mx := AX + AW * 0.86
	var mark := icon_strip("Mark", mimgs, {"at": Vector2(jround(mx), AY + 3), "parent": body})
	sample(mark, "frame", func(t: float) -> int:
		return 1 if (pulse(t, LUB + 0.02, 0.05) > 0.35 or pulse(t, DUB + 0.02, 0.04) > 0.6) else 0)
	var mg := glow("MarkGlow", 10, {"radius": 8, "color": C[4], "alpha": 0.25}, {"at": Vector2(mx, AY + 3), "parent": body})
	sample(mg, "material:shader_parameter/alpha", func(t: float) -> float: return 0.25 + 0.4 * beat(t), "linear")

	# ---------------------------------------------------------------- in front
	# steam jetting off the head after each beat: soft puffs swelling and thinning, a white heart while young
	var puff := [[0.0, 0.24], [0.1, (1 + 3.2 * sqrt(0.1)) / 4.2], [0.25, 2.6 / 4.2], [0.5, (1 + 3.2 * sqrt(0.5)) / 4.2], [1.0, 1.0]]
	var fade := [[0.0, 0.0], [0.083, 0.59], [0.25, 0.39], [0.5, 0.175], [0.75, 0.044], [1.0, 0.0]]
	var bi := 0
	for bt in [[LUB + 0.04, 7, 1.0], [DUB + 0.04, 4, 0.75]]:
		for side in [-1.0, 1.0]:
			var o := {"at": Vector2(side * AW * 0.36, AY + 3), "amount": bt[1], "lifetime": STEAM_LIFE, "life_random": 0.35,
				"one_shot": true, "explosiveness": 1.0 - (bt[1] * 0.016) / STEAM_LIFE, "dir": -90.0 + side * rad_to_deg(0.6), "spread": 6.0,
				"speed": [90.0 * bt[2], 130.0 * bt[2]], "drag": 7.0, "gravity": Vector2(0, -40), "scale": [0.8, 1.2], "scale_curve": puff,
				"alpha_curve": fade, "color": steam}
			var s := o.duplicate()
			s.merge({"layer": "soft", "texture": "disc9"})
			var p := particles("Steam%d" % bi, s)
			emit(p, bt[0])
			var c := o.duplicate()
			c.merge({"layer": "soft", "texture": "disc5", "color": WHITE, "alpha_curve": [[0.0, 0.0], [0.083, 0.5], [0.25, 0.34], [0.5, 0.15], [1.0, 0.0]]})
			var q := particles("SteamCap%d" % bi, c)
			q.position += Vector2(-1, -1)
			emit(q, bt[0])
			var h := o.duplicate()
			h.merge({"texture": "dot1", "color": WHITE, "alpha_curve": [[0.0, 1.0], [0.3, 0.0], [1.0, 0.0]], "scale_curve": [[0, 1], [1, 1]], "scale": [1, 1]})
			var r := particles("SteamHeart%d" % bi, h)
			emit(r, bt[0])
			bi += 1
	# jagged stress lines flashing out round the head on the beat
	var li := 0
	for sl in [[LUB, 8, 7.0], [DUB, 6, 5.0]]:
		var n: int = sl[1]
		var L: float = sl[2]
		for i in n:
			var ang := -PI / 2.0 + ((i + 0.5) / n - 0.5) * 4.4
			var ca := cos(ang)
			var sa := sin(ang)
			var cx := 0.0
			var cy := AY + 12.0
			var pts := []
			for j in 4:
				var r := 15.0 + (j / 3.0) * L
				var off := 1.3 if j % 2 else -0.4
				pts.append(Vector2(cx + ca * r - sa * off, cy + sa * r + ca * off))
			var lpx := {}
			for j in range(1, 4):
				for q in bres(pts[j - 1].x, pts[j - 1].y, pts[j].x, pts[j].y):
					lpx[q[0]] = C[7] if q[1] > 0.66 else (C[5] if q[1] > 0.33 else C[4])
			var spr := pixels("Stress%d" % li, lpx)
			var base := spr.position
			var gl := line("StressGlow%d" % li, PackedVector2Array([pts[0], pts[3]]), {"layer": "light", "width": 6.0, "color": C[4]})
			var kv := []
			var kp := []
			var ka := []
			var kg := []
			for t in times:
				var age := since(t, sl[0])
				var on := age <= 0.2
				var k := age / 0.2
				kv.append([t, on])
				kp.append([t, base + Vector2(jround(ca * 6.0 * k), jround(sa * 6.0 * k)) if on else base])
				ka.append([t, clampf(1.2 - k, 0.0, 1.0) if on else 0.0])
				kg.append([t, 0.3 * (1.0 - k) if on else 0.0])
			key(spr, "visible", kv, "nearest")
			key(spr, "position", kp, "nearest")
			key(spr, "modulate:a", ka, "nearest")
			key(gl, "modulate:a", kg, "nearest")
			li += 1
	# the stamp: embers spat up out of the cracks, grit hopping
	ground(0.0)
	var em := {"at": Vector2(0, -1), "amount": 10, "lifetime": 1.0, "life_random": 0.5, "one_shot": true, "explosiveness": 0.97,
		"emit": {"box": Vector2(15, 0.5)}, "dir": -90.0, "spread": 4.0, "speed": [40, 90], "gravity": Vector2(0, -20), "drag": 1.6,
		"ramp": gradient([Hh[3], Hh[2], Hh[3], Hh[2], Hh[2], Hh[1], Color(Hh[1], 0.0), Hh[1], Color(Hh[1], 0.0)], [0.0, 0.15, 0.3, 0.42, 0.5, 0.78, 0.84, 0.9, 0.95])}
	var embers := particles("Embers", em)
	emit(embers, LUB)
	var eg := em.duplicate()
	eg.merge({"layer": "light", "texture": "glow8"})
	var emg := particles("EmberGlow", eg)
	emg.modulate = Color(1, 1, 1, 0.14)
	emit(emg, LUB)
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 12, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0,
		"emit": {"box": Vector2(9, 0.5)}, "dir": -90.0, "spread": 32.0, "speed": [45, 120], "gravity": Vector2(0, G),
		"initial": gradient([C[2], C[2], grey]), "collide": {"hide": true}})
	emit(grit, LUB)
	# the beat flares red light round the head and down onto the floor
	var g1 := glow("HeadLight", 28, {"radius": 26, "color": C[4], "alpha": 0.12}, {"at": Vector2(0, AY + 10)})
	sample(g1, "material:shader_parameter/alpha", func(t: float) -> float: return 0.12 + 0.4 * beat(t), "linear")
	var g2 := glow("BodyLight", 36, {"radius": 34, "color": C[3], "alpha": 0.08}, {"at": Vector2(0, AY + 22)})
	sample(g2, "material:shader_parameter/alpha", func(t: float) -> float: return 0.08 + 0.18 * beat(t), "linear")
