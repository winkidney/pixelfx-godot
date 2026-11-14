# reimagined-from: src/fx/status/bleeding.js@5c01160f6e1795dc12704834c34654d1644cef2f
# Bleeding: Bleeding out: beads swell at three wounds, run, let go and fall to spatter into a glossy pool that ripples; each heartbeat spurts a little and flashes the body red.
# loop, 2.40 s, 60x56 canvas, origin [30.0, 46.0], backdrop ground, stand-in 2
# ramp palette: #350711 #5e0c1b #931327 #c71e33 #f2384a #ff8a7a
# The stand-in is the effect's own Actor, flashed red on each heartbeat. The three wounds, their runs and the pool
# are still marks worked out as the original does (from the stand-in's shape). Each drop is a bead (a strip of its
# four states) that swells on the original's clock, a falling drop keyed down its fall (tails by speed), and a splat
# (a strip: spreading, drying) with a crown thrown by a one-shot emitter. Each beat squeezes a spurt from the first
# wound (a one-shot emitter that dies on the floor).
extends "res://build/fx/status/_status.gd"

const G := 900.0
var C: PackedColorArray


## pixel dicts (from the feet) as frames of one sprite, placed where they belong
func dict_strip(name: String, dicts: Array, o: Dictionary = {}) -> Sprite2D:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for d in dicts:
		for q in d:
			lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
			hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	var sz := hi - lo + Vector2i.ONE
	var img := Image.create(sz.x * dicts.size(), sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in dicts.size():
		for q in dicts[i]:
			img.set_pixel(i * sz.x + q.x - lo.x, q.y - lo.y, dicts[i][q])
	keep_image_colours(img)
	var oo := {"at": Vector2(lo), "centered": false, "hframes": dicts.size()}
	oo.merge(o, true)
	return sprite(name, asset("_" + name.to_lower(), img), oo)


func make() -> void:
	var D: float = root.duration
	var BEAT := D / 2.0
	C = fit("palette", 6)
	var S := shape_of()
	var H := AH
	var W := AW
	ground(-1.0)

	# ---- the wounds
	var wounds := []
	var mk := func(mx: int, my: int, drops: int, phase: float) -> Dictionary:
		var run := 1
		while run < 3 and on(mx, my + run + 1):
			run += 1
		return {"x": AX + mx, "mx": mx, "y0": AY + my, "yb": AY + my + run + 1, "drops": drops, "phase": phase, "side": -1 if mx < W / 2.0 else 1}
	var edge := func(q: float, sd: int) -> Vector2i:
		var my := int(jround(H * q))
		return Vector2i(S.rows[my][0] + 1 if sd < 0 else S.rows[my][1] - 1, my)
	var front: Vector2i = edge.call(0.55, 1)
	for q in S.body:
		if q.y > H * 0.5 and q.y < H * 0.62 and q.x > W * 0.55 and q.x < W * 0.75 and on(q.x, q.y + 3):
			front = q
			break
	var e0: Vector2i = edge.call(0.57, -1)
	var e2: Vector2i = edge.call(0.6, 1)
	wounds = [mk.call(e0.x, e0.y, 3, 0.0), mk.call(front.x, front.y, 2, 0.35), mk.call(e2.x, e2.y, 2, 0.7)]

	# ---- behind: the pool, dark and glossy
	var pool := {}
	var pxc: float = (wounds[0].x + wounds[2].x + 1.0) / 2.0 - 1.0
	var rx := 6.5
	for x in range(int(floorf(pxc - rx - 1)), int(floorf(pxc + rx + 1)) + 1):
		var q := absf(x + 0.5 - pxc) / rx
		if q > 1.1:
			continue
		pool[Vector2i(x, -1)] = C[2] if q > 0.85 else C[1]
		if q < 0.8:
			pool[Vector2i(x, 0)] = C[1] if q < 0.5 else C[0]
		if q < 0.45:
			pool[Vector2i(x, 1)] = C[0]
	pool[Vector2i(int(floorf(pxc - 2)), -1)] = C[4]
	pool[Vector2i(int(floorf(pxc - 1)), -1)] = C[3]
	pool[Vector2i(int(floorf(pxc + 3)), -1)] = C[3]
	pixels("Pool", pool, {"back": true})
	var pg := glow("PoolLight", 10, {"radius": 8.0, "color": C[3], "alpha": 0.06}, {"at": Vector2(pxc, -1)})
	sample(pg, "material:shader_parameter/alpha", func(t: float) -> float: return 0.06 + 0.04 * exp(-fposmod(t, BEAT) / 0.25), "linear")

	# ---- the body, flashing red with each heartbeat
	var body := actor_node()
	body.material.set_shader_parameter("flash_color", C[4])
	var hurt := func(t: float) -> float: return maxf(0.0, 1.0 - fposmod(t, BEAT) / 0.12)
	sample(body, "material:shader_parameter/flash", func(t: float) -> float: return 0.26 * hurt.call(t))

	# ---- gashes and runs
	var marks := {}
	for w in wounds:
		marks[Vector2i(w.x, w.y0 - 1)] = C[1]
		marks[Vector2i(w.x - w.side, w.y0 - 1)] = C[0]
		marks[Vector2i(w.x - w.side, w.y0)] = C[2]
		for y in range(w.y0, w.yb):
			marks[Vector2i(w.x, y)] = C[4] if y == w.y0 else (C[3] if y >= w.yb - 1 else C[2])
	pixels("Wounds", marks)

	# ---- drops: bead, fall, splat
	var n := 0
	for w in wounds:
		var period: float = D / w.drops
		for k in int(w.drops):
			var born: float = w.phase * period + k * period
			var swell := period * 0.62
			var big: bool = (k + int(w.mx)) % 2 == 0
			var fall_h := maxf(1.0, -1.0 - w.yb)
			var fall := sqrt(2.0 * fall_h / G)
			var x: int = w.x
			# the bead's four states
			var beads := []
			for st in [[1, 4], [2, 4], [2, 5], [3, 5]]:
				var d := {}
				for j in int(st[0]):
					d[Vector2i(x, w.yb + j)] = C[2] if j == st[0] - 1 else C[3]
				if st[0] == 3:
					d[Vector2i(x - 1, w.yb + 2)] = C[1]
				d[Vector2i(x, w.yb + st[0] - 2)] = C[st[1]]
				beads.append(d)
			var bead := dict_strip("Bead%d" % n, beads)
			# the drop in flight: tails 0..5
			var flights := []
			for tail in 6:
				var d := {}
				for j in range(1, tail + 1):
					d[Vector2i(0, -j)] = C[3] if big else C[2]
				if big:
					d[Vector2i(0, 0)] = C[5]
					d[Vector2i(1, 0)] = C[4]
					d[Vector2i(0, 1)] = C[3]
					d[Vector2i(1, 1)] = C[2]
				else:
					d[Vector2i(0, 0)] = C[4]
				d[Vector2i(0, -5)] = d.get(Vector2i(0, -5), Color(0, 0, 0, 0))
				flights.append(d)
			var drop := dict_strip("Drop%d" % n, flights)
			# the splat: spreading for a tenth of a second, drying darker in three steps, its shine for 0.3 s
			var splats := []
			var hw_full := 2.2 if big else 1.4
			var cx := x + 0.5
			for st in [[0.55, 4, true], [0.8, 4, true], [1.0, 4, true], [1.0, 4, false], [1.0, 3, false], [1.0, 2, false]]:
				var hw: float = hw_full * st[0]
				var d := {}
				for xx in range(int(floorf(cx - hw)), int(ceilf(cx + hw)) + 1):
					d[Vector2i(xx, -1)] = C[st[1] - 1] if absf(xx + 0.5 - cx) > hw * 0.75 else C[st[1]]
				if st[2]:
					d[Vector2i(int(floorf(cx - 0.5)), -1)] = C[5]
				splats.append(d)
			var splat := dict_strip("Splat%d" % n, splats)
			var crown := particles("Crown%d" % n, {"at": Vector2(cx, -1.5), "amount": 3 if big else 2, "lifetime": 0.16, "one_shot": true,
				"explosiveness": 1.0, "texture": "dot1", "dir": -90, "spread": 28, "speed": [45, 80], "gravity": Vector2(0, G),
				"initial": gradient([C[4], C[3], C[3]]), "preprocess": 0.0})
			var life := D * 0.85
			var K := {"bv": [], "bf": [], "dv": [], "dp": [], "df": [], "sv": [], "sf": [], "sa": []}
			var land := fposmod(born + swell + fall, D)
			for t in frame_times():
				var age := fposmod(t - born, D)
				K.bv.append([t, age < swell])
				var u := age / swell
				K.bf.append([t, 0 if u < 0.35 else (1 if u < 0.5 else (2 if u < 0.75 else 3))])
				var fa := age - swell
				var flying := fa >= 0.0 and fa < fall
				K.dv.append([t, flying])
				if flying:
					K.dp.append([t, Vector2(x, floorf(w.yb + 2 + 0.5 * G * fa * fa))])
					K.df.append([t, int(minf(5.0, floorf(G * fa * 0.012)))])
				var sg := fa - fall
				K.sv.append([t, sg >= 0.0 and sg <= life])
				if sg >= 0.0:
					K.sf.append([t, 0 if sg < 0.035 else (1 if sg < 0.07 else (2 if sg < 0.3 else (3 if sg < 0.35 else (4 if sg < 1.0 else 5))))])
					K.sa.append([t, 1.0 - smooth(life - 0.5, life, sg)])
			key(bead, "visible", K.bv, "nearest")
			key(bead, "frame", K.bf, "nearest")
			key(drop, "visible", K.dv, "nearest")
			key(drop, "position", K.dp, "nearest")
			key(drop, "frame", K.df, "nearest")
			drop.offset = Vector2(0, -5)
			key(splat, "visible", K.sv, "nearest")
			key(splat, "frame", K.sf, "nearest")
			key(splat, "modulate:a", K.sa, "nearest")
			emit(crown, land)
			n += 1

	# ---- the heartbeat squeezes a spurt from the first wound
	var w0: Dictionary = wounds[0]
	for b in 2:
		var sp := particles("Spurt%d" % b, {"at": Vector2(w0.x + 0.5, w0.y0), "amount": 7, "lifetime": 0.45, "one_shot": true,
			"explosiveness": 0.82, "texture": "streak3", "align": true, "dir": -122.0 if w0.side < 0 else -58.0, "spread": 24,
			"speed": [28, 66], "gravity": Vector2(0, G * 0.62), "drag": 1.0, "initial": gradient([C[5], C[4], C[3], C[2]]),
			"collide": {"hide": true, "size": 1.0}, "preprocess": 0.0})
		emit(sp, b * BEAT)
	var wg := glow("WoundLight", 8, {"radius": 6.0, "color": C[4], "alpha": 0.0}, {"at": Vector2(w0.x + 0.5, w0.y0)})
	sample(wg, "material:shader_parameter/alpha", func(t: float) -> float: return 0.25 * hurt.call(t), "linear")
