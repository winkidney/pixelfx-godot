# reimagined-from: src/fx/fire/torch.js@e4fc006bf9ce6b4c54f06869fdac765498f5a1d0
# Torch: a wall torch on an iron bracket: a licking flame leaping off a pitch-soaked wrap, licks and puffs torn off
# its tips, smoke, embers, a flickering light on the wall.
# The bracket, handle and wrap are the original's pixels (port/props.py); the flame is three emitters (a hot root,
# tongues that cool as they rise, puffs torn off the tips), smoke drifts off above it, embers float up, and a dim
# additive glow flickers on the wall.
extends "res://addons/pixelfx_particles/core/build.gd"

const TOP := -17.0   # where the wrap ends and the flame starts


func make() -> void:
	prop()

	# the light on the wall: dim and warm, flickering
	var glow := sprite("Glow", "glow64", {"at": Vector2(0, TOP - 8), "layer": "light", "scale": Vector2(1.5, 1.6), "modulate": Color("#ffb864")})
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var flick := []
	for i in 16:
		flick.append([i * root.duration / 16.0, 0.5 + 0.25 * rng.randf()])
	flick.append([root.duration, flick[0][1]])
	key(glow, "modulate:a", flick)

	var smoke := gradient([Color("#7d6d76", 0.7), Color("#645660", 0.5), Color("#4d434c", 0.3), Color("#4d434c", 0.0)], [0.0, 0.3, 0.65, 0.95])
	particles("Smoke", {"layer": "soft", "at": Vector2(0, TOP - 24), "amount": 9, "lifetime": 1.8, "randomness": 0.4, "texture": "disc3",
		"emit": {"box": Vector2(2, 3)}, "dir": -90, "spread": 14, "speed": [10, 15], "gravity": Vector2(2, -1),
		"scale_curve": [[0, 0.8], [0.5, 1.3], [1, 1.7]], "ramp": smoke,
		"turbulence": {"strength": 1.0, "scale": 3.0}})

	# the flame: tongues licking up off the wrap, white-yellow at the root, cooling to deep red at the tips
	var tongues := particles("Tongues", {"at": Vector2(0, TOP), "amount": 90, "lifetime": 0.6, "randomness": 0.3,
		"texture": "disc3", "emit": {"box": Vector2(3, 1)}, "dir": -90, "spread": 5, "speed": [30, 44],
		"damping": [10, 18], "scale_curve": [[0, 1.4], [0.5, 1.0], [1, 0.4]],
		"ramp": ramp("palette", {"reverse": true, "from": 0.18, "to": 0.85, "alpha": [[0, 1], [0.8, 1], [1, 0.4]]})})
	# the flame licks: its root sways a pixel or two, so each tongue leans a little differently
	var sway := []
	for i in 13:
		sway.append([i * root.duration / 12.0, Vector2((rng.randf() * 3.0 - 1.5) if i < 12 else 0.0, TOP)])
	sway[0][1] = Vector2(0, TOP)
	key(tongues, "position", sway)
	particles("Root", {"at": Vector2(0, TOP), "amount": 14, "lifetime": 0.3, "texture": "disc3",
		"emit": {"box": Vector2(1.5, 1)}, "dir": -90, "spread": 6, "speed": [18, 26], "scale_curve": [[0, 1.0], [1, 0.5]],
		"ramp": ramp("palette", {"reverse": true, "from": 0.55, "to": 0.88})})
	particles("Puffs", {"at": Vector2(0, TOP - 10), "amount": 10, "lifetime": 0.55, "randomness": 0.5,
		"texture": "dot2", "emit": {"box": Vector2(3, 4)}, "dir": -90, "spread": 14, "speed": [26, 40],
		"damping": [10, 16], "scale_curve": [[0, 1.0], [1, 0.5]],
		"ramp": ramp("palette", {"reverse": true, "from": 0.1, "to": 0.7, "alpha": [[0, 1], [0.7, 1], [1, 0.2]]}),
		"turbulence": {"strength": 2.0, "scale": 2.0}})
	particles("Embers", {"at": Vector2(0, TOP - 10), "amount": 14, "lifetime": 2.2, "randomness": 0.5,
		"texture": "dot1", "emit": {"box": Vector2(4, 5)}, "dir": -90, "spread": 35, "speed": [14, 26],
		"gravity": Vector2(1.5, -3), "damping": [3, 6],
		"ramp": ramp("palette", {"reverse": true, "from": 0.55, "to": 1.0, "alpha": [[0, 1], [0.85, 1], [1, 0]]}),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
