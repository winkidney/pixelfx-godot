# reimagined-from: src/fx/projectiles/muzzle-smg.js@f0c6a5696fe02db15ab2480bef7e1b7455dcef39
# SMG burst: Sustained fire at twelve rounds a second: each shot a different spiky flash with a white core, sparks, smoke wisps piling up and drifting, brass casings bouncing on the floor.
# loop, 1.00 s, 112x72 canvas, origin [56.0, 66.0], backdrop ground
# Twelve shots a loop, each drawn from the original's own rng(S, s, ...) (projectiles/_projectiles.gd): its flash is
# its own lobes (flash_shape() + flash(), a hero frame then a cooler one, shown on the frames the original shows
# them); its sparks and unburnt grains are GPU particles stepped with the original's gravity and drag (_muzzle.gd
# bits(): one looping emitter per spark of a shot, so each is born on its shot, with points of light); its three
# smoke wisps are GPU particles on the original's closed-form paths (_muzzle_puff.gdshader mode 1: a push forward,
# a lift, a drift back over the gun, piling into a haze the latest pop lights warm; drawn lit by
# _muzzle_lobe.gdshader); its casing tumbles out of the port, bounces and lies a moment (_lib.js casing(),
# _muzzle_casing.gdshader). A pop of light at the muzzle on every shot.
extends "res://build/fx/projectiles/_muzzle.gd"

const SHOTS := 12
const F1 := 1.0 / 30.0


func make() -> void:
	var F := pal("palette")
	var B := pal("brass")
	var SM := pal("smoke")
	var S := int(meta.options.seed)
	var D: float = root.duration
	var H: float = meta.options.height
	var MY := -H
	var top := -float(root.origin.y) + 1.0
	var SP := [F[7], F[6], F[4], F[3]]
	# a shot's age at t (it fires at s * D / SHOTS, every loop)
	var age_of := func(s: int, t: float) -> float: return fposmod(t - s * D / SHOTS + 1e-7, D)
	var pop := func(t: float, tau: float, life: float) -> float:
		var k := 0.0
		for s in SHOTS:
			var a: float = age_of.call(s, t)
			if a < life:
				k = maxf(k, exp(-(a + 0.008) / tau))
		return k

	# smoke: every shot leaves three wisps; particle i of 108 is born at i / 36 s, wisp i % 36 (shot s, wisp j)
	var rows := [[], [], []]
	for s in SHOTS:
		for j in 3:
			var r := rng([S, s, j, 3])
			var life := r.range(1.5, 2.2)
			var port := j == 2
			var vx := r.range(-12, 6) if port else r.range(45, 100) * (1.0 - j * 0.4)
			var vy := -r.range(14, 26) if port else -r.range(4, 16)
			var drift := r.range(3, 7)
			var phase := r.range(0, TAU)
			var lift := r.range(9, 16)
			var grow := r.range(2, 4.5)
			rows[0].append(Vector4(-7.0 if port else 3.0, MY - 2.0 if port else MY, vx, vy))
			rows[1].append(Vector4(life, drift, lift, phase))
			rows[2].append(Vector4(1.0 if port else 1.2, grow, 0.24 if port else 0.34, j * (0.03 - 1.0 / 36.0)))
	var WR := PackedColorArray([SM[0], mixc(F[1], SM[1], 0.5), mixc(F[2], SM[2], 0.4), F[3], F[4], F[5], F[7]])
	var smoke := particles("Smoke", {"layer": "soft", "amount": 108, "lifetime": 3.0, "preprocess": 3.0, "texture": "glow16", "local": true,
		"process_shader": PROJ + "_muzzle_puff.gdshader", "process_params": {"count": 36.0, "mode": 1.0, "wmul": 1.0, "top": top, "muzzle": Vector2(0, MY)}})
	smoke.process_material.set_shader_parameter("data", data_tex("smoke_data", rows))
	smoke.material = lobe_mat(SM, WR, 1.4, 0.7, 1.3)
	keyf(smoke, "process_material:shader_parameter/wmul", func(t: float) -> float: return pop.call(t, 0.035, 0.2), 0.0, D, 30.0, "nearest")

	# casings: thrown up and back out of the ejection port, tumbling, bouncing on the floor, then lying a moment
	for s in SHOTS:
		var r := rng([S, s, 7])
		var cvx := -r.range(18, 48)
		var cvy := -r.range(85, 135)
		var cva := r.sign() * r.range(20, 32)
		var ca0 := r.range(0, TAU)
		var ss: int = s
		var cf := func(t: float) -> Dictionary:
			var a: float = age_of.call(ss, t)
			var k := casing(-7, MY - 1, cvx, cvy, cva, a, 850, -0.5, 0.42, ca0)
			k.fade = clampf((D - a) / 0.25, 0.0, 1.0)
			k.glint = 1.0 if (k.hit >= 0.0 and k.hit < 0.07) else 0.0
			return k
		var lo := Vector2(1e9, 1e9)
		var hi := -lo
		for i in 31:
			var k: Dictionary = cf.call(i / 30.0)
			lo = Vector2(minf(lo.x, k.x), minf(lo.y, k.y))
			hi = Vector2(maxf(hi.x, k.x), maxf(hi.y, k.y))
		casing_node("Casing%d" % s, 0, [B[1], B[2], B[3]], lo, hi, cf, 0.0, D)
		var cg := light_at("CasingGlint%d" % s, Vector2.ZERO, 5, B[3], 0.0)
		keyf(cg, "position", func(t: float) -> Vector2:
			var k: Dictionary = cf.call(t)
			return Vector2(k.x, k.y - 0.5), 0.0, D, 30.0, "nearest")
		keyf(cg, "material:shader_parameter/alpha", func(t: float) -> float:
			var k: Dictionary = cf.call(t)
			return 0.55 * (1.0 - k.hit / 0.07) if (k.hit >= 0.0 and k.hit < 0.07) else 0.0, 0.0, D, 30.0, "nearest")

	# the flash: a hero frame with a white core, then a cooler, smaller one; every shot its own shape
	for s in SHOTS:
		for f in [1, 2]:
			var r := rng([S, s])
			var tilt := r.range(-0.06, 0.06)
			var size := r.range(0.95, 1.2)
			var L := flash_shape(r, f, {"size": size, "spike": [12, 21], "diag": [6, 11], "cross": [4, 7.5], "back": [2.5, 5]})
			var C: Array = [Color.WHITE, F[7], F[6], F[3]] if f == 1 else [F[7], F[6], F[4], F[2]]
			var fl := flash("Flash%d_%d" % [s, f], Vector2(0, MY), tilt, L, C, s * 7 + f)
			var ss: int = s
			var ff: int = f
			var on := func(t: float) -> bool:
				var a: float = age_of.call(ss, t)
				return a < 2 * F1 and (1 if a < F1 else 2) == ff
			fl.visible = on.call(0.0)
			keyf(fl, "visible", on, 0.0, D, 30.0, "nearest")

	# sparks and unburnt grains spat forward with each shot, dropping as they slow
	for j in 5:
		var bl := []
		for s in SHOTS:
			var r := rng([S, s, j, 11])
			var life := r.range(0.05, 0.16) * (1.8 if j > 2 else 1.0)
			var a := r.range(-0.3, 0.3)
			var sp := r.range(170, 380) * (0.5 if j > 2 else 1.0)
			bl.append({"kind": GRAIN if j > 2 else SPARK, "x": 2.0, "y": MY, "vx": cos(a) * sp, "vy": sin(a) * sp, "life": life, "size": 1.0,
				"delay": 0.0, "seed": 0.0, "g": 420.0, "drag": 2.2, "stretch": 0.011, "max": 9.0, "floor": false, "glow": 0.0 if j > 2 else 0.45})
		bits("Bits%d" % j, bl, SP, {"grain": [F[6], F[4]], "one_shot": false, "lifetime": D, "light": j <= 2})

	# light: a hot pop at the muzzle on every shot, the floor and smoke catching it
	for g in [["Pop", Vector2(4, MY), 26.0, F[4], 0.8], ["PopHot", Vector2(2, MY), 7.0, Color.WHITE, 0.45], ["PopFloor", Vector2(2, 0), 12.0, F[4], 0.16]]:
		pop_light(g[0], g[1], g[2], g[3], g[4], func(t: float) -> float: return pop.call(t, 0.03, 0.15), 0.0, D)
