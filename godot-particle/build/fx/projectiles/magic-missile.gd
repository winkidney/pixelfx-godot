# reimagined-from: src/fx/projectiles/magic-missile.js@f82a9e8405efda2e78f2288d3cb6a5480dca3256
# Magic missile: Motes gather into an arcane orb at a hand `height` px above the floor (the origin); it weaves to its target trailing a twisting ribbon and bursts into a star of light.
# one-shot, 1.90 s, 208x112 canvas, origin [24.0, 104.0], backdrop ground
# The original's simulation is replayed in the build script (its 120 Hz steps and its own random draws): the orb
# (fx/projectiles/_magic-missile_orb: rim, body, white heart, three sparks turning round it) gathers at the hand and
# weaves along the original's path, keyed every frame; the ribbon trailing it is a shader fed the last 0.32 s of
# that path (_magic-missile_ribbon: twisting, its bright face and dark back taking turns, thinning and dithering out),
# with a run of small lights along it. The motes spiralling in, the motes and stars it sheds, and the burst's motes,
# stars and sparks are GPU particles: each spawn the original made becomes a particle (a data texture of when, where,
# how fast, how long, what colour) moved by its own physics in a particle process shader (_magic-missile_sim) and
# drawn as it draws them (two-tone streaks: _magic-missile_streak, twinkling sparkles: _magic-missile_star), each
# kind with a light twin. The burst: an eight-ray flare, a white disc, a ring opening out, a sparkle, two lights.
extends "res://build/fx/projectiles/_projectiles.gd"

const CHARGE := 0.2
const FLY := 0.62
const STEP := (1.0 / 30.0) / 4.0

var C: PackedColorArray
var H := 26.0
var X1 := 112.0
## kind (0 mote, 1 star, 2 spark) -> [{ts, x, y, vx, vy, life, col, size, seed, delay}]
var spawns := {0: [], 1: [], 2: []}
## [x, y, t] every step of the flight
var trail := []
var t_burst := 0.0


func pos(u: float) -> Vector2:
	return Vector2(X1 * in_out_sine(u) + sin(u * PI) * 6.0, -H + sin(u * TAU * 1.5) * 9.0 * sin(u * PI))


func spawn(R: Rng, kind: int, x: float, y: float, vx: float, vy: float, life: float, col: Color, size: float, delay: float, t: float) -> void:
	# the step it's born in already moves it once: count it from a step before
	spawns[kind].append({"ts": t - STEP, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "col": col, "size": size,
		"seed": R.next() * 100.0, "delay": delay})


## The original's update(), step by step: the same draws from its Rng in the same order.
func simulate() -> void:
	var R := Rng.new(int(meta.options.seed))
	var W := Color.WHITE
	var t := 0.0
	var burst := false
	for step in int(ceilf(root.duration * 120.0)) + 1:
		t += STEP
		if t < CHARGE:
			if R.chance(0.8):
				var a := R.range(0, TAU)
				var d := R.range(12, 26)
				var sp := d / 0.14
				var col: Color = R.pick([C[5], C[6], W])
				spawn(R, 0, cos(a) * d, -H + sin(a) * d, -cos(a) * sp - sin(a) * sp * 0.5, -sin(a) * sp + cos(a) * sp * 0.5, 0.14, col, 0.8, 0.0, t)
		elif t < CHARGE + FLY:
			var p := pos((t - CHARGE) / FLY)
			trail.append([p.x, p.y, t])
			if R.chance(0.6):
				var vx := R.range(-50, 50)
				var vy := R.range(-50, 50)
				var life := R.range(0.2, 0.4)
				var col: Color = R.pick([C[4], C[5], C[6]])
				spawn(R, 0, p.x, p.y, vx, vy, life, col, 0.7, 0.0, t)
			if R.chance(0.25):
				var x := p.x + R.range(-3, 3)
				var y := p.y + R.range(-3, 3)
				var vx := R.range(-10, 10)
				var vy := R.range(-10, 10)
				var life := R.range(0.25, 0.5)
				spawn(R, 1, x, y, vx, vy, life, C[6], R.range(0.6, 1.6), 0.0, t)
		elif not burst:
			burst = true
			t_burst = t
			var y := -H
			for i in 26:
				var a := R.range(0, TAU)
				var sp := R.range(60, 150) * (1.0 - 0.65 * maxf(0.0, sin(a)))
				var life := R.range(0.25, 0.45)
				var col: Color = R.pick([C[5], C[6], W])
				spawn(R, 0 if i % 3 else 1, X1, y, cos(a) * sp, sin(a) * sp, life, col, R.range(0.8, 1.8), 0.0, t)
			for i in 18:
				var a := R.range(0, TAU)
				var sp := R.range(110, 240) * (1.0 - 0.5 * maxf(0.0, sin(a)))
				spawn(R, 2, X1, y, cos(a) * sp, sin(a) * sp - 30.0, R.range(0.12, 0.3), W, 1.0, 0.0, t)
			for i in 14:
				var a := R.range(0, TAU)
				var d := R.range(4, 22)
				var vy := -R.range(2, 8)
				var life := R.range(0.5, 1.1)
				var col: Color = R.pick([C[6], W, C[5]])
				var size := R.range(0.8, 2.6)
				spawn(R, 1, X1 + cos(a) * d, y + sin(a) * d * 0.8, 0.0, vy, life, col, size, R.range(0.05, 0.45), t)


## One kind of the original's particles: an emitter whose particles replay its spawns, and its light twin.
func replay(name: String, kind: int, look: Shader, tex: String, look_params: Dictionary = {}) -> void:
	var list: Array = spawns[kind]
	var img := Image.create(3, list.size(), false, Image.FORMAT_RGBAF)
	for i in list.size():
		var q: Dictionary = list[i]
		img.set_pixel(0, i, Color(q.ts, q.x, q.y, q.life))
		img.set_pixel(1, i, Color(q.vx, q.vy, q.size, q.seed))
		var c: Color = q.col
		img.set_pixel(2, i, Color(c.r, c.g, c.b, q.delay))
		keep_colour(c)
		if kind == 0:
			keep_colour(Color(c.r * 0.55, c.g * 0.55, c.b * 0.55))
		elif kind == 1:
			keep_colour(Color(c.r * 0.75, c.g * 0.75, c.b * 0.75))
	var data := asset(name.to_snake_case() + "_spawns", img)
	var S := [Color.WHITE, C[6], C[5], C[4]]
	for lit in [false, true]:
		var p := particles(name + ("Light" if lit else ""), {"amount": list.size(), "lifetime": root.duration, "one_shot": true,
			"explosiveness": 1.0, "local": true, "texture": "glow16" if lit else tex, "layer": "light" if lit else "color"})
		var pm := ShaderMaterial.new()
		pm.shader = pshader("magic-missile_sim")
		pm.set_shader_parameter("data", data)
		pm.set_shader_parameter("kind", kind)
		pm.set_shader_parameter("glow", 1.0 if lit else 0.0)
		pm.set_shader_parameter("tex_size", 16.0 if lit else 8.0)
		for j in 3:
			pm.set_shader_parameter("s%d" % j, S[j])
		p.process_material = pm
		if not lit:
			var m := ShaderMaterial.new()
			m.shader = look
			for k in look_params:
				m.set_shader_parameter(k, look_params[k])
			p.material = m


func make() -> void:
	C = pal("palette")
	H = meta.options.height
	X1 = meta.options.reach
	var D: float = root.duration
	simulate()
	var TB := CHARGE + FLY

	# the ribbon, and its light
	var rib := shape("Ribbon", pshader("magic-missile_ribbon"), Vector2(150, 50), {"c2": C[2], "c4": C[4], "c5": C[5], "c6": C[6],
		"count": 0.0, "now": 0.0}, {"at": Vector2(58, -24)})
	var ribl := shape("RibbonLight", pshader("magic-missile_ribbon_light"), Vector2(150, 50), {"color": C[4], "count": 0.0, "now": 0.0},
		{"at": Vector2(58, -24)})
	var pk := []
	var ck := []
	var nk := []
	var nf := int(ceilf(D * FPS))
	for f in nf + 1:
		var now := f * 4 * STEP
		var keep := PackedVector4Array()
		for q in trail:
			if q[2] <= now + 1e-9 and now - q[2] < 0.32:
				keep.append(Vector4(q[0], q[1], q[2], 0.0))
		var n := keep.size()
		while keep.size() < 48:
			keep.append(Vector4.ZERO)
		var at := maxf(0.0, f / FPS - 0.002) if f > 0 else 0.0
		pk.append([at, keep])
		ck.append([at, float(mini(n, 48))])
		nk.append([at, now])
	for node in [rib, ribl]:
		key(node, "material:shader_parameter/pts", pk, "nearest")
		key(node, "material:shader_parameter/count", ck, "nearest")
		key(node, "material:shader_parameter/now", nk, "nearest")
	show(rib, CHARGE, TB + 0.34)
	show(ribl, CHARGE, TB + 0.34)

	# the particles: motes, stars, sparks
	var S := [Color.WHITE, C[6], C[5], C[4]]
	replay("Motes", 0, pshader("magic-missile_streak"), "streak8", {"kind": 0})
	replay("Stars", 1, pshader("magic-missile_star"), "disc9")
	replay("Sparks", 2, pshader("magic-missile_streak"), "streak8", {"kind": 2, "s0": S[0], "s1": S[1], "s2": S[2], "s3": S[3]})

	# the orb: gathering at the hand, then flying
	var orb_at := func(t: float) -> Vector2: return Vector2(0, -H) if t < CHARGE else pos((t - CHARGE) / FLY)
	var orb_k := func(t: float) -> float: return t / CHARGE if t < CHARGE else 1.0
	var orb := shape("Orb", pshader("magic-missile_orb"), Vector2(150, 50), {"rim": C[3], "body": C[5], "spark": C[6], "r": 1.0},
		{"at": Vector2(58, -24)})
	keyf(orb, "material:shader_parameter/pos", orb_at, 0.0, TB)
	keyf(orb, "material:shader_parameter/r", func(t: float) -> float: return 1.0 + 3.0 * out_back(orb_k.call(t)), 0.0, TB)
	key(orb, "material:shader_parameter/ang", [[0.0, 0.0], [TB, TB * 14.0]])
	show(orb, 0.0, TB)
	for L in [["OrbLight", 20.0, C[4], 0.65], ["OrbHot", 7.0, C[6], 0.5]]:
		var gl := light_at(L[0], Vector2(0, -H), L[1], L[2], 0.0)
		var k0: float = L[3]
		keyf(gl, "position", orb_at, 0.0, TB)
		keyf(gl, "material:shader_parameter/alpha", func(t: float) -> float: return k0 * orb_k.call(t) if t < TB else 0.0, 0.0, TB + 0.04)

	# the burst: a star flare and a ring that open out and fade, a white disc, a sparkle
	var at := Vector2(X1, -H)
	# light keys start on the frame before the burst, so the first frame of it is a key of its own
	var T0 := floorf(TB * FPS) / FPS
	var e := func(t: float) -> float: return (t - TB) / 0.5
	var fl := flare8("Flare", at, 28, 1.0, C)
	keyf(fl, "material:shader_parameter/len", func(t: float) -> float: return 26.0 * pow(maxf(0.0, 1.0 - e.call(t) * 2.0), 1.2) + 2.0, TB, TB + 0.25)
	keyf(fl, "material:shader_parameter/k", func(t: float) -> float: return 1.0 - e.call(t) * 2.0, TB, TB + 0.25)
	show(fl, TB, TB + 0.25)
	var disc := ring("Pop", 9, {"radius": 7, "color": Color.WHITE}, {"at": at})
	keyf(disc, "material:shader_parameter/radius", func(t: float) -> float: return 6.0 * (1.0 - e.call(t) / 0.12) + 1.0, TB, TB + 0.06)
	show(disc, TB, TB + 0.06)
	var rr := ring("Ring", 26, {"radius": 4, "thickness": 2.5, "color": C[6]}, {"at": at})
	keyf(rr, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 20.0 * out_cubic(e.call(t)), TB, TB + 0.5)
	keyf(rr, "material:shader_parameter/thickness", func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - e.call(t))), TB, TB + 0.5)
	keyf(rr, "material:shader_parameter/alpha", func(t: float) -> float: return minf(1.0, (1.0 - e.call(t)) * 1.5), TB, TB + 0.5)
	keyf(rr, "material:shader_parameter/color", func(t: float) -> Color: return C[6] if e.call(t) < 0.3 else C[5], TB, TB + 0.5, 30.0, "nearest")
	show(rr, TB, TB + 0.5)
	var sk := sparkle("Sparkle", at, 7, C[6], C[4])
	var arm := func(t: float) -> float: return roundf(7.0 * (1.0 - e.call(t) / 0.4))
	keyf(sk, "material:shader_parameter/arm", arm, TB, TB + 0.2, 30.0, "nearest")
	show(sk, TB, TB + 0.2)
	var skl := light_at("SparkleLight", at, 18, C[6], 0.0)
	keyf(skl, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + arm.call(t) * 2.0, TB, TB + 0.2, 30.0, "nearest")
	keyf(skl, "material:shader_parameter/alpha", func(t: float) -> float: return 0.6 * (1.0 - e.call(t) / 0.4) if t >= TB and arm.call(t) >= 1.0 else 0.0,
		T0, TB + 0.21, 30.0, "nearest")
	# its lights (the original's Lights: shrinking a little, dying as k^2)
	for L in [["BurstLight", 52.0, C[4], 0.95, 0.55], ["BurstHot", 22.0, Color.WHITE, 0.8, 0.12]]:
		var r0: float = L[1]
		var k0: float = L[3]
		var life: float = L[4]
		var lg := light_at(L[0], at, r0, L[2], 0.0)
		var kk := func(t: float) -> float: return clampf(1.0 - (t - t_burst + STEP) / life, 0.0, 1.0) if t >= t_burst - 1e-6 else 0.0
		keyf(lg, "material:shader_parameter/radius", func(t: float) -> float: return r0 * (0.55 + 0.45 * kk.call(t)), T0, TB + life + 0.04)
		keyf(lg, "material:shader_parameter/alpha", func(t: float) -> float: return k0 * pow(kk.call(t), 2.0), T0, TB + life + 0.04)
