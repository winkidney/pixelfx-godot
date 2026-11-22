# reimagined-from: src/fx/fire/fire-ring.js@94591eab6f9e00c1b3bcfc5cf23bb6af0574d6f9
# Fire ring: a white flash at the feet, then flames race outward along the floor in a ring, flaring as the front
# passes and burning down behind it over a smouldering scorch.
# The flames are ten rings of sites on the floor ellipse (the original's), each ring a set of layered emitters (a red
# rim, orange, a yellow heart) emitting from its sites' points, lit as the front reaches it, keyed to flare, cool
# and burn down; the far halves are behind the stand-in, the near halves in front. The front is a band of ring
# shaders racing out, the scorch a translucent ring of soot with embers cooling in it; streaks spiral in to charge,
# a flash and sparks burst at the feet, puffs, smoke and embers rise off the burning ring, and light runs with the
# front (sixteen glows keyed round it).
extends "res://build/fx/fire/_fire.gd"

const SY := 0.2
const CHARGE := 0.32
const SPREAD := 0.75
const SOOT2 := Color("#17121d")
const WARM := Color8(255, 176, 96)
const PL := 0.13         # how long a flame particle takes to climb its tongue

var REACH := 92.0


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func front(t: float) -> float:
	return REACH * out_cubic(clampf((t - CHARGE) / SPREAD, 0.0, 1.0))


func reached_at(d: float) -> float:
	return CHARGE + SPREAD * (1.0 - pow(1.0 - minf(1.0, d / REACH), 1.0 / 3.0))


func make() -> void:
	fire_begin()
	REACH = float(meta.options.reach)
	var D: float = root.duration
	var GLOW := glow_colour()
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6

	# the rings of sites, as the original lays them out
	var rings := []
	var r := 10.0
	while r <= REACH:
		var per := TAU * sqrt((r * r + pow(r * SY, 2.0)) / 2.0)
		var n := maxi(5, roundi(per / 8.5))
		var q := minf(1.0, r / REACH)
		var back := PackedVector2Array()
		var near := PackedVector2Array()
		for k in n:
			var a := (k + rng.randf_range(0.15, 0.85)) / n * TAU
			var rr := r + rng.randf_range(-3, 3)
			var p := Vector2(cos(a) * rr, sin(a) * rr * SY)
			if sin(a) < 0.0:
				back.append(p)
			else:
				near.append(p)
		rings.append({"r": r, "q": q, "t0": reached_at(r) + 0.02, "life": 0.3 + 1.0 * q * q, "h": 14.0 * (0.6 + 0.55 * q),
			"w": 2.25 * (0.75 + 0.3 * q), "back": back, "near": near, "all": back + near})
		r += 9.0

	# ---- behind the stand-in: the scorch, the far half of the front, the far flames, smoke
	var soot := ring("Soot", REACH + 2, {"radius": 1.0, "squash": SY, "color": SOOT2, "translucent": true, "alpha": 0.0}, {"back": true})
	key(soot, "material:shader_parameter/radius", sampled(func(t: float): return maxf(0.5, front(t - 0.12))))
	key(soot, "material:shader_parameter/alpha", sampled(func(t: float): return 0.42 * smooth(CHARGE, CHARGE + 0.3, t) * (1.0 - smooth(D - 1.2, D - 0.15, t))))
	var i := 0
	var prev := 0.0
	for R in rings:
		# embers cooling in the soot where the front has crossed: still pixels, hot first
		var pts := PackedVector2Array()
		var area: float = PI * SY * (R.r * R.r - prev * prev)
		for k in int(area * 0.05):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf_range(prev * prev, R.r * R.r))
			pts.append(Vector2(cos(a) * d, sin(a) * d * SY).floor() + Vector2(0.5, 0.5))
		prev = R.r
		var specks := particles("Specks%d" % i, {"back": true, "amount": maxi(2, pts.size()), "lifetime": 1.9, "one_shot": true,
			"explosiveness": 0.7, "randomness": 0.4, "texture": "dot1", "emit": {"points": pts}, "speed": [0, 0],
			"ramp": gradient([H[3], H[4], H[5], H[6], Color(H[6], 0.0)], [0.0, 0.3, 0.55, 0.8, 0.97])})
		emit(specks, R.t0 - 0.02)
		i += 1
	band(-1)
	var order := rings.duplicate()
	order.reverse()
	for R in order:
		site_flames("Back%d" % rings.find(R), R, R.back, true)
	# floor light running with the front
	for k in 16:
		var a := k / 16.0 * TAU
		var g := glow("Floor%d" % k, 16, {"radius": 16, "color": GLOW, "alpha": 0.0}, {"at": Vector2.ZERO})
		key(g, "position", sampled(func(t: float): return Vector2(cos(a) * front(t), sin(a) * front(t) * SY - 3.0), CHARGE - 0.04, CHARGE + SPREAD + 1.5))
		key(g, "material:shader_parameter/alpha", sampled(func(t: float): return 0.0 if t < CHARGE else 0.2 * (1.0 - smooth(CHARGE + SPREAD, CHARGE + SPREAD + 1.4, t)), 0.0, CHARGE + SPREAD + 1.5))
	for R in rings:
		var j := rings.find(R)
		var sm_pts := PackedVector2Array()
		for p in R.all:
			sm_pts.append(p + Vector2(0, -R.h - 3))
		var smoke := particles("Smoke%d" % j, {"layer": "soft", "back": true, "amount": maxi(2, int(R.all.size() * 0.35)), "lifetime": 1.2,
			"randomness": 0.4, "texture": "disc3", "emit": {"points": sm_pts}, "dir": -90, "spread": 20, "speed": [8, 18], "damping": [4, 8],
			"gravity": Vector2(0, -12), "scale": [0.8, 1.2], "scale_curve": [[0, 0.7], [1, 1.4]],
			"ramp": gradient([Color("#7b6f72", 0.0), Color("#7b6f72", 0.22), Color("#5d5660", 0.16), Color("#433d48", 0.0)], [0.0, 0.1, 0.5, 0.95])})
		emit(smoke, R.t0 + 0.2, R.t0 + R.life * 0.7 + 0.2)

	# ---- in front: the near half of the front, the near flames, puffs, embers, sparks, the flash
	band(1)
	for R in rings:
		site_flames("Near%d" % rings.find(R), R, R.near, false)
	for R in rings:
		var j := rings.find(R)
		var pp := PackedVector2Array()
		for p in R.all:
			pp.append(p + Vector2(0, -R.h * 0.6))
		var puffs := particles("Puffs%d" % j, {"amount": maxi(2, int(R.all.size() * 0.12)), "lifetime": 0.3, "randomness": 0.3,
			"texture": "disc3", "emit": {"points": pp}, "dir": -90, "spread": 12, "speed": [20, 40], "gravity": Vector2(0, -95),
			"damping": [20, 40], "scale": [0.7, 1.0], "scale_curve": [[0, 0.7], [0.15, 1.0], [1, 0.5]],
			"ramp": gradient([H[1], H[2], H[3], H[4], H[5], H[6]], [0.0, 0.12, 0.3, 0.5, 0.7, 0.88])})
		emit(puffs, R.t0, R.t0 + R.life * 0.7)
		var embers := particles("Embers%d" % j, {"amount": maxi(1, int(R.all.size() * 0.05)), "lifetime": 1.1, "randomness": 0.4,
			"texture": "dot1", "emit": {"points": pp}, "dir": -90, "spread": 20, "speed": [30, 70], "damping": [30, 50],
			"gravity": Vector2(0, -25), "ramp": gradient([H[1], H[2], H[4], Color(H[4], 0.0)], [0.0, 0.4, 0.7, 0.97]),
			"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
		emit(embers, R.t0, R.t0 + R.life * 0.7)

	# the charge: streaks of fire spiral in to the feet, flame puffs and heat build there
	var spts := PackedVector2Array()
	for k in 24:
		var a := rng.randf() * TAU
		var d := rng.randf_range(26, 54)
		spts.append(Vector2(cos(a) * d, minf(-2.0, -6.0 + sin(a) * d * 0.45) + 4.0))
	var streaks := particles("Streaks", {"at": Vector2(0, -4), "amount": 9, "lifetime": 0.22, "randomness": 0.2, "texture": "streak4",
		"align": true, "emit": {"points": spts}, "speed": [0, 0], "radial": [-560, -520], "emitting": true,
		"initial": gradient([H[2], H[3]]), "alpha_curve": [[0, 1], [0.9, 1], [1, 0]]})
	(streaks.process_material as ParticleProcessMaterial).radial_velocity_min = -135
	(streaks.process_material as ParticleProcessMaterial).radial_velocity_max = -120
	emit(streaks, 0.0, CHARGE - 0.05)
	var feet := particles("ChargePuffs", {"at": Vector2(0, -1), "amount": 6, "lifetime": 0.2, "randomness": 0.3, "texture": "disc3",
		"emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 15, "speed": [20, 40], "gravity": Vector2(0, -95),
		"scale": [0.6, 1.2], "ramp": gradient([H[0], H[1], H[2], H[4], H[5]], [0.0, 0.15, 0.35, 0.6, 0.85])})
	emit(feet, 0.0, CHARGE)
	key(feet, "amount_ratio", [[0.0, 0.1], [CHARGE, 1.0]])
	var charge := glow("ChargeLight", 32, {"radius": 8, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, -3)})
	key(charge, "material:shader_parameter/radius", sampled(func(t: float): return 8.0 + 22.0 * minf(1.0, t / CHARGE), 0.0, CHARGE + 0.04))
	key(charge, "material:shader_parameter/alpha", sampled(func(t: float): return 0.6 * t / CHARGE if t < CHARGE else 0.0, 0.0, CHARGE + 0.04))

	# the release: a white flash at the feet, sparks thrown out, a burst of light
	var flash := ring("Flash", 16, {"radius": 14, "squash": 4.0 / 14.0, "color": H[2]}, {"at": Vector2(0, -1)})
	var heart := ring("FlashHeart", 10, {"radius": 9, "squash": 2.6 / 9.0, "color": Color.WHITE}, {"at": Vector2(0, -1)})
	var fk := []
	var hk := []
	for k in 4:
		var t := CHARGE + k / 30.0
		var kk := 1.0 - (t - CHARGE) / 0.1
		fk.append([t, 14.0 * (0.6 + 0.4 * kk)])
		hk.append([t, 9.0 * (0.6 + 0.4 * kk)])
	key(flash, "material:shader_parameter/radius", fk)
	key(heart, "material:shader_parameter/radius", hk)
	key(heart, "material:shader_parameter/color", [[CHARGE, Color.WHITE], [CHARGE + 0.05, H[1]]], "nearest")
	show(flash, CHARGE, CHARGE + 0.1)
	show(heart, CHARGE, CHARGE + 0.1)
	var sparks := particles("Sparks", {"at": Vector2(0, -2), "amount": 40, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "emitting": false, "texture": "streak4", "align": true, "emit": {"box": Vector2(3, 0.5)}, "dir": -90,
		"spread": 80, "speed": [80, 220], "damping": [180, 300], "gravity": Vector2(0, 427),
		"ramp": gradient([H[1], H[2], H[4], H[5]], [0.0, 0.4, 0.7, 0.9]), "collide": {"bounce": 0.45, "friction": 0.3}})
	emit(sparks, CHARGE)
	burst_light("BurstWarm", Vector2(0, -18), 64, WARM, 0.85, 0.5)
	burst_light("BurstWhite", Vector2(0, -6), 30, Color.WHITE, 0.8, 0.08)
	var big := glow("Light", 94, {"radius": 92, "color": GLOW, "alpha": 0.0}, {"at": Vector2(0, -6)})
	key(big, "material:shader_parameter/alpha", sampled(func(t: float): return 0.3 * smooth(CHARGE - 0.05, CHARGE, t) * (1.0 - smooth(CHARGE + SPREAD * 0.5, CHARGE + SPREAD + 1.2, t)), 0.0, CHARGE + SPREAD + 1.3))


## A light that fades as k² and shrinks to 55 % over its life (the original's Lights).
func burst_light(name: String, at: Vector2, r: float, c: Color, k: float, life: float) -> void:
	var g := glow(name, r, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	key(g, "material:shader_parameter/radius", sampled(func(t: float): return r * (0.55 + 0.45 * clampf(1.0 - (t - CHARGE) / life, 0.0, 1.0)), CHARGE, CHARGE + life))
	key(g, "material:shader_parameter/alpha", [[0.0, 0.0], [CHARGE - 0.001, 0.0]] + sampled(func(t: float):
		var u := clampf(1.0 - (t - CHARGE) / life, 0.0, 1.0)
		return k * u * u, CHARGE, CHARGE + life + 0.04))


## The front: a band racing out along the floor, white-hot at its leading edge, red behind. side 1: the near half
## (in front of the stand-in), -1: the far half.
func band(side: int) -> void:
	var cols := [[1.0, H[6], 0.55], [0.7, H[4], 0.85], [0.4, H[2], 1.0], [0.15, H[1], 1.0]]
	var j := 0
	for c in cols:
		var b := ring("Band%s%d" % ["Near" if side > 0 else "Far", j], REACH + 3, {"radius": 1.0, "thickness": 1.0, "squash": SY,
			"color": c[1], "side": -1.0 if side > 0 else 1.0, "alpha": 0.0}, {"back": side < 0})
		var share: float = c[0]
		var al: float = c[2]
		key(b, "material:shader_parameter/radius", sampled(func(t: float): return front(t) + 1.5, CHARGE, CHARGE + SPREAD + 0.1))
		key(b, "material:shader_parameter/thickness", sampled(func(t: float):
			var k := (t - CHARGE) / (SPREAD + 0.1)
			return maxf(1.0 if share < 0.2 else 0.6, maxf(1.5, 6.0 * (1.0 - k)) * share), CHARGE, CHARGE + SPREAD + 0.1))
		key(b, "material:shader_parameter/alpha", [[0.0, 0.0], [CHARGE - 0.001, 0.0]] + sampled(func(t: float):
			var k := (t - CHARGE) / (SPREAD + 0.1)
			if k < 0.0 or k >= 1.0:
				return 0.0
			return al * (1.0 if k < 0.75 else (1.0 - k) / 0.25), CHARGE, CHARGE + SPREAD + 0.1) + [[CHARGE + SPREAD + 0.11, 0.0]])
		if share < 0.2:
			key(b, "material:shader_parameter/color", [[0.0, Color.WHITE], [CHARGE + (SPREAD + 0.1) * 0.12, H[1]]], "nearest")
		j += 1


## One ring's flames on one half: three layered emitters (red rim, orange, yellow heart) from its sites, lit when the
## front reaches it, flaring, cooling and burning down over its life. The layers share a seed, so they nest.
func site_flames(name: String, R: Dictionary, pts: PackedVector2Array, back: bool) -> void:
	if pts.is_empty():
		return
	var n := pts.size()
	var t0: float = R.t0
	var life: float = R.life
	var h: float = R.h
	var w: float = R.w
	# [width share, height share, per-site particles, colours young / burning / dying]
	var layers := [[1.0, 1.0, 4.0, [H[6], H[7], H[7]]], [0.72, 0.84, 4.0, [H[4], H[5], H[6]]], [0.48, 0.64, 4.0, [H[1] if not back else H[2], H[3], H[5]]]]
	var k := 0
	for L in layers:
		var lw: float = L[0]
		var lh: float = L[1]
		var half := maxf(0.6, w * lw)
		var tex := "disc5" if half > 1.6 else "disc3"
		var ts := 5.0 if tex == "disc5" else 3.0
		var s := (2.0 * half + 1.0) / ts
		var v := h * lh / PL
		var p := particles("%s_%d" % [name, k], {"back": back, "amount": maxi(3, int(n * float(L[2]))), "lifetime": PL,
			"randomness": 0.15, "texture": tex, "emit": {"points": pts}, "dir": -90, "spread": 2, "speed": [v * 0.75, v * 1.05],
			"scale": [s * 0.9, s * 1.1], "scale_curve": TAPER, "color": L[3][0], "emitting": false})
		# the same seed, count and timing for every layer: particle i of each lands on the same site at the same
		# moment, so the layers nest into one tongue (rim round orange round a yellow heart)
		p.seed = absi(hash(id + name)) % 1000003
		emit(p, t0, t0 + life)
		var hk := sampled(func(t: float):
			var age := t - t0
			var u := clampf(age / life, 0.0, 1.0)
			var rise := out_back(clampf(age / 0.08, 0.0, 1.0), 2.0)
			var fade := 1.0 - pow(maxf(0.0, (u - 0.1) / 0.9), 1.3)
			var hh := rise * fade * (0.85 + 0.15 * N(t, 3.3, k + int(R.r))) * (1.0 + 0.5 * maxf(0.0, N(t, 2.6, int(R.r) + 70) - 0.55))
			return maxf(0.05, hh), t0, t0 + life)
		var vmin := []
		var vmax := []
		var smin := []
		var smax := []
		for e in hk:
			vmin.append([e[0], v * 0.75 * e[1]])
			vmax.append([e[0], v * 1.05 * e[1]])
			var fade := 1.0 - pow(maxf(0.0, ((e[0] - t0) / life - 0.1) / 0.9), 1.3)
			smin.append([e[0], s * 0.9 * (0.6 + 0.4 * fade)])
			smax.append([e[0], s * 1.1 * (0.6 + 0.4 * fade)])
		key(p, "process_material:initial_velocity_min", vmin)
		key(p, "process_material:initial_velocity_max", vmax)
		key(p, "process_material:scale_min", smin)
		key(p, "process_material:scale_max", smax)
		var cs: Array = L[3]
		key(p, "process_material:color", [[0.0, cs[0]], [t0 + life * 0.3, cs[1]], [t0 + life * 0.65, cs[2]]], "nearest")
		k += 1
