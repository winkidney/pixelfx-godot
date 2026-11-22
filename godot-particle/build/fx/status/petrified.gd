# reimagined-from: src/fx/status/petrified.js@5f7d7600c79fc1497d9702aa7d2f66f9575996c0
# Petrified: Turned to stone: grey creeps up from the feet behind a crackling edge that spits grit, the statue holds, cracks run through it, and it bursts into tumbling chunks and dust.
# one-shot, 3.80 s, 120x74 canvas, origin [60.0, 64.0], backdrop ground, stand-in 2
# ramp palette: #16141c #2a2733 #433f4d #5f5a6a #7d7889 #a29dab #cdc8d2 #f0edf3
# The statue is the effect's own Actor with fx/status/_petrified_body.gdshader: each pixel's stone colour (the
# original's formula, baked here) creeps up from the feet behind a crackling edge, holds, flashes white and is gone.
# The cracks (the original's random walks, replayed with its generator) run through it as a strip of overlays; the
# statue and its cracks shudder before it breaks. Emitters on the original's beats: grit, dust and motes spat off
# the creeping edge (riding it up), a puff of dust as it settles, pebbles dropping off, chips popping out of the
# cracks; then the burst: grit from a fifth of its pixels, shaded tumbling chunks, pale shards, glints, dust rolling
# along the floor and hanging in the air, and dust where chunks land. Lights flare on the settle and the burst.
extends "res://build/fx/status/_status.gd"

const CREEP := 0.95
const CRACK := 1.75
const SHATTER := 2.2
const BURST := 2.21   # the first frame after the white one
const G := 950.0
var C: PackedColorArray
var seed_ := 3


static func tile_noise(x: float, y: float, s: int) -> float:
	var ix := int(floorf(x))
	var iy := int(floorf(y))
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var a := jrand([ix, iy, s])
	var b := jrand([ix + 1, iy, s])
	var c := jrand([ix, iy + 1, s])
	var d := jrand([ix + 1, iy + 1, s])
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


static func fbm2(x: float, y: float, s: int) -> float:
	return (tile_noise(x, y, s) * 0.5 + tile_noise(x * 2.0, y * 2.0, s + 101) * 0.25) / 0.75


static func level(t: float) -> float:
	if t >= CREEP:
		return 1.2
	return 1.2 * smooth(0.0, CREEP, t) + 0.025 * sin(t / CREEP * TAU * 3.0)


func make() -> void:
	C = fit("palette", 8)
	seed_ = int(meta.options.seed)
	var S := shape_of()
	var H := AH
	var R := Rng.new(seed_)
	ground(0.0)

	# ---- the stone, pixel by pixel; the front's noise per column
	var stone := Image.create(AW, AH, false, Image.FORMAT_RGBA8)
	var cols := {}
	for q in S.body:
		var tone := clamp01((luma(col_at(q.x, q.y)) - 0.06) / 0.78)
		var mottle := fbm2(q.x * 0.32, q.y * 0.32, seed_ + 5)
		var i := 1 + int(jround(tone * 4.6 + mottle * 1.1))
		if not on(q.x - 1, q.y) or not on(q.x, q.y - 1):
			i += 1
		elif not on(q.x + 1, q.y) or not on(q.x, q.y + 1):
			i -= 1
		stone.set_pixel(q.x, q.y, C[clampi(i, 1, 6)])
		cols[q] = C[clampi(i, 1, 6)]
	var wob := PackedFloat32Array()
	for x in 24:
		wob.append(0.06 * fbm2(x * 0.4, 0.5, seed_))

	# ---- the cracks: random walks from a point on the chest
	var cracks := []
	var ox := int(jround(AW * 0.55))
	var oy := int(jround(H * 0.42))
	for i in 7:
		_walk(R, cracks, float(ox), float(oy), i / 7.0 * TAU + R.range(-0.3, 0.3), 14.0)

	# ---- the statue
	var body := actor_node()
	var m := ShaderMaterial.new()
	m.shader = load(STATUS + "_petrified_body.gdshader")
	m.set_shader_parameter("stone", asset("_stone", stone))
	m.set_shader_parameter("wobble", wob)
	m.set_shader_parameter("c5", C[5])
	m.set_shader_parameter("c6", C[6])
	m.set_shader_parameter("c7", C[7])
	body.material = m
	var times := frame_times()
	var K := {"lv": [], "cr": [], "fl": [], "wh": [], "vis": [], "pos": []}
	for t in times:
		K.lv.append([t, level(t)])
		K.cr.append([t, t < CREEP])
		K.fl.append([t, floorf(t * 24.0)])
		var sh := 0.0
		if t >= CRACK and t < SHATTER:
			sh = jround(sin(t * 90.0) * minf(1.0, (t - CRACK) / (SHATTER - CRACK)) * 1.2)
		K.pos.append([t, Vector2(sh, 0)])
	key(body, "material:shader_parameter/level", K.lv, "linear")
	key(body, "material:shader_parameter/creeping", K.cr, "nearest")
	key(body, "material:shader_parameter/flick", K.fl, "nearest")
	key(body, "material:shader_parameter/white", [[0.0, false], [SHATTER - 0.03, true], [BURST, false]], "nearest")
	key(body, "visible", [[0.0, true], [BURST, false]], "nearest")
	key(body, "position", K.pos, "nearest")
	# light along the creeping front
	var front := glow("FrontLight", 16, {"radius": 13.0, "squash": 0.4, "color": C[6], "alpha": 0.3})
	var fp := []
	for t in times:
		fp.append([t, Vector2(0, AY + H * (1.0 - minf(1.0, level(t))))])
	key(front, "position", fp, "linear")
	key(front, "material:shader_parameter/alpha", [[0.0, 0.3], [CREEP, 0.0]], "nearest")

	# ---- the cracks running through it, fresh tips white, a strip of overlays
	var imgs := []
	var cf := []
	var last := -1
	for t in times:
		if t < CRACK or t >= BURST:
			continue
		var k := clamp01((t - CRACK) / 0.3)
		if imgs.size() and k >= 1.0 and last >= 0:
			cf.append([t, last])
			continue
		var img := Image.create(AW + 2, AH + 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for pts in cracks:
			var n := int(floorf(pts.size() * k))
			for i in n:
				var px := int(floorf(pts[i].x)) + 1
				var py := int(floorf(pts[i].y)) + 1
				var fresh := i > n - 3
				img.set_pixel(px, py, WHITE if fresh else C[0])
				if not fresh:
					img.set_pixel(px, py - 1, C[6])
		last = imgs.size()
		imgs.append(img)
		cf.append([t, last])
	var strip := Image.create((AW + 2) * imgs.size(), AH + 2, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		strip.blit_rect(imgs[i], Rect2i(0, 0, AW + 2, AH + 2), Vector2i(i * (AW + 2), 0))
	keep_image_colours(strip)
	var ov := sprite("Cracks", asset("_cracks", strip), {"centered": false, "hframes": imgs.size(), "at": Vector2(AX - 1, AY - 1)})
	ov.offset = Vector2.ZERO
	show(ov, CRACK, BURST)
	key(ov, "frame", cf, "nearest")
	var cp := []
	for k2 in K.pos:
		cp.append([k2[0], Vector2(AX - 1, AY - 1) + k2[1]])
	key(ov, "position", cp, "nearest")
	var cg := glow("CrackLight", 14, {"radius": 12.0, "color": C[6], "alpha": 0.0}, {"at": apos(ox, oy)})
	key(cg, "material:shader_parameter/alpha", [[0.0, 0.0], [CRACK, 0.0], [CRACK + 0.3, 0.25], [SHATTER, 0.25], [BURST, 0.0]], "linear")

	# ---- the creeping edge spits grit, dust and the odd mote (riding the front up)
	var grit_cols := gradient([C[4], C[5], C[6]])
	for sd in [-1, 1]:
		var g := group("Edge%d" % (sd + 1))
		var ep := []
		for t in times:
			if t > CREEP:
				break
			var y := AY + H * (1.0 - clampf(level(t), 0.0, 1.0)) + 0.5
			ep.append([t, Vector2(sd * 5.0, y)])
		key(g, "position", ep, "linear")
		var gr := particles("EdgeGrit%d" % (sd + 1), {"parent": g, "amount": 4, "lifetime": 0.85, "life_random": 0.3, "texture": "dot1",
			"emit": {"box": Vector2(4, 1)}, "dir": -90 + sd * 25, "spread": 22, "speed": [40, 100], "gravity": Vector2(0, G), "drag": 0.8,
			"initial": grit_cols, "collide": {"bounce": 0.0, "friction": 1.0}, "alpha_curve": [[0, 1], [0.85, 1], [0.86, 0], [1, 0]]})
		emit(gr, 0.0, CREEP)
		var du := particles("EdgeDust%d" % (sd + 1), {"parent": g, "layer": "soft", "amount": 2, "lifetime": 0.55, "texture": "disc5",
			"emit": {"box": Vector2(4, 1)}, "dir": -90 + sd * 60, "spread": 20, "speed": [10, 30], "drag": 4.0, "color": C[4],
			"scale_curve": [[0, 0.7], [1, 1.2]], "alpha_curve": [[0, 0.7], [1, 0.0]]})
		emit(du, 0.0, CREEP)
		var mo := particles("EdgeMote%d" % (sd + 1), {"parent": g, "amount": 1, "lifetime": 0.22, "texture": "streak3", "align": true,
			"emit": {"box": Vector2(4, 1)}, "dir": -90 + sd * 45, "spread": 20, "speed": [50, 110], "drag": 0.6, "color": C[7],
			"alpha_curve": [[0, 1], [1, 0.3]]})
		emit(mo, 0.0, CREEP)
		g.z_index = 1

	# ---- it settles: light flares, dust rolls out round the feet
	_flash("SettleLight", Vector2(0, AY + H * 0.5), 34, C[6], 0.35, CREEP, 0.3)
	var sdust := particles("SettleDust", {"layer": "soft", "back": true, "at": Vector2(0, -1), "amount": 8, "lifetime": 0.8, "life_random": 0.4,
		"one_shot": true, "explosiveness": 1.0, "texture": "disc7", "emit": {"box": Vector2(8, 1)}, "dir": 180, "spread": 180,
		"speed": [20, 50], "drag": 4.0, "color": C[3], "scale_curve": [[0, 0.5], [1, 1.0]], "alpha_curve": [[0, 0.7], [1, 0.0]]})
	_lock_y(sdust)
	emit(sdust, CREEP)

	# ---- while it holds, a pebble or two drops off; the cracks pop chips as they run
	var bottoms := PackedVector2Array()
	for q in S.body:
		if not on(q.x, q.y + 1) and q.y < H - 2:
			bottoms.append(apos(q.x + 0.5, q.y + 1))
	var peb := particles("Pebbles", {"amount": 2, "lifetime": 1.0, "texture": "dot1", "emit": {"points": bottoms}, "dir": 90, "spread": 60,
		"speed": [0, 8], "gravity": Vector2(0, G), "drag": 0.8, "color": C[3], "collide": {"bounce": 0.0, "friction": 1.0}})
	emit(peb, CREEP + 0.2, SHATTER)
	var crackpts := PackedVector2Array()
	for pts in cracks:
		for p in pts:
			crackpts.append(apos(p.x, p.y))
	var chips := particles("Chips", {"amount": 5, "lifetime": 0.7, "life_random": 0.4, "texture": "dot1", "emit": {"points": crackpts},
		"dir": -90, "spread": 35, "speed": [35, 85], "gravity": Vector2(0, G), "drag": 0.8, "initial": gradient([C[5], C[6]]),
		"collide": {"bounce": 0.0, "friction": 1.0}, "alpha_curve": [[0, 1], [0.85, 1], [0.86, 0], [1, 0]]})
	emit(chips, CRACK, SHATTER)

	# ---- the burst
	_flash("BurstLight", Vector2(0, AY + H * 0.45), 46, C[6], 0.7, BURST, 0.5)
	_flash("BurstWhite", Vector2(0, AY + H * 0.45), 30, WHITE, 0.7, BURST, 0.12)
	var cx := apos(ox, oy)
	var small := PackedVector2Array()
	var big := PackedVector2Array()
	var all := PackedVector2Array()
	for q in S.body:
		all.append(apos(q.x + 0.5, q.y + 0.5))
		if jrand([q.x, q.y, 9]) > 0.22:
			continue
		if jrand([q.x, q.y, 4]) < 0.35:
			big.append(apos(q.x + 0.5, q.y + 0.5))
		else:
			small.append(apos(q.x + 0.5, q.y + 0.5))
	var stone_cols := gradient([C[2], C[3], C[4], C[5], C[3], C[6], C[4]])
	var gi := 0
	for pts in [small, big]:
		var bg := particles("BurstGrit%d" % gi, {"amount": pts.size(), "lifetime": 1.4, "life_random": 0.35, "one_shot": true, "explosiveness": 1.0,
			"texture": "dot1" if gi == 0 else "dot2", "emit": {"points": pts}, "dir": -90, "spread": 10, "speed": [40, 140],
			"gravity": Vector2(0, G), "drag": 0.8, "initial": stone_cols, "collide": {"bounce": 0.25, "friction": 1.0},
			"alpha_curve": [[0, 1], [0.87, 1], [0.88, 0], [1, 0]]})
		_radial(bg, cx, 40.0, 130.0)
		emit(bg, BURST)
		gi += 1
	# chunks: shaded, tumbling, bouncing once
	for ci in 3:
		var s: float = [1.4, 2.0, 2.6][ci]
		var ch := particles("Chunks%d" % ci, {"amount": 6, "lifetime": 1.5, "life_random": 0.27, "one_shot": true, "explosiveness": 1.0,
			"texture": asset("_chunk%d" % ci, _chunk(s)), "emit": {"points": all}, "dir": -90, "spread": 15, "speed": [60, 160],
			"gravity": Vector2(0, G), "drag": 0.4, "angle": [0, 360], "spin": [-800, 800],
			"collide": {"bounce": 0.3, "friction": 0.9, "size": s * 0.6}, "alpha_curve": [[0, 1], [0.75, 1], [1, 0]]})
		_radial(ch, cx, 35.0, 110.0)
		emit(ch, BURST)
	# pale shards of its skin
	var shard := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	shard.set_pixel(0, 0, C[6])
	shard.set_pixel(1, 0, C[6])
	shard.set_pixel(2, 0, WHITE)
	var shd := particles("Shards", {"at": cx, "amount": 16, "lifetime": 1.4, "life_random": 0.35, "one_shot": true, "explosiveness": 1.0,
		"texture": asset("_shard", shard), "emit": {"box": Vector2(5, 8)}, "dir": -90, "spread": 80, "speed": [50, 120],
		"gravity": Vector2(0, G * 0.8), "drag": 0.6, "angle": [0, 360], "spin": [-1000, 1000], "initial": gradient([C[5], C[6], C[7]]),
		"collide": {"bounce": 0.3, "friction": 0.9}, "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	emit(shd, BURST)
	keep_colour(WHITE)
	# glints in the dust
	var stars := particles("Glints", {"at": cx + Vector2(0, 2), "amount": 6, "lifetime": 0.7, "one_shot": true, "explosiveness": 0.5,
		"texture": "star5", "emit": {"box": Vector2(12, 12)}, "dir": -90, "spread": 60, "speed": [5, 20], "color": C[6],
		"alpha_curve": [[0, 1], [0.2, 0.6], [0.4, 1], [0.6, 0.6], [0.8, 1], [1, 0]]})
	emit(stars, BURST + 0.05)
	twin(stars, {"modulate": Color(C[6], 0.4), "texture": "glow8"})
	# dust rolling along the floor and hanging in the air
	var fd := particles("FloorDust", {"layer": "soft", "at": Vector2(0, -3), "amount": 12, "lifetime": 1.4, "life_random": 0.35, "one_shot": true,
		"explosiveness": 0.95, "texture": "disc9", "emit": {"box": Vector2(8, 3)}, "dir": 180, "spread": 180, "speed": [20, 60], "drag": 1.6,
		"gravity": Vector2(0, -20), "ramp": gradient([C[4], C[3], C[2]]), "scale_curve": [[0, 0.55], [0.4, 0.85], [1, 1.0]],
		"alpha_curve": [[0, 0.0], [0.08, 0.55], [0.6, 0.35], [1, 0.0]]})
	_lock_y(fd)
	(fd.process_material as ParticleProcessMaterial).direction = Vector3(-1, -0.15, 0)
	emit(fd, BURST)
	var ad := particles("AirDust", {"layer": "soft", "at": Vector2(0, AY + H * 0.55), "amount": 6, "lifetime": 1.5, "life_random": 0.3,
		"one_shot": true, "explosiveness": 0.95, "texture": "disc9", "emit": {"box": Vector2(6, 9)}, "dir": -90, "spread": 60,
		"speed": [10, 30], "drag": 1.4, "gravity": Vector2(0, -10), "ramp": gradient([C[3], C[2]]),
		"scale_curve": [[0, 0.7], [1, 1.1]], "alpha_curve": [[0, 0.0], [0.08, 0.55], [0.6, 0.35], [1, 0.0]]})
	emit(ad, BURST)
	# dust where the chunks come down
	var ld := particles("LandDust", {"layer": "soft", "at": Vector2(0, -1), "amount": 5, "lifetime": 0.5, "texture": "disc5",
		"emit": {"box": Vector2(22, 0.5)}, "dir": -90, "spread": 70, "speed": [4, 18], "drag": 4.0, "color": C[3],
		"scale_curve": [[0, 0.8], [1, 1.3]], "alpha_curve": [[0, 0.7], [1, 0.0]]})
	emit(ld, BURST + 0.25, BURST + 0.9)


## A light that flares and dies (the original's Lights): radius r (0.55 + 0.45 k), alpha a k^2 over life seconds.
func _flash(name: String, at: Vector2, r: float, col: Color, a: float, t0: float, life: float) -> void:
	var g := glow(name, r + 2, {"radius": r, "color": col, "alpha": 0.0}, {"at": at})
	var ra := [[0.0, r]]
	var al := [[0.0, 0.0], [t0 - 0.002, 0.0]]
	for i in 13:
		var u := i / 12.0
		var k := 1.0 - u
		ra.append([t0 + u * life, r * (0.55 + 0.45 * k)])
		al.append([t0 + u * life, a * k * k])
	key(g, "material:shader_parameter/radius", ra)
	key(g, "material:shader_parameter/alpha", al)


## Out from the chest (velocity_pivot), on top of the emitter's own upward speed.
func _radial(p: GPUParticles2D, pivot: Vector2, lo: float, hi: float) -> void:
	var m: ParticleProcessMaterial = p.process_material
	m.radial_velocity_min = lo
	m.radial_velocity_max = hi
	m.velocity_pivot = Vector3(pivot.x - p.position.x, pivot.y - p.position.y, 0)


## Dust that rolls along the floor: no vertical speed from its direction.
func _lock_y(p: GPUParticles2D) -> void:
	var m: ParticleProcessMaterial = p.process_material
	m.spread = 0.0
	m.direction = Vector3(-1, 0, 0)
	m.initial_velocity_min = -m.initial_velocity_max


## A shaded chunk (the original's Bits CHUNK at angle 0): lit top-left, dark bottom-right, a dark rim.
func _chunk(s: float) -> Image:
	var r := int(ceilf(s)) + 1
	var n := 2 * r + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var Rr := [C[0], C[2], C[3], C[5], C[6]]
	for py in range(-r, r + 1):
		for px in range(-r, r + 1):
			var u := px + 0.5
			var v := py + 0.5
			var d := absf(u) / s + absf(v) / (s * 0.62)
			if d > 1.3:
				continue
			var c: Color = Rr[0] if d > 1.0 else (((Rr[4] if u < 0 else Rr[3])) if v < 0 else (Rr[2] if u < 0 else Rr[1]))
			img.set_pixel(px + r, py + r, c)
			keep_colour(c)
	return img


func _walk(R: Rng, cracks: Array, x: float, y: float, ang: float, length: float) -> void:
	var pts := [Vector2(x, y)]
	var s := 0
	while s < length:
		ang += R.range(-0.55, 0.55)
		x += cos(ang) * R.range(1.4, 2.4)
		y += sin(ang) * R.range(1.4, 2.4)
		if not on(int(floorf(x)), int(floorf(y))):
			break
		pts.append(Vector2(x, y))
		if pts.size() > 3 and cracks.size() < 16 and R.chance(0.14):
			_walk(R, cracks, x, y, ang + R.sgn() * R.range(0.6, 1.2), length / 2.0)
		s += 1
	cracks.append(pts)
