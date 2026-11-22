# reimagined-from: src/fx/projectiles/homing-missile.js@97b9950edf53b3a8cb804ea0027ecea2c1f0dc4d
# Homing missile: A missile kicks off, arcs up, rolls over and dives onto its target (the origin), its smoke trail left hanging in the air, and hits in a fiery blast of flame, sparks and rocks.
# one-shot, 3.80 s, 248x140 canvas, origin [160.0, 120.0], backdrop ground
# The flight is the original's bezier path and its quickening progress, keyed every frame: the missile (the
# original's pixel sprite, built into a texture here) turned along its heading, a flickering white-hot jet and its
# light. The trail is smoke puffs dropped along the path that hang where they fall (lobes(): lit crowns, warm while
# young, swelling and thinning), from emitters riding behind the missile whose rate follows its speed (one puff every
# 1.5 px of flight), and sparks spat back off the motor. The hit: a white disc for two frames, a ring of flame cut off
# at the floor (_homing-missile_ring), a band rolling out along the floor (its far half behind), balls of flame that
# burst and cool down the fire ramp as they rise (an outer and a hotter inner twin), a column of them, sparks and
# embers, stones and grit thrown up onto a collision floor, a smoke column and dust rolling out, a scorch that cools
# to soot (_homing-missile_scorch) and the blast's light.
extends "res://build/fx/projectiles/_projectiles.gd"

const FLY := 1.15
const PATH := [Vector2(-130, -22), Vector2(-114, -110), Vector2(-30, -120), Vector2(0, 0)]
const Y := -6.0
const MISSILE := ["ff..........", ".fhhhhhhhre.", "nmmmmmmmmrrw", ".fsssssssrd.", "ff.........."]
const OUTLINE := Color("#1a1422")

var F: PackedColorArray
var SM: PackedColorArray
var WR: PackedColorArray


static func bez(u: float) -> Vector2:
	var v := 1.0 - u
	return PATH[0] * (v * v * v) + PATH[1] * (3.0 * v * v * u) + PATH[2] * (3.0 * v * u * u) + PATH[3] * (u * u * u)


static func heading(u: float) -> float:
	var v := 1.0 - u
	var d: Vector2 = (PATH[1] - PATH[0]) * (3.0 * v * v) + (PATH[2] - PATH[1]) * (6.0 * v * u) + (PATH[3] - PATH[2]) * (3.0 * u * u)
	return atan2(d.y, d.x)


static func progress(t: float) -> float:
	return pow(clampf(t / FLY, 0.0, 1.0), 1.45)


static func pos(t: float) -> Vector2:
	return bez(progress(t))


static func hdg(t: float) -> float:
	return heading(progress(t))


## Where the motor is (the trail and the sparks leave from there): 7 px behind the missile.
static func tail(t: float) -> Vector2:
	var h := hdg(t)
	return pos(t) - Vector2(cos(h), sin(h)) * 7.0


## The original's Lights.add(): a glow that shrinks a little and dies, k * (life left)^2, from t0.
func light_burst(name: String, t0: float, at: Vector2, r0: float, c: Color, k: float, life: float) -> void:
	var lg := glow(name, r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": at})
	keyf(lg, "material:shader_parameter/radius", func(t: float) -> float: return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0, t0 + life)
	keyf(lg, "material:shader_parameter/alpha", func(t: float) -> float: return k * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 else 0.0, maxf(0.0, t0 - 0.04), t0 + life + 0.01)


## The original's drag (speed falling as exp(-k t)) as a velocity limit over the particle's life, plus a drift.
func drag_limit(p: GPUParticles2D, v0: float, k: float, drift: float) -> void:
	var m: ParticleProcessMaterial = p.process_material
	var pts := []
	for i in 13:
		var u := i / 12.0
		pts.append([u, v0 * exp(-k * u * p.lifetime) + drift])
	m.velocity_limit_curve = curve(pts, v0 + drift)


## A spark as the original draws it: a head in the hot colours and a tail a step cooler, streaked along its motion
## (two emitters with the same seed and textures that are each half a streak), and its point of light.
func sparks(name: String, o: Dictionary, SP: Array, head: Texture2D, tail_: Texture2D) -> Array:
	var tl := o.duplicate()
	tl.texture = tail_
	tl.align = true
	tl.ramp = gradient([SP[0], SP[1], SP[3]], [0.0, 0.4, 0.5])
	var a := particles(name + "Tail", tl)
	var hd := o.duplicate()
	hd.texture = head
	hd.align = true
	hd.ramp = gradient([SP[0], SP[1], SP[2]], [0.0, 0.4, 0.7])
	var b := particles(name + "Head", hd)
	b.seed = a.seed
	var lt := o.duplicate()
	lt.layer = "light"
	lt.texture = "glow8"
	lt.scale = [0.75, 0.75]
	lt.ramp = gradient([Color(SP[0], 0.45), Color(SP[2], 0.0)], [0.0, 1.0], true)
	var c := particles(name + "Light", lt)
	c.seed = a.seed
	return [a, b, c]


## A smoke puff's state over its life (the original's Smoke.puffs(): density a * (1 - k)^1.3, brightness
## b * (1 - k / 2), the fire's light warm * exp(-5 age), weighted to the puff's fire side as its cloud() does).
func puff_state(a: float, b: float, warm: float, life: float) -> Array:
	var out := []
	for i in 13:
		var u := i / 12.0
		var age := u * life
		out.append([u, clampf(b * (1.0 - u * 0.5), 0.0, 1.0), 0.65 * warm * exp(-age * 5.0), a * minf(1.0, age * 30.0) * pow(1.0 - u, 1.3)])
	return out


## A puff's radius over its life as a share of its full size: r0 swelling toward r1 (grow 1/s).
static func swell(r0: float, r1: float, grow: float, life: float) -> Array:
	var out := []
	for i in 13:
		var u := i / 12.0
		out.append([u, (r0 + (r1 - r0) * (1.0 - exp(-grow * u * life))) / r1])
	return out


## A stone chunk as the original shades its rocks: lit top-left, dark bottom-right, an outline.
func chunk(r: float, st: Dictionary) -> Texture2D:
	var n := int(ceilf((r + 0.9) * 2.0))
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for j in n:
		for i in n:
			var dx := i - c
			var dy := j - c
			var d := Vector2(dx * 1.15, dy).length()
			if d > r + 0.9:
				continue
			var lit := (dx + dy) * 0.4
			img.set_pixel(i, j, OUTLINE if d > r else (st.light if lit < -0.4 else (st.shade if lit > 0.6 else st.body)))
	return asset("chunk%d.res" % n, img)


func make() -> void:
	F = pal("palette")
	SM = pal("smoke")
	var M := pal("metal")
	var D: float = root.duration
	WR = PackedColorArray([SM[0], mixc(F[1], SM[1], 0.5), mixc(F[2], SM[2], 0.4), F[3], F[4], F[6], F[7]])
	var st0 := Color(meta.options.stone)
	var stone := {"light": mixc(st0 * 1.35, Color.WHITE, 0.08), "body": st0, "shade": Color(st0 * 0.64, 1.0), "dust": mixc(st0 * 1.2, Color("#968c96"), 0.3)}
	for k in stone:
		stone[k].a = 1.0
		keep_colour(stone[k])
	keep_colour(OUTLINE)
	var SP := [F[7], F[6], F[4], F[3]]
	var head_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	var tail_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	for j in 8:
		head_img.set_pixel(0, j, Color(1, 1, 1, 1.0 if j >= 4 else 0.0))
		tail_img.set_pixel(0, j, Color(1, 1, 1, 1.0 if j <= 4 else 0.0))
	var head_tex := asset("spark_head.res", head_img)
	var tail_tex := asset("spark_tail.res", tail_img)
	ground()

	# ---- behind: the scorch and the far half of the band
	var scorch := shape("Scorch", pshader("homing-missile_scorch"), Vector2(40, 8), {"fire": F, "soot": Color("#0d0a12"),
		"soot2": Color("#17121d"), "age": 0.0, "rx": 0.0}, {"back": true, "at": Vector2(0, 0)})
	show(scorch, FLY)
	keyf(scorch, "material:shader_parameter/age", func(t: float) -> float: return maxf(0.0, t - FLY), FLY, D, 30.0, "nearest")
	keyf(scorch, "material:shader_parameter/rx", func(t: float) -> float: return 16.0 * minf(1.0, maxf(0.0, t - FLY) / 0.06), FLY, FLY + 0.1, 30.0, "nearest")
	keyf(scorch, "material:shader_parameter/alpha", func(t: float) -> float: return 1.0 - smooth(D - 1.0, D - 0.2, t), D - 1.1, D, 30.0, "nearest")
	band(true, stone)

	# ---- the launch: a flash of light at the launcher, a few puffs kicked out
	light_burst("LaunchLight", 0.0, PATH[0], 30, F[4], 0.7, 0.25)
	var kick := lobes("LaunchSmoke", {"at": PATH[0] + Vector2(2, 2), "amount": 6, "lifetime": 1.8, "life_random": 0.33, "one_shot": true,
		"explosiveness": 1.0, "emit": {"box": Vector2(2, 1)}, "dir": 0, "spread": 180, "speed": [8, 30], "damping": [20, 35],
		"gravity": Vector2(0, -6), "radius": [5.0, 7.5], "scale_curve": swell(2.0, 6.2, 2.0, 1.5)}, puff_state(0.6, 0.85, 1.0, 1.5), SM, WR, 1.4)
	kick.material.set_shader_parameter("dens", 1.4 / 1.6 * 1.6)
	emit(kick, 0.0)

	# ---- the trail: a puff every 1.5 px of flight, left hanging where it fell. Emitters ride behind the missile, one for
	# each stretch of the flight, each at the rate the missile's speed asks for there
	var W := 12
	# a frame's worth of flight: the emitter only moves once a frame, so the puffs of a frame are spread back along it
	# (an emission box as long as the frame's step)
	var step := func(t: float) -> float: return tail(t).distance_to(tail(maxf(0.0, t - 1.0 / 30.0)))
	for w in W:
		var t0 := FLY * w / W
		var t1 := FLY * (w + 1) / W
		var length := 0.0
		for s in 12:
			length += tail(t0 + (t1 - t0) * (s + 1) / 12.0).distance_to(tail(t0 + (t1 - t0) * s / 12.0))
		var rate := length / 1.65 / (t1 - t0)
		var tr := lobes("Trail%d" % w, {"at": tail(t0), "amount": maxi(2, int(ceilf(rate * 2.3))), "lifetime": 2.3, "life_random": 0.35,
			"emitting": false, "emit": {"box": Vector2(0.6, 0.6)}, "dir": 180, "spread": 18, "speed": [10, 30], "damping": [30, 60],
			"gravity": Vector2(0, -2), "radius": [3.2, 5.4], "scale_curve": swell(1.4, 4.3, 1.2, 1.9)}, puff_state(0.5, 0.9, 0.8, 1.9), SM, WR, 1.4)
		tr.material.set_shader_parameter("dens", 1.4 / 1.6)
		emit(tr, t0, t1)
		keyf(tr, "position", func(t: float) -> Vector2:
			var h := hdg(t)
			return tail(t) - Vector2(cos(h), sin(h)) * step.call(t) * 0.5, t0, t1, 60.0)
		keyf(tr, "rotation", func(t: float) -> float: return hdg(t), t0, t1, 60.0)
		keyf(tr, "process_material:emission_box_extents", func(t: float) -> Vector3: return Vector3(0.6 + step.call(t) * 0.5, 0.6, 0.0), t0, t1, 60.0)
	# sparks spat back off the motor
	var fs := sparks("FlightSparks", {"at": tail(0), "amount": 15, "lifetime": 0.35, "life_random": 0.57, "emitting": false,
		"dir": 180, "spread": 28.6, "speed": [40, 140], "damping": [40, 90], "gravity": Vector2(0, 427), "scale": [0.35, 0.55],
		"collide": {"bounce": 0.45, "friction": 0.3}}, SP, head_tex, tail_tex)
	for p in fs:
		emit(p, 0.0, FLY)
		keyf(p, "position", func(t: float) -> Vector2: return tail(t), 0.0, FLY, 60.0)
		keyf(p, "rotation", func(t: float) -> float: return hdg(t), 0.0, FLY, 60.0)

	# ---- the missile: its jet and its sprite turned along its heading, its light
	var ms := group("Missile", {"at": pos(0)})
	keyf(ms, "position", func(t: float) -> Vector2: return pos(t), 0.0, FLY, 30.0, "nearest")
	keyf(ms, "rotation", func(t: float) -> float: return hdg(t), 0.0, FLY, 30.0, "nearest")
	show(ms, 0.0, FLY)
	var jet := group("Jet", {"parent": ms, "at": Vector2(-6.5, 0)})
	var jl := line("JetCore", PackedVector2Array([Vector2(0, 0.5), Vector2(-8, 0.5)]), {"parent": jet,
		"gradient": gradient([Color.WHITE, F[6], F[4]], [0.0, 0.3, 0.6])})
	var js := line("JetSide", PackedVector2Array([Vector2(0, 1.3), Vector2(-4, 1.3)]), {"parent": jet, "color": F[5]})
	keep_colour(F[5])
	keyf(jet, "scale", func(t: float) -> Vector2: return Vector2((5.0 + 3.0 * jrand([floori(t * 30.0), 7])) / 8.0, 1.0), 0.0, FLY, 30.0, "nearest")
	var cmap := {"f": M[1], "h": M[4], "m": M[3], "s": M[1], "n": M[0], "r": F[2], "e": F[3], "d": F[1], "w": Color.WHITE}
	var img := Image.create(12, 5, false, Image.FORMAT_RGBA8)
	for j in 5:
		for i in 12:
			var ch: String = MISSILE[j][i]
			img.set_pixel(i, j, cmap[ch] if cmap.has(ch) else Color(0, 0, 0, 0))
	sprite("Body", asset("missile.res", img), {"parent": ms, "layer": "prop", "centered": false, "offset": Vector2(-6, -2.5)})
	light_at("MotorGlow", Vector2(-8, 0), 18, F[4], 0.5, {"parent": ms})
	light_at("MotorHot", Vector2(-7, 0), 6, F[7], 0.5, {"parent": ms})

	# ---- the hit
	blast(stone, SP, head_tex, tail_tex)


## The band rolling out along the floor (the original's band(): 60 px over 0.45 s, squashed to 0.16, 4 px thick
## thinning to 1): rings of dots every half pixel inward from its rim (the original's own steps, so its rim is mostly
## the fire's orange, white-hot when the steps land on it), stone inward; the far half behind, the near half in front.
## The colour layer dithers them as they fade, as the original's dots do.
func band(back: bool, stone: Dictionary) -> void:
	var t0 := FLY
	var RC := [stone.body, stone.light, F[4], F[7]]
	for c in RC:
		keep_colour(c)
	var R := func(t: float) -> float: return 60.0 * (1.0 - pow(1.0 - seg(t, t0, t0 + 0.45), 3.0))
	var TH := func(t: float) -> float: return maxf(1.0, 4.0 * (1.0 - seg(t, t0, t0 + 0.45)))
	# step m of the band: o = th - 0.5 m px in from the rim (innermost first, so the rim draws on top)
	for m in 9:
		var ln := line(("BandBack%d" if back else "BandFront%d") % m, PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]),
			{"back": back, "color": F[4], "at": Vector2(0, 0.5)})
		keyf(ln, "points", func(t: float) -> PackedVector2Array:
			var r: float = R.call(t) - maxf(0.0, TH.call(t) - 0.5 * m)
			var pts := PackedVector2Array()
			var n := maxi(12, int(ceilf(maxf(r, 1.0) * TAU * 0.6)))
			for k in n + 1:
				var a := PI * k / n
				pts.append(Vector2(cos(a) * r, (-1.0 if back else 1.0) * sin(a) * r * 0.16))
			return pts, t0, t0 + 0.45, 30.0, "nearest")
		keyf(ln, "default_color", func(t: float) -> Color:
			var th: float = TH.call(t)
			var o := th - 0.5 * m
			if o < 0.0:
				return Color(F[4], 0.0)
			var u := o / th
			var k := 1.15 - seg(t, t0, t0 + 0.45)
			var c: Color = RC[3] if u < 0.15 else (RC[2] if u < 0.4 else (RC[1] if u < 0.7 else RC[0]))
			return Color(c, clampf(k * (1.2 if u < 0.4 else 1.15 - u), 0.0, 1.0)), t0, t0 + 0.45, 30.0, "nearest")
		show(ln, t0, t0 + 0.45)


func blast(stone: Dictionary, SP: Array, head_tex: Texture2D, tail_tex: Texture2D) -> void:
	var t0 := FLY
	var at := Vector2(0, Y)
	# the near half of the band
	band(false, stone)
	# light: a warm swell and a white pop
	light_burst("BlastLight", t0, Vector2(0, Y - 2), 52, Color("#ffb060"), 0.8, 0.8)
	light_burst("BlastHot", t0, Vector2(0, Y - 2), 30, Color.WHITE, 0.75, 0.1)
	# the flash: a white ball in a red rim for two frames
	var R := func(t: float) -> float: return 14.0 * (0.8 + 0.2 * (1.0 - seg(t, t0, t0 + 0.07)))
	for L in [["FlashRim", 1.2, F[3], F[3]], ["FlashBody", 0.0, F[7], F[6]], ["FlashCore", -1.0, Color.WHITE, F[7]]]:
		var add: float = L[1]
		var disc := ring(L[0], 19, {"radius": 14, "color": L[2]}, {"at": at})
		keyf(disc, "material:shader_parameter/radius", func(t: float) -> float: return R.call(t) * 0.6 if add < 0.0 else R.call(t) + add, t0, t0 + 0.07, 60.0, "nearest")
		key(disc, "material:shader_parameter/color", [[t0, L[2]], [t0 + 0.035, L[3]]], "nearest")
		show(disc, t0, t0 + 0.07)
	# the ring of flame, cut off at the floor
	var ring_ := shape("FlameRing", pshader("homing-missile_ring"), Vector2(80, 80), {"radius": 8, "width": 2.9, "cut": -Y, "color": F[5]}, {"at": at})
	keyf(ring_, "material:shader_parameter/radius", func(t: float) -> float: return 8.0 + 30.0 * (1.0 - pow(1.0 - seg(t, t0, t0 + 0.3), 3.0)), t0, t0 + 0.3)
	keyf(ring_, "material:shader_parameter/width", func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - seg(t, t0, t0 + 0.3)) + 0.4), t0, t0 + 0.3)
	keyf(ring_, "material:shader_parameter/alpha", func(t: float) -> float: return minf(1.0, (1.0 - seg(t, t0, t0 + 0.3)) * 1.6), t0, t0 + 0.3)
	show(ring_, t0, t0 + 0.3)

	# smoke: a column boiling up off the fire, lit by the blast at first, and dust rolling out along the floor
	var col := lobes("SmokeColumn", {"at": Vector2(0, Y - 4), "back": true, "amount": 18, "lifetime": 2.2, "life_random": 0.23,
		"one_shot": true, "explosiveness": 0.86, "emitting": false, "emit": {"box": Vector2(4, 2)}, "dir": -90, "spread": 40,
		"speed": [20, 80], "gravity": Vector2(0, -42), "radius": [8.0, 14.0], "scale_curve": swell(3.0, 11.0, 2.0, 1.95)},
		puff_state(0.62, 0.88, 1.0, 1.95), SM, WR, 1.4)
	col.material.set_shader_parameter("dens", 1.4 / 1.6 * 1.3)
	drag_limit(col, 80.0, 1.8, 30.0)
	emit(col, t0 + 0.05)
	for s in [-1.0, 1.0]:
		var dust := lobes("Dust" + ("L" if s < 0 else "R"), {"at": Vector2(s * 3, -3), "back": true, "amount": 6, "lifetime": 1.7,
			"life_random": 0.35, "one_shot": true, "explosiveness": 1.0, "emitting": false, "emit": {"box": Vector2(3, 0.5)},
			"dir": 90 - s * 90 - s * 4, "spread": 4, "speed": [60, 150], "gravity": Vector2(0, -5), "radius": [6.0, 9.0],
			"scale_curve": swell(2.5, 7.5, 2.0, 1.4)}, puff_state(0.5, 0.75, 0.3, 1.4), SM, WR, 1.4)
		dust.material.set_shader_parameter("dens", 1.4 / 1.6 * 1.3)
		drag_limit(dust, 150.0, 3.0, 3.0)
		emit(dust, t0)

	# balls of flame bursting out, rising as they cool down the fire ramp (outer: two steps cooler; a hot inner twin)
	var FR := [F[8], F[7], F[6], F[5], F[4], F[3], F[2], F[1], F[0]]
	var offs := [0.0, 0.035, 0.107, 0.206, 0.327, 0.469, 0.63, 0.81]
	var inner_cols := []
	var outer_cols := []
	for i in 8:
		inner_cols.append(FR[i])
		outer_cols.append(FR[mini(8, i + 2)])
	# the last of a puff: a dark red ball fading out
	outer_cols.append(Color(FR[8], 0.0))
	inner_cols.append(Color(FR[7], 0.0))
	offs.append(0.95)
	var fire_sets := [["Fire", 26, 0.95, 0.53, 1.0, {"circle": 6.0}, -90, 120, [30.0, 170.0], [3.2, 6.5]],
		["FireColumn", 5, 1.1, 0.36, 0.93, {"box": Vector2(3, 0.5)}, -90, 6, [90.0, 150.0], [4.0, 5.5]]]
	for fs in fire_sets:
		var base := {"at": at, "amount": fs[1], "lifetime": fs[2], "life_random": fs[3], "one_shot": true, "explosiveness": fs[4],
			"emitting": false, "emit": fs[5], "dir": fs[6], "spread": fs[7], "speed": fs[8],
			"gravity": Vector2(0, -95), "scale_curve": [[0, 0.55], [0.14, 1.0], [1, 0.45]]}
		var sz: Array = fs[9]
		var o1 := base.duplicate()
		o1.texture = "disc9"
		o1.scale = [sz[0] * 2.0 / 9.0, sz[1] * 2.0 / 9.0]
		o1.ramp = gradient(outer_cols, offs)
		var a := particles(fs[0] + "Rim", o1)
		var o2 := base.duplicate()
		o2.texture = "disc9"
		o2.scale = [sz[0] * 1.5 / 9.0, sz[1] * 1.5 / 9.0]
		o2.ramp = gradient(inner_cols, offs)
		var b := particles(fs[0], o2)
		b.seed = a.seed
		var o3 := base.duplicate()
		o3.layer = "light"
		o3.texture = "glow16"
		o3.scale = [sz[0] * 5.0 / 16.0, sz[1] * 5.0 / 16.0]
		o3.ramp = gradient([Color(FR[1], 0.18), Color(FR[3], 0.12), Color(FR[5], 0.0)], [0.0, 0.3, 0.63], true)
		var c := particles(fs[0] + "Light", o3)
		c.seed = a.seed
		for p in [a, b, c]:
			drag_limit(p, float(fs[8][1]), 4.0, 30.0)
			emit(p, t0)

	# sparks flung up and out, bouncing on the floor; embers drifting off
	var bs := sparks("BlastSparks", {"at": at, "amount": 70, "lifetime": 0.65, "life_random": 0.69, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "dir": -90, "spread": 83, "speed": [110, 290], "damping": [120, 240], "gravity": Vector2(0, 427),
		"scale": [0.4, 0.75], "collide": {"bounce": 0.45, "friction": 0.3}}, SP, head_tex, tail_tex)
	for p in bs:
		emit(p, t0)
	var eo := {"at": at, "amount": 22, "lifetime": 1.6, "life_random": 0.44, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"emit": {"circle": 4.0}, "dir": -90, "spread": 90, "speed": [40, 140], "damping": [50, 90], "gravity": Vector2(0, -30),
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.03]}}
	var e1 := eo.duplicate()
	e1.texture = "dot1"
	e1.ramp = gradient([SP[0], SP[1], SP[2], Color(SP[2], 0.5)], [0.0, 0.4, 0.7, 0.8])
	var em := particles("Embers", e1)
	var e2 := eo.duplicate()
	e2.layer = "light"
	e2.texture = "glow8"
	e2.ramp = gradient([Color(SP[0], 0.35), Color(SP[2], 0.0)], [0.0, 1.0], true)
	var eml := particles("EmberLight", e2)
	eml.seed = em.seed
	emit(em, t0)
	emit(eml, t0)

	# stones and grit thrown up, landing and lying a while
	var ini := gradient([stone.light, stone.body, stone.body, stone.shade])
	for rk in [["Stones", 9, 1.35], ["BigStones", 7, 2.1]]:
		var p := particles(rk[0], {"layer": "prop", "at": Vector2(0, -2), "amount": rk[1], "lifetime": 2.2, "life_random": 0.32,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": chunk(rk[2], stone), "emit": {"box": Vector2(5, 0.5)},
			"dir": -90, "spread": 30, "speed": [150, 300], "gravity": Vector2(0, 950), "angle": [0, 360],
			"alpha_curve": [[0, 1], [0.78, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.7, "size": 3}})
		emit(p, t0)
	for g in [["Grit", 30, "dot1"], ["GritBig", 20, "dot2"]]:
		var p := particles(g[0], {"at": Vector2(0, -1), "amount": g[1], "lifetime": 1.8, "life_random": 0.44, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": g[2], "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 32,
			"speed": [80, 220], "gravity": Vector2(0, 950), "initial": ini, "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
			"collide": {"bounce": 0.15, "friction": 1.0}})
		emit(p, t0)
