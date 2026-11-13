# reimagined-from: src/fx/arcane/arcane-missiles.js@e992bce1af5fd7f2f8013cf428458528392d225b
# Arcane missiles: A volley of violet bolts fans out of the hand, curls round on twisting ribbons and pops on the target one after another.
# one-shot, 1.75 s, 240x116 canvas, origin [26.0, 88.0], backdrop ground, stand-in 2
# Five bolts fly the original's homing paths (its steering replayed at 120 Hz into keys): each a layered head (ring
# shader discs, spinning rays) on a ribbon that twists down its trail (a Line2D through the trail with
# fx/arcane/_ribbon.gdshader: the tapered capsule and two strands), light along it, motes shed behind (an emitter
# riding the head). Each pop: a white disc, a cross (the flare shader), a ring, light, sparks and stars (one-shot
# emitters), the floor lit. Four brackets lock onto the target and kick as each bolt lands (_brackets.gdshader).
extends "res://build/fx/arcane/_arcane.gd"

const HX := 15.0
const HY := -24.0
const TX := 152.0
const TY := -22.0
const TRAIL := 18
const FAN := [-1.05, 0.7, -0.5, 1.1, -1.4]

var bolts := []
var pops := []


func make() -> void:
	ground()
	simulate()
	lock()
	for i in bolts.size():
		bolt_nodes(i, bolts[i])
	for i in pops.size():
		pop_nodes(i, pops[i])
	# the hand flickers as it throws them
	var hand := sparkle("HandGlint", Vector2(HX, HY), 3, C[6], C[5])
	keyf(hand, "material:shader_parameter/arm", func(t: float): return 3.0 + 2.0 * sin(t * 40.0), 0.0, 0.55, 30.0, "nearest")
	show(hand, 0.0, 0.55)
	var hl := glow("HandLight", 14, {"radius": 12, "color": C[6], "alpha": 0.45}, {"at": Vector2(HX, HY)})
	keyf(hl, "material:shader_parameter/alpha", func(t: float): return 0.45 * maxf(0.0, 1.0 - t / 0.55), 0.0, 0.56)


## The original's update at 120 Hz: each bolt leaves the hand on its own heading, then homes in harder and faster.
func simulate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in FAN.size():
		var a: float = FAN[i] + rng.randf_range(-0.12, 0.12)
		var sp := rng.randf_range(130, 165)
		bolts.append({"t0": 0.05 + i * 0.1, "x": HX, "y": HY, "vx": cos(a) * sp, "vy": sin(a) * sp, "trail": [], "hit": -1.0, "on": false,
			"tx": TX + rng.randf_range(-3, 3), "ty": TY + rng.randf_range(-6, 6), "tw": rng.randf_range(0, TAU), "heads": {}, "trails": {}})
	var dt := 1.0 / 120.0
	var t := 0.0
	for step in int(1.75 * 120) + 2:
		t += dt
		for b in bolts:
			if t < b.t0 or b.hit >= 0.0:
				continue
			b.on = true
			var age: float = t - b.t0
			var dx: float = b.tx - b.x
			var dy: float = b.ty - b.y
			var d := maxf(1e-6, Vector2(dx, dy).length())
			var spd := 150.0 + 560.0 * age * age
			var steer := minf(1.0, (1.4 + 15.0 * age) * dt)
			b.vx += (dx / d * spd - b.vx) * steer
			b.vy += (dy / d * spd - b.vy) * steer
			b.x += b.vx * dt
			b.y += b.vy * dt
			b.trail.push_front(Vector2(b.x, b.y))
			if b.trail.size() > TRAIL:
				b.trail.pop_back()
			b.heads[step + 1] = Vector2(b.x, b.y)
			b.trails[step + 1] = PackedVector2Array(b.trail)
			if d < 3.0 or age > 1.3:
				b.hit = t
				pops.append({"t": t, "x": b.x, "y": b.y})


## The state the simulation had at time t (the step at or before it).
func state(b: Dictionary, what: String, t: float) -> Variant:
	var steps: Dictionary = b[what]
	var s := int(floorf(t * 120.0 + 1e-4))
	var lo: int = steps.keys().min()
	var hi: int = steps.keys().max()
	return steps[clampi(s, lo, hi)]


func bolt_nodes(i: int, b: Dictionary) -> void:
	var t0: float = b.t0
	var hit: float = b.hit
	var g := group("Bolt%d" % i)
	# the launch: light at the hand, motes thrown along its heading
	light_burst("Launch", t0, Vector2(HX, HY), 28, C[5], 0.7, 0.14)
	var launch := particles("Launch%d" % i, {"at": Vector2(HX, HY), "amount": 4, "lifetime": 0.25, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "streak3", "align": true, "dir": rad_to_deg(atan2(b.trails.values()[0][0].y - HY, b.trails.values()[0][0].x - HX)),
		"spread": 34, "speed": [60, 140], "damping": [40, 80], "color": C[6], "alpha_curve": [[0, 1], [0.5, 1], [1, 0]]})
	life_rand(launch, 0.5)
	emit(launch, t0)

	# the ribbon: a Line2D through the trail, the ribbon shader on it
	var rib := line("Ribbon", PackedVector2Array([Vector2(HX, HY), Vector2(HX - 1, HY)]), {"parent": g, "width": 9.0})
	rib.texture = texture("beam16")
	rib.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	rib.joint_mode = Line2D.LINE_JOINT_BEVEL
	var wc := []
	for k in 11:
		var u := k / 10.0
		wc.append([u, (2.6 * pow(1.0 - u, 0.8) + 0.3 + 1.6) / 4.5])
	rib.width_curve = curve(wc).curve
	var m := ShaderMaterial.new()
	m.shader = arcane_shader("ribbon")
	for k in [["c4", C[4]], ["c5", C[5]], ["c6", C[6]], ["white", Color.WHITE]]:
		m.set_shader_parameter(k[0], k[1])
	m.set_shader_parameter("tw", b.tw)
	rib.material = m
	keyf(rib, "points", func(t: float):
		var tr: PackedVector2Array = state(b, "trails", t)
		if tr.size() < 2:
			return PackedVector2Array([tr[0], tr[0] + Vector2(-0.5, 0)])
		return tr, t0, minf(hit + 0.17, root.duration), 30.0, "nearest")
	keyf(rib, "material:shader_parameter/t", func(t: float): return t, t0, minf(hit + 0.17, root.duration), 30.0, "nearest")
	keyf(rib, "material:shader_parameter/fade", func(t: float): return 1.0 - seg(t, hit, hit + 0.16), hit, hit + 0.17, 30.0, "nearest")
	show(rib, t0, hit + 0.16)
	var rl := glow_path("RibbonLight", Vector2(-20, -70), Vector2(170, 10), 12, C[5], 0.3, 6.0, {"parent": g})
	rl.material.set_shader_parameter("k_end", 0.0)
	keyf(rl, "material:shader_parameter/a", func(t: float): return state(b, "trails", t)[0], t0, minf(hit + 0.17, root.duration), 30.0, "nearest")
	keyf(rl, "material:shader_parameter/b", func(t: float):
		var tr: PackedVector2Array = state(b, "trails", t)
		return tr[tr.size() - 1], t0, minf(hit + 0.17, root.duration), 30.0, "nearest")
	keyf(rl, "material:shader_parameter/alpha", func(t: float): return 1.0 - seg(t, hit, hit + 0.16), hit, hit + 0.17, 30.0, "nearest")
	show(rl, t0, hit + 0.16)

	# the head: spinning rays round layered discs, light
	var head := group("Head", {"parent": g, "at": Vector2(HX, HY)})
	keyf(head, "position", func(t: float): return state(b, "heads", t), t0, hit, 30.0, "nearest")
	show(head, t0, hit)
	for k in 4:
		var kk := k
		var ray := line("Ray%d" % k, PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]), {"parent": head, "color": C[6]})
		keyf(ray, "points", func(t: float):
			var a: float = t * 24.0 + kk * TAU / 4.0 + b.tw
			var l := 5.5 + 1.5 * sin(t * 50.0 + kk)
			var out := PackedVector2Array()
			var dir := Vector2(cos(a), sin(a))
			for j in 4:
				out.append(dir * lerpf(3.2, l, j / 3.0))
			return out, t0, hit, 30.0, "nearest")
	for dd in [[3.8, C[4]], [3.0, C[5]], [2.1, C[6]], [1.2, Color.WHITE]]:
		ring("Disc%d" % int(dd[0] * 10), 5, {"radius": dd[0], "color": dd[1]}, {"parent": head})
	glow("Light", 25, {"radius": 24, "color": C[5], "alpha": 0.6}, {"parent": head})
	glow("Hot", 8, {"radius": 7, "color": Color.WHITE, "alpha": 0.4}, {"parent": head})
	# motes shed behind it
	var shed := particles("Shed%d" % i, {"at": Vector2(HX, HY), "amount": 16, "lifetime": 0.4, "texture": "dot1", "emitting": false,
		"spread": 180, "speed": [5, 25], "damping": [5, 15], "initial": gradient([C[6], C[5]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(shed, 0.5)
	keyf(shed, "position", func(t: float): return state(b, "heads", t), t0, hit, 30.0)
	emit(shed, t0, hit)


func pop_nodes(i: int, q: Dictionary) -> void:
	var t0: float = q.t
	var at := Vector2(q.x, q.y)
	var D := 0.35
	# a white disc in a violet rim
	for L in [[1.5, C[5], "Rim"], [0.0, Color.WHITE, "Core"]]:
		var disc := ring("Pop%d%s" % [i, L[2]], 13, {"radius": 10, "color": L[1]}, {"at": at})
		var add: float = L[0]
		keyf(disc, "material:shader_parameter/radius", func(t: float): return 9.0 * (1.0 - seg(t, t0, t0 + D * 0.16)) + 1.5 + add, t0, t0 + D * 0.16, 60.0)
		show(disc, t0, t0 + D * 0.16)
	# the cross
	var cr := flare("Pop%dCross" % i, at, 18, 1.0)
	cr.material.set_shader_parameter("cross", 1.0)
	cr.material.set_shader_parameter("vert", 0.7)
	cr.material.set_shader_parameter("diag", 0.0)
	keyf(cr, "material:shader_parameter/len", func(t: float): return 15.0 * (1.0 - seg(t, t0, t0 + D * 0.4)) + 3.0, t0, t0 + D * 0.4, 30.0)
	show(cr, t0, t0 + D * 0.4)
	# the ring
	var rr := ring("Pop%dRing" % i, 23, {"radius": 3.5, "thickness": 3, "color": Color.WHITE}, {"at": at})
	keyf(rr, "material:shader_parameter/radius", func(t: float): return 3.5 + 18.0 * out_cubic(seg(t, t0, t0 + D)), t0, t0 + D)
	keyf(rr, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 3.0 * (1.0 - seg(t, t0, t0 + D))), t0, t0 + D)
	keyf(rr, "material:shader_parameter/alpha", func(t: float): return clampf(1.2 - seg(t, t0, t0 + D), 0.0, 1.0), t0, t0 + D)
	key(rr, "material:shader_parameter/color", [[0.0, Color.WHITE], [t0 + D * 0.3, C[6]]], "nearest")
	show(rr, t0, t0 + D)
	# light, the floor lit beneath
	light_burst("Pop%d" % i, t0, at, 70, C[5], 0.9, 0.3)
	light_burst("Pop%dHot" % i, t0, at, 24, Color.WHITE, 0.85, 0.09)
	var fl := glow("Pop%dFloor" % i, 23, {"radius": 22, "color": C[5], "alpha": 0.0}, {"at": Vector2(q.x, -1), "back": true})
	keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.25 * pow(1.0 - seg(t, t0, t0 + 0.5), 2.0) if t >= t0 else 0.0, t0 - 0.04, minf(t0 + 0.5, root.duration))
	# sparks and stars
	var sparks := particles("Pop%dSparks" % i, {"at": at, "amount": 16, "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak4", "align": true, "spread": 180, "speed": [80, 230], "damping": [150, 300], "gravity": Vector2(0, 428),
		"ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
	life_rand(sparks, 0.66)
	emit(sparks, t0)
	var stars := particles("Pop%dStars" % i, {"at": at, "amount": 7, "lifetime": 0.48, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "dir": -80, "spread": 100, "speed": [40, 140], "damping": [60, 120], "initial": gradient([Color.WHITE, C[6], C[5]]),
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(stars, 0.48)
	emit(stars, t0)


## The lock: four brackets close on the target, turning, and kick white as each bolt lands.
func lock() -> void:
	var br := shape("Lock", arcane_shader("brackets"), Vector2(52, 52), {"radius": 19, "color": C[5], "alpha": 0.0}, {"at": Vector2(TX, TY)})
	var kick := func(t: float) -> float:
		var k := 0.0
		for q in pops:
			k = maxf(k, exp(-pow((t - q.t) / 0.06, 2.0)))
		return k
	keyf(br, "material:shader_parameter/radius", func(t: float): return 9.0 + 10.0 * (1.0 - out_cubic(smooth(0.0, 0.22, t))) + 3.0 * kick.call(t), 0.0, 1.46, 30.0)
	keyf(br, "material:shader_parameter/spin", func(t: float): return t * 1.5, 0.0, 1.46, 30.0)
	keyf(br, "material:shader_parameter/alpha", func(t: float): return smooth(0.0, 0.22, t) * (1.0 - smooth(1.15, 1.45, t)), 0.0, 1.46, 30.0)
	keyf(br, "material:shader_parameter/color", func(t: float): return Color.WHITE if kick.call(t) > 0.4 else C[5], 0.0, 1.46, 30.0, "nearest")
	var gl := glow("LockLight", 13, {"radius": 12, "color": C[4], "alpha": 0.0}, {"at": Vector2(TX, TY)})
	keyf(gl, "material:shader_parameter/alpha", func(t: float): return 0.2 * smooth(0.0, 0.22, t) * (1.0 - smooth(1.15, 1.45, t)), 0.0, 1.46, 30.0)
