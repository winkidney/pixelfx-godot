# reimagined-from: src/fx/spawn/shatter-death.js@60097322821f0d07804f2e0a9d2a2f26d7e72a04
# Shatter death: Frost races up the body and seals it in faceted ice, a glint sweeps it, cracks spread from the chest, then it bursts into its own facets that tumble, bounce and melt.
# one-shot, 3.30 s, 172x96 canvas, origin [84.0, 84.0], backdrop ground, stand-in 2
# ramp palette: #0e1636 #1a2f66 #2557a3 #3488d6 #5fc0f0 #a2e6ff #dcf8ff #ffffff
# The original's own update() runs here with its seeded draws: the ice grown round the stand-in's own pixels and cut
# into facets round random seeds, its rime spikes, the cracks walked from the chest, the pieces it bursts into. The ice
# is drawn as the original draws it (fx/spawn/_ice_body.gdshader: climbing from the feet, locking white, a glint
# sweeping it, its outline, spikes (the original's crystal()), cracks, the shudder, the burst). Every facet then flies
# as a tracked GPU particle carrying its own pixels (_ice_piece: tumbling, bouncing, melting away), with the shards
# (_shards: the original's Bits), the vapour, stars and dust (_parts) and the frost and rime on the floor
# (_frost_floor). Lights tracked (_lamps), glows keyed on its formulas.
extends "res://build/fx/spawn/_spawn.gd"

const LOCK := 0.5
const CRACK := 1.05
const BURST := 1.4


static func jround(x: float) -> int:
	return floori(x + 0.5)


func make() -> void:
	var Wc := Color.WHITE
	R = JsRng.new(int(meta.options.seed))
	var body := body_of(C)
	var W: int = body.w + 2
	var H: int = body.h + 1
	var X0: int = body.x - 1
	var Y0: int = body.y - 1
	var cells: Dictionary = body.cells
	var in_body := func(mx: int, my: int) -> bool: return cells.has(Vector2i(mx, my))
	var ice := PackedInt32Array()
	ice.resize(W * H)
	ice.fill(-1)
	var col := []
	col.resize(W * H)
	var glass := PackedInt32Array()
	glass.resize(W * H)
	var solid := PackedByteArray()
	solid.resize(W * H)
	for y in H:
		for x in W:
			var mx := x - 1
			var my := y - 1
			if in_body.call(mx, my) or (my < body.h - 1 and (in_body.call(mx - 1, my) or in_body.call(mx + 1, my) or in_body.call(mx, my - 1) or in_body.call(mx, my + 1))):
				ice[y * W + x] = 0
	var seeds := []
	for i in 22:
		var x := 0.0
		var y := 0.0
		var tries := 0
		while true:
			x = R.range(0, W)
			y = R.range(0, H)
			tries += 1
			if not (ice[floori(y) * W + floori(x)] < 0 and tries < 40):
				break
		seeds.append(Vector2(x, y))
	var at := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < W and y < H and ice[y * W + x] >= 0
	for y in H:
		for x in W:
			var i := y * W + x
			if ice[i] < 0:
				continue
			var d1 := 1e9
			var d2 := 1e9
			var k := 0
			for j in seeds.size():
				var d := Vector2(x + 0.5 - seeds[j].x, (y + 0.5 - seeds[j].y) * 0.85).length()
				if d < d1:
					d2 = d1
					d1 = d
					k = j
				elif d < d2:
					d2 = d
			ice[i] = k
			var s: Vector2 = seeds[k]
			var lit := clamp01(0.55 + 0.35 * (rand([k, 41]) - 0.5) - 0.5 * ((s.x - W / 2.0) / W) - 0.55 * ((s.y - H / 2.0) / H))
			var own: Variant = cells[Vector2i(x - 1, y - 1)].c if cells.has(Vector2i(x - 1, y - 1)) else null
			col[i] = mixc(own, C[4], 0.36) if own != null else C[3]
			glass[i] = mini(2, floori(lit * 3))
			var sc: Variant = null
			if d2 - d1 < 0.42 and own == null:
				sc = C[6] if lit > 0.5 else C[5]
			elif d2 - d1 < 0.42:
				col[i] = mixc(col[i], C[6], 0.45)
			if not at.call(x - 1, y) or not at.call(x, y - 1):
				sc = C[6]
			if not at.call(x + 1, y) or (not at.call(x, y + 1) and y < H - 1):
				sc = C[3]
			if sc != null:
				col[i] = sc
				solid[i] = 1
	# rime spikes where the ice pushes out: on the shoulders, the head and the feet
	var spikes := []
	for i in 7:
		var x: int = R.int_(1, W - 2)
		var y0: int = R.int_(2, H - 3)
		var y := y0
		while y > 0 and at.call(x, y - 1):
			y -= 1
		if at.call(x, y):
			var h := R.range(3, 6)
			var w := R.range(2.5, 3.5)
			var lean := R.range(-2.5, 2.5)
			var t0 := LOCK + R.range(-0.02, 0.08)
			spikes.append([Vector4(X0 + x + 0.5, Y0 + y + 1, h, w), Vector4(lean, t0, 0, 0)])
	for sd in [-1.0, 1.0]:
		for i in 2:
			var h := R.range(5, 7) if i else R.range(8, 11)
			var x: float = sd * (R.range(11, 13) if i else R.range(7, 9))
			var lean: float = sd * h * R.range(0.25, 0.45)
			var t0 := R.range(0.08, 0.2)
			spikes.append([Vector4(x, 0, h, 3.5 if i else 4.5), Vector4(lean, t0, 0, 0)])
	# cracks from the chest
	var IX := jround(W * 0.48)
	var IY := jround(H * 0.42)
	var cracks := []
	var walk := func(walk_: Callable, x: float, y: float, a: float, n: float) -> void:
		var pts := [Vector2(x, y)]
		var s := 0
		while s < n:
			a += R.range(-0.5, 0.5)
			x += cos(a) * R.range(1.4, 2.4)
			y += sin(a) * R.range(1.4, 2.4)
			if not at.call(floori(x), floori(y)):
				break
			pts.append(Vector2(x, y))
			if pts.size() > 3 and cracks.size() < 18 and R.chance(0.15):
				var na := a + R.sign() * R.range(0.6, 1.1)
				walk_.call(walk_, x, y, na, n / 2.0)
			s += 1
		cracks.append(pts)
	for i in 7:
		walk.call(walk, IX, IY, (i / 7.0) * TAU + R.range(-0.3, 0.3), 20.0)

	var ps := new_parts()
	ps.ground = 0.0
	var bs := new_bits()
	bs.ground = 0.0
	var lm := new_lamps()
	var pieces := []
	var maps := []
	var rime := []
	var st := {"t": 0.0, "locked": false, "cracked": false, "burst": false}
	var dur: float = root.duration
	var level := func(t: float) -> float: return H * (1 - out_cubic(clamp01(t / LOCK)))

	var shatter := func() -> void:
		var groups := {}
		var keys := []
		for y in H:
			for x in W:
				var k := ice[y * W + x]
				if k < 0:
					continue
				if not groups.has(k):
					groups[k] = []
					keys.append(k)
				var i := y * W + x
				groups[k].append([x, y, col[i] if solid[i] else mixc(col[i], C[3 + glass[i]], 0.3)])
		for k in keys:
			var px: Array = groups[k]
			var cx := 0.0
			var cy := 0.0
			for q in px:
				cx += q[0] + 0.5
				cy += q[1] + 0.5
			cx /= px.size()
			cy /= px.size()
			var r := 0.0
			var map := {}
			for q in px:
				r = maxf(r, Vector2(q[0] + 0.5 - cx, q[1] + 0.5 - cy).length())
				map[Vector2i(jround(q[0] + 0.5 - cx), jround(q[1] + 0.5 - cy))] = q[2]
			r += 1
			var dx := cx - IX
			var dy := cy - IY
			var d := Vector2(dx, dy).length()
			if d == 0.0:
				d = 1.0
			var sp := R.range(55, 115)
			var life := R.range(1.3, 1.85)
			var vx := (dx / d) * sp + R.range(-18, 18)
			var vy := (dy / d) * sp * 0.6 - R.range(110, 220)
			var va := R.range(-9, 9)
			maps.append(map)
			pieces.append({"id": pieces.size() + 1, "x": X0 + cx, "y": Y0 + cy, "vx": vx, "vy": vy, "a": 0.0, "va": va, "r": r, "life": life, "max": life,
				"rest": false, "n": px.size(), "on": true})
		for i in 64:
			var a := -PI / 2 + R.range(-1.45, 1.45)
			var sp := R.range(60, 180)
			var x := X0 + IX + R.range(-6, 6)
			var y := Y0 + IY + R.range(-8, 8)
			var life := R.range(0.9, 1.6)
			var an := R.range(0, TAU)
			var va := R.range(-20, 20)
			var s := R.range(1.5, 3.2)
			var c: Color = R.pick([C[7], C[6], C[5]])
			bs.add({"kind": 0, "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "g": 0.85, "drag": 0.6, "bounce": 0.3, "life": life, "a": an, "va": va, "s": s, "c": c})
		for i in 14:
			var x := R.range(-10, 10)
			var y := -R.range(1, 20)
			var vx := R.sign() * R.range(20, 80)
			var vy := -R.range(4, 20)
			var life := R.range(0.6, 1.1)
			var c: Color = C[6] if R.chance(0.5) else C[5]
			var s := R.range(2.5, 4.5)
			ps.spawn(VAPOUR, x, y, vx, vy, life, c, s)
		for i in 16:
			var x := R.range(-16, 16)
			var y := -R.range(4, 38)
			var vx := R.range(-40, 40)
			var vy := -R.range(10, 60)
			var life := R.range(0.4, 1)
			var c: Color = R.pick([Wc, C[6]])
			var s := R.range(1, 2.4)
			ps.spawn(STAR, x, y, vx, vy, life, c, s)
		lm.add(0, Y0 + IY, 46, Wc, 0.75, 0.14)
		lm.add(0, Y0 + IY, 70, C[4], 0.6, 0.5)

	var step := func(dt: float) -> void:
		st.t += dt
		var t: float = st.t
		# the cold climbs: rime sparkles at the frost line, vapour rolls off the feet
		if t < LOCK:
			var y: float = Y0 + level.call(t)
			if R.chance(0.7):
				var x := R.range(-10, 10)
				var vx := R.range(-12, 12)
				var vy := -R.range(0, 18)
				var life := R.range(0.25, 0.5)
				var c: Color = Wc if R.chance(0.5) else C[6]
				var s := R.range(0.8, 1.8)
				ps.spawn(STAR, x, y, vx, vy, life, c, s)
			if R.chance(0.25):
				var x := R.range(-8, 8)
				var vx := R.sign() * R.range(15, 50)
				var vy := -R.range(2, 10)
				var life := R.range(0.6, 1)
				var s := R.range(2, 3.5)
				ps.spawn(VAPOUR, x, -1, vx, vy, life, C[6], s)
		if not st.locked and t >= LOCK:
			st.locked = true
			lm.add(0, -20, 54, C[4], 0.6, 0.3)
			for i in 6:
				var x := R.range(-12, 12)
				var y := -R.range(4, 36)
				var life := R.range(0.35, 0.7)
				var c: Color = R.pick([Wc, C[6]])
				var s := R.range(1.2, 2.4)
				ps.spawn(STAR, x, y, 0, -4, life, c, s)
		if st.locked and t < CRACK and R.chance(0.08):
			var x := R.range(-11, 11)
			var y := -R.range(2, 36)
			var life := R.range(0.3, 0.6)
			var c: Color = R.pick([Wc, C[6]])
			var s := R.range(0.8, 2)
			ps.spawn(STAR, x, y, 0, -3, life, c, s)
		if not st.cracked and t >= CRACK:
			st.cracked = true
			for i in 5:
				var a := R.range(0, TAU)
				var sp := R.range(60, 150)
				var life := R.range(0.5, 0.9)
				var an := R.range(0, TAU)
				var va := R.range(-20, 20)
				var s := R.range(1, 2)
				bs.add({"kind": 0, "x": X0 + IX, "y": Y0 + IY, "vx": cos(a) * sp, "vy": sin(a) * sp - 60, "g": 0.8, "drag": 0.6, "bounce": 0.3, "life": life, "a": an, "va": va, "s": s, "c": C[6]})
			lm.add(0, Y0 + IY, 24, Wc, 0.7, 0.1)
		if not st.burst and t >= BURST:
			st.burst = true
			shatter.call()
		# the pieces: tumble, bounce, skid to a stop, melt
		for i in range(pieces.size() - 1, -1, -1):
			var q: Dictionary = pieces[i]
			if not q.on:
				continue
			q.life -= dt
			if q.life <= 0:
				q.on = false
				continue
			if q.rest:
				if t < dur - 0.9 and R.chance(0.02):
					var vx := R.range(-4, 4)
					var vy := -R.range(4, 10)
					var life := R.range(0.5, 0.8)
					var s := R.range(1.5, 2.5)
					ps.spawn(VAPOUR, q.x, q.y - 1, vx, vy, life, C[5], s)
				continue
			q.vy += 900 * dt
			q.vx -= q.vx * 0.5 * dt
			q.x += q.vx * dt
			q.y += q.vy * dt
			q.a += q.va * dt
			var g: float = -q.r * 0.55
			if q.y > g and q.vy > 0:
				q.y = g
				if q.vy > 90:
					rime.append(Vector3(q.x, 2 + q.r * 0.6, t))
					q.vy *= -0.32
					q.vx *= 0.65
					q.va = q.va * 0.5 + R.range(-4, 4)
					if q.n > 8:
						ps.spawn(STAR, q.x, q.y, 0, -6, 0.3, Wc, 1.2)
					for j in 2:
						var x: float = q.x + R.range(-2, 2)
						var vx := R.sign() * R.range(10, 30)
						var vy := -R.range(2, 8)
						var life := R.range(0.3, 0.5)
						var s := R.range(1.2, 2)
						ps.spawn(DUST, x, -0.5, vx, vy, life, C[5], s)
				elif absf(q.vx) > 12:
					q.vy = 0.0
					q.vx *= 0.9
					q.va *= 0.85
				else:
					q.rest = true
					q.vx = 0.0
					q.vy = 0.0
		bs.step(dt)
		ps.update(dt)
		lm.step(dt)

	var pt := new_track(2, 60.0, 2)
	var plt := new_track(2)
	var rec := func(s: int) -> void:
		for q in pieces:
			if not q.on:
				continue
			var fade := minf(1.0, q.life / 0.5)
			pt.put_head(q.id - 1, 1, Color(q.id - 1, 0, 0, 0))
			pt.put(q.id - 1, s, 0, Color(q.x, q.y, 1.0, q.a))
			pt.put(q.id - 1, s, 1, Color(fade, 1.0 if q.max - q.life < 0.05 else 0.0, q.id, ceilf(q.r)))
			if q.n > 6:
				plt.put(q.id - 1, s, 0, Color(q.x, q.y, 1.0, 0.2 * fade))
				plt.put(q.id - 1, s, 1, Color(6.0, 0, 0, 0))
		bs.record(s)
		ps.record(s)
		lm.record(s)
	run(step, rec)
	assert(rime.size() <= 48, "more rime than the shader holds")
	var u := "material:shader_parameter/"

	# behind: frost on the floor under the feet and where the pieces hit, its cold light
	var fk := func(t: float) -> float: return smooth(0.1, LOCK, t) * (1 - smooth(BURST + 0.6, BURST + 1.6, t))
	var rimes := []
	for i in 48:
		rimes.append(rime[i] if i < rime.size() else Vector3(0, 0, 99))
	var fr := shape("Frost", ssh("frost_floor"), Vector2(170, 3), {"rime": PackedVector3Array(rimes), "rime_count": float(rime.size()),
		"c5": C[5], "c6": C[6], "white": Wc}, {"at": Vector2(0, 0.5), "back": true})
	keyf(fr, u + "k", func(t: float) -> float: return fk.call(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(fr, u + "reach", func(t: float) -> float: return 6 + 12 * smooth(0, LOCK + 0.3, jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(fr, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	keyf(fr, u + "fade", func(t: float) -> float: return 1 - smooth(dur - 1, dur - 0.15, jt(t)), 0.0, -1.0, 60.0, "nearest")
	var fg := glow_path("FrostLight", Vector2(0, -2), Vector2(0, -2), 26, C[4])
	keyf(fg, u + "k", func(t: float) -> float: return 0.25 * fk.call(jt(t)))

	# the stand-in, until the burst
	var actor := actor_node()
	steps(actor, "visible", [[0.0, true], [BURST, false]])
	# the ice
	var gimg := Image.create(W, H, false, Image.FORMAT_RGBAF)
	for y in H:
		for x in W:
			var i := y * W + x
			if ice[i] >= 0:
				var c: Color = col[i]
				gimg.set_pixel(x, y, Color(c.r, c.g, c.b, 1 + 2 * solid[i] + 4 * glass[i]))
	var cimg := Image.create(512, 1, false, Image.FORMAT_RGBAF)
	var npts := 0
	for pts in cracks:
		for i in pts.size():
			cimg.set_pixel(npts, 0, Color(pts[i].x, pts[i].y, i, pts.size()))
			npts += 1
	var sa := []
	var sb := []
	for i in 12:
		sa.append(spikes[i][0] if i < spikes.size() else Vector4.ZERO)
		sb.append(spikes[i][1] if i < spikes.size() else Vector4(0, 99, 0, 0))
	var pal := []
	for i in 8:
		pal.append(C[i])
	var ib := shape("Ice", ssh("ice_body"), Vector2(60, 56), {"grid": asset("_grid", gimg), "cracks": asset("_cracks", cimg), "origin": Vector2(X0, Y0),
		"lock_t": LOCK, "crack_t": CRACK, "crack_count": float(npts), "spike_a": PackedVector4Array(sa), "spike_b": PackedVector4Array(sb),
		"spike_count": float(spikes.size()), "pal": pal, "white": Wc}, {"at": Vector2(0, -27)})
	keyf(ib, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	keyf(ib, u + "lv", func(t: float) -> float: return level.call(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(ib, u + "shake", func(t: float) -> float:
		var tt := jt(t)
		return ((1.0 if floori(tt * 50) % 2 else -1.0) * (1.0 if tt > BURST - 0.15 else 0.5)) if (tt > CRACK and tt < BURST) else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(ib, u + "glint", func(t: float) -> float: return fmod((jt(t) - LOCK) * 0.9, 1.6) if jt(t) > LOCK else -1.0, 0.0, -1.0, 60.0, "nearest")
	keyf(ib, u + "show_ice", func(t: float) -> float: return 1.0 if jt(t) < BURST else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(ib, u + "crack_k", func(t: float) -> float: return clamp01((jt(t) - CRACK) / 0.25) if jt(t) >= CRACK else -1.0, 0.0, -1.0, 60.0, "nearest")
	keyf(ib, u + "burst", func(t: float) -> Vector3:
		var tt := jt(t)
		return Vector3(X0 + IX, Y0 + IY, 10 * (1 - (tt - BURST) / 0.08) + 3) if (tt >= BURST and tt < BURST + 0.08) else Vector3(0, 0, -1), 0.0, -1.0, 60.0, "nearest")
	var il := glow_path("IceLight", Vector2(0, -18), Vector2(0, -18), 30, C[4])
	keyf(il, u + "k", func(t: float) -> float: return 0.18 * smooth(0, LOCK, jt(t)) if jt(t) < BURST else 0.0)
	var arm := func(t: float) -> float:
		var tt := jt(t)
		return float(jround(8 * (1 - (tt - LOCK) / 0.18))) if (tt > LOCK and tt < LOCK + 0.18) else 0.0
	var spk := shape("LockGlint", load("res://addons/pixelfx_particles/fx/arcane/_sparkle.gdshader"), Vector2(19, 19),
		{"arm": 0, "c": Wc, "tip": C[5], "heart": Wc}, {"at": Vector2(-4 + 0.5, Y0 + 8 + 0.5)})
	keyf(spk, u + "arm", arm, 0.0, LOCK + 0.3, 60.0, "nearest")
	var sgl := glow_path("LockGlintLight", Vector2(-4, Y0 + 8), Vector2(-4, Y0 + 8), 20, Wc)
	keyf(sgl, u + "radius", func(t: float) -> float: return 4.0 + 2.0 * arm.call(t), 0.0, LOCK + 0.3, 60.0, "nearest")
	keyf(sgl, u + "k", func(t: float) -> float: return 0.6 if arm.call(t) >= 1 else 0.0, 0.0, LOCK + 0.3, 60.0, "nearest")
	# the pieces, the shards, the particles, the lights
	var msize := 1
	for m in maps:
		for k in m:
			msize = maxi(msize, 2 * maxi(absi(k.x), absi(k.y)) + 1)
	var mimg := Image.create(msize, msize * maxi(1, maps.size()), false, Image.FORMAT_RGBAF)
	var hm := msize / 2
	for j in maps.size():
		for k in maps[j]:
			var c: Color = maps[j][k]
			mimg.set_pixel(k.x + hm, j * msize + k.y + hm, Color(c.r, c.g, c.b, 1))
	var reach := 4.0
	for q in pieces:
		reach = maxf(reach, ceilf(q.r))
	track("Pieces", pt, ssh("ice_piece"), int(reach) * 2 + 1, {"maps": asset("_maps", mimg), "msize": float(msize), "white": Wc})
	track("PiecesLight", plt, ssh("lamps"), 13, {"pal": [C[5], C[5], C[5], C[5], C[5], C[5], C[5], C[5]]}, {"layer": "light"})
	bits("Shards", bs)
	parts("Parts", ps, {"sparks": [Wc, C[6], C[5], C[4]], "haze": C[5]})
	lamps("Lights", lm)
