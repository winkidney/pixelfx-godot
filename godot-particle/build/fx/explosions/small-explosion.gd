# reimagined-from: src/fx/explosions/small-explosion.js@64b98a2976bf623829fe4bc9bdfc2b4ae894672a
# Explosion: a ground blast: a white flash and shock rings, fire that cools into a rolling smoke column, sparks,
# burning brands that land and keep burning, tumbling rocks and a glowing scorch.
# Shapes: the flash, two shock rings and a band rolling out along the floor are ring shaders keyed from the
# original's curves; the scorch is a shader of its own (_small-explosion_scorch.gdshader, the original's formula).
# Particles are the original's recipe, each kind thrown with the original's own spread of positions and velocities
# (directed emission points: a point and a velocity per sample) and drawn as it draws them
# (_small-explosion_puff.gdshader): fire puffs with a darker rim, a lit core and a tongue, cooling down the fire ramp;
# big soft smoke puffs with a dense core and a lit cap, rising and greying into a column; dust rolling out both ways
# along the floor and a dust column; sparks that bounce, floating embers, rocks and grit landing on a collision
# floor. Where the fire puffs die their smoke starts (the build script replays their flight to find where), the few
# burning brands fly the original's arcs (keyed) trailing flame, and small fires burn a second where they land.
extends "res://addons/pixelfx_particles/core/build.gd"

const RAD := 18.0
const POWER := 0.9
const Y := -RAD * 0.3          # the blast's heart, a little above the floor
const SMOKE := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const DARK := Color8(34, 29, 38)
const SOOT := Color("#0d0a12")
const SOOT2 := Color("#17121d")
const WARM := Color8(255, 176, 96)
const HOT := ["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"]
const PUFF := "res://addons/pixelfx_particles/fx/explosions/_small-explosion_puff.gdshader"

var rng := RandomNumberGenerator.new()
var F: PackedColorArray
var FR: PackedColorArray
var ST := {}


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func r(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func sgn() -> float:
	return -1.0 if rng.randf() < 0.5 else 1.0


func make() -> void:
	rng.seed = 7
	ground()
	F = root.ramps.palette
	var mid := F[1].lerp(F[0], 0.5)
	FR = PackedColorArray([F[7], F[6], F[5], F[4], F[3], F[2], F[1], mid, F[0]])
	keep_colour(mid)
	var body := Color(meta.options.stone)
	ST = {"light": (body * 1.35).lerp(Color.WHITE, 0.08), "body": body, "shade": body * 0.64,
		"dust": (body * 1.2).lerp(Color8(150, 140, 150), 0.3)}
	for k in ST:
		ST[k].a = 1.0
		keep_colour(ST[k])
	for c in SMOKE + [DARK, SOOT, SOOT2]:
		keep_colour(Color(c))

	_floor()
	_light_and_flash()
	_fire()
	_smoke()
	_sparks_and_embers()
	_brands()
	_earth()


# ------------------------------------------------------------------ the floor, the light, the flash and rings

func _floor() -> void:
	var heat := PackedColorArray()
	for i in 8:
		heat.append(F[7 - i])
	var cool := 1.2 + RAD / 14.0
	var D: float = meta.duration
	var sc := shape("Scorch", load("res://addons/pixelfx_particles/fx/explosions/_small-explosion_scorch.gdshader"), Vector2(50, 6),
		{"heat": heat, "soot": SOOT, "soot2": SOOT2, "rx0": 22.0, "cool": cool}, {"at": Vector2(0, 1), "back": true})
	key(sc, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var fk := []
	for i in 21:
		var t := D - 1.4 + i * 1.4 / 20.0
		fk.append([t, 1.0 - smooth(D - 1.2, D - 0.2, t)])
	key(sc, "material:shader_parameter/fade", fk)
	# its glow on the floor, cooling with it
	var g := glow("ScorchGlow", 30, {"radius": 26, "squash": 0.2, "color": F[3], "alpha": 0.0})
	var gk := []
	for i in 31:
		var t := i * cool / 30.0
		gk.append([t, 0.4 * pow(clampf(1.0 - t / cool, 0.0, 1.0), 1.4) * minf(1.0, t / 0.08)])
	key(g, "material:shader_parameter/alpha", gk)

	# the band of dust and light rolling out along the floor: its far half behind, its near half in front
	for half in [[1.0, true, "Far"], [-1.0, false, "Near"]]:
		var outer := ring("Band%s" % half[2], 84, {"radius": 1, "thickness": 1, "squash": 0.16, "color": F[6], "side": half[0]},
			{"at": Vector2(0, 0.5), "back": half[1]})
		var inner := ring("Band%sBody" % half[2], 84, {"radius": 1, "thickness": 1, "squash": 0.16, "color": F[3], "side": half[0]},
			{"at": Vector2(0, 0.5), "back": half[1]})
		var ro := []
		var ri := []
		var ti := []
		var al := []
		var ci := []
		for i in 31:
			var k := i / 30.0
			var t := k * 0.5
			var R := maxf(1.0, 80.0 * out_cubic(k))
			var th := maxf(1.0, (2.0 + RAD / 9.0) * (1.0 - k))
			ro.append([t, R])
			ri.append([t, R - 0.8])
			ti.append([t, maxf(0.5, th - 0.8)])
			al.append([t, minf(1.0, 1.15 - k)])
		key(outer, "material:shader_parameter/radius", ro)
		key(inner, "material:shader_parameter/radius", ri)
		key(inner, "material:shader_parameter/thickness", ti)
		key(outer, "material:shader_parameter/alpha", al)
		key(inner, "material:shader_parameter/alpha", al)
		# deep down the band it is the stone's dust; at its lip, light
		key(inner, "material:shader_parameter/color", [[0.0, F[3]], [0.2, ST.light], [0.35, ST.body]], "nearest")
		show(outer, 0.0, 0.5)
		show(inner, 0.0, 0.5)


func _light_and_flash() -> void:
	for L in [["Swell", RAD * 3.4, WARM, 0.6 * POWER, 0.7], ["Pop", RAD * 1.6, Color.WHITE, 0.6, 0.08]]:
		var g := glow(L[0], L[1] + 2, {"radius": L[1], "color": L[2], "alpha": L[3]}, {"at": Vector2(0, Y)})
		var ak := []
		var rk := []
		for j in 21:
			var k: float = 1.0 - j / 20.0
			ak.append([L[4] * j / 20.0, L[3] * k * k])
			rk.append([L[4] * j / 20.0, L[1] * (0.55 + 0.45 * k)])
		key(g, "material:shader_parameter/alpha", ak)
		key(g, "material:shader_parameter/radius", rk)
	# the flash: an orange edge, a hot body and a white heart, for two frames
	var fr0 := RAD * 1.05
	var edge := ring("FlashEdge", fr0 + 2, {"radius": fr0 + 1.2, "color": F[2]}, {"at": Vector2(0, Y)})
	var fbody := ring("Flash", fr0 + 1, {"radius": fr0, "color": F[6]}, {"at": Vector2(0, Y)})
	var heart := ring("FlashHeart", fr0, {"radius": fr0 * 0.6, "color": Color.WHITE}, {"at": Vector2(0, Y)})
	var ek := []
	var bk := []
	var hk := []
	for j in 7:
		var t := j * 0.06 / 6.0
		var k := 1.0 - t / 0.06
		var rr := fr0 * (0.8 + 0.2 * k)
		ek.append([t, rr + 1.2])
		bk.append([t, rr])
		hk.append([t, rr * 0.6])
	key(edge, "material:shader_parameter/radius", ek)
	key(fbody, "material:shader_parameter/radius", bk)
	key(heart, "material:shader_parameter/radius", hk)
	key(fbody, "material:shader_parameter/color", [[0.0, F[6]], [0.06 * 0.55, F[5]]], "nearest")
	key(heart, "material:shader_parameter/color", [[0.0, Color.WHITE], [0.06 * 0.55, F[6]]], "nearest")
	for n in [edge, fbody, heart]:
		show(n, 0.0, 0.06)
	# two shock rings
	for R in [["Shock", RAD * 0.45, RAD * 2.7, 0.34, 3.0, F[5]], ["Shock2", RAD * 0.3, RAD * 1.6, 0.22, 1.8, F[3]]]:
		var rg := ring(R[0], R[2] + 2, {"radius": R[1], "thickness": R[4], "color": R[5]}, {"at": Vector2(0, Y)})
		var rk := []
		var tk := []
		var ak := []
		for j in 21:
			var u := j / 20.0
			var t: float = u * R[3]
			var k2 := 1.0 - u
			rk.append([t, R[1] + (R[2] - R[1]) * (1.0 - k2 * k2 * k2)])
			tk.append([t, maxf(1.0, R[4] * k2 + 0.4)])
			ak.append([t, minf(1.0, k2 * 1.6)])
		key(rg, "material:shader_parameter/radius", rk)
		key(rg, "material:shader_parameter/thickness", tk)
		key(rg, "material:shader_parameter/alpha", ak)
		show(rg, 0.0, R[3])


# ------------------------------------------------------------------ fire and smoke

## A material drawing particles as the original's FIRE puffs (mode 1) or SMOKE puffs (mode 0, translucent).
func puff_mat(mode: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(PUFF)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("fr", FR)
	m.set_shader_parameter("sm", PackedColorArray(SMOKE.map(func(c: String) -> Color: return Color(c))))
	m.set_shader_parameter("dark", DARK)
	m.set_shader_parameter("dust", ST.dust)
	m.set_shader_parameter("translucent", mode < 0.5)
	return m


## A smooth gradient carrying data to the puff shader (kept off the palette).
func data(points: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for p in points:
		offs.append(p[0])
		cs.append(p[1])
	g.offsets = offs
	g.colors = cs
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


## Samples [{p, v, life, size}] as an emitter's options: each particle starts at a sample's point flying at its
## velocity (directed points, the normal's length scaling the mean speed); lifetimes and sizes span the samples'.
func thrown(samples: Array, o: Dictionary) -> Dictionary:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	var v0 := 0.0
	for s in samples:
		v0 += (s.v as Vector2).length()
	v0 = maxf(1.0, v0 / samples.size())
	var lo := 1e9
	var hi := 0.0
	var smin := 1e9
	var smax := 0.0
	for s in samples:
		pts.append(s.p)
		nor.append(s.v / v0)
		lo = minf(lo, s.life)
		hi = maxf(hi, s.life)
		smin = minf(smin, s.size)
		smax = maxf(smax, s.size)
	var oo := {"amount": samples.size(), "lifetime": hi, "life_random": 1.0 - lo / hi, "emit": {"points": pts, "normals": nor},
		"dir": 0.0, "speed": [v0, v0], "scale": [smin, smax]}
	oo.merge(o, true)
	return oo


## FIRE puffs (the original's P.FIRE): the samples' size is the puff's radius in px.
func fire_puffs(name: String, samples: Array, o: Dictionary) -> GPUParticles2D:
	var heat := []
	var lit := []
	for i in 13:
		var age := i / 12.0
		var k := 1.0 - age
		var h := minf(0.999, pow(age, 0.62) + 0.05)
		var idx := mini(7, int(floor(h * 8.0)))
		heat.append([age, Color(h, 0, 0, minf(1.0, k * 3.0) if idx >= 7 else 1.0)])
		lit.append([age, Color(FR[idx], 0.18 * k if idx < 6 else 0.0)])
	var sz := []
	for s in samples:
		s.size = s.size * 0.675     # dot4 is 4 px across: the ball's radius is 2 px / 1.35 a unit of scale
	var curve_pts := []
	for i in 13:
		var age := i / 12.0
		curve_pts.append([age, (0.55 + 0.45 * minf(1.0, age * 7.0)) * (1.0 - age * 0.55)])
	var oo := thrown(samples, {"one_shot": true, "explosiveness": 1.0, "texture": "dot4", "ramp": data(heat), "scale_curve": curve_pts,
		"gravity": Vector2(0, -95), "drag": 4.0, "emitting": false})
	oo.merge(o, true)
	var p := particles(name, oo)
	p.material = puff_mat(1.0)
	# its light: a soft glow round each, in its colour, while it's hot
	var q := twin(p, {"texture": "glow32", "scale": 0.26, "modulate": Color(1, 1, 1, 0.6)})
	var qm: ParticleProcessMaterial = q.process_material.duplicate()
	qm.color_ramp = data(lit)
	q.process_material = qm
	return p


## SMOKE puffs (P.SMOKE, BIG): who 0 their own grey ramp, 0.5 dark, 1 dust; the samples' size is the original's size.
func smoke_puffs(name: String, samples: Array, who: float, o: Dictionary) -> GPUParticles2D:
	var cols := []
	for i in 17:
		var age := i / 16.0
		var k := 1.0 - age
		cols.append([age, Color(age, 0, who, minf(1.0, age * 12.0) * minf(1.0, k * 2.4) * 0.7)])
	var curve_pts := []
	for i in 17:
		var age := i / 16.0
		curve_pts.append([age, 0.65 + minf(1.0, age * 2.5) * 0.45 + age * 0.5])
	for s in samples:
		s.size = s.size * 0.5         # dot4: a puff of radius r is r / 2 units of scale
	var oo := thrown(samples, {"layer": "soft", "back": true, "texture": "dot4", "ramp": data(cols), "scale_curve": curve_pts,
		"gravity": Vector2(0, -23), "drag": 1.4, "turbulence": {"strength": 1.0, "scale": 3.0, "influence": [0.004, 0.01]}})
	oo.merge(o, true)
	var p := particles(name, oo)
	p.material = puff_mat(0.0)
	return p


## The original's FIRE flight (buoyancy, a lick from side to side, drag), at its 120 Hz: where and how fast it dies.
func fire_death(s: Dictionary) -> Dictionary:
	var x: float = s.p.x
	var y: float = s.p.y
	var vx: float = s.v.x
	var vy: float = s.v.y
	var seed := rng.randf() * 100.0
	var dt := 1.0 / 120.0
	var t := 0.0
	while t < s.life:
		vy -= 95.0 * dt
		vx += sin((s.t0 + t) * 17.0 + seed) * 30.0 * dt
		vx -= vx * 5.0 * dt
		vy -= vy * 3.2 * dt
		x += vx * dt
		y += vy * dt
		t += dt
	return {"p": Vector2(x, y), "v": Vector2(vx, vy), "t": s.t0 + s.life}


func _fire() -> void:
	var core := []
	for i in 5:
		core.append({"p": Vector2(r(-2.5, 2.5), Y + r(-2.5, 2.5)), "v": Vector2(r(-20, 20), r(-40, -10)), "life": r(0.18, 0.3),
			"size": r(RAD * 0.4, RAD * 0.55), "t0": 0.0})
	var burst := []
	var smokes := []
	for i in roundi(28 * POWER):
		var a := r(0, TAU)
		var d := r(0, RAD * 0.55)
		var sp := r(40, 210) * POWER
		var s := {"p": Vector2(cos(a) * d, Y + sin(a) * d), "v": Vector2(cos(a) * sp, sin(a) * sp * 0.8 - 40.0), "life": r(0.55, 1.15),
			"size": r(RAD * 0.22, RAD * 0.46), "t0": 0.0}
		burst.append(s)
		if rng.randf() < 0.45:
			smokes.append(s)
	var column := []
	for i in 5:
		var s := {"p": Vector2(r(-RAD * 0.25, RAD * 0.25), Y), "v": Vector2(r(-12, 12), r(-180, -100)), "life": r(0.8, 1.3),
			"size": r(RAD * 0.24, RAD * 0.36), "t0": r(0, 0.1)}
		column.append(s)
		if rng.randf() < 0.6:
			smokes.append(s)
	# the smoke each fire puff that SMOKES leaves where it dies, BIG: from its flight, replayed
	var after := []
	var t_lo := 1e9
	var t_hi := 0.0
	for s in smokes:
		var e := fire_death(s)
		after.append({"p": e.p, "v": e.v * 0.6 - Vector2(0, 6), "life": r(1.3, 2.3), "size": s.size * 0.85})
		t_lo = minf(t_lo, e.t)
		t_hi = maxf(t_hi, e.t)
	var ps := fire_puffs("FireCore", core, {})
	emit(ps, 0.0)
	ps = fire_puffs("Fire", burst, {"drag": 2.5})
	emit(ps, 0.0)
	ps = fire_puffs("FireColumn", column, {"explosiveness": 0.0})
	# (five puffs over their first tenth of a second)
	ps.lifetime = 1.3
	ps.one_shot = true
	ps.explosiveness = 0.92
	emit(ps, 0.0)
	var sm := smoke_puffs("FireSmoke", after, 0.0, {"one_shot": true, "explosiveness": 0.0, "emitting": false})
	# its puffs come out over the time the fires die
	sm.explosiveness = 1.0 - (t_hi - t_lo) / sm.lifetime
	emit(sm, t_lo)


func _smoke() -> void:
	var dark := []
	for i in 5:
		var a := r(0, TAU)
		var d := r(RAD * 0.1, RAD * 0.5)
		dark.append({"p": Vector2(cos(a) * d, Y + sin(a) * d), "v": Vector2(cos(a) * 30.0, sin(a) * 20.0 - 30.0), "life": r(0.9, 1.5),
			"size": r(RAD * 0.15, RAD * 0.26)})
	var p := smoke_puffs("DarkSmoke", dark, 0.5, {"one_shot": true, "explosiveness": 0.9, "emitting": false})
	emit(p, 0.06)
	var col := []
	for i in roundi(10 * POWER):
		var a := r(0, TAU)
		var d := r(0, RAD * 0.7)
		var sp := r(15, 100)
		col.append({"p": Vector2(cos(a) * d, Y + sin(a) * d), "v": Vector2(cos(a) * sp, sin(a) * sp * 0.6 - 35.0), "life": r(1.8, 2.8),
			"size": r(RAD * 0.26, RAD * 0.44)})
	p = smoke_puffs("Smoke", col, 0.0, {"one_shot": true, "explosiveness": 0.88, "emitting": false, "drag": 0.8})
	emit(p, 0.12)
	# the ground's part: dust rolling out both ways along the floor, and a column of dust thrown up
	var roll := []
	for i in roundi(RAD * 0.5):
		var s := sgn()
		roll.append({"p": Vector2(s * r(0, RAD * 0.6), -r(1, 5 + RAD * 0.04)), "v": Vector2(s * r(3, 9.5) * RAD, -r(2, 15)),
			"life": r(1.1, 2.0), "size": r(4, 7) + RAD / 6.0})
	p = smoke_puffs("DustRoll", roll, 1.0, {"one_shot": true, "explosiveness": 0.97, "emitting": false, "drag": 0.8})
	emit(p, 0.0)
	var up := []
	for i in roundi(1.6 * 12):
		up.append({"p": Vector2(r(-0.3, 0.3) * RAD, -r(2, RAD * 0.6)), "v": Vector2(r(-15, 15), -r(60, 190) * 1.6 * 0.6),
			"life": r(1.6, 2.6), "size": r(5, 9) + RAD / 7.0})
	# (Godot's friction is quadratic: a lighter one lets the fast ones climb as high as the original's drag does)
	p = smoke_puffs("DustColumn", up, 1.0, {"one_shot": true, "explosiveness": 0.94, "emitting": false, "drag": 0.7})
	emit(p, 0.0)


# ------------------------------------------------------------------ sparks, embers, brands

func _sparks_and_embers() -> void:
	var sp := []
	for i in roundi(80 * POWER):
		var a := r(0, TAU)
		var v := r(140, 380) * POWER
		sp.append({"p": Vector2(0, Y), "v": Vector2(cos(a) * v, sin(a) * v - 70.0), "life": r(0.18, 0.6), "size": 1.0})
	var sparks := particles("Sparks", thrown(sp, {"one_shot": true, "explosiveness": 1.0, "texture": "streak6", "align": true,
		"gravity": Vector2(0, 950 * 0.45), "drag": 3.3, "collide": {"bounce": 0.45, "friction": 0.3},
		"ramp": gradient([F[6], F[5], F[3], F[2]], [0.0, 0.4, 0.7, 0.85])}))
	twin(sparks, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.4)})
	var em := []
	for i in roundi(40 * POWER):
		var a := r(0, TAU)
		var v := r(30, 150)
		em.append({"p": Vector2(cos(a) * RAD * 0.4, Y + sin(a) * RAD * 0.4), "v": Vector2(cos(a) * v, sin(a) * v - 75.0),
			"life": r(1.2, 2.6), "size": 1.0})
	var embers := particles("Embers", thrown(em, {"one_shot": true, "explosiveness": 1.0, "texture": "dot1",
		"gravity": Vector2(0, -26), "drag": 1.0,
		"ramp": gradient([F[6], F[5], F[3], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.8, 0.9]),
		"alpha_curve": [[0, 1], [0.75, 1], [0.78, 0], [0.82, 1], [0.86, 0], [0.9, 1], [0.94, 0], [1, 0]]}))
	twin(embers, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})


## The few burning brands: each flies the original's arc (keyed), a burning chunk trailing flame, and where it lands
## a small fire burns for a second or so.
func _brands() -> void:
	# (the original's own draw lands three of them, at about -41, +45 and +57: these are drawn from the same spread
	# until they land there)
	var targets := [-41.0, 45.0, 57.0, 999.0]
	for i in targets.size():
		var fl := {}
		for attempt in 400:
			fl = _fly(r(-1.35, 1.35), r(170, 330), r(0.7, 1.3))
			if targets[i] > 900.0:
				if not fl.landed:
					break
			elif fl.landed and absf(fl.x - targets[i]) < 2.5:
				break
		var path: Array = fl.path
		var t: float = fl.t
		var x: float = fl.x
		var landed: bool = fl.landed
		var g := group("Brand%d" % i)
		key(g, "position", path)
		show(g, 0.0, t)
		var chunk := ring("Chunk", 3, {"radius": 1.6, "color": Color(HOT[3])}, {"parent": g})
		chunk.z_index = 1
		var lit := glow("ChunkLight", 8, {"radius": 7, "color": Color(HOT[2]), "alpha": 0.45}, {"parent": g})
		lit.z_index = 2
		var trail := particles("Trail%d" % i, {"parent": g, "amount": 18, "lifetime": 0.32, "life_random": 0.5, "texture": "dot4",
			"dir": -90, "spread": 40, "speed": [8, 14], "gravity": Vector2(0, -95), "drag": 5.0,
			"scale": [0.9 * 0.675, 1.7 * 0.675], "scale_curve": [[0, 0.55], [0.15, 1.0], [1, 0.45]],
			"ramp": data([[0.0, Color(0.05, 0, 0, 1)], [0.3, Color(0.5, 0, 0, 1)], [0.7, Color(0.8, 0, 0, 1)], [1.0, Color(0.95, 0, 0, 0.3)]])})
		trail.material = puff_mat(1.0)
		emit(trail, 0.0, t)
		if landed:
			_blaze(i, x, t, r(0.9, 1.5), r(0.55, 0.85))


## A brand's flight from the blast's heart (the original's: heavy, a little drag across): its keyed path, how long it
## flew, whether and where it landed.
func _fly(dev: float, v: float, life: float) -> Dictionary:
	var dt := 1.0 / 120.0
	var a := -PI / 2.0 + dev
	var x := 0.0
	var y := Y
	var vx := cos(a) * v
	var vy := sin(a) * v
	var t := 0.0
	var path := [[0.0, Vector2(x, y)]]
	var step := 0
	while t < life:
		vy += 950.0 * 0.8 * dt
		vx -= vx * 0.9 * dt
		var ny := y + vy * dt
		x += vx * dt
		t += dt
		step += 1
		if vy > 0.0 and y <= 0.0 and ny >= 0.0:
			path.append([t, Vector2(x, 0)])
			return {"path": path, "t": t, "x": x, "landed": true}
		y = ny
		if step % 2 == 0:
			path.append([t, Vector2(x, y)])
	return {"path": path, "t": t, "x": x, "landed": false}


## A little fire burning where a brand landed (the original's Blazes): puffs rising off a hot spot for `life` s.
func _blaze(i: int, x: float, t0: float, life: float, power: float) -> void:
	var p := particles("Blaze%d" % i, {"at": Vector2(x, -1), "back": true, "amount": 12, "lifetime": 0.6, "life_random": 0.5,
		"texture": "dot4", "emit": {"box": Vector2(1.5, 0.5)}, "dir": -90, "spread": 15, "speed": [12, 30], "gravity": Vector2(0, -95),
		"drag": 4.0, "scale": [1.2 * power * 0.675, 2.8 * power * 0.675], "scale_curve": [[0, 0.55], [0.15, 1.0], [1, 0.45]],
		"ramp": data([[0.0, Color(0.1, 0, 0, 1)], [0.3, Color(0.45, 0, 0, 1)], [0.7, Color(0.78, 0, 0, 1)], [1.0, Color(0.95, 0, 0, 0.3)]]),
		"emitting": false})
	p.material = puff_mat(1.0)
	emit(p, t0, t0 + life)
	key(p, "amount_ratio", [[t0, 1.0], [t0 + life * 0.3, 1.0], [t0 + life, 0.35]])
	var spot := rect("BlazeSpot%d" % i, Rect2(roundf(x), -1, 1, 1), Color(HOT[1]), {"back": true})
	var fl := []
	for j in int(life * 15.0):
		fl.append([t0 + j / 15.0, Color(HOT[1]) if (j % 2 == 0 and j < life * 15.0 * 0.6) else Color(HOT[3])])
	key(spot, "color", fl, "nearest")
	show(spot, t0, t0 + life)
	var g := glow("BlazeLight%d" % i, 12, {"radius": 6 + 5 * power, "color": Color(HOT[2]), "alpha": 0.0}, {"at": Vector2(x, -1)})
	key(g, "material:shader_parameter/alpha", [[t0 - 0.001, 0.0], [t0, 0.3 * power], [t0 + life, 0.0]])


# ------------------------------------------------------------------ rocks, grit, dust where rocks land

func _earth() -> void:
	var rocks := []
	var rest := []
	var dt := 1.0 / 120.0
	for i in 26:
		var s := {"p": Vector2(r(-0.4, 0.4) * RAD, -3), "v": Vector2(r(-9, 9) * RAD * 0.25, -r(7, 16) * RAD * 0.9),
			"life": r(1.8, 2.6), "size": float(rng.randi_range(1, 3))}
		rocks.append(s)
		# where and when it comes to rest: the original's bounce, replayed
		var x: float = s.p.x
		var y: float = s.p.y
		var vx: float = s.v.x
		var vy: float = s.v.y
		var t := 0.0
		while t < s.life:
			vy += 950.0 * dt
			vx -= vx * 0.4 * dt
			vy -= vy * 0.4 * dt
			x += vx * dt
			y += vy * dt
			t += dt
			if y >= 0.0 and vy > 0.0:
				y = 0.0
				if vy > 70.0:
					vy = -vy * 0.3
					vx *= 0.7
				else:
					rest.append({"x": x, "t": t})
					break
	var big := []
	var small := []
	for s in rocks:
		(big if s.size > 1.5 else small).append(s)
	for pair in [["Rocks", big, "disc3"], ["Pebbles", small, "dot2"]]:
		var list: Array = pair[1]
		for s in list:
			s.size = 1.0
		var p := particles(pair[0], thrown(list, {"one_shot": true, "explosiveness": 1.0, "texture": pair[2], "gravity": Vector2(0, 950),
			"drag": 0.4, "spin": [-900, 900], "initial": gradient([ST.light, ST.body, ST.body, ST.shade]),
			"alpha_curve": [[0, 1], [0.84, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.7, "size": 2.0}}))
		# a dark rim round each
		var rim := twin(p, {"layer": "color", "name": pair[0] + "Rim", "texture": "disc5" if pair[2] == "disc3" else "disc4"})
		rim.process_material = rim.process_material.duplicate()
		rim.process_material.color_initial_ramp = gradient([Color("#1a1422")])
		rim.z_index = 0
	# grit thrown up in a fan, falling back, gone half a second after it lands
	for pair in [["Grit", 63, "dot1"], ["Clods", 52, "dot2"]]:
		var g := []
		for i in pair[1]:
			var u := r(-1, 1)
			var a := -PI / 2.0 + u * 0.5
			var v := r(5, 15) * RAD * (1.0 - 0.45 * absf(u))
			g.append({"p": Vector2(u * 0.25 * RAD, -1), "v": Vector2(cos(a) * v, sin(a) * v), "life": r(0.7, 1.1), "size": 1.0})
		particles(pair[0], thrown(g, {"one_shot": true, "explosiveness": 1.0, "texture": pair[2], "gravity": Vector2(0, 950),
			"drag": 0.8, "initial": gradient([ST.light, ST.body, ST.body, ST.shade]), "alpha_curve": [[0, 1], [0.85, 1], [1, 0]],
			"collide": {"bounce": 0.1, "friction": 1.0}}))
	# dust kicked up where rocks come to rest
	if rest.size() > 0:
		var pts := PackedVector2Array()
		var t_lo := 1e9
		var t_hi := 0.0
		for e in rest:
			pts.append(Vector2(e.x, -0.5))
			t_lo = minf(t_lo, e.t)
			t_hi = maxf(t_hi, e.t)
		var dust := particles("RockDust", {"layer": "soft", "back": true, "amount": 3 * rest.size(), "lifetime": 0.65,
			"life_random": 0.5, "texture": "disc5", "emit": {"points": pts}, "dir": -90, "spread": 80, "speed": [8, 35],
			"drag": 4.0, "scale": [0.5, 1.1], "scale_curve": [[0, 0.6], [1, 1.5]], "color": Color(ST.dust, 0.7),
			"alpha_curve": [[0, 1], [0.4, 0.6], [1, 0]], "emitting": false})
		emit(dust, t_lo, maxf(t_lo + 0.1, t_hi))
