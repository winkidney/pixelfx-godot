# reimagined-from: src/fx/holy/holy-pillar.js@0bb153e1bc9959fcbc492c18cf6689260bff39db
# Holy pillar: Light breaks through from above: a sun opens at the top and a fan of shafts converges on the mark, pulsing, while a sigil burns on the floor; then the fan folds shut.
# one-shot, 3.50 s, 192x232 canvas, origin [96.0, 204.0], backdrop ground
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The fan is a shader behind everything (fx/holy/_pillar_fan.gdshader, soft layer, with its light twin
# _pillar_fan_light): the shafts are rolled with the original's generator, and unfold, pour down, pulse, fold shut
# and lift away on its clock. The sun (fx/holy/_pillar_sun.gdshader) opens like an iris on a keyed radius; the sigil
# (fx/holy/_pillar_sigil.gdshader, far half behind) burns in round from the front and cools. Particles: streaks
# gathering to the sun, sparks off the mark when the light lands (bouncing on the floor), embers off the burning
# sigil, stars in the shafts and when the fan snaps shut, motes in the light and a few feathers (the original's
# feather as a texture) sinking through it; sparkles and lights on the original's beats.
extends "res://build/fx/holy/_strike.gd"

const TOP := -204.0
const PY := -1.0
const SUN := TOP + 38.0
const SY := 0.24
const RX := 26.0
const OPEN := 0.3
const HIT := 0.66
const FOLD := 2.05
const SHUT := 2.45
const LIFT := 2.75


static func in_back(x: float, s := 1.70158) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else (s + 1.0) * x * x * x - s * x * x)


func make() -> void:
	ground()
	var D: float = meta.duration
	var N: int = maxi(3, int(meta.options.shafts))
	var R := Rng.new(int(meta.options.seed))
	var mid := (N - 1) / 2.0
	var sh := PackedVector4Array()
	var far := PackedFloat32Array()
	for i in 7:
		if i >= N:
			sh.append(Vector4.ZERO)
			far.append(0.0)
			continue
		var off := i - mid
		var fr := absf(off) / mid
		var th := off * (0.4 / mid) + R.range(-0.02, 0.02)
		var spread := R.range(0.05, 0.085) * (1.0 - fr * 0.25)
		var b := (1.0 - fr * 0.35) * R.range(0.8, 1.0)
		sh.append(Vector4(th, spread, b, R.range(0.0, 1.0)))
		far.append(fr)

	# ---- the fan of shafts and its light
	var fsz := Vector2(192, 204)
	var fat := Vector2(0, -102)
	var fan := shape("Fan", holy_shader("pillar_fan"), fsz, {"n": mini(N, 7), "sh": sh, "far": far, "c6": C[6], "translucent": true}, {"at": fat, "back": true})
	key(fan, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var fan_l := shape("FanLight", holy_shader("pillar_fan_light"), fsz, {"n": mini(N, 7), "sh": sh, "far": far, "c4": C[4], "c5": C[5]}, {"at": fat})
	key(fan_l, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])

	# ---- the sigil burning on the floor: far half behind, near half in front
	var heat := func(t: float) -> float: return 1.0 - smooth(SHUT, SHUT + 0.8, t)
	var outk := func(t: float) -> float: return (1.0 - smooth(SHUT + 0.4, SHUT + 1.0, t)) if t >= HIT else 0.0
	for side in [true, false]:
		var sg := shape("SigilFar" if side else "SigilNear", holy_shader("pillar_sigil"), Vector2(60, 18), {"back": side, "pal": C}, {"back": side})
		key(sg, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
		keyn(sg, "material:shader_parameter/u", func(t: float) -> float: return seg(t, HIT, HIT + 0.2), 0.0, HIT + 0.3)
		keyn(sg, "material:shader_parameter/heat", heat)
		keyn(sg, "material:shader_parameter/out_k", outk)
		keyn(sg, "material:shader_parameter/first", func(t: float) -> bool: return t < HIT + 0.08, 0.0, HIT + 0.2)
	var sg_l := glow("SigilLight", 44, {"radius": 40, "squash": 0.45, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -2)})
	keyn(sg_l, "material:shader_parameter/alpha", func(t: float) -> float: return 0.45 * outk.call(t) * (0.5 + 0.5 * heat.call(t)))
	var sg_w := glow("SigilWhite", 11, {"radius": 10, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -1)})
	keyn(sg_w, "material:shader_parameter/alpha", func(t: float) -> float: return 0.3 * heat.call(t) * outk.call(t))

	# ---- the sun: opens like an iris, rays ticking round it, closes with a glint
	var sr := func(t: float) -> float: return 15.0 * out_back(seg(t, 0.02, 0.45), 1.8) * (1.0 - in_back(seg(t, SHUT, LIFT + 0.1), 1.5))
	var sun_at := Vector2(0, SUN)
	var sun := shape("Sun", holy_shader("pillar_sun"), Vector2(60, 60), {"c4": C[4], "c5": C[5], "c6": C[6]}, {"at": sun_at})
	keyn(sun, "material:shader_parameter/r", sr)
	key(sun, "material:shader_parameter/spin", [[0.0, 0.0], [D, D * 0.6]])
	var sun_g := glow("SunGlow", 34, {"radius": 1, "color": C[4], "alpha": 0.5}, {"at": sun_at})
	keyn(sun_g, "material:shader_parameter/radius", func(t: float) -> float: return minf(32.0, sr.call(t) * 3.0))
	keyn(sun_g, "material:shader_parameter/alpha", func(t: float) -> float: return 0.5 if sr.call(t) > 0.5 else 0.0)
	var sun_w := glow("SunWhite", 26, {"radius": 1, "color": Color.WHITE, "alpha": 0.35}, {"at": sun_at})
	keyn(sun_w, "material:shader_parameter/radius", func(t: float) -> float: return sr.call(t) * 1.4)
	keyn(sun_w, "material:shader_parameter/alpha", func(t: float) -> float: return 0.35 if sr.call(t) > 0.5 else 0.0)
	# light gathers to the sun as it opens
	var gather := particles("Gather", {"at": sun_at, "amount": 14, "lifetime": 0.23, "life_random": 0.3, "emitting": false, "texture": "streak4", "align": true,
		"emit": {"ring": [34.0, 22.0]}, "radial_speed": [-110, -60], "initial": gradient([C[6], C[5]]), "alpha_curve": [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]]})
	emit(gather, 0.0, OPEN + 0.1)

	# ---- sparkles and lights on the beats
	for b in [["Land", HIT - 0.02, 0.27, 12.0, Vector2(0, PY - 2), 0.7], ["Snap", SHUT, 0.2, 8.0, Vector2(0, PY - 2), 0.5], ["Glint", LIFT, 0.3, 10.0, sun_at, 0.6]]:
		var t0: float = b[1]
		var life: float = b[2]
		var arm0: float = b[3]
		var k0: float = b[5]
		var arm := func(t: float) -> float: return minf(9.0, arm0 * (1.0 - (t - t0) / life)) if (t >= t0 and t < t0 + life) else 0.0
		var sp := sparkle(b[0], b[4], 0.0, Color.WHITE, C[5])
		keyn(sp, "material:shader_parameter/arm", arm, 0.0, t0 + life + 0.07)
		var sl := glow(b[0] + "Light", 26, {"radius": 24, "color": Color.WHITE, "alpha": 0.0}, {"at": b[4]})
		keyn(sl, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * roundf(arm.call(t)), 0.0, t0 + life + 0.07)
		keyn(sl, "material:shader_parameter/alpha", func(t: float) -> float: return k0 if arm.call(t) >= 0.5 else 0.0, 0.0, t0 + life + 0.07)
	light_burst("HitLight", HIT, Vector2(0, -30), 64, C[5], 0.85, 0.5)
	light_burst("HitWhite", HIT, Vector2(0, -6), 30, Color.WHITE, 0.8, 0.12)
	light_burst("ShutLight", SHUT, Vector2(0, -60), 70, C[5], 0.7, 0.35)
	light_burst("GlintLight", LIFT, sun_at, 40, Color.WHITE, 0.6, 0.2)

	# ---- when the light lands: sparks off the mark
	var sparks := spark_particles("Sparks", [Color.WHITE, C[6], C[5], C[3]], {"at": Vector2(0, -2), "amount": 26, "lifetime": 0.6, "life_random": 0.55,
		"emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 69, "speed": [70, 190]})
	emit(sparks, HIT)

	# ---- while it holds: embers off the sigil, stars and motes in the shafts, feathers sinking through them
	var rim := PackedVector2Array()
	for j in 96:
		var g := j / 96.0 * TAU
		var r := RX * (1.0 if j % 2 else 0.72)
		rim.append(Vector2(cos(g) * r, sin(g) * r * SY - 1.0))
	var embers := particles("Embers", {"amount": 26, "lifetime": 0.8, "life_random": 0.4, "emitting": false, "texture": "dot1", "emit": {"points": rim},
		"dir": -90, "spread": 14, "speed": [12, 30], "drag": 1.2, "ramp": gradient([Color.WHITE, C[5], C[5], Color(C[4], 0.0)], [0.0, 0.2, 0.6, 0.92])})
	emit(embers, HIT, SHUT + 0.1)
	twin(embers, {"texture": "glow8", "modulate": Color(C[5], 0.3)})
	var stars := star_particles("Stars", 1.4, Color.WHITE, C[6], {"at": Vector2(0, -90), "amount": 3, "lifetime": 0.6, "life_random": 0.5, "one_shot": false,
		"explosiveness": 0.0, "emit": {"box": Vector2(40, 70)}, "dir": 90, "speed": [2, 8]})
	emit(stars, HIT, FOLD)
	twin(stars, {"texture": "glow8", "modulate": Color(C[6], 0.4)})
	var shut_stars := star_particles("ShutStars", 1.6, Color.WHITE, C[6], {"at": Vector2(0, -90), "amount": 12, "lifetime": 0.8, "life_random": 0.5,
		"emit": {"box": Vector2(4, 80)}, "dir": 0, "spread": 180, "speed": [4, 25]})
	emit(shut_stars, SHUT)
	twin(shut_stars, {"texture": "glow8", "modulate": Color(C[6], 0.4)})
	var field := PackedVector2Array()
	var g2 := RandomNumberGenerator.new()
	g2.seed = 5
	for i in 160:
		var y := g2.randf_range(TOP + 20, -12)
		field.append(Vector2(g2.randf_range(-0.42, 0.42) * (PY - y), y))
	var motes := particles("Motes", {"amount": 30, "lifetime": 1.1, "life_random": 0.4, "emitting": false, "texture": "dot1", "emit": {"points": field},
		"dir": 90, "speed": [7, 18], "ramp": gradient([Color(C[6], 0.0), C[6], Color.WHITE, C[6], Color(C[6], 0.0)], [0.0, 0.15, 0.4, 0.6, 0.85])})
	emit(motes, HIT - 0.15, SHUT - 0.3)
	twin(motes, {"modulate": Color(C[5], 0.4)})
	var wing := PackedColorArray([C[2], C[3], C[4], C[5], C[6], Color.WHITE])
	var feathers := particles("Feathers", {"at": Vector2(0, -125), "amount": 6, "lifetime": 1.6, "life_random": 0.1, "one_shot": true, "explosiveness": 0.3, "emitting": false,
		"texture": asset("feather.png", feather_image(8.0, 2.1, wing, 1, 0.0, 0.2)), "emit": {"box": Vector2(46, 25)}, "dir": 90, "spread": 40,
		"speed": [4, 10], "gravity": Vector2(0, 14), "angle": [-30, 30], "spin": [-50, 50], "alpha_curve": [[0.0, 0.0], [0.05, 1.0], [0.72, 1.0], [1.0, 0.0]],
		"turbulence": {"strength": 3.0, "scale": 2.0, "influence": [0.015, 0.03]}})
	emit(feathers, HIT + 0.1)
	twin(feathers, {"texture": "glow16", "modulate": Color(C[5], 0.22)})
