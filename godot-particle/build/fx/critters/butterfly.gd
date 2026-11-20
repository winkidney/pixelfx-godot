# reimagined-from: src/fx/critters/butterfly.js
# Butterfly: An iridescent butterfly wanders a loop in bursts of quick wingbeats and open-winged glides, its veined,
# spotted wings shedding a twinkling trail of glowing dust.
# loop, 3.20 s, 128x88 canvas, origin [64, 44], backdrop sky
# The butterfly is the original's own body cells (critter()); the dust it sheds is 56 particles placed frame by frame
# on the original's own cycle (where each was shaken off, drifting down, twinkling), each with its glow, and every
# ninth flaring into a sparkle; the shine round the wings is a keyed light that brightens as they open.
extends "res://build/fx/critters/_critters.gd"

const BURSTS := [[0.0, 0.95], [1.5, 2.55]]


func flapping(t: float) -> bool:
	for b in BURSTS:
		if t >= b[0] and t < b[1]:
			return true
	return false


func fold(t: float) -> float:
	t = jmod(t, D)
	for b in BURSTS:
		if t >= b[0] and t < b[1]:
			var n := roundf((b[1] - b[0]) * 6.3)
			var ph: float = ((t - b[0]) / (b[1] - b[0])) * n
			return 0.14 + 0.86 * (0.5 + 0.5 * cos(ph * TAU))
	return 1.0


func at(t: float) -> Vector2:
	t = jmod(t, D)
	var a := (t / D) * TAU
	var lift := 0.0
	for b in BURSTS:
		lift += -3.0 * sin(PI * clampf((t - b[0]) / (b[1] - b[0]), 0.0, 1.0))
	return Vector2(30.0 * sin(a) + 6.0 * sin(3.0 * a), 12.0 * sin(2.0 * a + 0.4) + lift)


func make() -> void:
	var SP: PackedColorArray = root.ramps.spots
	var dust := []
	var stars := []
	for f in NF:
		var t := ft(f)
		var row := []
		var srow := []
		row.resize(56)
		for i in 7:
			srow += sparkle_es(0, 0, 0, 8, 8, 0.0, 2)
		cycle(t, D, 56, 8, func(g: JsRng) -> float: return g.range(1.0, 1.8), func(age: float, L: float, r: JsRng, i: int) -> void:
			var born := jmod(t - age, D)
			var B := at(born)
			var k := age / L
			if not flapping(born) and r.chance(0.45):
				return
			var x := B.x + r.range(-9, 9) + sin(age * 3.0 + i) * 1.5
			var y := B.y + r.range(-4, 8) + 7.0 * age + 3.0 * age * age
			var tw := 0.5 + 0.5 * sin(age * 11.0 + i * 2.1)
			var a := minf(1.0, k * 8.0) * (1.0 - k)
			var c: Variant = 6 if tw > 0.7 else (SP[2] if r.chance(0.3) else 5)
			row[i] = dot_e(x, y, c, a * 1.2, [x, y, 6.0, 4, 0.5 * a * tw])
			if i % 9 == 0 and tw > 0.85 and k < 0.5:
				var s := sparkle_es(x, y, 2, 6, 5, 0.3 * a, 2)
				for j in s.size():
					srow[(i / 9) * s.size() + j] = s[j])
		dust.append(row)
		stars.append(srow)
	table("Dust", K_DOT, dust)
	table("Sparkles", K_DOT, stars)
	critter()
	glows("Shine", func(i: int, t: float) -> Array:
		var S := at(t)
		var w := fold(t)
		return [{"c": C[4], "p": S, "r": 38.0, "k": 0.16 + 0.14 * w}, {"c": C[5], "p": S, "r": 12.0, "k": 0.12 + 0.1 * w}])
