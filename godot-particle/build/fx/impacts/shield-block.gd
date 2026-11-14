# reimagined-from: src/fx/impacts/shield-block.js@ff7cda3a61304a52d9b6ade8b6a45da95e28d9ab
# Shield block: A blow is caught on a half-dome of energy in front of the character: its diamond lattice flashes, a
# ripple runs over it, sparks glance off, then it blinks out cell by cell.
# The dome is a shader of its own (fx/impacts/_dome.gdshader: the original's lattice mapped on by longitude and
# latitude, glassy fill, rim, sheen, the two ripples and the cell-by-cell blink, worked out from the effect's clock),
# its far side behind the stand-in and its face in front, with its glitter on the light layer. The blow is the
# impacts' star on its two frames; the sparks glancing off and the motes lifting off as cells blink out are GPU
# particles from the original's draws on its physics (_sim.gdshader).
extends "res://build/fx/impacts/_impacts.gd"

const CX := 3.0
const RX := 28.0
const RY := 44.0
const GONE := 0.5
const LON := 1.18
const LAT := 0.5


func on_dome(lon: float, lat: float) -> Vector2:
	return Vector2(CX + RX * cos(lat) * sin(lon), -RY * sin(lat))


func make() -> void:
	R = JsRng.new(int(meta.options.seed))
	var S: PackedColorArray = root.ramps.sparks
	var W := Color.WHITE
	var D: float = meta.duration
	var h := on_dome(LON, LAT)
	var sp := spikes(8, 0.2, {"len": [5.0, 8.0], "w": [1.4, 1.9], "fwd": 1.2, "back": 0.3})
	var nA := atan2(-sin(LAT) / RY, (cos(LAT) * sin(LON)) / RX)
	for i in 14:
		var a := nA + R.range(-1.2, 0.9)
		var v := R.range(130, 300)
		var life := R.range(0.15, 0.42)
		spawn(SPARK, h.x + 1, h.y, cos(a) * v, sin(a) * v - 30, life, W, 1, R.range(0.01, 0.04) if i > 10 else 0.0)
	# as cells blink out, little motes of light lift off
	var t := 0.0
	while t < GONE + 0.38:
		t += DT
		if t > GONE and t < GONE + 0.38 and R.chance(0.5):
			var lon := R.range(0, PI / 2)
			var p := on_dome(lon, R.range(0.05, 1.4))
			var vx := R.range(-10, 10)
			var vy := -R.range(10, 40)
			var life := R.range(0.2, 0.36)
			var c: Color = C[6] if R.chance(0.5) else C[5]
			spawn(STAR, p.x, p.y, vx, vy, life, c, R.range(0.6, 1.4), 0.0, 0, t - DT)

	var U := "material:shader_parameter/"
	var box := Vector2(RX + 4, RY + 4)
	var at := Vector2(CX + RX / 2.0, -RY / 2.0).round()
	var pr := {"cx": CX, "rx": RX, "ry": RY, "grid": 3.4, "hit_at": Vector2(LON, LAT), "gone": GONE, "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6], "white": W}
	var far := pr.duplicate()
	far.back = 1.0
	var dome_back := shape("DomeBack", sh("dome"), box, far, {"at": at, "back": true})
	clock(dome_back)
	show(dome_back, 0.0, GONE + 0.56)
	var dome := shape("Dome", sh("dome"), box, pr, {"at": at})
	clock(dome)
	show(dome, 0.0, GONE + 0.56)
	var glit := shape("DomeGlitter", sh("dome_light"), box, {"cx": CX, "rx": RX, "ry": RY, "grid": 3.4, "hit_at": Vector2(LON, LAT), "gone": GONE, "color": C[4]}, {"at": at})
	clock(glit)
	show(glit, 0.0, GONE + 0.56)
	# where the dome meets the floor
	for f in 2:
		var fl := []
		for x in range(int(CX), int(CX + RX) + 1):
			fl.append([Vector2(x, 0), W if f == 0 else C[5], 0.6 + 0.4 * ((x - CX) / RX)])
		var foot := dots("Foot%d" % f, fl)
		keyf(foot, "modulate:a", func(tt: float) -> float: return 1.0 - smooth(GONE + 0.3, GONE + 0.55, tt), 0.0, D, 30.0)
		show(foot, 0.0 if f == 0 else 0.05, 0.05 if f == 0 else GONE + 0.55)

	hit_star("Star", h.round(), sp, 2.0, [[0.0, 1.0, 1.0, 1.0, [S[3], S[0], S[1], W]], [0.03, 1.25, 0.55, 1.0, [S[3], S[1], S[2], S[0]]], [0.06]])
	flush({"sparks": [S[0], S[1], S[2], S[3]]})

	glow_fn("DomeGlow", Vector2(CX + RX * 0.5, -RY * 0.45).round(), RY * 0.9, C[4],
		func(tt: float) -> float: return 0.2 * (1.0 - smooth(GONE, GONE + 0.55, tt)) + 0.35 * exp(-tt / 0.08), 0.0, D)
	light_add("Light", h.round(), 40, S[1], 0.7, 0.2)
	light_add("LightWhite", h.round(), 12, W, 0.7, 0.06)
