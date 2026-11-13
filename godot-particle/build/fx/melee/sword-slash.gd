# reimagined-from: src/fx/melee/sword-slash.js
# Sword slash: a tilted crescent whips round in two frames, cools from white to deep blue down a dithered tail; the
# tip glints, sparks and shavings fly off the edge.
# The smear and its thinner echo are the arc shader (shaders/arc.gdshader, the original's crescent profile), their
# head and tail keyed from the original's sweep / hold / trail timing; a glow rides the head; sparks off the tip and
# shavings off the arc are bursts as the edge lands; a star glint at the tip.
extends "res://addons/pixelfx_particles/core/build.gd"

const A0 := -2.55
const A1 := 0.95


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## One smear: arc centre (cx, cy), radius R, width W, start t0 and its sweep / hold / trail, colours `ramp_to` of
## the palette (bright first).
func smear(name: String, R: float, W: float, a0: float, a1: float, t0: float, sweep: float, hold: float, trail: float, n: int) -> void:
	var cols: PackedColorArray = root.ramps.palette
	var bright := []
	for i in n:
		bright.append(cols[n - 1 - i])
	var r := arc(name, R, {"radius": R, "squash": 0.6, "tilt": rad_to_deg(-0.38), "thickness": W, "ramp": gradient(bright),
		"steps": float(n), "head": rad_to_deg(a0), "tail": rad_to_deg(a0)}, {"at": Vector2(6, -26)})
	var heads := []
	var tails := []
	var widths := []
	var ages := []
	var end := sweep + hold + trail
	var steps := int(ceil((t0 + end) * 60.0)) + 1
	for i in steps + 1:
		var t := i / 60.0
		var u := t - t0
		var head := out_expo(clampf(u / sweep, 0.0, 1.0)) if u >= 0.0 else 0.0
		var tail := smooth(sweep + hold, sweep + hold + trail, u) if u >= 0.0 else 0.0
		heads.append([t, rad_to_deg(a0 + (a1 - a0) * head)])
		tails.append([t, rad_to_deg(a0 + (a1 - a0) * tail)])
		widths.append([t, W * (1.0 - tail * 0.55) if (u >= 0.0 and tail < 1.0) else 0.0])
		ages.append([t, clampf(u / end, 0.0, 1.0)])
	key(r, "material:shader_parameter/head", heads)
	key(r, "material:shader_parameter/tail", tails)
	key(r, "material:shader_parameter/thickness", widths)
	key(r, "material:shader_parameter/age", ages)


func make() -> void:
	var R0: float = meta.options.radius
	var tip := _on_arc(R0 - 12 * 0.3, A1)
	# light rides the head of the swing
	var shine := glow("Shine", 40, {"radius": 40, "color": color("palette", 0.5)}, {"at": _on_arc(R0 - 4, A0)})
	var path := []
	for i in 19:
		var t := i / 60.0
		path.append([t, _on_arc(R0 - 4, A0 + (A1 - A0) * out_expo(clampf(t / 0.06, 0.0, 1.0)))])
	key(shine, "position", path)
	key(shine, "material:shader_parameter/alpha", [[0.0, 0.5], [0.3, 0.0]])

	smear("Echo", R0 * 33.0 / 42.0, R0 * 4.5 / 42.0, A0 + (A1 - A0) * 0.1, A1 - (A1 - A0) * (0.15 / 3.5), 0.017, 0.06, 0.03, 0.2, 6)
	smear("Smear", R0, 12.0, A0, A1, 0.0, 0.06, 0.06, 0.24, 7)

	# as the edge lands: sparks off the tip, shavings flung off the arc
	var d := (_on_arc(R0 - 12 * 0.3, A1 + 0.05) - tip).normalized()
	var sp_ramp := gradient(meta.options.sparks)
	var sparks := particles("Sparks", {"at": tip, "amount": 10, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "streak3", "align": true, "dir": rad_to_deg(d.angle()), "spread": 29,
		"speed": [150, 400], "damping": [300, 500], "ramp": sp_ramp})
	emit(sparks, 0.06)
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(_on_arc(R0, A0 + (A1 - A0) * (0.3 + 0.7 * i / 23.0)) - Vector2(6, -26))
	var shavings := particles("Shavings", {"at": Vector2(6, -26), "amount": 16, "lifetime": 0.45, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "dot1", "emit": {"points": pts}, "spread": 180,
		"speed": [30, 100], "radial": [40, 80], "ramp": ramp("palette", {"from": 0.66, "to": 0.85, "alpha": [[0, 1], [0.7, 1], [1, 0]]})})
	emit(shavings, 0.06)
	# the tip glints as the edge arrives
	var glint := sprite("Glint", "star5", {"at": tip, "modulate": color("palette", 0.83)})
	show(glint, 0.036, 0.256)
	key(glint, "scale", [[0.036, Vector2(0.4, 0.4)], [0.086, Vector2(1.8, 1.8)], [0.256, Vector2(0.2, 0.2)]])


func _on_arc(r: float, a: float) -> Vector2:
	var lx := cos(a) * r
	var ly := sin(a) * r * 0.6
	var c := cos(-0.38)
	var n := sin(-0.38)
	return Vector2(6 + lx * c - ly * n, -26 + lx * n + ly * c)
