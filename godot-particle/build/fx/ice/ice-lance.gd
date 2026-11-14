# reimagined-from: src/fx/ice/ice-lance.js@f9541cde4698d2c8270776088b0bf2d85c44cd6c
# Ice lance: a faceted ice spear flying right: a light pulse runs through its core, rings of cold air shear off the
# tip, frost peels off into a wake and crystals shed behind it.
# The spear and its three fletching shards are shaders (the spear's row-by-row shading, the ice blade), the pulse and
# glint keyed along it; the wake is a translucent ribbon shader rippling with the loop; frost puffs, tumbling
# crystals and speed lines are emitters streaming left; the shearing rings are dotted ellipses keyed off the
# original's three-a-loop cycle; light is glow lines and glows.
extends "res://build/fx/ice/_ice.gd"

const L := 40.0


func make() -> void:
	var D: float = root.duration
	# the wake and the light down its length
	var wake := shape("Wake", load(ICE + "_wake.gdshader"), Vector2(2 * (L + 104), 26), {"start": -L + 4.0, "reach": 104.0,
		"heart": C[6], "body": C[5], "edge": C[4], "alpha": 0.7, "translucent": true}, {"at": Vector2(0, 0)})
	loop_t(wake)
	glow_line("WakeLight", Vector2(-L - 60, 0), Vector2(0, 0), 14, C[4], 0.22)

	# frost peeling off the shaft into soft puffs left behind
	var puffs := particles("Puffs", {"layer": "soft", "at": Vector2(-(L + 6) / 2.0, 0), "amount": 8, "lifetime": 0.45, "randomness": 0.3,
		"texture": tex("puff16"), "emit": {"box": Vector2((L - 10) / 2.0, 2.5)}, "dir": 180, "spread": 9, "speed": [150, 230],
		"damping": [230, 300], "scale_curve": [[0, 0.15], [1, 0.85]],
		"ramp": gradient([Color(C[6], 0.5), Color(C[5], 0.33), Color(C[5], 0.17), Color(C[5], 0.05), Color(C[5], 0.0)], [0.0, 0.3, 0.55, 0.8, 1.0], true)})
	puffs.process_material.lifetime_randomness = 0.3
	lit_copy(puffs, "PuffLight", "glow32", Color(C[4], 0.1), [[0, 1], [1, 0]])

	# crystals shed along the way: short tumbling shards
	particles("Crystals", {"at": Vector2(-(L + 6) / 2.0, 0), "amount": 6, "lifetime": 0.5, "randomness": 0.3, "texture": "streak4",
		"emit": {"box": Vector2((L - 6) / 2.0, 3)}, "dir": 180, "spread": 7, "speed": [170, 260], "damping": [150, 220],
		"gravity": Vector2(0, 60), "angle": [0, 360], "spin": [-1000, 1000], "color": C[5],
		"alpha_curve": [[0, 1], [0.85, 1], [0.86, 0], [0.9, 1], [0.93, 0], [0.96, 1], [1, 0]]})

	# speed lines: the air streaming past above and below
	for side in [-1, 1]:
		for k in 2:
			particles("Speed%s%d" % ["Up" if side < 0 else "Down", k], {"at": Vector2(-10, side * 8.5), "amount": 1, "lifetime": 0.21,
				"randomness": 0.4, "texture": tex("fade8" if k == 0 else "fade16"), "align": true, "emit": {"box": Vector2(10, 4.5)},
				"dir": 180, "speed": [280, 380], "ramp": gradient([Color(C[6], 0.9), Color(C[4], 0.75), Color(C[4], 0.45), Color(C[4], 0.2)], [0.0, 0.25, 0.55, 0.8])})

	# rings of cold air shearing off the point and sliding back along the shaft
	for i in 3:
		var ring_node := shape("Shear%d" % i, load(ICE + "_shear.gdshader"), Vector2(32, 32), {"rx": 1.2, "ry": 4.5, "near": Color.WHITE,
			"far": C[5]}, {"at": Vector2(-4, 0)})
		var light_ring := glow("ShearLight%d" % i, 18, {"radius": 3.4, "thickness": 3.0, "color": C[5], "alpha": 0.0}, {"at": Vector2(-4, 0)})
		var pos := []
		var rx := []
		var ry := []
		var cut := []
		var near := []
		var far := []
		var vis := []
		var gr := []
		var ga := []
		var n := int(roundf(D * FPS))
		for f in n + 1:
			var t := f / FPS
			var q := fmod(t / D * 3.0 + i / 3.0, 1.0)
			var x := -4.0 - q * (L + 20.0)
			pos.append([t, Vector2(floorf(x), 0)])
			rx.append([t, 1.2 + q * 2.6])
			ry.append([t, 4.5 + q * 8.0])
			cut.append([t, -L - 2.0 - floorf(x)])
			near.append([t, Color.WHITE if q < 0.35 else C[6]])
			far.append([t, C[5] if q < 0.4 else C[4]])
			vis.append([t, q <= 0.8])
			gr.append([t, (4.5 + q * 8.0) * 0.75])
			ga.append([t, 0.14 * (1.0 - q) if q <= 0.8 else 0.0])
		key(ring_node, "position", pos, "nearest")
		key(ring_node, "material:shader_parameter/rx", rx, "nearest")
		key(ring_node, "material:shader_parameter/ry", ry, "nearest")
		key(ring_node, "material:shader_parameter/cut", cut, "nearest")
		key(ring_node, "material:shader_parameter/near", near, "nearest")
		key(ring_node, "material:shader_parameter/far", far, "nearest")
		key(ring_node, "visible", vis, "nearest")
		key(light_ring, "position", pos, "nearest")
		key(light_ring, "material:shader_parameter/radius", gr, "nearest")
		key(light_ring, "material:shader_parameter/alpha", ga, "nearest")

	# the ice fletching at the back: three shards fanning out behind the shaft
	for b in [[-1.0, 10.0, 4.0], [1.0, 9.0, 4.0], [-0.2, 6.0, 3.0]]:
		var base := Vector2(-L + 3, b[0] * 1.5)
		var tip := Vector2(-L + 3 - b[1], b[0] * (2.0 + b[1] * 0.5))
		blade("Fletch%d" % int(b[1]), base, tip, b[2], {"ymax": 100.0})

	# the spear, its pulse and glint
	var spear := shape("Spear", load(ICE + "_spear.gdshader"), Vector2(2 * (L + 2), 14), {"span": L, "ramp": ramp("palette", {"stops": 8})})
	var pulse := glow("PulseLight", 10, {"radius": 8, "color": C[6], "alpha": 0.3})
	var pk := []
	var gk := []
	var lk := []
	var n2 := int(roundf(D * FPS))
	for f in n2 + 1:
		var t := f / FPS
		var ph := t / D
		var px := -L + fmod(ph * 2.0, 1.0) * (L + 6.0)
		pk.append([t, px])
		gk.append([t, -fmod(ph * 2.0 + 0.5, 1.0) * L * 1.2])
		lk.append([t, Vector2(roundf(px), 0)])
	key(spear, "material:shader_parameter/pulse", pk, "nearest")
	key(spear, "material:shader_parameter/glint", gk, "nearest")
	key(pulse, "position", lk, "nearest")
	glow_line("ShaftLight", Vector2(-L, 0), Vector2(0, 0), 10, C[4], 0.1)
	glow("TipLight", 10, {"radius": 8, "color": Color.WHITE, "alpha": 0.4})
	glow("BodyLight", 32, {"radius": 30, "color": C[3], "alpha": 0.16}, {"at": Vector2(-L * 0.4, 0)})
