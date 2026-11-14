# reimagined-from: src/fx/status/frozen.js@7ef8ecedc74ea65e71899349d414192b1e8b2126
# Frozen: Chilled to the bone: frost ferns creep over the body, icicles hang from chin and hands and drip, breath steams, snow settles, a shiver every second, frost spreads underfoot.
# loop, 2.00 s, 72x64 canvas, origin [36.0, 54.0], backdrop ground, stand-in 2
# ramp palette: #151a3d #212f6b #2c58aa #3a8bd8 #62c8f4 #a6ecff #dcfbff #ffffff
# The whole chilled body is the effect's own Actor with fx/status/_frozen_body.gdshader: its colours pulled toward
# ice, the dark rim frosted, frost ferns (the original's paths, below) creeping in from the outline and cracking off
# on each shiver; the Actor and everything on it judder for the shiver. Icicles (fx/status/_frozen_icicle.gdshader)
# grow, drip and shrink back on the original's beats; frost crusts the floor (_frozen_frost.gdshader); snow sits on
# the head and shoulders; emitters for falling snow, the flakes flung off each shiver and the breath steaming.
extends "res://build/fx/status/_status.gd"

const SHIVER := 1.0
# the original's frost-fern pixels [x, y, when] in mask space and its icicles [x, y, length, phase, period]: its plan
# picks fern roots with a shuffle (V8's sort under a random comparator), so they're its choices, written down once
const FERNS := [
	[8, 22, 0], [9, 22, 0.1111], [10, 21, 0.1778], [10, 20, 0.2444], [10, 23, 0.1778], [10, 23, 0.2444],
	[10, 21, 0.2222], [11, 21, 0.3333], [12, 20, 0.4], [12, 20, 0.4667], [12, 22, 0.4], [13, 23, 0.4667],
	[12, 21, 0.4444], [13, 20, 0.5556], [13, 19, 0.6222], [14, 21, 0.6222], [14, 20, 0.6667], [15, 19, 0.7778],
	[15, 18, 0.8444], [16, 19, 0.8444], [16, 18, 0.8889], [18, 22, 0], [17, 21, 0.1111], [16, 22, 0.1778],
	[17, 20, 0.1778], [17, 19, 0.2444], [16, 21, 0.2222], [15, 21, 0.3333], [14, 22, 0.4], [14, 23, 0.4667],
	[14, 20, 0.4], [14, 19, 0.4667], [14, 21, 0.4444], [13, 21, 0.5556], [12, 21, 0.6222], [12, 20, 0.6222],
	[12, 19, 0.6889], [12, 20, 0.6667], [10, 20, 0.7778], [10, 21, 0.8444], [10, 19, 0.8444], [9, 20, 0.8889],
	[9, 31, 0], [10, 31, 0.1111], [11, 30, 0.1778], [11, 32, 0.1778], [11, 33, 0.2444], [11, 34, 0.3111],
	[11, 31, 0.2222], [12, 31, 0.3333], [13, 31, 0.4], [14, 30, 0.4667], [12, 32, 0.4], [13, 32, 0.4444],
	[14, 32, 0.5556], [15, 32, 0.6222], [14, 33, 0.6222], [15, 33, 0.6667], [16, 33, 0.7778], [17, 33, 0.8444],
	[16, 34, 0.8444], [17, 34, 0.8889], [9, 28, 0], [10, 27, 0.1111], [9, 26, 0.1778], [9, 25, 0.2444],
	[9, 24, 0.3111], [10, 28, 0.1778], [11, 28, 0.2444], [10, 27, 0.2222], [11, 26, 0.3333], [11, 25, 0.4],
	[11, 24, 0.4667], [12, 26, 0.4], [12, 25, 0.4444], [13, 25, 0.5556], [13, 24, 0.6222], [14, 25, 0.6222],
	[14, 24, 0.6667], [14, 23, 0.7778], [14, 22, 0.8444], [15, 23, 0.8444], [15, 22, 0.8889], [17, 25, 0],
	[16, 24, 0.1111], [15, 25, 0.1778], [15, 26, 0.2444], [14, 27, 0.3111], [16, 23, 0.1778], [15, 24, 0.2222],
	[14, 24, 0.3333], [13, 25, 0.4], [13, 23, 0.4], [13, 22, 0.4667], [13, 23, 0.4444], [12, 23, 0.5556],
	[11, 24, 0.6222], [10, 24, 0.6889], [12, 22, 0.6222], [11, 22, 0.6667], [10, 22, 0.7778], [9, 22, 0.8444],
	[10, 21, 0.8444], [9, 21, 0.8889], [18, 25, 0], [17, 25, 0.1111], [16, 25, 0.1778], [15, 25, 0.2444],
	[17, 24, 0.1778], [17, 23, 0.2444], [16, 24, 0.2222], [15, 24, 0.3333], [14, 25, 0.4], [14, 25, 0.4667],
	[15, 23, 0.4], [15, 22, 0.4667], [14, 24, 0.4444], [13, 24, 0.5556], [12, 25, 0.6222], [13, 23, 0.6222],
	[12, 22, 0.6889], [12, 24, 0.6667], [11, 24, 0.7778], [11, 25, 0.8444], [10, 23, 0.8444], [10, 24, 0.8889]]
const ICICLES := [[18, 12, 5.4769, 0.4832, 2], [19, 11, 5.1097, 0.798, 1], [4, 18, 3.945, 0.9516, 2], [5, 21, 4.6726, 0.087, 1]]


static func since(t: float) -> float:
	return fposmod(t, SHIVER)


static func shake(t: float) -> int:
	if since(t) >= 0.22:
		return 0
	return 1 if int(floorf(t * 50.0 + 1e-6)) % 2 else -1


func make() -> void:
	var C := fit("palette", 8)
	var D: float = root.duration
	var S := shape_of()
	var H: float = AH

	# ---- behind: a cold light pooling on the floor and the frost crust round the feet
	glow("FloorLight", 26, {"radius": 24.0, "squash": 4.0 / 24.0, "color": C[4], "alpha": 0.24}, {"at": Vector2(0, 0.5), "back": true})
	var noise := Image.create(48, 1, false, Image.FORMAT_RGBA8)
	for i in 48:
		noise.set_pixel(i, 0, Color(jrand([i - 24, 17]), jrand([i - 24, 3]), 0, 1))
	var frost := shape("Frost", load(STATUS + "_frozen_frost.gdshader"), Vector2(48, 5),
		{"noise": asset("_frost_noise", noise), "reach": 13.0, "c4": C[4], "c5": C[5], "c6": C[6], "c7": C[7]},
		{"at": Vector2(0, 1.5), "back": true})
	loop_t(frost)
	sample(frost, "material:shader_parameter/reach", func(t: float) -> float: return 13.0 + 3.5 * sin(t / D * TAU), "linear")

	# ---- the body, chilled, ferns creeping over it; it judders on each shiver
	var body := actor_node()
	var m := ShaderMaterial.new()
	m.shader = load(STATUS + "_frozen_body.gdshader")
	m.set_shader_parameter("ramp", C)
	var data := Image.create(AW, AH, false, Image.FORMAT_RGBA8)
	data.fill(Color(1, 0, 0, 1))
	for f in FERNS:
		var u: float = f[2]
		var old := data.get_pixel(f[0], f[1])
		if u < old.r:
			data.set_pixel(f[0], f[1], Color(u, 1.0 if jrand([f[0], f[1], 5]) < 0.5 else 0.0, 0, 1))
	m.set_shader_parameter("ferns", asset("_ferns", data))
	body.material = m
	for c in C:
		keep_colour(c)
	sample(body, "material:shader_parameter/grow", func(t: float) -> float: return 0.2 + 0.65 * smooth(0.05, 0.95, since(t)), "linear")
	var shaking := [body]

	# snow settled on the head and shoulders
	var snow := {}
	for q in S.up:
		if q.y >= H * 0.6:
			continue
		snow[Vector2i(AX + q.x, AY + q.y - 1)] = C[7]
		if jrand([q.x, 4, 3]) < 0.45:
			snow[Vector2i(AX + q.x, AY + q.y - 2)] = C[7] if jrand([q.x, q.y, 9]) < 0.5 else C[6]
	var ledge := pixels("Snow", snow)
	shaking.append(ledge)

	# icicles under the hair, the jaw and the hands: they grow, a drop gathers and falls, they shrink back
	var i := 0
	for ic in ICICLES:
		var x0: int = AX + int(ic[0])
		var y0: int = AY + int(ic[1])
		var h := -y0
		var per: float = ic[4]
		var ph0: float = ic[3]
		var L0: float = ic[2]
		var node := shape("Icicle%d" % i, load(STATUS + "_frozen_icicle.gdshader"), Vector2(2, h),
			{"len": L0, "drop": 0.0, "drop_mode": 0, "c4": C[4], "c5": C[5], "c6": C[6], "c7": C[7]},
			{"at": Vector2(x0 + 1, y0 + h / 2.0)})
		var lens := []
		var drops := []
		var modes := []
		var pos := []
		for t in frame_times():
			var u := fposmod(t / per + ph0, 1.0)
			var L := L0 * (0.55 + 0.45 * smooth(0.0, 0.7, u))
			lens.append([t, L])
			var mode := 0
			var dy := 0.0
			if u > 0.7 and u < 0.86:
				mode = 1
				dy = L
			elif u >= 0.86:
				var f := (u - 0.86) * per
				dy = L + 0.5 * 760.0 * f * f
				if y0 + dy < -1.0:
					mode = 2
			modes.append([t, mode])
			drops.append([t, dy])
			pos.append([t, Vector2(x0 + 1 + shake(t), y0 + h / 2.0)])
		key(node, "material:shader_parameter/len", lens, "nearest")
		key(node, "material:shader_parameter/drop", drops, "nearest")
		key(node, "material:shader_parameter/drop_mode", modes, "nearest")
		key(node, "position", pos, "nearest")
		glow("IcicleLight%d" % i, 6, {"radius": 4.0, "color": C[5], "alpha": 0.18}, {"at": Vector2(x0 + 0.5, y0 + L0 * 0.5)})
		i += 1

	for n in shaking:
		sample(n, "position", func(t: float) -> Vector2: return Vector2(shake(t), 0) + (n.position if n != body else Vector2.ZERO))

	# ---- breath steaming from the mouth between shivers
	# four puffs a twentieth of a second apart, from 0.35 s into each shiver: a one-shot spread over 0.15 s
	for b in 2:
		var breath := particles("Breath%d" % b, {"layer": "soft", "at": Vector2(4.0, -32.0), "amount": 4, "lifetime": 0.6,
			"one_shot": true, "explosiveness": 0.75, "texture": "disc7", "emit": {"box": Vector2(1.0, 0.5)}, "dir": -20.0,
			"spread": 6.0, "speed": [15.0, 18.0], "drag": 2.2, "gravity": Vector2(0, -3), "color": C[7],
			"scale_curve": [[0.0, 0.23], [0.15, 0.48], [0.4, 0.66], [1.0, 0.9]],
			"alpha_curve": [[0.0, 0.18], [0.12, 0.5], [0.5, 0.34], [1.0, 0.0]]})
		emit(breath, 0.35 + b * SHIVER)

	# ---- snow drifting down over the head; flakes flung off by each shiver
	var flakes := gradient([C[7], C[6]])
	particles("SnowFall", {"at": Vector2(0, -54), "amount": 6, "lifetime": 1.3, "life_random": 0.1, "texture": "dot1",
		"emit": {"box": Vector2(14, 0.5)}, "dir": 90.0, "spread": 5.0, "speed": [13.0, 15.0], "initial": flakes,
		"alpha_curve": [[0.0, 0.0], [0.19, 1.0], [1.0, 1.0]]})
	var side := PackedVector2Array()
	for k in 8:
		var sd := 1.0 if k % 2 else -1.0
		side.append(Vector2(sd * (6.0 + 6.0 * jrand([k, 6])), 3.0 * jrand([k, 7]) - 1.5))
	for b in 2:
		var p := particles("Shiver%d" % b, {"at": Vector2(0, -36.5), "amount": 8, "lifetime": 0.5, "one_shot": true,
			"explosiveness": 1.0, "texture": "dot1", "emit": {"points": side}, "dir": -90.0, "spread": 0.0,
			"speed": [20.0, 50.0], "radial_speed": [20.0, 50.0], "gravity": Vector2(0, 300), "initial": gradient([C[6], C[6], C[7]]),
			"alpha_curve": [[0.0, 1.0], [0.2, 1.0], [1.0, 0.2]]})
		emit(p, b * SHIVER)

	# ---- a glint on the frosted shoulder as the shiver lands
	var sp := sparkle("Glint", {"color": C[6], "tip": C[5]})
	var sk := []
	for t in frame_times():
		var ph := since(t)
		var arm := jround(3.0 * (1.0 - ph / 0.25)) if ph < 0.25 else 0.0
		sk.append([t, Vector2(AX + roundf(AW * 0.3) + shake(t), AY + 4), arm, 0.4])
	sparkle_keys(sp, sk)

	# ---- cold light off the body, lifting with each shiver
	var cold := glow("ColdLight", 32, {"radius": 30.0, "color": C[4], "alpha": 0.2}, {"at": Vector2(0, AY + H * 0.45)})
	sample(cold, "material:shader_parameter/alpha", func(t: float) -> float: return 0.2 + 0.12 * exp(-since(t) / 0.2), "linear")
	glow("FeetLight", 18, {"radius": 16.0, "color": C[5], "alpha": 0.1}, {"at": Vector2(0, AY + 2)})
