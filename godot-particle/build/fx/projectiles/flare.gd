# reimagined-from: src/fx/projectiles/flare.js@12e06947eed1751bdc0efd88e6b849b5f04d4e31
# Signal flare: A signal flare streaks up off the ground trailing sparks and smoke, bursts, and hangs as a pulsing red star that drips sparks under its own red-lit smoke, then gutters out.
# one-shot, 5.00 s, 152x232 canvas, origin [76.0, 226.0], backdrop sky
# The original's update is replayed at 120 Hz with its own Rng, so every puff and spark is its own: the smoke (the
# launch's puffs, the trail left up the rise, the burst's, the plume boiling off the star) is GPU particles stepped
# with its physics (fx/projectiles/_flare_puff: _muzzle_puff plus the star's red light on every puff by distance),
# drawn lit on their crowns (_muzzle_lobe); the sparks shed on the rise, thrown by the burst and dripping off the
# star are GPU particles with its gravity, drag and floor (_muzzle.gd bits(), with points of light). The rising
# flare is a small sprite keyed up its eased path; the star is three discs (ring shaders) pulsing and guttering,
# the original's sparkle and, at the burst, its 8-ray flare and a white ball; light pools round all of it.
extends "res://build/fx/projectiles/_muzzle.gd"

const RISE := 0.85
const BURN := 3.1

var T := []          # the original's clock at every frame
var H := 150.0


func rise(t: float) -> Vector2:
	return Vector2(sin(t * 3.0) * 2.0 * (t / RISE), -H * out_cubic(clampf(t / RISE, 0.0, 1.0)))


func star(t: float) -> Vector2:
	var u := t - RISE
	return Vector2(sin(u * 1.6) * 3.0 + rise(RISE).x, -H + u * 9.0 + sin(u * 2.3) * 1.5)


## Key node.prop on frames k0..k1 with f(the original's clock at that frame), held.
func kf(node: Node, prop: String, k0: int, k1: int, f: Callable) -> void:
	var keys := []
	for k in range(k0, mini(k1, T.size() - 1) + 1):
		keys.append([maxf(0.0, k / 30.0 - 0.002) if k > 0 else 0.0, f.call(T[k])])
	key(node, prop, keys, "nearest")


## The original's Lights.add() at t0: a glow that shrinks a little and dies as (life left)^2.
func burst_light(name: String, t0: float, at: Vector2, r: float, c: Color, k: float, life: float) -> void:
	var g := light_at(name, at, r, c, 0.0)
	var k0 := maxi(0, int(floorf(t0 * 30.0)) - 1)
	var k1 := int(ceilf((t0 + life) * 30.0)) + 1
	kf(g, "material:shader_parameter/radius", k0, k1, func(t: float) -> float: return r * (0.55 + 0.45 * clampf(1.0 - (t - t0) / life, 0.0, 1.0)))
	kf(g, "material:shader_parameter/alpha", k0, k1, func(t: float) -> float: return k * pow(clampf(1.0 - (t - t0) / life, 0.0, 1.0), 2.0) if t >= t0 else 0.0)


func make() -> void:
	var C := pal("palette")
	var SM := pal("smoke")
	var D: float = root.duration
	H = meta.options.height
	var N := int(D * 30.0)
	for k in N + 1:
		T.append(sim_t(k))
	var R := Rng.new(int(meta.options.seed))
	var WR := PackedColorArray([C[0], C[1], mixc(C[2], SM[2], 0.45), mixc(C[3], SM[3], 0.35), C[4], C[5], C[6]])

	# ---- the original's update, replayed
	var sl := []
	var bl := []
	for i in 5:
		var q := {"y": -2.0, "r0": 2.0, "a": 0.5, "warm": 0.8, "rise": 6.0}
		q.x = R.range(-3, 3)
		q.vx = R.range(-25, 25)
		q.vy = -R.range(5, 20)
		q.r1 = R.range(4, 6)
		q.life = R.range(1, 1.6)
		smoke_add(sl, R, q)
	var t := 0.0
	var dt := 1.0 / 120.0
	var burst := false
	var burst_t := 0.0
	var em := 0.0
	var drip := 0.0
	for step in int(D * 120.0) + 2:
		var pt := t
		t += dt
		if t < RISE:
			var p := rise(t)
			var pp := rise(maxf(0.0, t - dt))
			em += p.distance_to(pp) / 1.5
			while em > 1.0:
				var q := {"r0": 1.3, "a": 0.5, "b": 0.95, "warm": 0.9, "rise": 3.0, "drag": 2.0, "grow": 1.4, "delay": pt}
				q.x = p.x + R.range(-0.6, 0.6)
				q.y = p.y + 4.0
				q.vx = R.range(-6, 6)
				q.vy = R.range(0, 8)
				q.r1 = R.range(3, 4.8)
				q.life = R.range(1.4, 2.1)
				smoke_add(sl, R, q)
				em -= 1.0
			if R.chance(0.5):
				var vx := R.range(-40, 40)
				var vy := R.range(20, 90)
				spawn(bl, R, SPARK, p.x, p.y + 3.0, vx, vy, R.range(0.2, 0.45), 1.0, pt)
		elif not burst:
			burst = true
			burst_t = t
			var p := star(t)
			for i in 30:
				var a := R.range(0, TAU)
				var sp := R.range(70, 190)
				spawn(bl, R, SPARK, p.x, p.y, cos(a) * sp, sin(a) * sp - 30.0, R.range(0.25, 0.7), 1.0, pt)
			for i in 10:
				var q := {"r0": 2.5, "a": 0.55, "warm": 1.0, "rise": 10.0, "drag": 2.5, "delay": pt}
				q.x = p.x + R.range(-3, 3)
				q.y = p.y + R.range(-3, 3)
				q.vx = R.range(-40, 40)
				q.vy = R.range(-40, 10)
				q.r1 = R.range(6, 9)
				q.life = R.range(1.6, 2.4)
				smoke_add(sl, R, q)
		elif t < RISE + BURN:
			var p := star(t)
			var k := (t - RISE) / BURN
			var power := 1.0 - smooth(0.75, 1.0, k)
			drip += dt * 26.0 * power
			while drip > 1.0:
				var x := p.x + R.range(-1.5, 1.5)
				var vx := R.range(-30, 30)
				var vy := R.range(10, 60)
				spawn(bl, R, SPARK, x, p.y + 2.0, vx, vy, R.range(0.35, 0.8), 1.0, pt)
				drip -= 1.0
			if R.chance(dt * 18.0 * power):
				var q := {"r0": 2.0, "a": 0.5, "b": 0.85, "warm": 1.0, "rise": 14.0, "drag": 1.6, "grow": 1.2, "delay": pt}
				q.x = p.x + R.range(-1.5, 1.5)
				q.y = p.y - 2.0
				q.vx = R.range(-8, 8)
				q.vy = -R.range(15, 30)
				q.r1 = R.range(6, 10)
				q.life = R.range(1.6, 2.4) * (1.0 - 0.4 * k)
				smoke_add(sl, R, q)

	# ---- smoke, lit red by the star, more the closer and the brighter it burns
	var rows := [[], [], [], []]
	for q in sl:
		rows[0].append(Vector4(q.x, q.y, q.vx, q.vy))
		rows[1].append(Vector4(q.r0, q.r1, q.life, q.a))
		rows[2].append(Vector4(q.b, q.drag, q.rise, q.grow))
		rows[3].append(Vector4(q.curl, q.warm, q.delay, q.seed))
	var smoke := particles("Smoke", {"layer": "soft", "amount": sl.size(), "lifetime": D - 0.02, "one_shot": true, "explosiveness": 1.0,
		"texture": "glow16", "local": true, "process_shader": PROJ + "_flare_puff.gdshader", "process_params": {"count": float(sl.size()), "mode": 0.0, "wmul": 1.0}})
	smoke.process_material.set_shader_parameter("data", data_tex("smoke_data", rows))
	smoke.material = lobe_mat(SM, WR, 1.4, 0.8, 1.3)
	var lit := func(tt: float) -> float: return 1.0 - smooth(0.75, 1.0, (tt - RISE) / BURN) if (tt > RISE and tt < RISE + BURN) else 0.0
	kf(smoke, "process_material:shader_parameter/star_lit", 0, N, lit)
	kf(smoke, "process_material:shader_parameter/star", 0, N, func(tt: float) -> Vector2: return star(clampf(tt, RISE, RISE + BURN)))

	bits("Sparks", bl, [Color.WHITE, C[6], C[4], C[2]])

	# ---- the rising flare: a white-hot head, a short red flame under it
	var img := Image.create(1, 7, false, Image.FORMAT_RGBA8)
	var px := [C[6], Color.WHITE, C[6], C[6], C[4], C[3], C[3]]
	for i in 7:
		img.set_pixel(0, i, px[i])
	var kr := int(ceilf(RISE * 30.0)) + 1
	var head := sprite("Rising", asset("rising", img), {"layer": "prop", "centered": false, "offset": Vector2(0, -1)})
	kf(head, "position", 0, kr, func(tt: float) -> Vector2: return rise(minf(tt, RISE)).floor())
	kf(head, "visible", 0, kr, func(tt: float) -> bool: return tt < RISE)
	for g in [["RiseGlow", 14.0, C[4], 0.6], ["RiseHot", 4.0, Color.WHITE, 0.4]]:
		var gl := light_at(g[0], Vector2.ZERO, g[1], g[2], g[3])
		kf(gl, "position", 0, kr, func(tt: float) -> Vector2: return rise(minf(tt, RISE)))
		kf(gl, "visible", 0, kr, func(tt: float) -> bool: return tt < RISE)
	burst_light("Launch", 0.0, Vector2(0, -3), 26, C[4], 0.8, 0.25)

	# ---- the star
	var k0 := int(floorf(RISE * 30.0)) - 1
	var k1 := int(ceilf((RISE + BURN) * 30.0)) + 1
	var on := func(tt: float) -> bool: return tt >= RISE and tt < RISE + BURN
	var fl := func(tt: float) -> float: return 0.8 + 0.2 * jrand([floori(tt * 30.0), 3]) + 0.08 * sin((tt - RISE) * 19.0)
	var die := func(tt: float) -> float: return 1.0 - smooth(0.78, 1.0, (tt - RISE) / BURN)
	var rad := func(tt: float) -> float: return (2.0 + 0.6 * fl.call(tt)) * (0.4 + 0.6 * die.call(tt))
	var st := group("Star")
	kf(st, "position", k0, k1, func(tt: float) -> Vector2: return star(clampf(tt, RISE, RISE + BURN)))
	st.visible = false
	kf(st, "visible", 0, k1, on)
	# the burst: a flash of white and rays for a moment
	var kb := int(ceilf((RISE + 0.25) * 30.0)) + 1
	var rays := flare8("Rays", Vector2.ZERO, 25, 1.0, C, {"parent": st})
	kf(rays, "material:shader_parameter/len", k0, kb, func(tt: float) -> float: return 22.0 * (1.0 - (tt - RISE) / 0.25) + 3.0)
	kf(rays, "material:shader_parameter/k", k0, kb, func(tt: float) -> float: return 1.0 - (tt - RISE) / 0.25)
	kf(rays, "visible", k0, kb, func(tt: float) -> bool: return tt - RISE < 0.25)
	var ball := ring("BurstBall", 7, {"radius": 6, "color": Color.WHITE}, {"parent": st})
	kf(ball, "material:shader_parameter/radius", k0, kb, func(tt: float) -> float: return 5.0 * (1.0 - (tt - RISE) / 0.25 * 3.0) + 1.0)
	kf(ball, "visible", k0, kb, func(tt: float) -> bool: return (tt - RISE) / 0.25 < 0.25)
	# a hot ball with a long cross of light that pulses, guttering at the end
	var d1 := ring("StarRim", 5, {"radius": 4, "color": C[3]}, {"parent": st})
	kf(d1, "material:shader_parameter/radius", k0, k1, func(tt: float) -> float: return rad.call(tt) + 1.2)
	var d2 := ring("StarBody", 4, {"radius": 3, "color": C[5]}, {"parent": st})
	kf(d2, "material:shader_parameter/radius", k0, k1, rad)
	kf(d2, "material:shader_parameter/color", k0, k1, func(tt: float) -> Color: return C[5] if die.call(tt) > 0.4 else C[4])
	var d3 := ring("StarHeart", 3, {"radius": 2, "color": Color.WHITE}, {"parent": st, "at": Vector2(-0.3, -0.3)})
	kf(d3, "material:shader_parameter/radius", k0, k1, func(tt: float) -> float: return rad.call(tt) * 0.55)
	kf(d3, "material:shader_parameter/color", k0, k1, func(tt: float) -> Color: return Color.WHITE if die.call(tt) > 0.6 else C[6])
	kf(d3, "visible", k0, k1, func(tt: float) -> bool: return die.call(tt) > 0.25)
	var arm := func(tt: float) -> float:
		var dd: float = die.call(tt)
		return roundf((5.0 + 3.0 * fl.call(tt)) * dd) if (dd > 0.15 and jrand([floori(tt * 30.0), 9]) > 0.15) else 0.0
	var cross := sparkle("Cross", Vector2.ZERO, 0, C[6], C[4], {"parent": st})
	kf(cross, "material:shader_parameter/arm", k0, k1, arm)
	var cl := light_at("CrossLight", Vector2.ZERO, 22, C[6], 0.0, {"parent": st})
	kf(cl, "material:shader_parameter/radius", k0, k1, func(tt: float) -> float: return 4.0 + 2.0 * maxf(1.0, arm.call(tt)))
	kf(cl, "material:shader_parameter/alpha", k0, k1, func(tt: float) -> float: return 0.5 * die.call(tt) if arm.call(tt) >= 1.0 else 0.0)
	var g1 := light_at("StarPool", Vector2.ZERO, 70, C[3], 0.0, {"parent": st})
	kf(g1, "material:shader_parameter/radius", k0, k1, func(tt: float) -> float: return 70.0 * (0.6 + 0.4 * die.call(tt)))
	kf(g1, "material:shader_parameter/alpha", k0, k1, func(tt: float) -> float: return 0.55 * fl.call(tt) * die.call(tt))
	var g2 := light_at("StarGlow", Vector2.ZERO, 22, C[4], 0.0, {"parent": st})
	kf(g2, "material:shader_parameter/alpha", k0, k1, func(tt: float) -> float: return 0.5 * fl.call(tt) * die.call(tt))
	var g3 := light_at("StarHot", Vector2.ZERO, 6, Color.WHITE, 0.0, {"parent": st})
	kf(g3, "material:shader_parameter/alpha", k0, k1, func(tt: float) -> float: return 0.35 * die.call(tt))
	burst_light("Burst", burst_t, star(burst_t), 64, C[4], 0.9, 0.5)
	burst_light("BurstHot", burst_t, star(burst_t), 24, Color.WHITE, 0.8, 0.12)
