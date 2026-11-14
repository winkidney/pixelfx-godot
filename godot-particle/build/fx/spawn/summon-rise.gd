# reimagined-from: src/fx/spawn/summon-rise.js@aede4ab2dcbf7898e206280174ccb192f4228e9d
# Summon rise: A rune circle burns into the floor, the ground bursts, and a horned brute heaves up out of it through dust and rubble, lit from below, until its eyes flare.
# one-shot, 4.60 s, 176x116 canvas, origin [88.0, 94.0], backdrop ground
# ramp body: #060409 #0e0913 #170f1e #211628 #2d2036
# ramp horn: #0c080c #201820 #352a32 #4e3f48 #6e5c64
# ramp palette: #1a0608 #3d0c0c #7a1a10 #c0381a #f06a1e #ffae3a #ffe08a #ffffff
# ramp stone: #1a1424 #2b2639 #4a4263 #6c6488 #9a91b4
# The original's own update() runs here with its seeded draws. The brute is built here as the original builds it,
# part by part (its shading per part from its own blurred shape, its creases, its rim toward the floor), and drawn
# as the original draws it (fx/spawn/_beast.gdshader: heaving up out of the floor, lit from the fire below, eyes
# flaring open, crumbling away). The floor (_summon_floor: cracks, the two rings burnt in round the circle, the
# runes, the gash) with its light; the rubble (_shards: the original's Bits) and the sparks, embers, fire, smoke,
# grit and dust (_parts: the original's Particles, grit skipping and fire leaving smoke by its own draws); glows keyed
# on its formulas; its lights tracked (_lamps).
extends "res://build/fx/spawn/_spawn.gd"

const SOOT_C := Color8(0x2a, 0x1e, 0x2a)
const IGN := 0.5
const RUNES := 0.78
const BREAK := 1.05
const EYES := 2.3
const FADE := 3.4
const SY := 0.3
const R0 := 36.0
const R1 := 27.0
const GLYPHS := [
	[[[0, -2], [0, 2]], [[-1.5, -1], [1.5, 1]]],
	[[[-1.5, 2], [0, -2], [1.5, 2]], [[-0.8, 0.4], [0.8, 0.4]]],
	[[[-1.5, -2], [-1.5, 2], [1.5, 2]], [[0, -2], [1.5, -0.5]]],
	[[[0, -2], [0, 2]], [[0, -2], [1.6, -0.6], [0, 0.6]]],
	[[[-1.5, -2], [1.5, 2]], [[1.5, -2], [-1.5, 2]], [[-1.5, 0], [1.5, 0]]],
	[[[-1.4, -2], [1.4, -2], [-1.4, 2], [1.4, 2]]],
]

var BW := 46
var BH := 46
var part := PackedInt32Array()


static func jround(x: float) -> int:
	return floori(x + 0.5)


## The original's beast(): the brute part by part (1 head, 2 horns, 3 arms, 4 shoulders, 5 chest, 6 waist, 7 legs,
## 8 tail), each pixel's frontmost part, ambient light, downward facing, rim and crease.
func beast() -> Dictionary:
	var W := 46
	var H := 46
	var N := W * H
	var CX := 22.5
	var parts := []
	for k in 8:
		var a := PackedByteArray()
		a.resize(N)
		parts.append(a)
	var cur := [0]
	var put := func(x: float, y: float) -> void:
		var xi := jround(x)
		var yi := jround(y)
		if xi >= 0 and yi >= 0 and xi < W and yi < H:
			parts[cur[0]][yi * W + xi] = 1
	var ell := func(cx: float, cy: float, rx: float, ry: float) -> void:
		for y in range(floori(cy - ry), ceili(cy + ry) + 1):
			for x in range(floori(cx - rx), ceili(cx + rx) + 1):
				var dx := (x + 0.5 - cx) / rx
				var dy := (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1:
					put.call(x, y)
	var stroke := func(pts: Array, r0: float, r1: float) -> void:
		var L := []
		var total := 0.0
		for i in range(1, pts.size()):
			var l := Vector2(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]).length()
			L.append(l)
			total += l
		var acc := 0.0
		for i in range(1, pts.size()):
			var n := ceili(L[i - 1] * 3) + 1
			for j in n + 1:
				var u := j / float(n)
				var r: float = r0 + (r1 - r0) * ((acc + L[i - 1] * u) / total)
				ell.call(pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * u, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * u, r, r)
			acc += L[i - 1]
	for s in [-1.0, 1.0]:
		var X := func(d: float) -> float: return CX + s * d
		cur[0] = 1
		stroke.call([[X.call(4), 11], [X.call(8), 8], [X.call(12), 6.5], [X.call(15), 4], [X.call(16), 1.5], [X.call(15.2), 0]], 2.3, 0.45)
		cur[0] = 3
		ell.call(X.call(10), 16, 7, 5)
		ell.call(X.call(8.5), 19.5, 5.5, 4.2)
		cur[0] = 2
		stroke.call([[X.call(14.5), 16.5], [X.call(17.5), 22], [X.call(18.5), 28]], 4, 3.2)
		stroke.call([[X.call(18.5), 28], [X.call(19), 33], [X.call(19.2), 36.5]], 3.4, 2.8)
		ell.call(X.call(19.2), 37.8, 3, 2.3)
		stroke.call([[X.call(17.2), 39], [X.call(16.6), 41.8]], 0.9, 0.4)
		stroke.call([[X.call(19.2), 39.5], [X.call(19.3), 42.6]], 0.9, 0.4)
		stroke.call([[X.call(21.2), 38.8], [X.call(22), 41.4]], 0.9, 0.4)
		cur[0] = 6
		stroke.call([[X.call(5.5), 31], [X.call(8), 37], [X.call(7.5), 42]], 4, 3)
		ell.call(X.call(8.5), 44.3, 4.2, 1.7)
	cur[0] = 7
	stroke.call([[CX, 30], [CX + 0.5, 36], [CX + 2.5, 41.5], [CX + 7, 44.6], [CX + 12.5, 44.2], [CX + 14.5, 42.5]], 2.3, 0.6)
	cur[0] = 4
	ell.call(CX, 22.5, 8.2, 7.5)
	cur[0] = 5
	ell.call(CX, 29.5, 6.2, 4.5)
	cur[0] = 0
	ell.call(CX, 12.5, 5.2, 4.6)
	ell.call(CX, 16, 4.2, 2.8)
	var pt := PackedInt32Array()
	pt.resize(N)
	for i in N:
		for k in 8:
			if parts[k][i]:
				pt[i] = k + 1
				break
	var on := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < W and y < H and pt[y * W + x] > 0
	var blur := func(src: PackedByteArray) -> PackedFloat32Array:
		var a := PackedFloat32Array()
		a.resize(N)
		for i in N:
			a[i] = src[i]
		var b := PackedFloat32Array()
		b.resize(N)
		for pass_ in 2:
			for y in H:
				for x in W:
					var s := 0.0
					for d in range(-2, 3):
						s += a[y * W + x + d] if (x + d >= 0 and x + d < W) else 0.0
					b[y * W + x] = s / 5
			for y in H:
				for x in W:
					var s := 0.0
					for d in range(-2, 3):
						s += b[(y + d) * W + x] if (y + d >= 0 and y + d < H) else 0.0
					a[y * W + x] = s / 5
		return a
	var amb := PackedFloat32Array()
	amb.resize(N)
	var down := PackedFloat32Array()
	down.resize(N)
	var rim := PackedFloat32Array()
	rim.resize(N)
	var crease := PackedByteArray()
	crease.resize(N)
	for k in 8:
		var B: PackedFloat32Array = blur.call(parts[k])
		var at := func(x: int, y: int) -> float: return B[y * W + x] if (x >= 0 and y >= 0 and x < W and y < H) else 0.0
		for y in H:
			for x in W:
				var i := y * W + x
				if pt[i] != k + 1:
					continue
				var gx: float = at.call(x + 1, y) - at.call(x - 1, y)
				var gy: float = at.call(x, y + 1) - at.call(x, y - 1)
				var g := Vector2(gx, gy).length()
				if g == 0.0:
					g = 1e-6
				var ox := -gx / g
				var oy := -gy / g
				var e := clamp01(g / 0.28)
				amb[i] = 0.42 + e * (0.4 * maxf(0, -oy) + 0.14 * maxf(0, -ox) - 0.3 * maxf(0, oy) - 0.08 * maxf(0, ox))
				down[i] = e * maxf(0, oy) * (0.3 if (absf(x + 0.5 - CX) < 7 and y > 27) else 1.0)
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var j: int = (y + dd.y) * W + x + dd.x
					if on.call(x + dd.x, y + dd.y) and pt[j] > k + 1:
						crease[i] = 1
	for y in H:
		for x in W:
			if not on.call(x, y):
				continue
			var kk := 1.0 if not on.call(x, y + 1) else 0.5 if not on.call(x, y + 2) else 0.0
			rim[y * W + x] = kk * 0.3 if (absf(x + 0.5 - CX) < 7 and y > 27) else kk
	var eyes := []
	var tusks := []
	for s in [-1.0, 1.0]:
		eyes.append(Vector2(jround(CX + s * 2.2 - 0.5), 12))
		eyes.append(Vector2(jround(CX + s * 3.2 - 0.5), 12))
		tusks.append(Vector2(jround(CX + s * 3.4 - 0.5), 16))
		tusks.append(Vector2(jround(CX + s * 3.6 - 0.5), 15))
	return {"w": W, "h": H, "part": pt, "amb": amb, "down": down, "rim": rim, "crease": crease, "eyes": eyes, "tusks": tusks,
		"glints": [Vector2(jround(CX - 2.7 - 0.5) - W / 2.0, 12 - H), Vector2(jround(CX + 2.7 - 0.5) - W / 2.0, 12 - H)]}


static func rise(t: float) -> float:
	if t < BREAK:
		return 0.0
	var a := out_cubic(clamp01((t - BREAK) / 0.4)) * 0.56
	var sag := 0.04 * sin(PI * clamp01((t - BREAK - 0.42) / 0.3))
	var b := out_back(clamp01((t - BREAK - 0.62) / 0.45), 1.4) * 0.44
	return a - sag + b


static func heat(t: float) -> float:
	return smooth(0, IGN, t) * (1 - smooth(FADE, FADE + 0.8, t)) * (1 - 0.25 * smooth(EYES + 0.2, EYES + 0.9, t)) * (0.85 + 0.15 * noise(t * 9, 3) + 0.5 * exp(-pow(t - BREAK, 2) / 0.02) + 0.3 * exp(-pow(t - EYES, 2) / 0.01))


func make() -> void:
	var W := Color.WHITE
	var SH: PackedColorArray = root.ramps.body
	var HR: PackedColorArray = root.ramps.horn
	var ST: PackedColorArray = root.ramps.stone
	var DUSTC := mixc(ST[2], Color8(0x7a, 0x6c, 0x78), 0.45)
	var B := beast()
	BW = B.w
	BH = B.h
	part = B.part
	R = JsRng.new(int(meta.options.seed))
	var ps := new_parts()
	ps.ground = 0.0
	var RUB := [ST[0], ST[1], mixc(ST[2], C[2], 0.3), mixc(ST[3], C[4], 0.3), mixc(ST[4], C[5], 0.35)]
	var rocks := new_bits()
	rocks.ground = 0.0
	var lm := new_lamps()
	var runes := []
	for i in 12:
		runes.append({"a": (i / 12.0) * TAU + 0.13, "g": GLYPHS[(i * 5 + 2) % GLYPHS.size()]})
	var cracks := []
	for i in 7:
		var a := (i / 7.0) * TAU + R.range(-0.25, 0.25)
		var r := 3.0
		var pts := [Vector2(0, 0)]
		var len := R.range(R1 * 0.6, R1 * 1.05)
		while r < len:
			r += R.range(2, 4)
			a += R.range(-0.3, 0.3)
			pts.append(Vector2(cos(a) * r, sin(a) * r * SY))
		cracks.append(pts)
	var st := {"t": 0.0}
	var done := {}
	var dur: float = root.duration
	var left := func(a: float, b: float) -> float: return maxf(0.05, minf(R.range(a, b), dur - 0.1 - st.t))
	var once := func(k: String, at: float) -> bool:
		if not done.get(k, false) and st.t >= at:
			done[k] = true
			return true
		return false
	var top_edge := func() -> Array:
		var off := BH * (1 - rise(st.t))
		var pts := []
		for x in BW:
			for y in BH:
				if part[y * BW + x]:
					var ly := y - BH + off
					if ly < 0:
						pts.append(Vector2(x - BW / 2.0, ly))
					break
		return pts

	var step := func(dt: float) -> void:
		st.t += dt
		var t: float = st.t
		var h := heat(t)
		# the rings smoulder: embers and thin smoke off the lines, sparks at the burning front
		if t < IGN:
			var ph := (t / IGN) * PI
			for s in [-1.0, 1.0]:
				var a: float = PI / 2 + s * ph
				var y := sin(a) * R0 * SY
				if R.chance(0.5):
					if y < -0.5:
						var vx := R.range(-40, 40)
						var vy := -R.range(40, 130)
						var life := R.range(0.2, 0.45)
						ps.spawn(SPARK, cos(a) * R0, y, vx, vy, life)
					else:
						var vx := R.range(-20, 20)
						var vy := -R.range(30, 70)
						var life := R.range(0.3, 0.6)
						ps.spawn(EMBER, cos(a) * R0, y, vx, vy, life, C[6], 1.4)
		if t > 0.2 and t < FADE + 0.6 and R.chance(0.2 * h):
			var a := R.range(0, TAU)
			var r: float = R.pick([R0, R1, R0])
			var vx := R.range(-10, 10)
			var vy := -R.range(20, 50)
			var life: float = left.call(0.8, 1.6)
			var sz := R.range(1, 1.8)
			ps.spawn(EMBER, cos(a) * r, sin(a) * r * SY, vx, vy, life, C[5], sz)
		if t > 0.15 and R.chance(0.4 * minf(1, h)):
			var a := R.range(0, TAU)
			var r := R0 if R.chance(0.7) else R1
			if (absf(fmod(a - PI / 2 + PI * 3, TAU) - PI) < (t / IGN) * PI) if t < IGN else true:
				var vx := R.range(-4, 4)
				var vy := -R.range(6, 16)
				var life := R.range(0.18, 0.4)
				var sz := R.range(0.8, 1.6) * minf(1, h)
				var fl := SMOKES if R.chance(0.25) else 0
				ps.spawn(FIRE, cos(a) * r, sin(a) * r * SY - 0.5, vx, vy, life, null, sz, 0, fl)
		if t > 0.3 and t < FADE + 0.4 and R.chance(0.05 * h):
			var a := R.range(0, TAU)
			var vx := R.range(-4, 4)
			var vy := -R.range(12, 24)
			var life: float = left.call(1.4, 2.2)
			var sz := R.range(2.2, 3.4)
			ps.spawn(SMOKE, cos(a) * R0 * 0.9, sin(a) * R0 * SY - 1, vx, vy, life, null, sz)
		if once.call("ign", IGN):
			lm.add(0, -4, 60, C[4], 0.55, 0.5)
		if once.call("runes", RUNES):
			lm.add(0, -4, 50, C[5], 0.5, 0.35)
		# the rumble: grit jumps on the floor, dust stirs
		if t > RUNES and t < BREAK and R.chance(0.35):
			var x := R.range(-R1, R1)
			var vx := R.range(-20, 20)
			var vy := -R.range(40, 120)
			var life := R.range(0.5, 0.9)
			var c: Color = R.pick([ST[2], ST[3], ST[4]])
			ps.spawn(GRIT, x, -0.5, vx, vy, life, c, 1)
		if t > RUNES and t < BREAK and R.chance(0.1):
			var x := R.range(-R1, R1)
			var vx := R.range(-12, 12)
			var vy := -R.range(4, 12)
			var life := R.range(0.4, 0.7)
			var sz := R.range(1.5, 2.5)
			ps.spawn(DUST, x, -1, vx, vy, life, DUSTC, sz)
		# the break: the floor bursts open
		if once.call("break", BREAK):
			lm.add(0, -18, 64, C[4], 0.9, 0.6)
			lm.add(0, -8, 26, C[6], 0.8, 0.14)
			for i in 18:
				var x := R.range(-14, 14)
				var vx := R.range(-75, 75)
				var vy := -R.range(170, 320)
				var life := R.range(1.6, 2.4)
				var an := R.range(0, TAU)
				var va := R.range(-14, 14)
				var s := R.range(1.3, 3)
				rocks.add({"kind": 1, "x": x, "y": -2.0, "vx": vx, "vy": vy, "g": 1.0, "drag": 0.7, "bounce": 0.32, "life": life, "a": an, "va": va, "s": s})
			for i in 60:
				var u := R.range(-1, 1)
				var a := -PI / 2 + u * 0.7
				var sp := R.range(80, 230) * (1 - 0.4 * absf(u))
				var life := R.range(1, 1.8)
				var c: Color = R.pick([ST[2], ST[3], ST[3], ST[4]])
				var sz := 2.0 if R.chance(0.4) else 1.0
				ps.spawn(GRIT, u * 10, -1, cos(a) * sp, sin(a) * sp, life, c, sz)
			for i in 12:
				var s := R.sign()
				var x := s * R.range(2, 14)
				var y := -R.range(1, 5)
				var vx := s * R.range(35, 100)
				var vy := -R.range(4, 24)
				var life := R.range(1.2, 2)
				var sz := R.range(3.5, 6)
				var dl := R.range(0, 0.1)
				ps.spawn(SMOKE, x, y, vx, vy, life, DUSTC, sz, dl, BIG)
			for i in 4:
				var s := R.sign()
				var x := s * R.range(10, 18)
				var y := -R.range(2, 8)
				var vx := s * R.range(10, 30)
				var vy := -R.range(40, 90)
				var life := R.range(1.4, 2.2)
				var sz := R.range(4, 6.5)
				var dl := R.range(0, 0.12)
				ps.spawn(SMOKE, x, y, vx, vy, life, DUSTC, sz, dl, BIG)
			for i in 24:
				var a := -PI / 2 + R.range(-1.1, 1.1)
				var sp := R.range(150, 360)
				var x := R.range(-6, 6)
				var life := R.range(0.25, 0.65)
				ps.spawn(SPARK, x, -2, cos(a) * sp, sin(a) * sp, life)
		# the heave: earth slides off its shoulders, dust rolls out round its feet
		var rv := rise(t) - rise(t - dt)
		if t > BREAK and t < BREAK + 1.2 and rv > 0:
			if R.chance(minf(0.9, rv * 140)):
				var e: Array = top_edge.call()
				if e.size():
					var p: Vector2 = R.pick(e)
					var vx := R.range(-25, 25)
					var vy := -R.range(10, 60)
					var life := R.range(0.8, 1.4)
					var c: Color = R.pick([ST[2], ST[3], ST[4]])
					var sz := 2.0 if R.chance(0.3) else 1.0
					ps.spawn(GRIT, p.x, p.y, vx, vy, life, c, sz)
			if R.chance(minf(0.8, rv * 70)):
				var s := R.sign()
				var x := s * R.range(10, 22)
				var y := -R.range(1, 4)
				var vx := s * R.range(30, 80)
				var vy := -R.range(2, 12)
				var life := R.range(1, 1.8)
				var sz := R.range(3, 5.5)
				ps.spawn(SMOKE, x, y, vx, vy, life, DUSTC, sz, 0, BIG)
		if once.call("heave2", BREAK + 0.64):
			lm.add(0, -10, 56, C[4], 0.6, 0.4)
			for i in 8:
				var x := R.sign() * R.range(10, 22)
				var vx := R.sign() * R.range(25, 70)
				var vy := -R.range(90, 180)
				var life := R.range(1.2, 1.8)
				var an := R.range(0, TAU)
				var va := R.range(-12, 12)
				var s := R.range(1.2, 2.4)
				rocks.add({"kind": 1, "x": x, "y": -2.0, "vx": vx, "vy": vy, "g": 1.0, "drag": 0.7, "bounce": 0.3, "life": life, "a": an, "va": va, "s": s})
		# the eyes flare
		if once.call("eyes", EYES):
			for g in B.glints:
				lm.add(g.x, g.y, 14, C[6], 0.7, 0.3)
				for i in 5:
					var vx := R.range(-90, 90)
					var vy := R.range(-90, 20)
					var life := R.range(0.15, 0.35)
					ps.spawn(SPARK, g.x, g.y, vx, vy, life)
			for i in 10:
				var s := R.sign()
				var x := s * R.range(8, 20)
				var vx := s * R.range(30, 80)
				var vy := -R.range(3, 10)
				var life := R.range(0.4, 0.8)
				var sz := R.range(1.5, 3)
				ps.spawn(DUST, x, -1, vx, vy, life, DUSTC, sz)
		if t > FADE + 0.05 and t < FADE + 0.75 and R.chance(0.45):
			var x: int = R.int_(4, BW - 5)
			var y: int = R.int_(2, BH - 4)
			if part[y * BW + x]:
				var lx := x - BW / 2.0
				var ly := float(y - BH)
				var vx := R.range(-6, 6)
				var vy := -R.range(10, 26)
				var life: float = left.call(0.9, 1.5)
				var sz := R.range(2, 3.4)
				ps.spawn(SMOKE, lx, ly, vx, vy, life, SOOT_C, sz)
				if R.chance(0.3):
					var vx2 := R.range(-10, 10)
					var vy2 := -R.range(15, 40)
					var life2: float = left.call(0.6, 1.2)
					ps.spawn(EMBER, lx, ly, vx2, vy2, life2, C[4], 1)
		rocks.step(dt)
		for b in rocks.list:
			if b.rest and not b.get("dusted", false):
				b.dusted = true
				for i in 2:
					var x: float = b.x + R.range(-1.5, 1.5)
					var vx := R.sign() * R.range(6, 30)
					var vy := -R.range(2, 12)
					var life := R.range(0.3, 0.6)
					var sz := R.range(1.2, 2.4)
					ps.spawn(DUST, x, -0.5, vx, vy, life, DUSTC, sz)
		ps.update(dt)
		lm.step(dt)
	var rec := func(s: int) -> void:
		rocks.record(s)
		ps.record(s)
		lm.record(s)
	run(step, rec)
	var u := "material:shader_parameter/"
	var pal := []
	for i in 8:
		pal.append(C[i])
	var hk := func(t: float) -> float: return heat(jt(t))

	# behind: the warm pool on the floor, the cracks, the rings, the runes, the gash, and their light
	for g in [["PoolLight", Vector2(0, -2), 52.0, C[4], 0.28], ["AirLight", Vector2(0, -22), 72.0, C[4], 0.1], ["HotLight", Vector2(0, -1), 22.0, C[5], 0.2]]:
		var gl := glow_path(g[0], g[1], g[1], g[2], g[3])
		var kk: float = g[4]
		keyf(gl, u + "k", func(t: float) -> float: return kk * hk.call(t) if hk.call(t) > 0.01 else 0.0)
	var cimg := Image.create(32, 7, false, Image.FORMAT_RGBAF)
	for c in cracks.size():
		for i in cracks[c].size():
			cimg.set_pixel(i, c, Color(cracks[c][i].x, cracks[c][i].y, 0, cracks[c].size()))
	var rimg := Image.create(64, 2, false, Image.FORMAT_RGBAF)
	var nseg := 0
	var mid := (R0 + R1) / 2 + 0.5
	for r in runes:
		var ta := Vector2(-sin(r.a), cos(r.a))
		var na := Vector2(cos(r.a), sin(r.a))
		var proj := func(p: Array) -> Vector2: return Vector2(na.x * mid + ta.x * p[0] * 1.1 + na.x * p[1], (na.y * mid + ta.y * p[0] * 1.1 + na.y * p[1]) * SY)
		for stroke in r.g:
			for i in range(1, stroke.size()):
				var a: Vector2 = proj.call(stroke[i - 1])
				var b: Vector2 = proj.call(stroke[i])
				rimg.set_pixel(nseg, 0, Color(a.x, a.y, b.x, b.y))
				rimg.set_pixel(nseg, 1, Color(r.a, 1, 0, 0))
				nseg += 1
	assert(nseg <= 64)
	var fparams := {"cracks": asset("_cracks", cimg), "runes": asset("_runes", rimg), "r0": R0, "r1": R1, "sy": SY, "ign_t": IGN, "pal": pal, "white": W}
	var fsize := Vector2(2 * ceilf(R0 + 4), 2 * ceilf((R0 + 3) * SY + 6))
	var fl := shape("Floor", ssh("summon_floor"), fsize, fparams, {"back": true})
	var fll := shape("FloorLight", ssh("summon_floor_light"), Vector2(2 * ceilf(R0 + 11), 2 * ceilf(R0 * SY + 11)), fparams)
	for n in [fl, fll]:
		keyf(n, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
		keyf(n, u + "heat_k", hk, 0.0, -1.0, 60.0, "nearest")
	keyf(fl, u + "ck", func(t: float) -> float: return smooth(RUNES, BREAK, jt(t)) * (1 - smooth(FADE, FADE + 0.7, jt(t))), 0.0, -1.0, 60.0, "nearest")
	keyf(fl, u + "cool", func(t: float) -> float: return smooth(BREAK + 0.1, BREAK + 1.1, jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(fl, u + "rk", func(t: float) -> float: return smooth(RUNES - 0.1, RUNES + 0.15, jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(fl, u + "inner", func(t: float) -> float: return smooth(RUNES - 0.15, RUNES + 0.05, jt(t)) if jt(t) > RUNES - 0.15 else 0.0, 0.0, -1.0, 60.0, "nearest")
	var hole := func(t: float) -> float: return smooth(BREAK - 0.05, BREAK + 0.15, jt(t)) * (1 - smooth(BREAK + 0.95, BREAK + 1.5, jt(t)))
	keyf(fl, u + "hole", hole, 0.0, -1.0, 60.0, "nearest")
	var hg := glow_path("GashLight", Vector2(0, 0), Vector2(0, 0), 24, C[5])
	keyf(hg, u + "k", func(t: float) -> float: return 0.3 * hole.call(t) * hk.call(t) if (hk.call(t) > 0.01 and hole.call(t) > 0) else 0.0)
	# the brute
	var bimg := Image.create(BW, BH, false, Image.FORMAT_RGBAF)
	for y in BH:
		for x in BW:
			var i := y * BW + x
			bimg.set_pixel(x, y, Color(part[i] + 16 * B.crease[i], B.amb[i], B.down[i], B.rim[i]))
	var bst := shape("Brute", ssh("beast"), Vector2(56, 50), {"beast": asset("_beast", bimg), "eyes_t": EYES, "break_t": BREAK, "fade_t": FADE,
		"eyes": PackedVector2Array(B.eyes), "tusks": PackedVector2Array(B.tusks), "glints": PackedVector2Array(B.glints), "sh": SH, "hr": HR, "pal": pal,
		"white": W}, {"at": Vector2(0, -24)})
	keyf(bst, u + "rise_on", func(t: float) -> float: return 1.0 if rise(jt(t)) > 0 else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(bst, u + "off", func(t: float) -> float: return BH * (1 - rise(jt(t))), 0.0, -1.0, 60.0, "nearest")
	keyf(bst, u + "k", func(t: float) -> float: return minf(1.0, hk.call(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(bst, u + "fade", func(t: float) -> float: return smooth(FADE + 0.1, FADE + 0.8, jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(bst, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	# its eyes' glow, and the light raking up its front
	for g in B.glints:
		var eg := glow_path("EyeLight%d" % int(g.x + 10), Vector2(g.x + 0.5, -46), Vector2(g.x + 0.5, 0), 6, C[5])
		var gp: Vector2 = g
		keyf(eg, u + "a", func(t: float) -> Vector2: return Vector2(gp.x + 0.5, gp.y + BH * (1 - rise(jt(t)))), 0.0, -1.0, 60.0, "nearest")
		keyf(eg, u + "b", func(t: float) -> Vector2: return Vector2(gp.x + 0.5, gp.y + BH * (1 - rise(jt(t)))), 0.0, -1.0, 60.0, "nearest")
		keyf(eg, u + "k", func(t: float) -> float:
			var tt := jt(t)
			if rise(tt) <= 0 or tt <= EYES - 0.05 or gp.y + BH * (1 - rise(tt)) >= 0:
				return 0.0
			return 0.5 * (1 - smooth(FADE + 0.6, FADE + 1.0, tt)) * (0.85 + 0.15 * sin(tt * 13)), 0.0, -1.0, 60.0, "nearest")
	var rake := glow_path("RakeLight", Vector2(0, -6), Vector2(0, -6), 30, C[4])
	keyf(rake, u + "k", func(t: float) -> float: return 0.25 * hk.call(t) * rise(jt(t)) if rise(jt(t)) > 0 else 0.0)
	# rubble, particles (the back ones go with the floor's fire), lights
	bits("Rubble", rocks, RUB)
	var em := parts("Parts", ps, {"sparks": [C[6], C[5], C[4], C[3]]})
	for e in em:
		if String(e.name) == "PartsBack":
			keyf(e, "visible", func(t: float) -> bool: return hk.call(t) > 0.01, 0.0, -1.0, 60.0, "nearest")
	lamps("Lights", lm)
