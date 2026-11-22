# reimagined-from: src/fx/nature/tornado.js@a2efc88293cd3be0a6a45e6b12a53d25d34304c3
# Tornado: A snaking funnel of spinning wind bands under a flared, churning top that flickers with lightning; leaves
# and debris whirl round it front and back, dust boils at its foot.
# The funnel is a shader of its own (fx/nature/_funnel.gdshader) drawn in three passes: behind (the crown's dark
# underside and far bands, the far halves of the wind bands), the body (a translucent column of sheared noise, lit
# from the left, dusty at its foot) and in front (near halves, the crown, scuffs swept round the floor), with the
# original's own seeded bands and noise (build/fx/nature/_lib_wind.gd). Debris (leaves, twigs, pebbles drawn the way
# the original draws them) and the dust boiling at its foot are particles riding the original's spiral round the
# snaking axis (fx/nature/_spiral.gdshader), each kind a pair of emitters behind and in front; grit hops off the
# floor. The crown's lightning is a Line2D bolt rolled from the original's seeds on its beats; light: a pale column,
# a pool at its foot, glints on the band heads, the flash.
# loop, 2.00 s, 196x168 canvas, origin [98, 152], backdrop ground
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const W := preload("res://build/fx/nature/_lib_wind.gd")
const SPIRAL := preload("res://addons/pixelfx_particles/fx/nature/_spiral.gdshader")
const FUNNEL := preload("res://addons/pixelfx_particles/fx/nature/_funnel.gdshader")
const SEED := 4
const FH := 112.0


static func ax(u: float, t: float, D: float) -> float:
	var ph := TAU * t / D
	return 8.5 * sin(ph - 2.6 * u) * (0.2 + 0.8 * u) + 3.0 * sin(2.0 * ph + 1.3 - 4.5 * u) * u


static func rad(u: float) -> float:
	var f := N.smooth(0.78, 1.0, u)
	return 3.0 + 20.0 * pow(u, 1.5) + 17.0 * f * f


static func flash_at(t: float, D: float) -> float:
	var q := t / D
	return maxf(0.0, 1.0 - absf(q - 0.62) / 0.025) + 0.6 * maxf(0.0, 1.0 - absf(q - 0.69) / 0.015)


static func bolt_path(R: W.Rng, a: Vector2, b: Vector2, jag: float, depth: int) -> PackedVector2Array:
	var pts := [a, b]
	for d in depth:
		var nxt := [pts[0]]
		for i in range(1, pts.size()):
			var A: Vector2 = pts[i - 1]
			var B: Vector2 = pts[i]
			var dd := B - A
			var L := dd.length()
			var off := (R.next() * 2.0 - 1.0) * jag * L
			var Ln := L if L > 0.0 else 1.0
			nxt.append((A + B) / 2.0 + Vector2(-dd.y / Ln, dd.x / Ln) * off)
			nxt.append(B)
		pts = nxt
	return PackedVector2Array(pts)


func tex1(cols: Array) -> ImageTexture:
	var img := Image.create(cols.size(), 1, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		img.set_pixel(i, 0, cols[i])
	return ImageTexture.create_from_image(img)


## Two emitters (behind, in front) running the spiral shader with the same numbers: every particle shows on one.
## sides: [-1, 1] for a pair, [0] for one that's always shown.
func whirl(name: String, amount: int, textures: Array, layer: String, params: Dictionary, sides := [-1.0, 1.0]) -> void:
	var D: float = meta.duration
	for i in sides.size():
		var s: float = sides[i]
		var p := particles(name + ("Back" if s < 0 else "Front" if s > 0 else ""), {"amount": amount, "lifetime": D,
			"texture": textures[i], "local": true, "back": s < 0, "layer": layer})
		var m := ShaderMaterial.new()
		m.shader = SPIRAL
		m.set_shader_parameter("side", s)
		for k in params:
			var v: Variant = params[k]
			m.set_shader_parameter(k, float(v) if v is int and k != "mode" else v)
		p.process_material = m
		key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, 1.0]])


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var Dst: PackedColorArray = root.ramps.dust
	var L: PackedColorArray = root.ramps.leaves
	var D: float = meta.duration
	keep_colour(Color.WHITE)

	# the original's seeded shapes
	var ba := PackedVector4Array()
	var bb := PackedVector4Array()
	for j in 58:
		var R := W.rng([SEED * 3 + 5, j])
		var u := (j + R.range(0.1, 0.9)) / 58.0
		var K := R.int_(2, 4)
		var span := R.range(0.7, 2.1)
		var lvl := R.next()
		var rf := R.range(1.0, 1.1)
		var head := R.range(0, TAU)
		ba.append(Vector4(u, rf, head, span))
		bb.append(Vector4(K, lvl, 0, 0))
	var ca := PackedVector4Array()
	var cb := PackedVector4Array()
	for j in 16:
		var R := W.rng([SEED * 7 + 2, j])
		var rf := R.range(0.4, 1.15)
		var K := R.int_(1, 2)
		var span := R.range(1.4, 2.8)
		var head := R.range(0, TAU)
		var th0 := R.range(3.2, 6)
		var lift := R.range(-4, 3) - (1.0 - rf / 1.15) * 5.0
		ca.append(Vector4(rf, head, span, th0))
		cb.append(Vector4(K, lift, 0, 0))
	var sc := PackedVector4Array()
	for j in 7:
		var R := W.rng([SEED * 5 + 1 + 3, j])
		var rr := R.range(12, 28)
		var th0 := R.range(0, TAU)
		var span := R.range(0.5, 1.1)
		sc.append(Vector4(rr, th0, span, 0))
	var nz := Image.create(6, 41, false, Image.FORMAT_RGBA8)
	for iy in range(-39, 2):
		for x in 6:
			var v := W.rand([x, iy, SEED])
			nz.set_pixel(x, iy + 39, Color(v, v, v, 1))
	var rows := Image.create(1, 112, false, Image.FORMAT_RGBA8)
	for y in range(-111, 1):
		rows.set_pixel(0, y + 111, Color.WHITE if W.rand([y, SEED]) < 0.35 else Color.BLACK)
	var common := {"t": 0.0, "flash": 0.0, "band_a": ba, "band_b": bb, "crown_a": ca, "crown_b": cb, "scuff": sc,
		"pal": tex1(Array(C)), "dust": tex1(Array(Dst)), "noise": ImageTexture.create_from_image(nz),
		"rows": ImageTexture.create_from_image(rows), "translucent": true}
	var fl := []
	for i in int(D * 60.0) + 1:
		var t := i / 60.0
		fl.append([t, flash_at(t, D)])
	var passes := {}
	for ps in [["FunnelBack", 0.0], ["Body", 1.0], ["FunnelFront", 2.0]]:
		var pr := common.duplicate()
		pr.pass = ps[1]
		passes[ps[1]] = pr
	var size := Vector2(140, 146)
	var at := Vector2(0, -61)

	# behind: dust and the far side of the crown and bands, debris going round the back, then the body over them
	whirl("Dust", 40, [N.disc(4.5, Dst[1]), N.disc(4.5, Dst[2])], "soft", {"mode": 3, "seed": 5.0, "life_min": 0.7,
		"life_max": 1.3, "tex_size": Vector2(4.5, 4.5)})
	whirl("DustLit", 40, [N.disc(4.5, Dst[2]), N.disc(4.5, Dst[3])], "soft", {"mode": 3, "seed": 5.0, "life_min": 0.7,
		"life_max": 1.3, "tex_size": Vector2(4.5, 4.5), "sub": Vector4(-0.2, -0.5, 0.55, 0.8)})
	var back := shape("FunnelBack", FUNNEL, size, passes[0.0], {"at": at, "back": true})
	var deb := [
		["LeafAmber", 8, [N.leaf(7.5, 2.2, 0.0, [L[0], L[1], L[1], L[2]]), N.leaf(7.5, 2.2, 0.0, [L[0], L[1], L[2], L[3]])],
			{"len_range": Vector2(6, 9), "wid_range": Vector2(1.8, 2.6), "tex_size": Vector2(7.5, 2.2)}],
		["LeafGreen", 7, [N.leaf(7.5, 2.2, 0.0, [L[4], L[5], L[5], L[6]]), N.leaf(7.5, 2.2, 0.0, [L[4], L[5], L[6], L[7]])],
			{"len_range": Vector2(6, 9), "wid_range": Vector2(1.8, 2.6), "tex_size": Vector2(7.5, 2.2)}],
		["Twig", 4, [_twig(L[0], L[2]), _twig(L[1], L[2])], {"len_range": Vector2(6, 6), "tex_size": Vector2(6, 1), "flip": 0.0}],
		["Pebble", 5, [N.rock(3, 2.1, C), N.rock(3, 2.1, C)], {"len_range": Vector2(1.6, 2.6), "tex_size": Vector2(2.1, 2.1), "flip": 0.0}],
	]
	var i := 0
	for d in deb:
		var pr := {"mode": 2, "seed": 20.0 + i * 13.0, "life_min": 1.3, "life_max": 1.95}
		pr.merge(d[3], true)
		whirl(d[0], d[1], d[2], "color", pr)
		i += 1
	var body := shape("Body", FUNNEL, size, passes[1.0], {"at": at, "back": true})
	var front := shape("FunnelFront", FUNNEL, size, passes[2.0], {"at": at})
	for n in [back, body, front]:
		loop_t(n)
		key(n, "material:shader_parameter/flash", fl)
	# the debris and dust in front go over the funnel: move their front emitters after it
	for n in root.get_children():
		if n is GPUParticles2D and not n.name.ends_with("Back"):
			root.move_child(n, -1)
	# grit hopping off the floor round its foot
	whirl("Grit", 8, [_dot(Dst[3])], "color", {"mode": 4, "seed": 41.0, "life_min": 0.35, "life_max": 0.6}, [0.0])
	whirl("Grit2", 8, [_dot(Dst[4])], "color", {"mode": 4, "seed": 43.0, "life_min": 0.35, "life_max": 0.6}, [0.0])

	# light: a pale column, a pool at its foot, glints on the band heads, the crown's flash and its bolt
	var column := line("Column", PackedVector2Array([Vector2(0, -11), Vector2(0, -100)]), {"width": 52, "color": Color(C[5], 0.08), "layer": "light"})
	var foot := glow("FootLight", 32, {"radius": 30, "color": Dst[3], "alpha": 0.12}, {"at": Vector2(0, -2)})
	var heads := shape("HeadLight", load("res://addons/pixelfx_particles/fx/nature/_funnel_glow.gdshader"), size,
		{"t": 0.0, "band_a": ba, "band_b": bb, "color": C[6], "alpha": 0.3}, {"at": at})
	loop_t(heads)
	var flash := glow("Flash", 72, {"radius": 70, "color": C[7], "alpha": 0.0}, {"at": Vector2(0, -FH - 2)})
	var bolt := line("Bolt", PackedVector2Array([Vector2.ZERO, Vector2.ONE]), {"color": Color.WHITE})
	var cpts := []
	var fpos := []
	var fpts := []
	var falpha := []
	var bpts := []
	var bcol := []
	var bvis := []
	var balpha := []
	for k in int(D * 30.0) + 1:
		var t := k / 30.0
		var cx := ax(1.0, t, D)
		cpts.append([t, PackedVector2Array([Vector2(ax(0.1, t, D), -FH * 0.1), Vector2(cx, -FH * 0.9)])])
		fpos.append([t, Vector2(ax(0.0, t, D), -2)])
		fpts.append([t, Vector2(cx, -FH - 2)])
		var f := flash_at(t, D)
		falpha.append([t, 0.45 * f])
		var on := f > 0.05 and t < D
		bvis.append([t, on])
		if on:
			var R := W.rng([SEED, 99, int(floor(t / D * 7.0))])
			bpts.append([t, bolt_path(R, Vector2(cx - 18, -FH - 6), Vector2(cx + 16, -FH + 2), 0.3, 3)])
			bcol.append([t, Color.WHITE if f > 0.6 else C[7]])
			balpha.append([t, minf(1.0, f * 1.5)])
	key(column, "points", cpts)
	key(foot, "position", fpos)
	key(flash, "position", fpts)
	key(flash, "material:shader_parameter/alpha", falpha)
	key(bolt, "visible", bvis, "nearest")
	key(bolt, "points", bpts, "nearest")
	key(bolt, "default_color", bcol, "nearest")
	key(bolt, "modulate:a", balpha, "nearest")
	bolt.visible = false


func _twig(c: Color, tip: Color) -> ImageTexture:
	var img := Image.create(6, 1, false, Image.FORMAT_RGBA8)
	for x in 6:
		img.set_pixel(x, 0, tip if x == 5 else c)
	return ImageTexture.create_from_image(img)


func _dot(c: Color) -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, c)
	return ImageTexture.create_from_image(img)
