# reimagined-from: src/fx/fire/meteor.js@8b88172ce84b477c859cafe32755a2f72c75a250
# Meteor: a burning rock streaks in from the upper left in a comet of fire and smashes into the floor: a white flash,
# a fireball, rocks and brands thrown, a glowing crater that cools.
# The comet is a group flown along the original's path (keyed every frame): the rock (a small shader: white-hot on
# its leading face, cracks glowing on its dark back), four flame tongues streaming back off it (fire/_fire.gd
# tongues, in the comet's own coordinates), puffs, sparks and embers shed into the world behind it, burning out into
# a trail of smoke, and its light. At the impact: a flash and a flare of rays, a stone-dust ring along the floor, a
# fireball of puffs and a column cooling into a big smoke cloud, dust rolling out, sparks, embers, rocks and grit on
# a collision floor, brands that land and keep burning, and the crater (a shader) where the rock lies cooling.
extends "res://build/fx/fire/_fire.gd"

const HIT := 0.62
const FROM := Vector2(-112, -142)
const SOOT := Color("#0d0a12")
const SOOT2 := Color("#17121d")
const OUTLINE := Color("#1a1422")
const WARM := Color8(255, 176, 96)
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]

var ST := {}
var U := Vector2.ZERO


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## Where the rock is t seconds in: speeding up a touch as it falls.
func pos(t: float) -> Vector2:
	var u := clampf(t / HIT, 0.0, 1.0)
	var k := u * u * 0.35 + u * 0.65
	return FROM * (1.0 - k)


func make() -> void:
	fire_begin()
	var D: float = root.duration
	var c := Color(meta.options.stone)
	ST = {"light": (c * 1.35).lerp(Color.WHITE, 0.08), "body": c, "shade": c * 0.64, "dust": (c * 1.2).lerp(Color8(150, 140, 150), 0.3)}
	for k in ST:
		ST[k].a = 1.0
	var RK: PackedColorArray = root.ramps.rock
	var GLOW := glow_colour()
	U = -FROM.normalized()
	ground()
	# a flame puff cools as the original's do: heat = age^0.62 down the hot-first ramp
	var fire := gradient([H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]], [0.0, 0.035, 0.107, 0.206, 0.327, 0.469, 0.63, 0.81])
	# smoke as the original's: down SMOKE_RAMP to near-black as it ages, thinning out at the end
	var big_smoke := gradient([Color(SMOKE_RAMP[0], 0.0), Color(SMOKE_RAMP[0], 0.66), Color(SMOKE_RAMP[1], 0.66), Color(SMOKE_RAMP[2], 0.62),
		Color(SMOKE_RAMP[3], 0.5), Color(SMOKE_RAMP[4], 0.3), Color(SMOKE_RAMP[4], 0.0)], [0.0, 0.06, 0.19, 0.38, 0.57, 0.76, 0.95])

	# ---- behind: the crater, smoke, dust, the brands' fires, the far half of the ring
	var crater := shape("Crater", load("res://addons/pixelfx_particles/fx/fire/_meteor_crater.gdshader"), Vector2(84, 10), {
		"hot": gradient(Array(H)), "soot": SOOT, "soot2": SOOT2, "shade": ST.shade, "lip_hot": ST.light.lerp(H[4], 0.5),
		"lip_cool": ST.light, "outline": OUTLINE, "seed": 104.0, "age": 0.0, "alpha": 1.0}, {"back": true, "at": Vector2(0, -1)})
	show(crater, HIT)
	key(crater, "material:shader_parameter/age", [[HIT, 0.0], [D, D - HIT]])
	key(crater, "material:shader_parameter/alpha", sampled(func(t: float): return 1.0 - smooth(D - 1.0, D - 0.15, t), D - 1.1, D))

	# the comet's trail of smoke: its shed puffs burning out, hanging in the air and drifting up
	var trail_smoke := particles("TrailSmoke", {"layer": "soft", "back": true, "at": pos(0), "amount": 60, "lifetime": 2.0, "randomness": 0.35,
		"emitting": false, "texture": "disc7", "emit": {"box": Vector2(3, 3)}, "dir": -90, "spread": 40, "speed": [4, 14], "damping": [4, 8],
		"gravity": Vector2(2, -14), "scale": [0.7, 1.1], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.35]], "ramp": big_smoke,
		"turbulence": {"strength": 1.0, "scale": 3.0}})
	emit(trail_smoke, 0.25, HIT + 0.2)
	key(trail_smoke, "position", sampled(func(t: float): return pos(t - 0.33) - U * 18.0, 0.25, HIT + 0.2))
	# the impact's smoke: a column cooling off the fireball and a big rolling cloud
	var cloud := particles("Cloud", {"layer": "soft", "back": true, "at": Vector2(0, -14), "amount": 30, "lifetime": 2.3, "one_shot": true,
		"explosiveness": 0.88, "randomness": 0.3, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(14, 10)}, "dir": -90,
		"spread": 25, "speed": [30, 110], "damping": [50, 80], "gravity": Vector2(0, -16), "scale": [1.1, 1.6],
		"scale_curve": [[0, 0.6], [0.4, 1.1], [1, 1.5]], "ramp": big_smoke, "turbulence": {"strength": 1.0, "scale": 3.0}})
	emit(cloud, HIT + 0.2)
	var column_smoke := particles("ColumnSmoke", {"layer": "soft", "back": true, "at": Vector2(0, -60), "amount": 14, "lifetime": 1.6,
		"one_shot": true, "explosiveness": 0.8, "randomness": 0.3, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(10, 25)},
		"dir": -90, "spread": 30, "speed": [10, 40], "damping": [10, 20], "gravity": Vector2(0, -23), "scale": [0.7, 1.2],
		"scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.4]], "ramp": big_smoke})
	emit(column_smoke, HIT + 0.6)
	var dust := gradient([Color(ST.dust, 0.0), Color(ST.dust, 0.66), Color(Color(SMOKE_RAMP[1]), 0.4), Color(Color(SMOKE_RAMP[2]), 0.0)], [0.0, 0.06, 0.5, 0.96])
	for s in [-1, 1]:
		var roll := particles("Dust%s" % ("L" if s < 0 else "R"), {"layer": "soft", "back": true, "at": Vector2(s * 10, -3),
			"amount": 8, "lifetime": 1.8, "one_shot": true, "explosiveness": 0.95, "randomness": 0.4, "emitting": false,
			"texture": "disc13", "emit": {"box": Vector2(7, 2)}, "dir": 90 - s * 90 - s * 5, "spread": 4, "speed": [60, 130],
			"damping": [100, 140], "gravity": Vector2(0, -6), "scale": [0.8, 1.2], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.3]], "ramp": dust})
		emit(roll, HIT)
	# the brands' little fires, burning where they land
	var blazes := particles("Blazes", {"back": true, "at": Vector2(0, -1), "amount": 40, "lifetime": 0.45, "randomness": 0.4,
		"emitting": false, "texture": "disc3", "emit": {"points": blaze_points()}, "dir": -90, "spread": 12, "speed": [12, 30],
		"gravity": Vector2(0, -95), "damping": [20, 40], "scale": [0.6, 1.2], "scale_curve": [[0, 0.7], [0.15, 1.0], [1, 0.5]], "ramp": fire})
	emit(blazes, HIT + 0.35, HIT + 1.9)
	key(blazes, "amount_ratio", [[HIT + 0.35, 1.0], [HIT + 1.0, 0.8], [HIT + 1.9, 0.2]])
	ring_band(true)

	# ---- the flight: the comet
	var comet := group("Comet", {"at": pos(0)})
	key(comet, "position", sampled(func(t: float): return pos(t), 0.0, HIT))
	show(comet, 0.0, HIT)
	var dir_deg := rad_to_deg((-U).angle())
	var blades := [[36.0, 7.0, 0.0], [26.0, 7.5, -2.5], [26.0, 7.5, 2.5], [16.0, 8.0, 0.0]]
	for i in blades.size():
		var b: Array = blades[i]
		var n := (99 + i) * 13
		var at: Vector2 = Vector2(-U.y, U.x) * float(b[2]) - U * 4.0
		var L0: float = b[0]
		var tg := tongue("Blade%d" % i, at, L0 * 1.05, b[1], {"parent": comet, "dir": dir_deg, "life": 0.16, "layers": LAYERS,
			"height": func(t: float): return 0.85 + 0.25 * N(t, 5.0, n),
			"sweep": func(t: float): return N(t, 3.0, n + 3) * 3.0})
		for p in tg:
			p.local_coords = true
			p.seed = absi(hash(id + "blade%d" % i)) % 1000003
			emit(p, 0.0, HIT)
	var rock := shape("Rock", load("res://addons/pixelfx_particles/fx/fire/_meteor_rock.gdshader"), Vector2(20, 20), {
		"radius": 6.5, "dir": U, "cool": 0.0, "h0": H[0], "h1": H[1], "h2": H[2], "h4": H[4], "h6": H[6],
		"rk0": RK[0], "rk1": RK[1], "rk2": RK[2], "outline": OUTLINE}, {"parent": comet})
	var shed := particles("Shed", {"at": pos(0), "amount": 44, "lifetime": 0.5, "randomness": 0.35, "emitting": false, "texture": "disc9",
		"emit": {"box": Vector2(3, 3)}, "dir": rad_to_deg(U.angle()) - 15, "spread": 35, "speed": [20, 60], "gravity": Vector2(0, -95),
		"damping": [40, 70], "scale": [0.7, 1.15], "scale_curve": [[0, 0.65], [0.15, 1.0], [1, 0.5]], "ramp": fire})
	emit(shed, 0.0, HIT)
	key(shed, "position", sampled(func(t: float): return pos(t) - U * 9.0, 0.0, HIT))
	var spark_ramp := gradient([H[1], H[2], H[4], H[5]], [0.0, 0.4, 0.7, 0.9])
	var trail_sparks := particles("TrailSparks", {"at": pos(0), "amount": 12, "lifetime": 0.45, "randomness": 0.5, "emitting": false,
		"texture": "streak3", "align": true, "dir": rad_to_deg(U.angle()), "spread": 50, "speed": [60, 150], "damping": [100, 200],
		"gravity": Vector2(0, 427), "ramp": spark_ramp})
	emit(trail_sparks, 0.0, HIT)
	key(trail_sparks, "position", sampled(func(t: float): return pos(t), 0.0, HIT))
	var ember_ramp_ := gradient([H[1], H[2], H[4], Color(H[4], 0.0)], [0.0, 0.4, 0.7, 0.97])
	var trail_embers := particles("TrailEmbers", {"at": pos(0), "amount": 18, "lifetime": 1.4, "randomness": 0.4, "emitting": false,
		"texture": "dot1", "dir": -90, "spread": 60, "speed": [10, 40], "damping": [20, 30], "gravity": Vector2(0, -25), "ramp": ember_ramp_,
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	emit(trail_embers, 0.0, HIT)
	key(trail_embers, "position", sampled(func(t: float): return pos(t), 0.0, HIT))
	var rock_glow := glow("RockGlow", 46, {"radius": 46, "color": GLOW, "alpha": 0.55}, {"parent": comet})
	var rock_heart := glow("RockHeart", 12, {"radius": 12, "color": H[1], "alpha": 0.4}, {"parent": comet})
	var floor_light := glow("FloorLight", 70, {"radius": 30, "squash": 7.0 / 30.0, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, 0.5)})
	key(floor_light, "material:shader_parameter/radius", sampled(func(t: float): return 30.0 + 40.0 * minf(1.0, t / HIT), 0.0, HIT))
	key(floor_light, "material:shader_parameter/squash", sampled(func(t: float): return 7.0 / (30.0 + 40.0 * minf(1.0, t / HIT)), 0.0, HIT))
	key(floor_light, "material:shader_parameter/alpha", sampled(func(t: float): return 0.5 * pow(t / HIT, 2.0) if t < HIT else 0.0, 0.0, HIT + 0.04))

	# ---- the impact
	# the rock lies half-buried in the crater, cooling
	var core := shape("Core", load("res://addons/pixelfx_particles/fx/fire/_meteor_rock.gdshader"), Vector2(18, 18), {
		"radius": 5.5, "dir": U, "cool": 0.0, "h0": H[0], "h1": H[1], "h2": H[2], "h4": H[4], "h6": H[6],
		"rk0": RK[0], "rk1": RK[1], "rk2": RK[2], "outline": OUTLINE}, {"at": Vector2.ZERO})
	show(core, HIT)
	key(core, "material:shader_parameter/cool", [[HIT, 0.0], [HIT + 2.8, 1.0]])
	key(core, "material:shader_parameter/alpha", sampled(func(t: float): return 1.0 - smooth(D - 1.1, D - 0.2, t), D - 1.2, D))
	var core_glow := glow("CoreGlow", 22, {"radius": 22, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, -2)})
	key(core_glow, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0]] + sampled(func(t: float):
		return 0.4 * (1.0 - clampf((t - HIT) / 2.8, 0.0, 1.0)) * (1.0 - smooth(D - 1.1, D - 0.2, t)), HIT, D))

	ring_band(false)
	particles("Rocks", {"at": Vector2(0, -3), "amount": 28, "lifetime": 2.4, "one_shot": true, "explosiveness": 1.0, "randomness": 0.3,
		"emitting": false, "texture": "disc5", "emit": {"box": Vector2(8, 0.5)}, "dir": -84, "spread": 32, "speed": [150, 350],
		"gravity": Vector2(0, 950), "damping": [10, 30], "spin": [-600, 600], "scale": [0.55, 1.0],
		"initial": gradient([ST.light, ST.body, ST.body, ST.shade]), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
		"collide": {"bounce": 0.3, "friction": 0.7, "size": 3}})
	emit(root.get_node("Rocks"), HIT)
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 80, "lifetime": 2.0, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(6, 0.5)}, "dir": -81, "spread": 40, "speed": [90, 270],
		"gravity": Vector2(0, 950), "scale": [1.0, 1.6], "initial": gradient([ST.light, ST.body, ST.body, ST.shade]),
		"alpha_curve": [[0, 1], [0.85, 1], [1, 0]], "collide": {"bounce": 0.1, "friction": 1.0}})
	emit(grit, HIT)
	# brands: burning chunks that arc out and land (their fires burn on behind, "Blazes")
	var brands := particles("Brands", {"at": Vector2(0, -6), "amount": 10, "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "disc3", "dir": -90, "spread": 58, "speed": [130, 240], "gravity": Vector2(0, 760), "damping": [30, 60],
		"scale": [1.0, 1.2], "ramp": gradient([H[1], H[2], H[3], H[3]], [0.0, 0.1, 0.3, 1.0]), "collide": {"hide": true, "size": 2}})
	emit(brands, HIT)

	# the fireball: puffs thrown up and forward with the rock's momentum, and a column punching up; big puffs, so
	# they show their darker rims and cool sooner than the comet's little ones
	var ball_ramp := gradient([H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]], [0.0, 0.025, 0.07, 0.14, 0.24, 0.38, 0.56, 0.78])
	var ball := particles("Fireball", {"at": Vector2(0, -6), "amount": 34, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.45, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(6, 4)}, "dir": -76, "spread": 74,
		"speed": [50, 210], "damping": [450, 650], "gravity": Vector2(0, -60), "scale": [0.55, 1.0],
		"scale_curve": [[0, 0.6], [0.12, 1.0], [1, 0.45]], "ramp": ball_ramp})
	emit(ball, HIT)
	# the original's drag stops the burst within a fifth of a second; then the heat carries the puffs up
	for k in ["damping_min", "damping_max"]:
		key(ball, "process_material:" + k, [[HIT + 0.22, 550.0 if k == "damping_max" else 450.0], [HIT + 0.3, 15.0]])
	var col := particles("Column", {"at": Vector2(0, -6), "amount": 9, "lifetime": 1.2, "one_shot": true, "explosiveness": 0.9,
		"randomness": 0.3, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(6, 1)}, "dir": -90, "spread": 6,
		"speed": [130, 220], "damping": [330, 380], "gravity": Vector2(0, -50), "scale": [0.8, 1.1],
		"scale_curve": [[0, 0.6], [0.12, 1.0], [1, 0.5]], "ramp": ball_ramp})
	emit(col, HIT)
	for k in ["damping_min", "damping_max"]:
		key(col, "process_material:" + k, [[HIT + 0.4, 350.0], [HIT + 0.5, 10.0]])
	var sparks := particles("Sparks", {"at": Vector2(0, -4), "amount": 90, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "emitting": false, "texture": "streak4", "align": true, "dir": -81, "spread": 74, "speed": [100, 300],
		"damping": [150, 300], "gravity": Vector2(0, 427), "ramp": spark_ramp, "collide": {"bounce": 0.45, "friction": 0.3}})
	emit(sparks, HIT)
	var embers := particles("Embers", {"at": Vector2(0, -8), "amount": 36, "lifetime": 2.4, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.5, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(8, 6)}, "dir": -90, "spread": 100,
		"speed": [40, 150], "damping": [60, 100], "gravity": Vector2(0, -30), "ramp": ember_ramp_,
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	emit(embers, HIT)

	# the hero frame: a white-hot flash and a flare of rays
	var fl := [["Flash", 12.5, H[3], H[3]], ["FlashMid", 11.0, H[1], H[2]], ["FlashHeart", 7.0, Color.WHITE, H[1]]]
	for f in fl:
		var r0: float = f[1]
		var disc := ring(f[0], r0 + 1, {"radius": r0, "color": f[2]}, {"at": Vector2(0, -6)})
		key(disc, "material:shader_parameter/radius", [[HIT, r0], [HIT + 0.08, r0 * 0.7 + (1.5 if r0 > 12 else 0.0) * 0.3]])
		key(disc, "material:shader_parameter/color", [[HIT, f[2]], [HIT + 0.04, f[3]]], "nearest")
		show(disc, HIT, HIT + 0.08)
	var rays := group("Flare", {"at": Vector2(0, -6)})
	show(rays, HIT, HIT + 0.24)
	for i in 8:
		var an := i * PI / 4.0
		var share: float = 1.0 if i % 4 == 0 else 0.6 if i % 2 == 0 else 0.3
		var dv := Vector2(cos(an), sin(an))
		var ray := line("Ray%d" % i, PackedVector2Array([Vector2.ZERO, dv]), {"parent": rays, "width": 1,
			"gradient": gradient([Color.WHITE, H[2], H[4]], [0.0, 0.35, 0.7])})
		key(ray, "points", sampled(func(t: float):
			var fr := clampf((t - HIT) / 0.24, 0.0, 1.0)
			var len := maxf(0.5, 44.0 * pow(1.0 - fr, 1.4) * share)
			return PackedVector2Array([Vector2.ZERO, (dv * len).round()]), HIT, HIT + 0.24), "nearest")

	burst_light("BurstWarm", Vector2(0, -40), 100, WARM, 0.95, 0.9)
	burst_light("BurstWhite", Vector2(0, -20), 46, Color.WHITE, 0.9, 0.12)


## Where the brands come down: spread along the floor either side, more to the right (the rock's momentum).
func blaze_points() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var pts := PackedVector2Array()
	for i in 10:
		var a := deg_to_rad(-90.0 + rng.randf_range(-57, 60))
		var sp := rng.randf_range(130, 240)
		var vx := cos(a) * sp
		var vy := sin(a) * sp
		var tl := (-vy + sqrt(vy * vy + 2.0 * 760.0 * 6.0)) / 760.0
		pts.append(Vector2(vx * tl * 0.8, 0))
	return pts


## A light that fades as k² and shrinks to 55 % over its life (the original's Lights), from the impact.
func burst_light(name: String, at: Vector2, r: float, c: Color, k: float, life: float) -> void:
	var g := glow(name, r, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	key(g, "material:shader_parameter/radius", sampled(func(t: float): return r * (0.55 + 0.45 * clampf(1.0 - (t - HIT) / life, 0.0, 1.0)), HIT, HIT + life))
	key(g, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0]] + sampled(func(t: float):
		var u := clampf(1.0 - (t - HIT) / life, 0.0, 1.0)
		return k * u * u, HIT, HIT + life + 0.04))


## The stone-dust ring racing out along the floor from the impact: bright at its leading edge, stone behind.
func ring_band(back: bool) -> void:
	var cols := [[1.0, ST.body, 0.8], [0.7, ST.light, 0.9], [0.4, H[4], 1.0], [0.15, H[1], 1.0]]
	var j := 0
	for cc in cols:
		var b := ring("Ring%s%d" % ["Far" if back else "Near", j], 116, {"radius": 1.0, "thickness": 1.0, "squash": 0.16,
			"color": cc[1], "side": 1.0 if back else -1.0, "alpha": 0.0}, {"back": back, "at": Vector2(0, 0.5)})
		var share: float = cc[0]
		var al: float = cc[2]
		key(b, "material:shader_parameter/radius", sampled(func(t: float): return 110.0 * out_cubic(clampf((t - HIT) / 0.5, 0.0, 1.0)), HIT, HIT + 0.5))
		key(b, "material:shader_parameter/thickness", sampled(func(t: float):
			var k := (t - HIT) / 0.5
			return maxf(0.7, maxf(1.0, 5.0 * (1.0 - k)) * share), HIT, HIT + 0.5))
		key(b, "material:shader_parameter/alpha", [[0.0, 0.0], [HIT - 0.001, 0.0]] + sampled(func(t: float):
			var k := (t - HIT) / 0.5
			return 0.0 if k <= 0.0 or k >= 0.999 else al * clampf(1.15 - k, 0.0, 1.0), HIT, HIT + 0.5) + [[HIT + 0.51, 0.0]])
		if share < 0.2 and not back:
			key(b, "material:shader_parameter/color", [[0.0, Color.WHITE], [HIT + 0.5 * 0.12, H[1]]], "nearest")
		j += 1
