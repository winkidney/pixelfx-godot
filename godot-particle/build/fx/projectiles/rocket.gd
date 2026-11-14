# reimagined-from: src/fx/projectiles/rocket.js@f932d473c6560de8f5c78fb1ef60bd98602a6615
# Rocket: A steel rocket roars along: a flickering jet with shock diamonds and a white-hot nozzle, a thick billowing smoke trail lit by the flame, sparks shed behind.
# loop, 1.20 s, 288x76 canvas, origin [252.0, 42.0], backdrop sky
# The rocket is still and the air streams past (the original's frame). The ship is the original's pixel shape, built
# into a texture here (its body, nose, fins and glowing bell), bobbing a pixel with the original's bob(t); the jet is
# a shader (fx/projectiles/_rocket_jet: the banded cone, shock diamonds, white-hot nozzle) whose length, wobble and
# diamonds are re-rolled every frame from the original's own rand(). Everything it sheds is particles streaming back:
# the smoke trail as lit puffs (_projectiles.gd lobes(): warm and bright while young, swelling, rising, thinning
# and greying), flame tongues torn off the jet's tip (an outer and a hotter inner twin), embers, two-tone sparks
# (a head and a tail twin) that drop as they cool. Light: the pool round the tail, the smoke lit from inside, the
# beam of the flame, the white-hot nozzle and the flame's light on the ship's belly, all breathing with the jet.
extends "res://build/fx/projectiles/_projectiles.gd"

const OUTLINE := Color("#100d17")
const NOZZLE := -14.0
const J0 := 22.0
const LIT := 1.1
# the original's cloud(dens 1.3) sums the density of the two or three puffs that overlap: a lobe alone is denser
const DENS := 2.6

var S := 5


## The original's bob: a pixel up and down over the loop.
func bob(t: float) -> float:
	return roundf(sin(t / root.duration * TAU) * 0.62)


func frame_of(t: float) -> int:
	return floori(t * 30.0 + 1e-6)


## The jet's length this frame (the original's J).
func jet_len(t: float) -> float:
	return J0 * (0.84 + 0.32 * jrand([frame_of(t), S, 1]))


## The original's SHIP: pixelShape(-15, -9, 30, 19, ...) with its outline, as rows of characters.
func ship_rows() -> Array:
	var x0 := -15
	var y0 := -9
	var w := 30
	var h := 19
	var g := []
	for j in h:
		var row := []
		row.resize(w)
		row.fill(".")
		g.append(row)
	var put := func(px: int, py: int, ch: String) -> void:
		var i := px - x0
		var jj := py - y0
		if i >= 0 and jj >= 0 and i < w and jj < h:
			g[jj][i] = ch
	var body := {-3: "4", -2: "6", -1: "5", 0: "4", 1: "3", 2: "2", 3: "1"}
	var seam := {-3: "3", -2: "4", -1: "4", 0: "3", 1: "2", 2: "1", 3: "1"}
	var paint := {-3: "d", -2: "e", -1: "e", 0: "d", 1: "c", 2: "b", 3: "a"}
	for y in range(-3, 4):
		for x in range(-11, 6):
			put.call(x, y, body[y])
	for y in range(-3, 4):
		put.call(-3, y, seam[y])
		put.call(-9, y, paint[y])
		put.call(-8, y, paint[y])
	var nose := {6: 3, 7: 3, 8: 2, 9: 2, 10: 1, 11: 1, 12: 0, 13: 0}
	for xs in nose:
		for y in range(-nose[xs], nose[xs] + 1):
			put.call(xs, y, paint[y])
	put.call(7, -2, "w")
	put.call(8, -2, "w")
	put.call(9, -1, "e")
	put.call(13, 0, "e")
	var fins := [[-13, -8], [-13, -9], [-13, -10], [-13, -11]]
	for i in fins.size():
		var a: int = fins[i][0]
		var b: int = fins[i][1]
		for x in range(a, b + 1):
			put.call(x, -4 - i, "5" if x == b else ("4" if i > 1 else "3"))
			put.call(x, 4 + i, "3" if x == b else ("1" if i > 1 else "2"))
	for y in range(-2, 3):
		put.call(-12, y, "3" if y < 0 else "2")
	for y in range(-3, 4):
		put.call(-13, y, "2" if y < -1 else "1")
	put.call(-14, -3, "h")
	put.call(-14, 3, "h")
	for y in range(-2, 3):
		put.call(-14, y, "x" if absi(y) < 2 else "h")
	var solid := func(i: int, j: int) -> bool:
		return i >= 0 and j >= 0 and i < w and j < h and g[j][i] != "." and g[j][i] != "o"
	for j in h:
		for i in w:
			if g[j][i] == "." and (solid.call(i - 1, j) or solid.call(i + 1, j) or solid.call(i, j - 1) or solid.call(i, j + 1)):
				g[j][i] = "o"
	return g


## The smoke puffs' material: lit from straight above (fx/projectiles/_rocket_lobe), as dense as the original's
## overlapping puffs (the lobe shader scales dens by 1.6).
func trail_lit(p: GPUParticles2D) -> void:
	var m: ShaderMaterial = p.material
	var keep := {}
	for u in m.shader.get_shader_uniform_list():
		keep[u.name] = m.get_shader_parameter(u.name)
	m.shader = pshader("rocket_lobe")
	for k in keep:
		if keep[k] != null:
			m.set_shader_parameter(k, keep[k])
	m.set_shader_parameter("dens", DENS / 1.6)
	m.set_shader_parameter("light_dir", Vector2(-0.12, -1.0))


func make() -> void:
	var F := pal("palette")
	var M := pal("metal")
	var A := pal("paint")
	var SM := pal("smoke")
	S = int(meta.options.seed)
	var V: float = meta.options.speed
	var D: float = root.duration
	var by := func(t: float) -> Vector2: return Vector2(0, bob(t))
	var fl := func(t: float) -> float: return jet_len(t) / J0

	# ---- the smoke: puffs leave the tail of the flame, stream back, swell and rise, lit by the fire while young
	var WR := PackedColorArray([mixc(F[0], SM[0], 0.5), mixc(F[1], SM[1], 0.45), mixc(F[2], SM[2], 0.35), F[3], F[4], F[6], F[7]])
	var state := []
	for i in 13:
		var u := i / 12.0
		var age := u * 1.3
		var k := u
		var a := minf(1.0, age * 16.0) * pow(1.0 - k, 1.3) * 0.72
		# the fire's light on it, weighted to its fire side as the original weights it (about 0.6 of it over a puff)
		state.append([u, clampf(0.95 - k * 0.8, 0.0, 1.0), 0.62 * exp(-age * 4.6), a])
	for big in [false, true]:
		var R0: float = 2.6
		var Rf: Array = [11.0, 15.0] if big else [6.5, 10.5]
		var mid: float = (Rf[0] + Rf[1]) / 2.0
		var sc := []
		for i in 13:
			var u := i / 12.0
			sc.append([u, (R0 + (mid - 2.6) * (1.0 - exp(-2.2 * u * 1.3))) / mid])
		var sm := lobes("Smoke" + ("Big" if big else ""), {"at": Vector2(NOZZLE - J0 * 0.71, 0), "amount": 17 if big else 49,
			"lifetime": 1.45, "life_random": 0.24, "emit": {"box": Vector2(2.0, 1.0)}, "dir": 180, "spread": 3.5,
			"speed": [126, 146], "gravity": Vector2(0, -10), "radius": Rf, "scale_curve": sc,
			# each puff a little brighter or darker than the next (the original's b +- 0.08)
			"initial": raw([Color(0.8, 1, 1, 1), Color(1, 1, 1, 1)], [0.0, 1.0], true)}, state, SM, WR, LIT)
		trail_lit(sm)
		# the young (warm, bright) puffs over the old
		sm.draw_order = GPUParticles2D.DRAW_ORDER_LIFETIME
		keyf(sm, "position", func(t: float) -> Vector2: return Vector2(NOZZLE - J0 * 0.71, bob(t)), 0.0, D, 30.0, "nearest")

	# ---- embers carried off in the smoke, cooling and winking out
	var ember := {"at": Vector2(NOZZLE - J0 * 0.6, 0), "amount": 9, "lifetime": 1.1, "life_random": 0.45, "texture": "dot1",
		"dir": 180, "spread": 12, "speed": [150, 200], "damping": [20, 40], "gravity": Vector2(0, -8)}
	var e1 := ember.duplicate()
	e1.ramp = gradient([F[6], F[4], F[2], Color(F[2], 0.4)], [0.0, 0.4, 0.7, 0.85])
	var em := particles("Embers", e1)
	var e2 := ember.duplicate()
	e2.layer = "light"
	e2.texture = "glow8"
	e2.scale = [0.75, 0.75]
	e2.ramp = gradient([Color(F[6], 0.35), Color(F[4], 0.0)], [0.0, 1.0], true)
	var eml := particles("EmberLight", e2)
	eml.seed = em.seed
	for p in [em, eml]:
		keyf(p, "position", func(t: float) -> Vector2: return Vector2(NOZZLE - J0 * 0.6, bob(t)), 0.0, D, 30.0, "nearest")

	# ---- tongues of flame torn off the tip of the jet, cooling and shrinking as they fall behind
	var tongue := {"at": Vector2(NOZZLE - J0 * 0.75, 0.5), "amount": 22, "lifetime": 0.16, "life_random": 0.5, "texture": "disc5",
		"emit": {"box": Vector2(3.3, 1.5)}, "dir": 180, "spread": 8, "speed": [125, 160], "gravity": Vector2(0, -30),
		"scale": [0.45, 0.8], "scale_curve": [[0, 1.0], [1, 0.4]]}
	var t1 := tongue.duplicate()
	t1.ramp = gradient([F[5], F[4], F[3], F[2]], [0.0, 0.25, 0.55, 0.8])
	var tg := particles("Tongues", t1)
	var t2 := tongue.duplicate()
	t2.texture = "disc3"
	t2.ramp = gradient([F[7], F[6], F[5], F[4]], [0.0, 0.25, 0.55, 0.8])
	var tgc := particles("TongueHearts", t2)
	tgc.seed = tg.seed
	var t3 := tongue.duplicate()
	t3.layer = "light"
	t3.texture = "glow8"
	t3.scale = [0.8, 1.2]
	t3.ramp = gradient([Color(F[7], 0.2), Color(F[5], 0.0)], [0.0, 1.0], true)
	var tgl := particles("TongueLight", t3)
	tgl.seed = tg.seed
	for p in [tg, tgc, tgl]:
		keyf(p, "position", func(t: float) -> Vector2: return Vector2(NOZZLE - J0 * 0.75, bob(t) + 0.5), 0.0, D, 30.0, "nearest")

	# ---- sparks shed behind, streaking back and dropping: a hot head and a cooler tail (twins), and a slow few
	var head_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	var tail_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	for j in 8:
		head_img.set_pixel(0, j, Color(1, 1, 1, 1.0 if j >= 4 else 0.0))
		tail_img.set_pixel(0, j, Color(1, 1, 1, 1.0 if j <= 4 else 0.0))
	var head_tex := asset("spark_head.res", head_img)
	var tail_tex := asset("spark_tail.res", tail_img)
	var SP := [F[7], F[6], F[4], F[3]]
	var sets := [["Sparks", 20, 0.45, 0.6, [140.0, 300.0], 16.0, [60.0, 110.0], 160.0],
		["SlowSparks", 8, 0.8, 0.38, [125.0, 200.0], 14.0, [30.0, 60.0], 170.0]]
	for st in sets:
		var base := {"at": Vector2(NOZZLE - 8, 0.5), "amount": st[1], "lifetime": st[2], "life_random": st[3], "align": true,
			"emit": {"box": Vector2(6.0, 1.5)}, "dir": 182, "spread": st[5], "speed": st[4], "damping": st[6],
			"gravity": Vector2(0, st[7]), "scale": [0.6, 0.95]}
		var tl := base.duplicate()
		tl.texture = tail_tex
		tl.ramp = gradient([SP[0], SP[1], SP[3]], [0.0, 0.4, 0.5])
		var ps_t := particles(st[0] + "Tail", tl)
		var hd := base.duplicate()
		hd.texture = head_tex
		hd.ramp = gradient([SP[0], SP[1], SP[2]], [0.0, 0.4, 0.7])
		var ps_h := particles(st[0] + "Head", hd)
		ps_h.seed = ps_t.seed
		var lt := base.duplicate()
		lt.layer = "light"
		lt.texture = "glow8"
		lt.align = false
		lt.scale = [0.75, 0.75]
		lt.ramp = gradient([Color(SP[0], 0.45), Color(SP[2], 0.0)], [0.0, 1.0], true)
		var ps_l := particles(st[0] + "Light", lt)
		ps_l.seed = ps_t.seed
		for p in [ps_t, ps_h, ps_l]:
			keyf(p, "position", func(t: float) -> Vector2: return Vector2(NOZZLE - 8, bob(t) + 0.5), 0.0, D, 30.0, "nearest")

	# ---- the rocket: the jet and the ship, bobbing
	var rk := group("Rocket")
	keyf(rk, "position", by, 0.0, D, 30.0, "nearest")
	var jet := shape("Jet", pshader("rocket_jet"), Vector2(40, 16), {"x0": NOZZLE, "y0": 0.5, "J": J0, "wob": 1.0,
		"f2": F[2], "f3": F[3], "f4": F[4], "f5": F[5], "f7": F[7], "f8": F[8]}, {"at": Vector2(-30, 0), "parent": rk})
	keyf(jet, "material:shader_parameter/J", func(t: float) -> float: return jet_len(t), 0.0, D, 30.0, "nearest")
	keyf(jet, "material:shader_parameter/wob", func(t: float) -> float: return 0.92 + 0.16 * jrand([frame_of(t), S, 2]), 0.0, D, 30.0, "nearest")
	keyf(jet, "material:shader_parameter/fr", func(t: float) -> float: return float(frame_of(t) + S * 31), 0.0, D, 30.0, "nearest")
	keyf(jet, "material:shader_parameter/dia", func(t: float) -> Vector4:
		var f := frame_of(t) + S * 31
		var v := Vector4()
		for i in 4:
			v[i] = 3.6 + i * 4.3 + (jrand([f, i, 41]) - 0.5) * 0.7
		return v, 0.0, D, 30.0, "nearest")
	var cmap := {"o": OUTLINE, "1": M[1], "2": M[2], "3": M[3], "4": M[4], "5": M[5], "6": M[6], "a": A[0], "b": A[1], "c": A[2],
		"d": A[3], "e": A[4], "w": Color.WHITE, "h": F[5], "x": F[8]}
	var rows := ship_rows()
	var img := Image.create(30, 19, false, Image.FORMAT_RGBA8)
	for j in rows.size():
		for i in rows[j].size():
			var ch: String = rows[j][i]
			img.set_pixel(i, j, cmap[ch] if cmap.has(ch) else Color(0, 0, 0, 0))
	sprite("Ship", asset("ship.res", img), {"parent": rk, "layer": "prop", "centered": false, "at": Vector2(-15, -9)})

	# ---- light: a warm pool round the tail that breathes with the jet, the smoke lit from inside, the flame's glow,
	# a white-hot nozzle, the flame lighting the tail from below
	var smoke_glow := light_at("SmokeGlow", Vector2(NOZZLE - J0 - 6, 0), 26, F[4], 0.24, {"parent": rk})
	keyf(smoke_glow, "material:shader_parameter/alpha", func(t: float) -> float: return 0.24 * fl.call(t), 0.0, D, 30.0, "nearest")
	var pool := light_at("Pool", Vector2(NOZZLE - 10, 0), 60, F[4], 0.28, {"parent": rk})
	keyf(pool, "material:shader_parameter/alpha", func(t: float) -> float: return 0.28 * fl.call(t), 0.0, D, 30.0, "nearest")
	var beam := glow_line("Beam", Vector2(NOZZLE - 3, 0.5), Vector2(NOZZLE - J0 * 0.9, 0.5), 11, F[4], 0.2,
		{"parent": rk, "lo": Vector2(NOZZLE - J0 * 1.2, 0.5), "hi": Vector2(NOZZLE - 3, 0.5)})
	keyf(beam, "material:shader_parameter/b", func(t: float) -> Vector2: return Vector2(NOZZLE - jet_len(t) * 0.9, 0.5), 0.0, D, 30.0, "nearest")
	light_at("Nozzle", Vector2(NOZZLE - 1, 0.5), 8, F[7], 0.45, {"parent": rk})
	var belly := light_at("Belly", Vector2(NOZZLE + 3, 5), 12, F[4], 0.22, {"parent": rk})
	keyf(belly, "material:shader_parameter/alpha", func(t: float) -> float: return 0.22 * fl.call(t), 0.0, D, 30.0, "nearest")
