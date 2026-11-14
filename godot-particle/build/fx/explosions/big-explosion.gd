# reimagined-from: src/fx/explosions/big-explosion.js@c65b9b28822279573830d7d6eb2ba4afbd7e5de4
# Big explosion: a huge ground blast in three beats: a white dome, a rolling fireball that climbs into a mushrooming
# smoke column, heavy rocks, and fires left burning.
# The rolling fireball is a shader of its own (_big-explosion_plume.gdshader: the original's vortex-ring Plume, 42
# lobes from a data texture, each a sky-lit ball burning in its heart and cooling to smoke, all driven by one keyed
# clock); the column feeding it is GPU particles drawn as the same lobes (_big-explosion_lobe.gdshader, mode 0), and
# every fire puff is a particle drawn as the original's fire ball (mode 1). The floor scorch is a shader
# (_big-explosion_scorch.gdshader); the dome, shock rings, air flashes and the band rolling along the floor are ring
# shaders keyed from the original's curves; the flare is Line2D rays; sparks, embers, brands, grit, rocks, dust and
# smoke are bursts on the original's three beats; fires burn on where the brands land; lights are keyed glows.
extends "res://addons/pixelfx_particles/core/build.gd"

const RAD := 30.0
const POWER := 1.45
const SM := ["#83777f", "#6e6470", "#575060", "#3f3947", "#29242f"]
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const SOOT := Color("#0d0a12")
const SOOT2 := Color("#17121d")
const OUTLINE := Color("#1a1422")
const LOBE := "res://addons/pixelfx_particles/fx/explosions/_big-explosion_lobe.gdshader"
# the plume (the original's Plume options)
const PL := {"x": 0.0, "y": -34.0, "rise": 118.0, "tau": 1.25, "drift": 4.0, "tube": [9.0, 21.0], "ring": [2.0, 19.0], "grow": 1.0,
	"n": 42, "size": [6.0, 11.0], "swell": 0.9, "spin": 2.6, "spin_tau": 1.7, "heat": 1.2, "cool": 0.42, "under": 0.5, "tilt": 0.22,
	"squash": 0.72, "fade": [4.4, 6.4], "spread": 22.0}
const P0 := 0.08     # the plume's clock starts here

var F: PackedColorArray
var FR: PackedColorArray
var st := {}
var rng := RandomNumberGenerator.new()


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func sc(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))


## The plume's centre and radii at effect time t: Vector4(y, tube, ring, g).
func shape_at(t: float) -> Vector4:
	var u := maxf(0.0, t - P0)
	var g := 1.0 - exp(-u / PL.grow)
	return Vector4(PL.y - PL.rise * (1.0 - exp(-u / PL.tau)) - PL.drift * u, PL.tube[0] + (PL.tube[1] - PL.tube[0]) * g,
		PL.ring[0] + (PL.ring[1] - PL.ring[0]) * g, g)


func hot_at(t: float) -> float:
	return clampf(PL.heat - PL.cool * maxf(0.0, t - P0) + 0.3, 0.0, 1.0)


## Keys prop on node from f(t) every 1/hz s between t0 and t1.
func sample(node: Node, prop: String, f: Callable, t0: float, t1: float, interp := "linear", hz := 30.0) -> void:
	var keys := []
	var n := int(ceil((t1 - t0) * hz))
	for i in n + 1:
		var t := minf(t1, t0 + i / hz)
		keys.append([t, f.call(t)])
	key(node, prop, keys, interp)


## A smooth gradient that carries data (heat, glow, opacity) to a particle shader, not colours: kept off the palette.
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


func lobe_mat(mode: float, soft_layer: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(LOBE)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("fr", FR)
	m.set_shader_parameter("sm", PackedColorArray(SM.map(func(c): return Color(c))))
	m.set_shader_parameter("translucent", soft_layer)
	return m


## FIRE puffs (the original's fire balls): radius [min, max] px; they cool down the fire ramp over their life.
func puffs(name: String, radius: Array, o: Dictionary) -> GPUParticles2D:
	var heat := []
	for i in 9:
		var a := i / 8.0
		var al := 1.0 if a < 0.667 else clampf((1.0 - a) * 3.0, 0.0, 1.0)
		heat.append([a, Color(minf(0.999, pow(a, 0.62) * o.get("hot", 1.0)), 1, 1, al)])
	var oo := {"texture": "dot4", "one_shot": true, "explosiveness": 1.0, "scale": [2.7 * radius[0] / 4.0, 2.7 * radius[1] / 4.0],
		"scale_curve": [[0, 0.55], [0.14, 0.92], [0.5, 0.72], [1, 0.45]], "ramp": data(heat), "emitting": false}
	oo.merge(o, true)
	oo.erase("hot")
	var p := particles(name, oo)
	p.material = lobe_mat(1.0, true)
	return p


func make() -> void:
	F = root.ramps.palette
	FR = PackedColorArray([F[7], F[6], F[5], F[4], F[3], F[2], F[1], F[1].lerp(F[0], 0.5), F[0]])
	var HR := PackedColorArray(Array(FR).slice(0, 8))
	HR.append(FR[8].lerp(SOOT, 0.3))
	HR.append(FR[8].lerp(SOOT, 0.65))
	var stone := Color(meta.options.stone)
	st = {"light": sc(stone, 1.35).lerp(Color.WHITE, 0.08), "body": stone, "shade": sc(stone, 0.64),
		"dust": sc(stone, 1.2).lerp(Color8(150, 140, 150), 0.3)}
	for c in SM + SMOKE_RAMP:
		keep_colour(Color(c))
	for c in [SOOT, SOOT2, OUTLINE, st.light, st.shade, st.dust, FR[7], HR[8], HR[9]]:
		keep_colour(c)
	var WARM := F[3].lerp(F[6], 0.45)
	rng.seed = 11
	var D: float = meta.duration
	ground()

	# ---- behind: the scorch, the far half of the band, smoke and dust, the column, the plume, the fires left burning
	var scorch := shape("Scorch", load("res://addons/pixelfx_particles/fx/explosions/_big-explosion_scorch.gdshader"), Vector2(112, 4),
		{"hr": HR, "soot": SOOT, "soot2": SOOT2, "rx0": 52.0, "cool": 3.4, "rows": 3.0}, {"at": Vector2(0, 2), "back": true})
	# core shape() hands colour arrays over as PackedVector4Array, which the scene saves as null: set them back as colours
	scorch.material.set_shader_parameter("hr", HR)
	key(scorch, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	sample(scorch, "material:shader_parameter/fade", func(t: float): return 1.0 - smooth(D - 1.6, D - 0.3, t), 0.0, D)
	band(true)

	_smoke()
	_column()
	_plume()
	_blazes()

	# ---- in front: the band's near half, the dome, rocks, fire, sparks, flare, rings, flashes, light
	band(false)
	_dome()
	_rocks()
	_blast("Main", Vector2(0, -9), RAD, POWER, true, 0.0)
	_blast("Air1", Vector2(-17, -30), 17.0, 0.9, false, 0.13)
	_blast("Air2", Vector2(15, -46), 15.0, 0.8, false, 0.25)
	_flare()
	_rings()

	# light: the blast's flares, the fireball's glow on the air and on the floor
	for L in [[Vector2(0, -33), 72.0, WARM, 0.6 * POWER, 0.8, 0.0], [Vector2(0, -21), 44.0, Color.WHITE, 0.6, 0.1, 0.0],
			[Vector2(-17, -30), 17.0 * 3.4, WARM, 0.54, 0.8, 0.13], [Vector2(-17, -30), 27.0, Color.WHITE, 0.6, 0.1, 0.13],
			[Vector2(15, -46), 15.0 * 3.4, WARM, 0.48, 0.8, 0.25], [Vector2(15, -46), 24.0, Color.WHITE, 0.6, 0.1, 0.25]]:
		var g := glow("Light", L[1] + 2, {"radius": L[1], "color": L[2], "alpha": 0.0}, {"at": L[0]})
		var r0: float = L[1]
		var k0: float = L[3]
		var life: float = L[4]
		var t0: float = L[5]
		sample(g, "material:shader_parameter/radius", func(t: float): return r0 * (0.55 + 0.45 * clampf(1.0 - (t - t0) / life, 0.0, 1.0)), t0, t0 + life)
		sample(g, "material:shader_parameter/alpha", func(t: float):
			var k := 1.0 - (t - t0) / life
			return k0 * k * k if t >= t0 and k > 0.0 else 0.0, maxf(0.0, t0 - 0.034), t0 + life)
	# smoke and dust sit behind the column and the fireball, as the original draws them
	for n in root.get_children():
		if n is GPUParticles2D and n.material == soft and n.z_index == -2:
			n.z_index = -3
	var pool := glow("Pool", 152, {"radius": 150, "squash": 22.0 / 150.0, "color": F[3]}, {"at": Vector2(0, 1)})
	sample(pool, "material:shader_parameter/alpha", func(t: float):
		var fl := maxf(0.0, 1.0 - t / 0.9)
		return 0.24 * hot_at(t) + 0.5 * fl * fl, 0.0, 4.2)


## The band rolling out along the floor: far half behind, near half in front.
func band(far: bool) -> void:
	var cols := [F[6], F[3], st.light, st.body]
	var parts := [[0.0, 0.15, F[6]], [0.15, 0.4, F[3]], [0.4, 0.7, st.light], [0.7, 1.0, st.body]]
	for i in parts.size():
		var pr: Array = parts[i]
		var b := ring("Band%s%d" % ["Far" if far else "Near", i], 134, {"radius": 4.0, "thickness": 1.0, "squash": 0.16, "color": pr[2],
			"side": 1.0 if far else -1.0}, {"back": far})
		var u0: float = pr[0]
		var u1: float = pr[1]
		sample(b, "material:shader_parameter/radius", func(t: float):
			var k := t / 0.6
			var th := maxf(1.0, 6.0 * (1.0 - k))
			return 132.0 * out_cubic(k) - th * u0, 0.0, 0.6)
		sample(b, "material:shader_parameter/thickness", func(t: float):
			var th := maxf(1.0, 6.0 * (1.0 - t / 0.6))
			return maxf(0.6, th * (u1 - u0)), 0.0, 0.6)
		sample(b, "material:shader_parameter/alpha", func(t: float): return clampf((1.15 - t / 0.6) * (1.2 if u0 < 0.4 else 1.15 - u0), 0.0, 1.0), 0.0, 0.6)
		show(b, 0.0, 0.6)


func _dome() -> void:
	# a dome of white-hot air on the floor that cools into the fire, and a white light over it
	var parts := [["DomeRim", 1.0, F[6], F[5]], ["DomeBody", 0.8, Color.WHITE, F[6]], ["DomeCore", 0.5, Color.WHITE, F[6]]]
	for pr in parts:
		var params := {"radius": 44.0 * pr[1], "color": pr[2], "side": 1.0}
		if pr[0] == "DomeRim":
			params.edge = 1.4
			params.edge_color = F[2]
		var d := ring(pr[0], 46, params)
		var f: float = pr[1]
		var hot: Color = pr[2]
		var cooler: Color = pr[3]
		var limit := 0.2 if pr[0] == "DomeCore" else 0.45
		sample(d, "material:shader_parameter/radius", func(t: float): return (44.0 if t < 0.04 else 38.0 - (t - 0.04) * 120.0) * f, 0.0, 0.11, "nearest")
		sample(d, "material:shader_parameter/color", func(t: float):
			var k := 1.0 if t < 0.04 else 1.0 - (t - 0.04) / 0.07
			return hot if k > limit else cooler, 0.0, 0.11, "nearest")
		show(d, 0.0, 0.11)
	var white := glow("DomeLight", 70, {"radius": 68, "color": Color.WHITE, "alpha": 0.6}, {"at": Vector2(0, -30)})
	show(white, 0.0, 0.04)


func _flare() -> void:
	var g := gradient([Color.WHITE, F[6], F[5]], [0.0, 0.35, 0.7])
	for i in 8:
		var an := i * PI / 4.0
		var lk := 1.0 if i % 4 == 0 else (0.6 if i % 2 == 0 else 0.3)
		var dv := Vector2(cos(an), sin(an))
		var ln := line("Flare%d" % i, PackedVector2Array([Vector2(0, -14), Vector2(0, -14)]), {"width": 1, "gradient": g})
		sample(ln, "points", func(t: float):
			var L := 70.0 * pow(maxf(0.0, 1.0 - t / 0.24), 1.4) * lk
			return PackedVector2Array([Vector2(0, -14), Vector2(0, -14) + dv * maxf(L, 0.5)]), 0.0, 0.24, "nearest")
		show(ln, 0.0, 0.24)


func _rings() -> void:
	# the main shock: a shell racing out over the floor (its upper half), light hugging it
	var shock := ring("Shock", 116, {"radius": 34, "thickness": 3.5, "color": F[6], "side": 1.0})
	sample(shock, "material:shader_parameter/radius", func(t: float): return 34.0 + 80.0 * out_cubic(t / 0.5), 0.0, 0.5)
	sample(shock, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 3.0 * (1.0 - t / 0.5) + 0.5), 0.0, 0.5)
	sample(shock, "material:shader_parameter/alpha", func(t: float): return minf(1.0, (1.0 - t / 0.5) * 1.6), 0.0, 0.5)
	sample(shock, "material:shader_parameter/color", func(t: float):
		var u := t / 0.5
		return F[6] if u < 0.3 else (F[5] if u < 0.6 else F[3]), 0.0, 0.5, "nearest")
	show(shock, 0.0, 0.5)
	var shell := shape("ShockLight", load("res://addons/pixelfx_particles/fx/explosions/_big-explosion_dome.gdshader"), Vector2(250, 250),
		{"radius": 34, "width": 6, "color": F[4], "alpha": 0.35})
	sample(shell, "material:shader_parameter/radius", func(t: float): return 34.0 + 80.0 * out_cubic(t / 0.5), 0.0, 0.5)
	sample(shell, "material:shader_parameter/alpha", func(t: float): return 0.35 * (1.0 - t / 0.5), 0.0, 0.5)
	show(shell, 0.0, 0.5)
	# the later beats: a flash and two rings in the air
	for b in [[Vector2(-17, -30), 17.0, 0.13, "1"], [Vector2(15, -46), 15.0, 0.25, "2"]]:
		var at: Vector2 = b[0]
		var rad: float = b[1]
		var t0: float = b[2]
		var fl := ring("AirFlash" + b[3], rad * 1.05 + 3, {"radius": rad * 1.05, "color": F[6], "edge": 1.2, "edge_color": F[2]}, {"at": at})
		var core := ring("AirCore" + b[3], rad + 2, {"radius": rad * 0.63, "color": Color.WHITE}, {"at": at})
		for n in [fl, core]:
			var f := 1.0 if n == fl else 0.6
			var hot: Color = F[6] if n == fl else Color.WHITE
			var cool: Color = F[5] if n == fl else F[6]
			sample(n, "material:shader_parameter/radius", func(t: float): return rad * 1.05 * (0.8 + 0.2 * (1.0 - (t - t0) / 0.06)) * f, t0, t0 + 0.06, "nearest")
			sample(n, "material:shader_parameter/color", func(t: float): return hot if 1.0 - (t - t0) / 0.06 > 0.45 else cool, t0, t0 + 0.06, "nearest")
			show(n, t0, t0 + 0.06)
		for rr in [[0.45, 2.7, 0.36, 3.0, F[5]], [0.3, 1.6, 0.24, 1.8, F[3]]]:
			var r0: float = rad * rr[0]
			var r1: float = rad * rr[1]
			var life: float = rr[2]
			var th: float = rr[3]
			var rg := ring("AirRing" + b[3] + str(rr[1]), r1 + 2, {"radius": r0, "thickness": th, "color": rr[4]}, {"at": at})
			sample(rg, "material:shader_parameter/radius", func(t: float): return r0 + (r1 - r0) * (1.0 - pow(1.0 - (t - t0) / life, 3.0)), t0, t0 + life)
			sample(rg, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, th * (1.0 - (t - t0) / life) + 0.4), t0, t0 + life)
			sample(rg, "material:shader_parameter/alpha", func(t: float): return minf(1.0, (1.0 - (t - t0) / life) * 1.6), t0, t0 + life)
			show(rg, t0, t0 + life)


## One detonation at `at`: fire puffs, smoke, sparks and embers; the main one throws brands, dust and grit as well.
func _blast(nm: String, at: Vector2, rad: float, power: float, main: bool, t0: float) -> void:
	var down := 0.25 if main else PI
	var core := puffs(nm + "Core", [rad * 0.4, rad * 0.55], {"at": at, "amount": 5, "lifetime": 0.3, "randomness": 0.4,
		"emit": {"box": Vector2(2.5, 2.5)}, "dir": -90, "spread": 30, "speed": [10, 40], "gravity": Vector2(0, -95), "damping": [60, 120]})
	emit(core, t0)
	var fire := puffs(nm + "Fire", [rad * 0.22, rad * 0.46], {"at": at, "amount": int(round(26 * power)), "lifetime": 1.15, "randomness": 0.5,
		"emit": {"circle": rad * 0.4}, "dir": -90, "spread": rad_to_deg(PI / 2 + down) if main else 180.0, "speed": [40 * power, 200 * power],
		"gravity": Vector2(0, -95), "damping": [500, 900]})
	emit(fire, t0)
	# smoke: a dark puff from the heart, then big smoke rolling up off the fire
	var dark := gradient([Color("#221d26", 0.0), Color("#221d26", 0.4), Color(SMOKE_RAMP[2], 0.35), Color(SMOKE_RAMP[3], 0.2), Color(SMOKE_RAMP[4], 0.0)], [0.0, 0.1, 0.4, 0.75, 0.97])
	var sm_dark := particles(nm + "SmokeDark", {"layer": "soft", "back": true, "at": at, "amount": 5, "lifetime": 1.5, "one_shot": true,
		"explosiveness": 0.85, "randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"circle": rad * 0.4}, "dir": -90, "spread": 70,
		"speed": [20, 40], "damping": [20, 40], "gravity": Vector2(0, -23), "scale": [rad * 0.15 / 6.5, rad * 0.26 / 6.5],
		"scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": dark})
	emit(sm_dark, t0 + 0.06)
	var big := gradient([Color(SMOKE_RAMP[0], 0.0), Color(SMOKE_RAMP[0], 0.55), Color(SMOKE_RAMP[1], 0.5), Color(SMOKE_RAMP[2], 0.38),
		Color(SMOKE_RAMP[3], 0.18), Color(SMOKE_RAMP[4], 0.0)], [0.0, 0.08, 0.25, 0.5, 0.7, 0.9])
	var sm_big := particles(nm + "Smoke", {"layer": "soft", "back": true, "at": at + Vector2(0, -6), "amount": int(round(8 * power)) + 6,
		"lifetime": 2.4, "one_shot": true, "explosiveness": 0.7, "randomness": 0.4, "emitting": false, "texture": "disc13",
		"emit": {"circle": rad * 0.6}, "dir": -90, "spread": 80, "speed": [10, 60], "damping": [30, 60], "gravity": Vector2(0, -10),
		"scale": [rad * 0.26 / 6.5, rad * 0.4 / 6.5], "scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": big})
	emit(sm_big, t0 + 0.25)
	if main:
		# the smoke the dying fire leaves, hanging round the column's middle
		var mid := particles("SmokeMid", {"layer": "soft", "back": true, "at": at + Vector2(0, -30), "amount": 14, "lifetime": 2.2,
			"one_shot": true, "explosiveness": 0.6, "randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(30, 22)},
			"dir": -90, "spread": 90, "speed": [5, 30], "damping": [10, 20], "gravity": Vector2(0, -12), "scale": [1.3, 2.0],
			"scale_curve": [[0, 0.65], [0.4, 1.2], [1, 1.5]], "ramp": big})
		emit(mid, t0 + 0.55)
	var sparks := particles(nm + "Sparks", {"at": at, "amount": int(round(80 * power)), "lifetime": 0.65, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "emitting": false, "texture": "streak6", "align": true, "spread": 180, "speed": [170, 470 if main else 380],
		"damping": [300, 500], "gravity": Vector2(0, 430), "ramp": gradient([F[6], F[5], F[3], F[2]], [0.0, 0.4, 0.7, 0.85]),
		"collide": {"bounce": 0.45, "friction": 0.3}})
	emit(sparks, t0)
	var spark_light := particles(nm + "SparkLight", {"layer": "light", "at": at, "amount": int(round(80 * power)), "lifetime": 0.65, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.6, "emitting": false, "texture": "glow8", "modulate": Color(1, 1, 1, 0.35)})
	spark_light.process_material = sparks.process_material
	spark_light.seed = sparks.seed
	emit(spark_light, t0)
	var embers := particles(nm + "Embers", {"at": at, "amount": int(round(15 * power)), "lifetime": 2.2, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.5, "emitting": false, "texture": "dot1", "emit": {"ring": [rad * 0.4, rad * 0.3]}, "dir": -90, "spread": 180,
		"speed": [30, 150], "damping": [40, 80], "gravity": Vector2(0, -30),
		"ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.97]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})
	emit(embers, t0)
	if not main:
		return
	# burning brands that land and keep the ground on fire
	var brands := particles("Brands", {"at": at, "amount": 14, "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "disc3", "dir": -90, "spread": rad_to_deg(1.3), "speed": [160, 340], "damping": [60, 120], "gravity": Vector2(0, 760),
		"ramp": gradient([F[6], F[5], F[3]], [0.0, 0.3, 0.6]), "collide": {"hide": true, "size": 2}})
	emit(brands, t0)
	var brand_trail := particles("BrandTrail", {"at": at, "amount": 14, "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak12", "align": true, "modulate": Color(1, 1, 1, 0.9), "collide": {"hide": true, "size": 2}})
	brand_trail.process_material = brands.process_material.duplicate()
	brand_trail.process_material.color_ramp = gradient([F[3], F[2], F[1]], [0.0, 0.4, 0.8])
	brand_trail.seed = brands.seed
	emit(brand_trail, t0)
	var brand_light := particles("BrandLight", {"layer": "light", "at": at, "amount": 14, "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "glow16", "modulate": Color(1, 0.7, 0.4, 0.45)})
	brand_light.process_material = brands.process_material
	brand_light.seed = brands.seed
	emit(brand_light, t0)
	# the ground's part: grit thrown up in a fan, landing and lying a while
	var stones := gradient([st.light, st.body, st.body, st.shade])
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 150, "lifetime": 2.4, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(7, 0.5)}, "dir": -90, "spread": rad_to_deg(0.55), "speed": [120, 440],
		"damping": [20, 40], "gravity": Vector2(0, 950), "initial": stones, "alpha_curve": [[0, 1], [0.85, 1], [1, 0]],
		"collide": {"bounce": 0.2, "friction": 0.9}})
	emit(grit, t0)
	var grit2 := particles("GritBig", {"at": Vector2(0, -1), "amount": 40, "lifetime": 2.4, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "dot2", "emit": {"box": Vector2(7, 0.5)}, "dir": -90, "spread": rad_to_deg(0.55), "speed": [120, 400],
		"damping": [20, 40], "gravity": Vector2(0, 950), "initial": stones, "alpha_curve": [[0, 1], [0.85, 1], [1, 0]],
		"collide": {"bounce": 0.2, "friction": 0.9, "size": 2}})
	emit(grit2, t0)


func _smoke() -> void:
	var dust := Color(st.dust)
	# dust: rolling out along the floor both ways, a dust column up the middle, then dust drawn back in along the floor
	var roll := gradient([Color(dust, 0.0), Color(dust, 0.6), Color(dust.lerp(Color(SMOKE_RAMP[1]), 0.4), 0.55),
		Color(Color(SMOKE_RAMP[2]).lerp(dust, 0.3), 0.4), Color(SMOKE_RAMP[3], 0.0)], [0.0, 0.06, 0.35, 0.7, 0.97])
	for s in [-1, 1]:
		var r := particles("DustRoll%s" % ("L" if s < 0 else "R"), {"layer": "soft", "back": true, "at": Vector2(s * 6, -5), "amount": 9,
			"lifetime": 2.2, "one_shot": true, "explosiveness": 0.9, "randomness": 0.4, "texture": "disc13", "emit": {"box": Vector2(9, 2)},
			"dir": 90 - s * 90, "spread": 4, "speed": [90, 270], "damping": [200, 240], "gravity": Vector2(0, -12),
			"scale": [8.0 / 6.5, 12.0 / 6.5], "scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": roll})
		emit(r, 0.0)
	var col := particles("DustColumn", {"layer": "soft", "back": true, "at": Vector2(0, -12), "amount": 19, "lifetime": 2.0, "one_shot": true,
		"explosiveness": 0.85, "randomness": 0.4, "texture": "disc13", "emit": {"box": Vector2(9, 8)}, "dir": -90, "spread": 8,
		"speed": [55, 180], "damping": [120, 170], "gravity": Vector2(0, -8), "scale": [8.0 / 6.5, 12.0 / 6.5],
		"scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": roll})
	emit(col, 0.0)
	# afterwinds: dust drawn in along the floor toward the column, and dust boiling up its foot
	for s in [-1, 1]:
		var w := particles("Afterwind%s" % ("L" if s < 0 else "R"), {"layer": "soft", "back": true, "at": Vector2(s * 80, -3), "amount": 8,
			"lifetime": 1.9, "randomness": 0.4, "emitting": false, "texture": "disc9", "emit": {"box": Vector2(40, 1.5)}, "dir": 90 + s * 90,
			"spread": 6, "speed": [10, 30], "scale": [3.5 / 4.5, 5.5 / 4.5], "scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": roll})
		emit(w, 0.45, 3.1)
		key(w, "amount_ratio", [[0.45, 1.0], [2.2, 1.0], [3.1, 0.2]])
	var foot := particles("FootDust", {"layer": "soft", "back": true, "at": Vector2(0, -4), "amount": 7, "lifetime": 1.6, "randomness": 0.4,
		"emitting": false, "texture": "disc13", "emit": {"box": Vector2(5, 2.5)}, "dir": -90, "spread": 4, "speed": [40, 80],
		"damping": [10, 20], "gravity": Vector2(0, -16), "scale": [5.0 / 6.5, 8.0 / 6.5], "scale_curve": [[0, 0.65], [0.4, 1.3], [1, 1.6]], "ramp": roll})
	emit(foot, 0.2, 2.4)
	key(foot, "amount_ratio", [[0.2, 1.0], [1.8, 1.0], [2.4, 0.3]])


func _column() -> void:
	# the stem: lobes boiling up off the floor into the fireball, wide at the foot, fire at the foot early on
	var mat := lobe_mat(0.0, true)
	mat.set_shader_parameter("style", 0.0)
	var life := [[0.22, 0.75, 0.95], [0.75, 1.5, 1.35], [1.5, 2.5, 1.7]]
	var i := 0
	for L in life:
		var lt: float = L[2]
		var lob := data([[0.0, Color(1.1, 0, 1, 0)], [0.12, Color(1.0, 0, 1, 0.85)], [0.5, Color(0.65, 0.0, 1, 0.9)], [0.51, Color(0.64, 0.01, 0, 0.9)],
			[0.75, Color(0.43, 0.5, 0, 0.9)], [0.85, Color(0.33, 0.85, 0, 0.9)], [1.0, Color(0.2, 1.0, 0, 0.0)]])
		var p := particles("Column%d" % i, {"back": true, "at": Vector2(0, -2), "amount": int(28 * 85.0 / (80.0 * lt) * lt) + 4, "lifetime": lt,
			"randomness": 0.15, "emitting": false, "texture": "dot4", "emit": {"box": Vector2(2, 1)}, "dir": -90, "spread": 2,
			"speed": [70, 95], "scale": [7.0 / 2.0, 11.0 / 2.0],
			"scale_curve": [[0, 0.3], [0.06, 1.15], [0.25, 1.0], [0.5, 0.96], [1, 1.1]], "ramp": lob})
		p.material = mat
		emit(p, L[0], L[1])
		# when the feed stops the stem thins away
		key(p, "modulate:a", [[0.0, 1.0], [2.5, 1.0], [3.9, 0.0]])
		i += 1
	# fire boiling up the column early on
	var cf := puffs("ColumnFire", [4.0, 7.5], {"back": true, "at": Vector2(0, -9), "amount": 12, "lifetime": 0.8, "one_shot": false,
		"explosiveness": 0.0, "randomness": 0.4, "emit": {"box": Vector2(6, 5)}, "dir": -90, "spread": 6, "speed": [90, 150],
		"gravity": Vector2(0, -95), "damping": [60, 120]})
	emit(cf, 0.2, 1.5)
	# its foot: lobes spreading wide and slow at the floor
	var foot_data := data([[0.0, Color(1.1, 0, 1, 0)], [0.25, Color(1.05, 0, 1, 0.85)], [1.0, Color(1.0, 0, 1, 0.0)]])
	var ft := particles("ColumnFoot", {"back": true, "at": Vector2(0, -4), "amount": 6, "lifetime": 0.6, "randomness": 0.3, "emitting": false,
		"texture": "dot4", "emit": {"box": Vector2(8, 1)}, "dir": -90, "spread": 10, "speed": [15, 35], "scale": [8.0 / 2.0, 12.0 / 2.0],
		"scale_curve": [[0, 0.4], [0.3, 1.2], [1, 1.1]], "ramp": foot_data})
	ft.material = mat
	emit(ft, 0.22, 2.5)
	# the material is shared: keyed through the foot, it heats and lights every lobe of the column
	sample(ft, "material:shader_parameter/fire", func(t: float): return maxf(0.0, 1.0 - t / 1.4), 0.0, 2.5)
	sample(ft, "material:shader_parameter/glow", func(t: float): return hot_at(t), 0.0, 4.5)
	key(ft, "modulate:a", [[0.0, 1.0], [2.5, 1.0], [3.6, 0.0]])


func _plume() -> void:
	var n: int = PL.n
	var img := Image.create(n, 3, false, Image.FORMAT_RGBAF)
	for i in n:
		var th := TAU * fposmod(i * 0.618034 + rng.randf_range(-0.08, 0.08), 1.0)
		var ph := TAU * (i + rng.randf_range(-0.35, 0.35)) / n
		var j := rng.randf_range(-0.55, 0.12)
		var s := rng.randf_range(PL.size[0], PL.size[1])
		var h := rng.randf_range(-0.22, 0.08)
		var dx := rng.randf_range(-1, 1)
		var dy := rng.randf_range(-1, 0.4)
		var f := rng.randf_range(-0.9, 0.5)
		var gv := rng.randf_range(0.55, 1.15)
		img.set_pixel(i, 0, Color(th, ph, j, s))
		img.set_pixel(i, 1, Color(h, dx, dy, f))
		img.set_pixel(i, 2, Color(gv, 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	var D: float = meta.duration
	var pl := shape("Plume", load("res://addons/pixelfx_particles/fx/explosions/_big-explosion_plume.gdshader"), Vector2(240, 250),
		{"lobes": tex, "count": n, "at": Vector2(PL.x, PL.y), "rise": PL.rise, "tau": PL.tau, "drift": PL.drift,
		"tube": Vector2(PL.tube[0], PL.tube[1]), "ring": Vector2(PL.ring[0], PL.ring[1]), "grow": PL.grow, "swell": PL.swell,
		"spin": PL.spin, "spin_tau": PL.spin_tau, "heat": PL.heat, "cool": PL.cool, "under": PL.under, "tilt": PL.tilt,
		"squash": PL.squash, "fade": Vector2(PL.fade[0], PL.fade[1]), "spread": PL.spread, "fr": FR,
		"sm": PackedColorArray(SM.map(func(c): return Color(c))), "translucent": true}, {"at": Vector2(0, -125), "back": true})
	# core shape() hands colour arrays over as PackedVector4Array, which the scene saves as null: set them back as colours
	pl.material.set_shader_parameter("fr", FR)
	pl.material.set_shader_parameter("sm", PackedColorArray(SM.map(func(c): return Color(c))))
	key(pl, "material:shader_parameter/pt", [[0.0, 0.0], [P0, 0.0], [D, D - P0]])
	show(pl, P0, PL.fade[1] + P0 + 0.5)
	# its light: the hot heart on the air, and the fire in its lobes
	var heart := glow("PlumeGlow", 90, {"radius": 40, "color": FR[3], "alpha": 0.0})
	var fire := glow("PlumeFire", 60, {"radius": 30, "color": FR[2], "alpha": 0.0})
	sample(heart, "position", func(t: float): return Vector2(0, shape_at(t).x), P0, 3.8)
	sample(fire, "position", func(t: float): return Vector2(0, shape_at(t).x), P0, 3.8)
	sample(heart, "material:shader_parameter/radius", func(t: float):
		var S := shape_at(t)
		return (S.y + S.z) * 1.8 + 14.0, P0, 3.8)
	sample(fire, "material:shader_parameter/radius", func(t: float):
		var S := shape_at(t)
		return (S.y + S.z) * 1.1 + 10.0, P0, 3.8)
	sample(heart, "material:shader_parameter/alpha", func(t: float): return 0.32 * hot_at(t) if t >= P0 else 0.0, 0.0, 3.8)
	sample(fire, "material:shader_parameter/alpha", func(t: float):
		var base: float = PL.heat - PL.cool * maxf(0.0, t - P0)
		return 0.35 * clampf((base - 0.2) / 0.75, 0.0, 1.0) if t >= P0 else 0.0, 0.0, 3.8)
	# the fireball sheds embers, then ash drifts down out of the cloud
	var shed := particles("Shed", {"amount": 24, "lifetime": 2.4, "randomness": 0.5, "emitting": false, "texture": "dot1",
		"emit": {"box": Vector2(30, 8)}, "dir": -90, "spread": 80, "speed": [30, 80], "damping": [30, 50], "gravity": Vector2(0, -20),
		"ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.97])})
	emit(shed, 0.3, 3.0)
	sample(shed, "position", func(t: float): return Vector2(0, shape_at(t).x), 0.3, 3.0)
	sample(shed, "amount_ratio", func(t: float): return hot_at(t), 0.3, 3.0)
	var ash := particles("Ash", {"amount": 18, "lifetime": 2.4, "randomness": 0.4, "emitting": false, "texture": "dot1",
		"emit": {"box": Vector2(36, 2)}, "dir": 90, "spread": 30, "speed": [2, 10], "gravity": Vector2(0, 4),
		"initial": gradient([SM[1], SM[2], F[2]]), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(ash, 1.4, 4.6)
	sample(ash, "position", func(t: float):
		var S := shape_at(t)
		return Vector2(0, S.x + S.y * 0.6), 1.4, 4.6)


func _blazes() -> void:
	# little fires burning where the brands and molten rocks came down
	# where the brands come down (the original's brand flight: thrown up and out, gravity 760, drag 0.9)
	var spots := PackedVector2Array()
	for i in 16:
		var a := -PI / 2 + rng.randf_range(-1.3, 1.3)
		var sp := rng.randf_range(160, 340)
		var v := Vector2(cos(a), sin(a)) * sp
		var q := Vector2(0, -9)
		for k in 240:
			v.y += 760.0 / 60.0
			v.x -= v.x * 0.9 / 60.0
			q += v / 60.0
			if q.y >= 0.0 and v.y > 0.0:
				break
		var x := clampf(q.x, -140, 140) if i < 14 else rng.randf_range(-60, 60)
		for j in 3:
			spots.append(Vector2(x + j - 1, -1))
	var bl := puffs("Blazes", [1.4, 3.2], {"back": true, "at": Vector2(0, -1), "amount": 70, "lifetime": 0.6, "one_shot": false,
		"explosiveness": 0.0, "randomness": 0.4, "emit": {"points": spots}, "dir": -90, "spread": 12, "speed": [12, 30],
		"gravity": Vector2(0, -95), "damping": [20, 40]})
	emit(bl, 0.75, 4.6)
	key(bl, "amount_ratio", [[0.75, 0.5], [1.0, 1.0], [2.6, 0.8], [3.8, 0.35], [4.6, 0.1]])
	# each flame's light: the same puffs again as soft warm glows
	var bll := particles("BlazeGlow", {"layer": "light", "at": Vector2(0, -1), "amount": 70, "lifetime": 0.6, "randomness": 0.4,
		"emitting": false, "texture": "glow16", "modulate": Color(1, 1, 1, 0.16)})
	bll.process_material = bl.process_material.duplicate()
	bll.process_material.color_ramp = gradient([F[4], F[3], Color(F[2], 0.0)], [0.0, 0.5, 1.0], true)
	bll.seed = bl.seed
	emit(bll, 0.75, 4.6)
	key(bll, "amount_ratio", [[0.75, 0.5], [1.0, 1.0], [2.6, 0.8], [3.8, 0.35], [4.6, 0.1]])
	var ember := particles("BlazeEmbers", {"back": true, "at": Vector2(0, -2), "amount": 10, "lifetime": 1.2, "randomness": 0.5, "emitting": false,
		"texture": "dot1", "emit": {"points": spots}, "dir": -90, "spread": 25, "speed": [15, 45], "damping": [20, 30],
		"ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.97])})
	emit(ember, 0.8, 4.2)
	var blight := glow("BlazeLight", 112, {"radius": 110, "squash": 0.08, "color": F[4], "alpha": 0.0}, {"at": Vector2(0, -1)})
	key(blight, "material:shader_parameter/alpha", [[0.0, 0.0], [0.75, 0.0], [1.0, 0.3], [3.0, 0.25], [4.6, 0.0]])


func _rocks() -> void:
	# heavy rocks thrown high: stone ones, and molten ones that glow, cool and trail smoke
	var stones := gradient([st.light, st.body, st.body, st.shade])
	for k in 2:
		var big := k == 0
		var rocks := particles("Rocks" + ("Big" if big else ""), {"at": Vector2(0, -4), "amount": 6 if big else 8, "lifetime": 5.0, "one_shot": true,
			"explosiveness": 1.0, "randomness": 0.3, "texture": "disc5" if big else "disc3", "emit": {"box": Vector2(12, 1)}, "dir": -90,
			"spread": 16, "speed": [280, 480] if big else [320, 560], "damping": [10, 30], "gravity": Vector2(0, 950), "spin": [-400, 400],
			"initial": stones, "alpha_curve": [[0, 1], [0.9, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.7, "size": 4 if big else 2}})
		emit(rocks, 0.0)
		var molten := particles("Molten" + ("Big" if big else ""), {"at": Vector2(0, -4), "amount": 5 if big else 7, "lifetime": 5.0, "one_shot": true,
			"explosiveness": 1.0, "randomness": 0.3, "texture": "disc5" if big else "disc3", "emit": {"box": Vector2(12, 1)}, "dir": -90,
			"spread": 16, "speed": [280, 480] if big else [320, 560], "damping": [10, 30], "gravity": Vector2(0, 950),
			"ramp": gradient([F[6], F[5], F[3], F[2], F[1], st.shade], [0.0, 0.08, 0.2, 0.35, 0.5, 0.7]),
			"collide": {"bounce": 0.3, "friction": 0.7, "size": 4 if big else 2}})
		emit(molten, 0.0)
		# their trails: the same rocks drawn again as a streak of thin smoke behind them
		var trail := particles("Trail" + ("Big" if big else ""), {"layer": "soft", "back": true, "at": Vector2(0, -4), "amount": 5 if big else 7,
			"lifetime": 5.0, "one_shot": true, "explosiveness": 1.0, "randomness": 0.3, "texture": "streak12", "align": true,
			"modulate": Color(1, 1, 1, 0.5)})
		trail.process_material = molten.process_material.duplicate()
		trail.process_material.color_ramp = gradient([Color(SM[1], 0.0), Color(SM[1], 0.7), Color(SM[2], 0.5), Color(SM[3], 0.0)], [0.0, 0.02, 0.2, 0.32])
		trail.seed = molten.seed
		emit(trail, 0.0)
		var lit := particles("MoltenLight" + ("Big" if big else ""), {"layer": "light", "at": Vector2(0, -4), "amount": 5 if big else 7, "lifetime": 5.0,
			"one_shot": true, "explosiveness": 1.0, "randomness": 0.3, "texture": "glow16", "modulate": Color(1, 0.6, 0.3, 0.5)})
		lit.process_material = molten.process_material.duplicate()
		lit.process_material.color_ramp = gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)], [0.0, 0.3, 0.6])
		lit.seed = molten.seed
		emit(lit, 0.0)
	# a burst of dust as they come down
	var thud := particles("Thud", {"layer": "soft", "at": Vector2(0, -1), "amount": 20, "lifetime": 0.7, "randomness": 0.5, "emitting": false,
		"texture": "disc5", "emit": {"box": Vector2(120, 0.5)}, "dir": -90, "spread": 70, "speed": [10, 40],
		"scale_curve": [[0, 0.6], [1, 1.4]], "ramp": gradient([Color(st.dust, 0.6), Color(st.dust, 0.3), Color(st.dust, 0.0)], [0.0, 0.5, 0.95])})
	emit(thud, 0.9, 2.2)
