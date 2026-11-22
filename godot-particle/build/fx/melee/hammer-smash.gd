# reimagined-from: src/fx/melee/hammer-smash.js@3b3ecf833b6cc2bb9502b621925f24d145403d94
# Hammer smash: A hammer drops in front in a wedge of motion: a white slam with rays, a dome of force, a dent with cracks, rocks thrown up that bounce and settle, and dust.
# one-shot, 2.00 s, 208x112 canvas, origin [80.0, 92.0], backdrop ground, stand-in 2
# The hammer's comet and its speed lines are fx/melee/_wedge.gdshader on the original's swing, keyed from its drop;
# the blow is a white flash on the floor (ring shader), rays (Line2Ds and fx/melee/_glowline), a dome of force
# swelling off the floor (fx/melee/_dome, light riding it), a dent drawn at build time, cracks (fx/melee/_cracks) and
# a ring across the floor (fx/melee/_band, far half behind). Rocks (fx/melee/_prock), hot chips, grit, motes, sparks
# and rolling dust are the original's spawns replayed on GPU particles (fx/melee/_kinds.gdshader).
extends "res://build/fx/melee/_melee.gd"

const DROP := 0.15
const SOOT := Color("#0d0a12")
const HOT2 := ["#fff3a6", "#ffc23d", "#ff8a2a", "#c9281f"]


static func head(t: float) -> float:
	var x := clamp01((t + 0.03) / (DROP + 0.03))
	return 0.28 * x + 0.72 * x * x


func make() -> void:
	var n := C.size()
	var st := stone(meta.options.stone)
	keep_colour(SOOT)
	var A := swing({"cx": 5.0, "cy": -25.0, "R": 32.0, "sy": 1.0, "rot": 0.0, "a0": -2.25, "dir": 1.0})
	var U1 := 0.0
	while on_swing(A, A.R, U1).y < -0.5 and U1 < 4.0:
		U1 += 0.005
	var HW := 13.0
	var Rm: float = A.R - HW / 2.0
	var X := on_swing(A, Rm, U1).x
	var lines := cracks(X, 5, 24, 6, 0)
	var rays := []
	var rd := [-0.95, -0.6, -0.3, -0.05, 0.22, 0.5, 0.85]
	for i in rd.size():
		rays.append([-PI / 2.0 + rd[i] + R.rf(-0.06, 0.06), (34.0 if i == 3 else 26.0 if (i == 2 or i == 4) else 18.0 if (i == 1 or i == 5) else 12.0) * R.rf(0.9, 1.1)])
	var end: float = root.duration

	# behind: the dent, the floor's top knocked down into a shallow pit, lit at the bottom, chipped lips
	var img := Image.create(23, 7, false, Image.FORMAT_RGBA8)
	for x in range(-11, 12):
		var u := x / 10.0
		var d := 0 if absi(x) > 10 else int(roundf(3.2 * (1.0 - u * u) + (hrand(x, 4) - 0.5) * 0.8))
		for y in d:
			img.set_pixel(x + 11, y + 2, SOOT if y == 0 else st.dark)
		if d > 0:
			img.set_pixel(x + 11, d + 2, st.light if absi(x) < 7 else st.body)
		if absi(x) >= 8:
			img.set_pixel(x + 11, 1, st.body if absi(x) >= 10 else st.light)
		if absi(x) == 9 and hrand(x, 7) < 0.7:
			img.set_pixel(x + 11, 0, st.body)
	var dent := sprite("Dent", asset("dent", img), {"centered": false, "at": Vector2(floorf(X) - 11.0, -2.0), "back": true})
	var fade := func(t: float) -> float: return 1.0 - smooth(1.3, 1.7, t - DROP)
	keyf_window(dent, "modulate:a", fade, DROP, end + 1.0)

	# the hammer's wedge
	var wst := func(t: float) -> Dictionary:
		var h := head(t)
		var U := U1 * h
		var after := smooth(DROP, DROP + 0.07, t)
		var lag_u := maxf(0.0, U - (0.3 + 1.05 * h))
		return {"T": lag_u + (U - lag_u) * after * 0.8, "U": U, "after": after}
	var wd := swing_shape("Wedge", "wedge", A, {"HW": HW, "Rm": Rm, "ramp": Array(C), "n": float(n), "ln": PackedVector4Array([
		Vector4(-HW / 2 - 2, 3, 26, 0), Vector4(-HW / 2 - 5, 9, 16, 0), Vector4(HW / 2 + 2, 2, 30, 0), Vector4(HW / 2 + 5, 8, 18, 0),
		Vector4(-1, 2, 14, 1), Vector4(3, 4, 9, 1)])}, HW + 1.0, 8.0)
	keyd(wd, ["T", "U", "after"], wst, 0.0, DROP + 0.09)
	glow_path("HeadLight", 35, C[4], func(t: float) -> Array:
		return [on_swing(A, Rm, U1 * head(t)), 34.0, 0.5 * (1.0 - smooth(DROP - 0.03, DROP, t))], 0.0, DROP)

	# cracks split out of the dent: a white flash, then dark lines that fade with the dent
	var cr := cracks_shape("Cracks", lines, Vector2(X - 32, -2), Vector2(X + 32, 14), {"mode": 1.0, "reach": 30.0, "ramp_t": 0.08, "at_k": 0.06,
		"dark": SOOT, "shade": st.shade, "c_mid": C[5], "ramp": Array(C)})
	key(cr, "material:shader_parameter/q", [[0.0, -1.0], [DROP - 0.001, -1.0], [DROP, 0.0], [end, end - DROP]])
	keyf(cr, "material:shader_parameter/fade", fade, DROP, end)
	# the floor ring
	floor_band("Ring", Vector2(X, 0.5), 56, DROP, 0.5, func(k: float) -> Array:
		return [6.0 + 50.0 * out_cubic(k), maxf(1.0, 2.0 * (1.0 - k)), 1.15 - k], [C[7], C[5], C[3], st.body])
	# the dome of force swells off the floor, thins and fades
	var d0 := DROP + 0.045
	var dome := shape("Dome", mel_shader("dome"), Vector2(92, 46), {"cx": X - floorf(X), "c4": C[4], "c5": C[5], "c6": C[6]}, {"at": Vector2(floorf(X), -23)})
	var dst := func(t: float) -> Dictionary:
		var d := (t - d0) / 0.4
		var on := d >= 0.0 and d < 1.0
		var r := 12.0 + 30.0 * out_cubic(d)
		return {"r": r, "th": maxf(1.0, 3.6 * pow(maxf(0.0, 1.0 - d), 0.8)), "d": d, "alpha": (1.0 if d < 0.6 else (1.0 - d) / 0.4) if on else 0.0,
			"R": r, "gr": r, "k0": 0.36 * (1.0 - d) if on else 0.0}
	keyd(dome, ["r", "th", "d"], dst, d0, d0 + 0.4)
	keyf_window(dome, "material:shader_parameter/alpha", func(t: float) -> float: return dst.call(t).alpha, d0, d0 + 0.4)
	var ds := swing({"cx": X, "cy": 0.0, "R": 12.0, "a0": 0.0, "dir": -1.0})
	var dl := swing_shape("DomeLight", "swing_light", ds, {"u0": 0.08 * PI, "u1": 0.921 * PI, "gstep": 0.14 * PI, "rad": 14.0, "color": C[4], "lin": 0.0}, 2.0, 46.0)
	keyd(dl, ["R", "gr"], dst, d0, d0 + 0.4)
	keyf_window(dl, "material:shader_parameter/k0", func(t: float) -> float: return dst.call(t).k0, d0, d0 + 0.4)
	# rays of light shoot up out of the slam
	for i in rays.size():
		var ry: Array = rays[i]
		var e := Vector2(cos(ry[0]), sin(ry[0]))
		var o := Vector2(X, -1)
		var ext := func(t: float) -> Array:
			var q := t - DROP
			return [ry[1] * smooth(0.04, 0.2, q), ry[1] * out_cubic(minf(1.0, q / 0.05))]
		seg_line("Ray%dTip" % i, func(t: float) -> Array:
			var x: Array = ext.call(t)
			var mid: float = lerpf(2.0 + x[0], x[1], 0.5)
			return [o + e * mid, o + e * x[1], C[6], 1.0 if x[1] - x[0] >= 1.0 else 0.0], DROP, DROP + 0.2)
		seg_line("Ray%d" % i, func(t: float) -> Array:
			var x: Array = ext.call(t)
			return [o + e * (2.0 + x[0]), o + e * lerpf(2.0 + x[0], x[1], 0.5), Color.WHITE, 1.0 if x[1] - x[0] >= 1.0 else 0.0], DROP, DROP + 0.2)
		var gl := shape("Ray%dLight" % i, mel_shader("glowline"), Vector2(88, 52), {"a": o, "b": o, "radius": 4.0, "color": C[5], "k": 0.0}, {"at": Vector2(floorf(X), -20)})
		keyd(gl, ["a", "b"], func(t: float) -> Dictionary:
			var x: Array = ext.call(t)
			return {"a": o + e * x[0], "b": o + e * x[1]}, DROP, DROP + 0.2)
		keyf_window(gl, "material:shader_parameter/k", func(t: float) -> float:
			var x: Array = ext.call(t)
			return 0.18 * (1.0 - (t - DROP) / 0.2) if x[1] - x[0] >= 1.0 else 0.0, DROP, DROP + 0.2)
	# the white slam: a flat flash on the floor for two frames
	for s in [["SlamRim", 2.0, 1.0, C[6], C[5]], ["Slam", 0.0, 0.0, Color.WHITE, C[7]]]:
		var sl := ring(s[0], 20, {"radius": 16.0 + s[1], "squash": (3.0 + s[2]) / (16.0 + s[1]), "color": s[3], "alpha": 0.0}, {"at": Vector2(floorf(X) + 0.0, 0.0)})
		key(sl, "material:shader_parameter/alpha", [[0.0, 0.0], [DROP, 1.0], [DROP + 0.07, 0.0]], "nearest")
		key(sl, "material:shader_parameter/radius", [[0.0, 16.0 + s[1]], [DROP + 0.035, 12.0 + s[1]]], "nearest")
		key(sl, "material:shader_parameter/squash", [[0.0, (3.0 + s[2]) / (16.0 + s[1])], [DROP + 0.035, (2.0 + s[2]) / (12.0 + s[1])]], "nearest")
		key(sl, "material:shader_parameter/color", [[0.0, s[3]], [DROP + 0.035, s[4]]], "nearest")
	glow_path("Pop", 27, C[5], func(t: float) -> Array: return [Vector2(X, -5), 26.0, 0.3 * exp(-(t - DROP) / 0.05)], DROP, DROP + 0.2)
	keep_colour(Color(HOT2[2]))
	glow_path("Warm", 17, Color(HOT2[2]), func(t: float) -> Array: return [Vector2(X, -1), 16.0, 0.28 * exp(-(t - DROP) / 0.35)], DROP, end + 1.0)
	light_burst("Flash", DROP, Vector2(X, -5), 16, Color.WHITE, 0.35, 0.08)
	light_burst("Glow", DROP, Vector2(X, -10), 64, C[4], 0.42, 0.6)

	# rocks thrown up out of the dent: they tumble, land, bounce and settle; hot chips; grit; motes; sparks; dust
	var rocks := []
	var dust := []
	var glints := []
	for i in 15:
		var s := R.sgn()
		var q := sp(X + s * R.rf(0, 5), -2, s * R.rf(20, 105), -R.rf(110, 300), R.rf(1.25, 1.65), st.body, float(R.pick([1, 1, 2, 2, 3])))
		q.merge({"g": 1.0, "drag": 0.35, "bounce": 0.38, "spin": R.rf(-16, 16)})
		rocks.append(q)
		# where it lands it kicks up a little dust, and now and then catches the light
		var land: float = q.p.x + q.v.x * 0.6
		var when: float = minf(1.0, 2.0 * absf(q.v.y) / 950.0 * 1.3)
		for j in 3:
			dust.append(sp(land + R.rf(-1.5, 1.5), -0.5, R.sgn() * R.rf(8, 35), -R.rf(2, 14), R.rf(0.3, 0.6), st.dust, R.rf(1.3, 2.6), when))
		if R.chance(0.4):
			glints.append(sp(land + R.rf(-1, 1), -1.5 - q.size, 0, -2, R.rf(0.25, 0.45), Color(HOT2[0]) if R.chance(0.5) else Color.WHITE, R.rf(0.6, 1.6), R.rf(0.4, 1.2)))
	var chips := []
	for i in 11:
		var a := -PI / 2.0 + R.rf(-1.2, 1.2)
		var v := R.rf(90, 230)
		var q := sp(X + R.rf(-4, 4), -2, cos(a) * v, sin(a) * v, R.rf(0.9, 1.5))
		q.merge({"g": 0.9, "drag": 0.5, "bounce": 0.35})
		chips.append(q)
	var grit := []
	for i in 40:
		var a := -PI / 2.0 + R.rf(-1.1, 1.1)
		var v := R.rf(50, 210)
		grit.append(sp(X + R.rf(-4, 4), -1, cos(a) * v, sin(a) * v, R.rf(0.9, 1.5), R.pick([st.light, st.body, st.body, st.shade]), 2.0 if R.chance(0.4) else 1.0))
	var motes := []
	for i in 14:
		var s := -1.0 if i % 2 else 1.0
		motes.append(sp(X + s * 6.0, -R.rf(1, 4), s * R.rf(120, 260), -R.rf(0, 30), R.rf(0.18, 0.34), C[6] if R.chance(0.5) else C[5], 0.8, R.rf(0.02, 0.05)))
	var sparks := []
	for i in 24:
		var a := -PI / 2.0 + R.rf(-1.4, 1.4)
		var v := R.rf(150, 380)
		sparks.append(sp(X + cos(a) * 6.0, -2.0 + sin(a) * 4.0, cos(a) * v, sin(a) * v - 30.0, R.rf(0.12, 0.42), Color.WHITE, 1.0, R.rf(0.035, 0.08)))
	var smoke := []
	for i in 20:
		var s := -1.0 if i % 2 else 1.0
		smoke.append(sp(X + s * R.rf(2, 10), -R.rf(2, 7), s * R.rf(40, 125), -R.rf(2, 14), R.rf(0.95, 1.5), st.dust, R.rf(6, 9), R.rf(0.02, 0.08)))
	for i in 7:
		smoke.append(sp(X + R.rf(-6, 6), -R.rf(3, 9), R.rf(-20, 20), -R.rf(30, 80), R.rf(1.0, 1.4), st.dust, R.rf(5, 7.5), R.rf(0.04, 0.14)))
	for i in 8:
		dust.append(sp(X + R.rf(-6, 6), -R.rf(1, 4), R.rf(-70, 70), -R.rf(8, 30), R.rf(0.35, 0.7), st.dust, R.rf(2, 3.5)))
	burst("Dust", SMOKE_BIG, DROP, smoke, {"back": true})
	burst("Puffs", DUST, DROP, dust, {"back": true})
	burst("Rocks", CHUNK, DROP, rocks, {"stone": st})
	burst("Chips", CHIP, DROP, chips, {"sparks": HOT2})
	burst("Grit", GRIT, DROP, grit)
	burst("Motes", MOTE, DROP, motes)
	burst("Sparks", SPARK, DROP, sparks, {"sparks": HOT})
	burst("Glints", STAR, DROP, glints)
