# reimagined-from: src/fx/arcane/magic-circle-cast.js@c95d98a086eae877fb894717d3c2931d8bcf7e58
# Magic circle cast: A circle draws itself on the floor, runes ignite one by one, it flashes, and a column of light fires up and breaks apart into glints.
# one-shot, 3.90 s, 200x220 canvas, origin [100.0, 192.0], backdrop ground
# The circle and its runes are a canvas shader drawn twice (fx/arcane/_castcircle.gdshader: far half behind, near half
# in front) that writes itself off the effect's clock; the pens are sparkles keyed along the original's paths, shedding
# glitter (emitters riding them); the column is a canvas shader (_column.gdshader: thread, beam, strands, pulses,
# halos, the break) with a run of light up it; two shock bands roll out across the floor at the flash (ring shader);
# light rushes in along the floor, sparks, stars and twinkles burst at the flash, the column throws off stars and
# breaks into glints (emitters on the original's beats).
extends "res://build/fx/arcane/_arcane.gd"

const R := 40.0
const R2 := 35.0
const RI := 24.0
const RR := 30.0
const SY := 0.3
const TOP := 192.0
const W := 11.0
const PEN := [0.04, 0.42]
const INNER := [0.3, 0.6]
const STAR := [0.52, 0.88]
const RUNES := [0.9, 1.3]
const FLASH := 1.52
const BREAK := 2.42
const GONE := 3.45


static func level(t: float) -> float:
	if t < RUNES[0]:
		return 0.55
	if t < FLASH:
		return 0.55 + 0.4 * smooth(RUNES[0], FLASH, t)
	if t < FLASH + 0.07:
		return 1.2
	if t < BREAK:
		return 0.92
	return 0.92 * (1.0 - smooth(BREAK, GONE, t))


func fade(t: float) -> float:
	return 1.0 - smooth(BREAK + 0.25, BREAK + 0.55, t)


func make() -> void:
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var D: float = root.duration

	# the floor glows under the circle as it burns
	var fl := glow("FloorGlow", R * 1.3 + 1, {"radius": R * 1.3, "color": C[4], "alpha": 0.0}, {"back": true})
	keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.28 * level(t) * smooth(PEN[0], PEN[1] + 0.2, t) if t < GONE else 0.0)
	for s in [-1, 1]:
		var side := glow("FloorSide%d" % (s + 1), R * 0.7 + 1, {"radius": R * 0.7, "color": C[5], "alpha": 0.0}, {"at": Vector2(s * R * 0.6, 1), "back": true})
		keyf(side, "material:shader_parameter/alpha", func(t: float): return 0.12 * level(t) * smooth(PEN[0], PEN[1] + 0.2, t) if t < GONE else 0.0)

	# shock bands rolling out across the floor at the flash (behind and in front)
	for spec in [[0.0, R * 0.6, R * 2.0, 6.0, 0.5], [0.08, R * 0.4, R * 1.4, 3.0, 0.4]]:
		for half in [[1.0, true, "Back"], [-1.0, false, "Front"]]:
			band("Shock%d%s" % [int(spec[0] * 100), half[2]], spec, half[0], half[1])

	# the column (behind the near half of the circle) and its light
	var strands := PackedVector3Array()
	for i in 9:
		strands.append(Vector3(rng.randf_range(-0.85, 0.85), rng.randf_range(0.04, 0.1), rng.randf_range(1, 3)))
	var col := shape("Column", arcane_shader("column"), Vector2(64, 202), {"dur": D, "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6],
		"white": Color.WHITE, "strands": strands}, {"at": Vector2(0, -96), "back": true})
	loop_t(col)
	var col_light := glow_line("ColumnLight", Vector2(0, 0), Vector2(0, -150), 43, C[5], 0.3, 8.0)
	keyf(col_light, "material:shader_parameter/alpha", func(t: float): return fade(t) if t >= FLASH and t <= BREAK + 0.6 else 0.0, 0.0, -1.0, 30.0)
	keyf(col_light, "material:shader_parameter/radius", func(t: float):
		var u := t - FLASH
		var brk := seg(t, BREAK, BREAK + 0.45)
		var w := W * (1.0 + 0.38 * exp(-u * 9.0)) if t < BREAK else W * (1.0 - out_cubic(brk) * 0.85)
		return w * 2.4 + 6.0, FLASH, BREAK + 0.6)
	keyf(col_light, "material:shader_parameter/b", func(t: float): return Vector2(0, -clampf(TOP * out_expo(clampf((t - FLASH) / 0.09, 0.0, 1.0)) - 40.0, 0.0, 150.0)), FLASH, FLASH + 0.2)
	var foot := glow("ColumnFoot", 35, {"radius": 34, "color": C[6], "alpha": 0.0}, {"at": Vector2(0, -4)})
	keyf(foot, "material:shader_parameter/alpha", func(t: float):
		if t < FLASH - 0.22 or t > BREAK + 0.6:
			return 0.0
		if t < FLASH:
			return 0.0
		return 0.45 * fade(t))
	var wide := glow("ColumnWide", 71, {"radius": 70, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -60)})
	keyf(wide, "material:shader_parameter/alpha", func(t: float): return 0.25 * fade(t) if t >= FLASH and t <= BREAK + 0.6 else 0.0)
	# the thread's light: its tip and its foot
	var tip := glow("ThreadTip", 10, {"radius": 9, "color": C[6], "alpha": 0.0}, {"at": Vector2(0, 0)})
	keyf(tip, "position", func(t: float): return Vector2(0, -(TOP - 10) * out_cubic(smooth(FLASH - 0.22, FLASH - 0.04, t))), FLASH - 0.22, FLASH)
	keyf(tip, "material:shader_parameter/alpha", func(t: float): return 0.5 * smooth(FLASH - 0.22, FLASH - 0.04, t) if t < FLASH else 0.0, FLASH - 0.25, FLASH + 0.04)
	var tfoot := glow("ThreadFoot", 25, {"radius": 24, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -6)})
	keyf(tfoot, "material:shader_parameter/alpha", func(t: float): return 0.4 * smooth(FLASH - 0.22, FLASH - 0.04, t) if t < FLASH else 0.0, FLASH - 0.25, FLASH + 0.04)

	# the circle and its runes
	var sz := Vector2(R * 2 + 8, 44)
	for half in [[1.0, true, "CircleBack"], [0.0, false, "CircleFront"]]:
		var c := shape(half[2], arcane_shader("castcircle"), sz, {"dur": D, "far": half[0], "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6],
			"white": Color.WHITE}, {"at": Vector2(0, -8), "back": half[1]})
		loop_t(c)
	rune_light()

	pens()
	bursts(rng)

	# the flash: a big flare and white light
	var fl2 := flare("Flash", Vector2(0, -8), 34, 1.0)
	keyf(fl2, "material:shader_parameter/len", func(t: float): return 34.0 * pow(1.0 - seg(t, FLASH, FLASH + 0.24), 1.5), FLASH, FLASH + 0.24)
	keyf(fl2, "material:shader_parameter/k", func(t: float): return 1.0 - seg(t, FLASH, FLASH + 0.24), FLASH, FLASH + 0.24)
	show(fl2, FLASH, FLASH + 0.24)
	var white := glow("FlashLight", 57, {"radius": 56, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -26)})
	keyf(white, "material:shader_parameter/alpha", func(t: float): return 0.5 * (1.0 - seg(t, FLASH, FLASH + 0.24)) if t >= FLASH else 0.0, FLASH - 0.04, FLASH + 0.27)
	var big := glow("FlashPool", 105, {"radius": 104, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -56)})
	keyf(big, "material:shader_parameter/radius", func(t: float): return 104.0 * (0.55 + 0.45 * (1.0 - seg(t, FLASH, FLASH + 0.6))), FLASH, FLASH + 0.6)
	keyf(big, "material:shader_parameter/alpha", func(t: float): return 0.9 * pow(1.0 - seg(t, FLASH, FLASH + 0.6), 2.0) if t >= FLASH else 0.0, FLASH - 0.04, FLASH + 0.6)
	var hot := glow("FlashHot", 37, {"radius": 36, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -5)})
	keyf(hot, "material:shader_parameter/alpha", func(t: float): return 0.8 * pow(1.0 - seg(t, FLASH, FLASH + 0.14), 2.0) if t >= FLASH else 0.0, FLASH - 0.04, FLASH + 0.15)


func band(name: String, spec: Array, side: float, back: bool) -> void:
	var d0: float = FLASH + spec[0]
	var dur: float = spec[4]
	var r0: float = spec[1]
	var r1: float = spec[2]
	var th: float = spec[3]
	for layer in [["Rim", Color.WHITE, 0.0, 0.0], ["Body", C[6], 1.0, 0.35], ["Core", C[5], 0.0, 0.35]]:
		var rr := ring(name + layer[0], r1 + 2, {"radius": r0, "thickness": 1, "squash": SY, "color": layer[1], "side": side}, {"back": back})
		var kind: String = layer[0]
		keyf(rr, "material:shader_parameter/radius", func(t: float):
			var k := (t - d0) / dur
			var r := r0 + (r1 - r0) * out_cubic(k)
			var w := maxf(1.0, th * (1.0 - k))
			if kind == "Rim":
				return r
			if kind == "Body":
				return r - 1.0
			return r - 1.0 - w * 0.3, d0, d0 + dur)
		keyf(rr, "material:shader_parameter/thickness", func(t: float):
			var k := (t - d0) / dur
			var w := maxf(1.0, th * (1.0 - k))
			if kind == "Rim":
				return 1.0
			if kind == "Body":
				return maxf(0.5, w * 0.3)
			return maxf(0.5, w * 0.7 - 1.0), d0, d0 + dur)
		keyf(rr, "material:shader_parameter/alpha", func(t: float):
			var k := (t - d0) / dur
			var w := maxf(1.0, th * (1.0 - k))
			var a := clampf(1.15 - k, 0.0, 1.0)
			if kind == "Core":
				return a * 0.75 if w * 0.7 - 1.0 > 0.3 else 0.0
			if kind == "Body":
				return a if w > 1.6 else 0.0
			return a, d0, d0 + dur)
		show(rr, d0, d0 + dur)


## Light over each rune as it burns, and a little at its foot.
func rune_light() -> void:
	for k in 8:
		var g := -PI / 2 + (k + 0.5) * TAU / 8.0
		var x := cos(g) * RR
		var y0 := sin(g) * RR * SY
		var lit_at: float = RUNES[0] + k * (RUNES[1] - RUNES[0]) / 7.0
		var out_at := BREAK + 0.2 + k * 0.08
		var inner_t: float = INNER[0] + fposmod(g + PI / 2, TAU) / TAU * (INNER[1] - INNER[0])
		var top := glow("RuneLight%d" % k, 9, {"radius": 8, "color": C[5], "alpha": 0.0}, {"at": Vector2(x, y0 - 3)})
		keyf(top, "position", func(t: float):
			var lit := t - lit_at
			var rise := 3.0 * out_back(clampf(lit / 0.2, 0.0, 1.0), 2.4) if lit >= 0.0 else 0.0
			return Vector2(x, y0 - 3.0 - rise), lit_at, lit_at + 0.25)
		keyf(top, "material:shader_parameter/alpha", func(t: float):
			if t < lit_at or t < inner_t:
				return 0.0
			var gone := clampf((t - out_at) / 0.25, 0.0, 1.0)
			return (0.3 + 0.3 * level(t)) * (1.0 - gone), lit_at - 0.04, out_at + 0.3)
		var low := glow("RuneFoot%d" % k, 7, {"radius": 6, "color": C[4], "alpha": 0.0}, {"at": Vector2(x, y0)})
		keyf(low, "material:shader_parameter/alpha", func(t: float):
			if t < lit_at:
				return 0.0
			return 0.2 * (1.0 - clampf((t - out_at) / 0.25, 0.0, 1.0)), lit_at - 0.04, out_at + 0.3)


## The pens: white points running round, writing light, shedding glitter.
func pens() -> void:
	var paths := []
	for s in [-1, 1]:
		paths.append([PEN[0], PEN[1], func(t: float):
			var g: float = PI / 2 + s * (t - PEN[0]) / (PEN[1] - PEN[0]) * PI
			return Vector2(cos(g) * R, sin(g) * R * SY)])
	paths.append([INNER[0], INNER[1], func(t: float):
		var g: float = -PI / 2 + (t - INNER[0]) / (INNER[1] - INNER[0]) * TAU
		return Vector2(cos(g) * RI, sin(g) * RI * SY)])
	for tr in [-PI / 2, PI / 2]:
		var a0: float = tr
		paths.append([STAR[0], STAR[1], func(t: float):
			var e := clampf((t - STAR[0]) / (STAR[1] - STAR[0]) * 3.0, 0.0, 2.9999)
			var k := floori(e)
			var s := e - k
			var p0 := Vector2(cos(a0 + k * TAU / 3), sin(a0 + k * TAU / 3)) * RI
			var p1 := Vector2(cos(a0 + (k + 1) * TAU / 3), sin(a0 + (k + 1) * TAU / 3)) * RI
			var q := p0.lerp(p1, s)
			return Vector2(q.x, q.y * SY)])
	var i := 0
	for P in paths:
		var t0: float = P[0]
		var t1: float = P[1]
		var f: Callable = P[2]
		var pen := sparkle("Pen%d" % i, f.call(t0), 2, C[6], C[5])
		keyf(pen, "position", func(t: float): return f.call(t).floor() + Vector2(0.5, 0.5), t0, t1, 60.0, "nearest")
		show(pen, t0, t1)
		var pl := glow("PenLight%d" % i, 8, {"radius": 7, "color": C[6], "alpha": 0.45}, {"at": f.call(t0)})
		keyf(pl, "position", f, t0, t1, 60.0)
		show(pl, t0, t1)
		var gl := particles("Glitter%d" % i, {"at": f.call(t0) + Vector2(0, -1), "amount": 8, "lifetime": 0.55, "texture": "dot1", "emitting": false,
			"spread": 25, "dir": -90, "speed": [10, 32], "damping": [20, 40], "gravity": Vector2(0, -12), "color": C[6],
			"alpha_curve": [[0, 1], [0.6, 1], [1, 0]], "turbulence": {"strength": 2.0, "scale": 2.0, "influence": [0.01, 0.02]}})
		life_rand(gl, 0.5)
		keyf(gl, "position", func(t: float): return f.call(t) + Vector2(0, -1), t0, t1, 60.0)
		emit(gl, t0, t1)
		i += 1


func bursts(rng: RandomNumberGenerator) -> void:
	var cols := gradient([Color.WHITE, C[6], C[5]])
	# light rushing in along the floor to the heart of the circle
	var pts := PackedVector2Array()
	for i in 120:
		var g := rng.randf() * TAU
		var d := rng.randf_range(R * 0.7, R * 1.1)
		pts.append(Vector2(cos(g) * d, sin(g) * d * SY + 1))
	var rush := particles("Rush", {"at": Vector2(0, -2), "amount": 18, "lifetime": 0.24, "texture": "streak6", "align": true, "emitting": false,
		"emit": {"points": pts}, "radial": [-900, -600], "initial": gradient([C[6], C[5]]), "ramp": gradient([C[5], C[6], Color.WHITE], [0.0, 0.5, 0.85])})
	radial_speed(rush, -40, -20)
	life_rand(rush, 0.33)
	emit(rush, RUNES[1] - 0.1, FLASH - 0.05)

	# glints popping along the burning circle
	var ring_pts := PackedVector2Array()
	for i in 90:
		var g := rng.randf() * TAU
		var r: float = [R, R2, RI][i % 3]
		ring_pts.append(Vector2(cos(g) * r, sin(g) * r * SY - 0.5))
	var glints := particles("Glints", {"amount": 6, "lifetime": 0.45, "texture": "plus3", "emitting": false, "emit": {"points": ring_pts},
		"dir": -90, "speed": [2, 8], "initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.5, 1], [1, 0]]})
	life_rand(glints, 0.44)
	emit(glints, RUNES[0], BREAK + 0.2)

	# the flash: sparks thrown out low along the floor, stars thrown up, twinkles flung out
	for s in [-1, 1]:
		var sp := particles("Sparks%s" % ("L" if s < 0 else "R"), {"at": Vector2(s * R * 0.25, -1), "amount": 18, "lifetime": 0.7, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "streak4", "align": true, "emit": {"box": Vector2(R * 0.25, 0.5)},
			"dir": -90 + s * 50, "spread": 32, "speed": [90, 240], "damping": [150, 300], "gravity": Vector2(0, 428),
			"ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
		life_rand(sp, 0.64)
		emit(sp, FLASH)
		var tw := particles("Twinkles%s" % ("L" if s < 0 else "R"), {"at": Vector2(s * 7, -2.5), "amount": 17, "lifetime": 0.95, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(7, 1.5)}, "dir": -90 + s * 65, "spread": 22,
			"speed": [50, 160], "damping": [70, 140], "initial": gradient([Color.WHITE, C[6], C[6], C[5]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
		life_rand(tw, 0.55)
		emit(tw, FLASH)
	var up := particles("Stars", {"at": Vector2(0, -3.5), "amount": 26, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "plus3", "emit": {"box": Vector2(R, 2.5)}, "dir": -90, "spread": 12, "speed": [40, 130], "damping": [40, 90],
		"initial": cols, "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	life_rand(up, 0.55)
	emit(up, FLASH)

	# the column throws off stars and light streams up inside it
	var cs := particles("ColumnStars", {"at": Vector2(0, -60), "amount": 50, "lifetime": 1.1, "texture": "dot1", "emitting": false,
		"emit": {"box": Vector2(W * 1.5, 60)}, "dir": -90, "spread": 8, "speed": [30, 85], "damping": [40, 80], "initial": cols,
		"alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	life_rand(cs, 0.55)
	emit(cs, FLASH, BREAK)
	var cs2 := particles("ColumnCrosses", {"at": Vector2(0, -60), "amount": 14, "lifetime": 1.1, "texture": "plus3", "emitting": false,
		"emit": {"box": Vector2(W * 1.5, 60)}, "dir": -90, "spread": 8, "speed": [30, 85], "damping": [40, 80], "initial": cols,
		"alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	life_rand(cs2, 0.55)
	emit(cs2, FLASH, BREAK)
	var stream := particles("Stream", {"at": Vector2(0, -25), "amount": 14, "lifetime": 0.35, "texture": "streak8", "align": true, "emitting": false,
		"emit": {"box": Vector2(W * 0.8, 25)}, "dir": -90, "speed": [160, 300], "initial": gradient([Color.WHITE, C[6]])})
	life_rand(stream, 0.43)
	emit(stream, FLASH, BREAK)

	# it breaks apart into glints that twinkle as they drift up
	var shards := particles("Shards", {"at": Vector2(0, -78), "amount": 46, "lifetime": 1.15, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "dot1", "emit": {"box": Vector2(W * 0.9, 76)}, "dir": -90, "spread": 20, "speed": [8, 40], "damping": [6, 20],
		"initial": gradient([Color.WHITE, Color.WHITE, C[6], C[5]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	life_rand(shards, 0.55)
	emit(shards, BREAK)
	var shards2 := particles("ShardCrosses", {"at": Vector2(0, -78), "amount": 16, "lifetime": 1.15, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "plus3", "emit": {"box": Vector2(W * 0.9, 76)}, "dir": -90, "spread": 20, "speed": [8, 40], "damping": [6, 20],
		"initial": gradient([Color.WHITE, Color.WHITE, C[6], C[5]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	life_rand(shards2, 0.55)
	emit(shards2, BREAK)
	var drift := particles("Drift", {"at": Vector2(0, -76), "amount": 60, "lifetime": 0.9, "texture": "dot1", "emitting": false,
		"emit": {"box": Vector2(W * 0.7, 74)}, "dir": -90, "spread": 15, "speed": [10, 50], "damping": [10, 30], "initial": cols,
		"alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	life_rand(drift, 0.55)
	emit(drift, BREAK, BREAK + 0.4)
	# each rune goes out in a little puff of glints
	for k in 8:
		var g := -PI / 2 + (k + 0.5) * TAU / 8.0
		var puff := particles("Puff%d" % k, {"at": Vector2(cos(g) * RR, sin(g) * RR * SY - 5), "amount": 4, "lifetime": 0.55, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(2, 2)}, "dir": -90, "spread": 30,
			"speed": [10, 40], "damping": [15, 30], "initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
		life_rand(puff, 0.45)
		emit(puff, BREAK + 0.2 + k * 0.08)
