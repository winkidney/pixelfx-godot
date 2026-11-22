# reimagined-from: src/fx/explosions/firework-rocket.js@6e11a9b0ea200b9e36d80d5e2889f9138cc5f3ec
# Firework rocket: a rocket fizzes off the ground on a sparkling gold trail, coasts, and bursts into a palm: heavy
# gold fronds arc out, droop on glittering trails and crackle at the tips.
# The rocket (a little tube on a stick, its flickering tail) rides the original's climb curve, keyed every frame; it
# carries emitters for its spitting sparks, the glitter it leaves hanging and a thread of smoke. At the top a white
# heart and a turning eight-ray flare (Line2Ds) burst with sparks and a puff of smoke; nine fronds follow the
# original's drag-and-gravity arcs (replayed in the build script into keys): each a hot head, a trail emitter
# leaving gold dots that cool and dither out, glitter shed along the way and a crackle of pops where it dies.
extends "res://addons/pixelfx_particles/core/build.gd"

const FLY := 1.05
const HIGH := 192.0
const DRAG := 1.35
const G := 105.0
const TRAIL := 1.15


static func out_quad(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func at(t: float) -> Vector2:
	return Vector2(sin(t * 8.0) * 1.6 * (t / FLY), -8.0 - HIGH * out_quad(clampf(t / FLY, 0.0, 1.0)))


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var T: PackedColorArray = root.ramps.tips
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var smoke_c := Color("#4a4458")
	keep_colour(smoke_c)

	# ignition: a light on the ground, a spray of sparks and a puff of smoke
	var ign := glow("IgnitionLight", 26, {"radius": 24, "color": C[4], "alpha": 0.7}, {"at": Vector2(0, -14)})
	var ik := []
	for i in 12:
		var t := i * 0.35 / 11.0
		var k := 1.0 - t / 0.35
		ik.append([t, 0.7 * k * k])
	key(ign, "material:shader_parameter/alpha", ik)
	var sp_ramp := gradient([C[6], C[5], C[4], C[3]], [0.0, 0.4, 0.7, 0.85])
	particles("IgnitionSparks", {"at": Vector2(0, -2), "amount": 18, "lifetime": 0.4, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.6, "texture": "streak3", "align": true, "dir": -90, "spread": 69, "speed": [50, 140],
		"damping": [150, 250], "gravity": Vector2(0, 430), "ramp": sp_ramp})
	particles("IgnitionSmoke", {"layer": "soft", "at": Vector2(0, -2), "amount": 5, "lifetime": 1.0, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.4, "texture": "disc9", "emit": {"box": Vector2(3, 1)}, "dir": -90, "spread": 70,
		"speed": [5, 20], "damping": [20, 30], "scale": [0.7, 1.1], "scale_curve": [[0, 0.6], [1, 1.5]],
		"ramp": gradient([Color("#5a5468", 0.45), Color("#5a5468", 0.3), Color("#5a5468", 0.15), Color("#5a5468", 0.0)], [0.0, 0.3, 0.6, 0.9])})

	# the rocket: a little tube on a stick, a white-hot tail flickering under it, and what it leaves behind
	var rocket := group("Rocket")
	var body := group("Body", {"parent": rocket})
	rect("Stick", Rect2(0, 4, 1, 8), Color("#5a4030"), {"parent": body})
	rect("Tube", Rect2(-1, -3, 3, 7), Color("#b8303a"), {"parent": body})
	rect("Lit", Rect2(-1, -3, 1, 1), Color("#e86070"), {"parent": body})
	rect("Cap", Rect2(0, -4, 1, 1), Color("#d8d0c0"), {"parent": body})
	var tail := line("Tail", PackedVector2Array([Vector2(0.5, 4), Vector2(0.5, 7)]), {"width": 1,
		"gradient": gradient([Color.WHITE, C[5]], [0.0, 0.4]), "parent": body})
	glow("RocketLight", 11, {"radius": 9, "color": C[4], "alpha": 0.6}, {"at": Vector2(0, 5), "parent": body})
	var spit := particles("Spit", {"parent": rocket, "at": Vector2(0, 4), "amount": 32, "lifetime": 0.36, "randomness": 0.6,
		"texture": "streak3", "align": true, "dir": 90, "spread": 26, "speed": [20, 90], "damping": [200, 300],
		"gravity": Vector2(0, 430), "ramp": sp_ramp})
	var glitter := particles("ClimbGlitter", {"parent": rocket, "at": Vector2(0, 4), "amount": 20, "lifetime": 0.9,
		"randomness": 0.5, "texture": "dot1", "emit": {"box": Vector2(1.5, 2)}, "dir": 90, "spread": 30, "speed": [5, 20],
		"initial": gradient([C[5], Color.WHITE]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
	var thread := particles("ClimbSmoke", {"parent": rocket, "layer": "soft", "at": Vector2(0, 5), "amount": 18, "lifetime": 1.1,
		"randomness": 0.4, "texture": "disc3", "dir": 90, "spread": 30, "speed": [4, 12], "damping": [10, 20],
		"scale_curve": [[0, 0.8], [1, 1.6]],
		"ramp": gradient([Color(smoke_c, 0.45), Color(smoke_c, 0.3), Color(smoke_c, 0.15), Color(smoke_c, 0.0)], [0.0, 0.3, 0.6, 0.9])})
	for e in [spit, glitter, thread]:
		emit(e, 0.0, FLY)
	show(body, 0.0, FLY)
	var path := []
	var flick := []
	var n := int(ceil(FLY * 60.0))
	for i in n + 1:
		var t := i / 60.0
		path.append([t, at(t)])
		var fl := 2.0 + (1.0 if sin(t * 70.0) > 0.0 else 0.0)
		flick.append([t, PackedVector2Array([Vector2(0.5, 4), Vector2(0.5, 4 + fl + 1)])])
	key(rocket, "position", path)
	key(tail, "points", flick, "nearest")

	# the burst: a white heart for two frames, a flare of eight rays turning, light, sparks and a puff of smoke
	var B := at(FLY)
	var big := glow("BurstLight", 84, {"radius": 82, "color": C[4], "alpha": 0.0}, {"at": B})
	var bk := []
	var br := []
	for i in 49:
		var t := FLY + i * 1.6 / 48.0
		var k := 1.0 - (t - FLY) / 1.6
		bk.append([t, 0.8 * k * k])
		br.append([t, 82.0 * (0.55 + 0.45 * k)])
	bk.push_front([FLY - 0.001, 0.0])
	key(big, "material:shader_parameter/alpha", bk)
	key(big, "material:shader_parameter/radius", br)
	var pop := glow("BurstFlash", 42, {"radius": 40, "color": Color.WHITE, "alpha": 0.0}, {"at": B})
	key(pop, "material:shader_parameter/alpha", [[FLY - 0.001, 0.0], [FLY, 0.6], [FLY + 0.04, 0.15], [FLY + 0.08, 0.0]])
	var heart := ring("Heart", 4, {"radius": 2.5, "color": Color.WHITE}, {"at": B})
	show(heart, FLY, FLY + 0.07)
	var flare_light := glow("FlareLight", 42, {"radius": 40, "color": C[4], "alpha": 0.0}, {"at": B})
	var fl_k := [[FLY - 0.001, 0.0]]
	var fl_r := []
	var rays := []
	var ray_g := gradient([Color.WHITE, C[5], C[4]], [0.0, 0.3, 0.65])
	for i in 8:
		rays.append(line("Ray%d" % i, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"width": 1, "gradient": ray_g, "at": B}))
	var ray_keys := [[], [], [], [], [], [], [], []]
	var ray_a := [[], [], [], [], [], [], [], []]
	for j in 17:
		var b := j * 0.26 / 16.0
		var u := b / 0.26
		var L := 30.0 * pow(1.0 - u, 1.3)
		fl_k.append([FLY + b, 0.35 if j < 16 else 0.0])
		fl_r.append([FLY + b, 4.0 + L * 1.2])
		for i in 8:
			var an := u * 0.5 + i * TAU / 8.0
			var len_i := L * 0.45 if i % 2 == 1 else L
			ray_keys[i].append([FLY + b, PackedVector2Array([Vector2.ZERO, Vector2(cos(an), sin(an)) * maxf(len_i, 0.5)])])
	for i in 8:
		key(rays[i], "points", ray_keys[i])
		show(rays[i], FLY, FLY + 0.26)
	key(flare_light, "material:shader_parameter/alpha", fl_k)
	key(flare_light, "material:shader_parameter/radius", fl_r)
	var bsparks := particles("BurstSparks", {"at": B, "amount": 30, "lifetime": 0.35, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.5, "emitting": false, "texture": "streak3", "align": true, "dir": 0, "spread": 180, "speed": [40, 160],
		"damping": [80, 160], "gravity": Vector2(0, 430), "ramp": sp_ramp})
	emit(bsparks, FLY)
	var puff := particles("BurstSmoke", {"layer": "soft", "at": B, "amount": 4, "lifetime": 2.2, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.3, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(4, 4)},
		"dir": 0, "spread": 180, "speed": [5, 20], "damping": [15, 25], "scale": [0.9, 1.4],
		"scale_curve": [[0, 0.6], [1, 1.5]],
		"ramp": gradient([Color(smoke_c, 0.3), Color(smoke_c, 0.2), Color(smoke_c, 0.12), Color(smoke_c, 0.0)],
			[0.0, 0.2, 0.5, 0.8])})
	emit(puff, FLY)

	# the palm: nine heavy comets thrown up and out, replayed with the original's drag and gravity
	var trail_ramp := gradient([C[6], C[5], C[4], C[3], C[2], Color(C[2], 0.0)], [0.0, 0.08, 0.25, 0.5, 0.75, 1.0])
	for i in 9:
		var a := -PI / 2.0 + ((i - 4) / 4.0) * 1.4 + rng.randf_range(-0.1, 0.1)
		var spd := rng.randf_range(180, 210) * (1.0 - 0.12 * absi(i - 4) / 4.0)
		var life := rng.randf_range(1.8, 2.15)
		var v := Vector2(cos(a), sin(a)) * spd
		var x := B
		var head := group("Frond%d" % i, {"at": B})
		var pts := []
		var dt := 1.0 / 120.0
		var age := 0.0
		var step := 0
		while age < life:
			if step % 2 == 0:
				pts.append([FLY + age, x])
			v.x -= v.x * DRAG * dt
			v.y -= v.y * DRAG * dt - G * dt
			x += v * dt
			age += dt
			step += 1
		var death := FLY + life
		key(head, "position", pts)
		show(head, FLY)
		# the head: a 2 px white-hot bead with gold arms, flickering as it dies, and its light
		var arms := sprite("Arms", "disc4", {"parent": head, "modulate": C[5]})
		show(arms, FLY, FLY + life * 0.6)
		var bead := sprite("Bead", "dot2", {"parent": head})
		key(bead, "modulate", [[FLY, Color.WHITE], [FLY + life * 0.5, C[6]]], "nearest")
		var blink := [[0.0, false], [FLY, true]]
		var tb := FLY + life * 0.8
		var seed := rng.randf_range(0, 100)
		while tb < death:
			blink.append([tb, sin(tb * 55.0 + seed) >= 0.0])
			tb += 1.0 / 60.0
		blink.append([death, false])
		key(bead, "visible", blink, "nearest")
		var hl := glow("HeadLight", 12, {"radius": 10, "color": C[4], "alpha": 0.6}, {"parent": head})
		key(hl, "material:shader_parameter/alpha", [[FLY, 0.6], [death - 0.001, 0.3], [death, 0.0]])
		# the trail: gold dots left where it has been, cooling and dithering out over 1.15 s
		var trail := particles("Trail", {"parent": head, "amount": 150, "lifetime": TRAIL, "texture": "dot2", "emitting": false,
			"scale_curve": [[0, 1.0], [0.69, 1.0], [0.7, 0.5], [1, 0.5]], "ramp": trail_ramp,
			"alpha_curve": [[0, 1.0], [0.5, 0.75], [0.8, 0.5], [1, 0.0]]})
		# each frame's dots fly back along the stretch the head just covered and stop there (a velocity limit that
		# drops to 0 after a frame), so the trail is a line however far the head moved in a frame
		var tm: ParticleProcessMaterial = trail.process_material
		tm.velocity_limit_curve = curve([[0.0, 400.0], [0.028, 400.0], [0.03, 0.0], [1.0, 0.0]], 400.0)
		var dirs := []
		var speeds := []
		for j in range(1, pts.size()):
			var dv: Vector2 = pts[j][1] - pts[j - 1][1]
			var vel: Vector2 = dv / (pts[j][0] - pts[j - 1][0])
			var back: Vector2 = -vel.normalized()
			dirs.append([pts[j - 1][0], Vector3(back.x, back.y, 0)])
			speeds.append([pts[j - 1][0], vel.length()])
		key(trail, "process_material:direction", dirs)
		key(trail, "process_material:initial_velocity_max", speeds)
		emit(trail, FLY, death)
		show(trail, FLY, death)
		key(trail, "modulate:a", [[FLY, 1.0], [FLY + life * 0.55, 1.0], [death, 0.8]])
		# glitter shed all along: specks that hang, twinkle and drift down
		var shed := particles("Glitter", {"parent": head, "amount": 34, "lifetime": 1.0, "randomness": 0.5, "texture": "dot1",
			"emitting": false, "emit": {"box": Vector2(1, 1)}, "dir": 90, "spread": 40, "speed": [0, 14], "damping": [4, 8],
			"initial": gradient([C[5], C[5], C[5], Color.WHITE, Color.WHITE]), "alpha_curve": [[0, 1], [0.5, 1], [0.75, 0.5], [1, 0]]})
		emit(shed, FLY, minf(death, root.duration - 1.0))
		# where it burns out: a crackle of little pops
		var end: Vector2 = pts[-1][1]
		var pops := particles("Pops%d" % i, {"at": end, "amount": 4, "lifetime": 0.12, "one_shot": true, "explosiveness": 0.0,
			"emitting": false, "texture": "spark5", "emit": {"box": Vector2(5, 5)}, "initial": gradient([Color.WHITE, T[3]]),
			"alpha_curve": [[0, 0.4], [0.5, 1], [1, 0.3]]})
		emit(pops, death)
