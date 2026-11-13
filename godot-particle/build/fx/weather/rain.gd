# reimagined-from: src/fx/weather/rain.js
# Rain: slanted rain at four depths: far drops fade into the dark, near ones glint and splash, drops ring the puddles
# and a low mist drifts over the wet floor.
# The haze, the wet floor line and the puddles are the original's still pixels (port/props.py --share 0.3). Four
# emitters across the top, one per depth (streaks aligned with their fall, longer and brighter nearer), the far two
# ending in the air, the near two landing on a collision floor; droplets splashing up all along the floor; ripples on
# the puddles; a band of mist drifting low along the floor (the fog shader).
extends "res://addons/pixelfx_particles/core/build.gd"

const SLANT := -0.2          # x per y as they fall
const TOP := -184.0          # just above the canvas (the origin is the floor, 170 px down)


func make() -> void:
	ground()
	prop({"name": "Haze"})
	var fall := rad_to_deg(atan2(1.0, SLANT))
	# far to near: [amount, speed, streak, colour from..to, lifetime (far ones end in the air)]
	var layers := [
		["Far", 200, [230, 280], "streak3", [0.25, 0.4], [0.5, 0.62], false],
		["Mid", 150, [300, 340], "streak4", [0.3, 0.55], [0.48, 0.58], false],
		["Near", 96, [380, 430], "streak8", [0.45, 0.75], 0.75, true],
		["Close", 60, [470, 520], "streak12", [0.6, 0.9], 0.6, true],
	]
	particles("Splash", {"at": Vector2(0, -1), "amount": 90, "lifetime": 0.3, "texture": "dot1", "emit": {"box": Vector2(160, 0.5)},
		"dir": -90, "spread": 60, "speed": [25, 55], "gravity": Vector2(0, 320), "ramp": ramp("palette", {"from": 0.62, "to": 0.85})})
	for L in layers:
		var c: Array = L[4]
		var o := {"at": Vector2(0, TOP), "amount": L[1], "lifetime": L[5] if L[5] is float else L[5][1], "randomness": 0.2,
			"texture": L[3], "align": true, "emit": {"box": Vector2(200, 1)}, "dir": fall, "spread": 0, "speed": L[2],
			"ramp": ramp("palette", {"from": c[0], "to": c[1], "reverse": true})}
		if L[6]:
			o.collide = {"hide": true, "size": 1}
		particles(L[0], o)
	# rings on the puddles and a mist drifting low over the wet floor
	particles("Ripples", {"at": Vector2(0, -1), "amount": 14, "lifetime": 0.45, "texture": "ripple7x3", "emit": {"box": Vector2(160, 0.5)},
		"scale_curve": [[0, 0.6], [1, 1.6]], "ramp": ramp("palette", {"from": 0.5, "to": 0.75, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
	fog("Mist", Vector2(330, 36), {"profile": Vector4(-22, -4, 7, 10), "drift": Vector2(1, 0), "period": Vector2(256 / 0.45, 64 / 4.0),
		"low": color("palette", 0.43), "high": color("palette", 0.57), "crest": color("palette", 0.57).lerp(color("palette", 0.71), 0.5),
		"alpha": 0.5}, {"at": Vector2(0, -7)})
