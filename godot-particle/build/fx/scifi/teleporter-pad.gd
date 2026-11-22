# reimagined-from: src/fx/scifi/teleporter-pad.js@17aa24bb28e13edf7a8a429b3a5aba7e5cad8eee
# Teleporter pad: A steel pad glows on the floor, its rings rippling outward; a soft column of light rises off it and rings of light lift away, sparkles drifting up through them.
# loop, 2.40 s, 96x104 canvas, origin [48.0, 92.0], backdrop ground
# The pad (steel drum, lit rim, a well of light whose rings roll outward, chasing emitters), the soft column and the
# rings lifting off it are shaders keyed by the loop clock (fx/scifi/_teleporter.gdshader, modes 0..2; light in
# _teleporter_light.gdshader). The streaks of light drawn up the column are particles placed where the original's
# cycle() puts them (_vstreak.gdshader, coloured along their length by _vline.gdshader); the motes and sparkles
# drifting up through it are the original's own Ghosts (_ghost.gdshader).
extends "res://build/fx/scifi/_scifi.gd"

const RX := 31.0
const RY := 7.0
const PY := -3.0
const IN := 0.78
const HIGH := -84.0


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var H: PackedColorArray = fit(root.ramps.metal, 6)
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0
	var W := RX * IN

	var pad := shape("Pad", sh("teleporter"), canvas, {"mode": 0, "t": 0.0, "pal": C, "metal": H}, {"at": mid})
	clock(pad)
	var col := shape("Column", sh("teleporter"), canvas, {"mode": 1, "t": 0.0, "pal": C, "metal": H, "translucent": true}, {"at": mid})
	clock(col)

	# streaks of light drawn up the column (the original's cycle(t, D, 30, seed + 3, ...))
	var bits := Image.create(30, 1, false, Image.FORMAT_RGBAF)
	for i in 30:
		var g := rng([S + 3, i, 911])
		var born := g.next() * D
		var L := g.range(0.6, 1.1)
		var r := rng([S + 3, i])
		bits.set_pixel(i, 0, Color(born, L, r.range(-0.9, 0.9), 0.0))
	var sp := particles("Streaks", {"amount": 30, "lifetime": D, "explosiveness": 1.0, "local": true, "texture": "dot1", "preprocess": 1.0 / 60.0,
		"process_shader": "res://addons/pixelfx_particles/fx/scifi/_vstreak.gdshader",
		"process_params": {"t": 0.0, "period": D, "bits": asset("_streaks", bits), "y0": PY - 2.0, "y1": HIGH + 10.0, "pw": 1.0,
			"l0": 3.0, "l1": 7.0, "fade": 1.2, "width": W}})
	sp.interpolate = false
	var vm := ShaderMaterial.new()
	vm.shader = sh("vline")
	vm.set_shader_parameter("head", C[6])
	vm.set_shader_parameter("tail", C[4])
	vm.set_shader_parameter("split", 0.3)
	sp.material = vm
	key(sp, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])

	var rings := shape("Rings", sh("teleporter"), canvas, {"mode": 2, "t": 0.0, "pal": C, "metal": H}, {"at": mid})
	clock(rings)
	# each ring's progress and colour step, on the original's clock (frame_t), so a ring born on a frame shows when
	# the original's does
	var ring_k := func(tt: float) -> Vector4:
		var v := Vector4(2, 2, 2, 2)
		for i in 4:
			var k := since(tt, (i / 4.0) * D, D) / 1.25
			v[i] = k if k < 1.0 else 2.0
		return v
	frames_key(rings, "material:shader_parameter/ring_k", ring_k)
	frames_key(rings, "material:shader_parameter/ring_c", func(tt: float) -> Vector4:
		var v := Vector4.ZERO
		for i in 4:
			var k := since(tt, (i / 4.0) * D, D) / 1.25
			v[i] = 0.0 if k < 0.12 else 1.0 if k < 0.4 else 2.0 if k < 0.65 else 3.0 if k < 0.85 else 4.0
		return v)

	# motes and sparkles drifting up through the column
	ghosts_begin(D)
	var rn := JsRng.new(S)
	for i in 40:
		var a := rn.range(0, TAU)
		var r := sqrt(rn.next()) * RX * IN * 0.9
		var star := i % 3 == 0
		var born := rn.range(0, D)
		var vx := rn.range(-4, 4)
		var vy := -rn.range(30, 75)
		var life := rn.range(0.7, 1.3)
		var c: Color = rn.pick([Color.WHITE, C[6], C[5]])
		var sz := rn.range(1.8, 3.4) if star else rn.range(0.6, 1.2)
		ghost(born, STAR if star else MOTE, cos(a) * r, PY + sin(a) * r * (RY / RX), vx, vy, life, c, sz)
	ghosts({"box": [-46, -90, 46, 10]})

	var lit := shape("Light", sh("teleporter_light"), canvas, {"t": 0.0, "pal": C}, {"at": mid})
	clock(lit)
