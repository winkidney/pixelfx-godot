# reimagined-from: src/fx/explosions/small-explosion.js@64b98a2976bf623829fe4bc9bdfc2b4ae894672a
# Explosion: a ground blast: a white flash and shock rings, fire that cools into a rolling smoke column, sparks,
# burning brands that land and keep burning, tumbling rocks and a glowing scorch.
# Shapes: the flash, two shock rings and a band rolling out along the floor are ring shaders keyed over time.
# Particles: fire puffs bursting and cooling into smoke, a smoke column, sparks, embers, dust along the floor, rocks
# and grit that land on the floor (a collision floor), and brands that arc out and land, lighting small fires where
# they fall (an emitter along the floor that starts as they land).
extends "res://addons/pixelfx_particles/core/build.gd"

const Y := -5.4          # the blast's heart, a little above the floor
const STONE := ["#6b5d8c", "#4a3f69", "#2f2843"]


func make() -> void:
	ground()
	var white := color("palette", 1.0)
	var hot := color("palette", 0.85)
	var orange := color("palette", 0.43)
	var red := color("palette", 0.14)

	# the floor under it: a scorch that glows and cools to soot
	var scorch := ring("Scorch", 24, {"radius": 22, "squash": 0.18, "color": Color("#17121d"), "side": -1}, {"back": true})
	key(scorch, "material:shader_parameter/alpha", [[0.0, 0.0], [0.08, 1.0], [4.2, 1.0], [5.2, 0.0]])
	var scorch_glow := glow("ScorchGlow", 26, {"radius": 24, "squash": 0.2, "color": orange})
	key(scorch_glow, "material:shader_parameter/alpha", [[0.0, 0.0], [0.08, 0.9], [1.4, 0.3], [2.4, 0.0]])

	# light: a white pop and a warm swell
	var pop := glow("Pop", 60, {"radius": 30, "color": white}, {"at": Vector2(0, Y)})
	key(pop, "material:shader_parameter/alpha", [[0.0, 1.0], [0.1, 0.0]])
	var swell := glow("Swell", 80, {"radius": 64, "color": Color("#ffb060")}, {"at": Vector2(0, Y)})
	key(swell, "material:shader_parameter/alpha", [[0.0, 0.6], [0.7, 0.2], [1.4, 0.0]])

	# the flash: a white disc for two frames, then two shock rings and a band along the floor
	var flash := ring("Flash", 22, {"radius": 19, "color": white, "edge": 1.2, "edge_color": red.lerp(orange, 0.5)}, {"at": Vector2(0, Y)})
	show(flash, 0.0, 0.07)
	var r1 := ring("Shock", 50, {"radius": 8, "thickness": 3, "color": hot}, {"at": Vector2(0, Y)})
	key(r1, "material:shader_parameter/radius", [[0.0, 8.0], [0.34, 48.0]], "cubic")
	key(r1, "material:shader_parameter/thickness", [[0.0, 3.0], [0.34, 1.0]])
	show(r1, 0.0, 0.34)
	var r2 := ring("Shock2", 30, {"radius": 5, "thickness": 1.8, "color": orange}, {"at": Vector2(0, Y)})
	key(r2, "material:shader_parameter/radius", [[0.0, 5.0], [0.22, 29.0]], "cubic")
	show(r2, 0.0, 0.22)
	for side in [[1.0, true, "BandBack"], [-1.0, false, "BandFront"]]:
		var band := ring(side[2], 82, {"radius": 4, "thickness": 4, "squash": 0.16, "color": hot, "side": side[0], "ragged": 0.5}, {"back": side[1]})
		key(band, "material:shader_parameter/radius", [[0.0, 4.0], [0.5, 80.0]], "cubic")
		key(band, "material:shader_parameter/thickness", [[0.0, 4.0], [0.5, 1.0]])
		key(band, "material:shader_parameter/color", [[0.0, hot], [0.25, orange], [0.5, Color("#6b5d8c")]])
		show(band, 0.0, 0.5)

	# fire: puffs that burst out, rise and cool through the palette into smoke
	var fire := gradient([white, hot, color("palette", 0.57), orange, red, Color("#4b3d45"), Color("#3a3240", 0.7), Color("#3a3240", 0.0)],
		[0.0, 0.08, 0.18, 0.3, 0.45, 0.6, 0.8, 0.97])
	var puffs := particles("Fire", {"at": Vector2(0, Y), "amount": 34, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.5, "texture": "disc9", "emit": {"circle": 6}, "spread": 180, "speed": [30, 120],
		"damping": [120, 200], "gravity": Vector2(0, -40), "scale": [0.8, 1.4], "scale_curve": [[0, 0.7], [0.2, 1.2], [1, 0.9]], "ramp": fire})
	emit(puffs, 0.0)
	var column := particles("Column", {"at": Vector2(0, Y), "amount": 8, "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0,
		"texture": "disc7", "emit": {"box": Vector2(4, 2)}, "dir": -90, "spread": 6, "speed": [100, 170], "damping": [90, 130],
		"scale": [1.1, 1.5], "ramp": fire})
	emit(column, 0.0)
	var smoke := gradient([Color("#6d6578", 0.9), Color("#5a5266", 0.75), Color("#463f52", 0.5), Color("#463f52", 0.0)], [0.0, 0.35, 0.7, 0.96])
	var rise := particles("Smoke", {"layer": "soft", "at": Vector2(0, Y - 4), "amount": 18, "lifetime": 2.6, "one_shot": true, "explosiveness": 0.8,
		"randomness": 0.4, "texture": "disc9", "emit": {"box": Vector2(6, 4)}, "dir": -90, "spread": 25, "speed": [25, 70],
		"damping": [12, 22], "gravity": Vector2(3, -6), "scale": [0.8, 1.3], "scale_curve": [[0, 0.5], [0.4, 1.1], [1, 1.5]], "ramp": smoke})
	emit(rise, 0.15)

	# sparks and embers
	particles("Sparks", {"at": Vector2(0, Y), "amount": 70, "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0, "randomness": 0.6,
		"texture": "streak3", "align": true, "spread": 180, "speed": [140, 360], "damping": [200, 300], "gravity": Vector2(0, 160),
		"ramp": ramp("palette", {"reverse": true, "from": 0.4, "to": 1.0})})
	particles("Embers", {"at": Vector2(0, Y), "amount": 36, "lifetime": 2.4, "one_shot": true, "explosiveness": 1.0, "randomness": 0.6,
		"texture": "dot1", "emit": {"circle": 7}, "spread": 180, "speed": [30, 150], "damping": [50, 80], "gravity": Vector2(0, -4),
		"ramp": ramp("palette", {"reverse": true, "from": 0.3, "to": 0.9, "alpha": [[0, 1], [0.85, 1], [1, 0]]}),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})

	# the ground's part: dust rolling out along the floor, rocks and grit thrown up that land and stay a while
	var dust := gradient([Color("#7b6f8a", 0.85), Color("#625873", 0.6), Color("#4d455c", 0.3), Color("#4d455c", 0.0)], [0.0, 0.4, 0.75, 0.97])
	var roll := particles("Dust", {"layer": "soft", "at": Vector2(0, -4), "amount": 14, "lifetime": 1.8, "one_shot": true, "explosiveness": 0.9,
		"randomness": 0.4, "texture": "disc11", "emit": {"box": Vector2(8, 2)}, "dir": 0, "spread": 180, "speed": [55, 170],
		"damping": [70, 110], "gravity": Vector2(0, -3), "scale_curve": [[0, 0.6], [0.5, 1.1], [1, 1.3]], "ramp": dust})
	emit(roll, 0.05)
	particles("Rocks", {"at": Vector2(0, -3), "amount": 26, "lifetime": 3.0, "one_shot": true, "explosiveness": 1.0, "randomness": 0.3,
		"texture": "disc3", "emit": {"box": Vector2(6, 1)}, "dir": -90, "spread": 55, "speed": [60, 150], "gravity": Vector2(0, 260),
		"spin": [-400, 400], "initial": gradient(STONE), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
		"collide": {"bounce": 0.3, "friction": 0.6, "size": 3}})
	particles("Grit", {"at": Vector2(0, -1), "amount": 60, "lifetime": 2.0, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"texture": "dot1", "dir": -90, "spread": 35, "speed": [40, 140], "gravity": Vector2(0, 220),
		"initial": gradient(STONE), "alpha_curve": [[0, 1], [0.85, 1], [1, 0]], "collide": {"bounce": 0.2, "friction": 0.8}})

	# brands: burning chunks that arc out and land; small fires burn on where they fell
	particles("Brands", {"at": Vector2(0, Y), "amount": 9, "lifetime": 1.4, "one_shot": true, "explosiveness": 1.0,
		"texture": "dot2", "dir": -90, "spread": 75, "speed": [120, 220], "gravity": Vector2(0, 300),
		"ramp": ramp("palette", {"reverse": true, "from": 0.4, "to": 0.9}), "collide": {"hide": true, "size": 2}})
	var blazes := particles("Blazes", {"at": Vector2(0, -1), "amount": 36, "lifetime": 0.7, "texture": "disc3", "emitting": false,
		"emit": {"box": Vector2(70, 0.5)}, "dir": -90, "spread": 10, "speed": [6, 14], "scale_curve": [[0, 1.0], [1, 0.3]],
		"ramp": ramp("palette", {"reverse": true, "from": 0.15, "to": 0.85, "alpha": [[0, 1], [0.7, 1], [1, 0.3]]})})
	emit(blazes, 0.75, 3.6)
	key(blazes, "amount_ratio", [[0.75, 1.0], [2.4, 0.6], [3.6, 0.2]])
