# reimagined-from: src/fx/pickups/loot-beam.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Loot beam: A dropped sword in a tall pillar of rarity light: a white core thinning to the sky, rings pulsing across the floor, motes streaming up, a glint racing up the shaft.
# loop, 2.40 s, 96x176 canvas, origin [48, 162], backdrop ground
# ramp palette: #140a24 #2c1250 #4b1d86 #7330c0 #a050f0 #c890ff #ecd4ff #ffffff
# The column is a canvas shader running the original's rows (fx/pickups/_beam.gdshader): ramp bands out from a white
# core, drifting strands, climbing pulses, dashes and threads flickering toward the sky, the flare at its foot; its
# light every few rows is a light shader on the same keys (ph, beat, the glint's height). The rings pulsing over the
# floor are band shaders (far halves behind the beam, near halves in front), keyed every frame. The sword is a prop
# drawn at build time from the original's own column-by-column recipe. The glint racing up the shaft, the glint on
# the blade, the floor's lit pixels and the motes streaming up (dots and twinkles) are particles placed frame by frame
# where the original draws them, with their glows.
extends "res://build/fx/pickups/_pickups.gd"

const H := 150.0
const RINGS := [0.08, 0.58]
const OX := 4
const STEEL := ["#151726", "#2c3149", "#4f5775", "#8a93b3", "#d6dcef", "#ffffff"]
const GOLD := ["#3a2008", "#7a4a10", "#b8801c", "#e8b432", "#ffe27a", "#fff6cc"]
const LEATHER := ["#1e0f0e", "#3e2016", "#633620"]
const SWORD_INK := Color("#0d0b14")


static func ring_age(ph: float, k: int) -> float:
	return jmod(ph - RINGS[k], 1.0)


static func axis(x: float) -> int:
	return int(floorf(-4.0 + (x + 4.0) / 7.0 + 0.5))


func beat_at(ph: float) -> float:
	var b := 0.0
	for k in RINGS.size():
		var s := ring_age(ph, k) * D
		b = maxf(b, maxf(exp(-s * 7.0) * (1.0 if s < 0.5 else 0.0), exp(-((D - s) * 30.0))))
	return b


func glint_h(ph: float) -> float:
	var gq := (ph - 0.22) / 0.42
	return 4.0 + (H - 4.0) * (gq * gq) if gq > 0.0 and gq < 1.0 else -100.0


## the sword lying where it fell, built column by column as the original builds it, outlined: an image and its corner
func sword() -> Array:
	var W := Color.WHITE
	var st := STEEL.map(func(h: String) -> Color: return Color(h))
	var go := GOLD.map(func(h: String) -> Color: return Color(h))
	var le := LEATHER.map(func(h: String) -> Color: return Color(h))
	var cells := {}
	var put := func(x: int, y: int, c: Color) -> void: cells[Vector2i(x + OX, y)] = c
	var edge_lit := func(x: int) -> Color: return C[6] if absf(x + OX - 0.5) < 6.0 else mixc(st[4], C[6], 0.45)
	for x in range(-11, 11):
		var a := axis(x)
		if x <= -9:
			var m := x + 10
			if m == 0:
				put.call(x, a - 1, C[6])
				put.call(x, a, W)
				put.call(x, a + 1, C[4])
			else:
				put.call(x, a, C[5] if m < 0 else C[3])
		elif x <= -5:
			put.call(x, a, le[2 if x % 2 else 1])
			put.call(x, a + 1, le[1 if x % 2 else 0])
		elif x <= -3:
			for y in range(a - 3, a + 4):
				var end := y == a - 3 or y == a + 3
				var c: Color
				if y == a:
					c = C[6] if x == -4 else C[4]
				elif x == -4:
					c = go[3] if end else mixc(go[4], C[6], 0.3)
				else:
					c = go[0] if end else go[1]
				put.call(x, y, c)
		else:
			var tip := x - 8
			if tip < 1:
				put.call(x, a - 1, edge_lit.call(x))
			if tip < 2:
				put.call(x, a, edge_lit.call(x) if tip == 1 else mixc(st[3], C[4], 0.2))
			put.call(x, a + 1, st[2] if tip == 2 else st[0])
	var lo := Vector2i(1000, 1000)
	var hi := Vector2i(-1000, -1000)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	lo -= Vector2i.ONE
	hi += Vector2i.ONE
	var img := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var p := Vector2i(x, y)
			if cells.has(p):
				img.set_pixel(x - lo.x, y - lo.y, cells[p])
			elif cells.has(p + Vector2i(1, 0)) or cells.has(p - Vector2i(1, 0)) or cells.has(p + Vector2i(0, 1)) or cells.has(p - Vector2i(0, 1)):
				img.set_pixel(x - lo.x, y - lo.y, SWORD_INK)
	return [img, Vector2(lo)]


## a ring's band (far or near half) keyed every frame
func floor_ring(name: String, k: int, back: bool) -> void:
	var b := shape(name, psh("band"), Vector2(64, 16), {"ramp": [C[2], C[4], C[5], C[6]], "cx": 0.5, "cy": 0.0, "sy": 0.2, "back": back},
		{"at": Vector2(0, 0), "back": back})
	var age := func(t: float) -> float: return ring_age(t / D, k) * D / 1.1
	per_frame(b, "material:shader_parameter/r", func(i: int, t: float) -> float:
		var kk: float = age.call(t)
		return 3.0 + 24.0 * out_cubic(kk) if kk < 1.0 else 0.0)
	per_frame(b, "material:shader_parameter/th", func(i: int, t: float) -> float: return maxf(1.0, 3.2 * (1.0 - age.call(t))))
	per_frame(b, "material:shader_parameter/k", func(i: int, t: float) -> float:
		var kk: float = age.call(t)
		return minf(1.0, 1.25 * (1.0 - kk)) if kk < 1.0 else 0.0)
	per_frame(b, "material:shader_parameter/hot", func(i: int, t: float) -> bool: return age.call(t) < 0.12)


func make() -> void:
	var seed_ := 4
	var W := Color.WHITE
	# the floor: a pool of rarity light, light thrown in front, lit pixels right under the item
	glows("FloorLight", func(i: int, t: float) -> Array:
		return [{"t": G_POOL, "c": C[4], "p": Vector2(0.5, 0), "r": 34.0, "ry": 5.0, "k": 0.14},
			{"t": G_POOL, "c": C[5], "p": Vector2(0.5, 0), "r": 30.0, "ry": 6.0, "k": 0.4, "ymin": -1.0}])
	var floor_px := []
	for x in range(-16, 17):
		var q := absf(x) / 16.5
		var a := 1.35 - q * 1.25
		floor_px.append(dot_e(x, 0.0, 8 if q < 0.3 else (6 if q < 0.6 else 5), a))
		floor_px.append(dot_e(x, 1.0, 6 if q < 0.3 else (5 if q < 0.55 else 4), a * 0.8) if q < 0.75 else null)
		floor_px.append(dot_e(x, 2.0, 4, a * 0.5) if q < 0.4 else null)
	var fl := []
	for i in NF:
		fl.append(floor_px)
	table("FloorPixels", K_DOT, fl, {"back": true})
	# the far half of each ring, behind the item and the beam
	for k in RINGS.size():
		floor_ring("RingBack%d" % k, k, true)
	# the column, its light, the glint racing up it, the flare at its foot
	var cr := canvas_rect()
	var col := body("Column", "beam", {"part": 0}, {"back": true})
	var colf := func(n: Node) -> void:
		per_frame(n, "material:shader_parameter/ph", func(i: int, t: float) -> float: return t / D)
		per_frame(n, "material:shader_parameter/beat", func(i: int, t: float) -> float: return beat_at(t / D))
	colf.call(col)
	per_frame(col, "material:shader_parameter/gh", func(i: int, t: float) -> float: return glint_h(t / D))
	var cl := shape("ColumnLight", psh("beam_light"), cr.size, {"c4": C[4], "c5": C[5], "canvas": canvas_v4()}, {"at": cr.position + cr.size / 2.0})
	colf.call(cl)
	var rows := []
	for i in NF:
		var ph := ft(i) / D
		var gh := glint_h(ph)
		var gq := (ph - 0.22) / 0.42
		rows.append([glint_e(0.0, -gh, 3.5 * (1.0 - gq * 0.5), 6, 0.6) if gh > 0.0 else null])
	table("BeamGlint", K_GLINT, rows, {"back": true})
	var dirs := PackedVector2Array()
	for i in 8:
		dirs.append(Vector2(cos(i * PI / 4.0), sin(i * PI / 4.0)))
	var flare := body("Flare", "beam", {"part": 1, "dirs": dirs}, {"back": true})
	per_frame(flare, "material:shader_parameter/flare_l", func(i: int, t: float) -> float:
		var ph := t / D
		return 8.0 + 3.0 * beat_at(ph) + sin(ph * TAU * 4.0) * 0.8)
	per_frame(flare, "material:shader_parameter/flare_k", func(i: int, t: float) -> float: return 0.6 + 0.4 * beat_at(t / D))
	glows("Glow", func(i: int, t: float) -> Array:
		var ph := t / D
		var b := beat_at(ph)
		var gh := glint_h(ph)
		var l := [{"c": C[4], "p": Vector2(0.5, -16), "r": 16.0, "k": 0.12 + 0.25 * b},
			({"c": C[5], "p": Vector2(0.5, -gh), "r": 14.0, "k": 0.45} if gh > 0.0 else null)]
		for k in RINGS.size():
			var kk := ring_age(ph, k) * D / 1.1
			for s in [-1.0, 1.0]:
				if kk < 1.0:
					l.append({"c": C[5], "p": Vector2(0.5 + s * (3.0 + 24.0 * out_cubic(kk)), -1), "r": 8.0, "k": 0.35 * (1.0 - kk)})
				else:
					l.append(null)
		return l)
	# in front: the shadow where it lies, the sword and the glint sliding down its edge
	var sh := shadow("Shadow", func(i: int, t: float) -> Array: return [OX - 0.5, 12.5, 0.95], {"span": 20, "back": false})
	var sw := sword()
	sprite("Sword", asset("sword", sw[0]), {"centered": false, "at": sw[1], "layer": "prop"})
	rows = []
	for i in NF:
		var g := (ft(i) / D - 0.72) / 0.16
		if g > 0.0 and g < 1.0:
			var x := -1.0 + 9.0 * in_out_sine(g)
			rows.append([glint_e(x + OX, axis(jround(x)) - 1.0, 2.6 * sin(g * PI), 8, 0.5)])
		else:
			rows.append([null])
	table("SwordGlint", K_GLINT, rows)
	for k in RINGS.size():
		floor_ring("RingFront%d" % k, k, false)
	# motes streaming up round the beam, a few twinkling
	var dots := []
	var twinkles := []
	for i in NF:
		var t := ft(i)
		var dr := []
		var tr := []
		for j in 30:
			var g := rng([seed_, j, 911])
			var born := g.next() * D
			var life := g.range(1.0, 2.2)
			var age := jmod(t - born, D)
			var e3 := [null, null, null]
			var gl: Variant = null
			if age < life:
				var r := rng([seed_, j])
				var inner := r.chance(0.3)
				var side := r.sign()
				var x0 := r.range(-3, 3) if inner else side * r.range(4, 15)
				var vy := r.range(22, 52) * (1.5 if inner else 1.0)
				var x := x0 + sin(age * r.range(1.5, 3.5) + r.range(0, TAU)) * 1.6
				var y := -r.range(1, 10) - vy * age
				var k := minf(minf(1.0, age / 0.25), (life - age) / 0.5)
				if k > 0.0 and y >= -H:
					if r.chance(0.22):
						var tw := 0.5 + 0.5 * sin(age * r.range(9, 14) + r.range(0, TAU))
						if tw * k > 0.3:
							gl = glint_e(x, y, 2.0 if tw > 0.75 else 1.0, 6, 0.4 * k)
					else:
						e3 = [dot_e(x, y, 8 if inner else 6, k * 1.5, [x + 0.5, y + 0.5, 3.5, C[5], 0.35 * k]),
							dot_e(x, y + 1.0, 6 if inner else 4, k), dot_e(x, y + 2.0, 3, k * 0.6)]
			dr += e3
			tr.append(gl)
		dots.append(dr)
		twinkles.append(tr)
	table("Motes", K_DOT, dots)
	table("MoteTwinkles", K_GLINT, twinkles)
