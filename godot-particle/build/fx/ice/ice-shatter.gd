# reimagined-from: src/fx/ice/ice-shatter.js@0167dbb72c3374ef1826c6d5fffeb3bd96628822
# Ice shatter: a block of ice takes a hit from the left: it jolts, cracks race over its faces, it flashes white and
# bursts into chunks that tumble, bounce and skid off in a roll of ice dust.
# The block is a shader (its shaded faces, reflections sweeping across, fracture plane, veins and bubbles, lit edges)
# in a group keyed through its jolts and shiver; the cracks are the original's fracture walk, grown as Line2Ds (a dark
# groove under a pale line, a white-hot tip and its light) at the original's speeds. The hit is a sparkle, a flare,
# sparks and chips flung back; the block flashes white under a flare and bursts: its faces chopped into chunks (block
# chunk textures drawn here) flung right and up with splinters and lumps, bouncing on a collision floor, ice dust and
# vapour rolling out, snow and glints. A frost patch on the floor melts away.
extends "res://build/fx/ice/_ice.gd"

const HIT := 0.26
const CRACK2 := 0.4
const SHIVER := 0.54
const FLASH := 0.62
const BURST := 0.68
const HIT_AT := Vector2(-16, -15)
const FRONT := [Vector2(-16, 0), Vector2(-16, -28), Vector2(12, -28), Vector2(12, 0)]
const TOP := [Vector2(-16, -28), Vector2(-8, -34), Vector2(20, -34), Vector2(12, -28)]
const SIDE := [Vector2(12, 0), Vector2(12, -28), Vector2(20, -34), Vector2(20, -6)]
const SIL := [Vector2(-16, 0), Vector2(-16, -28), Vector2(-8, -34), Vector2(20, -34), Vector2(20, -6), Vector2(12, 0)]

func jolt(t: float) -> float:
	if t >= HIT and t < HIT + 0.05:
		return 2.0
	if t >= HIT + 0.05 and t < HIT + 0.12:
		return 1.0
	if t >= SHIVER and t < FLASH:
		return 1.0 if int(floor(t * 40.0)) % 2 else 0.0
	return 0.0


func make() -> void:
	var D: float = root.duration
	rng.seed = 6
	ground()

	# the frost patch the block stands on, melting away after the burst
	var patch := {}
	for x in range(-22, 27):
		var d := absf(x - 2) / 24.0
		var h := jrand([x, 41])
		var a := clamp01((1.1 - d) / 0.25)
		if a <= 0.0:
			continue
		patch[Vector2i(x, 0)] = Color(Color.WHITE if h < 0.35 else C[6], a)
		if h < 0.4 and (x < -16 or x > 20):
			patch[Vector2i(x, -1)] = Color(C[5], a)
		for j in range(1, 2 + int(roundf(jrand([x, 7]) * 3.0 * (1.0 - d)))):
			patch[Vector2i(x, j)] = Color(C[5] if j < 2 else C[4], a * (1.0 - j / 5.0))
	var floor_frost := bitmap("FrostPatch", patch, {"back": true})
	key(floor_frost, "modulate", sample(func(t): return Color(1, 1, 1, 1.0 - smooth(BURST + 0.6, BURST + 1.5, t))))

	# cold light in the ice, brighter as it cracks; a pool on the floor
	var inner := glow("InnerLight", 36, {"radius": 34, "color": C[4], "alpha": 0.16}, {"at": Vector2(2, -17)})
	key(inner, "material:shader_parameter/alpha", sample(func(t): return (0.16 + 0.22 * smooth(HIT, FLASH, t)) * (1.0 - smooth(BURST, BURST + 0.4, t))))
	var pool := glow("Pool", 32, {"radius": 30, "color": C[4], "alpha": 0.14}, {"at": Vector2(2, -2)})
	key(pool, "material:shader_parameter/alpha", sample(func(t): return 0.14 * (1.0 - smooth(BURST, BURST + 0.4, t))))

	block()
	hit()
	burst()


## The block and its cracks, jolting as one.
func block() -> void:
	var D: float = root.duration
	var body := group("Block")
	key(body, "position", sample(func(t): return Vector2(jolt(t), 0)), "nearest")
	show(body, 0.0, BURST)
	# the ice's insides: veins of frost and trapped bubbles in the front face
	var veins := PackedVector2Array()
	for k in 3:
		var x := rng.randf_range(-12, 8)
		var y := rng.randf_range(-24, -6)
		var a := rng.randf_range(0, TAU)
		for i in 9:
			a += rng.randf_range(-0.6, 0.6)
			x += cos(a) * 1.5
			y += sin(a) * 1.2
			if x < -14 or x > 10 or y < -26 or y > -2:
				break
			veins.append(Vector2(floorf(x), floorf(y)))
	var bubbles := []
	for k in 5:
		bubbles.append(Vector3(rng.randi_range(-12, 8), rng.randi_range(-23, -4), 1.0 if rng.randf() < 0.4 else 0.0))
	var shape_node := shape("Ice", load(ICE + "_block.gdshader"), Vector2(48, 48), {"veins": veins, "vein_count": float(veins.size()),
		"bubbles": bubbles, "ramp": ramp("palette", {"stops": 8})}, {"at": Vector2(2, -16), "parent": body})
	key(shape_node, "material:shader_parameter/sweep", sample(func(t): return -40.0 + 70.0 * seg(t, 0.04, 0.3), 0.0, BURST), "nearest")
	key(shape_node, "material:shader_parameter/white", sample(func(t): return 1.0 if t >= FLASH else 0.0, 0.0, BURST), "nearest")
	# cracks walking out from the point of impact, a second wave racing over the faces
	var cracks := fractures(SIL, Vector2(HIT_AT.x + 1, HIT_AT.y), 4, 8, -0.9, 1.9, 0.16)
	var cracks2 := fractures(SIL, Vector2(HIT_AT.x + 1, HIT_AT.y), 6, 18, -1.3, 2.7, 0.16)
	# drawn on the block until it flashes white (the white block is all there is then)
	var lines := group("Cracks", {"parent": body})
	show(lines, 0.0, FLASH)
	var i := 0
	for set in [[cracks, HIT, 170.0], [cracks2, CRACK2, 200.0]]:
		for pts in set[0]:
			grow_crack("Crack%d" % i, pts, set[1], set[2], lines, BURST)
			i += 1


## The hit: a star and a short flare on the left face, chips and sparks thrown back, light.
func hit() -> void:
	var D: float = root.duration
	light_flash("HitWhite", HIT_AT, 24, Color.WHITE, 0.6, HIT, 0.08)
	light_flash("HitCold", HIT_AT + Vector2(6, 0), 40, C[5], 0.4, HIT, 0.3)
	var sp := sparkle("HitStar", {"reach": 30})
	var keys := []
	for f in int(roundf(D * FPS)) + 1:
		var t := f / FPS
		var h := t - HIT
		keys.append([t, HIT_AT - Vector2(1, 0), 9.0 * out_back(minf(1.0, h / 0.04)) * (1.0 - h / 0.2) if (h >= 0.0 and h < 0.2) else 0.0, 0.7])
	sparkle_keys(sp, keys)
	var fl := flare("HitFlare", HIT_AT - Vector2(1, 0), 16)
	key(fl, "material:shader_parameter/len", sample(func(t): return 14.0 * (1.0 - (t - HIT) / 0.08) if (t >= HIT and t < HIT + 0.08) else 0.0, 0.0, HIT + 0.12), "nearest")
	key(fl, "material:shader_parameter/k", sample(func(t): return 1.0 - (t - HIT) / 0.08, HIT, HIT + 0.12), "nearest")
	var sparks := particles("Sparks", {"at": HIT_AT - Vector2(1, 0), "amount": 12, "lifetime": 0.4, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("fade6"), "align": true, "dir": 200, "spread": 52, "speed": [60, 130], "damping": [100, 180],
		"gravity": Vector2(0, 427), "ramp": gradient([C[7], C[6], C[5], C[4]], [0.0, 0.4, 0.7, 0.9]), "collide": {"bounce": 0.45, "size": 0.5}})
	sparks.process_material.lifetime_randomness = 0.6
	var spark_light := lit_copy(sparks, "SparkLight", "glow8", Color(C[6], 0.45), [[0, 1], [1, 0]])
	var chips := particles("Chips", {"at": HIT_AT - Vector2(1, 0), "amount": 6, "lifetime": 0.9, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "streak3", "emit": {"box": Vector2(0.5, 2)}, "dir": 215, "spread": 40, "speed": [70, 130], "damping": [40, 70],
		"gravity": Vector2(0, 810), "angle": [0, 360], "spin": [-1100, 1100], "initial": gradient([C[5], C[6], C[7]]),
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]], "collide": {"bounce": 0.3, "size": 1}})
	chips.process_material.lifetime_randomness = 0.4
	emit_all([sparks, spark_light, chips], HIT)
	# the second wave of cracks: light and a few chips
	light_flash("CrackLight", Vector2(0, -16), 36, C[6], 0.35, CRACK2, 0.15)
	var chips2 := particles("Chips2", {"at": Vector2(2, -17), "amount": 3, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "streak3", "emit": {"box": Vector2(16, 13)}, "dir": -90, "spread": 40, "speed": [10, 50],
		"gravity": Vector2(0, 810), "angle": [0, 360], "spin": [-1100, 1100], "initial": gradient([C[5], C[6], C[7]]),
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	emit(chips2, CRACK2)
	# it flashes white under a flare
	light_flash("FlashLight", Vector2(2, -17), 44, Color.WHITE, 0.7, FLASH, 0.08)
	var big := flare("BurstFlare", Vector2(2, -17), 28)
	key(big, "material:shader_parameter/len", sample(func(t): return 26.0 * (1.0 - clamp01((t - FLASH) / 0.18)) if (t >= FLASH and t < BURST + 0.12) else 0.0, 0.0, BURST + 0.16), "nearest")
	key(big, "material:shader_parameter/k", sample(func(t): return 1.0 - clamp01((t - FLASH) / 0.18), FLASH, BURST + 0.16), "nearest")


func chop(pts: Array, most: float, depth: int) -> Array:
	var c := centroid(pts)
	if c.z < most or depth > 4:
		return [pts]
	var out := []
	for q in split_poly(pts, c.x + rng.randf_range(-1, 1), c.y + rng.randf_range(-1, 1), rng.randf_range(0, PI)):
		out += chop(q, most, depth + 1)
	return out


## The burst: chunks of each face flung away from the hit, mostly right and up; splinters, lumps, ice dust, vapour,
## snow, glints, a flash of light.
func burst() -> void:
	var groups := {"block_front_l": PackedVector2Array(), "block_front_m": PackedVector2Array(), "block_top": PackedVector2Array(), "block_side": PackedVector2Array()}
	for f in [[FRONT, 46.0, "front"], [TOP, 40.0, "top"], [SIDE, 46.0, "side"]]:
		for part in chop(f[0], f[1], 0):
			var m := centroid(part)
			var k: String = "block_" + f[2]
			if f[2] == "front":
				k += "_l" if m.z > 30.0 else "_m"
			groups[k].append(Vector2(m.x, m.y))
	for k in groups:
		var pts: PackedVector2Array = groups[k]
		if pts.is_empty():
			continue
		var p := particles("Chunks_" + k, {"at": Vector2.ZERO, "amount": pts.size(), "lifetime": 1.8, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": tex(k), "emit": {"points": pts}, "dir": -42, "spread": 26, "speed": [100, 250], "damping": [40, 80],
			"gravity": Vector2(0, 855), "angle": [-40, 40], "spin": [-570, 570], "alpha_curve": [[0, 1], [0.78, 1], [1, 0]],
			"collide": {"bounce": 0.38, "friction": 0.9, "size": 0.6}})
		p.process_material.lifetime_randomness = 0.2
		emit(p, BURST)
	var inside := PackedVector2Array()
	while inside.size() < 40:
		var q := Vector2(rng.randf_range(-15, 19), -rng.randf_range(1, 33))
		if in_poly(SIL, q):
			inside.append(q)
	var spl := particles("Splinters", {"at": Vector2.ZERO, "amount": 34, "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "emit": {"points": inside}, "dir": -55, "spread": 40, "speed": [80, 260], "damping": [50, 90], "gravity": Vector2(0, 810),
		"angle": [0, 360], "spin": [-1260, 1260], "initial": gradient([C[4], C[5], C[6], C[7]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"collide": {"bounce": 0.32, "friction": 0.8, "size": 1}})
	spl.process_material.lifetime_randomness = 0.4
	var lumps := particles("Lumps", {"at": Vector2.ZERO, "amount": 6, "lifetime": 1.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": tex("chunk5"), "emit": {"points": inside}, "dir": -55, "spread": 40, "speed": [80, 240], "damping": [50, 90], "gravity": Vector2(0, 810),
		"angle": [0, 360], "spin": [-1260, 1260], "alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "collide": {"bounce": 0.32, "friction": 0.8, "size": 0.5}})
	lumps.process_material.lifetime_randomness = 0.4
	emit_all([spl, lumps], BURST)
	var roll := particles("Vapour", {"layer": "soft", "at": Vector2(6, -3.5), "amount": 9, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(12, 2.5)}, "dir": -6, "spread": 6, "speed": [12, 130], "damping": [60, 100],
		"scale_curve": [[0, 0.45], [1, 0.95]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.25), Color(C[6], 0.08), Color(C[6], 0.0)], [0.0, 0.4, 0.8, 1.0], true)})
	roll.process_material.lifetime_randomness = 0.4
	var haze := lit_copy(roll, "Haze", "glow16", Color(C[5], 0.16), [[0, 1], [1, 0]])
	var dust := particles("Dust", {"layer": "soft", "at": Vector2(5, -2.5), "amount": 5, "lifetime": 0.9, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(11, 1.5)}, "dir": -3, "spread": 4, "speed": [30, 110], "damping": [60, 100],
		"scale_curve": [[0, 0.35], [1, 0.5]], "ramp": gradient([Color(C[5], 0.7), Color(C[5], 0.35), Color(C[5], 0.0)], [0.0, 0.5, 1.0], true)})
	var high := particles("VapourHigh", {"layer": "soft", "at": Vector2(5, -18), "amount": 4, "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex("puff16"), "emit": {"box": Vector2(13, 10)}, "dir": -60, "spread": 30, "speed": [10, 50], "damping": [30, 50],
		"scale_curve": [[0, 0.5], [1, 1.1]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.22), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	var snow := particles("Snow", {"at": Vector2(4, -17), "amount": 16, "lifetime": 1.6, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(12, 11)}, "dir": -70, "spread": 70, "speed": [40, 140], "damping": [80, 130], "gravity": Vector2(0, 35),
		"initial": gradient([Color.WHITE, Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]]})
	snow.process_material.lifetime_randomness = 0.35
	var stars := particles("Stars", {"at": Vector2(13, -22), "amount": 7, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "emit": {"box": Vector2(27, 18)}, "dir": -80, "spread": 40, "speed": [4, 18], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.3, 0.5], [0.6, 1], [1, 0]]})
	stars.process_material.lifetime_randomness = 0.5
	emit_all([roll, haze, dust, high, snow, stars], BURST)
	light_flash("BurstWhite", Vector2(2, -17), 64, Color.WHITE, 0.85, BURST, 0.14)
	light_flash("BurstCold", Vector2(16, -18), 86, C[4], 0.5, BURST, 0.55)
	# glints wink on the settling debris, chunks crumble into ice dust where they lie
	var settle := particles("DebrisGlints", {"at": Vector2(60, -3), "amount": 1, "lifetime": 0.3, "emitting": false, "texture": "plus3",
		"emit": {"box": Vector2(55, 2)}, "dir": -90, "speed": [3, 3], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.4, 0.4], [0.7, 1], [1, 0]]})
	emit(settle, BURST + 0.1, BURST + 1.0)
	var crumble := particles("Crumble", {"layer": "soft", "at": Vector2(70, -1.5), "amount": 4, "lifetime": 0.55, "emitting": false,
		"texture": tex("puff16"), "emit": {"box": Vector2(60, 1)}, "dir": -90, "spread": 50, "speed": [4, 12],
		"scale_curve": [[0, 0.3], [1, 0.5]], "ramp": gradient([Color(C[6], 0.45), Color(C[6], 0.2), Color(C[6], 0.0)], [0.0, 0.5, 1.0], true)})
	emit(crumble, BURST + 0.5, BURST + 1.5)
