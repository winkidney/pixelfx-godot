# reimagined-from: src/fx/water/rain-splash.js@fc0377abdffa8813dd7b738c614238958149c5e6
# Rain splash: A low close-up on one puddle in the rain: big drops land in crowns that throw beads and a rebound jet, rings spread and interfere, a lamp's reflection wobbles on the water.
# loop, 2.40 s, 176x80 canvas, origin [88.0, 50.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The puddle is a canvas shader (fx/water/_puddle.gdshader) driven by the original's eight drops (where and when each
# lands, its crown and jet): the see-through water with the swell of every ring summed (soft layer), the lamp's
# reflection pushed about by the swell and the lit far rim, the crowns' fingers, the drops falling in, the rebound jets
# and their beads, the rings' crisp near halves (colour layer), and their light. The beads torn off each crown are a
# burst on its beat; finer rain streaks down and dimples the water (emitters).
extends "res://build/fx/water/_water.gd"

const D := 2.4
const SY := 0.3
const RX := 92.0
const G := 640.0
const N := 8
const LAMP := 34.0


func make() -> void:
	var S: int = meta.options.seed
	var da := PackedVector4Array()
	var db := PackedVector2Array()
	var tips := PackedFloat32Array()
	var drops := []
	for i in N:
		var q := {"x": (jsrand([i, S]) - 0.5) * 120.0, "z": (jsrand([i, S + 1]) - 0.5) * 50.0,
			"t0": ((i + 0.25 * jsrand([i, S + 2])) / N) * D, "H": 10.0 + 4.0 * jsrand([i, S + 3]),
			"J": 7.0 + 4.0 * jsrand([i, S + 4]), "spin": jsrand([i, S + 5]) * TAU}
		drops.append(q)
		da.append(Vector4(q.x, q.z, q.t0, q.spin))
		db.append(Vector2(q.H, q.J))
		for f in 10:
			tips.append(jsrand([i, f, 7]))
	var size := Vector2(184, 84)
	var at := Vector2(0, -10)
	var params := {"pal": C, "dur": D, "sy": SY, "rx": RX, "lamp": LAMP, "drop_a": da, "drop_b": db, "tips": tips}
	for m in [["Water", 0.0, true], ["Sky", 3.0, true], ["Swell", 4.0, true], ["Reflection", 1.0, true], ["Splashes", 2.0, false]]:
		var pr := params.duplicate()
		pr.mode = m[1]
		if m[1] == 0.0 or m[1] > 2.5:
			pr.translucent = true
		loop_t(shape(m[0], water_shader("puddle"), size, pr, {"at": at, "back": m[2]}))
	loop_t(shape("Light", water_shader("puddle_light"), size, params, {"at": at}))
	glow("LampLight", 30, {"radius": 30, "color": C[4], "alpha": 0.16}, {"at": Vector2(LAMP, -6)})

	# beads torn off each crown's tips arc out and fall back
	for i in N:
		var q: Dictionary = drops[i]
		var beads := particles("Beads%d" % i, {"at": Vector2(q.x, q.z * SY - q.H * 0.75), "amount": 5, "lifetime": 0.28,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "dot1", "dir": -90, "spread": 38,
			"speed": [45, 80], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[7]])})
		emit(beads, fmod(q.t0 + 0.16, D))

	# finer rain: streaks falling past, dimples and the beads' little rings on the water
	particles("Rain", {"at": Vector2(0, -44), "amount": 2, "lifetime": 0.1, "texture": "streak6", "align": true,
		"emit": {"box": Vector2(80, 4)}, "dir": 90, "speed": [580, 620], "ramp": gradient([C[3], C[5]], [0.0, 0.5])})
	particles("Dimples", {"amount": 6, "lifetime": 0.4, "texture": "ripple7x3", "emit": {"box": Vector2(78, 7)},
		"ramp": ramp("palette", {"from": 0.57, "to": 0.86, "reverse": true,
		"alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
