# reimagined-from: src/fx/scifi/laser-grid.js@88ba1f3225d30dea6ec6ed64690e7eb7a4cf94bb
# Laser grid: Security lasers between two steel posts: red beams slide and scissor across, dust and haze light up only where they cut through, and the floor sweepers scorch and spark.
# loop, 3.00 s, 128x84 canvas, origin [64.0, 76.0], backdrop ground
# A shader keyed by the loop clock draws the grid in the original's order (fx/scifi/_laser_grid.gdshader: mode 0 the
# haze lit only near a beam, translucent, its own tileFbm noise; mode 1 the scorch, the posts with their carriages
# and glinting grooves, the beams' red bodies and white cores with running dashes, the crossings, the hot spots);
# its light is _laser_grid_light.gdshader. The dust is 90 particles hanging in the air that show only where a beam
# passes (_laser_motes.gdshader); the sparks and smoke the sweepers kick up are the original's own Ghosts.
extends "res://build/fx/scifi/_scifi.gd"

const IN := 44.0


func sweep_x(t: float, s: float) -> float:
	return s * (34.0 - 68.0 * (0.5 - 0.5 * cos(TAU * (t / root.duration) + (0.0 if s > 0.0 else 1.9))))


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var H: PackedColorArray = fit(root.ramps.metal, 6)
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var haze := shape("Haze", sh("laser_grid"), canvas, {"mode": 0, "t": 0.0, "seed": S, "pal": C, "metal": H, "translucent": true}, {"at": mid})
	var grid := shape("Grid", sh("laser_grid"), canvas, {"mode": 1, "t": 0.0, "seed": S, "pal": C, "metal": H}, {"at": mid})
	clock(haze)
	clock(grid)

	var mimg := Image.create(90, 1, false, Image.FORMAT_RGBAF)
	for i in 90:
		mimg.set_pixel(i, 0, Color(rand([S, i]), rand([S, i, 1]), 0.0, 0.0))
	var mtex := asset("_motes", mimg)
	var mp := particles("Dust", {"amount": 90, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": "dot1", "preprocess": 1.0 / 60.0,
		"process_shader": "res://addons/pixelfx_particles/fx/scifi/_laser_motes.gdshader",
		"process_params": {"t": 0.0, "motes": mtex, "hi": Color.WHITE, "lo": C[6]}})
	mp.interpolate = false
	key(mp, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])

	# the sweepers kick up sparks and wisps of smoke where they burn the floor
	ghosts_begin(D)
	var rn := JsRng.new(S)
	for i in 36:
		var tb := (i / 36.0) * D + rn.range(0, 0.05)
		var s := 1.0 if i % 2 else -1.0
		var x := sweep_x(tb, s)
		var dir := signf(sweep_x(tb + 0.02, s) - x)
		if dir == 0.0:
			dir = 1.0
		var a := -PI / 2.0 - dir * rn.range(0.2, 1.1)
		var vx := cos(a) * rn.range(50, 140)
		var vy := sin(a) * rn.range(50, 140)
		ghost(tb, SPARK, x, -1, vx, vy, rn.range(0.2, 0.45))
		if i % 4 == 0:
			var svx := rn.range(-4, 4)
			var svy := -rn.range(6, 14)
			var sl := rn.range(0.8, 1.2)
			ghost(tb, SMOKE, x, -2, svx, svy, sl, Color("#3a2a30"), rn.range(1.6, 2.4))
	ghosts({"sparks": [Color.WHITE, C[6], C[4], C[3]], "floor": 0.0, "box": [-62, -80, 62, 7], "back": false})

	var lit := shape("Light", sh("laser_grid_light"), canvas, {"t": 0.0, "seed": S, "motes": mtex, "pal": C}, {"at": mid})
	clock(lit)
