# reimagined-from: src/fx/shadow/soul-drain.js@180649ad575376cfec76edaf4943a8274ae9a5fd
# Soul drain: Pale souls are torn loose on the right and dragged down a funnel of streaks into a black crystal vessel, which flares violet as each one lands.
# loop, 3.20 s, 208x120 canvas, origin [40.0, 110.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# ramp soul: #2c3f66 #7d9fd0 #cfe6ff #ffffff
# The funnel's eleven streamlines (the original's beziers, its own rand()) are drawn once at build time into a data
# texture; a shader runs the dashes down them off the clock (fx/shadow/_souldrain_funnel.gdshader). The streaks
# racing down, the haze where souls are torn loose and the motes round the vessel are particles placed by a process
# shader (_souldrain_bits.gdshader) replaying the original's cycle() slots, with light twins. The black crystal is a
# shader keyed by the landings (_souldrain_vessel.gdshader); the souls (tail, face, the rings where they tear loose
# and land) are a shader on the soft layer (_souldrain_souls.gdshader); glows are keyed light nodes.
extends "res://build/fx/shadow/_pool.gd"

const D := 3.2
const VY := -50.0
const LINES := 11
const SOULS := 4
const TRAVEL := 1.45
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var LN: Array = []      # [sx, sy, c1x, c1y, c2x, c2y]
var S: PackedColorArray


static func wrapd(x: float) -> float:
	return fposmod(x, D)


func along(L: Array, u: float) -> Vector2:
	var v := 1.0 - u
	var a := v * v * v
	var b := 3.0 * v * v * u
	var c := 3.0 * v * u * u
	var d := u * u * u
	return Vector2(a * L[0] + b * L[2] + c * L[4], a * L[1] + b * L[3] + c * L[5] + d * (VY - L[1]) + d * L[1])


func soul_born(j: int) -> float:
	return (j + 0.15 + jrand([j, 7]) * 0.5) * (D / SOULS)


func soul_line(j: int) -> int:
	return floori(jrand([j, 8]) * LINES)


func landings(t: float) -> float:
	var f := 0.0
	for j in SOULS:
		var since := wrapd(t - soul_born(j) - TRAVEL)
		f += exp(-since / 0.14) * (1.0 if since < 1.0 else 0.0)
	return minf(1.4, f)


func y0_at(t: float) -> float:
	return VY + sin(TAU * t / D) * 1.5


func line_arrays() -> Array:
	var la := PackedVector4Array()
	var lb := PackedVector4Array()
	for L in LN:
		la.append(Vector4(L[0], L[1], L[2], L[3]))
		lb.append(Vector4(L[4], L[5], 0, 0))
	return [la, lb]


## The original's drawBack() streamlines, rasterised once: the faint lines (pre-dithered as the original dithers
## them) and the cells where a dash can still show (no later stroke covers them), with their u and line.
func funnel_data() -> Image:
	var w: int = root.canvas_size.x
	var h: int = root.canvas_size.y
	var ox: int = root.origin.x
	var oy: int = root.origin.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bits := PackedInt32Array()
	bits.resize(w * h)
	var cand := {}   # cell index -> [u, line]
	for i in LINES:
		var L: Array = LN[i]
		var prev := Vector2.INF
		var u := 0.0
		while u <= 1.0001:
			var p := along(L, u)
			if prev != Vector2.INF:
				var a := 0.4 + 0.6 * u
				var bright := u > 0.6
				# Bresenham from the previous sample's cell to this one's, dithered at alpha a
				var sx := floori(prev.x) + ox
				var sy := floori(prev.y) + oy
				var ex := floori(p.x) + ox
				var ey := floori(p.y) + oy
				var dx := absi(ex - sx)
				var dy := -absi(ey - sy)
				var stx := 1 if sx < ex else -1
				var sty := 1 if sy < ey else -1
				var err := dx + dy
				while true:
					var thr: float = (BAYER[((sy & 3) << 2) | (sx & 3)] + 0.5) / 16.0
					if (a >= 1.0 or a > thr) and sx >= 0 and sy >= 0 and sx < w and sy < h:
						var k := sy * w + sx
						bits[k] = 1 | (2 if bright else 0)
						cand.erase(k)
					if sx == ex and sy == ey:
						break
					var e2 := 2 * err
					if e2 >= dy:
						err += dy
						sx += stx
					if e2 <= dx:
						err += dx
						sy += sty
			var cx := floori(p.x) + ox
			var cy := floori(p.y) + oy
			if cx >= 0 and cy >= 0 and cx < w and cy < h:
				cand[cy * w + cx] = [u, i]
			prev = p
			u += 0.01
	for k in w * h:
		var b := bits[k]
		var col := Color(0, 0, 0, 0)
		if cand.has(k):
			var q: int = clampi(int(roundf(cand[k][0] * 65535.0)), 0, 65535)
			col = Color8(q >> 8, q & 255, int(cand[k][1]), b | 4)
		elif b != 0:
			col = Color8(0, 0, 0, b)
		img.set_pixel(k % w, k / w, col)
	return img


func bits(name: String, mode: int, amount: int, slots: PackedVector4Array, tex: Variant, o: Dictionary = {}) -> GPUParticles2D:
	var arrs := line_arrays()
	var pp := {"mode": mode, "period": D, "vy": VY, "la": arrs[0], "lb": arrs[1], "count": slots.size(), "tex_len": 10.0,
		"c4": C[4], "c6": C[6], "c7": C[7], "s1": S[1], "s2": S[2]}
	if slots.size() > 0:
		var full := slots.duplicate()
		while full.size() < 22:
			full.append(Vector4(0, 0, 0, 0))
		pp["slots"] = full
	var po := {"amount": amount, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": tex, "preprocess": 0.05,
		"process_shader": SHD + "_souldrain_bits.gdshader", "process_params": pp}
	po.merge(o, true)
	var p := particles(name, po)
	p.interpolate = false
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	return p


func make() -> void:
	S = root.ramps.soul
	for i in LINES:
		var sx := 96.0 + jrand([i, 1]) * 64.0
		var sy := -88.0 + jrand([i, 2]) * 72.0
		var bend := (jrand([i, 3]) - 0.5) * 50.0
		LN.append([sx, sy, sx * 0.55, sy + bend, 22.0 + jrand([i, 4]) * 14.0, VY + (sy - VY) * 0.25])
	var arrs := line_arrays()
	var canvas_mid := -Vector2(root.origin) + Vector2(root.canvas_size) / 2.0

	# drawBack: the funnel, and a wash of light round its mouth
	var fun := shape("Funnel", shadow_shader("souldrain_funnel"), Vector2(root.canvas_size), {"data": asset("funnel", funnel_data()),
		"period": D, "c2": C[2], "c3": C[3], "c5": C[5], "c6": C[6], "c7": C[7]}, {"at": canvas_mid, "back": true})
	key(fun, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	glow("Mouth", 41, {"radius": 40, "color": C[4], "alpha": 0.22}, {"at": Vector2(10, VY), "back": true})

	# draw: the haze out on the right (cycle 10, seed 8) and the streaks racing down (cycle 22, seed 9)
	var haze := PackedVector4Array()
	for i in 10:
		var g := jrng([8, i, 911])
		var born := g.next() * D
		var life := g.range(0.8, 1.3)
		var r := jrng([8, i])
		var hx := r.range(100, 150)
		haze.append(Vector4(born, life, hx, r.range(-80, -20)))
	bits("Haze", 2, 10, haze, "dot1")
	bits("HazeLight", 3, 10, haze, "glow8", {"layer": "light"})
	var streaks := PackedVector4Array()
	for i in 22:
		var g := jrng([9, i, 911])
		var born := g.next() * D
		var life := g.range(0.4, 0.7)
		var r := jrng([9, i])
		var li := floori(r.next() * LINES)
		streaks.append(Vector4(born, life, li, r.range(0.15, 0.5)))
	var img := Image.create(10, 1, false, Image.FORMAT_RGBA8)
	for x in 10:
		img.set_pixel(x, 0, C[4] if x < 4 else C[6] if x < 7 else Color.WHITE)
	keep_colour(Color.WHITE)
	bits("Streaks", 0, 22, streaks, asset("streak", img))
	bits("StreakLight", 1, 22, streaks, "glow8", {"layer": "light"})

	# the vessel, its light, the motes round it
	var ves := shape("Vessel", shadow_shader("souldrain_vessel"), Vector2(22, 34), {"c1": C[1], "c2": C[2], "c3": C[3],
		"c4": C[4], "c5": C[5], "c6": C[6], "c7": C[7], "white": Color.WHITE}, {"at": Vector2(0, VY)})
	keyf(ves, "material:shader_parameter/y0", func(t: float): return y0_at(t))
	keyf(ves, "material:shader_parameter/f", func(t: float): return landings(t))
	var vg := glow("VesselGlow", 52, {"radius": 30, "color": C[5], "alpha": 0.5}, {"at": Vector2(0, VY)})
	keyf(vg, "position", func(t: float): return Vector2(0, y0_at(t)))
	keyf(vg, "material:shader_parameter/radius", func(t: float): return 30.0 + 14.0 * landings(t))
	keyf(vg, "material:shader_parameter/alpha", func(t: float): return 0.5 + 0.5 * landings(t))
	var hg := glow("HeartGlow", 9, {"radius": 8, "color": Color.WHITE, "alpha": 0.25}, {"at": Vector2(0, VY + 1)})
	keyf(hg, "position", func(t: float): return Vector2(0, y0_at(t) + 1))
	keyf(hg, "material:shader_parameter/alpha", func(t: float): return 0.25 + 0.6 * landings(t))
	bits("Motes", 4, 6, PackedVector4Array(), "dot1")
	bits("MoteLight", 5, 6, PackedVector4Array(), "glow8", {"layer": "light"})

	# the souls, the rings where they tear loose and land; their light
	var sl := PackedVector4Array()
	for j in SOULS:
		sl.append(Vector4(soul_born(j), soul_line(j), j, 0))
	var souls := shape("Souls", shadow_shader("souldrain_souls"), Vector2(root.canvas_size), {"period": D, "travel": TRAVEL,
		"vy": VY, "la": arrs[0], "lb": arrs[1], "souls": sl, "s0": S[0], "s1": S[1], "s2": S[2], "s3": S[3], "c3": C[3],
		"c5": C[5], "c7": C[7], "translucent": true}, {"at": canvas_mid})
	key(souls, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	for j in SOULS:
		var L: Array = LN[soul_line(j)]
		var born := soul_born(j)
		var head := glow("SoulGlow%d" % j, 11, {"radius": 10, "color": S[1], "alpha": 0.0})
		keyf(head, "position", func(t: float):
			var age := wrapd(t - born)
			return along(L, pow(minf(age, TRAVEL) / TRAVEL, 1.8)).floor() + Vector2(0.5, 0.5))
		keyf(head, "material:shader_parameter/alpha", func(t: float): return 0.5 if wrapd(t - born) <= TRAVEL else 0.0)
		var tear := glow("TearGlow%d" % j, 13, {"radius": 12, "color": S[1], "alpha": 0.0}, {"at": Vector2(L[0], L[1]).floor() + Vector2(0.5, 0.5)})
		keyf(tear, "material:shader_parameter/alpha", func(t: float):
			var age := wrapd(t - born)
			return 0.5 * (1.0 - age / 0.18) if age < 0.18 else 0.0)
	var hal := halo("Halo", Vector2(0, VY), 23, 4, 22, C[6], 0.0)
	keyf(hal, "position", func(t: float): return Vector2(0, y0_at(t)))
	keyf(hal, "material:shader_parameter/k", func(t: float): return 0.25 * landings(t))
