# reimagined-from: src/fx/ice/freeze.js@471f08c7fcdb2f031927a0456498f543d2d64fbe
# Freeze: frost races in and climbs the character, turning it to ice; a faceted block crystallizes round it pane by
# pane, glints, cracks and bursts, and the character thaws free.
# Frost lines race in along the floor (the frost shader's fern mode) with streaks and vapour riding them. The
# character turns to ice pixel by pixel: the original's ragged flood up from the feet, worked out here into a map of
# when the frost reaches each pixel and its ice colour, which a shader over the stand-in plays (white at the front,
# rime feathers standing out from the outline, the ice running off from the top after the burst). The block is a
# glass shader (thirteen panes, each setting at its time, two sweeps of light, and their light) with Line2D edges, a
# white trace round each pane as it sets, cracks grown along the original's fracture walk; it jolts, shivers, flashes
# white under a flare and bursts into glass panes (textures drawn here) and shards that shatter where they land.
extends "res://build/fx/ice/_ice.gd"

const SNAP := 0.16
const CLIMB := [0.14, 0.62]
const SEAL := 0.6
const SWEEPS := Vector2(1.12, 1.82)
const CRACK := 2.2
const CRACK2 := 2.34
const FLASH := 2.46
const BURST := 2.52
const THAW := 0.36
const MELT := [2.95, 3.7]
const REACH := 38.0
const CORE := Vector2(0, -21)
const V := {
	"l0": Vector2(-15, 0), "l1": Vector2(-17, -10), "l2": Vector2(-17, -31), "p1": Vector2(-12, -45), "n1": Vector2(-6, -42), "p2": Vector2(0, -52),
	"n2": Vector2(6, -43), "p3": Vector2(12, -47), "r2": Vector2(17, -30), "r1": Vector2(16, -9), "r0": Vector2(14, 0),
	"i0": Vector2(-6, -36), "i1": Vector2(6, -35), "i2": Vector2(-9, -21), "i3": Vector2(3, -25), "i4": Vector2(9, -13), "i5": Vector2(-5, -8),
	"i6": Vector2(2, 0), "i7": Vector2(0, -40),
}
const FACET_DEF := [
	["l0 l1 i5 i6", 0.62, 0.0], ["i5 i4 i6", 0.42, 0.03], ["i4 r2 r1 r0 i6", 0.2, 0.05], ["l1 l2 i2 i5", 0.74, 0.08], ["i2 i3 i4 i5", 0.5, 0.1],
	["i1 r2 i4 i3", 0.28, 0.13], ["l2 i0 i2", 0.7, 0.15], ["i0 i1 i3 i2", 0.58, 0.18], ["n1 i7 n2 i1 i0", 0.52, 0.2], ["i1 n2 p3 r2", 0.4, 0.23],
	["l2 p1 n1 i0", 0.88, 0.25], ["p2 n2 i7", 0.66, 0.28], ["n1 p2 i7", 1.0, 0.31],
]
const OUTLINE_KEYS := "l0 l1 l2 p1 n1 p2 n2 p3 r2 r1 r0"

var facets := []
var outline := []
var A := Vector2i(-12, -38)


func jolt(t: float) -> float:
	if t >= CRACK and t < CRACK + 0.06:
		return 1.0
	if t >= CRACK2 and t < FLASH:
		return 1.0 if int(floor(t * 40.0)) % 2 else -1.0
	return 0.0


func sweep(F: Dictionary, t: float) -> float:
	var g := 0.0
	for s0 in [SWEEPS.x, SWEEPS.y]:
		g = maxf(g, sin(PI * clamp01((t - s0 - F.d * 0.32) / 0.13)))
	return g * (0.35 + 0.65 * F.lit)


static func in_quad(x: float) -> float:
	return x * x


static func out_quad(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


func make() -> void:
	var D: float = root.duration
	rng.seed = 5
	ground()
	for k in OUTLINE_KEYS.split(" "):
		outline.append(V[k])
	for i in FACET_DEF.size():
		var f: Array = FACET_DEF[i]
		var pts := []
		var names: PackedStringArray = String(f[0]).split(" ")
		for k in names:
			pts.append(V[k])
		var c := centroid(pts)
		var perim := 0.0
		for k in pts.size():
			perim += (pts[(k + 1) % pts.size()] - pts[k]).length()
		facets.append({"pts": pts, "names": names, "lit": f[1], "at": SEAL + f[2], "c": Vector2(c.x, c.y), "area": c.z,
			"tint": C[3 + int(roundf(f[1] * 3.0))], "alpha": 0.2 + 0.24 * f[1], "d": clamp01((c.x + 0.55 * c.y + 36.0) / 46.0), "len": perim, "i": i})

	# frost lines racing in along the floor to the feet, rime ferns standing up, melting at the end
	var frost := shape("Frost", load(ICE + "_frost.gdshader"), Vector2(2 * (REACH + 4), 24), {"kind": 3, "x1": REACH, "start": SNAP,
		"ramp": ramp("palette", {"stops": 8})}, {"at": Vector2(0, 0), "back": true})
	key(frost, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	key(frost, "material:shader_parameter/a", sample(func(t: float) -> float: return 1.0 - smooth(MELT[0], MELT[1], t)), "nearest")
	for s in [-1, 1]:
		var tag := "L" if s < 0 else "R"
		var rider := group("Race%s" % tag, {"at": Vector2(s * REACH, 0)})
		key(rider, "position", sample(func(t: float) -> Vector2: return Vector2(s * REACH * maxf(0.0, 1.0 - t / SNAP), 0), 0.0, SNAP + 0.04))
		var st := particles("RaceStreaks%s" % tag, {"parent": rider, "at": Vector2(s * 3, -2.5), "amount": 7, "lifetime": 0.13, "texture": tex("fade6"),
			"align": true, "emit": {"box": Vector2(3, 1.5)}, "dir": 90 - s * 90, "speed": [50, 90], "initial": gradient([C[6], C[5]])})
		st.position = Vector2(s * 3, -2.5)
		var vp := particles("RaceVapour%s" % tag, {"parent": rider, "layer": "soft", "back": true, "at": Vector2(0, -1), "amount": 2, "lifetime": 0.4,
			"texture": tex("puff16"), "emit": {"box": Vector2(1, 1)}, "dir": 90 - s * 93, "speed": [40, 90], "drag": true, "damping": [4, 4],
			"scale_curve": [[0, 0.25], [1, 0.4]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
		vp.position = Vector2(0, -1)
		emit_all([st, vp], 0.0, SNAP)

	# the cold light: a pool under the ice, a glow in it that brightens as it cracks, the climbing front's light
	var hold := func(t: float) -> float: return smooth(CLIMB[0], SEAL, t) * (1.0 - smooth(BURST, BURST + 0.6, t))
	var pool := glow("Pool", 36, {"radius": 34, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -2)})
	key(pool, "material:shader_parameter/alpha", sample(func(t: float) -> float: return 0.22 * hold.call(t) * (0.85 + 0.15 * sin(t * 3.0))))
	var core := glow("CoreLight", 42, {"radius": 40, "color": C[3], "alpha": 0.0}, {"at": CORE + Vector2(0, -4)})
	key(core, "material:shader_parameter/alpha", sample(func(t: float) -> float: return (0.22 + 0.1 * smooth(CRACK, FLASH, t)) * hold.call(t)))
	var climb := glow("ClimbLight", 20, {"radius": 18, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, 0)})
	key(climb, "position", sample(func(t: float) -> Vector2: return Vector2(0, roundf(-38.0 * out_quad(seg(t, CLIMB[0], CLIMB[1]))))), "nearest")
	key(climb, "material:shader_parameter/alpha", sample(func(t: float) -> float: return 0.28 if (t > CLIMB[0] and t < CLIMB[1]) else 0.0), "nearest")

	character()
	block()
	setting()
	breaking()


## The character turned to ice: the original's flood up from the feet, quicker round the outline, as maps a shader
## plays; rime feathers off the outline; stars and snow kicked off the climbing front.
func character() -> void:
	var D: float = root.duration
	var img: Image = load(EFFECT.STAND_INS[2]).get_image()
	var W := img.get_width()
	var H := img.get_height()
	var on := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < W and y < H and img.get_pixel(x, y).a > 0.5
	var N := W * H
	var dist := []
	dist.resize(N)
	dist.fill(INF)
	var rim := []
	rim.resize(N)
	var ice := []
	ice.resize(N)
	var open := []
	for y in H:
		for x in W:
			if not on.call(x, y):
				continue
			var i := y * W + x
			rim[i] = not on.call(x - 1, y) or not on.call(x + 1, y) or not on.call(x, y - 1)
			var up: bool = not on.call(x - 1, y) or not on.call(x, y - 1)
			var c := img.get_pixel(x, y)
			var l := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			var k := clampi(int(roundf(2.0 if l < 0.12 else 2.0 + l * 5.2)), 1, 7)
			if up:
				k = mini(7, k + 1)
			ice[i] = C[k].lerp(C[6], 0.2)
			keep_colour(ice[i])
			if (y == H - 1 or not on.call(x, y + 1)) and y >= H - 4:
				dist[i] = rng.randf_range(0, 1.5)
				open.append(i)
	var done := {}
	while open.size():
		var bi := 0
		for j in range(1, open.size()):
			if dist[open[j]] < dist[open[bi]]:
				bi = j
		var i: int = open[bi]
		open[bi] = open[-1]
		open.pop_back()
		if done.has(i):
			continue
		done[i] = true
		var x := i % W
		var y := i / W
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if not on.call(nx, ny):
				continue
			var j := ny * W + nx
			var w: float = (0.55 if rim[j] else 1.0) * (1.0 if d.y < 0 else 1.3) + rng.randf_range(0, 1.5)
			if dist[i] + w < dist[j]:
				dist[j] = dist[i] + w
				open.append(j)
	var max_d := 0.0
	for i in N:
		if dist[i] < INF:
			max_d = maxf(max_d, dist[i])
	var M := 3
	var when := Image.create(W + 2 * M, H + 2 * M, false, Image.FORMAT_RGBA8)
	var cols := Image.create(W + 2 * M, H + 2 * M, false, Image.FORMAT_RGBA8)
	var fe := Image.create(W + 2 * M, H + 2 * M, false, Image.FORMAT_RGBA8)
	for im in [when, cols, fe]:
		im.fill(Color(0, 0, 0, 0))
	var enc := func(t: float) -> Color:
		var v := t * 255.0 / 8.0
		return Color(floorf(v) / 255.0, v - floorf(v), 1.0, 1.0)
	var order := []
	var reach := {}
	for i in N:
		if dist[i] < INF:
			reach[i] = CLIMB[0] + (CLIMB[1] - CLIMB[0]) * pow(dist[i] / max_d, 0.85)
			order.append(i)
			when.set_pixel(i % W + M, i / W + M, enc.call(reach[i]))
			cols.set_pixel(i % W + M, i / W + M, ice[i])
	order.sort_custom(func(a: int, b: int) -> bool: return reach[a] < reach[b])
	# rime feathers: little ticks of frost standing out from the outline once the frost has passed
	var feathers := []
	for i in order:
		var x: int = i % W
		var y: int = i / W
		if not rim[i] or jrand([i, 5, 3]) > 0.42 or y > H - 3:
			continue
		var dx := -1 if not on.call(x - 1, y) else (1 if not on.call(x + 1, y) else (-1 if jrand([i, 9]) < 0.5 else 1))
		var dy := -1 if not on.call(x, y - 1) else (-1 if jrand([i, 4]) < 0.5 else 0)
		var L := 1 + int(floor(jrand([i, 7]) * 2.6))
		var at: float = reach[i] + 0.04
		for j in L:
			var q := Vector2i(x + dx + dx * j + M, y + dy + dy * j + M)
			if q.x < 0 or q.y < 0 or q.x >= W + 2 * M or q.y >= H + 2 * M:
				continue
			var c: Color = enc.call(at + 0.08 * (j + 0.5) / L)
			c.a = 1.0 if j == L - 1 else 0.5
			fe.set_pixel(q.x, q.y, c)
		feathers.append(Vector2(A.x + x + dx, A.y + y + dy))
	var node := shape("Frozen", load(ICE + "_frozen.gdshader"), Vector2(W + 2 * M, H + 2 * M), {"when": asset("when.png", when), "ice": asset("ice.png", cols),
		"feathers": asset("feathers.png", fe), "margin": float(M), "burst": BURST, "c6": C[6], "c7": C[7]},
		{"at": Vector2(A.x - M + (W + 2 * M) / 2.0, A.y - M + (H + 2 * M) / 2.0)})
	key(node, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	key(node, "material:shader_parameter/thaw", sample(func(t: float) -> float: return in_quad(seg(t, BURST, BURST + THAW)) * (H + 2) - 2.0 if t >= BURST else -1.0), "nearest")
	# stars and snow kicked off the climbing front
	var front := group("ClimbFront", {"at": Vector2(0, -2)})
	key(front, "position", sample(func(t: float) -> Vector2: return Vector2(0, -2.0 - 34.0 * pow(seg(t, CLIMB[0], CLIMB[1]), 1.15)), 0.0, CLIMB[1] + 0.05))
	var stars := particles("ClimbStars", {"parent": front, "amount": 12, "lifetime": 0.32, "texture": "plus3", "emitting": false, "emit": {"box": Vector2(8, 3)},
		"dir": -90, "spread": 30, "speed": [3, 18], "initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.4, 0.5], [0.7, 1], [1, 0]]})
	var hearts: GPUParticles2D = stars.duplicate()
	hearts.name = "ClimbStarHearts"
	front.add_child(hearts)
	hearts.texture = texture("dot1")
	hearts.modulate = Color(2, 2, 2, 1)
	hearts.seed = stars.seed
	var flakes := particles("ClimbSnow", {"parent": front, "amount": 5, "lifetime": 0.7, "texture": "dot1", "emitting": false, "emit": {"box": Vector2(8, 3)},
		"dir": -90, "spread": 45, "speed": [10, 30], "gravity": Vector2(0, 35), "color": C[6], "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	emit_all([stars, hearts, flakes], CLIMB[0], CLIMB[1] + 0.03)
	# the burst throws half the feathers off as white splinters; the last of the ice runs off as drips
	var half := PackedVector2Array()
	for k in feathers.size():
		if k % 2 == 0:
			half.append(feathers[k])
	if half.size():
		var fs := particles("FeatherShards", {"at": Vector2.ZERO, "amount": half.size(), "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "streak3", "emit": {"points": half}, "dir": -90, "spread": 55, "speed": [30, 100], "damping": [40, 70],
			"gravity": Vector2(0, 760), "angle": [0, 360], "spin": [-1100, 1100], "color": Color.WHITE, "alpha_curve": [[0, 1], [0.6, 1], [1, 0]],
			"life_random": 0.5, "collide": {"bounce": 0.3, "size": 1}})
		emit(fs, BURST)
	var thaw := group("ThawLine", {"at": Vector2(0, A.y)})
	key(thaw, "position", sample(func(t: float) -> Vector2: return Vector2(0, -H + in_quad(seg(t, BURST, BURST + THAW)) * H), BURST, BURST + THAW))
	var drips := particles("Drips", {"parent": thaw, "amount": 4, "lifetime": 0.5, "texture": tex("fade4"), "align": true, "emitting": false,
		"emit": {"box": Vector2(9, 1)}, "dir": 90, "speed": [10, 10], "gravity": Vector2(0, 475), "color": C[5], "collide": {"hide": true, "size": 0.5}})
	emit(drips, BURST, BURST + THAW)


## The block: glass panes setting one by one, lit edges, a sweep of light twice, cracks; it jolts and shivers.
func block() -> void:
	var D: float = root.duration
	var body := group("Block")
	key(body, "position", sample(func(t: float) -> Vector2: return Vector2(jolt(t), 0)), "nearest")
	show(body, SEAL - 0.08, BURST)
	# which pane every pixel belongs to
	var fid := Image.create(36, 53, false, Image.FORMAT_RGBA8)
	fid.fill(Color(0, 0, 0, 0))
	for y in range(-53, 0):
		for x in range(-18, 18):
			var q := Vector2(x + 0.5, y + 0.5)
			if not in_poly(outline, q):
				continue
			var f := -1
			for F in facets:
				if in_poly(F.pts, q):
					f = F.i
					break
			if f < 0:
				var best := INF
				for F in facets:
					var dd: float = F.c.distance_to(Vector2(x, y))
					if dd < best:
						best = dd
						f = F.i
			fid.set_pixel(x + 18, y + 53, Color(f / 255.0, 0, 1, 1))
	var ats := PackedFloat32Array()
	var tints := PackedColorArray()
	var strengths := PackedFloat32Array()
	var delays := PackedFloat32Array()
	var lits := PackedFloat32Array()
	for F in facets:
		ats.append(F.at)
		tints.append(F.tint)
		strengths.append(F.alpha)
		delays.append(F.d)
		lits.append(F.lit)
	var tex_f := asset("facets.png", fid)
	var glass := shape("Glass", load(ICE + "_glass.gdshader"), Vector2(36, 53), {"facets": tex_f, "at": ats, "tints": tints, "opacity": strengths,
		"delay": delays, "lit": lits, "sweeps": SWEEPS, "c6": C[6], "c7": C[7], "translucent": true}, {"at": Vector2(0, -26.5), "parent": body})
	var shine := shape("GlassLight", load(ICE + "_glass_light.gdshader"), Vector2(36, 53), {"facets": tex_f, "at": ats, "delay": delays, "lit": lits,
		"sweeps": SWEEPS, "c5": C[5]}, {"at": Vector2(0, -26.5), "parent": body})
	for n in [glass, shine]:
		key(n, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
		key(n, "material:shader_parameter/white", sample(func(t: float) -> float: return 1.0 if t >= FLASH else 0.0), "nearest")
	# its edges: the outline lit where it faces up and left, cool on the shadow side with a deep rim outside it;
	# inner edges pale; any pane that has just set (or flashes in a sweep) rings white
	var edges := []
	for F in facets:
		for k in F.names.size():
			var a: String = F.names[k]
			var b: String = F.names[(k + 1) % F.names.size()]
			var e: Dictionary = {}
			for o in edges:
				if (o.a == a and o.b == b) or (o.a == b and o.b == a):
					e = o
			if e.is_empty():
				e = {"a": a, "b": b, "fs": []}
				edges.append(e)
			e.fs.append(F)
	var n := 0
	for e in edges:
		var p0: Vector2 = V[e.a]
		var p1: Vector2 = V[e.b]
		var c: Vector2 = e.fs[0].c
		var nv := Vector2(p1.y - p0.y, p0.x - p1.x)
		if nv.dot((p0 + p1) / 2.0 - c) < 0.0:
			nv = -nv
		var outer: bool = e.fs.size() == 1
		var lit: float = (-nv.x * 0.55 - nv.y * 0.84) / nv.length()
		if p0.y == 0 and p1.y == 0:
			continue
		var at := INF
		for F in e.fs:
			at = minf(at, F.at)
		var pts := PackedVector2Array([p0 + Vector2(0.5, 0.5), p1 + Vector2(0.5, 0.5)])
		if outer and lit < 0.0:
			var deep := line("Deep%d" % n, PackedVector2Array([pts[0] + Vector2(1, 0), pts[1] + Vector2(1, 0)]), {"color": C[1], "parent": body})
			show(deep, at, FLASH)
		if outer:
			var gl := glow_line("EdgeLight%d" % n, p0, p1, 5, C[4], 0.1)
			show(gl, at, BURST)
		var edge := line("Edge%d" % n, pts, {"color": C[5], "parent": body})
		show(edge, at)
		var base: Color = (Color.WHITE if lit > 0.3 else (C[6] if lit > -0.2 else C[4])) if outer else (C[6] if (p0.y + p1.y) / 2.0 < -30.0 else C[5])
		var fs: Array = e.fs
		key(edge, "default_color", sample(func(t: float) -> Color:
			if t >= FLASH:
				return C[6]
			for F in fs:
				if t - F.at < 0.1 or sweep(F, t) > 0.6:
					return Color.WHITE
			return base, at, BURST), "nearest")
		n += 1
	for c in [C[1], C[4], C[5], C[6]]:
		keep_colour(c)
	# a pane about to set: its edges traced in white from its first corner round, a bead of light at the head
	for F in facets:
		var trace := line("Trace%d" % F.i, PackedVector2Array(), {"color": Color.WHITE, "parent": body})
		var bead := glow("Bead%d" % F.i, 7, {"radius": 6, "color": C[6], "alpha": 0.0}, {"at": F.pts[0], "parent": body})
		var kp := [[0.0, PackedVector2Array()]]
		var kb := [[0.0, Vector2(F.pts[0])]]
		var ka := [[0.0, 0.0]]
		for f in int(roundf(D * FPS)) + 1:
			var t := f / FPS
			var age: float = t - F.at
			if age < -0.07 or age >= 0.0:
				continue
			var left: float = (age + 0.07) / 0.07 * F.len
			var pts := PackedVector2Array([F.pts[0] + Vector2(0.5, 0.5)])
			var head: Vector2 = F.pts[0]
			for k in F.pts.size():
				if left <= 0.0:
					break
				var a: Vector2 = F.pts[k]
				var b: Vector2 = F.pts[(k + 1) % F.pts.size()]
				var v := minf(1.0, left / (b - a).length())
				left -= (b - a).length()
				head = a.lerp(b, v)
				pts.append(cell(head))
			kp.append([t, pts])
			kb.append([t, head.round()])
			ka.append([t, 0.6])
			kp.append([t + 1.0 / FPS - 0.001, PackedVector2Array()])
			ka.append([t + 1.0 / FPS - 0.001, 0.0])
		key(trace, "points", kp, "nearest")
		key(bead, "position", kb, "nearest")
		key(bead, "material:shader_parameter/alpha", ka, "nearest")
	# cracks walking out from its heart, a second wave racing over it; drawn until it flashes white
	var lines := group("Cracks", {"parent": body})
	show(lines, 0.0, FLASH)
	var cracks := fractures(outline, CORE, 3, 9, -2.2, 3.6, 0.16)
	var cracks2 := fractures(outline, CORE + Vector2(1, -2), 6, 16, rng.randf_range(0, TAU), TAU, 0.22)
	var i := 0
	for set in [[cracks, CRACK, 150.0], [cracks2, CRACK2, 190.0]]:
		for pts in set[0]:
			grow_crack("Crack%d" % i, pts, set[1], set[2], lines, BURST)
			i += 1
	# the seal: a star at the crown as the last pane sets
	var top: float = facets[-1].at
	var star := sparkle("Seal", {"reach": 22})
	var keys := []
	for f in int(roundf(D * FPS)) + 1:
		var t := f / FPS
		var g := t - top
		keys.append([t, V.p2, 8.0 * out_back(minf(1.0, g / 0.06)) * (1.0 - g / 0.3) if (g > 0.0 and g < 0.3) else 0.0, 0.6])
	sparkle_keys(star, keys)
	var fl := flare("Flare", CORE, 36)
	key(fl, "material:shader_parameter/len", sample(func(t: float) -> float: return 34.0 * pow(1.0 - clamp01((t - FLASH) / 0.22), 1.4) if (t >= FLASH and t < BURST + 0.16) else 0.0), "nearest")
	key(fl, "material:shader_parameter/k", sample(func(t: float) -> float: return 1.0 - clamp01((t - FLASH) / 0.22)), "nearest")


## Each pane snaps into place with a chip of shards, a puff and a glint; then it holds: glints on its corners, cold
## vapour off its foot, a little snow; it cracks: chips spall off, light leaks out.
func setting() -> void:
	for F in facets:
		var c: Vector2 = F.c
		var out := (c - CORE).angle()
		var sh := particles("Chip%d" % F.i, {"at": c, "amount": 3, "lifetime": 0.55, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": "streak3", "dir": rad_to_deg(Vector2.from_angle(out).lerp(Vector2.UP, 0.3).angle()), "spread": 40, "speed": [50, 120],
			"damping": [50, 80], "gravity": Vector2(0, 760), "angle": [0, 360], "spin": [-1000, 1000], "initial": gradient([C[5], C[6], C[7]]),
			"alpha_curve": [[0, 1], [0.6, 1], [1, 0]], "life_random": 0.4})
		var st := particles("Glint%d" % F.i, {"at": c, "amount": 1, "lifetime": 0.35, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": "spark5", "emit": {"box": Vector2(2, 2)}, "dir": -90, "speed": [4, 4], "color": Color.WHITE,
			"alpha_curve": [[0, 1], [0.4, 0.5], [0.7, 1], [1, 0]]})
		emit_all([sh, st], F.at)
		if c.y > -14:
			var vp := particles("SetPuff%d" % F.i, {"layer": "soft", "at": Vector2(c.x, -1), "amount": 1, "lifetime": 0.65, "one_shot": true,
				"explosiveness": 1.0, "emitting": false, "texture": tex("puff16"), "dir": 90 - signf(c.x if c.x != 0 else 1.0) * 98, "speed": [10, 30],
				"scale_curve": [[0, 0.4], [1, 0.7]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
			emit(vp, F.at)
		light_flash("SetLight%d" % F.i, c, 16, C[6], 0.4, F.at, 0.12)
	var sealed: float = facets[-1].at
	light_flash("SealLight", Vector2(0, -26), 70, C[5], 0.6, sealed, 0.4)
	var seal_stars := particles("SealStars", {"at": Vector2(0, -25), "amount": 5, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "emit": {"box": Vector2(15, 19)}, "dir": -90, "spread": 40, "speed": [0, 8], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.4, 0.5], [0.7, 1], [1, 0]], "life_random": 0.5})
	emit(seal_stars, sealed)
	var corners := PackedVector2Array()
	for k in V:
		corners.append(V[k])
	var winks := particles("Winks", {"at": Vector2.ZERO, "amount": 2, "lifetime": 0.45, "texture": "plus3", "emitting": false, "emit": {"points": corners},
		"dir": -90, "speed": [2, 2], "initial": gradient([C[6], C[6], Color.WHITE]), "alpha_curve": [[0, 0], [0.15, 1], [0.4, 0.4], [0.6, 1], [1, 0]]})
	emit(winks, sealed, CRACK2)
	for s in [-1, 1]:
		var foot := particles("FootVapour%s" % ("L" if s < 0 else "R"), {"layer": "soft", "back": true, "at": Vector2(s * 15, -2), "amount": 2, "lifetime": 0.9,
			"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(3, 1)}, "dir": 90 - s * 100, "speed": [8, 24],
			"scale_curve": [[0, 0.3], [1, 0.5]], "ramp": gradient([Color(C[6], 0.4), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
		emit(foot, sealed, CRACK2)
	var snow := particles("Snow", {"at": Vector2(0, -66), "amount": 2, "lifetime": 1.5, "texture": "dot1", "emitting": false, "emit": {"box": Vector2(30, 10)},
		"dir": 90, "spread": 30, "speed": [4, 10], "gravity": Vector2(0, 20), "initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	emit(snow, sealed, CRACK2 - 0.6)
	light_flash("CrackLight", CORE, 26, Color.WHITE, 0.4, CRACK, 0.1)
	var spall := particles("Spall", {"at": Vector2(0, -25), "amount": 4, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"box": Vector2(14, 15)}, "dir": -90, "spread": 50, "speed": [10, 60], "gravity": Vector2(0, 855), "angle": [0, 360],
		"spin": [-1100, 1100], "initial": gradient([C[5], C[6], C[7]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]], "collide": {"bounce": 0.3, "size": 1}})
	emit(spall, CRACK)
	light_flash("Crack2Light", CORE, 40, C[6], 0.35, CRACK2, 0.16)
	var leak := particles("LeakStars", {"at": Vector2(0, -24), "amount": 3, "lifetime": 0.25, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "emit": {"box": Vector2(12, 16)}, "dir": -90, "speed": [3, 3], "color": Color.WHITE, "alpha_curve": [[0, 1], [0.5, 0.5], [1, 0]]})
	emit(leak, CRACK2)
	light_flash("FlashLight", CORE, 60, Color.WHITE, 0.9, FLASH, 0.1)


## It bursts: the panes fly off tumbling and shatter where they land, shards and ice dust, glints, a flurry, light.
func breaking() -> void:
	light_flash("BurstWhite", CORE, 64, Color.WHITE, 0.85, BURST, 0.14)
	light_flash("BurstCold", CORE + Vector2(0, -4), 72, C[4], 0.55, BURST, 0.6)
	var sizes := {"glass_l": PackedVector2Array(), "glass_m": PackedVector2Array(), "glass_s": PackedVector2Array()}
	for F in facets:
		for part in chop(F.pts, 0):
			var m := centroid(part)
			var k := "glass_l" if m.z > 14.0 else ("glass_m" if m.z > 7.0 else "glass_s")
			sizes[k].append(Vector2(m.x, m.y) - CORE)
	for k in sizes:
		var all: PackedVector2Array = sizes[k]
		# two emitters a quarter turn apart, so they don't all square up to the light at once
		for h in 2:
			var pts := PackedVector2Array()
			for j in all.size():
				if j % 2 == h:
					pts.append(all[j])
			if pts.is_empty():
				continue
			var p := particles("Panes_%s_%d" % [k, h], {"layer": "soft", "at": CORE, "amount": pts.size(), "lifetime": 1.45, "one_shot": true,
				"explosiveness": 1.0, "emitting": false, "texture": tex(k), "emit": {"points": pts}, "dir": -90, "spread": 12, "speed": [90, 190],
				"radial_speed": [40, 85], "damping": [50, 80], "gravity": Vector2(0, 807), "angle": [-40, 40], "spin": [-515, 515],
				"alpha_curve": [[0, 1], [0.8, 1], [1, 0]], "life_random": 0.3, "collide": {"hide": true, "size": 0.5}})
			var turns: float = {"glass_l": 1.6, "glass_m": 2.2, "glass_s": 2.8}[k]
			tumble(p, turns + h * 0.4, {"glass_l": 0.3, "glass_m": 1.2, "glass_s": 2.0}[k] + h * PI / 2.0)
			emit(p, BURST)
	var inside := PackedVector2Array()
	while inside.size() < 40:
		var q := Vector2(rng.randi_range(-18, 17), rng.randi_range(-53, -1))
		if in_poly(outline, q + Vector2(0.5, 0.5)):
			inside.append(q - CORE)
	var shards := particles("Shards", {"at": CORE, "amount": 40, "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"points": inside}, "dir": -90, "spread": 15, "speed": [60, 170], "radial_speed": [50, 130], "damping": [70, 110],
		"gravity": Vector2(0, 807), "angle": [0, 360], "spin": [-1260, 1260], "initial": gradient([C[4], C[5], C[6], C[7]]),
		"alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "life_random": 0.4, "collide": {"bounce": 0.3, "friction": 0.8, "size": 1}})
	emit(shards, BURST)
	# where the panes land: splinters skipping along the floor, puffs of ice dust, glints
	var land := particles("LandSplinters", {"at": Vector2(0, -1), "amount": 14, "lifetime": 0.6, "texture": "streak3", "emitting": false,
		"emit": {"box": Vector2(40, 0.5)}, "dir": -90, "spread": 55, "speed": [30, 100], "gravity": Vector2(0, 760), "angle": [0, 360],
		"spin": [-1000, 1000], "initial": gradient([C[5], C[6], C[7]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]], "collide": {"bounce": 0.35, "size": 1}})
	var dust := particles("LandDust", {"layer": "soft", "at": Vector2(0, -1.5), "amount": 4, "lifetime": 0.55, "texture": tex("puff16"), "emitting": false,
		"emit": {"box": Vector2(40, 1)}, "dir": -90, "spread": 60, "speed": [5, 25], "scale_curve": [[0, 0.3], [1, 0.5]],
		"ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	emit_all([land, dust], BURST + 0.3, BURST + 0.85)
	for s in [-1, 1]:
		var vp := particles("BurstVapour%s" % ("L" if s < 0 else "R"), {"layer": "soft", "at": Vector2(s * 9, -3.5), "amount": 6, "lifetime": 1.1,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(7, 2.5)}, "dir": 90 - s * 100,
			"spread": 8, "speed": [30, 90], "damping": [50, 80], "scale_curve": [[0, 0.45], [1, 1.0]], "life_random": 0.4,
			"ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.25), Color(C[6], 0.08), Color(C[6], 0.0)], [0.0, 0.4, 0.8, 1.0], true)})
		emit(vp, BURST)
	var cloud := particles("BurstCloud", {"layer": "soft", "at": Vector2(0, -24), "amount": 8, "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(14, 16)}, "dir": -90, "spread": 45, "speed": [10, 35], "damping": [20, 30],
		"scale_curve": [[0, 0.6], [1, 1.2]], "life_random": 0.4,
		"ramp": gradient([Color(C[6], 0.4), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	var haze := lit_copy(cloud, "CloudHaze", "glow16", Color(C[5], 0.16), [[0, 1], [1, 0]])
	var flurry := particles("Flurry", {"at": CORE, "amount": 18, "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "dot1",
		"emit": {"box": Vector2(10, 12)}, "dir": -90, "spread": 90, "speed": [40, 130], "damping": [90, 140], "gravity": Vector2(0, 35),
		"initial": gradient([Color.WHITE, Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]], "life_random": 0.33})
	var stars := particles("BurstStars", {"at": Vector2(0, -29), "amount": 7, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "emit": {"box": Vector2(26, 23)}, "dir": -90, "spread": 50, "speed": [4, 16], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.3, 0.5], [0.6, 1], [1, 0]], "life_random": 0.5})
	emit_all([cloud, haze, flurry, stars], BURST)
	var settle := particles("DebrisGlints", {"at": Vector2(0, -3), "amount": 2, "lifetime": 0.3, "emitting": false, "texture": "plus3",
		"emit": {"box": Vector2(40, 3)}, "dir": -90, "speed": [3, 3], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.4, 0.4], [0.7, 1], [1, 0]]})
	emit(settle, BURST + 0.1, BURST + 0.9)


func chop(pts: Array, depth: int) -> Array:
	var c := centroid(pts)
	if c.z < 20.0 or depth > 2:
		return [pts]
	var out := []
	for q in split_poly(pts, c.x, c.y, rng.randf_range(0, PI)):
		out += chop(q, depth + 1)
	return out
