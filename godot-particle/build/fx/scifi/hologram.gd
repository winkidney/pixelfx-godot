# reimagined-from: src/fx/scifi/hologram.js@e7d1ccd898099f842c303e7a8caa7b9a6aa8d211
# Hologram: A floor projector throws a cone of light holding a turning wireframe model: scanlines roll through it, a data ring circles it, and it flickers, tears and jitters.
# loop, 4.00 s, 112x104 canvas, origin [56.0, 92.0], backdrop ground
# The projector's steel drum and lens are the original's still pixels (port/props.py). The cone, the stage ring and
# the turning crystal are shaders keyed by the loop clock (fx/scifi/_hologram.gdshader: mode 1 the cone, mode 0 the
# model; the original's 3D pose, faces, sorted edges and dashed data ring worked out per pixel), every put() pixel
# going through the original's glitch: a data texture rolled here from its rand(seed, frame, ...) drops odd rows,
# tears bands sideways with a pink fringe and jolts the model. The data bits rising through the cone are particles
# placed where the original's cycle() puts them (_hologram_bits.gdshader); the light is _hologram_light.gdshader.
extends "res://build/fx/scifi/_scifi.gd"

const OY := -50.0
const RAD := 16.0
const S := 21
const GLITCHES := [[0.92, 0.12, 1.0], [2.55, 0.2, 1.4], [3.42, 0.06, 0.7]]


func make() -> void:
	var D: float = root.duration
	var NF := int(round(D * 30.0))
	prop()

	# each frame's glitch, as the original rolls it (its frame counter reads the drifting clock: frame_t)
	var data := Image.create(NF, 11, false, Image.FORMAT_RGBAF)
	for i in NF:
		var t := frame_t(i)
		var fr := int(floor(t * 30.0))
		var gl := 0.0
		for g in GLITCHES:
			if t >= g[0] and t < g[0] + g[1]:
				gl = maxf(gl, g[2])
		var flick: bool = gl > 0.0 and rand([S, fr]) < 0.5
		var cx := 0.0
		if gl > 0.0:
			cx = (-2.0 if rand([S, fr, 2]) < 0.5 else 2.0) * gl
		var cy := OY + 1.5 * sin(TAU * (t / D) * 2.0)
		data.set_pixel(i, 0, Color(gl, 1.0 if flick else 0.0, cx, 0.0))
		# the crystal's corners this frame, turning once a loop, tilted toward us
		var spin := TAU * (t / D)
		var tilt := 0.32
		for v in 8:
			# plain floats: a Vector3 would round them to single precision
			var px := 0.0
			var py := 1.45 if v == 0 else -1.45
			var pz := 0.0
			if v >= 2:
				var a := ((v - 2) / 6.0) * TAU
				px = cos(a) * 0.9
				py = 0.12
				pz = sin(a) * 0.9
			var x1 := px * cos(spin) + pz * sin(spin)
			var z1 := -px * sin(spin) + pz * cos(spin)
			var y2 := py * cos(tilt) - z1 * sin(tilt)
			var z2 := py * sin(tilt) + z1 * cos(tilt)
			data.set_pixel(i, 3 + v, Color(cx + x1 * RAD, cy - y2 * RAD, z2, 0.0))
		if gl > 0.0:
			for k in 2:
				var y0 := floorf(cy - RAD + rand([S, fr, k]) * RAD * 2.0)
				var h := 2.0 + floorf(rand([S, fr, k, 1]) * 4.0)
				var dx := floorf((rand([S, fr, k, 2]) - 0.5) * 10.0 * gl + 0.5)
				data.set_pixel(i, 1 + k, Color(y0, h, dx, 0.0))
	var dtex := asset("_glitch", data)
	var split := Color(meta.options.split)
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0

	var cone := shape("Cone", sh("hologram"), canvas, {"mode": 1, "t": 0.0, "data": dtex, "pal": C, "split_c": split}, {"at": mid})
	clock(cone)

	# data bits rising through the cone (the original's cycle(t, D, 18, seed + 1, ...))
	var bits := Image.create(18, 1, false, Image.FORMAT_RGBAF)
	for i in 18:
		var g := rng([S + 1, i, 911])
		var born := g.next() * D
		var L := g.range(0.8, 1.4)
		var r := rng([S + 1, i])
		var u := r.range(-0.8, 0.8)
		var white := r.chance(0.3)
		bits.set_pixel(i, 0, Color(born, L, u, 1.0 if white else 0.0))
	var bp := particles("Bits", {"amount": 18, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": "dot1", "preprocess": 1.0 / 60.0,
		"process_shader": "res://addons/pixelfx_particles/fx/scifi/_hologram_bits.gdshader",
		"process_params": {"t": 0.0, "data": dtex, "bits": asset("_bits", bits), "hi": Color.WHITE, "lo": C[5]}})
	bp.interpolate = false
	key(bp, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])

	var model := shape("Model", sh("hologram"), canvas, {"mode": 0, "t": 0.0, "data": dtex, "pal": C, "split_c": split}, {"at": mid})
	clock(model)
	var lit := shape("Light", sh("hologram_light"), canvas, {"t": 0.0, "data": dtex, "pal": C}, {"at": mid})
	clock(lit)
