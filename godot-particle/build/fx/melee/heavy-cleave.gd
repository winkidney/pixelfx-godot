# reimagined-from: src/fx/melee/heavy-cleave.js@5dc5a393287494e1524774c012384187994ae26e
# Heavy cleave: A glint over the head, then a thick ember arc accelerates over the top into the floor: a white slam, glowing cracks, dust rolling both ways, grit and rising embers.
# one-shot, 1.90 s, 208x116 canvas, origin [68.0, 96.0], backdrop ground, stand-in 2
# The arc and its echo are fx/melee/_cleave.gdshader on the original's swing (each pixel cooling by how long ago the
# edge passed), with light riding it and its dotted trace of embers; the raised blade glints; the blow is the impact
# star (fx/melee/_star), slivers, a hot patch of floor cooling to soot (fx/melee/_hotfloor), cracks racing out and
# cooling (fx/melee/_cracks), a shock ring across the floor (fx/melee/_band, far half behind) and light. Heat
# gathering to the blade, embers, sparks, rolling dust, grit and tumbling stones are the original's spawns replayed on
# GPU particles (fx/melee/_kinds.gdshader, rocks drawn by fx/melee/_prock).
extends "res://build/fx/melee/_melee.gd"

const RAISE := 0.2
const SWING := 0.135
const HIT := RAISE + SWING
const HOLD := 0.05
const TRAIL := 0.22


static func head(t: float) -> float:
	return in_quad((t - RAISE) / SWING)


func make() -> void:
	var n := C.size()
	var st := stone(meta.options.stone)
	var A := swing({"cx": 3.0, "cy": -22.0, "R": 37.0, "sy": 0.88, "rot": 0.32, "a0": -2.45, "dir": 1.0})
	var U1 := 0.0
	while on_swing(A, A.R, U1).y < -0.5 and U1 < 4.0:
		U1 += 0.005
	var E := A.duplicate()
	E.R = A.R * 0.76
	var W := 16.0
	var WE := 5.0
	var X := on_swing(A, A.R - 2.0, U1).x
	var GLINT := on_swing(A, A.R - 3.0, 0.0)
	var lines := cracks(X, 4, 40, 7, 0.4)
	var spikes := []
	var sa := [-PI, -2.7, -2.15, -1.62, -1.05, -0.45, 0.0]
	for i in sa.size():
		spikes.append([sa[i] + R.rf(-0.08, 0.08), (20.0 if (i == 0 or i == 6) else 15.0 if i == 3 else 9.0) + R.rf(0, 4), 1.6 + R.rf(0, 0.6)])
	var shards := []
	for a in [-2.5, -1.9, -1.2, -0.6]:
		shards.append([a + R.rf(-0.15, 0.15), 8.0 + R.rf(0, 3), R.rf(80, 130), R.rf(0.35, 0.6)])
	var spark_ramp := [C[6], C[5], C[4], C[3]]
	var gone := func(tt: float) -> float: return smooth(HIT + HOLD, HIT + HOLD + TRAIL, tt)
	var heat := func(t: float) -> float: return pow(clamp01(1.0 - (t - HIT) / 1.2), 1.2)

	# behind: the floor under the blade, white hot, cooling through the ramp to soot
	var hf := shape("HotFloor", mel_shader("hotfloor"), Vector2(20, 4), {"ramp": Array(C), "dark": st.dark, "shade": st.shade, "q": -1.0},
		{"at": Vector2(floorf(X) - 9.0 + 10.0, 2.0), "back": true})
	key(hf, "material:shader_parameter/q", [[0.0, -1.0], [HIT - 0.001, -1.0], [HIT, 0.0], [root.duration, root.duration - HIT]])
	keyf(hf, "material:shader_parameter/fade", func(t: float) -> float: return 1.0 - smooth(1.0, 1.5, t - HIT), HIT, root.duration)

	# the glint over the head: the raised blade catching the light
	var gl := func(t: float) -> float:
		return out_back(clamp01(t / 0.1)) * (1.0 + 0.15 * sin(t * 60.0)) * ((1.0 - (t - RAISE) / 0.03) if t > RAISE else 1.0)
	sparkle("Glint", GLINT, C[6], C[4], func(t: float) -> Array: return [1.0 + 7.0 * gl.call(t), 0.5], 0.0, RAISE + 0.03)
	glow_path("GlintLight", 23, C[4], func(t: float) -> Array: return [GLINT, 22.0, 0.3 * gl.call(t)], 0.0, RAISE + 0.03)

	# cracks race out from the cut and split down into the floor
	var cr := cracks_shape("Cracks", lines, Vector2(X - 46, -2), Vector2(X + 46, 12), {"mode": 0.0, "reach": 40.0, "ramp_t": 0.13, "at_k": 0.1,
		"ramp": Array(C), "dark": st.dark})
	key(cr, "material:shader_parameter/q", [[0.0, -1.0], [HIT - 0.001, -1.0], [HIT, 0.0], [root.duration, root.duration - HIT]])
	keyf(cr, "material:shader_parameter/heat", heat, HIT, root.duration)
	keyf(cr, "material:shader_parameter/fade", func(t: float) -> float: return 1.0 - smooth(1.15, 1.5, t - HIT), HIT, root.duration)
	glow_path("HeatLight", 35, C[4], func(t: float) -> Array:
		return [Vector2(X, -2), 34.0, 0.32 * heat.call(t) * (1.0 - smooth(1.15, 1.5, t - HIT))], HIT, root.duration)
	# the shock runs out along the floor
	floor_band("Shock", Vector2(X, 0.5), 52, HIT, 0.45, func(k: float) -> Array:
		return [6.0 + 46.0 * out_cubic(k), maxf(1.0, 3.0 * (1.0 - k)), 1.15 - k], [C[6], C[4], st.light, st.body])

	# the arc and its echo, then a dotted trace of embers where it has been
	for b in [[E, WE, 0.02, 0.0, "Echo"], [A, W, 0.0, 1.0, "Arc"]]:
		var s: Dictionary = b[0]
		var w0: float = b[1]
		var lag: float = b[2]
		var rim: bool = b[3] > 0.5
		var stf := func(t: float) -> Dictionary:
			var tt := t - lag
			var U := U1 * head(tt)
			var T: float = U1 * gone.call(tt)
			var on := U >= 0.02 and T < U - 0.02
			var tail: float = U1 * gone.call(t)
			var th := 0.8 * (1.0 - clamp01((t - HIT - HOLD) / (TRAIL + 0.25)))
			return {"T": T, "U": U if on else T, "tt": tt, "gone": gone.call(tt), "shrink": 1.0 - 0.75 * gone.call(tt),
				"tr_u1": tail, "tr_k": th if (rim and tail > 0.02 and th > 0.0) else 0.0,
				"u0": T, "u1": U if on else -1.0, "la": T, "lb": maxf(U, T + 0.001), "at": tt, "k0": 0.26 if on else 0.0}
		var node := swing_shape(b[4], "cleave", s, {"w0": w0, "U1": U1, "RAISE": RAISE, "SWING": SWING, "rim": b[3], "ramp": Array(C), "n": float(n),
			"tr_r": A.R - 0.5, "tr_col": C[3]}, w0, 1.0)
		keyd(node, ["T", "U", "tt", "gone", "shrink", "tr_u1", "tr_k"], stf, 0.0, HIT + HOLD + TRAIL + 0.3)
		if rim:
			var lit := swing_shape("ArcLight", "swing_light", s, {"gr": s.R - w0 * 0.4, "gstep": 0.35, "rad": 7.0 + w0 * 0.5, "color": C[4], "lin": 1.0,
				"age_mode": 2.0, "ap0": RAISE, "ap1": SWING, "aspan": U1, "atau": 0.2}, w0, 16.0)
			keyd(lit, ["u0", "u1", "la", "lb", "at", "k0"], stf, 0.0, HIT + HOLD + TRAIL + 0.05)
	glow_path("Ride", 41, C[4], func(t: float) -> Array: return [on_swing(A, A.R - 5.0, U1 * head(t)), 40.0, 0.5], RAISE, HIT + 0.05)

	# the white slam: an impact star flat on the floor, then slivers flying off and a hot pool
	var at := Vector2(X, -1)
	impact_star("Slam", at, spikes, 32, func(t: float) -> Array:
		if t - HIT < 0.035:
			return [1.0, 1.0, 0.0, Color.WHITE, C[6], C[7], C[5]]
		return [1.25, 0.55, 0.0, C[7], C[6], C[6], C[4]], HIT, HIT + 0.07)
	slivers("Shards", at, shards, HIT + 0.05, 0.11, C[6], C[5], C[4])
	glow_path("Pop", 31, C[5], func(t: float) -> Array: return [Vector2(X, -6), 30.0, 0.8 * exp(-(t - HIT) / 0.05)], HIT, HIT + 0.2)
	glow_path("PopWhite", 11, Color.WHITE, func(t: float) -> Array: return [Vector2(X, -2), 10.0, 0.7 * exp(-(t - HIT) / 0.05)], HIT, HIT + 0.2)
	light_burst("Flash", HIT, Vector2(X, -6), 26, Color.WHITE, 0.9, 0.1)
	light_burst("Warm", HIT, Vector2(X, -12), 64, C[4], 0.5, 0.8)

	# streams before the blow: heat gathers to the raised blade, embers shed off the edge as it comes over
	var gather := []
	var shed := []
	var breath := []
	var t := 0.0
	var t0 := 1.0 / 120.0
	while t < HIT + 0.6:
		t += 1.0 / 120.0
		if t < RAISE - 0.04 and R.chance(0.35):
			var a := R.rf(0, TAU)
			var D := R.rf(14, 26)
			var T := R.rf(0.14, 0.2)
			var v := D * 3.0 / (exp(3.0 * T) - 1.0)
			gather.append(sp(GLINT.x + cos(a) * D, GLINT.y + sin(a) * D, -cos(a) * v, -sin(a) * v, T, C[5] if R.chance(0.5) else C[4], 1.0, t - t0))
		if t > RAISE and t < HIT and R.chance(0.7):
			var p := on_swing(A, A.R - R.rf(0, 6), U1 * head(t) * R.rf(0.6, 1))
			shed.append(sp(p.x, p.y, R.rf(-20, 20), R.rf(-40, -10), R.rf(0.5, 1.1), C[4], R.rf(1, 2), t - t0))
		if t >= HIT and R.chance(0.12):
			var c: Dictionary = R.pick(lines)
			var pt: Vector2 = R.pick(c.pts)
			breath.append(sp(pt.x, pt.y - 1.0, R.rf(-12, 12), -R.rf(20, 50), R.rf(0.5, 0.9), C[4], 1.0, t - t0))
	burst("Gather", STREAK, t0, gather, {"floor": false})
	burst("Shed", EMBER, t0, shed + breath, {"sparks": spark_ramp})

	# the blow: sparks fan up off the floor, dust rolls out both ways, grit and stones are thrown up, embers lift
	var sparks := []
	for i in 26:
		var a := -PI / 2.0 + R.rf(-1.2, 1.35)
		var v := R.rf(140, 360)
		sparks.append(sp(X, -1, cos(a) * v, sin(a) * v - 40.0, R.rf(0.15, 0.5)))
	var smoke := []
	for i in 20:
		var s := -1.0 if i % 2 else 1.0
		smoke.append(sp(X + s * R.rf(0, 8), -R.rf(2, 6), s * R.rf(45, 135), -R.rf(2, 12), R.rf(1.0, 1.45), st.dust, R.rf(5, 8.5), R.rf(0, 0.07)))
	for i in 4:
		smoke.append(sp(X + R.rf(-4, 4), -R.rf(3, 8), R.rf(-15, 15), -R.rf(40, 90), R.rf(1.0, 1.45), st.dust, R.rf(4, 6.5), R.rf(0.02, 0.1)))
	var dust := []
	for i in 8:
		dust.append(sp(X + R.rf(-4, 4), -R.rf(1, 4), R.rf(-60, 60), -R.rf(8, 30), R.rf(0.35, 0.7), st.dust, R.rf(2, 3.5)))
	var grit := []
	for i in 44:
		var a := -PI / 2.0 + R.rf(-0.7, 1.0)
		var v := R.rf(60, 230)
		grit.append(sp(X + R.rf(-3, 3), -1, cos(a) * v, sin(a) * v, R.rf(1.0, 1.5), R.pick([st.light, st.body, st.body, st.shade]), 2.0 if R.chance(0.35) else 1.0))
	var rocks := []
	for i in 6:
		var q := sp(X + R.rf(-3, 3), -2, R.rf(-50, 110), -R.rf(120, 260), R.rf(1.15, 1.5), st.body, float(R.ri(1, 2)))
		q.merge({"g": 1.0, "drag": 0.4, "bounce": 0.3, "spin": R.rf(-14, 14)})
		rocks.append(q)
		# where it comes to rest it kicks up a little dust
		for j in 2:
			dust.append(sp(q.p.x + q.v.x * 0.55 + R.rf(-1.5, 1.5), -0.5, R.sgn() * R.rf(8, 30), -R.rf(2, 12), R.rf(0.3, 0.6), st.dust, R.rf(1.3, 2.4), 0.55 + R.rf(0, 0.3)))
	var embers := []
	for i in 16:
		embers.append(sp(X + R.rf(-8, 8), -R.rf(1, 6), R.rf(-50, 60), -R.rf(30, 110), R.rf(0.7, 1.5), C[4], R.rf(1, 2)))
	burst("Dust", SMOKE_BIG, HIT, smoke, {"back": true})
	burst("Puffs", DUST, HIT, dust, {"back": true})
	burst("Rocks", CHUNK, HIT, rocks, {"stone": st})
	burst("Grit", GRIT, HIT, grit)
	burst("Embers", EMBER, HIT, embers, {"sparks": spark_ramp})
	burst("Sparks", SPARK, HIT, sparks, {"sparks": spark_ramp})
