# reimagined-from: src/fx/transitions/iris.js@022b4ba67998bba6943eb6aefbc748ec23df8868
# Iris: a lit iris closes onto a warm spotlight where dust drifts, holds as its rim twinkles, snaps shut into a glint,
# then pops open from a flash with a white-hot rim throwing sparks.
# The ink and its lit rim are one shader (shaders/iris.gdshader) whose radius follows the original's curve, sampled
# every frame into keys; the spotlight is an additive glow, dust motes drift in it, a glint marks the shut, a white
# flash and a ring of sparks open it again.
extends "res://addons/pixelfx_particles/core/build.gd"

const D := 2.2
const CLOSE := 0.62
const SNAP := 0.9
const SHUT := 0.99
const POP := 1.2
const OPEN := 1.75
const RS := 24.0
const RW := 5.0


static func in_out_cubic(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func out_quart(x: float) -> float:
	return 1.0 - pow(1.0 - x, 4.0)


func radius(t: float, R0: float) -> float:
	if t < CLOSE:
		return RS + (R0 - RS) * (1.0 - in_out_cubic(t / CLOSE))
	if t < SNAP:
		return RS + sin((t - CLOSE) * 22.0) * 0.8 * (1.0 - (t - CLOSE) / (SNAP - CLOSE))
	if t < SHUT:
		var u := (t - SNAP) / (SHUT - SNAP)
		return RS * (1.0 - u * u * u)
	if t < POP:
		return 0.0
	return R0 * out_quart(clampf((t - POP) / (OPEN - POP), 0.0, 1.0))


func make() -> void:
	var focus := Vector2(160, 100)
	var W := 320.0
	var H := 180.0
	var R0 := 0.0
	for c in [Vector2(0, 0), Vector2(W, 0), Vector2(0, H), Vector2(W, H)]:
		R0 = maxf(R0, c.distance_to(focus))
	R0 += RW + 2.0
	var ink := Color(meta.options.color)

	# the spotlight inside the hole while it holds, and its dust
	var spot := glow("Spot", 40, {"radius": RS + 6, "color": color("palette", 0.71)}, {"at": focus})
	key(spot, "material:shader_parameter/alpha", [[0.0, 0.0], [CLOSE - 0.15, 0.0], [CLOSE, 0.55], [SNAP, 0.6], [SHUT, 0.0]])
	var motes := particles("Motes", {"at": focus, "amount": 14, "lifetime": 1.2, "texture": "dot1", "emitting": false,
		"emit": {"circle": RS - 3}, "dir": -90, "spread": 180, "speed": [2, 6], "ramp": ramp("palette", {"from": 0.6, "to": 0.9,
		"alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]]})})
	emit(motes, CLOSE - 0.2, SNAP)

	var hole := shape("Iris", "iris", Vector2(W, H), {"focus": focus, "radius": R0, "ink": ink, "rim": RW,
		"rim_inner": color("palette", 0.86), "rim_outer": color("palette", 0.43)}, {"at": Vector2(W / 2, H / 2)})
	var keys := []
	var twinkle := []
	var grain := []
	var n := int(roundf(D * 30.0))
	for i in n + 1:
		var t := i / 30.0
		keys.append([t, radius(t, R0)])
		twinkle.append([t, 0.35 if (t > CLOSE and t < SNAP) else 0.0])
		grain.append([t, float(i % 7)])
	key(hole, "material:shader_parameter/radius", keys)
	key(hole, "material:shader_parameter/twinkle", twinkle, "nearest")
	key(hole, "material:shader_parameter/grain", grain, "nearest")
	# a white-hot rim as it pops open, cooling to the lit gold
	key(hole, "material:shader_parameter/rim_inner", [[0.0, color("palette", 0.86)], [POP, Color.WHITE], [OPEN, color("palette", 0.86)]], "nearest")

	# the glint where it shuts, and the flash and sparks that open it
	var glint := sprite("Glint", "spark7", {"at": focus, "modulate": Color.WHITE})
	show(glint, SHUT - 0.03, POP - 0.05)
	key(glint, "scale", [[SHUT - 0.03, Vector2(1, 1)], [SHUT + 0.06, Vector2(2, 2)], [POP - 0.05, Vector2(0.5, 0.5)]])
	var flash := glow("Flash", 120, {"radius": 110, "color": Color.WHITE}, {"at": focus})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [POP - 0.01, 0.0], [POP, 1.0], [POP + 0.18, 0.0]])
	var sparks := particles("Sparks", {"at": focus, "amount": 40, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": "streak3", "align": true, "emit": {"circle": 4}, "spread": 180, "speed": [90, 220], "damping": [120, 200],
		"ramp": ramp("palette", {"reverse": true, "from": 0.55, "to": 1.0})})
	emit(sparks, POP)
