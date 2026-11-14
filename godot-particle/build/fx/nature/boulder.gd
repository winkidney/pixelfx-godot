# reimagined-from: src/fx/nature/boulder.js@3152de68568f730da12f1c597b490e0d53717e52
# Boulder: A spinning boulder arcs right shedding dust and pebbles, smashes into the floor in a white flash and bursts
# into tumbling chunks, gravel and rolling dust.
# The boulder is a body: its frames are the original's (port/frames.py, cropped to the rock: fx/nature/boulder/
# body.png), carried along the original's arc by keys, trailing four speed lines (Line2D). Everything else is made
# here: dust and pebbles shed in flight (emitters riding the arc), the hit's white frame (the last rock frame through
# the actor shader's flash), a sparkle and lines of force, a ring racing out along the floor (ring shader), faceted
# chunks drawn the way the original draws its stones (build-time textures) tumbling and bouncing on a collision
# floor, grit, sparks, dust rolling out and climbing (soft layer), a dent left in the floor, and the light.
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const X0 := 6.0
const Y0 := -26.0
const VX := 220.0
const VY := -170.0
const G := 860.0
const RAD := 11.0


func at(t: float) -> Vector2:
	return Vector2(X0 + VX * t, Y0 + VY * t + 0.5 * G * t * t)


func make() -> void:
	ground()
	var S: PackedColorArray = root.ramps.palette
	var t_hit := (-VY + sqrt(VY * VY - 2.0 * G * (Y0 + RAD * 0.8))) / G
	var x_hit := X0 + VX * t_hit
	var hit := Vector2(x_hit, -RAD * 0.6)
	var dust := S[6].lerp(Color("#9a8f86"), 0.4)
	var dust2 := S[5].lerp(Color("#7a7068"), 0.35)
	var D: float = meta.duration

	# the dent it leaves in the floor, fading at the end
	var scar := group("Scar", {"back": true, "at": Vector2(roundf(x_hit), 0)})
	rect("Dent", Rect2(-10, 0, 21, 1), S[1], {"back": true, "parent": scar})
	rect("DentCore", Rect2(-6, 0, 13, 1), S[0], {"back": true, "parent": scar})
	rect("DentLow", Rect2(-5, 1, 11, 1), S[1], {"back": true, "parent": scar})
	for sd in [-1, 1]:
		for k in 4:
			rect("Crack%d%d" % [sd + 1, k], Rect2(sd * (12 + k * 3), k & 1, 1, 1), S[1], {"back": true, "parent": scar, "modulate": Color(1, 1, 1, 1.0 - k / 4.0)})
	show(scar, t_hit)
	key(scar, "scale", [[t_hit, Vector2(0.3, 1)], [t_hit + 0.05, Vector2(1, 1)]])
	key(scar, "modulate:a", [[0.0, 1.0], [D - 0.6, 1.0], [D - 0.15, 0.0]])

	# in flight: speed lines trailing it, dust and pebbles shed off it, a faint light on it
	var trail := group("Trail")
	for i in 4:
		var off := (i - 1.5) * RAD * 0.55
		var L := 10.0 + (i % 2) * 6.0
		line("Speed%d" % i, PackedVector2Array([Vector2(-(RAD + 2), off), Vector2(-(RAD + 2 + L), off)]),
			{"color": S[5] if i % 2 else S[6], "parent": trail})
	trail.modulate.a = 0.8
	var shed := particles("Shed", {"layer": "soft", "amount": 10, "lifetime": 0.55, "randomness": 0.4, "texture": "disc9",
		"emit": {"box": Vector2(2, 4)}, "dir": 180, "spread": 20, "speed": [10, 40], "damping": [40, 80],
		"scale": [0.5, 0.8], "scale_curve": [[0, 0.5], [1, 1.2]],
		"ramp": gradient([Color(dust, 0.7), Color(dust, 0.5), Color(dust, 0.3), Color(dust, 0.1)])})
	emit(shed, 0.0, t_hit)
	var pebbles := particles("Pebbles", {"amount": 3, "lifetime": 0.75, "texture": "dot1", "emit": {"box": Vector2(4, 3)},
		"dir": -20, "spread": 25, "speed": [60, 90], "gravity": Vector2(0, 950),
		"initial": gradient([S[5], S[4]])})
	emit(pebbles, 0.0, t_hit)
	var rock_light := glow("RockLight", 24, {"radius": 22, "color": S[6], "alpha": 0.12})
	show(rock_light, 0.0, t_hit)
	var body := sprite("Boulder", load("res://addons/pixelfx_particles/fx/nature/boulder/body.png"), {"layer": "prop", "centered": false})
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://addons/pixelfx_particles/fx/nature/boulder/body.json"))
	var n: int = info.count
	body.hframes = n
	body.offset = -Vector2(16, 16)
	var flash := ShaderMaterial.new()
	flash.shader = load("res://addons/pixelfx_particles/shaders/actor.gdshader")
	body.material = flash
	var frames := []
	var pos := []
	var rot := []
	var tpos := []
	for i in n:
		var t := i / 30.0
		frames.append([t, i])
		var c: Array = info.centres[i]
		pos.append([t, Vector2(c[0], c[1])])
	for i in int(ceil(t_hit * 60.0)) + 1:
		var t := minf(i / 60.0, t_hit)
		var v := Vector2(VX, VY + G * t)
		tpos.append([t, at(t)])
		rot.append([t, v.angle()])
	frames.append([t_hit, n - 1])
	pos.append([t_hit, hit + Vector2(0, -RAD * 0.2)])
	key(body, "frame", frames, "nearest")
	key(body, "position", pos, "nearest")
	key(body, "material:shader_parameter/flash", [[0.0, 0.0], [t_hit, 1.0]], "nearest")
	show(body, 0.0, t_hit + 0.07)
	key(trail, "position", tpos)
	key(trail, "rotation", rot)
	show(trail, 0.0, t_hit)
	for e in [shed, pebbles, rock_light]:
		key(e, "position", tpos)
	var puff := particles("Puff", {"layer": "soft", "at": Vector2(X0 - 3, Y0), "amount": 6, "lifetime": 0.6, "randomness": 0.3,
		"one_shot": true, "explosiveness": 1.0, "texture": "disc9", "emit": {"box": Vector2(3, 4)}, "dir": 180, "spread": 30,
		"speed": [20, 70], "damping": [60, 120], "scale": [0.6, 1.0], "scale_curve": [[0, 0.6], [1, 1.4]],
		"ramp": gradient([Color(dust, 0.7), Color(dust, 0.5), Color(dust, 0.3), Color(dust, 0.1)])})
	emit(puff, 0.0)
	var throw_light := glow("ThrowLight", 32, {"radius": 30, "color": Color.WHITE}, {"at": Vector2(X0, Y0)})
	key(throw_light, "material:shader_parameter/alpha", [[0.0, 0.3], [0.05, 0.08], [0.1, 0.0]])

	# the hit: light, a sparkle, lines of force, a ring racing out along the floor
	var white := glow("HitFlash", 40, {"radius": 36, "color": Color.WHITE, "alpha": 0.0}, {"at": hit})
	key(white, "material:shader_parameter/alpha", [[0.0, 0.0], [t_hit - 0.001, 0.0], [t_hit, 0.75], [t_hit + 0.05, 0.19], [t_hit + 0.1, 0.0]])
	key(white, "material:shader_parameter/radius", [[t_hit, 36.0], [t_hit + 0.1, 20.0]])
	var warm := glow("HitWarm", 62, {"radius": 60, "color": Color("#ffb060"), "alpha": 0.0}, {"at": hit})
	var wk := [[0.0, 0.0], [t_hit - 0.001, 0.0]]
	var wr := []
	for i in 11:
		var k := 1.0 - i / 10.0
		wk.append([t_hit + 0.05 * i, 0.45 * k * k])
		wr.append([t_hit + 0.05 * i, 60.0 * (0.55 + 0.45 * k)])
	key(warm, "material:shader_parameter/alpha", wk)
	key(warm, "material:shader_parameter/radius", wr)
	var spark_glow := glow("SparkleLight", 30, {"radius": 28, "color": Color.WHITE, "alpha": 0.0}, {"at": hit})
	key(spark_glow, "material:shader_parameter/alpha", [[0.0, 0.0], [t_hit - 0.001, 0.0], [t_hit, 0.6], [t_hit + 0.07, 0.0]])
	var star := gradient([Color("#ffd27a"), Color.WHITE, Color("#ffd27a")], [0.0, 0.3, 0.7])
	for k in 2:
		var arm := 12.0 * (1.0 - (k * 0.035 + 0.02) / 0.07)
		for axis in [Vector2(1, 0), Vector2(0, 1)]:
			var sl := line("Sparkle%d%s" % [k, "H" if axis.x > 0 else "V"], PackedVector2Array([hit - axis * arm, hit + axis * arm]), {"gradient": star})
			show(sl, t_hit + k * 0.035, t_hit + (k + 1) * 0.035)
	for i in 9:
		var a := -PI + i / 8.0 * PI
		var d := Vector2(cos(a), sin(a))
		var fl := line("Force%d" % i, PackedVector2Array([hit + d * (RAD + 4), hit + d * (RAD + 12)]), {"color": Color.WHITE})
		var pts := []
		var cols := []
		for j in 5:
			var e := j / 30.0
			var k := e / 0.14
			var r0 := RAD + 4 + 16 * k
			var r1 := r0 + 8 * (1 - k)
			pts.append([t_hit + e, PackedVector2Array([hit + d * r0, hit + d * r1])])
			cols.append([t_hit + e, Color.WHITE if k < 0.5 else S[6]])
		key(fl, "points", pts, "nearest")
		key(fl, "default_color", cols, "nearest")
		show(fl, t_hit, t_hit + 0.14)
	# the band racing out along the floor: a lit inner band (ring shader) under a 1 px rim (a Line2D ellipse)
	var band := ring("Band", 50, {"radius": 4, "thickness": 3, "squash": 0.18, "color": Color("#ffd27a")}, {"at": Vector2(x_hit, 0.5)})
	var rim := line("BandRim", N.ellipse(Vector2(x_hit, 0.5), 4, 0.18), {"color": Color.WHITE})
	var br := []
	var bt := []
	var ba := []
	var rp := []
	var ra := []
	for i in 15:
		var e := i / 30.0
		var k := e / 0.45
		var r := 46.0 * N.out_cubic(k)
		br.append([t_hit + e, r - 0.8])
		rp.append([t_hit + e, N.ellipse(Vector2(x_hit, 0.5), r, 0.18)])
		bt.append([t_hit + e, maxf(0.0, 3.0 * (1.0 - k) - 0.8)])
		ba.append([t_hit + e, clampf(1.15 - k, 0.0, 1.0)])
		ra.append([t_hit + e, clampf(1.2 * (1.15 - k), 0.0, 1.0)])
	key(band, "material:shader_parameter/radius", br)
	key(band, "material:shader_parameter/thickness", bt)
	key(band, "material:shader_parameter/alpha", ba)
	key(rim, "points", rp, "nearest")
	key(rim, "modulate:a", ra)
	key(band, "material:shader_parameter/color", [[t_hit, Color("#ffd27a")], [t_hit + 0.2, S[6]]], "nearest")
	show(band, t_hit, t_hit + 0.3)
	show(rim, t_hit, t_hit + 0.45)

	# the boulder bursts: faceted chunks thrown up and on, spinning, bouncing and settling; small ones; grit; sparks
	var fade := [[0, 1], [0.75, 1], [1, 0]]
	var big := [[3.0, 31, 3], [4.0, 47, 3], [4.9, 53, 3]]
	for b in big:
		var p := particles("Chunk%d" % b[1], {"at": hit, "amount": b[2], "lifetime": 1.5, "randomness": 0.15, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": N.rock(b[1], b[0], S), "emit": {"box": Vector2(5, 5)}, "dir": -87,
			"spread": 64, "speed": [100, 240], "gravity": Vector2(0, 950), "damping": [30, 60], "angle": [0, 360],
			"spin": [-800, 800], "alpha_curve": fade, "collide": {"bounce": 0.35, "friction": 0.5, "size": 1}})
		emit(p, t_hit)
	for b in [[1.6, 61, 5], [2.0, 67, 5], [2.5, 71, 4]]:
		var p := particles("Bit%d" % b[1], {"at": Vector2(x_hit, hit.y), "amount": b[2], "lifetime": 1.3, "randomness": 0.15,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": N.rock(b[1], b[0], S),
			"emit": {"box": Vector2(4, 1)}, "dir": -86, "spread": 80, "speed": [120, 280], "gravity": Vector2(0, 950),
			"damping": [40, 80], "angle": [0, 360], "spin": [-1000, 1000], "alpha_curve": fade,
			"collide": {"bounce": 0.3, "friction": 0.5, "size": 1}})
		emit(p, t_hit)
	var grit_cols := gradient([S[6], S[5], S[4], S[4], S[3]])
	for g in [["Grit", "dot1", 36], ["Gravel", "dot2", 24]]:
		var p := particles(g[0], {"at": Vector2(x_hit, -1), "amount": g[2], "lifetime": 1.2, "randomness": 0.4, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": g[1], "emit": {"box": Vector2(6, 0.5)}, "dir": -86, "spread": 63,
			"speed": [80, 300], "gravity": Vector2(0, 950), "damping": [20, 60], "initial": grit_cols,
			"collide": {"bounce": 0.1, "friction": 1.0}})
		emit(p, t_hit)
	var sparks := particles("Sparks", {"at": hit, "amount": 12, "lifetime": 0.35, "randomness": 0.5, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "streak6", "align": true, "dir": -84, "spread": 75,
		"speed": [150, 380], "damping": [300, 500], "gravity": Vector2(0, 430), "ramp": gradient(meta.options.sparks)})
	emit(sparks, t_hit)
	var stars := particles("Stars", {"at": hit + Vector2(0, -3), "amount": 3, "lifetime": 0.3, "randomness": 0.3, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(8, 7)}, "speed": [4, 4],
		"color": S[7], "alpha_curve": [[0, 1], [0.5, 0.6], [1, 0]]})
	emit(stars, t_hit)

	# dust rolling out both ways along the floor and a cloud climbing off the hit
	var cloud := gradient([Color(dust, 0.0), Color(dust, 0.75), Color(dust.lerp(Color("#5d5660"), 0.35), 0.6),
		Color(dust2.lerp(Color("#433d48"), 0.5), 0.4), Color(Color("#433d48"), 0.2), Color(Color("#433d48"), 0.0)],
		[0.0, 0.04, 0.3, 0.55, 0.8, 0.95])
	for side in [-1, 1]:
		var roll := particles("Roll%s" % ("L" if side < 0 else "R"), {"layer": "soft", "at": Vector2(x_hit + side * 6, -3),
			"amount": 7, "lifetime": 1.5, "randomness": 0.25, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": "disc13", "emit": {"box": Vector2(4, 2)}, "dir": 90 - side * 90 - side * 6, "spread": 7,
			"speed": [35, 110], "damping": [70, 110], "gravity": Vector2(0, -26), "scale": [0.85, 1.3],
			"scale_curve": [[0, 0.55], [0.3, 1.0], [1, 1.5]], "ramp": cloud})
		emit(roll, t_hit)
	var climb := particles("Climb", {"layer": "soft", "at": hit + Vector2(0, -4), "amount": 6, "lifetime": 1.6, "randomness": 0.25,
		"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(6, 5)},
		"dir": -85, "spread": 20, "speed": [30, 70], "damping": [40, 60], "gravity": Vector2(0, -18), "scale": [1.0, 1.4],
		"scale_curve": [[0, 0.55], [0.3, 1.0], [1, 1.5]], "ramp": cloud})
	emit(climb, t_hit)
	var settle := particles("Settle", {"layer": "soft", "at": Vector2(x_hit + 10, -1), "amount": 10, "lifetime": 0.5,
		"randomness": 0.4, "emitting": false, "texture": "disc5", "emit": {"box": Vector2(50, 0.5)}, "dir": -90, "spread": 80,
		"speed": [8, 30], "damping": [30, 60], "scale_curve": [[0, 0.6], [1, 1.2]],
		"ramp": gradient([Color(dust2, 0.6), Color(dust2, 0.4), Color(dust2, 0.2)])})
	emit(settle, t_hit + 0.3, t_hit + 1.1)
