# reimagined-from: src/fx/lightning/zap-hit.js@cf5a8d0dcc8f77e70291697c63068c2a6e35cdde
# Zap hit: A contact zap: an arc snaps in from the left, the hit point overloads into a knot of tiny crackling zigzags, a fern of burn marks glows outward, sparks jink away, ozone puffs.
# one-shot, 0.90 s, 144x112 canvas, origin [76.0, 56.0], backdrop dark
# The arc is a layered bolt (fx/lightning/_volt.gd) racing in from the left with a hot head, re-struck every frame
# and flickering; the knot is a dozen crackles re-thrown every frame round a white heart; the fern is grown once
# here, its pixels baked with their distance from the hit into a data texture, and a shader burns it outward and
# cools it down the palette (another adds its light); the jinking sparks replay the original's little physics as
# keyed lines; ozone puffs rise on the soft layer; lights flare and strobe out.
extends "res://build/fx/lightning/_base.gd"

const SNAP := 0.05
const Y0 := -12.0


func make() -> void:
	var C := pal()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3

	# the fern of burn marks, behind everything
	_fern(rng, C)

	# the arc: snaps in from the left in two frames, holds and flickers, then lets go
	var arc := volt("Arc", Vector2(-66, Y0), Vector2.ZERO, {"jag": 0.22, "forks": 0.35, "rate": 30.0, "thick": 0.95,
		"head": 2.0, "head_light": 0.6, "head_reach": 14.0})
	var kk := []
	var up := []
	var hero := []
	var th := []
	for i in 11:
		var t := i / FPS
		var f := i
		var k: float = 1.0 if t < SNAP else ((0.7 if f % 2 else 1.0) if t < 0.2 else 0.55 * (1.0 - (t - 0.2) / 0.12))
		var at := maxf(0.0, t - 0.5 / FPS)
		kk.append([at, k])
		up.append([at, clampf(t / SNAP, 0.0, 1.0)])
		hero.append([at, t >= SNAP and t < SNAP + 0.034])
		th.append([at, 0.95 if t < SNAP + 0.034 else 0.7])
	key(arc, "k", kk, "nearest")
	key(arc, "up_to", up, "nearest")
	key(arc, "hero", hero, "nearest")
	key(arc, "thick", th, "nearest")
	show(arc, 0.0, 0.32)
	# the knot: tiny zigzags re-thrown every frame round a white heart
	var knot := []
	for j in 11:
		knot.append(volt("Knot%d" % j, Vector2.ZERO, Vector2(4, 0), {"style": 1, "jag": 0.5, "forks": 0.0, "rate": 30.0, "light": 0.25, "visible": false}))
	var heart_out := ring("HeartOut", 6, {"radius": 4.0, "color": C[5]})
	var heart := ring("Heart", 4, {"radius": 2.5, "color": Color.WHITE})
	var heart_light := glow("HeartLight", 22, {"radius": 20, "color": C[4], "alpha": 0.0})
	var heart_white := glow("HeartWhite", 11, {"radius": 9, "color": Color.WHITE, "alpha": 0.0})
	key(heart_white, "material:shader_parameter/alpha", [[0.0, 0.0], [SNAP - 0.001, 0.0], [SNAP, 0.4], [SNAP + 0.07, 0.4], [SNAP + 0.071, 0.0]], "nearest")
	var vis := []
	var fr := []
	var to := []
	var ks := []
	for j in 11:
		vis.append([])
		fr.append([])
		to.append([])
		ks.append([])
	var r_out := []
	var r_in := []
	var hl := []
	for i in 15:
		var t := i / FPS
		var at := maxf(0.0, t - 0.5 / FPS)
		var live := t >= SNAP and t < 0.45
		var a := (t - SNAP) / 0.4
		var R0 := 8.0 * (1.0 - a * 0.6)
		var m := int(roundf(11.0 * (1.0 - a * 0.5))) if live else 0
		for j in 11:
			var ang := rng.randf_range(0, TAU)
			var d0 := rng.randf_range(0.5, R0 * 0.5)
			var ang2 := ang + rng.randf_range(-1.2, 1.2)
			var d1 := rng.randf_range(R0 * 0.55, R0)
			vis[j].append([at, j < m])
			fr[j].append([at, Vector2(cos(ang), sin(ang)) * d0])
			to[j].append([at, Vector2(cos(ang2), sin(ang2)) * d1])
			ks[j].append([at, 0.75 * (1.0 - a) + 0.25])
		r_out.append([at, 3.0 * (1.0 - a) + 1.0 if live else 0.0])
		r_in.append([at, 2.0 * (1.0 - a) + 0.5 if live else 0.0])
		hl.append([at, 0.55 * (1.0 - a) if live else 0.0])
	for j in 11:
		key(knot[j], "visible", vis[j], "nearest")
		key(knot[j], "from", fr[j], "nearest")
		key(knot[j], "to", to[j], "nearest")
		key(knot[j], "k", ks[j], "nearest")
	key(heart_out, "material:shader_parameter/radius", r_out, "nearest")
	key(heart, "material:shader_parameter/radius", r_in, "nearest")
	key(heart_light, "material:shader_parameter/alpha", hl, "nearest")

	# the light: a flare at the hit, and a glow that strobes as it dies
	flash("Flare", Vector2.ZERO, 60, C[4], 0.7, 0.3, SNAP)
	flash("FlareWhite", Vector2.ZERO, 14, Color.WHITE, 0.5, 0.07, SNAP)
	var strobe := glow("Strobe", 42, {"radius": 40, "color": C[3], "alpha": 0.0})
	var sr := []
	var sa := []
	for i in 28:
		var t := i / FPS
		var at := maxf(0.0, t - 0.5 / FPS)
		sr.append([at, 40.0 * maxf(0.0, 1.0 - t / 0.85)])
		sa.append([at, 0.45 * exp(-(t - SNAP) * 5.0) * (0.7 if i % 2 else 1.0) if t >= SNAP else 0.0])
	key(strobe, "material:shader_parameter/radius", sr, "nearest")
	key(strobe, "material:shader_parameter/alpha", sa, "nearest")

	_jinks(rng, C)

	# ozone: three little puffs rise off the hit
	var ash := Color("#6a6680").lerp(C[4], 0.3)
	var puffs := particles("Ozone", {"layer": "soft", "amount": 3, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "disc7", "emit": {"box": Vector2(4, 3)}, "dir": -90, "spread": 30, "speed": [8, 16],
		"damping": [6, 10], "scale": [0.8, 1.1], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.2]],
		"ramp": gradient([Color(ash, 0.0), Color(ash, 0.45), Color(Color("#4e4a5e"), 0.3), Color(Color("#4e4a5e"), 0.0)], [0.0, 0.08, 0.6, 0.95])})
	emit(puffs, SNAP)


## The burn the current leaves: six fronds radiating, side fronds alternating off them, baked into a data texture
## (distance from the hit, side line) that _fern.gdshader burns outward.
func _fern(rng: RandomNumberGenerator, C: PackedColorArray) -> void:
	var out := []
	for i in 6:
		_grow(rng, out, Vector2.ZERO, i / 6.0 * TAU + rng.randf_range(-0.35, 0.35), rng.randf_range(18, 32), 1.0, 0.0, 0)
	# rasterise: each segment a line of pixels carrying its end's distance; the thick side line one px right
	var px := {}
	for br in out:
		var pts: Array = br.pts
		for i in range(1, pts.size()):
			var a: Vector3 = pts[i - 1]
			var b: Vector3 = pts[i]
			for q in _bresenham(Vector2i(floori(a.x), floori(a.y)), Vector2i(floori(b.x), floori(b.y))):
				px[q] = Vector2(b.z, 0.0)
			if br.w >= 1.0 and b.z < 9.0:
				for q in _bresenham(Vector2i(floori(a.x) + 1, floori(a.y)), Vector2i(floori(b.x) + 1, floori(b.y))):
					if not px.has(q):
						px[q] = Vector2(b.z, 1.0)
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-100000, -100000)
	for q in px:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	lo -= Vector2i(6, 6)
	hi += Vector2i(7, 7)
	var sz := hi - lo
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	for q in px:
		var v: Vector2 = px[q]
		img.set_pixel(q.x - lo.x, q.y - lo.y, Color(v.x / 64.0, v.y, 0.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var centre := Vector2(lo) + Vector2(sz) / 2.0
	var params := {"data": tex, "c1": C[1], "c2": C[2], "c4": C[4], "c5": C[5], "c6": C[6], "c7": C[7]}
	var burn := shape("Fern", load("res://addons/pixelfx_particles/fx/lightning/_fern.gdshader"), Vector2(sz), params, {"at": centre, "back": true})
	key(burn, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	var lit := shape("FernLight", load("res://addons/pixelfx_particles/fx/lightning/_fern_light.gdshader"), Vector2(sz), {"data": tex, "color": C[5]}, {"at": centre})
	key(lit, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])


func _grow(rng: RandomNumberGenerator, out: Array, p: Vector2, a: float, length: float, w: float, d: float, depth: int) -> void:
	var pts := [Vector3(p.x, p.y, d)]
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var s := 0.0
	while s < length:
		a += rng.randf_range(-0.3, 0.3)
		p += Vector2(cos(a), sin(a)) * 1.4
		d += 1.4
		pts.append(Vector3(p.x, p.y, d))
		if depth < 2 and s > 2.0 and rng.randf() < 0.24:
			side = -side
			_grow(rng, out, p, a + side * rng.randf_range(0.55, 1.05), (length - s) * rng.randf_range(0.3, 0.55), w * 0.6, d, depth + 1)
		s += 1.4
	out.append({"pts": pts, "w": w})


static func _bresenham(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		out.append(p)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return out


## Sparks that jink: they fly out and jerk to a new heading every few hundredths of a second, a bright head and the
## zigzag behind it cooling. The original's physics, replayed here at 120 Hz and keyed every frame as lines.
func _jinks(rng: RandomNumberGenerator, C: PackedColorArray) -> void:
	var dt := 1.0 / 120.0
	for j in 16:
		var a := rng.randf_range(-1.2, 1.2) + (0.0 if rng.randf() < 0.7 else PI)
		var sp := rng.randf_range(130, 250)
		var s := {"x": 0.0, "y": 0.0, "vx": cos(a) * sp, "vy": sin(a) * sp - 40.0, "life": rng.randf_range(0.2, 0.36),
			"age": -SNAP, "next": rng.randf_range(0.02, 0.05), "trail": []}
		var tail := line("Jink%d" % j, PackedVector2Array(), {"color": C[5]})
		var tip := line("JinkHead%d" % j, PackedVector2Array(), {"color": Color.WHITE})
		var tail_keys := []
		var tip_keys := []
		var tail_col := []
		var tip_col := []
		var t := 0.0
		var frame := 0
		var steps := 0
		while frame < 28:
			if steps % 4 == 0:
				var at := maxf(0.0, frame / FPS - 0.5 / FPS)
				var live: bool = s.age >= 0.0 and s.age < s.life
				var path: Array = s.trail.duplicate()
				path.append(Vector2(s.x, s.y))
				var k: float = 1.0 - s.age / s.life
				if live:
					var pts := PackedVector2Array()
					for q in path.slice(0, path.size() - 1):
						pts.append((q as Vector2).floor() + Vector2(0.5, 0.5))
					var hp := PackedVector2Array([(path[-2] as Vector2).floor() + Vector2(0.5, 0.5) if path.size() > 1 else Vector2(s.x, s.y), Vector2(s.x, s.y).floor() + Vector2(0.5, 0.5)])
					tail_keys.append([at, pts if pts.size() > 1 else PackedVector2Array()])
					tip_keys.append([at, hp])
					tail_col.append([at, C[5] if k > 0.5 else C[4]])
					tip_col.append([at, Color.WHITE if k > 0.5 else C[6]])
				else:
					tail_keys.append([at, PackedVector2Array()])
					tip_keys.append([at, PackedVector2Array()])
					tail_col.append([at, C[5]])
					tip_col.append([at, Color.WHITE])
				frame += 1
			# the original's update
			t += dt
			steps += 1
			s.age += dt
			if s.age < 0.0 or s.age >= s.life:
				continue
			s.next -= dt
			if s.next <= 0.0:
				s.next = rng.randf_range(0.025, 0.055)
				var spd := Vector2(s.vx, s.vy).length()
				var an := atan2(s.vy, s.vx) + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.6, 1.3)
				s.vx = cos(an) * spd
				s.vy = sin(an) * spd
				s.trail.append(Vector2(s.x, s.y))
				if s.trail.size() > 4:
					s.trail.pop_front()
			s.vx -= s.vx * 3.0 * dt
			s.vy -= s.vy * 3.0 * dt - 140.0 * dt
			s.x += s.vx * dt
			s.y += s.vy * dt
		key(tail, "points", tail_keys, "nearest")
		key(tip, "points", tip_keys, "nearest")
		key(tail, "default_color", tail_col, "nearest")
		key(tip, "default_color", tip_col, "nearest")
