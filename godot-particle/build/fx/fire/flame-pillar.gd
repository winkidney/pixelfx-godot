# reimagined-from: src/fx/fire/flame-pillar.js@c840c42a7a29e1e7fa7816fe44b6d24a91e3e22f
# Flame pillar: the floor cracks and glows, a column of fire erupts white-hot and roars, spewing embers and shedding
# flame, then collapses into rolling smoke.
# The cracks are lines growing on the original's beats, their colour keyed down its heat curve to soot. The column
# is eight nested emitters (white heart out to a dithered deep-red rim) sharing one seed, so their discs stack into
# one roaring stream; its height and width follow the original's curves (keyed as speed and scale), a crown of
# tongues rides its top. Sparks, rocks and grit burst from the foot onto a collision floor, a stone-dust ring and
# rolling dust go out along the floor; flame puffs shed off the sides and a billowing cap cool into smoke, and the
# falling top breaks into puffs that roll off as smoke. Lights: the eruption's flash, the column's glow (keyed glows
# up its length), the floor's glow from beneath.
extends "res://build/fx/fire/_fire.gd"

const ERUPT := 0.55
const RISE := 0.12
const FALL := 1.95
const GONE := 2.45
const SOOT := Color("#0d0a12")
const WARM := Color8(255, 176, 96)
const L := 0.12          # how long a column particle takes to climb the column
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]

var HMAX := 140.0
var S := 65
var ST := {}


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func height(t: float) -> float:
	if t < ERUPT:
		return 0.0
	if t < ERUPT + RISE:
		return HMAX * out_cubic((t - ERUPT) / RISE)
	if t < FALL:
		return HMAX * (1.0 + 0.05 * N(t, 3.0, S))
	var u := clampf((t - FALL) / (GONE - FALL), 0.0, 1.0)
	return HMAX * (1.0 - u * u)


func width(t: float) -> float:
	if t < ERUPT:
		return 0.0
	if t < FALL:
		return 12.0 * (1.0 + 0.45 * exp(-(t - ERUPT) * 7.0)) * (0.94 + 0.06 * N(t, 9.0, S + 1))
	return 12.0 * (1.0 - smooth(FALL, GONE, t)) + 1.5 * (1.0 - smooth(GONE - 0.1, GONE, t))


func heat(t: float) -> float:
	return smooth(0.0, ERUPT, t) * 0.75 + 0.25 * smooth(ERUPT - 0.05, ERUPT + 0.1, t) - smooth(GONE - 0.3, root.duration - 0.6, t) * 1.05


func make() -> void:
	fire_begin()
	HMAX = float(meta.options.height)
	S = int(meta.options.seed) * 13
	var c := Color(meta.options.stone)
	ST = {"light": (c * 1.35).lerp(Color.WHITE, 0.08), "body": c, "shade": c * 0.64, "dust": (c * 1.2).lerp(Color8(150, 140, 150), 0.3)}
	for k in ST:
		ST[k].a = 1.0
	var GLOW := glow_colour()
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# ---- behind: the cracks, the floor's glow, dust and smoke, the far half of the stone-dust ring
	var floor_light := glow("FloorLight", 44, {"radius": 44, "squash": 8.0 / 44.0, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, 0.5)})
	key(floor_light, "material:shader_parameter/alpha", sampled(func(t: float): return 0.35 * maxf(0.0, heat(t))))
	cracks(rng, GLOW)

	var dust := gradient([Color(ST.dust, 0.0), Color(ST.dust, 0.62), Color(Color(SMOKE_RAMP[1]), 0.4), Color(Color(SMOKE_RAMP[2]), 0.0)], [0.0, 0.06, 0.5, 0.96])
	for s in [-1, 1]:
		var roll := particles("DustRoll%s" % ("L" if s < 0 else "R"), {"layer": "soft", "back": true, "at": Vector2(s * 6, -3),
			"amount": 7, "lifetime": 1.6, "one_shot": true, "explosiveness": 0.95, "randomness": 0.4, "emitting": false,
			"texture": "disc13", "emit": {"box": Vector2(4, 1.5)}, "dir": 90 - s * 90 - s * 4, "spread": 5, "speed": [40, 110],
			"damping": [80, 110], "gravity": Vector2(0, -8), "scale": [0.6, 0.95], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.35]], "ramp": dust})
		emit(roll, ERUPT)
	var smoke := gradient([Color(SMOKE_RAMP[0], 0.0), Color(SMOKE_RAMP[0], 0.6), Color(SMOKE_RAMP[1], 0.5), Color(SMOKE_RAMP[2], 0.3), Color(SMOKE_RAMP[3], 0.0)], [0.0, 0.08, 0.35, 0.7, 0.97])
	# smoke off the cap and the shed flame while it roars, then the big roll off the collapse
	var cap_smoke := particles("CapSmoke", {"layer": "soft", "back": true, "at": Vector2(0, -HMAX - 6), "amount": 26, "lifetime": 1.6,
		"randomness": 0.4, "emitting": false, "texture": "disc9", "emit": {"box": Vector2(10, 4)}, "dir": -90, "spread": 25,
		"speed": [15, 45], "damping": [10, 20], "gravity": Vector2(0, -20), "scale": [0.6, 1.0], "scale_curve": [[0, 0.7], [0.5, 1.1], [1, 1.4]], "ramp": smoke,
		"turbulence": {"strength": 1.5, "scale": 3.0}})
	emit(cap_smoke, ERUPT + 0.3, GONE)
	key(cap_smoke, "position", sampled(func(t: float): return Vector2(0, -maxf(20.0, height(t)) - 6.0), ERUPT, GONE))
	# the collapse's puffs all burn out into smoke where they die, high up where the top was
	var fall_smoke := particles("FallSmoke", {"layer": "soft", "back": true, "at": Vector2(0, -HMAX), "amount": 40, "lifetime": 1.3,
		"randomness": 0.4, "emitting": false, "texture": "disc7", "emit": {"box": Vector2(9, 10)}, "dir": -90, "spread": 30,
		"speed": [6, 25], "damping": [8, 14], "gravity": Vector2(0, -16), "scale": [0.55, 1.0], "scale_curve": [[0, 0.65], [0.4, 1.0], [1, 1.3]], "ramp": smoke,
		"turbulence": {"strength": 1.5, "scale": 3.0}})
	emit(fall_smoke, FALL + 0.3, GONE + 0.5)
	key(fall_smoke, "position", sampled(func(t: float): return Vector2(0, -maxf(40.0, height(t - 0.45)) - 10.0), FALL, GONE + 0.5))
	stone_ring(true)

	# ---- in front: the column's crown, the column, its glow
	var crown := group("Crown", {"at": Vector2(0, 12)})
	key(crown, "position", sampled(func(t: float): return Vector2(0, -height(t) + 12.0), ERUPT - 0.02, FALL + 0.3))
	for i in 5:
		var n := (S + i) * 17
		var share: float = 1.2 if i == 2 else 0.6 if i % 4 == 0 else 0.9
		var w0: float = 3.4 * (0.7 if i % 4 == 0 else 1.0)
		var th0 := 18.0 * share
		var tg := tongue("Crown%d" % i, Vector2((i - 2) * 4.8, 0), th0, w0, {"parent": crown, "life": 0.22, "emitting": false, "layers": LAYERS,
			"height": func(t: float): return (12.0 + 12.0 * (0.5 + 0.5 * N(t, 3.3, n, i))) * share / th0 * clampf(width(t) / 12.0, 0.0, 1.0)})
		for p in tg:
			p.seed = absi(hash(id + "crown%d" % i)) % 1000003
			emit(p, ERUPT + RISE + 0.03, FALL + 0.25)
			key(p, "position", sampled(func(t: float): return Vector2((i - 2) * width(t) * 0.4 + N(t, 2.0, n + 2) * 1.5, 0.0), ERUPT, FALL + 0.25))

	# licks: short flares sticking out of the column's sides, running up it
	for sd in [-1, 1]:
		for kind in 2:
			var lk := particles("Lick%s%d" % ["L" if sd < 0 else "R", kind], {"at": Vector2(sd * 11, -70), "amount": 14, "lifetime": 0.22,
				"randomness": 0.5, "emitting": false, "texture": "streak4" if kind == 0 else "streak3", "angle": [90, 90],
				"emit": {"box": Vector2(1, 60)}, "dir": -90 + sd * 8, "spread": 4, "speed": [30, 50],
				"scale_curve": [[0, 0.6], [0.3, 1.0], [1, 0.4]],
				"ramp": gradient([H[4], H[5], H[6], H[7]] if kind == 0 else [H[2], H[3], H[4], H[5]], [0.0, 0.3, 0.6, 0.85])})
			emit(lk, ERUPT + RISE, GONE)
			var inset := 1.0 if kind == 0 else 0.72
			key(lk, "position", sampled(func(t: float): return Vector2(sd * width(t) * inset, -maxf(8.0, height(t)) * 0.5), ERUPT, GONE))
			key(lk, "process_material:emission_box_extents", sampled(func(t: float): return Vector3(1, maxf(1.0, height(t) * 0.42), 0), ERUPT, GONE))
	var levels := [1.15, 0.96, 0.84, 0.7, 0.56, 0.42, 0.26, 0.12]
	for j in levels.size():
		var q: float = levels[j]
		var lvl := 7 - j
		var half := 12.0 * q
		var tex := "disc13" if half > 4.0 else "disc9" if half > 2.0 else "disc5"
		var ts := 13.0 if tex == "disc13" else 9.0 if tex == "disc9" else 5.0
		var s := 2.0 * half / ts
		var big := 1.15
		var col := particles("Column%d" % lvl, {"amount": 54, "lifetime": L, "randomness": 0.1, "emitting": false, "texture": tex,
			"emit": {"box": Vector2(1.2, 0.5)}, "dir": -90, "spread": 0.6, "speed": [HMAX / L, HMAX / L],
			"scale": [s * 0.85, s * big], "scale_curve": [[0, 1.5], [0.03, 1.2], [0.07, 1.0], [0.8, 1.0], [0.9, 0.75], [1.0, 0.3]],
			"color": Color(H[lvl], 0.55 if lvl == 7 else 1.0)})
		col.seed = absi(hash(id + "column")) % 1000003
		emit(col, ERUPT, GONE)
		key(col, "process_material:initial_velocity_min", sampled(func(t: float): return (HMAX if t < ERUPT + RISE else maxf(4.0, height(t))) / L * 0.97, ERUPT, GONE))
		key(col, "process_material:initial_velocity_max", sampled(func(t: float): return (HMAX if t < ERUPT + RISE else maxf(4.0, height(t))) / L * 1.03, ERUPT, GONE))
		key(col, "process_material:scale_min", sampled(func(t: float): return s * 0.85 * width(t) / 12.0, ERUPT, GONE))
		key(col, "process_material:scale_max", sampled(func(t: float): return s * big * width(t) / 12.0, ERUPT, GONE))
	# the column's light, every 12 rows up it, and the broad warm light round it
	for i in 13:
		var y := -12.0 * i
		var g := glow("ColumnLight%d" % i, 40, {"radius": 37, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, y)})
		key(g, "material:shader_parameter/radius", sampled(func(t: float): return width(t) * 2.4 + 8.0, ERUPT, GONE + 0.05))
		key(g, "material:shader_parameter/alpha", [[0.0, 0.0], [ERUPT - 0.001, 0.0]] + sampled(func(t: float): return 0.28 * clampf(width(t) / 12.0, 0.0, 1.0) if -y <= height(t) else 0.0, ERUPT, GONE + 0.05))
	var wash := glow("Wash", 92, {"radius": 92, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, -60)})
	key(wash, "position", sampled(func(t: float): return Vector2(0, -height(t) * 0.45), ERUPT, GONE))
	key(wash, "material:shader_parameter/alpha", [[0.0, 0.0], [ERUPT - 0.001, 0.0]] + sampled(func(t: float): return 0.3 * clampf(width(t) / 12.0, 0.0, 1.0), ERUPT, GONE + 0.05))

	# ---- the charge: little flames lick out of the crust in the middle
	# a flame puff cools as the original's do: heat = age^0.62 down the hot-first ramp
	var fire := gradient([H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]], [0.0, 0.035, 0.107, 0.206, 0.327, 0.469, 0.63, 0.81])
	var lick := particles("ChargeFlames", {"at": Vector2(0, -1), "amount": 8, "lifetime": 0.25, "randomness": 0.4, "texture": "disc3",
		"emit": {"box": Vector2(5, 0.5)}, "dir": -90, "spread": 10, "speed": [20, 45], "gravity": Vector2(0, -95), "damping": [20, 40],
		"scale": [0.8, 1.4], "ramp": fire})
	emit(lick, 0.15, ERUPT)
	key(lick, "amount_ratio", sampled(func(t: float): return maxf(0.05, smooth(0.15, ERUPT, t)), 0.15, ERUPT))

	# ---- the eruption: rocks, grit, sparks, the flash, the near half of the ring
	particles("Rocks", {"at": Vector2(0, -2), "amount": 18, "lifetime": 2.2, "one_shot": true, "explosiveness": 1.0, "randomness": 0.3,
		"emitting": false, "texture": "disc5", "emit": {"box": Vector2(6, 0.5)}, "dir": -90, "spread": 30, "speed": [160, 340],
		"gravity": Vector2(0, 950), "damping": [10, 30], "spin": [-600, 600], "scale": [0.55, 1.0],
		"initial": gradient([ST.light, ST.body, ST.body, ST.shade]), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
		"collide": {"bounce": 0.3, "friction": 0.7, "size": 3}})
	emit(root.get_node("Rocks"), ERUPT)
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 60, "lifetime": 1.6, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(5, 0.5)}, "dir": -90, "spread": 52, "speed": [80, 260],
		"gravity": Vector2(0, 950), "scale": [1.0, 1.6], "initial": gradient([ST.light, ST.body, ST.body, ST.shade]),
		"alpha_curve": [[0, 1], [0.85, 1], [1, 0]], "collide": {"bounce": 0.1, "friction": 1.0}})
	emit(grit, ERUPT)
	var sparks := particles("Sparks", {"at": Vector2(0, -2), "amount": 70, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "emitting": false, "texture": "streak4", "align": true, "emit": {"box": Vector2(4, 0.5)}, "dir": -90,
		"spread": 63, "speed": [100, 260], "damping": [150, 260], "gravity": Vector2(0, 427),
		"ramp": gradient([H[1], H[2], H[4], H[5]], [0.0, 0.4, 0.7, 0.9]), "collide": {"bounce": 0.45, "friction": 0.3}})
	emit(sparks, ERUPT)
	stone_ring(false)
	var flash := ring("Flash", 18, {"radius": 16, "squash": 6.0 / 16.0, "color": H[2]}, {"at": Vector2(0, -2)})
	var heart := ring("FlashHeart", 12, {"radius": 11, "squash": 4.0 / 11.0, "color": Color.WHITE}, {"at": Vector2(0, -3)})
	key(flash, "material:shader_parameter/radius", [[ERUPT, 16.0], [ERUPT + 0.08, 16.0 * 0.7]])
	key(heart, "material:shader_parameter/radius", [[ERUPT, 11.0], [ERUPT + 0.08, 11.0 * 0.7]])
	key(heart, "material:shader_parameter/color", [[ERUPT, Color.WHITE], [ERUPT + 0.04, H[1]]], "nearest")
	show(flash, ERUPT, ERUPT + 0.08)
	show(heart, ERUPT, ERUPT + 0.08)

	# ---- the roar: flame shed off the sides, a billowing cap, embers spewed high; then the falling top's puffs
	for s in [-1, 1]:
		var side := particles("Shed%s" % ("L" if s < 0 else "R"), {"at": Vector2(s * 10, -70), "amount": 6, "lifetime": 0.4, "randomness": 0.4,
			"emitting": false, "texture": "disc5", "emit": {"box": Vector2(2, 60)}, "dir": -90 + s * 35, "spread": 15, "speed": [35, 75],
			"gravity": Vector2(0, -95), "damping": [30, 50], "scale": [0.6, 1.1], "scale_curve": [[0, 0.7], [0.15, 1.0], [1, 0.5]], "ramp": fire})
		emit(side, ERUPT + 0.05, GONE)
		key(side, "position", sampled(func(t: float): return Vector2(s * width(t) * 0.9, -maxf(8.0, height(t)) * 0.47), ERUPT, GONE))
		key(side, "process_material:emission_box_extents", sampled(func(t: float): return Vector3(2, maxf(1.0, height(t) * 0.43), 0), ERUPT, GONE))
	var cap := particles("Cap", {"at": Vector2(0, -HMAX + 3), "amount": 14, "lifetime": 0.6, "randomness": 0.4, "emitting": false,
		"texture": "disc9", "emit": {"box": Vector2(10, 3)}, "dir": -90, "spread": 15, "speed": [30, 80], "gravity": Vector2(0, -95),
		"damping": [40, 60], "scale": [0.6, 1.05], "scale_curve": [[0, 0.6], [0.15, 1.0], [1, 0.45]], "ramp": fire})
	emit(cap, ERUPT + 0.1, GONE)
	key(cap, "position", sampled(func(t: float): return Vector2(0, -height(t) + 3.0), ERUPT, GONE))
	key(cap, "process_material:emission_box_extents", sampled(func(t: float): return Vector3(maxf(1.0, width(t)), 3, 0), ERUPT, GONE))
	var spew := particles("Spew", {"at": Vector2(0, -HMAX + 4), "amount": 18, "lifetime": 1.2, "randomness": 0.45, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(7, 2)}, "dir": -90, "spread": 35, "speed": [60, 120], "damping": [40, 70],
		"gravity": Vector2(0, -20), "ramp": gradient([H[1], H[2], H[4], Color(H[4], 0.0)], [0.0, 0.4, 0.7, 0.97]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	emit(spew, ERUPT + 0.1, FALL)
	key(spew, "position", sampled(func(t: float): return Vector2(0, -height(t) + 4.0), ERUPT, FALL))
	var fall := particles("FallPuffs", {"at": Vector2(0, -HMAX), "amount": 24, "lifetime": 0.75, "randomness": 0.4, "emitting": false,
		"texture": "disc9", "emit": {"box": Vector2(13, 4)}, "dir": -90, "spread": 35, "speed": [10, 50], "gravity": Vector2(0, -95),
		"damping": [30, 50], "scale": [0.75, 1.35], "scale_curve": [[0, 0.65], [0.15, 1.0], [1, 0.5]],
		"ramp": fire})
	emit(fall, FALL, GONE - 0.1)
	key(fall, "position", sampled(func(t: float): return Vector2(0, -height(t) - 4.0), FALL, GONE))

	burst_light("BurstWarm", Vector2(0, -40), 90, WARM, 0.7, 0.6)
	burst_light("BurstWhite", Vector2(0, -8), 44, Color.WHITE, 0.7, 0.1)


## A light that fades as k² and shrinks to 55 % over its life (the original's Lights), from the eruption.
func burst_light(name: String, at: Vector2, r: float, c: Color, k: float, life: float) -> void:
	var g := glow(name, r, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	key(g, "material:shader_parameter/radius", sampled(func(t: float): return r * (0.55 + 0.45 * clampf(1.0 - (t - ERUPT) / life, 0.0, 1.0)), ERUPT, ERUPT + life))
	key(g, "material:shader_parameter/alpha", [[0.0, 0.0], [ERUPT - 0.001, 0.0]] + sampled(func(t: float):
		var u := clampf(1.0 - (t - ERUPT) / life, 0.0, 1.0)
		return k * u * u, ERUPT, ERUPT + life + 0.04))


## The stone-dust ring rolling out along the floor from the eruption: bright at its leading edge, stone behind.
func stone_ring(back: bool) -> void:
	var cols := [[1.0, ST.body, 0.8], [0.7, ST.light, 0.9], [0.4, H[4], 1.0], [0.15, H[1], 1.0]]
	var j := 0
	for c in cols:
		var b := ring("Ring%s%d" % ["Far" if back else "Near", j], 90, {"radius": 1.0, "thickness": 1.0, "squash": 0.18,
			"color": c[1], "side": 1.0 if back else -1.0, "alpha": 0.0}, {"back": back, "at": Vector2(0, 0.5)})
		var share: float = c[0]
		var al: float = c[2]
		key(b, "material:shader_parameter/radius", sampled(func(t: float): return 84.0 * out_cubic(clampf((t - ERUPT) / 0.45, 0.0, 1.0)), ERUPT, ERUPT + 0.45))
		key(b, "material:shader_parameter/thickness", sampled(func(t: float):
			var k := (t - ERUPT) / 0.45
			return maxf(0.7, maxf(1.0, 4.0 * (1.0 - k)) * share), ERUPT, ERUPT + 0.45))
		key(b, "material:shader_parameter/alpha", [[0.0, 0.0], [ERUPT - 0.001, 0.0]] + sampled(func(t: float):
			var k := (t - ERUPT) / 0.45
			return 0.0 if k <= 0.0 or k >= 0.999 else al * clampf(1.15 - k, 0.0, 1.0), ERUPT, ERUPT + 0.45) + [[ERUPT + 0.46, 0.0]])
		if share < 0.2 and not back:
			key(b, "material:shader_parameter/color", [[0.0, Color.WHITE], [ERUPT + 0.45 * 0.15, H[1]]], "nearest")
		j += 1


## The cracks: jagged lines racing out from the middle (squashed for perspective) with branches, growing on the
## original's beats, glowing down its heat curve, then cooling to soot that fades. Each crack is three lines (its
## inner, middle and outer thirds) so the heat can fall off along it.
func cracks(rng: RandomNumberGenerator, GLOW: Color) -> void:
	keep_colour(SOOT)
	var list := []
	for i in 9:
		var a := i / 9.0 * TAU + rng.randf_range(-0.25, 0.25)
		var pts := crack_points(rng, Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3)), a, rng.randf_range(20, 40))
		list.append({"pts": pts, "t0": rng.randf_range(0, 0.16), "grow": rng.randf_range(0.22, 0.36), "w": 1})
		if pts.size() > 8:
			var j := 3 + rng.randi_range(0, pts.size() - 7)
			var sgn := -1.0 if rng.randf() < 0.5 else 1.0
			var b := crack_points(rng, pts[j], a + sgn * rng.randf_range(0.5, 1.0), rng.randf_range(6, 14))
			list.append({"pts": b, "t0": 0.18 + rng.randf_range(0, 0.15), "grow": rng.randf_range(0.22, 0.36), "w": 0})
	var ci := 0
	for c in list:
		var pts: PackedVector2Array = c.pts
		var n := pts.size()
		var t0: float = c.t0
		var grow: float = c.grow
		for part in 3:
			var i0 := int(floor(n * part / 3.0))
			var i1 := mini(n - 1, int(floor(n * (part + 1) / 3.0)))
			if i1 <= i0:
				continue
			var u := (i0 + i1) * 0.5 / n
			var lip: bool = c.w == 1 and part == 0
			if lip:
				var below := line("Crack%d_%dlo" % [ci, part], shift(pts.slice(i0, i1 + 1), Vector2(0, 1)), {"width": 1, "back": true, "color": H[5]})
				var above := line("Crack%d_%dhi" % [ci, part], shift(pts.slice(i0, i1 + 1), Vector2(0, -1)), {"width": 1, "back": true, "color": H[7]})
				for ln in [below, above]:
					grow_keys(ln, pts, i0, i1, t0, grow)
				key(below, "default_color", sampled(func(t: float):
					var hot := heat(t) * (1.0 - 0.45 * u)
					return (H[5] if hot > 0.6 else H[6]) if hot > 0.2 else Color(H[6], 0.0), 0.0, -1.0), "nearest")
				key(above, "default_color", sampled(func(t: float):
					var hot := heat(t) * (1.0 - 0.45 * u)
					return H[7] if hot > 0.2 else Color(H[7], 0.0), 0.0, -1.0), "nearest")
			var seam := line("Crack%d_%d" % [ci, part], pts.slice(i0, i1 + 1), {"width": 1, "back": true, "color": H[7]})
			grow_keys(seam, pts, i0, i1, t0, grow)
			key(seam, "default_color", sampled(func(t: float):
				var hot := heat(t) * (1.0 - 0.45 * u)
				if heat(t) <= -0.05:
					return Color(SOOT, 0.0)
				if hot < 0.0:
					return Color(SOOT, clampf(1.0 + hot * 3.0, 0.0, 1.0))
				return H[1] if hot > 0.85 else H[2] if hot > 0.65 else H[4] if hot > 0.45 else H[5] if hot > 0.25 else H[6] if hot > 0.1 else H[7]), "nearest")
		# the crack's light along it (every fourth point, as it reaches there)
		for i in range(2, n, 4):
			var u2 := float(i) / n
			var g := glow("CrackLight%d_%d" % [ci, i], 13, {"radius": 11, "color": GLOW, "alpha": 0.0}, {"at": pts[i]})
			key(g, "material:shader_parameter/alpha", sampled(func(t: float):
				var shown := float(n) * clampf((t - t0) / grow, 0.0, 1.0) > i
				var hot := heat(t) * (1.0 - 0.45 * u2)
				return 0.45 * hot if shown and hot > 0.0 else 0.0))
			key(g, "material:shader_parameter/radius", sampled(func(t: float): return 5.0 + 7.0 * maxf(0.0, heat(t) * (1.0 - 0.45 * u2))))
		ci += 1


func crack_points(rng: RandomNumberGenerator, at: Vector2, a: float, length: float) -> PackedVector2Array:
	var pts := PackedVector2Array([at])
	var p := at
	var d := 0.0
	while d < length:
		a += rng.randf_range(-0.55, 0.55)
		p += Vector2(cos(a) * 2.0, sin(a) * 0.76)
		pts.append(p)
		d += 2.0
	return pts


static func shift(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


## Grow a crack line's part [i0, i1] as the crack races out: its points appear one by one from t0 over grow.
func grow_keys(ln: Line2D, pts: PackedVector2Array, i0: int, i1: int, t0: float, grow: float) -> void:
	var off := ln.points[0] - pts[i0]
	var n := pts.size()
	var keys := [[0.0, PackedVector2Array()]]
	var last := -1
	for f in int(ceil((t0 + grow) * 30.0)) + 2:
		var t := f / 30.0
		var m := int(floor(n * clampf((t - t0) / grow, 0.0, 1.0)))
		var upto := mini(i1, m - 1)
		if upto == last:
			continue
		last = upto
		var seg := PackedVector2Array()
		if upto > i0:
			for i in range(i0, upto + 1):
				seg.append(pts[i] + off)
		keys.append([t, seg])
	key(ln, "points", keys, "nearest")
	ln.points = PackedVector2Array()
