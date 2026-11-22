# reimagined-from: src/fx/ice/ice-crystal.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Ice crystal: a floating ice crystal turning slowly in its own cold light: its facets brighten and darken as they
# turn, glints flash on them, frost motes circle it.
# The crystal is a solid body: a hexagonal bipyramid turned a sixth of a turn a loop (so it never seams), each face a
# Polygon2D whose corners and shade are keyed every frame from the original's projection and lighting, a dark hull
# behind them and Line2D edges over them. Glints are sparkle shaders keyed where a face mirrors the light. The motes
# are emitters orbiting in flattened rings, the far half dim and behind, the near half bright with its own glow; the
# shadow and the light pool on the floor breathe with the bob.
extends "res://build/fx/ice/_ice.gd"

const TIP := 0.28
const R := 8.0
const HEIGHT := 34.0
var SUN := Vector3(-0.55, -0.75, -0.45).normalized()


func bob(t: float) -> float:
	return sin(TAU * t / root.duration) * 2.5


## The original's crystalFaces(): every face (18 of them) as {pts, lit, spec, cx, cy, on}.
func faces(th: float) -> Array:
	var ct := cos(TIP)
	var st := sin(TIP)
	var P := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y * ct - z * st, y * st + z * ct)
	var top := []
	var bot := []
	for k in 6:
		var a := th + k * TAU / 6.0
		top.append(P.call(cos(a) * R, -R * 0.45, sin(a) * R))
		bot.append(P.call(cos(a) * R, R * 0.45, sin(a) * R))
	var A: Vector3 = P.call(0.0, -R * 2.2, 0.0)
	var Z: Vector3 = P.call(0.0, R * 1.7, 0.0)
	var fs := []
	for k in 6:
		var j := (k + 1) % 6
		fs.append([A, top[j], top[k]])
		fs.append([top[k], top[j], bot[j], bot[k]])
		fs.append([bot[k], bot[j], Z])
	var h := (SUN + Vector3(0, 0, -1)).normalized()
	var out := []
	for f in fs:
		var a: Vector3 = f[0]
		var u: Vector3 = f[1] - a
		var v: Vector3 = f[2] - a
		var n := u.cross(v).normalized()
		var c := Vector3.ZERO
		for q in f:
			c += q
		c /= f.size()
		if n.dot(c) < 0.0:
			n = -n
		var pts := PackedVector2Array()
		for q in f:
			pts.append(Vector2(q.x, q.y))
		out.append({"pts": pts, "lit": maxf(0.0, n.dot(SUN)), "spec": maxf(0.0, n.dot(h)), "cx": c.x, "cy": c.y, "on": n.z < -0.02})
	return out


static func hull(pts: Array) -> Array:
	var P := pts.duplicate()
	P.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var cross := func(o: Vector2, a: Vector2, b: Vector2) -> float: return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
	var lo := []
	for q in P:
		while lo.size() >= 2 and cross.call(lo[-2], lo[-1], q) <= 0:
			lo.pop_back()
		lo.append(q)
	var hi := []
	P.reverse()
	for q in P:
		while hi.size() >= 2 and cross.call(hi[-2], hi[-1], q) <= 0:
			hi.pop_back()
		hi.append(q)
	return lo.slice(0, -1) + hi.slice(0, -1)


func make() -> void:
	var D: float = root.duration
	# the floor: a shadow that shrinks as it lifts, a cold pool of light
	var shadow := ring("Shadow", 13, {"radius": 11, "squash": 0.09, "color": C[0], "alpha": 0.65, "translucent": true}, {"at": Vector2(0, 1), "back": true})
	key(shadow, "material:shader_parameter/radius", sample(func(t): return 11.0 * (1.0 - bob(t) / 12.0)))
	var pool := glow("Pool", 26, {"radius": 24, "color": C[4], "alpha": 0.2}, {"at": Vector2(0, -1)})
	key(pool, "material:shader_parameter/alpha", sample(func(t): return 0.2 + 0.05 * sin(TAU * t / D * 2.0)))

	# its own cold light, riding the bob
	var cold := glow("Cold", 36, {"radius": 34, "color": C[3], "alpha": 0.26}, {"at": Vector2(0, -HEIGHT)})
	var heart := glow("Heart", 16, {"radius": 14, "color": C[5], "alpha": 0.18}, {"at": Vector2(0, -HEIGHT)})
	key(cold, "position", sample(func(t): return Vector2(0, -HEIGHT + bob(t))))
	key(heart, "position", sample(func(t): return Vector2(0, -HEIGHT + bob(t))))
	key(heart, "material:shader_parameter/alpha", sample(func(t): return 0.18 + 0.08 * sin(TAU * t / D * 3.0)))

	motes(false)

	# the crystal: a dark hull, 18 faces (the ones facing us shown), their edges
	var body := group("Crystal")
	var rim := poly("Rim", PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(1, 0)]), {"color": C[1], "parent": body})
	var polys := []
	var lines := []
	for i in 18:
		polys.append(poly("Face%d" % i, PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(1, 0)]), {"color": C[4], "parent": body}))
	for i in 18:
		var l := line("Edge%d" % i, PackedVector2Array([Vector2.ZERO, Vector2.ONE]), {"width": 1.0, "color": C[6], "parent": body})
		lines.append(l)
	for c in C:
		keep_colour(c)
	var glints := [sparkle("GlintA"), sparkle("GlintB"), sparkle("TipGlint")]
	var gk := [[], [], []]
	var k_rim := []
	var k_pos := []
	var k_poly := []
	var k_col := []
	var k_vis := []
	var k_line := []
	var k_lcol := []
	for i in 18:
		k_poly.append([])
		k_col.append([])
		k_vis.append([])
		k_line.append([])
		k_lcol.append([])
	var n := int(roundf(D * FPS))
	for fi in n + 1:
		var t := fi / FPS
		var ph := t / D
		var Y := -HEIGHT + bob(t)
		var fs := faces(TAU / 6.0 * ph)
		var all := []
		for f in fs:
			if f.on:
				all += Array(f.pts)
		var hl := hull(all)
		var m := Vector2.ZERO
		for q in hl:
			m += q
		m /= hl.size()
		var hp := PackedVector2Array()
		for q in hl:
			var d: Vector2 = q - m
			hp.append(q + d / maxf(0.001, d.length()) * 1.2)
		k_rim.append([t, hp])
		k_pos.append([t, Vector2(0, Y)])
		var lit_faces := []
		for i in 18:
			var f: Dictionary = fs[i]
			k_vis[i].append([t, f.on])
			k_poly[i].append([t, f.pts])
			var col: Color = Color.WHITE if f.spec > 0.985 else C[clampi(int(roundf(1.0 + pow(f.lit, 1.4) * 6.6)), 1, 7)]
			k_col[i].append([t, col])
			var lp := PackedVector2Array()
			for q in f.pts:
				lp.append(cell(q + Vector2(0, Y)) - Vector2(0, Y))
			lp.append(lp[0])
			k_line[i].append([t, lp])
			k_lcol[i].append([t, C[7] if f.lit > 0.6 else (C[6] if f.lit > 0.3 else C[4])])
			if f.on and f.spec > 0.96:
				lit_faces.append(f)
		lit_faces.sort_custom(func(a, b): return a.spec > b.spec)
		for j in 2:
			if j < lit_faces.size():
				var f: Dictionary = lit_faces[j]
				gk[j].append([t, Vector2(f.cx, f.cy + Y), 2.0 + (f.spec - 0.96) * 150.0, 0.5])
			else:
				gk[j].append([t, Vector2(0, Y), 0.0, 0.0])
		var g := fmod(ph * 2.0, 1.0)
		var tip := Vector2(0, Y - R * 2.2 * cos(TIP))
		gk[2].append([t, tip, 5.0 * sin(g / 0.12 * PI) if g < 0.12 else 0.0, 0.6])
	key(body, "position", k_pos, "nearest")
	key(rim, "polygon", k_rim, "nearest")
	for i in 18:
		key(polys[i], "visible", k_vis[i], "nearest")
		key(polys[i], "polygon", k_poly[i], "nearest")
		key(polys[i], "color", k_col[i], "nearest")
		key(lines[i], "visible", k_vis[i], "nearest")
		key(lines[i], "points", k_line[i], "nearest")
		key(lines[i], "default_color", k_lcol[i], "nearest")
	for j in 3:
		sparkle_keys(glints[j], gk[j])

	motes(true)


## Motes circling the crystal: rings flattened to 0.3, a near half (bright, in front, glowing) and a far half (dim,
## behind). Each mote is born on one side and lives exactly half a turn, so it stays in its own half. They turn as the
## original's do: right to left across the front (a negative orbit: Godot's positive one turns +x up).
func motes(front: bool) -> void:
	var levels := [-12.0, -4.0, 4.0, 10.0]
	var speeds := [1.7, 2.5, 2.0, 2.3] if front else [2.4, 1.8, 2.2, 1.6]
	var i := 0
	for dy in levels:
		var w: float = speeds[i] / TAU      # turns a second
		var half := 0.5 / w
		var g := group("Motes%s%d" % ["Front" if front else "Back", i], {"at": Vector2(0, -HEIGHT + dy), "back": not front})
		g.scale = Vector2(1, 0.3)
		key(g, "position", sample(func(t): return Vector2(0, -HEIGHT + dy + bob(t) - 2.0)))
		var star: bool = front and i == 1
		var o := {"parent": g, "local": true, "amount": 1 + (i + int(front)) % 2, "lifetime": half, "randomness": 0.0, "texture": "plus3" if star else "dot1",
			"back": not front, "emit": {"box": Vector2(4, 0.5)}, "orbit": [-w, -w], "preprocess": half,
			"alpha_curve": [[0, 0], [0.12, 1], [0.8, 1], [1, 0]]}
		var p := particles("Mote%s%d" % ["F" if front else "B", i], o)
		p.position = Vector2.ZERO
		var m: ParticleProcessMaterial = p.process_material
		m.lifetime_randomness = 0.35
		m.emission_shape_offset = Vector3(18 if front else -18, 0, 0)
		stretch(p, 1.0, 1.0 / 0.3)
		if star:
			m.color = C[5]
			var heart := lit_copy(p, "MoteHeart%d" % i, "dot1", Color.WHITE)
			heart.material = dither
			heart.z_index = 1
			stretch(heart, 1.0, 1.0 / 0.3)
		elif front:
			m.color = C[6]
		else:
			m.color = C[4]
		if front:
			var lit := lit_copy(p, "MoteGlow%d" % i, "glow8", Color(C[5], 0.16))
			stretch(lit, 1.0, 1.0 / 0.3)
		i += 1
