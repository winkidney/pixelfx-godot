# reimagined-from: src/fx/fire/brazier.js@0f9ab2b138afd733a34503395505b37f34ea68a7
# Brazier: an iron bowl on a tripod heaped with glowing coals and a big roaring fire, sparks and embers streaming up
# off it, light on the iron and the floor.
# The bowl and tripod are the original's pixels (port/props.py); the coals breathe in a small shader; the fire is
# eleven layered tongues (fire/_fire.gd: a red rim round orange, yellow and a white heart, each a stream of shrinking
# discs, keyed to leap and sway), with flame puffs and licks torn off the tips, a smoke plume, sparks streaming up
# that slow into embers, and the fire's flickering light on the wall and the floor.
extends "res://build/fx/fire/_fire.gd"

const RIM := -25.0
const RX := 15.0
const S := 8
const HC := 32.0
const TONGUES := [
	[-7, -1.5, 0.5, 2.0, 1], [7.2, -1.5, 0.55, 2.0, 1], [-3, -2.5, 0.84, 2.2, 1], [3.3, -2.5, 0.86, 2.2, 1],
	[-11.5, 0.5, 0.2, 1.5, 0], [11.5, 0.5, 0.22, 1.5, 0], [-8.3, 0, 0.34, 2.0, 0], [8.5, 0, 0.38, 2.0, 0],
	[-4.7, -0.5, 0.6, 2.8, 0], [4.9, -0.5, 0.64, 2.8, 0], [0, -1, 1, 3.6, 0],
]


func make() -> void:
	fire_begin()
	var I: PackedColorArray = root.ramps.iron
	var GLOW := glow_colour()
	# light on the floor and the wall
	fire_glow("FloorLight", Vector2(0, 0.5), 40, GLOW, 0.32, S, 7.0 / 40.0)

	# the smoke plume curling off with the draught
	var smoke_col := SMOKE1.lerp(H[6], 0.25)
	particles("Smoke", {"layer": "soft", "at": Vector2(0, RIM - HC * 0.8 - 3), "amount": 26, "lifetime": 2.0, "randomness": 0.3,
		"texture": "disc7", "emit": {"box": Vector2(5, 3)}, "dir": -90, "spread": 12, "speed": [10, 17], "damping": [3, 6],
		"gravity": Vector2(3, -8), "scale": [0.8, 1.1], "scale_curve": [[0, 0.75], [0.4, 1.0], [1, 1.35]],
		"ramp": smoke_ramp(smoke_col, 0.36), "turbulence": {"strength": 1.0, "scale": 3.0}})

	var TT := flames(Vector2(0, RIM), TONGUES, HC, {"seed": S, "lean": 0.1})

	# the coals heaped in the bowl over the tongues' roots, and the bowl's lit rim
	shape("Coals", load("res://addons/pixelfx_particles/fx/fire/_coals.gdshader"), Vector2(32, 14), {
		"half_w": RX, "base": RIM, "mound": 4.0, "pulses": 2.0, "c0": H[6], "c1": H[2], "c2": H[3], "c3": H[4], "c4": H[5],
		"gap": I[0], "rim": I[3].lerp(H[4], 0.42), "rim_edge": I[0], "rivet": I[4].lerp(H[4], 0.22), "rim_half": 14.0},
		{"at": Vector2(0, RIM - 4)})
	var coals: ColorRect = root.get_node("Coals")
	loop_t(coals)
	prop({"back": false})

	tip_bits(Vector2(0, RIM), TT)

	# sparks streaming up in the draught: fast streaks that slow, then wander and cool as embers high above
	particles("Sparks", {"at": Vector2(0, RIM - 11), "amount": 12, "lifetime": 0.55, "randomness": 0.3, "texture": "streak4",
		"align": true, "emit": {"box": Vector2(8, 7)}, "dir": -90, "spread": 22, "speed": [70, 150], "damping": [120, 160],
		"ramp": gradient([H[1], H[2], H[2], H[4]], [0.0, 0.3, 0.6, 0.85])})
	particles("SparkEmbers", {"at": Vector2(0, RIM - 48), "amount": 22, "lifetime": 1.2, "randomness": 0.6, "texture": "dot1",
		"emit": {"box": Vector2(16, 12)}, "dir": -90, "spread": 60, "speed": [12, 40], "damping": [10, 25], "gravity": Vector2(0, -12),
		"ramp": gradient([H[2], H[2], H[4], H[5], Color(H[6], 0.0)], [0.0, 0.3, 0.6, 0.85, 0.97]),
		"turbulence": {"strength": 4.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	# a few big embers: little crosses
	particles("BigEmbers", {"at": Vector2(0, RIM - 40), "amount": 4, "lifetime": 1.4, "randomness": 0.5, "texture": "plus3",
		"emit": {"box": Vector2(14, 14)}, "dir": -90, "spread": 50, "speed": [10, 30], "damping": [5, 10], "gravity": Vector2(0, -10),
		"ramp": gradient([H[4], H[5], H[6], Color(H[6], 0.0)], [0.0, 0.4, 0.8, 0.97]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	particles("Embers", {"at": Vector2(0, RIM - HC * 0.55), "amount": 18, "lifetime": 1.8, "randomness": 0.5, "texture": "dot1",
		"emit": {"box": Vector2(7, 5)}, "dir": -90, "spread": 30, "speed": [25, 60], "damping": [20, 40], "gravity": Vector2(0, -20),
		"ramp": ember_ramp(), "turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})

	fire_light(Vector2(0, RIM), HC, 58.0, 1.4, S)
