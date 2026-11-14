# reimagined-from: src/fx/scifi/tractor-beam.js@120b64de16152b0598d963091f71d019bf8c0115
# Tractor beam: A hovering pod projects a cone of light to the floor; rocks tear loose in puffs of dust and spiral up spinning into the lens while rings of light climb the beam.
# loop, 3.00 s, 120x132 canvas, origin [60.0, 114.0], backdrop ground
# Shaders keyed by the loop clock draw the pool, the glassy cone, the rings climbing it, the tumbling rocks (popping out
# of the floor, wobbling, spiralling up: the original's own rock shapes and hauls) and the hovering pod, in the
# original's order (fx/scifi/_tractor.gdshader modes 0..5; light in _tractor_light.gdshader). The original's cycle()
# particles are GPU particles placed where it puts them: light streaks up the beam (_vstreak.gdshader), dust puffs,
# grit and motes hauled up in a spiral, twinkles (_tractor_bits.gdshader). The dust and grit each rock tears loose,
# and the dust swirling round the beam's foot, are the original's own Ghosts (_ghost.gdshader).
extends "res://build/fx/scifi/_scifi.gd"

const LENS := -84.0
const BOTW := 32.0
const POP := 0.1
const HOVER := 0.32
const RISE := 1.4
const BITS := "res://addons/pixelfx_particles/fx/scifi/_tractor_bits.gdshader"


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var H: PackedColorArray = fit(root.ramps.hull, 6)
	var ST: PackedColorArray = fit(root.ramps.stone, 5)
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0

	# the rocks, torn up one after another, and what each tears loose
	var rn := JsRng.new(S)
	var ra := PackedVector4Array()
	var rb := PackedVector4Array()
	var r0 := PackedVector4Array()
	var r1 := PackedVector4Array()
	var rocks := []
	for i in 7:
		var id := i + S * 31
		var born := (i / 7.0) * D + rn.range(-0.06, 0.06)
		var rr0 := rn.range(8, 25)
		var th0 := (0.0 if i % 2 else PI) + rn.range(-0.45, 0.45)
		var dir := rn.sign()
		var s := rn.range(2.4, 4.4)
		var a0 := rn.range(0, TAU)
		var va := rn.range(-7, 7)
		rocks.append([born, rr0, th0])
		ra.append(Vector4(born, rr0, th0, dir))
		rb.append(Vector4(s, a0, va, 0.0))
		var rv := []
		for j in 6:
			rv.append(rand([id, j]))
		r0.append(Vector4(rv[0], rv[1], rv[2], rv[3]))
		r1.append(Vector4(rv[4], rv[5], 0.0, 0.0))
	ghosts_begin(D)
	for r in rocks:
		var x: float = cos(r[2]) * r[1]
		for i in 5:
			var gx := x + rn.range(-3, 3)
			var vx := rn.range(-34, 34)
			var vy := -rn.range(8, 26)
			var life := rn.range(0.5, 0.9)
			ghost(r[0] + 0.02, DUST, gx, -1, vx, vy, life, mixc(ST[3], C[4], 0.3), rn.range(2.2, 3.6))
		for i in 6:
			var gx := x + rn.range(-2, 2)
			var vx := rn.range(-45, 45)
			var vy := -rn.range(60, 150)
			var life := rn.range(0.5, 0.9)
			var c: Color = rn.pick([ST[2], ST[3], ST[4]])
			ghost(r[0] + 0.02, GRIT, gx, -2, vx, vy, life, c, 2.0 if rn.chance(0.3) else 1.0)
	for i in 16:
		var s := rn.sign()
		var born := rn.range(0, D)
		var gx := s * rn.range(14, 34)
		var gy := -rn.range(0, 3)
		var vx := -s * rn.range(6, 22)
		var vy := -rn.range(4, 14)
		var life := rn.range(0.9, 1.5)
		ghost(born, DUST, gx, gy, vx, vy, life, mixc(ST[3], C[5], 0.3), rn.range(2.6, 4.4))
	# the in-between colours the original mixes for the rocks' lit tops and the dust it hauls
	for j in 9:
		keep_colour(mixc(ST[4], C[6], 0.3 + 0.6 * j / 8.0))
		keep_colour(mixc(ST[3], C[5], 0.25 + 0.5 * j / 8.0))
	keep_colour(mixc(ST[3], C[5], 0.4))

	var cur := []
	for s in 4:
		cur.append(rand([S, s, 7]))
	var base := {"t": 0.0, "pal": C, "hull": H, "stone": ST, "curtain": PackedFloat32Array(cur), "rock_a": ra, "rock_b": rb, "rock_r0": r0, "rock_r1": r1}
	var nodes := []
	var layer := func(name: String, m: int, extra: Dictionary) -> ColorRect:
		var pr := base.duplicate()
		pr.mode = m
		pr.merge(extra, true)
		var n := shape(name, sh("tractor"), canvas, pr, {"at": mid})
		nodes.append(n)
		return n
	layer.call("Pool", 0, {"translucent": true})
	layer.call("Back", 1, {})
	ghosts({"only": "back", "back": false, "floor": 0.0, "box": [-58, -112, 58, 14]})
	layer.call("Beam", 2, {})
	layer.call("Rings", 3, {})

	# light streaks drawn up the beam (cycle(t, D, 22, seed + 1, ...))
	var st := Image.create(22, 1, false, Image.FORMAT_RGBAF)
	for i in 22:
		var g := rng([S + 1, i, 911])
		var born := g.next() * D
		var L := g.range(0.6, 1.0)
		st.set_pixel(i, 0, Color(born, L, rng([S + 1, i]).range(-0.85, 0.85), 0.0))
	var sp := particles("Streaks", {"amount": 22, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": "dot1", "preprocess": 1.0 / 60.0,
		"process_shader": "res://addons/pixelfx_particles/fx/scifi/_vstreak.gdshader",
		"process_params": {"t": 0.0, "period": D, "bits": asset("_streaks", st), "y0": -2.0, "y1": LENS + 5.0, "pw": 2.0,
			"l0": 2.0, "l1": 6.0, "fade": 3.0, "cone": 1.0, "bot": BOTW, "top": 5.5, "lens": LENS}})
	sp.interpolate = false
	var vm := ShaderMaterial.new()
	vm.shader = sh("vline")
	vm.set_shader_parameter("head", C[7])
	vm.set_shader_parameter("tail", C[5])
	vm.set_shader_parameter("split", 0.3)
	sp.material = vm
	key(sp, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])

	# dust drawn up in soft puffs (cycle(t, D, 9, seed + 3, ...))
	var du := Image.create(9, 2, false, Image.FORMAT_RGBAF)
	for i in 9:
		var g := rng([S + 3, i, 911])
		var born := g.next() * D
		var L := g.range(1.4, 2.0)
		var r := rng([S + 3, i])
		var a := r.range(8, 26)
		var b := r.range(0, TAU)
		du.set_pixel(i, 0, Color(born, L, a, b))
		du.set_pixel(i, 1, Color(r.sign(), 0, 0, 0))
	_bits("Puffs", 0, 9, du, 10, {"dust_a": ST[3], "dust_b": C[5]})
	# grit and motes of light hauled up in a quick spiral (cycle(t, D, 46, seed + 2, ...))
	var gr := Image.create(46, 4, false, Image.FORMAT_RGBAF)
	for i in 46:
		var g := rng([S + 2, i, 911])
		var born := g.next() * D
		var L := g.range(0.8, 1.3)
		var r := rng([S + 2, i])
		var a := r.range(6, 30)
		var b := r.range(0, TAU)
		var dir := r.sign()
		var turns := r.range(1, 1.8)
		var mote := r.chance(0.45)
		var c: Color
		if mote:
			c = Color.WHITE if r.chance(0.5) else C[6]
		else:
			c = r.pick([ST[3], ST[4], ST[4]])
		var tail: Color = C[4] if mote else ST[2]
		keep_colour(c)
		keep_colour(scalec(c, 0.7))
		gr.set_pixel(i, 0, Color(born, L, a, b))
		gr.set_pixel(i, 1, Color(dir, turns, 1.0 if mote else 0.0, 0))
		gr.set_pixel(i, 2, c)
		gr.set_pixel(i, 3, tail)
	var grt := _bits("Grit", 1, 46, gr, 1)
	_bits("MoteHeads", 2, 46, gr, 1)
	# twinkles caught in the light (cycle(t, D, 8, seed + 4, 0.5, ...))
	var tw := Image.create(8, 2, false, Image.FORMAT_RGBAF)
	for i in 8:
		var g := rng([S + 4, i, 911])
		var born := g.next() * D
		var r := rng([S + 4, i])
		var a := r.range(4, 24)
		var b := r.range(0, TAU)
		var dir := r.sign()
		tw.set_pixel(i, 0, Color(born, 0.5, a, b))
		tw.set_pixel(i, 1, Color(dir, r.range(0.1, 0.7), 0, 0))
	var twt := _bits("Twinkles", 3, 8, tw, 5, {}, {"c": C[6], "tip": C[5]})

	layer.call("Rocks", 4, {})
	ghosts({"only": "front", "back": false, "floor": 0.0, "box": [-58, -112, 58, 14]})
	layer.call("Pod", 5, {})
	var lit := shape("Light", sh("tractor_light"), canvas, {"t": 0.0, "pal": C, "grit": grt, "twinkles": twt, "rock_a": ra, "rock_b": rb}, {"at": mid})
	nodes.append(lit)
	for n in nodes:
		clock(n)


## One kind of the original's cycle() particles: `n` slots placed by _tractor_bits.gdshader (mode), drawn by
## _tractor_bit.gdshader on a q x q quad. Returns its data texture.
func _bits(name: String, mode: int, n: int, img: Image, q: int, pp: Dictionary = {}, dp: Dictionary = {}) -> Texture2D:
	var D: float = root.duration
	var data := asset("_" + name.to_snake_case(), img)
	var params := {"t": 0.0, "mode": mode, "bits": data}
	params.merge(pp, true)
	var p := particles(name, {"amount": n, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": _quad(q) if q > 1 else texture("dot1"),
		"preprocess": 1.0 / 60.0, "process_shader": BITS, "process_params": params})
	(p.process_material as ShaderMaterial).set_shader_parameter("mode", mode)
	p.interpolate = false
	var m := ShaderMaterial.new()
	m.shader = sh("tractor_bit")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("quad", Vector2(q, q))
	for k in dp:
		m.set_shader_parameter(k, dp[k])
		keep_colour(dp[k])
	p.material = m
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	return data
