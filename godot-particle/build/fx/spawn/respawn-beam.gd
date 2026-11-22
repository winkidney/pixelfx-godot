# reimagined-from: src/fx/spawn/respawn-beam.js@038aa83e07da2aa3f1b801a9f2682307f2c73998
# Respawn beam: A guide line drops, a pillar of light slams onto the spot, and a scan bar climbs from the feet writing the character back in row by row, white-hot lines cooling to its colors.
# one-shot, 2.50 s, 128x150 canvas, origin [64.0, 136.0], backdrop ground, stand-in 2
# ramp palette: #061e1b #0c3e36 #136a5a #1f9c80 #45d1a8 #a8f5d8 #ffffff
# The original's own update() runs here with its seeded draws. The guide line and the beam are shaded row by row as
# the original shades them (fx/spawn/_beam.gdshader: a see-through column with hard flickering edges, a white-hot
# core, shimmering strands), behind the character; the character is written in from the feet (_write_body: each row
# landing white and cooling to its own colours, glitching sideways, the scan bar over it, the flash round it when it's
# done), then the stand-in itself takes over. The slam's glow on the floor (_ellipse) and its rings (the impacts' band
# shader); the motes drawn in along the floor, the sparks, stars and dust are the original's Particles, tracked
# (_parts); its lights tracked too (_lamps); glows keyed on its formulas.
extends "res://build/fx/spawn/_spawn.gd"

const SLAM := 0.32
const WRITE0 := SLAM + 0.08
const WRITE := 0.95
const DONE := WRITE0 + WRITE
const LIFT := DONE + 0.12
const DROP := 0.07
const TOPY := -136.0

var BW := 15.0
var H := 38.0


func width(t: float) -> float:
	if t < SLAM - DROP:
		return 0.0
	if t < SLAM:
		return BW * 0.6
	if t < LIFT:
		return BW * (1 + 0.4 * exp(-(t - SLAM) * 10)) * (0.92 + 0.08 * sin(t * 40))
	return BW * (1 - out_cubic(clamp01((t - LIFT) / 0.3)))


static func bottom(t: float) -> float:
	return 0.0 if t < LIFT else -150 * in_cubic(clamp01((t - LIFT) / 0.4))


static func y_end(t: float) -> float:
	return TOPY + (-1 - TOPY) * in_cubic(clamp01((t - SLAM + DROP) / DROP)) if t < SLAM else -1 + bottom(t)


func scan_y(t: float) -> float:
	return -in_out_sine(clamp01((t - WRITE0) / WRITE)) * (H + 2)


func make() -> void:
	var W := Color.WHITE
	BW = float(meta.options.width)
	R = JsRng.new(int(meta.options.seed))
	var body := body_of(C)
	var rim := rim_of(body)
	var top: float = body.y
	H = body.h
	var strands := []
	for i in 6:
		strands.append(Vector3(rand([i, 1]) * 1.6 - 0.8, 1 + rand([i, 2]) * 3, rand([i, 3])))
	var ps := new_parts()
	ps.ground = 0.0
	ps.single = true
	var lm := new_lamps()
	var st := {"t": 0.0, "slammed": false, "finished": false}

	var step := func(dt: float) -> void:
		st.t += dt
		var t: float = st.t
		# the guide: motes drawn in to the spot along the floor
		if t < SLAM and R.chance(0.5):
			var s := R.sign()
			var D := R.range(18, 40)
			var T := R.range(0.15, 0.25)
			var v := (D * 3) / (exp(3 * T) - 1)
			var y := -R.range(0, 3)
			var c: Color = C[5] if R.chance(0.5) else C[4]
			ps.spawn(STREAK, s * D, y, -s * v, 0, T, c)
		if not st.slammed and t >= SLAM:
			st.slammed = true
			lm.add(0, -28, 64, C[4], 1, 0.5)
			lm.add(0, -52, 80, C[5], 1.1, 0.4)
			lm.add(0, -9, 24, W, 0.9, 0.12)
			for i in 40:
				var s := R.sign()
				var sp := R.range(60, 135)
				var x := s * R.range(0, 6)
				var vy := -R.range(20, 140)
				var life := R.range(0.25, 0.7)
				ps.spawn(SPARK, x, -1, s * sp, vy, life)
			for i in 12:
				var x := R.range(-BW, BW)
				var y := -R.range(2, 40)
				var vx := R.range(-20, 20)
				var vy := -R.range(20, 70)
				var life := R.range(0.5, 1)
				var c: Color = R.pick([W, C[5]])
				var sz := R.range(0.8, 1.8)
				ps.spawn(STAR, x, y, vx, vy, life, c, sz)
			for i in 8:
				var s := R.sign()
				var x := s * R.range(4, 10)
				var vx := s * R.range(30, 80)
				var vy := -R.range(3, 10)
				var life := R.range(0.4, 0.7)
				var sz := R.range(1.5, 3)
				ps.spawn(DUST, x, -1, vx, vy, life, C[2], sz)
		# the scan bar spits sparks sideways as it climbs
		if t > WRITE0 and t < DONE and R.chance(0.45):
			var y := scan_y(t)
			var s := R.sign()
			var x := s * R.range(6, 11)
			var vx := s * R.range(40, 140)
			var vy := R.range(-60, 10)
			var life := R.range(0.15, 0.35)
			ps.spawn(SPARK, x, y, vx, vy, life)
		# motes rise inside the beam while it stands
		if t > SLAM and t < LIFT + 0.2 and R.chance(0.6):
			var x := R.range(-1.3, 1.3) * BW
			var y := -R.range(0, 90)
			var vx := R.range(-6, 6)
			var vy := -R.range(30, 90)
			var life := R.range(0.4, 0.9)
			var c: Color = R.pick([W, C[5], C[5], C[4]])
			var sz := R.range(1, 1.8) if R.chance(0.3) else 0.6
			ps.spawn(STAR, x, y, vx, vy, life, c, sz)
		if not st.finished and t >= DONE:
			st.finished = true
			lm.add(0, top + H / 2, 40, C[5], 0.7, 0.3)
			for i in 14:
				var c: Dictionary = R.pick(rim)
				var vx := R.range(-25, 25)
				var vy := -R.range(10, 50)
				var life := R.range(0.4, 0.9)
				var col: Color = R.pick([W, C[5]])
				var sz := R.range(0.8, 1.8)
				ps.spawn(STAR, c.x, c.y, vx, vy, life, col, sz)
		ps.update(dt)
		lm.step(dt)
	var rec := func(s: int) -> void:
		ps.record(s)
		lm.record(s)
	run(step, rec)
	var u := "material:shader_parameter/"

	# behind the character: the guide (a dotted line, a ring closing on the spot, a glow) and the beam with its light
	var guide_k := func(t: float) -> float: return smooth(0, SLAM * 0.7, t) * (1 - smooth(SLAM - DROP, SLAM, t) * 0.5) if t < SLAM else 0.0
	var gb := shape("GuideRing", sh("band"), Vector2(28, 8), {"mid": Vector2(0, 0), "radius": 10.0, "th": 1.0, "squash": 0.2, "side": 1.0,
		"c0": C[3], "c1": C[4], "c2": C[5], "c3": C[6], "alpha": 0.0}, {"at": Vector2(0, 0), "back": true})
	keyf(gb, u + "radius", func(t: float) -> float: return 10.0 - 4.0 * guide_k.call(jt(t)), 0.0, SLAM + 0.04)
	keyf(gb, u + "alpha", func(t: float) -> float: return guide_k.call(jt(t)), 0.0, SLAM + 0.04, 60.0, "nearest")
	var gg := glow_path("GuideLight", Vector2(0, -2), Vector2(0, -2), 16, C[4])
	keyf(gg, u + "k", func(t: float) -> float: return 0.4 * guide_k.call(jt(t)), 0.0, SLAM + 0.04)
	var reach := ceilf(BW * 1.4 * 1.0) + 2
	var bm := shape("Beam", ssh("beam"), Vector2(2 * reach, -TOPY), {"top_y": TOPY, "strands": PackedVector3Array(strands),
		"c4": C[4], "c5": C[5], "c6": C[6], "white": W}, {"at": Vector2(0, TOPY / 2.0), "back": true})
	keyf(bm, u + "w", func(t: float) -> float: return width(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(bm, u + "y_end", func(t: float) -> float: return y_end(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(bm, u + "fill", func(t: float) -> float:
		var tt := jt(t)
		return 0.2 - 0.1 * smooth(WRITE0 - 0.05, WRITE0 + 0.1, tt) * (1 - smooth(DONE, LIFT, tt)), 0.0, -1.0, 60.0, "nearest")
	keyf(bm, u + "writing", func(t: float) -> float:
		var tt := jt(t)
		return smooth(WRITE0 - 0.05, WRITE0 + 0.1, tt) * (1 - smooth(DONE, LIFT, tt)), 0.0, -1.0, 60.0, "nearest")
	keyf(bm, u + "core", func(t: float) -> float: return 1 - smooth(SLAM + 0.06, WRITE0 + 0.08, jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(bm, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	keyf(bm, u + "guide", func(t: float) -> float: return guide_k.call(jt(t)), 0.0, SLAM + 0.04, 60.0, "nearest")
	keyf(bm, u + "guide_odd", func(t: float) -> float: return float(floori(jt(t) * 60) % 2), 0.0, SLAM + 0.04, 60.0, "nearest")
	for sd in [-1.0, 1.0]:
		var el := glow_path("BeamEdgeLight%d" % int(sd + 1), Vector2(sd * reach, TOPY + 24), Vector2(-sd * reach, -1), 6, C[4])
		keyf(el, u + "a", func(t: float) -> Vector2: return Vector2(sd * width(jt(t)), TOPY + 24), 0.0, -1.0, 60.0, "nearest")
		keyf(el, u + "b", func(t: float) -> Vector2: return Vector2(sd * width(jt(t)), y_end(jt(t))), 0.0, -1.0, 60.0, "nearest")
		keyf(el, u + "k", func(t: float) -> float: return 0.3 if (width(jt(t)) > 0.2 and y_end(jt(t)) > TOPY + 24) else 0.0, 0.0, -1.0, 60.0, "nearest")
	var fl := glow_path("BeamFootLight", Vector2(0, -5), Vector2(0, -5), BW * 2.1 + 7, C[5])
	keyf(fl, u + "radius", func(t: float) -> float: return width(jt(t)) * 1.5 + 6, 0.0, -1.0, 60.0, "nearest")
	keyf(fl, u + "k", func(t: float) -> float: return 0.45 if width(jt(t)) > 0.2 else 0.0, 0.0, -1.0, 60.0, "nearest")

	# the stand-in, once it's written
	var actor := actor_node()
	steps(actor, "visible", [[0.0, false], [DONE + 0.04, true]])
	# in front: the slam's glow on the floor and its rings
	var sk := func(t: float) -> float: return (jt(t) - SLAM) / 0.45
	var se := shape("SlamGlow", ssh("ellipse"), Vector2(68, 12), {"mid_at": Vector2(0, 0.5), "rx": 14.0, "ry": 3.0, "t1": 0.4, "t2": 0.7, "k": 0.0,
		"inner": W, "mid": C[6], "outer": C[5]}, {"at": Vector2(0, 0)})
	keyf(se, u + "rx", func(t: float) -> float: return 14 + 18 * out_cubic(clamp01(sk.call(t))), SLAM - 0.04, SLAM + 0.5, 60.0, "nearest")
	keyf(se, u + "ry", func(t: float) -> float: return 3 + 1.5 * clamp01(sk.call(t)), SLAM - 0.04, SLAM + 0.5, 60.0, "nearest")
	keyf(se, u + "k", func(t: float) -> float: return (1 - sk.call(t)) * 1.4 if (sk.call(t) > 0 and sk.call(t) < 1) else 0.0, 0.0, SLAM + 0.5, 60.0, "nearest")
	var sl := glow_path("SlamFloorLight", Vector2(0, -2), Vector2(0, -2), 42, C[5])
	keyf(sl, u + "radius", func(t: float) -> float: return (14 + 18 * out_cubic(clamp01(sk.call(t)))) * 1.3, SLAM - 0.04, SLAM + 0.5, 60.0, "nearest")
	keyf(sl, u + "k", func(t: float) -> float: return 0.5 * (1 - sk.call(t)) if (sk.call(t) > 0 and sk.call(t) < 1) else 0.0, 0.0, SLAM + 0.5, 60.0, "nearest")
	for i in 2:
		var rr := shape("SlamRing%d" % i, sh("band"), Vector2(92, 20), {"mid": Vector2(0, 0), "radius": 8.0, "th": 3.0, "squash": 0.2, "side": 0.0,
			"c0": C[3], "c1": C[4], "c2": C[5], "c3": C[6], "alpha": 0.0}, {"at": Vector2(0, 0)})
		var kk := func(t: float) -> float: return (jt(t) - SLAM - 0.08 * i) / 0.5
		var span: float = 22.0 if i else 34.0
		keyf(rr, u + "radius", func(t: float) -> float: return 8 + span * out_cubic(clamp01(kk.call(t))), SLAM - 0.04, SLAM + 0.64)
		keyf(rr, u + "th", func(t: float) -> float: return maxf(1.0, 3.0 * (1 - kk.call(t))), SLAM - 0.04, SLAM + 0.64)
		keyf(rr, u + "alpha", func(t: float) -> float: return (1.15 - kk.call(t)) if (kk.call(t) > 0 and kk.call(t) < 1) else 0.0, 0.0, SLAM + 0.64, 60.0, "nearest")
		keyf(rr, u + "c3", func(t: float) -> Color: return W if kk.call(t) < 0.15 else C[6], SLAM - 0.04, SLAM + 0.64, 60.0, "nearest")
	# the character written in, the scan bar over it, the flash round it when it's done
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	var wb := shape("Written", ssh("write_body"), Vector2(53, 43), {"tex": tex, "origin": Vector2(body.x, top), "write0": WRITE0, "write_len": WRITE,
		"c4": C[4], "c5": C[5], "c6": C[6], "white": W}, {"at": Vector2(0.5, (top - 3 + 2) / 2.0)})
	keyf(wb, u + "t", func(t: float) -> float: return jt(t), 0.0, -1.0, 60.0, "nearest")
	keyf(wb, u + "body_on", func(t: float) -> float: return 1.0 if (jt(t) >= WRITE0 and jt(t) < DONE + 0.05) else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(wb, u + "bar_on", func(t: float) -> float: return 1.0 if jt(t) < DONE else 0.0, 0.0, -1.0, 60.0, "nearest")
	keyf(wb, u + "bar_y", func(t: float) -> float: return scan_y(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(wb, u + "bar_w", func(t: float) -> float: return width(jt(t)), 0.0, -1.0, 60.0, "nearest")
	keyf(wb, u + "flash", func(t: float) -> float:
		var fk := (jt(t) - DONE) / 0.25
		return fk if (fk > 0 and fk < 1) else -1.0, 0.0, -1.0, 60.0, "nearest")
	var bl := glow_path("ScanLight", Vector2(-reach, -H - 2), Vector2(reach, 0), 6, C[5])
	keyf(bl, u + "a", func(t: float) -> Vector2: return Vector2(-width(jt(t)), scan_y(jt(t))), 0.0, -1.0, 60.0, "nearest")
	keyf(bl, u + "b", func(t: float) -> Vector2: return Vector2(width(jt(t)), scan_y(jt(t))), 0.0, -1.0, 60.0, "nearest")
	keyf(bl, u + "k", func(t: float) -> float: return 0.6 if (jt(t) >= WRITE0 and jt(t) < DONE) else 0.0, 0.0, -1.0, 60.0, "nearest")
	var spk := shape("DoneGlint", load("res://addons/pixelfx_particles/fx/arcane/_sparkle.gdshader"), Vector2(19, 19),
		{"arm": 0, "c": W, "tip": C[5], "heart": W}, {"at": Vector2(6.5, top + 6.5)})
	var arm := func(t: float) -> float:
		var fk := (jt(t) - DONE) / 0.25
		return float(floori(6 * (1 - fk) + 0.5)) if (fk > 0 and fk < 1) else 0.0
	keyf(spk, u + "arm", arm, 0.0, -1.0, 60.0, "nearest")
	var sgl := glow_path("DoneGlintLight", Vector2(6, top + 6), Vector2(6, top + 6), 16, W)
	keyf(sgl, u + "radius", func(t: float) -> float: return 4.0 + 2.0 * arm.call(t), 0.0, -1.0, 60.0, "nearest")
	keyf(sgl, u + "k", func(t: float) -> float: return 0.5 if arm.call(t) >= 1 else 0.0, 0.0, -1.0, 60.0, "nearest")
	var flash := glow_path("SlamFlash", Vector2(0, -30), Vector2(0, -30), 56, W)
	keyf(flash, u + "k", func(t: float) -> float: return 0.6 * (1 - (jt(t) - SLAM) / 0.1) if (jt(t) >= SLAM and jt(t) - SLAM < 0.1) else 0.0, 0.0, SLAM + 0.2, 60.0, "nearest")
	# the particles, all in one pass in front as the original draws them; the lights
	parts("Parts", ps, {"sparks": [W, C[5], C[4], C[3]], "front": true})
	lamps("Lights", lm)
