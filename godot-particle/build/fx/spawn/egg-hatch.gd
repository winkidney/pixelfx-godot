# reimagined-from: src/fx/spawn/egg-hatch.js@960bba8ae71947f0cfca35e45af4aa85626d0fb8
# Egg hatch: A speckled egg rocks three times, each rock cracking it further with warm light leaking out, then pops: light pours out of the opening and lit shell halves tumble away.
# one-shot, 3.10 s, 120x96 canvas, origin [60.0, 84.0], backdrop ground
# ramp glow: #ff8a2a #ffd25a #fff3c0
# ramp palette: #1e1826 #4a3e52 #857684 #c4b4ac #ece0d2 #fffaf0
# The original's own update() runs here with its seeded draws (its cracks walked, its shell broken into pieces round
# random seeds, its Particles, Bits and Lights). The egg is shaded pixel by pixel as the original shades it
# (fx/spawn/_egg.gdshaderinc: rocked about its base, cracks opening stage by stage with light in the gaps and through
# the shell, the cup's burning rim, the flooded opening), with its light. The rays fanning out of the opening are
# tracked particles (fx/spawn/_ray.gdshader, with their light), as are the tumbling shell pieces (_piece: each its own
# map of the shell's cells, crumbling away), the chips (_shards: the original's Bits) and the stars, sparks, motes and
# dust (_parts). Glows keyed on the original's formulas.
extends "res://build/fx/spawn/_spawn.gd"

const WOBBLES := [[0.3, 0.11], [0.85, 0.19], [1.4, 0.28]]
const POP := 1.98
const EW := 16
const EH := 20
const ZY := 11
const LIGHT_DIR := [-0.72, 0.5, 0.48]


static func jround(x: float) -> int:
	return floori(x + 0.5)


static func stage(t: float) -> int:
	return 3 if t > WOBBLES[2][0] + 0.05 else 2 if t > WOBBLES[1][0] + 0.05 else 1 if t > WOBBLES[0][0] + 0.05 else 0


static func angle(t: float) -> float:
	var a := 0.0
	for w in WOBBLES:
		var u: float = t - w[0]
		if u > 0 and u < 0.55:
			a += w[1] * sin(u * 22) * exp(-u * 5)
	if t > POP - 0.14 and t < POP:
		a += 0.05 * sin(t * 120)
	return a


static func inner(t: float) -> float:
	return stage(t) / 3.0 + 0.25 * maxf(0.0, sin(t * 9)) * (stage(t) / 3.0) if t < POP else 1.6 * exp(-(t - POP) * 2.6)


func make() -> void:
	var G: PackedColorArray = root.ramps.glow
	var SPK := Color(String(meta.options.speckle))
	var SPK2 := mixc(SPK, C[1], 0.5)
	var W := Color.WHITE
	R = JsRng.new(int(meta.options.seed))
	var shell := [W, C[1], C[2], C[3], C[4], C[5], SPK, SPK2]
	# the egg in its own pixels: x across from its middle, y up from its base
	var egg := {}
	var order := []
	for y in EH:
		for x in range(-EW / 2, EW / 2):
			var v := (y + 0.5) / EH
			var u := (x + 0.5) / (EW / 2.0)
			var half := sqrt(maxf(0.0, 1.0 - pow(2 * v - 1, 2))) * (1.08 - 0.22 * v)
			if absf(u) <= half:
				var e := {"x": x, "y": y, "u": u, "v": v, "half": half}
				egg[Vector2i(x, y)] = e
				order.append(e)
	var has := func(x: int, y: int) -> bool: return egg.has(Vector2i(x, y))
	for e in order:
		var nx := clampf(e.u / maxf(0.05, e.half), -1, 1)
		var ny: float = (2 * e.v - 1) * 0.9
		var nz := sqrt(maxf(0.0, 1 - nx * nx - ny * ny))
		var d: float = nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1] + nz * LIGHT_DIR[2]
		var edge: bool = not has.call(e.x - 1, e.y) or not has.call(e.x + 1, e.y) or not has.call(e.x, e.y - 1) or not has.call(e.x, e.y + 1)
		var c := 0 if d > 0.9 else 5 if d > 0.62 else 4 if d > 0.32 else 3 if d > 0.02 else 2 if d > -0.3 else 1
		if edge and nx > 0.25 and ny < 0.55:
			c = 3
		elif rand([e.x, e.y, 3]) < 0.08 and e.v > 0.12 and not edge:
			c = 6 if d > 0.2 else 7
		e.c = c
		e.lit = d
	# cracks: three stages, the last a zigzag right round the egg where the top breaks off
	var crack := {}
	var walk := func(x: float, y: float, a: float, n: int, s: int) -> void:
		var px := jround(x)
		var py := jround(y)
		for i in n:
			var side := (1.0 if i % 2 else -1.0) * R.range(0.6, 1.3)
			a += R.range(-0.25, 0.25)
			x += cos(a) * 1.8 - sin(a) * side * 0.6
			y += sin(a) * 1.8 + cos(a) * side * 0.6
			var nx := jround(x)
			var ny := jround(y)
			var m := maxi(absi(nx - px), absi(ny - py))
			for j in range(1, m + 1):
				var k := Vector2i(jround(px + (nx - px) * j / float(m)), jround(py + (ny - py) * j / float(m)))
				if not egg.has(k):
					return
				if not crack.has(k):
					crack[k] = s
			px = nx
			py = ny
	walk.call(2, 15, -2.2, 3, 0)
	walk.call(2, 15, 0.3, 2, 0)
	walk.call(-2, 13, -0.6, 3, 1)
	walk.call(-2, 13, 2.7, 3, 1)
	walk.call(3, 11, 1.9, 2, 1)
	walk.call(2, 15, 1.5, 2, 1)
	var zig := []
	for x in range(-EW / 2, EW / 2):
		var y: int = ZY + (1 if (x + 8) % 3 == 0 else 0 if (x + 8) % 3 == 1 else -1)
		zig.append(y)
		if has.call(x, y):
			crack[Vector2i(x, y)] = 2
	var zig_at := func(x: int) -> int: return zig[clampi(x + EW / 2, 0, zig.size() - 1)]
	var eggimg := Image.create(EW, EH, false, Image.FORMAT_RGBAF)
	var nearimg := Image.create(EW, EH, false, Image.FORMAT_RGBAF)
	for e in order:
		var nn := [9.0, 9.0, 9.0]
		for s in 3:
			for k in crack:
				if crack[k] <= s:
					nn[s] = minf(nn[s], Vector2(k.x - e.x, k.y - e.y).length())
		eggimg.set_pixel(e.x + 8, e.y, Color(e.c, e.lit, crack.get(Vector2i(e.x, e.y), -1), 1))
		nearimg.set_pixel(e.x + 8, e.y, Color(nn[0], nn[1], nn[2], 1))

	var ps := new_parts()
	ps.ground = 0.0
	var bs := new_bits()
	bs.ground = 0.0
	var lm := new_lamps()
	var pieces := []
	var st := {"t": 0.0, "popped": false, "crumbled": false, "cup_a": 0.0, "cup_v": 0.0, "done": [false, false, false]}
	var dur: float = root.duration
	var CRUMBLE := dur - 0.55
	var maps := []

	var break_up := func(keep: Callable, n: int, vf: Callable, lf: Callable) -> void:
		var seeds := []
		for i in n:
			var sx := R.range(-EW / 2.0 + 1, EW / 2.0 - 1)
			var sy := R.range(0, EH)
			seeds.append(Vector2(sx, sy))
		var cells := {}
		var keys := []
		for e in order:
			if not keep.call(e.x, e.y):
				continue
			var best := 0
			var bd := 1e9
			for i in seeds.size():
				var d: float = Vector2(e.x - seeds[i].x, e.y - seeds[i].y).length()
				if d < bd:
					bd = d
					best = i
			if not cells.has(best):
				cells[best] = []
				keys.append(best)
			cells[best].append(e)
		for kk in keys:
			var px: Array = cells[kk]
			var cx := 0.0
			var cy := 0.0
			for e in px:
				cx += e.x + 0.5
				cy += e.y + 0.5
			cx /= px.size()
			cy /= px.size()
			var mine := {}
			for e in px:
				mine[Vector2i(e.x, e.y)] = true
			var map := {}
			var r := 0.0
			for e in px:
				var edge := false
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(e.x, e.y) + dd
					if not mine.has(q) and egg.has(q):
						edge = true
				var c: int = 3 if e.c in [1, 2] else e.c
				map[Vector2i(jround(e.x + 0.5 - cx), jround(-(e.y + 0.5 - cy)))] = [c, edge]
				r = maxf(r, Vector2(e.x + 0.5 - cx, e.y + 0.5 - cy).length())
			r += 1
			var v: Vector2 = vf.call(cx, cy)
			var l: float = lf.call()
			var va := R.range(-10, 10)
			maps.append(map)
			pieces.append({"id": pieces.size() + 1, "x": cx, "y": -cy, "vx": v.x, "vy": v.y, "a": 0.0, "va": va, "r": r, "life": l, "max": l,
				"rest": false, "born": st.t, "on": true})

	var pop := func() -> void:
		st.popped = true
		var keep := func(x: int, y: int) -> bool: return y >= zig_at.call(x)
		var vf := func(cx: float, _cy: float) -> Vector2:
			var vx := cx * R.range(8, 13) + R.range(-14, 14)
			return Vector2(vx, -R.range(140, 210))
		var lf := func() -> float: return R.range(0.95, 1.15)
		break_up.call(keep, 6, vf, lf)
		for i in 14:
			var a := -PI / 2 + R.range(-1.2, 1.2)
			var sp := R.range(70, 170)
			var x := R.range(-5, 5)
			var y := -ZY - R.range(0, 4)
			var life := R.range(0.55, 0.85)
			var an := R.range(0, TAU)
			var va := R.range(-20, 20)
			var s := R.range(1.2, 2.4)
			var c: Color = R.pick([C[5], C[5], C[4], G[2]])
			bs.add({"kind": 0, "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "g": 0.9, "drag": 0.6, "bounce": 0.3, "life": life, "a": an, "va": va, "s": s, "c": c})
		for i in 12:
			var a := -PI / 2 + R.range(-1.1, 1.1)
			var sp := R.range(50, 110)
			var x := R.range(-3, 3)
			var life := R.range(0.4, 0.9)
			var c: Color = R.pick([W, G[2], G[1]])
			var s := R.range(1, 2.2)
			ps.spawn(STAR, x, -ZY - 2, cos(a) * sp, sin(a) * sp, life, c, s)
		for i in 10:
			var a := -PI / 2 + R.range(-1, 1)
			var sp := R.range(100, 200)
			var x := R.range(-3, 3)
			var life := R.range(0.2, 0.45)
			ps.spawn(SPARK, x, -ZY - 1, cos(a) * sp, sin(a) * sp, life)
		for i in 4:
			var s := R.sign()
			var x := s * R.range(5, 8)
			var vx := s * R.range(25, 50)
			var vy := -R.range(2, 6)
			var life := R.range(0.15, 0.25)
			var sz := R.range(1, 1.8)
			ps.spawn(DUST, x, -1, vx, vy, life, C[5], sz)
		lm.add(0, -ZY - 10, 40, G[1], 0.9, 0.55)
		lm.add(0, -ZY - 2, 18, W, 0.9, 0.12)
		st.cup_v = R.sign() * 3

	var step := func(dt: float) -> void:
		st.t += dt
		var t: float = st.t
		for i in 3:
			if not st.done[i] and t >= WOBBLES[i][0] + 0.05:
				st.done[i] = true
				lm.add(-3 if i == 1 else 2, -14 + i, 8 + i * 2, G[1], 0.25 + i * 0.08, 0.18)
				for j in 2 + i * 2:
					var x := R.range(-5, 5)
					var y := -R.range(8, 17)
					var vx := R.range(-20, 20)
					var vy := -R.range(10, 30)
					var life := R.range(0.25, 0.5)
					var c: Color = R.pick([W, G[2]])
					var s := R.range(0.6, 1.4)
					ps.spawn(STAR, x, y, vx, vy, life, c, s)
				for j in i + 1:
					var x := R.range(-4, 4)
					var y := -R.range(10, 16)
					var vx := R.range(-50, 50)
					var vy := -R.range(40, 90)
					var life := R.range(0.5, 0.8)
					var an := R.range(0, TAU)
					var va := R.range(-20, 20)
					var s := R.range(1, 1.6)
					bs.add({"kind": 0, "x": x, "y": y, "vx": vx, "vy": vy, "g": 0.9, "drag": 0.5, "bounce": 0.3, "life": life, "a": an, "va": va, "s": s, "c": C[4]})
				var x := R.sign() * R.range(5, 7)
				var vx := R.sign() * R.range(8, 18)
				var vy := -R.range(1, 3)
				var life := R.range(0.15, 0.25)
				var s := R.range(0.8, 1.4)
				ps.spawn(DUST, x, -0.5, vx, vy, life, C[5], s)
		if not st.popped and t >= POP:
			pop.call()
		# light keeps welling up out of the empty cup for a moment: something came out of there
		if st.popped and t < POP + 0.6 and R.chance(0.35):
			var x := R.range(-4, 4)
			var vx := R.range(-8, 8)
			var vy := -R.range(40, 80)
			var life := minf(R.range(0.4, 0.8), dur - 0.1 - t)
			var c: Color = R.pick([G[2], G[1], W])
			ps.spawn(MOTE, x, -ZY - 1, vx, vy, life, c, 0.7)
		if st.popped and not st.crumbled and t >= CRUMBLE:
			st.crumbled = true
			var keep := func(x: int, y: int) -> bool: return y < zig_at.call(x)
			var vf := func(cx: float, _cy: float) -> Vector2:
				var vx := cx * R.range(4, 8)
				return Vector2(vx, -R.range(40, 80))
			var lf := func() -> float: return R.range(0.38, 0.48)
			break_up.call(keep, 4, vf, lf)
			for i in 3:
				var x := R.range(-6, 6)
				var vx := R.sign() * R.range(10, 25)
				var vy := -R.range(2, 6)
				var life := R.range(0.15, 0.25)
				var s := R.range(1, 1.6)
				ps.spawn(DUST, x, -1, vx, vy, life, C[5], s)
		if st.popped:
			st.cup_v += (-st.cup_a * 90 - st.cup_v * 4) * dt
			st.cup_a += st.cup_v * dt
		for i in range(pieces.size() - 1, -1, -1):
			var q: Dictionary = pieces[i]
			if not q.on:
				continue
			q.life -= dt
			if q.life <= 0:
				q.on = false
				continue
			if q.rest:
				continue
			q.vy += 900 * dt
			q.vx -= q.vx * 0.6 * dt
			q.x += q.vx * dt
			q.y += q.vy * dt
			q.a += q.va * dt
			var g: float = -q.r * 0.45
			if q.y > g and q.vy > 0:
				q.y = g
				if q.vy > 80:
					q.vy *= -0.35
					q.vx *= 0.6
					q.va *= 0.5
				else:
					q.rest = true
					q.vx = 0.0
					q.vy = 0.0
		bs.step(dt)
		ps.update(dt)
		lm.step(dt)

	var pt := new_track(2, 60.0, 2)
	var plt := new_track(2)
	var oy := -ZY + 0.5
	var rays := new_track(2)
	var ray_light := new_track(2)
	var looks := []
	var rec := func(s: int) -> void:
		var t: float = st.t
		var g := inner(t)
		looks.append({"cup": st.cup_a, "popped": st.popped, "crumbled": st.crumbled})
		for q in pieces:
			if not q.on:
				continue
			pt.put_head(q.id - 1, 1, Color(q.id - 1, 0, 0, 0))
			pt.put(q.id - 1, s, 0, Color(q.x, q.y, 1.0, q.a))
			pt.put(q.id - 1, s, 1, Color(minf(1.0, q.life / 0.4), 1.0 if t - q.born < 0.35 else 0.0, q.id, ceilf(q.r)))
			if t - q.born < 0.35:
				plt.put(q.id - 1, s, 0, Color(q.x, q.y, 1.0, 0.3))
				plt.put(q.id - 1, s, 1, Color(6.0, 0, 0, 0))
		var q2 := t - POP
		if st.popped and q2 < 0.65 and not st.crumbled and g > 0.22:
			var rk := q2 / 0.65
			var L := 36 * out_cubic(clamp01(q2 / 0.1)) * (1 - rk * 0.6)
			var li := 0
			for i in 7:
				var an := -PI / 2 + (i - 3) * 0.24 + 0.05 * sin(t * 6 + i)
				var ln := L * (0.65 if i % 2 else 1.0)
				var w := 1 if i % 2 else 2
				var x1 := cos(an) * ln
				var y1 := oy + sin(an) * ln
				for j in w:
					var a0 := Vector2(j * 0.8 - 0.4, oy - 1)
					rays.put(li, s, 0, Color(a0.x, a0.y, 1.0, 1.1 - rk))
					rays.put(li, s, 1, Color(0, 0, x1 + j * 0.8 - 0.4 - a0.x, y1 - a0.y))
					li += 1
				ray_light.put(i, s, 0, Color(0, oy, 1.0, 1 - rk))
				ray_light.put(i, s, 1, Color(0, 0, x1, y1 - oy))
		bs.record(s)
		ps.record(s)
		lm.record(s)
	run(step, rec)
	var look := func(t: float) -> Dictionary: return looks[clampi(roundi(t * HZ), 0, looks.size() - 1)]
	var u := "material:shader_parameter/"

	# behind: the soft contact shadow, shifting as the egg rocks; warm light on the floor as it leaks out
	var sh := shape("Shadow", ssh("egg_shadow"), Vector2(21, 3), {"color": C[0], "sx": 0.0, "k": 1.0, "translucent": true}, {"at": Vector2(0.5, 0.5), "back": true})
	keyf(sh, u + "sx", func(t: float) -> float: return 0.0 if look.call(t).popped else -angle(jt(t)) * 8, 0.0, -1.0, 60.0, "nearest")
	keyf(sh, u + "k", func(t: float) -> float: return 1.0 - smooth(POP, CRUMBLE, jt(t)) * 0.4 if look.call(t).popped else 1.0, 0.0, -1.0, 60.0, "nearest")
	keyf(sh, "visible", func(t: float) -> bool: return not look.call(t).crumbled, 0.0, -1.0, 60.0, "nearest")
	var fg := glow_path("FloorLight", Vector2(0, -3), Vector2(0, -3), 22, G[0])
	keyf(fg, u + "k", func(t: float) -> float:
		var g := inner(jt(t))
		return 0.18 * minf(1.2, g) if g > 0.05 else 0.0)

	# the egg, and its light
	var eparams := {"egg": asset("_egg", eggimg), "near": asset("_near", nearimg), "shell": shell, "c0": C[0], "c1": C[1], "c2": C[2], "c4": C[4],
		"g0": G[0], "g1": G[1], "g2": G[2], "white": W, "zig_y": float(ZY)}
	var eggs := [shape("Egg", ssh("egg"), Vector2(25, 26), eparams, {"at": Vector2(0.5, -11)})]
	eggs.append(shape("EggLight", ssh("egg_light"), Vector2(25, 26), eparams, {"at": Vector2(0.5, -11)}))
	for e in eggs:
		keyf(e, u + "angle", func(t: float) -> float: return look.call(t).cup * 0.03 if look.call(t).popped else angle(jt(t)), 0.0, -1.0, 60.0, "nearest")
		keyf(e, u + "popped", func(t: float) -> float: return 1.0 if look.call(t).popped else 0.0, 0.0, -1.0, 60.0, "nearest")
		keyf(e, u + "stage", func(t: float) -> float: return float(stage(jt(t))), 0.0, -1.0, 60.0, "nearest")
		keyf(e, u + "glow_in", func(t: float) -> float: return inner(jt(t)), 0.0, -1.0, 60.0, "nearest")
		keyf(e, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
		keyf(e, u + "flood", func(t: float) -> float:
			var lk: Dictionary = look.call(t)
			return 1.0 if (lk.popped and jt(t) - POP < 1.2 and not lk.crumbled and inner(jt(t)) > 0.22) else 0.0, 0.0, -1.0, 60.0, "nearest")
		keyf(e, "visible", func(t: float) -> bool: return not look.call(t).crumbled, 0.0, -1.0, 60.0, "nearest")
	# the pop: light over the opening, rays fanning up out of it, a flash, the light lingering over the cup
	var flood_on := func(t: float) -> bool:
		var lk: Dictionary = look.call(t)
		return lk.popped and jt(t) - POP < 1.2 and not lk.crumbled and inner(jt(t)) > 0.22
	var og := glow_path("OpeningLight", Vector2(0, oy), Vector2(0, oy), 16, G[1])
	keyf(og, u + "k", func(t: float) -> float: return 0.6 * inner(jt(t)) if flood_on.call(t) else 0.0, POP - 0.04)
	track("Rays", rays, ssh("ray"), 81, {"c0": W, "c1": G[2], "c2": G[1]})
	track("RaysLight", ray_light, ssh("seg_light"), 91, {"color": G[1], "radius": 5.0, "k": 0.35}, {"layer": "light"})
	var flash := glow_path("PopFlash", Vector2(0, oy - 4), Vector2(0, oy - 4), 30, W)
	keyf(flash, u + "k", func(t: float) -> float: return 0.6 * (1 - (jt(t) - POP) / 0.1) if (flood_on.call(t) and jt(t) - POP < 0.1) else 0.0, POP - 0.04, POP + 0.2)
	var cupl := glow_path("CupLight", Vector2(0, oy - 26), Vector2(0, oy), 8, G[1])
	keyf(cupl, u + "k", func(t: float) -> float: return 0.25 * inner(jt(t)) if flood_on.call(t) else 0.0, POP - 0.04)
	# the light inside, through the shell, before it pops
	var ig := glow_path("InnerLight", Vector2(0, -EH * 0.55), Vector2(0, -EH * 0.55), 13, G[1])
	keyf(ig, u + "radius", func(t: float) -> float: return 7.0 + 2.0 * stage(jt(t)), 0.0, POP + 0.04, 60.0, "nearest")
	keyf(ig, u + "k", func(t: float) -> float: return 0.05 * inner(jt(t)) if (not look.call(t).popped and inner(jt(t)) > 0) else 0.0, 0.0, POP + 0.04)
	# pieces of shell, chips, the glint, the particles, the lights
	var mapimg := Image.create(17, 17 * maxi(1, maps.size()), false, Image.FORMAT_RGBAF)
	for j in maps.size():
		for k in maps[j]:
			if absi(k.x) <= 8 and absi(k.y) <= 8:
				mapimg.set_pixel(k.x + 8, j * 17 + k.y + 8, Color(maps[j][k][0], 1.0 if maps[j][k][1] else 0.0, 0, 1))
	track("Pieces", pt, ssh("piece"), 21, {"maps": asset("_maps", mapimg), "shell": shell, "hot_c": G[2], "cool_c": C[4]})
	track("PiecesLight", plt, ssh("lamps"), 13, {"pal": [G[1], G[1], G[1], G[1], G[1], G[1], G[1], G[1]]}, {"layer": "light"})
	bits("Chips", bs)
	var spk := shape("Glint", load("res://addons/pixelfx_particles/fx/arcane/_sparkle.gdshader"), Vector2(19, 19),
		{"arm": 4, "c": W, "tip": G[1], "heart": W}, {"at": Vector2(-3 + 0.5, -ZY - 6 + 0.5)})
	keyf(spk, "material:shader_parameter/arm", func(t: float) -> float: return float(jround(4 * (1 - (jt(t) - POP) / 0.9))) if jt(t) >= POP else 0.0, POP - 0.04, POP + 0.94, 60.0, "nearest")
	var sgl := glow_path("GlintLight", Vector2(-3, -ZY - 6), Vector2(-3, -ZY - 6), 12, W)
	keyf(sgl, u + "radius", func(t: float) -> float: return 4.0 + 2.0 * jround(4 * (1 - (jt(t) - POP) / 0.9)), POP - 0.04, POP + 0.94, 60.0, "nearest")
	keyf(sgl, u + "k", func(t: float) -> float: return 0.4 if (jt(t) >= POP and jt(t) - POP < 0.9 and jround(4 * (1 - (jt(t) - POP) / 0.9)) >= 1) else 0.0, POP - 0.04, POP + 0.94, 60.0, "nearest")
	parts("Parts", ps, {"sparks": [W, G[2], G[1], G[0]]})
	lamps("Lights", lm)
