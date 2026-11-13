# reimagined-from: src/fx/arcane/arcane-orb.js@ed84392d5cda7e6eb8bdabf24c8b63b98a721570
# Arcane orb: A floating orb of smoky violet glass with a swirl turning round a white-hot heart, two tilted rings of light orbiting behind and in front.
# loop, 2.40 s, 136x112 canvas, origin [68.0, 104.0], backdrop ground, stand-in 0
# The orb is a canvas shader (fx/arcane/_orb.gdshader: glass, swirl, heart, rims and highlights off the loop's clock)
# bobbing on keys; each tilted ring is a shader drawn twice (_orbit.gdshader: its far half behind the orb, its near
# half in front) with light riding its beads; eight motes orbit on keyed paths, crossing behind and in front; sparks
# drift off the orb (particles); a glint twinkles on the highlight; light on the floor and round the orb.
extends "res://build/fx/arcane/_arcane.gd"

const D := 2.4
const RAD := 17.0
const Y0 := -52.0
const RINGS := [[31.0, 0.24, 0.36, 3, 2.0, 0.0], [27.0, 0.3, -0.55, 2, -3.0, 1.0]]
const SEED := 6


func cy(t: float) -> float:
	return Y0 + sin(t / D * TAU) * 2.0


func make() -> void:
	var bob := group("Bob", {"at": Vector2(0, Y0)})
	keyf(bob, "position", func(t: float): return Vector2(0, cy(t)))

	# the floor: a lit line under it and a glow, stronger as it bobs down
	var fl := glow("FloorLight", 37, {"radius": 36, "color": C[4], "alpha": 0.26}, {"at": Vector2(0, -1)})
	keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.26 - 0.04 * (cy(t) - Y0) / 2.0)
	var cols := []
	var offs := []
	for i in 9:
		var u := absf(i / 8.0 * 2.0 - 1.0)
		cols.append(Color(C[6] if u < 0.3 else C[5], clampf((1.1 - u) * 0.9, 0.0, 1.0)))
		offs.append(i / 8.0)
	var pts := PackedVector2Array()
	for x in 42:
		pts.append(Vector2(x - 20, 0.5))
	var line_floor := line("FloorLine", pts, {"gradient": gradient(cols, offs, true), "back": true})
	keyf(line_floor, "modulate:a", func(t: float): return (0.9 - 0.15 * (cy(t) - Y0) / 2.0) / 0.9)
	glow("Aura", 61, {"radius": 60, "color": C[4], "alpha": 0.36}, {"parent": bob})

	# behind: the far halves of the rings and the motes passing behind
	for i in RINGS.size():
		orbit("RingBack%d" % i, RINGS[i], false, bob)
	# the orb
	var orb := shape("Orb", arcane_shader("orb"), Vector2(40, 40), {"rad": RAD, "c1": C[1], "c2": C[2], "c4": C[4], "c5": C[5],
		"c6": C[6], "white": Color.WHITE}, {"parent": bob})
	loop_t(orb)
	var heart := glow("Heart", 21, {"radius": 20, "color": C[6], "alpha": 0.26}, {"parent": bob})
	keyf(heart, "material:shader_parameter/alpha", func(t: float): return 0.26 * (0.85 + 0.15 * sin(t / D * TAU * 3)))
	glow("RimLight", 24, {"radius": RAD, "thickness": 6, "color": C[5], "alpha": 0.25}, {"parent": bob})
	# in front: the near halves
	for i in RINGS.size():
		orbit("RingFront%d" % i, RINGS[i], true, bob)
	motes(bob)
	var glint := sparkle("Glint", Vector2(-RAD * 0.42, -RAD * 0.5), 1.5, C[6], C[5], {"parent": bob})
	keyf(glint, "material:shader_parameter/arm", func(t: float): return 1.5 + maxf(0.0, sin(t / D * TAU * 2)) * 2.0)
	var glint_light := glow("GlintLight", 12, {"radius": 9, "color": C[6], "alpha": 0.3}, {"parent": bob, "at": Vector2(-RAD * 0.42, -RAD * 0.5)})
	keyf(glint_light, "material:shader_parameter/radius", func(t: float): return 4 + 2 * roundf(1.5 + maxf(0.0, sin(t / D * TAU * 2)) * 2.0))

	# sparks drifting off the orb, rising
	var drift := particles("Drift", {"parent": bob, "amount": 4, "lifetime": 1.0, "texture": "dot1", "emit": {"ring": [RAD + 1, RAD + 1]},
		"gravity": Vector2(0, -16), "initial": gradient([C[6], C[5]]), "alpha_curve": [[0, 1], [0.6, 0.7], [1, 0]]})
	radial_speed(drift, 10, 18)
	life_rand(drift, 0.4)


func orbit(name: String, R: Array, near: bool, parent: Node) -> void:
	var o := shape(name, arcane_shader("orbit"), Vector2(R[0] * 2 + 8, R[0] * 2 + 8), {"r": R[0], "sy": R[1], "rot": R[2],
		"phase": R[5], "beads": float(R[3]), "turn": R[4], "near": 1.0 if near else 0.0, "dot_near": C[5], "dot_far": C[4],
		"c5": C[5], "c6": C[6], "white": Color.WHITE}, {"parent": parent, "back": not near})
	loop_t(o)
	# light riding each bead on this side
	for b in int(R[3]):
		var bl := glow("%sBead%d" % [name, b], 8, {"radius": 7 if near else 5, "color": C[6], "alpha": 0.5 if near else 0.25}, {"parent": parent})
		var bb := b
		keyf(bl, "position", func(t: float):
			var ph := t / D
			var g: float = ph * TAU * R[4] + bb * TAU / float(R[3])
			return ring_pos(R, ph, g))
		keyf(bl, "visible", func(t: float):
			var g: float = t / D * TAU * R[4] + bb * TAU / float(R[3])
			return (sin(g) > 0.0) == near, 0.0, -1.0, 30.0, "nearest")


func ring_pos(R: Array, ph: float, g: float) -> Vector2:
	var rot: float = R[2] + 0.12 * sin(ph * TAU + R[5])
	var lx: float = cos(g) * R[0]
	var ly: float = sin(g) * R[0] * R[1]
	return Vector2(lx * cos(rot) - ly * sin(rot), lx * sin(rot) + ly * cos(rot))


## Eight motes orbiting on tilted paths: a bright head and a short trail, in front of the orb on the near half of their
## path and behind it on the far half (two sets of three pixels, one shown at a time).
func motes(parent: Node) -> void:
	for i in 8:
		var head := group("Mote%d" % i, {"parent": parent})
		var front := group("Front", {"parent": head})
		var back := group("Back", {"parent": head})
		var dir := 1 if i % 2 else -1
		rect("Head", Rect2(0, 0, 1, 1), Color.WHITE, {"parent": front})
		rect("Tail", Rect2(-dir, 0, 1, 1), C[6], {"parent": front})
		var tail2 := rect("Tail2", Rect2(-2 * dir, 0, 1, 1), C[4], {"parent": front})
		tail2.modulate.a = 0.6
		rect("Head", Rect2(0, 0, 1, 1), C[5], {"parent": back, "back": true})
		var bt := rect("Tail", Rect2(-dir, 0, 1, 1), C[4], {"parent": back, "back": true})
		bt.modulate.a = 0.6
		var ii := i
		keyf(head, "position", func(t: float): return mote_at(ii, t / D).floor(), 0.0, -1.0, 30.0, "nearest")
		keyf(front, "visible", func(t: float): return mote_z(ii, t / D) > 0.0, 0.0, -1.0, 30.0, "nearest")
		keyf(back, "visible", func(t: float): return mote_z(ii, t / D) <= 0.0, 0.0, -1.0, 30.0, "nearest")
		var ml := glow("Light", 6, {"radius": 5, "color": C[6], "alpha": 0.35}, {"parent": front, "at": Vector2(0.5, 0.5)})
		ml.z_index = 2


func mote_a(i: int, ph: float) -> float:
	return fmod(i * 2.4 + SEED, TAU) + ph * TAU * (1 if i % 2 else -1) * (1 + (i % 3))


func mote_z(i: int, ph: float) -> float:
	return sin(mote_a(i, ph))


func mote_at(i: int, ph: float) -> Vector2:
	var a := mote_a(i, ph)
	var rr := RAD + 5 + fmod(i * 0.37, 1.0) * 12
	var tilt := (fmod(i * 0.71, 1.0) - 0.5) * 1.4
	var x0 := cos(a) * rr
	return Vector2(x0 * cos(tilt), x0 * sin(tilt) + sin(a) * rr * 0.28)
