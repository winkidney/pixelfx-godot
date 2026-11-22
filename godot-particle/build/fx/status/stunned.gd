# reimagined-from: src/fx/status/stunned.js@a780fbc3549a49fa8d20d01e5eb8c27c3d6e4f09
# Stunned: Seeing stars: three spinning stars and two little birds circle the head on a tilted ring, ducking behind it and sweeping round in front, trailing glitter.
# loop, 2.00 s, 60x64 canvas, origin [30.0, 56.0], backdrop ground, stand-in 2
# ramp birds: #1a1422 #6a7fae #b8c8e8 #f4f8ff
# ramp palette: #3a1e0c #8a4a12 #d88a1c #f5c030 #ffe36e #fff6c8 #ffffff
# Five things ride a tilted ring round the head (the original's formula, keyed every frame): three stars, shaded and
# outlined, spinning (a strip of their frames drawn here from the original's star shape), and two birds flapping
# (two wing frames, facing the way they fly). Each has a sprite behind the stand-in (dimmed, for the far half of the
# ring) and one in front. Their glitter is GPU particles placed on the ring by a process shader
# (fx/status/_stunned_glitter.gdshader) from the loop's time; a flare (fx/status/_stunned_flare.gdshader) as each star
# sweeps past the front; twinkles pop round the ring on the original's schedule; warm light under each star.
extends "res://build/fx/status/_status.gd"

const D := 2.0
const TURNS := 2.0
const N := 5
const STAR7 := ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#."]

var C: PackedColorArray
var Bd: PackedColorArray
var beak: Color


func ring_at(t: float) -> Array:
	var cy := AY + 2.0
	var rx := AW * 0.62
	var ry := 4.5
	var out := []
	for i in N:
		var th := TAU * ((TURNS * t) / D + i / float(N))
		var s := sin(th)
		out.append({"i": i, "th": th, "x": cos(th) * rx, "y": cy + s * ry, "near": s >= 0.0, "depth": 0.5 + 0.5 * s,
			"bird": i % 2 == 1, "rx": rx, "ry": ry, "cy": cy})
	return out


func bird(up: bool) -> Callable:
	var wing := [[-1, -1], [-1, -2], [-2, -2], [-2, -3], [-3, -3], [-3, -4]] if up else [[-1, 1], [-1, 2], [-2, 2], [-2, 3], [0, 1]]
	return func(dx: int, dy: int) -> String:
		var x := dx + 0.5
		var y := dy + 0.5
		if dx == 3 and dy == -2:
			return "e"
		if (dx == 5 or dx == 4) and dy == -1:
			return "b" if dx == 5 else "#"
		for w in wing:
			if w[0] == dx and w[1] == dy:
				return "w"
		if (x / 3.3) ** 2 + ((y - 0.6) / 1.9) ** 2 <= 1.0 or (x - 2.8) ** 2 + (y + 1.2) ** 2 <= 1.7 ** 2:
			return "#"
		if (dx == -4 and (dy == -1 or dy == 0)) or (dx == -5 and dy == -1):
			return "#"
		return ""


func dim(c: Color, far: bool) -> Color:
	return c.lerp(Bd[0], 0.3) if far else c


## A local process-shader emitter (as ice's formula()): every particle placed by the shader from its index and the
## keyed loop time t; emitted once, lives as long as the scene.
func formula(name: String, shader: String, params: Dictionary, o: Dictionary = {}) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = name
	_place(p, o, o.get("parent"))
	p.amount = o.get("amount", 16)
	p.lifetime = 600.0
	p.explosiveness = 1.0
	p.preprocess = 0.05
	p.local_coords = true
	p.fixed_fps = 60
	p.interpolate = false
	p.use_fixed_seed = true
	_count += 1
	p.seed = absi(hash(id + "/" + name)) % 1000003 + _count
	p.texture = texture(o.get("texture", "dot1"))
	p.visibility_rect = Rect2(-1024, -1024, 2048, 2048)
	var m := ShaderMaterial.new()
	m.shader = load(STATUS + shader)
	for k in params:
		var v: Variant = params[k]
		m.set_shader_parameter(k, float(v) if v is int and k != "mode" else v)
	p.process_material = m
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	return p


func make() -> void:
	C = fit("palette", 7)
	Bd = fit("birds", 4)
	beak = Color(meta.options.beak)
	var times := frame_times()

	# every frame's ring: which image each item shows, where, and on which side
	var imgs := []
	var index := {}
	var per := []   # per frame: [{layer, frame, pos}, ...] by item
	var add := func(img: Image) -> int:
		var k := img.get_data()
		if not index.has(k):
			index[k] = imgs.size()
			imgs.append(img)
		return index[k]
	for t in times:
		var row := []
		for it in ring_at(t):
			var far: bool = not it.near
			var fi: int
			var pos: Vector2
			if it.bird:
				var up: bool = int(floorf(t * 8.0 + it.i * 0.5)) % 2 == 0
				var bob := sin((t / D) * TAU * 4.0 + it.i) * 0.7
				var f := bird(up)
				var ins := f
				if it.near:
					ins = func(dx: int, dy: int) -> String: return f.call(-dx, dy)
				var R := [Bd[0], dim(Bd[1], far), dim(Bd[2], far), dim(Bd[3], far)]
				fi = add.call(icon_image(ins, 7, R, {"e": Bd[0], "b": dim(beak, far), "w": dim(Bd[1], far)}))
				pos = Vector2(jround(it.x), jround(it.y - 3.0 + bob))
			else:
				var spin: float = (t / D) * TAU * 3.0 + it.i
				var R := [C[0], dim(C[3], far), dim(C[4], far), dim(C[5], far)]
				var img: Image
				if it.depth > 0.55:
					img = icon_image(shaped(star_shape(0.44), 4.0 + 0.8 * it.depth, spin), 7, R)
				else:
					img = icon_image(bitmap(STAR7), 5, R)
				var c := (img.get_width() - 1) / 2
				img.set_pixel(c, c, C[5] if far else C[6])
				fi = add.call(img)
				pos = Vector2(jround(it.x), jround(it.y - 1.0))
			row.append({"far": far, "frame": fi, "pos": pos, "it": it})
		per.append(row)

	# the strip of every star and bird frame, shared by all the sprites
	var NS := 1
	for im in imgs:
		NS = maxi(NS, (im as Image).get_width())
	var strip := Image.create(NS * imgs.size(), NS, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for i in imgs.size():
		var im: Image = imgs[i]
		var d := (NS - im.get_width()) / 2
		strip.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(i * NS + d, d))
	keep_image_colours(strip)
	var tex := asset("ring_frames", strip)

	var ring := ring_at(0.0)
	var common := {"period": D, "turns": TURNS, "items": float(N), "rx": ring[0].rx, "ry": ring[0].ry, "cy": ring[0].cy}

	# behind: the far half's glitter, then the far stars and birds
	var gb := common.duplicate()
	gb.merge({"side": -1.0, "mode": 0, "c4": dim(C[4], true), "c5": dim(C[5], true), "c6": dim(C[6], true)})
	for k in ["c4", "c5", "c6"]:
		keep_colour(gb[k])
	formula("GlitterBack", "_stunned_glitter.gdshader", gb, {"amount": 36, "back": true})
	var sprites := []
	for side in ["Back", "Front"]:
		if side == "Front":
			var gf := common.duplicate()
			gf.merge({"side": 1.0, "mode": 0, "c4": C[4], "c5": C[5], "c6": C[6]})
			formula("GlitterFront", "_stunned_glitter.gdshader", gf, {"amount": 36})
		var row := []
		for i in N:
			var s := sprite(("Bird%d" if i % 2 else "Star%d") % i + side, tex, {"back": side == "Back", "centered": false, "hframes": imgs.size()})
			s.offset = -Vector2((NS - 1) / 2, (NS - 1) / 2)
			row.append(s)
		sprites.append(row)
	# the glitter's light
	var gl := common.duplicate()
	gl.merge({"side": 1.0, "mode": 1, "lightc": C[4]})
	formula("GlitterLight", "_stunned_glitter.gdshader", gl, {"amount": 36, "layer": "light"})
	var gl2 := common.duplicate()
	gl2.merge({"side": -1.0, "mode": 1, "lightc": C[4]})
	formula("GlitterLightBack", "_stunned_glitter.gdshader", gl2, {"amount": 36, "layer": "light"})

	for i in N:
		for li in 2:
			var s: Sprite2D = sprites[li][i]
			var vis := []
			var fr := []
			var ps := []
			for f in times.size():
				var e: Dictionary = per[f][i]
				var here: bool = e.far == (li == 0)
				vis.append([times[f], here])
				if here:
					fr.append([times[f], e.frame])
					ps.append([times[f], e.pos])
			key(s, "visible", vis, "nearest")
			key(s, "frame", fr, "nearest")
			key(s, "position", ps, "nearest")

	# the stars' light, and a flare as each sweeps past the front
	for i in [0, 2, 4]:
		var big := glow("StarGlow%d" % i, 13, {"radius": 11, "color": C[4], "alpha": 0.0})
		var hot := glow("StarHeart%d" % i, 6, {"radius": 4, "color": C[6], "alpha": 0.0})
		var fl := shape("Flare%d" % i, load(STATUS + "_stunned_flare.gdshader"), Vector2(23, 23),
			{"len": 0.0, "k": 1.0, "c6": C[5], "c5": C[4]})
		var kp := []
		var ka := []
		var kh := []
		var fp := []
		var flen := []
		var fk := []
		for f in times.size():
			var it: Dictionary = per[f][i].it
			var at := Vector2(it.x, it.y - 1.0)
			kp.append([times[f], at])
			ka.append([times[f], 0.24 + 0.3 * it.depth])
			kh.append([times[f], 0.3 * it.depth])
			var th: float = it.th - PI / 2.0
			var fr := exp(-pow(atan2(sin(th), cos(th)) / 0.32, 2.0))
			var on: bool = it.near and fr > 0.08
			fp.append([times[f], at.floor() + Vector2(0.5, 0.5)])
			flen.append([times[f], 9.0 * fr if on else 0.0])
			fk.append([times[f], fr])
		key(big, "position", kp, "nearest")
		key(big, "material:shader_parameter/alpha", ka, "nearest")
		key(hot, "position", kp, "nearest")
		key(hot, "material:shader_parameter/alpha", kh, "nearest")
		key(fl, "position", fp, "nearest")
		key(fl, "material:shader_parameter/len", flen, "nearest")
		key(fl, "material:shader_parameter/k", fk, "nearest")

	# twinkles popping round the ring, on the original's schedule
	var tw := []
	for i in 14:
		var sp := sparkle("Twinkle%d" % i, {"color": C[5], "tip": C[4], "size": 9, "reach": 12})
		var dot := pixels("TwinkleDot%d" % i, {Vector2i(0, 0): C[6]})
		dot.visible = false
		tw.append([sp, dot, [], [], [], []])
	for t in times:
		var seen := {}
		cycle(t, D, 14, int(meta.options.seed) + 3, func(r: Rng) -> float: return r.range(0.25, 0.5),
			func(age: float, life: float, r: Rng, i: int) -> void:
				var th := r.range(0, TAU)
				var u := age / life
				var x := cos(th) * AW * r.range(0.45, 0.95)
				var y := AY + 1 + sin(th) * 7 - r.range(0, 9)
				var arm := jround(r.range(1, 2.6) * sin(PI * u))
				seen[i] = true
				tw[i][2].append([t, Vector2(x, y), arm, 0.35 * sin(PI * u)])
				tw[i][3].append([t, arm < 1])
				tw[i][4].append([t, Vector2(x, y).floor()])
				tw[i][5].append([t, minf(1.0, sin(PI * u) * 1.4)]))
		for i in 14:
			if not seen.has(i):
				tw[i][2].append([t, Vector2(0, 0), 0, 0.0])
				tw[i][3].append([t, false])
	for e in tw:
		sparkle_keys(e[0], e[2])
		key(e[1], "visible", e[3], "nearest")
		if e[4].size():
			key(e[1], "position", e[4], "nearest")
			key(e[1], "modulate:a", e[5], "nearest")
	glow("HeadLight", 28, {"radius": 26, "color": C[4], "alpha": 0.13}, {"at": Vector2(0, AY + 1)})
