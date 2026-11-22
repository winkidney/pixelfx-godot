# reimagined-from: src/fx/explosions/firework-burst.js@dc7475a501431e83fef1792620f86f87b72a6dcd
# Firework burst: a shell climbs, slows and bursts into a sphere of coloured trailing stars round a gold core; they
# droop, crackle into white pops and fade, leaving glitter.
# The stars are GPU particles flung from the origin with the sphere's projected speeds (directed emission points whose
# normals carry each star's speed). They fly straight and steady inside a group whose scale and drop are keyed from
# the original's drag and gravity, so every star follows the original's curve exactly (a scale curve keeps their
# pixels whole). Their trails and glitter are the same stars again (same material, same seed) started a little
# later in groups keyed the same way a little later: each copy sits where the star was that long ago, in the trail's
# colour for that age. The heads have light twins and crackle into pops as they die. The climbing shell is a keyed
# line and dot with a spark fizz; the burst is a flare of Line2D rays, light, sparks and smoke.
extends "res://addons/pixelfx_particles/core/build.gd"

const RISE := 0.42
const Y0 := 72.0
const DRAG := 2.6
const G := 88.0
const TRAIL := 0.34
const TURN := 0.22
const SMOKE := Color("#4a4458")

var _curves := {}
var _spheres := 0


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## How far a star has come, as a share of how far it would have flown without drag (the group's scale).
static func reach(tau: float) -> float:
	if tau <= 0.0001:
		return 1.0
	return (1.0 - exp(-DRAG * tau)) / (DRAG * tau)


## How far gravity has pulled every star down by then.
static func drop(tau: float) -> float:
	if tau <= 0.0:
		return 0.0
	return G / DRAG * (tau - (1.0 - exp(-DRAG * tau)) / DRAG)


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var K: PackedColorArray = root.ramps.core
	keep_colour(SMOKE)
	var D: float = meta.duration
	var rng := RandomNumberGenerator.new()
	rng.seed = 9

	_rise(K)
	_burst(C, K)

	# the stars: [name, count, life, speed, ramp, big]
	# (lifetimes vary as the original's do: life_random takes the same share off a star and all its copies)
	var groups := [
		["Pink", 53, 1.9, 236.0, C, false, 0.29],
		["PinkBig", 13, 1.9, 236.0, C, true, 0.29],
		["Gold", 26, 1.4, 120.0, K, false, 0.29],
	]
	var trail_d := []
	for i in 8:
		trail_d.append((i + 1) * TRAIL / 8.0)
	var glitter_d := [0.12, 0.24, 0.36, 0.46, 0.55]
	# a group per delay, keyed as the stars fly: the head's own (0), the trail's, the glitter's
	var holders := {}
	for d in [0.0] + trail_d + glitter_d:
		var g := group("Fly%03d" % int(roundf(d * 1000.0)))
		var sc := []
		var pos := []
		var n := int(ceil((D - RISE - d) * 30.0))
		sc.append([0.0, Vector2.ONE])
		pos.append([0.0, Vector2.ZERO])
		for j in n + 1:
			var tau := j / 30.0
			var s := reach(tau)
			sc.append([RISE + d + tau, Vector2(s, s)])
			pos.append([RISE + d + tau, Vector2(0, drop(tau))])
		key(g, "scale", sc)
		key(g, "position", pos)
		holders[d] = g

	var gi := 0
	for sg in groups:
		var name: String = sg[0]
		var n: int = sg[1]
		var L: float = sg[2]
		var R: PackedColorArray = sg[4]
		var big: bool = sg[5]
		# the head: white on the burst frame, gold while it burns gold, then its colour, flickering before it dies
		var head_cols := [Color.WHITE, K[5], R[6], R[5]]
		var head_at := [0.0, 0.04 / L, TURN / L, 0.55]
		var flick := [[0, 1], [0.72, 1]]
		for f in 10:
			var x := 0.72 + f * 0.028
			flick += [[x + 0.001, 1.0 if f % 2 else 0.0], [x + 0.028, 1.0 if f % 2 else 0.0]]
		var head := particles(name, {"parent": holders[0.0], "local": true, "amount": n, "lifetime": L, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "plus3" if big else "dot1", "speed": [sg[3], sg[3]],
			"ramp": gradient(head_cols, head_at), "alpha_curve": flick, "scale_curve": _unshrink(L), "life_random": sg[6]})
		_sphere(head, rng)
		emit(head, RISE)
		if big:
			key(head, "texture", [[0.0, texture("dot1")], [RISE + 0.06, texture("plus3")], [RISE + 0.6 * L, texture("dot1")]], "nearest")
		var base: ParticleProcessMaterial = head.process_material
		# its light, a soft glow that comes in as the stars spread
		var gk := 0.5 if big else 0.32
		var gcols := []
		var gat := []
		for j in 12:
			var x := j / 12.0
			var age := x * L
			var c: Color = K[4] if age < TURN else R[4]
			gcols.append(Color(c, gk * (1.0 - 0.6 * x) * minf(1.0, (age + 0.05) / 0.2)))
			gat.append(x)
		var lit := _copy(head, name + "Light", holders[0.0], L, {"layer": "light", "texture": "glow8"})
		var lm: ParticleProcessMaterial = lit.process_material
		lm.color_ramp = gradient(gcols, gat)
		lm.alpha_curve = curve([[0, 1], [1, 1]])
		emit(lit, RISE)
		# it crackles out in a couple of white pops
		for k in 2:
			var pl := L + 0.3
			var on := (L + k * 0.07) / pl
			var off := (L + k * 0.07 + 0.09) / pl
			var pop := _copy(head, "%sPop%d" % [name, k], holders[0.0], pl, {"texture": "spark5" if k == 0 else "plus3"})
			var pm: ParticleProcessMaterial = pop.process_material
			pm.color_ramp = gradient([Color.WHITE if k == 0 else R[5]])
			pm.alpha_curve = curve([[0, 0], [on - 0.001, 0], [on, 1], [off, 1], [off + 0.001, 0], [1, 0]])
			emit(pop, RISE)
			var pop_lit := _copy(head, "%sPopLight%d" % [name, k], holders[0.0], pl, {"layer": "light", "texture": "glow16"})
			var plm: ParticleProcessMaterial = pop_lit.process_material
			plm.color_ramp = gradient([Color(Color.WHITE if k == 0 else R[5], 0.4)])
			plm.alpha_curve = pm.alpha_curve
			emit(pop_lit, RISE)
		# the trail: where it was a little while ago, cooling and thinning; the part laid while it burned gold stays gold
		for d in trail_d:
			var u: float = d / TRAIL
			var life: float = L - d
			var col_i := 5 if u < 0.3 else (4 if u < 0.6 else 3)
			var cols := []
			var at := []
			for j in 10:
				var x := j / 10.0
				var age := x * life
				var c: Color = K[col_i] if age < TURN else R[col_i]
				var a := clampf(pow(1.0 - u, 0.8) * (1.3 - 0.6 * (age + d) / L), 0.0, 1.0)
				cols.append(Color(c, a))
				at.append(x)
			var tr := _copy(head, "%sTrail%02d" % [name, int(roundf(d * 100.0))], holders[d], life, {"texture": "streak8", "align": true})
			var tm: ParticleProcessMaterial = tr.process_material
			tm.color_ramp = gradient(cols, at)
			tm.alpha_curve = curve([[0, 1], [1, 1]])
			emit(tr, RISE + d)
			var t0: float = RISE + d
			key(tr, "texture", [[0.0, texture("streak8")], [t0 + 0.16, texture("streak6")], [t0 + 0.3, texture("streak4")],
				[t0 + 0.5, texture("streak3")], [t0 + 0.72, texture("dot1")]], "nearest")
		# glitter shed along the way: specks that hang, twinkle and fall where it passed
		var share := [1.0, 0.9, 0.65, 0.4, 0.15]
		for j in glitter_d.size():
			var d: float = glitter_d[j]
			var tw := []
			var ph := float(j * 3 + gi)
			for f in 24:
				var x := f / 24.0
				var on := sin(x * L * (8.0 + j) + ph) > -0.3
				var sparse := 0.45 if x * L < 0.25 * L else 1.0
				tw += [[x, (share[j] * sparse) if on else 0.0], [x + 1.0 / 24.0 - 0.001, (share[j] * sparse) if on else 0.0]]
			var gl := _copy(head, "%sGlitter%d" % [name, j], holders[d], L, {"texture": "plus3" if j == 2 else "dot1"})
			var gm: ParticleProcessMaterial = gl.process_material
			gm.color_ramp = gradient([K[5] if (j + gi) % 2 else Color.WHITE])
			gm.alpha_curve = curve(tw)
			emit(gl, RISE + d)
		gi += 1


## One more emitter of the same stars (same material settings and seed, so the same stars), with its own lifetime,
## material copy (its colours and scale curve are its own) and texture.
func _copy(src: GPUParticles2D, name: String, parent: Node, life: float, o: Dictionary) -> GPUParticles2D:
	var oo := {"parent": parent, "local": true, "amount": src.amount, "lifetime": life, "one_shot": true, "explosiveness": 1.0,
		"emitting": false}
	oo.merge(o, true)
	var p := particles(name, oo)
	var m: ParticleProcessMaterial = src.process_material.duplicate()
	var ck := "%.3f" % life
	if not _curves.has(ck):
		_curves[ck] = curve(_unshrink(life), 8.0)
	m.scale_curve = _curves[ck]
	m.particle_flag_align_y = o.get("align", false)
	p.process_material = m
	p.seed = src.seed
	return p


## The particles' scale over a life of `life` seconds: undoes their group's shrinking (it is scaled by reach(age)) so
## a star stays a whole pixel.
func _unshrink(life: float) -> Array:
	var pts := []
	for j in 17:
		var x := j / 16.0
		pts.append([x, 1.0 / reach(x * life)])
	return pts


## The stars' directions and speeds: thrown over a sphere and seen side-on, so the ones flying at us or away look
## slower (directed emission points at the origin whose normals carry each one's share of the speed).
func _sphere(p: GPUParticles2D, rng: RandomNumberGenerator, n := 256) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in n:
		var z := rng.randf_range(-1, 1)
		var a := rng.randf_range(0, TAU)
		var s := sqrt(1.0 - z * z) * rng.randf_range(0.93, 1.05)
		pts.append(Vector2.ZERO)
		nor.append(Vector2(cos(a), sin(a)) * s)
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	# (beside the scene, not inside it)
	_spheres += 1
	m.emission_point_texture = asset("sphere%d_points" % _spheres, _points_texture(pts).get_image())
	m.emission_normal_texture = asset("sphere%d_normals" % _spheres, _points_texture(nor).get_image())
	m.emission_point_count = n
	m.direction = Vector3(1, 0, 0)
	m.spread = 0.0


## The shell climbing, slowing, shedding a fizz of gold sparks and a thread of smoke.
func _rise(K: PackedColorArray) -> void:
	var shell := group("Shell")
	var tail := line("ShellTail", _seg(Vector2.ZERO, Vector2(0, 9), 9), {"width": 1, "gradient": gradient([K[5], K[3]], [0.0, 0.3]),
		"parent": shell})
	var head := rect("ShellHead", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": shell})
	var lit := glow("ShellLight", 8, {"radius": 7, "color": K[4], "alpha": 0.5}, {"parent": shell})
	var pos := []
	var pts := []
	for j in int(ceil(RISE * 60.0)) + 1:
		var t := j / 60.0
		var u := t / RISE
		pos.append([t, Vector2(0, roundf(Y0 * (1.0 - out_cubic(u))))])
		pts.append([t, _seg(Vector2.ZERO, Vector2(0, 3.0 + 6.0 * (1.0 - u)), 9)])
	key(shell, "position", pos)
	key(tail, "points", pts)
	show(shell, 0.0, RISE)
	var fizz := particles("Fizz", {"parent": shell, "amount": 16, "lifetime": 0.35, "randomness": 0.4, "texture": "streak3",
		"align": true, "at": Vector2(0, 2), "emit": {"box": Vector2(0.5, 0.5)}, "dir": 90, "spread": 30, "speed": [25, 75],
		"drag": 2.2, "gravity": Vector2(0, 430), "ramp": gradient([K[6], K[5], K[4], K[3]], [0.0, 0.4, 0.7, 0.85])})
	emit(fizz, 0.0, RISE)
	var thread := particles("Thread", {"parent": shell, "layer": "soft", "amount": 8, "lifetime": 0.8, "randomness": 0.4,
		"texture": "disc3", "at": Vector2(0, 3), "dir": 90, "spread": 30, "speed": [5, 15], "drag": 4.0,
		"scale_curve": [[0, 1.0], [1, 2.0]], "color": Color(SMOKE, 0.45), "alpha_curve": [[0, 1], [1, 0]]})
	emit(thread, 0.0, RISE)


## The burst: a flare and a white heart, the sky lit up, a few sparks and the burst charge's smoke.
func _burst(C: PackedColorArray, K: PackedColorArray) -> void:
	for L in [["SkyLight", 110.0, C[4], 0.6, 1.5], ["HeartLight", 30.0, Color.WHITE, 0.5, 0.07]]:
		var g := glow(L[0], L[1] + 2, {"radius": L[1], "color": L[2], "alpha": 0.0})
		var ak := [[0.0, 0.0], [RISE - 0.001, 0.0]]
		var rk := []
		for j in 21:
			var k: float = 1.0 - j / 20.0
			ak.append([RISE + L[4] * j / 20.0, L[3] * k * k])
			rk.append([RISE + L[4] * j / 20.0, L[1] * (0.55 + 0.45 * k)])
		key(g, "material:shader_parameter/alpha", ak)
		key(g, "material:shader_parameter/radius", rk)
	var heart := ring("Heart", 4, {"radius": 2.6, "color": Color.WHITE})
	key(heart, "material:shader_parameter/radius", [[RISE, 2.6], [RISE + 0.07, 1.2]])
	show(heart, RISE, RISE + 0.07)
	var axis_g := gradient([Color.WHITE, C[5], C[4], Color(C[4], 0.5)], [0.0, 0.3, 0.65, 0.85])
	var diag_g := gradient([K[5], K[4], Color(K[4], 0.5)], [0.0, 0.5, 0.85])
	for i in 8:
		var diag := i % 2 == 1
		var ray := line("Flare%d" % i, _seg(Vector2.ZERO, Vector2.ZERO, 12), {"width": 1, "gradient": diag_g if diag else axis_g})
		var fk := []
		for j in 17:
			var b := j * 0.28 / 16.0
			var u := b / 0.28
			var L := 32.0 * pow(1.0 - u, 1.3) * (0.42 if diag else 1.0)
			var an := u * 0.6 + i * TAU / 8.0
			fk.append([RISE + b, _seg(Vector2.ZERO, Vector2(cos(an), sin(an)) * maxf(L, 0.5), 12)])
		key(ray, "points", fk)
		show(ray, RISE, RISE + 0.28)
	for L in [["FlareLight", C[4], 0.3, 4.0, 1.2], ["FlareWhite", Color.WHITE, 0.25, 2.0, 0.3]]:
		var g := glow(L[0], 44, {"radius": 40, "color": L[1], "alpha": L[2]})
		var rk := []
		for j in 9:
			var u := j / 8.0
			rk.append([RISE + u * 0.28, L[3] + 32.0 * pow(1.0 - u, 1.3) * L[4]])
		key(g, "material:shader_parameter/radius", rk)
		show(g, RISE, RISE + 0.28)
	var sparks := particles("Sparks", {"amount": 24, "lifetime": 0.35, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "streak3", "align": true, "spread": 180, "speed": [40, 140], "drag": 2.2,
		"gravity": Vector2(0, 430), "ramp": gradient([K[6], K[5], K[4], K[3]], [0.0, 0.4, 0.7, 0.85])})
	emit(sparks, RISE)
	var smoke := particles("Smoke", {"layer": "soft", "amount": 7, "lifetime": 3.0, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "disc13", "emit": {"circle": 6}, "spread": 180, "speed": [10, 30], "damping": [12, 20],
		"scale": [0.9, 1.6], "scale_curve": [[0, 0.9], [1, 2.0]], "color": Color(SMOKE, 0.35), "alpha_curve": [[0, 1], [0.3, 0.55], [0.7, 0.15], [1, 0]]})
	emit(smoke, RISE)


## n + 1 points evenly from a to b: a Line2D takes its gradient's colour only at its points.
static func _seg(a: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(a.lerp(b, i / float(n)))
	return out
