# reimagined-from: src/fx/transitions/diamond-wipe.js@518680ebe5412e8684915bf2a5c7314ddc37a59e
# Diamond wipe: A wave of faceted diamonds swells across the screen, rims bright and ridges lit, cooling to black as they lock; then they rise as gems again and shrink away with glints.
# one-shot, 2.00 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The original's lattice (each diamond's place and its in / out times, rolled from its seed) is a data texture; one
# screen shader swells and shrinks every diamond at the reference's clock with the original's facets, rims, ridges and
# sheen (fx/transitions/_diamond.gdshader), a light twin adds their rim light and glows. The glints on their top
# points as they lock in, and as they wink out, are frame-table particles (marks()).
extends "res://build/fx/transitions/_transitions.gd"

const S := 32.0
const HD := 17.0
const GROW := 0.24
const IN0 := 0.04
const IN1 := 0.66
const OUT0 := 1.05
const OUT1 := 1.56


func make() -> void:
	var seed: int = meta.options.seed
	# the lattice: rows of diamonds S apart, every other row shifted half a step
	var lat := []
	for j in range(-1, int(ceilf(SHH / (S / 2.0))) + 2):
		for i in range(-1, int(ceilf(SW / S)) + 2):
			var cx := i * S + (S / 2.0 if (j & 1) else 0.0)
			var cy := j * S / 2.0
			if cx + HD < 0.0 or cy + HD < 0.0 or cx - HD > SW or cy - HD > SHH:
				continue
			var u := clampf((cx + 0.45 * cy) / (SW + 0.45 * SHH), 0.0, 1.0)
			var jr_ := rand([i, j, seed])
			lat.append({"cx": cx, "cy": cy, "tin": IN0 + (IN1 - IN0) * clampf(u + (jr_ - 0.5) * 0.08, 0.0, 1.0),
				"tout": OUT0 + (OUT1 - OUT0) * clampf(u + (rand([i, j, seed + 1]) - 0.5) * 0.08, 0.0, 1.0),
				"glint": jr_ < 0.3, "spin": rand([i, j, seed + 2]) * 3.0})
	var img := Image.create(lat.size(), 1, false, Image.FORMAT_RGBAF)
	for n in lat.size():
		var d: Dictionary = lat[n]
		img.set_pixel(n, 0, Color(d.cx, d.cy, d.tin, d.tout))
	var tex := asset("_lattice", img)
	screen("Diamonds", "diamond", {"lat": tex, "count": lat.size()})
	screen("Light", "diamond_light", {"lat": tex, "count": lat.size()})

	# glints: on a diamond's top point as it locks in, at its heart as it winks out
	var rows := frame_rows(func(_i: int, t: float) -> Array:
		var gl := []
		for d in lat:
			if not d.glint:
				continue
			var ki: float = (t - d.tin) / GROW
			var ko: float = (t - d.tout) / GROW
			if ko > 0.7 and ko < 1.5:
				gl.append([d, (ko - 0.7) / 0.8, 0.0])
			if ki <= 0.0 or ko >= 1.0:
				continue
			var hd: float = HD * ((1.0 - in_back(ko, 2.0)) if ko > 0.0 else out_back(minf(1.0, ki), 2.2))
			if hd < 0.5:
				continue
			if ki > 0.6 and ki < 1.8:
				gl.append([d, (ki - 0.6) / 1.2, hd])
		var out := []
		for g in gl:
			var u: float = g[1]
			if u <= 0.0 or u >= 1.0:
				continue
			var d: Dictionary = g[0]
			var y: float = d.cy - g[2] if g[2] != 0.0 else d.cy
			out.append(glint_m(d.cx, y, 9.0 * pow(sin(PI * u), 0.7), d.spin + u * 1.5, 6, 5))
		return out)
	marks("Glints", rows)
