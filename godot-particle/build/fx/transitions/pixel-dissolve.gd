# reimagined-from: src/fx/transitions/pixel-dissolve.js@63ce05499f0ccf8561092f03dcae9f03189ba57f
# Pixel dissolve: Clumps of blocks wink in, each drawn in a white outline that fills black and cools, with glints; then they wink out, outlines collapsing, the last small ones sparkling away.
# one-shot, 2.20 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The original's layout (20 px cells split into blocks, each block's in and out time ranked off a clumpy field, rolled
# from its seed) is worked out at build time into data textures; one screen shader winks every block in and out at
# the reference's clock as the original draws it, outline, fill, collapsing heart and pixel dust from its own hashes
# (fx/transitions/_dissolve.gdshader), its light twin adds each block's glow. The spinning glints on the blocks'
# corners are frame-table particles (marks()).
extends "res://build/fx/transitions/_transitions.gd"

const P := 0.17
const IN0 := 0.04
const IN1 := 0.8
const OUT0 := 1.12
const OUT1 := 1.85
const CELL := 20


func make() -> void:
	var seed: int = meta.options.seed
	var blocks := []
	var cells := Image.create(16, 9, false, Image.FORMAT_RGF)
	for cy in 9:
		for cx in 16:
			var h := rand([cx, cy, seed])
			var n := 1 if h < 0.32 else (2 if h < 0.74 else 4)
			var s := CELL / n
			cells.set_pixel(cx, cy, Color(blocks.size(), n * n, 0))
			for j in n:
				for i in n:
					blocks.append({"x": cx * CELL + i * s, "y": cy * CELL + j * s, "s": s})
	var rank := func(key_: Callable) -> PackedFloat64Array:
		var v := []
		for b in blocks:
			v.append(key_.call(b))
		var idx := range(blocks.size())
		idx.sort_custom(func(a: int, b: int) -> bool: return v[a] < v[b] or (v[a] == v[b] and a < b))
		var out := PackedFloat64Array()
		out.resize(blocks.size())
		for k in idx.size():
			out[idx[k]] = k / float(blocks.size() - 1)
		return out
	var at := func(b: Dictionary, sd: int) -> float: return fbm((b.x + b.s / 2.0) / 64.0, (b.y + b.s / 2.0) / 64.0, sd, 3)
	var uin: PackedFloat64Array = rank.call(func(b: Dictionary) -> float: return at.call(b, seed) + 0.22 * rand([b.x, b.y, seed + 1]) + (0.12 if b.s == 20 else (-0.08 if b.s == 5 else 0.0)))
	var uout: PackedFloat64Array = rank.call(func(b: Dictionary) -> float: return at.call(b, seed + 7) + 0.22 * rand([b.x, b.y, seed + 2]) + (-0.14 if b.s == 20 else (0.1 if b.s == 5 else 0.0)))
	var img := Image.create(blocks.size(), 2, false, Image.FORMAT_RGBAF)
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		b.tin = IN0 + uin[i] * (IN1 - IN0)
		b.tout = OUT0 + uout[i] * (OUT1 - OUT0)
		b.glint = rand([b.x, b.y, seed + 3]) < (0.32 if b.s >= 10 else 0.1)
		b.gx = b.x + (0 if rand([b.x, b.y, seed + 4]) < 0.5 else b.s)
		b.gy = b.y + (0 if rand([b.x, b.y, seed + 5]) < 0.5 else b.s)
		b.spin = (rand([b.x, b.y, seed + 6]) - 0.5) * 3.0
		b.L = 9.0 + 6.0 * rand([b.x, b.y, seed + 9]) if (b.s == 20 and rand([b.x, b.y, seed + 8]) < 0.45) else 2.5 + b.s * 0.32
		img.set_pixel(i, 0, Color(b.x, b.y, b.s, i))
		img.set_pixel(i, 1, Color(b.tin, b.tout, 0, 0))
	var btex := asset("_blocks", img)
	var ctex := asset("_cells", cells)
	for nd in [screen("Blocks", "dissolve", {"blocks": btex, "cells": ctex}), screen("Light", "dissolve_light", {"blocks": btex, "cells": ctex})]:
		per_frame(nd, "material:shader_parameter/fr", func(_i: int, t: float) -> float: return floorf(t * 15.0))

	# glints on top: a spinning star on a corner of the block, swelling and fading
	var rows := frame_rows(func(_i: int, t: float) -> Array:
		var out := []
		for b in blocks:
			if not b.glint:
				continue
			var ki: float = (t - b.tin) / P
			var ko: float = (t - b.tout) / P
			if ki < 0.0 or ko >= 1.6:
				continue
			var u := 0.0
			var dir := 1.0
			if ko < 0.0:
				if not (ki > 0.15 and ki < 1.6):
					continue
				u = (ki - 0.15) / 1.45
			else:
				if not (ko > 0.3):
					continue
				u = (ko - 0.3) / 1.3
				dir = -1.0
			if u <= 0.0 or u >= 1.0:
				continue
			var L: float = b.L * pow(sin(PI * u), 0.7)
			var g: Variant = glint_m(b.gx, b.gy, L, b.spin * u * dir + 0.4, 5, 4)
			if g == null:
				g = {"k": M_NONE, "x": b.gx, "y": b.gy}
			if b.L > 8.0:
				g.lc = 5
				g.lp = Vector2(b.gx, b.gy)
				g.lr = 18.0 + L
				g.lk = 0.25 * sin(PI * u)
			out.append(g)
		return out)
	marks("Glints", rows)
