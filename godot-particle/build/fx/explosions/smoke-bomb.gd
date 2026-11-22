# reimagined-from: src/fx/explosions/smoke-bomb.js@e6b0cad38117f632250654efdd7e528425229d99
# Smoke bomb: a round canister clinks down, fuse sparking, and pops: thick grey-violet smoke gushes out, rolls along
# the floor, billows into a cloud that hides all, then thins to wisps.
# The canister is a shader of its own (_smoke-bomb_canister: the original's lit metal, turning red band, outline and
# fuse) riding the original's throw, bounces and roll (replayed in the build script into keys); its fuse spits sparks
# and a thread of smoke, each bounce clinks. The pop is a flash, an eight-ray flare (Line2Ds), light, sparks and grit.
# The cloud is emitters of cel-shaded lobes (_smoke-bomb_lobe: lit crescent, mid tone, dark underside, the particle
# colour carrying opacity and thinning): rollers sliding out along the floor, a fat core, a plume driven up and a
# late trickle, the far ones behind and darker; as it thins it sheds soft wisps.
extends "res://addons/pixelfx_particles/core/build.gd"

const POP := 0.95
const R0 := 4.0
const BAND := ["#3a1418", "#7a2a24", "#b84a34"]
const GRIT := ["#5a4f6b", "#3e3650", "#776c88"]
const OUTLINE := "#1a1422"

var can := {}
var hits := []
var lobe_shader: Shader


static func smoothstep_(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## The canister's flight, as the original steps it: it arcs down, bounces with a clink, rolls and stops.
func step(c: Dictionary, dt: float, t: float, record: bool) -> void:
	if c.rest:
		return
	c.vy += 900.0 * dt
	c.x += c.vx * dt
	c.y += c.vy * dt
	if c.y >= -R0 and c.vy > 0.0:
		c.y = -R0
		if c.vy > 80.0:
			if record:
				hits.append([t, c.x])
			c.vy = -c.vy * 0.38
			c.vx *= 0.78
		else:
			c.vy = 0.0
	if c.vy == 0.0 and c.y >= -R0 - 0.01:
		c.vx -= c.vx * 3.0 * dt
		if absf(c.vx) < 2.0:
			c.vx = 0.0
			c.rest = true
	c.a += (c.vx / R0 if c.vy == 0.0 else c.va) * dt


## A GradientTexture1D from raw values (not colours: no palette entries made for them).
func raw(values: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(values)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


## Cel-shaded smoke lobes: o as particles(); r: the lobe's full radius range [min, max] px; dark: steps down the
## ramp; thin: where in its life it starts to thin (0..1).
func lobes(name: String, o: Dictionary, r: Array, dark: float, thin: float) -> GPUParticles2D:
	var C: PackedColorArray = root.ramps.palette
	# opacity and thinning over life: up in a blink, holding, thinning as (1 - k)^1.4, a step darker past k 0.6
	var vals := []
	var offs := []
	var n := 24
	for i in n:
		var u := (i + 0.5) / n
		var k := smoothstep_(thin, 0.92, u)
		var a := minf(1.0, u * 40.0) * pow(1.0 - k, 1.4) * 0.97
		vals.append(Color(0.5 if k > 0.6 else 0.0, 1.0, 1.0, a))
		offs.append(i / float(n))
	# its radius over life: swelling from 0.38 of its size with a time constant of 0.28 s, a little more as it thins
	var L: float = o.lifetime
	var sc := []
	for i in 13:
		var u := i / 12.0
		var k := smoothstep_(thin, 0.92, u)
		sc.append([u, (0.38 + 0.62 * (1.0 - exp(-u * L / 0.28))) * (1.0 + 0.35 * k)])
	var oo := {"layer": "soft", "texture": "glow16", "one_shot": true, "randomness": 0.15, "scale": [r[0] * 2.0 / 16.0, r[1] * 2.0 / 16.0],
		"scale_curve": sc, "ramp": raw(vals, offs)}
	oo.merge(o, true)
	var p := particles(name, oo)
	var m := ShaderMaterial.new()
	m.shader = lobe_shader
	m.set_shader_parameter("translucent", true)
	for j in 5:
		m.set_shader_parameter("s%d" % j, C[5 - j])
	m.set_shader_parameter("dark", dark)
	p.material = m
	return p


## The original's drag (speed falling as exp(-k t)) and a slow rise once slowed (drift px/s): a velocity limit that
## decays as the drag would (Godot's damping is a constant deceleration).
## A constant damping on top slows the slow ones as the drag would; it's keyed away at `off` (seconds) so the rise
## can carry them on.
func drag(p: GPUParticles2D, v0: float, k: float, drift: float, damp := 0.0, off := 0.0) -> void:
	var m: ParticleProcessMaterial = p.process_material
	var pts := []
	for i in 13:
		var u := i / 12.0
		pts.append([u, v0 * exp(-k * u * p.lifetime) + drift])
	m.velocity_limit_curve = curve(pts, v0 + drift)
	if damp > 0.0:
		m.damping_min = damp
		m.damping_max = damp
		for prop in ["damping_min", "damping_max"]:
			key(p, "process_material:" + prop, [[0.0, damp], [off, damp], [off + 0.3, 0.0]])


## Emit out to both sides along the floor, a little up (directed points: their normals turn the velocity).
func sideways(p: GPUParticles2D, spread: float) -> void:
	var a := deg_to_rad(-6.0)
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(PackedVector2Array([Vector2(-1, 0), Vector2(1, 0)]))
	m.emission_normal_texture = _points_texture(PackedVector2Array([Vector2(-cos(a), sin(a)), Vector2(cos(a), sin(a))]))
	m.emission_point_count = 2
	m.direction = Vector3(1, 0, 0)
	m.spread = spread


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var K: PackedColorArray = root.ramps.canister
	var S: PackedColorArray = root.ramps.sparks
	var D: float = meta.duration
	lobe_shader = load("res://addons/pixelfx_particles/fx/explosions/_smoke-bomb_lobe.gdshader")
	ground()
	for c in BAND + GRIT + [OUTLINE, "#8a6a48"]:
		keep_colour(Color(c))

	# the canister's path: thrown in from the left so that it comes to rest on the anchor
	var start := {"x": -70.0, "y": -60.0, "vx": 125.0, "vy": -80.0, "va": 7.0, "a": 0.0, "rest": false}
	var sim := start.duplicate()
	for i in 2400:
		if sim.rest:
			break
		step(sim, 1.0 / 240.0, 0.0, false)
	can = start.duplicate()
	can.x = start.x - sim.x
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var path := []
	var dt := 1.0 / 240.0
	var t := 0.0
	var i := 0
	var popped := false
	var pop_x := 0.0
	while t <= D + 1e-6:
		if i % 4 == 0:
			path.append([t, Vector2(can.x, can.y), float(can.a)])
		t += dt
		i += 1
		step(can, dt, t, true)
		if not popped and t >= POP:
			popped = true
			pop_x = can.x
			can.vy = -95.0
			can.vx = rng.randf_range(-25, 25)
			can.va = 9.0 if rng.randf() < 0.5 else -9.0
			can.rest = false

	var body := shape("Canister", load("res://addons/pixelfx_particles/fx/explosions/_smoke-bomb_canister.gdshader"), Vector2(18, 18),
		{"radius": R0, "outline": Color(OUTLINE), "k0": K[0], "k1": K[1], "k2": K[2], "k3": K[3], "k4": K[4],
		"band0": Color(BAND[0]), "band1": Color(BAND[1]), "band2": Color(BAND[2]), "fuse": Color("#8a6a48")})
	var pos := []
	var subs := []
	var angs := []
	var tips := []
	for k in path:
		var p: Vector2 = k[1]
		var rp := p.round()
		pos.append([k[0], rp])
		subs.append([k[0], p - rp])
		angs.append([k[0], k[2]])
		tips.append([k[0], p + Vector2(sin(k[2]), -cos(k[2])) * (R0 + 2.5)])
	key(body, "position", pos, "nearest")
	key(body, "material:shader_parameter/sub", subs, "nearest")
	key(body, "material:shader_parameter/angle", angs, "nearest")
	key(body, "material:shader_parameter/live", [[0.0, 1.0], [POP, 0.0]], "nearest")
	key(body, "material:shader_parameter/alpha", [[0.0, 1.0], [4.3, 1.0], [4.55, 0.5], [4.8, 0.0]])

	# the fuse: its burning tip, sparks spitting off it quicker as it burns down, a thread of smoke
	var fuse := group("Fuse")
	key(fuse, "position", tips.filter(func(k): return k[0] <= POP + 0.02))
	var tip := rect("Tip", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": fuse})
	var fl := []
	for j in int(POP * 60.0):
		var tt := j / 60.0
		fl.append([tt, Color.WHITE if sin(tt * 50.0) > 0.0 else S[1]])
	key(tip, "color", fl, "nearest")
	var tip_light := glow("TipLight", 8, {"radius": 6, "color": S[2], "alpha": 0.45}, {"parent": fuse})
	var tl := []
	for j in int(POP * 30.0):
		tl.append([j / 30.0, 0.45 + 0.2 * sin(j / 30.0 * 37.0)])
	tl.append([POP, 0.0])
	key(tip_light, "material:shader_parameter/alpha", tl)
	show(tip, 0.0, POP)
	var spit := particles("FuseSparks", {"parent": fuse, "amount": 14, "lifetime": 0.18, "randomness": 0.5, "texture": "streak3",
		"align": true, "dir": -90, "spread": 35, "speed": [30, 100], "damping": [100, 200], "gravity": Vector2(0, 430),
		"ramp": gradient([S[0], S[1], S[2], S[3]], [0.0, 0.4, 0.7, 0.85])})
	emit(spit, 0.0, POP)
	key(spit, "amount_ratio", [[0.0, 0.35], [POP - 0.4, 0.35], [POP, 1.0]])
	var thread := particles("FuseSmoke", {"parent": fuse, "layer": "soft", "amount": 6, "lifetime": 0.8, "randomness": 0.3,
		"texture": "disc3", "dir": -90, "spread": 15, "speed": [10, 18], "damping": [8, 14], "scale_curve": [[0, 0.7], [1, 1.4]],
		"ramp": gradient([Color(C[5], 0.4), Color(C[5], 0.3), Color(C[5], 0.15), Color(C[5], 0.0)], [0.0, 0.3, 0.6, 0.9])})
	emit(thread, 0.0, POP)

	# each bounce clinks: a few bright specks and a puff of dust
	var h := 0
	for hit in hits:
		var at := Vector2(hit[1], -1)
		var specks := particles("Clink%d" % h, {"at": at, "amount": 3, "lifetime": 0.14, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "streak3", "align": true, "dir": -90, "spread": 40, "speed": [40, 110], "damping": [100, 200],
			"gravity": Vector2(0, 430), "ramp": gradient([S[0], S[1], S[2]])})
		emit(specks, hit[0])
		var dust := particles("ClinkDust%d" % h, {"layer": "soft", "at": at + Vector2(0, 0.5), "amount": 3, "lifetime": 0.55, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "disc3", "emit": {"box": Vector2(2, 0.5)}, "dir": -90, "spread": 80,
			"speed": [10, 40], "damping": [40, 70], "scale_curve": [[0, 0.8], [1, 1.4]],
			"ramp": gradient([Color(GRIT[2], 0.6), Color(GRIT[2], 0.4), Color(GRIT[2], 0.2)])})
		emit(dust, hit[0])
		h += 1

	# the pop: a flash, a flare, light, sparks and grit
	var X := pop_x
	var light := glow("PopLight", 66, {"radius": 64, "color": C[6], "alpha": 0.0}, {"at": Vector2(X, -9)})
	var lk := [[0.0, 0.0], [POP - 0.001, 0.0]]
	var lr := []
	for j in 8:
		var u := j * 0.22 / 7.0
		var k := 1.0 - u / 0.22
		lk.append([POP + u, 0.75 * k * k])
		lr.append([POP + u, 64.0 * (0.55 + 0.45 * k)])
	key(light, "material:shader_parameter/alpha", lk)
	key(light, "material:shader_parameter/radius", lr)
	var white := glow("PopWhite", 24, {"radius": 22, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(X, -5)})
	key(white, "material:shader_parameter/alpha", [[0.0, 0.0], [POP - 0.001, 0.0], [POP, 0.7], [POP + 0.03, 0.2], [POP + 0.06, 0.0]])
	var pool := glow("Pool", 52, {"radius": 50, "squash": 8.0 / 50.0, "color": C[6], "alpha": 0.0}, {"at": Vector2(X, 1)})
	key(pool, "material:shader_parameter/alpha", [[0.0, 0.0], [POP - 0.001, 0.0], [POP, 0.5], [POP + 0.35, 0.0]])
	var outer := ring("Flash", 8, {"radius": 6.5, "color": C[5]}, {"at": Vector2(X, -5)})
	var inner := ring("FlashCore", 6, {"radius": 4.5, "color": Color.WHITE}, {"at": Vector2(X, -5)})
	show(outer, POP, POP + 0.067)
	show(inner, POP, POP + 0.067)
	var ray_g := gradient([Color.WHITE, C[5], C[4]], [0.0, 0.35, 0.7])
	for j in 8:
		var an := j * PI / 4.0
		var f := 1.0 if j % 4 == 0 else (0.6 if j % 2 == 0 else 0.3)
		var ray := line("Ray%d" % j, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"width": 1, "gradient": ray_g, "at": Vector2(X, -5)})
		var rk := []
		for s in 6:
			var u := s * 0.16 / 5.0
			var L := 22.0 * (1.0 - u / 0.16) * f
			rk.append([POP + u, PackedVector2Array([Vector2.ZERO, Vector2(cos(an), sin(an)) * maxf(L, 0.5)])])
		key(ray, "points", rk)
		show(ray, POP, POP + 0.16)
	var sparks := particles("PopSparks", {"at": Vector2(X, -5), "amount": 30, "lifetime": 0.4, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "emitting": false, "texture": "streak3", "align": true, "dir": -90, "spread": 110, "speed": [120, 300],
		"damping": [250, 400], "gravity": Vector2(0, 430), "ramp": gradient([S[0], S[1], S[2], S[3]], [0.0, 0.4, 0.7, 0.85])})
	emit(sparks, POP)
	for g in [["PopGrit", 17, "dot1"], ["PopGrit2", 9, "dot2"]]:
		var grit := particles(g[0], {"at": Vector2(X, -1), "amount": g[1], "lifetime": 1.6, "one_shot": true, "explosiveness": 1.0,
			"randomness": 0.4, "emitting": false, "texture": g[2], "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 52,
			"speed": [80, 220], "gravity": Vector2(0, 950), "initial": gradient(GRIT), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
			"collide": {"bounce": 0.2, "friction": 1.0, "size": 1}})
		emit(grit, POP)

	# the cloud: lobes gushing out, front-loaded: rollers sliding out low along the floor, a fat core over the
	# canister, a plume driven up; a late trickle keeps the base filled. The far third sit behind, a step darker;
	# lobes low in the cloud sit in its shadow, a step darker
	var at := Vector2(X, -7)
	# [name, behind, steps darker, rollers a side, core, plume, trickle]
	for layer in [["Back", true, 1.0, 3, 5, 3, 2], ["", false, 0.0, 6, 12, 6, 6]]:
		var nm: String = layer[0]
		var back: bool = layer[1]
		var dk: float = layer[2]
		for side in [-1, 1]:
			var sn := "L" if side < 0 else "R"
			var roll := lobes("Roller" + sn + nm, {"at": at, "back": back, "amount": layer[3], "lifetime": 2.9, "explosiveness": 0.9,
				"emitting": false, "emit": {"box": Vector2(2, 1)}, "dir": 90 - side * 98, "spread": 7, "speed": [70, 170],
				"gravity": Vector2(3, -14)}, [12, 17], dk + 1.0, 0.45)
			drag(roll, 170.0, 2.4, 5.0, 85.0, POP + 0.9)
			emit(roll, POP)
		var core := lobes("Core" + nm, {"at": at + Vector2(0, -2), "back": back, "amount": layer[4], "lifetime": 2.9, "explosiveness": 0.9,
			"emitting": false, "emit": {"box": Vector2(2, 1)}, "dir": -90, "spread": 34, "speed": [8, 30],
			"gravity": Vector2(2, -8)}, [16, 22], dk, 0.45)
		drag(core, 30.0, 1.6, 6.0, 30.0, POP + 0.8)
		emit(core, POP)
		var plume := lobes("Plume" + nm, {"at": at + Vector2(0, -4), "back": back, "amount": layer[5], "lifetime": 2.9, "explosiveness": 0.9,
			"emitting": false, "emit": {"box": Vector2(2, 1)}, "dir": -90, "spread": 34, "speed": [30, 70],
			"gravity": Vector2(3, -12)}, [13, 18], dk, 0.45)
		drag(plume, 80.0, 1.6, 8.0, 40.0, POP + 0.8)
		emit(plume, POP + 0.05)
		var trickle := lobes("Trickle" + nm, {"at": at, "back": back, "amount": layer[6], "lifetime": 2.0, "explosiveness": 0.5,
			"emitting": false, "speed": [20, 60], "gravity": Vector2(2, -8)}, [14, 19], dk + 1.0, 0.25)
		sideways(trickle, 7.0)
		drag(trickle, 60.0, 2.4, 6.0, 40.0, POP + 1.6)
		emit(trickle, POP + 0.45)

	# as it thins it sheds wisps that drift off; the spent canister keeps smoking a little
	var wisp := gradient([Color(C[4], 0.3), Color(C[4], 0.22), Color(C[4], 0.14), Color(C[4], 0.06), Color(C[4], 0.0)], [0.0, 0.2, 0.45, 0.7, 0.92])
	var wisps := particles("Wisps", {"layer": "soft", "back": true, "at": Vector2(X, -40), "amount": 30, "lifetime": 1.3, "randomness": 0.4,
		"emitting": false, "texture": "disc13", "emit": {"box": Vector2(50, 14)}, "dir": -90, "spread": 30, "speed": [8, 20],
		"gravity": Vector2(5, -2), "scale": [0.9, 1.4], "scale_curve": [[0, 1.0], [1, 0.45]], "ramp": wisp})
	emit(wisps, 2.2, D - 1.4)
	var spent := particles("SpentSmoke", {"layer": "soft", "at": Vector2(can.x, -7), "amount": 4, "lifetime": 0.9, "randomness": 0.3,
		"emitting": false, "texture": "disc5", "dir": -90, "spread": 15, "speed": [8, 16], "scale_curve": [[0, 1.0], [1, 0.5]], "ramp": wisp})
	emit(spent, POP + 0.5, 4.1)
