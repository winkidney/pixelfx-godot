# reimagined-from: src/fx/scifi/energy-core.js@e0b4c8f981aee6a9630c9810f717cb7a25684e67
# Energy core: A plasma core beating in a steel cage: it swells and throws a shock ring on each beat, two tilted rings orbit it, and arcs jump to the bars and spark.
# loop, 2.40 s, 112x100 canvas, origin [56.0, 88.0], backdrop ground
# The cage, plinth, cap and the core's churning plasma are a shader keyed by the loop clock in the original's draw
# order (fx/scifi/_energy_core.gdshader mode 0; the core's bands are its own tileFbm noise). The filaments (re-rolled
# every other frame) and the arcs (one 0.1 s slot at a time) are the original's own bolt paths, rolled here from its
# seeded generators into a data texture and stroked by the shader (mode 1: halo, body, white core) with the thumps'
# shock rings; the light is _energy_core_light.gdshader. The sparks the arcs strike off the bars and the motes each
# thump throws are the original's own Ghosts (_ghost.gdshader), drawn from the same generator in the same order.
extends "res://build/fx/scifi/_scifi.gd"

const CY := -36.0
const R0 := 11.0
const RC := 24.0
const TOPY := -64.0
const BOTY := -9.0
const SLOT := 0.1
const BEATS := [[0.05, 1.0, true], [0.25, 0.5, false], [1.25, 1.0, true], [1.45, 0.5, false]]


static func env(a: float) -> float:
	return a / 0.03 if a < 0.03 else exp(-(a - 0.03) / 0.12)


func pulse_at(t: float) -> float:
	var m := 0.0
	for b in BEATS:
		m = maxf(m, b[1] * env(since(t, b[0], root.duration)))
	return m


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var NS := int(round(D / SLOT))
	var NF := int(round(D * 30.0))
	var H: PackedColorArray = fit(root.ramps.metal, 6)
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var bars := []
	for i in 6:
		var a := (i / 6.0) * TAU + PI / 6.0
		bars.append({"x": RC * sin(a), "z": cos(a)})
	var bar_u := PackedVector4Array()
	for b in bars:
		# the cell's middle: the original's x (11.999.. for 12) lands on its cells in double precision
		bar_u.append(Vector4(floorf(b.x) + 0.5, b.z, 1.0 if b.z >= 0.0 else 0.0, 0.0))

	var data := Image.create(64, NF + NS, false, Image.FORMAT_RGBAF)
	# the filaments: three bolts from the heart, re-rolled every other frame (rng(seed, f, 5)), reaching the pulsing rim
	for i in NF:
		var t := frame_t(i)
		var f := int(floor(t * 15.0))
		var r := rng([S, f, 5])
		var R := R0 * (1.0 + 0.14 * pulse_at(t))
		for j in 3:
			var a := (j / 3.0) * TAU + f * 0.7 + r.range(-0.4, 0.4)
			var pts := bolt_path(r, 0, CY, cos(a) * R * 0.88, CY + sin(a) * R * 0.88, 0.32, 3)
			for q in pts.size():
				data.set_pixel(j * 9 + q, i, Color(pts[q].x, pts[q].y, 0.0, 0.0))

	# the arcs and what they strike off, as the original's setup() rolls them
	var rn := JsRng.new(S)
	ghosts_begin(D)
	var slots := []
	for s in NS:
		slots.append([])
	for s in NS:
		var ts := s * SLOT
		var hot := false
		for b in BEATS:
			if b[2] and since(ts, b[0], D) < 0.16:
				hot = true
		for n in (2 if hot else 1):
			if not hot and not rn.chance(0.4):
				continue
			var cand := bars.filter(func(b: Dictionary) -> bool: return b.z > -0.2)
			var bar: Dictionary = rn.pick(cand)
			var ty := rn.range(TOPY + 8.0, BOTY - 6.0)
			var ang := atan2(ty - CY, bar.x)
			var sx := cos(ang) * R0
			var sy := CY + sin(ang) * R0
			var path := bolt_path(rn, sx, sy, bar.x - signf(bar.x) * 1.5, ty, 0.3, 4)
			var cnt := rn.int_(0, 1)
			var fk := fork_paths(rn, path, cnt, 7.0, 0.35)
			slots[s].append([path, 1.0])
			for p in fk:
				slots[s].append([p, 0.6])
			for i in 5:
				var a := atan2(ty - sy, bar.x - sx) + PI + rn.range(-1.2, 1.2)
				var sp := rn.range(60, 170)
				ghost(ts, SPARK, bar.x, ty, cos(a) * sp, sin(a) * sp - 40.0, rn.range(0.2, 0.5))
	for b in BEATS:
		if not b[2]:
			continue
		for i in 12:
			var a := rn.range(0, TAU)
			var sp := rn.range(40, 110)
			ghost(b[0] + 0.02, MOTE, cos(a) * R0, CY + sin(a) * R0, cos(a) * sp, sin(a) * sp, rn.range(0.25, 0.5), rn.pick([Color.WHITE, C[6], C[5]]), 0.7)
	for s in NS:
		var j := 0
		var sid := 0
		for st in slots[s]:
			for p in st[0]:
				data.set_pixel(j, NF + s, Color(p.x, p.y, sid, st[1]))
				j += 1
			sid += 1
		data.set_pixel(j, NF + s, Color(0, 0, -1, 0))
	var dtex := asset("_data", data)

	var params := {"t": 0.0, "data": dtex, "pal": C, "metal": H, "bars": bar_u, "seed": S, "frame": 0.0, "slot": 0.0, "k": 1.0}
	var m0 := params.duplicate()
	m0.mode = 0
	var machine := shape("Machine", sh("energy_core"), canvas, m0, {"at": mid})
	var m1 := params.duplicate()
	m1.mode = 1
	var arcs := shape("Arcs", sh("energy_core"), canvas, m1, {"at": mid})
	var lp := params.duplicate()
	lp.erase("metal")
	lp.erase("bars")
	lp.erase("seed")
	ghosts({"sparks": [Color.WHITE, C[6], C[5], C[4]], "floor": 0.0, "box": [-54, -98, 54, 11]})
	var lit := shape("Light", sh("energy_core_light"), canvas, lp, {"at": mid})
	for n in [machine, arcs, lit]:
		clock(n)
		frames_key(n, "material:shader_parameter/frame", func(t: float) -> float: return float(int(roundf(t * 30.0)) % NF))
		frames_key(n, "material:shader_parameter/slot", func(t: float) -> float: return float(int(floor(t / SLOT)) % NS))
		frames_key(n, "material:shader_parameter/k", func(t: float) -> float: return 1.0 - (t - floor(t / SLOT) * SLOT) / SLOT)
