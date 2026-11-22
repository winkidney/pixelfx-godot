# reimagined-from: src/fx/status/cursed.js@00358c595ae03f09fca39d379fdd13d17f6f8a1e
# Cursed: Hexed: violet smoke rises off the body in winding trails, a dark stain creeps up from the feet with a glowing edge, the eyes burn, a skull glitches in overhead.
# loop, 2.40 s, 64x84 canvas, origin [32.0, 76.0], backdrop ground, stand-in 2
# ramp palette: #0c0612 #1f0f2e #3a1a55 #5e2a85 #8a3fc0 #b86ef0 #e0b0ff #ffffff
# The stain is a shader on the effect's own Actor (fx/status/_cursed_body.gdshader) fed the original's creeping line
# (its tide and looping noise, worked out here per column per frame). Violet smoke winds up from four spots (soft
# emitters, two behind the body, whose launch direction is keyed with the original's sway so each ribbon winds). The
# skull is the original's shaded icon: clean while it hangs, torn row by row with two colour ghosts and fizzing
# scanlines as it glitches in and out (the tears drawn here from its dice, a strip of frames). The stain pools on the
# floor (a strip of its breathing widths); the eyes burn.
extends "res://build/fx/status/_status.gd"

const SKULL := ["...#####...", ".#########.", "###########", "##eee#eee##", "##eEe#eEe##", "##eee#eee##", "#####.#####",
	".####.####.", "..#######..", "..#.#.#.#..", "...#####..."]
const IN := 0.5
const HOLD := 0.75
const OUT := 1.85
const GONE := 2.1
var D := 2.4


static func tile_noise(x: float, y: float, py: int, seed_: int) -> float:
	var ix := int(floorf(x))
	var iy := int(floorf(y))
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var y0 := posmod(iy, py)
	var y1 := posmod(iy + 1, py)
	var a := jrand([ix, y0, seed_])
	var b := jrand([ix + 1, y0, seed_])
	var c := jrand([ix, y1, seed_])
	var d := jrand([ix + 1, y1, seed_])
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


func tide(t: float) -> float:
	return 0.3 + 0.12 * sin(t / D * TAU)


func reach(x: int, t: float, seed_: int) -> float:
	var n := (tile_noise(x * 0.35, t / D * 4.0, 4, seed_) * 0.5 + tile_noise(x * 0.7, t / D * 8.0, 8, seed_ + 101) * 0.25) / 0.75
	return tide(t) + 0.13 * n


func make() -> void:
	D = root.duration
	var C := fit("palette", 8)
	var S := shape_of()
	var H := AH
	var seed_: int = int(meta.options.seed)
	var times := frame_times()

	# ---- behind: the stain pooling round the feet, its rim glowing
	var fl: int = S.rows[H - 1][0]
	var fr: int = S.rows[H - 1][1]
	var cx := AX + (fl + fr + 1) / 2.0
	var pools := []
	var pool_keys := {}
	var pool_f := []
	var pool_r := []
	for t in times:
		var rx := (fr - fl) / 2.0 + 7.0 + 2.0 * sin(t / D * TAU)
		var d := {}
		var sig := ""
		for x in range(int(floorf(cx - rx - 1)), int(floorf(cx + rx + 1)) + 1):
			var q := absf(x + 0.5 - cx) / rx
			var n := jrand([x, 31])
			if q > 1.0 + n * 0.12:
				continue
			d[Vector2i(x, 0)] = C[4] if q > 0.8 else (C[3] if n < 0.2 else C[2])
			sig += "%d%s" % [x, "a" if q > 0.8 else "b"]
			if q < 0.85:
				d[Vector2i(x, 1)] = C[1]
				sig += "c"
			if q < 0.55 and n < 0.7:
				d[Vector2i(x, 2)] = C[1]
				sig += "d"
		if not pool_keys.has(sig):
			pool_keys[sig] = pools.size()
			pools.append(d)
		pool_f.append([t, pool_keys[sig]])
		pool_r.append([t, rx + 6.0])
	var pool := _dict_strip("Pool", pools, {"back": true})
	key(pool, "frame", pool_f, "nearest")
	var pool_l := glow("PoolLight", 26, {"radius": 22.0, "squash": 0.2, "color": C[4], "alpha": 0.2}, {"at": Vector2(cx, 0.5)})
	key(pool_l, "material:shader_parameter/radius", pool_r)

	# ---- the body, the stain creeping up it
	var body := actor_node()
	var lv := Image.create(AW, times.size(), false, Image.FORMAT_RF)
	for i in times.size():
		for x in AW:
			lv.set_pixel(x, i, Color(reach(x, times[i], seed_), 0, 0))
	var m := ShaderMaterial.new()
	m.shader = load(STATUS + "_cursed_body.gdshader")
	m.set_shader_parameter("levels", asset("_levels", lv))
	m.set_shader_parameter("c1", C[1])
	m.set_shader_parameter("c3", C[3])
	m.set_shader_parameter("c4", C[4])
	m.set_shader_parameter("c6", C[6])
	body.material = m
	var fk := []
	for i in times.size():
		fk.append([times[i], float(i)])
	key(body, "material:shader_parameter/frame", fk, "nearest")
	var line_l := glow("LineLight", 16, {"radius": 13.0, "squash": 0.45, "color": C[5], "alpha": 0.3})
	sample(line_l, "position", func(t: float) -> Vector2: return Vector2(0, AY + H * (1.0 - tide(t))), "linear")

	# the eyes burn
	var ey := {}
	for e in eyes():
		for q in e.px:
			ey[Vector2i(AX + q.x, AY + q.y)] = C[7] if q.y == e.y0 else C[5]
		glow("EyeLight%d" % e.x0, 7, {"radius": 5.0, "color": C[5], "alpha": 0.4}, {"at": apos((e.x0 + e.x1 + 1) / 2.0, (e.y0 + e.y1 + 1) / 2.0)})
	pixels("Eyes", ey)

	# ---- smoke trails winding up off the body
	var spots := [[0.12, -1], [0.1, 1], [0.5, -1], [0.48, 1]]
	for j in 4:
		var my := int(jround(H * spots[j][0]))
		var sd: int = spots[j][1]
		var at := apos(S.rows[my][0] if sd < 0 else S.rows[my][1] + 1, my)
		var front := j % 2 == 0
		var k := 0.5 if front else 0.62
		var p := particles("Smoke%d" % j, {"layer": "soft", "back": not front, "at": at, "amount": 24, "lifetime": 1.6, "texture": "disc9",
			"emit": {"circle": 0.6}, "dir": -90, "speed": [21, 24], "gravity": Vector2(0, -4), "scale": [0.5, 0.95],
			"scale_curve": [[0, 0.3], [0.3, 0.8], [0.6, 1.02], [1, 1.1]],
			"ramp": gradient([C[4], C[3], C[2], C[1]], [0.0, 0.3, 0.55, 0.8]),
			"alpha_curve": [[0, 0.0], [0.12, k * 0.6], [0.45, k * 0.55], [1, 0.0]]})
		var dk := []
		for t in times:
			var v := Vector2(sd * 4.4 + 4.0 * sin(t / D * TAU * 2.0 + j * 1.7), -22.0).normalized()
			dk.append([t, Vector3(v.x, v.y, 0)])
		key(p, "process_material:direction", dk)

	# ---- the skull glitches in, hangs there bobbing, and glitches out
	var base := bitmap(SKULL)
	var mains := []
	var g1 := []
	var g2 := []
	var K := {"v": [], "p": [], "f": [], "gv": [], "ga": [], "gb": [], "la": [], "ea": [], "lp": []}
	var lines := []
	for k in 3:
		lines.append({"n": rect("Scan%d" % k, Rect2(0, 0, 4, 1), C[6] if k % 2 else C[4]), "v": [], "p": [], "s": [], "a": []})
	var none := Color(0, 0, 0, 0)
	for t in times:
		var f := int(roundf(t * 30.0))
		var live: bool = t >= IN and t < GONE
		var glitch := 0.0
		if t < HOLD:
			glitch = 1.0 - (t - IN) / (HOLD - IN)
		elif t > OUT:
			glitch = (t - OUT) / (GONE - OUT)
		var shown := live and (glitch < 0.15 or jrand([f, 3]) > glitch * 0.6)
		var y := AY - 12.0 + sin(t / D * TAU * 2.0) * 1.2
		K.v.append([t, shown])
		K.p.append([t, Vector2(0, jround(y))])
		K.lp.append([t, Vector2(0, y)])
		K.la.append([t, (0.24 + 0.3 * glitch) if shown else 0.0])
		K.ea.append([t, 0.6 if shown else 0.0])
		K.gv.append([t, shown and glitch > 0.0])
		K.ga.append([t, 0.7 * glitch])
		K.gb.append([t, 0.5 * glitch])
		if shown and glitch > 0.0:
			var tear := func(dx: int, dy: int) -> String:
				var row := dy + 6
				var shift := 0
				if jrand([f, row >> 1, 7]) < glitch * 0.8:
					shift = int(jround((jrand([f, row, 9]) - 0.5) * 6.0 * glitch))
				return base.call(dx - shift, dy)
			K.f.append([t, mains.size() + 1])
			mains.append(icon_image(tear, 8, [C[0], C[4], C[6], C[7]], {"e": C[0], "E": C[7]}))
			g1.append(icon_image(tear, 8, [none, C[2], C[2], C[3]]))
			g2.append(icon_image(tear, 8, [none, C[6], C[6], C[6]]))
		else:
			K.f.append([t, 0])
		for k in 3:
			var ln: Dictionary = lines[k]
			var on_ := live and glitch > 0.1
			ln.v.append([t, on_])
			if on_:
				var ly := jround(y) - 5 + floorf(jrand([f, k, 11]) * 11.0)
				var lx := jround((jrand([f, k, 12]) - 0.5) * 10.0)
				var ln_len := 3 + int(floorf(jrand([f, k, 13]) * 8.0))
				ln.p.append([t, Vector2(floorf(lx - ln_len / 2.0), ly)])
				ln.s.append([t, Vector2(ln_len + 1, 1)])
				ln.a.append([t, glitch])
	var clean := icon_image(base, 8, [C[0], C[4], C[6], C[7]], {"e": C[0], "E": C[7]})
	var blank := Image.create(19, 19, false, Image.FORMAT_RGBA8)
	var gh1 := icon_strip("GhostA", [blank] + g1, {"file": "_ghost_a"})
	var gh2 := icon_strip("GhostB", [blank] + g2, {"file": "_ghost_b"})
	var skull := icon_strip("Skull", [clean] + mains, {"file": "_skull"})
	key(skull, "visible", K.v, "nearest")
	key(skull, "position", K.p, "nearest")
	key(skull, "frame", K.f, "nearest")
	var i := 0
	for gh in [gh1, gh2]:
		var off := Vector2(-2, 0) if i == 0 else Vector2(2, 0)
		key(gh, "visible", K.gv, "nearest")
		key(gh, "position", K.p.map(func(k: Array) -> Array: return [k[0], k[1] + off]), "nearest")
		key(gh, "frame", K.f, "nearest")
		key(gh, "modulate:a", K.ga if i == 0 else K.gb, "nearest")
		i += 1
	for ln in lines:
		key(ln.n, "visible", ln.v, "nearest")
		key(ln.n, "position", ln.p, "nearest")
		key(ln.n, "size", ln.s, "nearest")
		key(ln.n, "modulate:a", ln.a, "nearest")
	var sl := glow("SkullLight", 18, {"radius": 16.0, "color": C[4], "alpha": 0.0})
	key(sl, "position", K.lp, "nearest")
	key(sl, "material:shader_parameter/alpha", K.la, "nearest")
	for sx in [-3.0, 3.0]:
		var el := glow("SocketLight%d" % int(sx + 3), 7, {"radius": 5.0, "color": C[5], "alpha": 0.0})
		key(el, "position", K.lp.map(func(k: Array) -> Array: return [k[0], k[1] + Vector2(sx, -1)]), "nearest")
		key(el, "material:shader_parameter/alpha", K.ea, "nearest")

	# ---- violet light on the body
	var tl := glow("TideLight", 26, {"radius": 24.0, "color": C[4], "alpha": 0.2})
	sample(tl, "position", func(t: float) -> Vector2: return Vector2(0, AY + H * (1.0 - tide(t))), "linear")
	glow("BodyLight", 32, {"radius": 30.0, "color": C[3], "alpha": 0.12}, {"at": Vector2(0, AY + H * 0.45)})


func _dict_strip(name: String, dicts: Array, o: Dictionary = {}) -> Sprite2D:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for d in dicts:
		for q in d:
			lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
			hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var sz := hi - lo + Vector2i.ONE
	var img := Image.create(sz.x * dicts.size(), sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in dicts.size():
		for q in dicts[i]:
			img.set_pixel(i * sz.x + q.x - lo.x, q.y - lo.y, dicts[i][q])
	keep_image_colours(img)
	var oo := {"at": Vector2(lo), "centered": false, "hframes": dicts.size()}
	oo.merge(o, true)
	return sprite(name, asset("_" + name.to_lower(), img), oo)
