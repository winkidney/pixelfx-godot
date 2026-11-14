# Shared by the gun effects (projectiles/muzzle-pistol, muzzle-shotgun, muzzle-smg, cannonball; not an effect): the
# originals' gunsmoke puffs and their sparks, grains, embers and pellets replayed as GPU particles. A script spawns
# them with the original's own Rng in the original's order (smoke_add(), spawn(): the same numbers), and each
# becomes one particle whose numbers a process shader reads from a data texture by index
# (fx/projectiles/_muzzle_puff.gdshader, _muzzle_bits.gdshader) and steps with the original's physics; the puffs are
# drawn lit as its cloud() lights them (_muzzle_lobe.gdshader), the bits by _muzzle_bit.gdshader. Casings and shells are a
# small shader (_muzzle_casing.gdshader) keyed along _lib.js casing().
extends "res://build/fx/projectiles/_projectiles.gd"

const SPARK := 0
const GRAIN := 1
const PELLET := 2
const EMBER := 3
## core/sim.js GRAVITY * 0.45: a spark's fall
const SPARK_G := 950.0 * 0.45


## Smoke.add(q): the puff with the original's defaults; R gives its seed after q's own numbers, as the original's does.
static func smoke_add(list: Array, R: Rng, q: Dictionary) -> void:
	var d := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "r0": 1.0, "r1": 2.0, "life": 1.0, "drag": 2.5, "rise": 12.0, "grow": 2.0,
		"curl": 0.0, "a": 0.6, "b": 0.85, "warm": 0.0, "delay": 0.0}
	d.merge(q, true)
	d.seed = R.next() * 100.0
	list.append(d)


## Particles.spawn(kind, x, y, vx, vy, life, col, size, delay): R gives its seed, as the original's does.
static func spawn(list: Array, R: Rng, kind: int, x: float, y: float, vx: float, vy: float, life: float, size := 1.0, delay := 0.0) -> void:
	list.append({"kind": kind, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "size": size, "delay": delay, "seed": R.next() * 100.0,
		"g": SPARK_G, "drag": 2.2, "stretch": 0.022, "max": 9.0, "floor": true, "glow": 0.45 if kind == SPARK else 0.35})


## A float texture of per-particle numbers: rows of Vector4, one column a particle (saved beside the scene).
func data_tex(file: String, rows: Array) -> Texture2D:
	var n: int = (rows[0] as Array).size()
	var img := Image.create(maxi(1, n), rows.size(), false, Image.FORMAT_RGBAF)
	for r in rows.size():
		for i in n:
			var v: Vector4 = rows[r][i]
			img.set_pixel(i, r, Color(v.x, v.y, v.z, v.w))
	return asset(file, img)


## The draw material for puffs: _muzzle_lobe.gdshader on R (smoke, dark to bright) and WR (the same lit by fire), with the
## cloud's density (dens, max) and light (lit) as the original's cloud() options.
func lobe_mat(R: PackedColorArray, WR: PackedColorArray, dens: float, max_a: float, lit: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = pshader("muzzle_lobe")
	m.set_shader_parameter("translucent", true)
	m.set_shader_parameter("n", R.size())
	m.set_shader_parameter("lit", lit)
	# puffs blended over each other add up their density as the cloud's do
	m.set_shader_parameter("dens", dens)
	m.set_shader_parameter("max_a", max_a)
	var ra := PackedVector4Array()
	var wa := PackedVector4Array()
	for i in 8:
		var c: Color = R[mini(i, R.size() - 1)]
		var w: Color = WR[mini(i, WR.size() - 1)]
		ra.append(Vector4(c.r, c.g, c.b, 1.0))
		wa.append(Vector4(w.r, w.g, w.b, 1.0))
	for i in R.size():
		keep_colour(R[i])
		keep_colour(WR[i])
	m.set_shader_parameter("ramp_cols", ra)
	m.set_shader_parameter("warm_cols", wa)
	return m


## The original's Smoke puffs (smoke_add() list) as one one-shot emitter: every puff emitted at 0 and waiting out its
## delay (a puff spawned later carries its spawn time in its delay). o: lifetime (default: the longest puff, within
## the effect), back, dens, max, lit. Key "process_material:shader_parameter/wmul" for the pop's light on it.
func smoke_puffs(name: String, list: Array, R: PackedColorArray, WR: PackedColorArray, o: Dictionary = {}) -> GPUParticles2D:
	var rows := [[], [], [], []]
	var longest := 0.0
	for q in list:
		rows[0].append(Vector4(q.x, q.y, q.vx, q.vy))
		rows[1].append(Vector4(q.r0, q.r1, q.life, q.a))
		rows[2].append(Vector4(q.b, q.drag, q.rise, q.grow))
		rows[3].append(Vector4(q.curl, q.warm, q.delay, q.seed))
		longest = maxf(longest, float(q.delay) + float(q.life) + 0.04)
	var tex := data_tex(name.to_snake_case() + "_data", rows)
	var p := particles(name, {"layer": "soft", "back": o.get("back", false), "amount": list.size(),
		"lifetime": o.get("lifetime", minf(longest, root.duration - 0.02)), "one_shot": true, "explosiveness": 1.0, "texture": "glow16", "local": true,
		"process_shader": PROJ + "_muzzle_puff.gdshader", "process_params": {"count": list.size(), "mode": 0.0, "wmul": 1.0}})
	p.process_material.set_shader_parameter("data", tex)
	p.material = lobe_mat(R, WR, o.get("dens", 1.4), o.get("max", 0.86), o.get("lit", 1.4))
	return p


## Sparks, grains, embers, pellets (spawn() list) as one one-shot emitter and, with o.light, a twin on the light layer
## for their points of light. S: the spark colours [hot, warm, cool, tail]; o: grain [young, old], pellet [head, mid,
## tail], back, lifetime. Returns [emitter, light twin or null].
func bits(name: String, list: Array, S: Array, o: Dictionary = {}) -> Array:
	var rows := [[], [], [], []]
	var longest := 0.0
	for q in list:
		rows[0].append(Vector4(q.x, q.y, q.vx, q.vy))
		rows[1].append(Vector4(q.life, q.delay, q.seed, q.kind))
		rows[2].append(Vector4(q.g, q.drag, q.stretch, q.max))
		rows[3].append(Vector4(q.size, 1.0 if q.floor else 0.0, q.glow, 0.0))
		longest = maxf(longest, float(q.delay) + float(q.life) + 0.04)
	var tex := data_tex(name.to_snake_case() + "_data", rows)
	var grain: Array = o.get("grain", [S[1], S[2]])
	var pel: Array = o.get("pellet", [Color.WHITE, S[1], S[2]])
	var out := []
	for lit in [false, true]:
		if lit and not o.get("light", true):
			out.append(null)
			continue
		var oo := {"amount": list.size(), "one_shot": o.get("one_shot", true), "explosiveness": 1.0 if o.get("one_shot", true) else 0.0,
			"lifetime": o.get("lifetime", minf(longest, root.duration - 0.02)), "texture": "glow16" if lit else "dot1", "local": true,
			"process_shader": PROJ + "_muzzle_bits.gdshader", "process_params": {"count": list.size(), "glow": 1.0 if lit else 0.0,
				"s0": S[0], "s1": S[1], "s2": S[2], "s3": S[3], "g0": grain[0], "pellet": pel[1]}, "back": o.get("back", false)}
		if lit:
			oo.layer = "light"
		if o.has("preprocess"):
			oo.preprocess = o.preprocess
		var p := particles(name + ("Light" if lit else ""), oo)
		p.process_material.set_shader_parameter("data", tex)
		if not lit:
			var m := ShaderMaterial.new()
			m.shader = pshader("muzzle_bit")
			for k in [["s0", S[0]], ["s1", S[1]], ["s2", S[2]], ["s3", S[3]], ["g0", grain[0]], ["g1", grain[1]], ["p0", pel[0]], ["p1", pel[1]], ["p2", pel[2]]]:
				m.set_shader_parameter(k[0], k[1])
				keep_colour(k[1])
			p.material = m
		out.append(p)
	return out


## A casing (mode 0: brass, three dots; 1: a shotgun shell, two rows) drawn by _muzzle_casing.gdshader over a box
## lo..hi (px from the origin) that holds its whole flight; f(t) -> {x, y, a, fade, glint} is keyed every frame
## from t0 to t1 (shown only then). cols: brass [B1, B2, B3] or shell [SH0..SH4].
func casing_node(name: String, mode: int, cols: Array, lo: Vector2, hi: Vector2, f: Callable, t0: float, t1: float) -> ColorRect:
	var a := (lo - Vector2(3, 3)).floor()
	var b := (hi + Vector2(3, 3)).ceil()
	var sz := b - a
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	var params := {"mode": float(mode), "pos": Vector2.ZERO, "ang": 0.0, "fade": 1.0, "glint": 0.0}
	for i in cols.size():
		params["c%d" % i] = cols[i]
	var n := shape(name, pshader("muzzle_casing"), sz, params, {"at": a + sz / 2.0})
	keyf(n, "material:shader_parameter/pos", func(t: float) -> Vector2:
		var k: Dictionary = f.call(t)
		return Vector2(k.x, k.y), t0, t1, 30.0, "nearest")
	keyf(n, "material:shader_parameter/ang", func(t: float) -> float: return float(f.call(t).a), t0, t1, 30.0, "nearest")
	keyf(n, "material:shader_parameter/fade", func(t: float) -> float: return float(f.call(t).fade), t0, t1, 30.0, "nearest")
	keyf(n, "material:shader_parameter/glint", func(t: float) -> float: return float(f.call(t).glint), t0, t1, 30.0, "nearest")
	show(n, t0, t1)
	return n


## The pop of light at the muzzle: glows keyed as k * pop(t) (pop: Callable t -> 0..1) over [t0, t1].
func pop_light(name: String, at: Vector2, r: float, c: Color, k: float, pop: Callable, t0: float, t1: float) -> ColorRect:
	var g := light_at(name, at, r, c, 0.0)
	keyf(g, "material:shader_parameter/alpha", func(t: float) -> float: return k * float(pop.call(t)), t0, t1, 30.0, "nearest")
	return g


## The original's clock at frame k: a one-shot's own t, summed in 120 Hz substeps as core/fx.js steps it (sub 4), or
## a looping draw()'s t summed a frame at a time (sub 1); float for float, so a `t < 3 * F1` test lands on the same
## frames as the original's.
static func sim_t(k: int, sub := 4) -> float:
	var dt := 1.0 / 30.0
	var t := 0.0
	for i in k:
		for j in sub:
			t += dt / sub
	return t


## Key node.prop at every frame from 0 to `frames` with f(the original's clock at that frame) (nearest: held).
func key_frames(node: Node, prop: String, frames: int, f: Callable, sub := 4) -> void:
	var keys := []
	for k in frames + 1:
		keys.append([maxf(0.0, k / 30.0 - 0.002) if k > 0 else 0.0, f.call(sim_t(k, sub))])
	key(node, prop, keys, "nearest")
