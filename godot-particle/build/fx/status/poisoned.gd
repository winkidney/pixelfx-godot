# reimagined-from: src/fx/status/poisoned.js@8ea6920947faa3e5ad16305817dffdb51e6e1671
# Poisoned: Sick to the bone: green rolls up the body in waves, dark veins creep from a wound, toxic sweat drips and hisses; every 0.8 s it wobbles, blisters pop and a ring pulses out.
# loop, 1.60 s, 72x64 canvas, origin [36.0, 54.0], backdrop ground, stand-in 2
# ramp palette: #0e1d14 #173320 #23552e #318232 #55b92f #8eea3f #cfff63 #f6ffc2
# The sick body is the effect's own Actor (its texture padded so rows can sway) with fx/status/_poisoned_body.gdshader:
# the sway and the tick's wobble, green rolling up it in waves, veins creeping from the wound (the original's walks,
# replayed with its generator), blisters swelling and popping (their spray: one-shot emitters). Sweat beads gather,
# fall and hiss (fx/status/_poisoned_sweat.gdshader, one rect per spot); a ring pulses out on the floor on each
# tick (_poisoned_ring.gdshader, the far half behind the body); sick light pools on the floor and the body.
extends "res://build/fx/status/_status.gd"

const TICK := 0.8
const MARGIN := 2


func make() -> void:
	var D: float = root.duration
	var P := fit("palette", 8)
	var S := shape_of()
	var H := AH
	var W := AW
	var seed_: int = int(meta.options.seed)
	var R := Rng.new(seed_ * 7 + 3)

	# ---- the original's plan: veins walking out from a wound on the forearm, blisters, sweat spots
	var row: Array = S.rows[int(jround(H * 0.6))]
	var wx: int = row[1] - 1
	var wy := int(jround(H * 0.6))
	var data := Image.create(W, H, false, Image.FORMAT_RGBA8)
	data.fill(Color(1, 0, 0, 1))
	_walk(R, data, float(wx), float(wy), PI + (0 / 4.0 - 0.45) * 2.2, 11.0, 0)
	_walk(R, data, float(wx), float(wy), PI + (1 / 4.0 - 0.45) * 2.2, 11.0, 0)
	_walk(R, data, float(wx), float(wy), PI + (2 / 4.0 - 0.45) * 2.2, 11.0, 0)
	_walk(R, data, float(wx), float(wy), PI + (3 / 4.0 - 0.45) * 2.2, 11.0, 0)
	var px := data.get_pixel(wx, wy)
	data.set_pixel(wx, wy, Color(px.r, 1.0, 0, 1))
	px = data.get_pixel(wx - 1, wy)
	data.set_pixel(wx - 1, wy, Color(px.r, 0.5, 0, 1))
	var cand := []
	for q in S.body:
		if q.y > 4 and on(q.x - 1, q.y) and on(q.x + 1, q.y) and on(q.x, q.y - 1):
			cand.append(q)
	var blisters := []
	for tick in 2:
		for k in 3:
			var q: Vector2i = cand[int(floorf(R.next() * cand.size()))]
			blisters.append(Vector3(q.x, q.y, R.range(1.1, 1.8)))
	var sweat := []
	for e in eyes():
		sweat.append(Vector2(e.x0 - 1 if e.x0 < W / 2.0 else e.x1 + 1, e.y0 - 1))
	for sd in [-1, 1]:
		for q in S.body:
			if q.y > H * 0.5 and q.y < H * 0.7 and (q.x <= row[0] + 1 if sd < 0 else q.x >= row[1] - 1) and not on(q.x, q.y + 1):
				sweat.append(Vector2(q))
				break

	# ---- the floor: sick light, the far half of the ring
	var floor_l := glow("FloorLight", 26, {"radius": 24.0, "squash": 4.0 / 24.0, "color": P[4], "alpha": 0.14}, {"at": Vector2(0, 0.5)})
	sample(floor_l, "material:shader_parameter/alpha", func(t: float) -> float: return 0.14 + 0.2 * exp(-fposmod(t, TICK) / 0.2), "linear")
	var rings := []
	for sd in [1.0, -1.0]:
		rings.append(shape("RingFar" if sd > 0 else "RingNear", load(STATUS + "_poisoned_ring.gdshader"), Vector2(60, 14),
			{"side": sd, "squash": 0.18, "c3": P[3], "c4": P[4], "c5": P[5], "c6": P[6]}, {"at": Vector2(0, 0), "back": sd > 0}))
	for rn in rings:
		sample(rn, "material:shader_parameter/radius", func(t: float) -> float: return 5.0 + 22.0 * sqrt(minf(1.0, fposmod(t, TICK) / 0.55)))
		sample(rn, "material:shader_parameter/thickness", func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - fposmod(t, TICK) / 0.55)))
		sample(rn, "material:shader_parameter/alpha", func(t: float) -> float: return maxf(0.0, 1.0 - fposmod(t, TICK) / 0.55))

	# ---- the body
	var body := actor_node()
	var padded := Image.create(W + 2 * MARGIN, H, false, Image.FORMAT_RGBA8)
	padded.fill(Color(0, 0, 0, 0))
	padded.blit_rect(_img, Rect2i(0, 0, W, H), Vector2i(MARGIN, 0))
	body.texture = asset("_body", padded)
	body.offset = Vector2(AX - MARGIN, AY)
	var m := ShaderMaterial.new()
	m.shader = load(STATUS + "_poisoned_body.gdshader")
	m.set_shader_parameter("ramp", P)
	m.set_shader_parameter("vein", Color(meta.options.veins))
	m.set_shader_parameter("data", asset("_veins", data))
	m.set_shader_parameter("margin", float(MARGIN))
	for i in 6:
		m.set_shader_parameter("b%d" % i, blisters[i])
	body.material = m
	loop_t(body, "tw")
	glow("WoundLight", 8, {"radius": 6.0, "color": P[5], "alpha": 0.3}, {"at": apos(wx, wy)})

	# blisters pop: a spray of six flecks
	var i := 0
	for b in blisters:
		var pop := particles("Pop%d" % i, {"at": apos(b.x, b.y), "amount": 6, "lifetime": 0.18, "one_shot": true, "explosiveness": 1.0,
			"texture": "dot1", "emit": {"ring": [b.z + 0.5, b.z + 0.5]}, "radial_speed": [19, 20], "gravity": Vector2(0, -20),
			"initial": gradient([P[5], P[6]]), "alpha_curve": [[0, 1], [1, 0.3]], "preprocess": 0.0})
		emit(pop, (i / 3) * TICK + 0.38)
		i += 1

	# ---- toxic sweat
	i = 0
	for s in sweat:
		var sw := shape("Sweat%d" % i, load(STATUS + "_poisoned_sweat.gdshader"), Vector2(44, 46),
			{"spot": s, "lag": i * 0.37, "top_left": Vector2(-22, -43), "c4": P[4], "c5": P[5], "c6": P[6]}, {"at": Vector2(0, -20)})
		loop_t(sw, "tw")
		i += 1

	# ---- a sick light on the body, surging with the tick
	var sick := glow("SickLight", 28, {"radius": 26.0, "color": P[4], "alpha": 0.14}, {"at": Vector2(0, AY + H * 0.45)})
	sample(sick, "material:shader_parameter/alpha", func(t: float) -> float: return 0.14 + 0.2 * exp(-fposmod(t, TICK) / 0.18), "linear")


func _walk(R: Rng, data: Image, x: float, y: float, ang: float, length: float, depth: int) -> void:
	var s := 0
	while s < length:
		ang += R.range(-0.5, 0.5)
		x += cos(ang)
		y += sin(ang)
		var X := int(jround(x))
		var Y := int(jround(y))
		if not on(X, Y):
			break
		var u := s / length
		if u < data.get_pixel(X, Y).r:
			data.set_pixel(X, Y, Color(u, 0, 0, 1))
		if depth < 2 and s > 2 and R.chance(0.16):
			_walk(R, data, x, y, ang + R.sgn() * R.range(0.6, 1.1), length * 0.55, depth + 1)
		s += 1
