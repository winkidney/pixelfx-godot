# reimagined-from: src/fx/critters/bird.js@e07fc4063a8a120d0226f0dd9dbce0327ec33d7e
# Bird: A songbird flies in place: bursts of wingbeats that lift its body on each downstroke, a glide on spread wings, its tail fanning, a loose feather drifting away.
# loop, 2.40 s, 112x80 canvas, origin [56.0, 40.0], backdrop sky
# ramp breast: #4a1a0e #a8441c #e8783a #ffb070
# ramp palette: #0a0e1e #18244a #24407a #3466aa #5a94d4 #9cc8f0 #eaf6ff
# The bird is the original's own body cells (critter()); the see-through smear of the wing on each downstroke is a
# keyed polygon (soft layer), the loose feather six particles placed frame by frame on the original's drift, and the
# moonlight on its back a keyed light riding the body's lift.
extends "res://build/fx/critters/_critters.gd"

const POSE := {
	"up": [[0, 0], [-1, -8], [-5, -15], [-8, -13.5], [-10.5, -10.5], [-11, -7], [-9, -3], [-6, 1]],
	"mid": [[0, 0], [-3, -2.5], [-9, -2.5], [-10.5, -0.5], [-10, 1.2], [-8.5, 2], [-7, 2.2], [-5, 2]],
	"down": [[0, 0], [-1, 6], [-3.5, 12], [-6, 11], [-7.5, 8.5], [-8, 6], [-7, 3], [-5, 2]],
	"fold": [[0, 0], [-3, -4], [-10, -5.5], [-11, -4], [-10, -2.5], [-8.5, -1], [-7, 0.5], [-5, 1.5]],
	"glide": [[0, 0], [-2, -5], [-7, -10], [-10, -9], [-12, -6.5], [-11.5, -3.5], [-9, -1], [-6, 1]],
}
const FLAPS := 4.0
const GLIDE := 1.5


static func mix_pose(a: Array, b: Array, u: float) -> Array:
	var out := []
	for i in a.size():
		out.append([lerpf(a[i][0], b[i][0], u), lerpf(a[i][1], b[i][1], u)])
	return out


func wing(t: float) -> Dictionary:
	t = jmod(t, D)
	if t < GLIDE:
		var u := fmod((t / GLIDE) * FLAPS, 1.0)
		if u < 0.4:
			var k := in_out_sine(u / 0.4)
			return {"pts": mix_pose(POSE.up, POSE.mid, k * 2.0) if k < 0.5 else mix_pose(POSE.mid, POSE.down, k * 2.0 - 1.0), "down": true, "u": u}
		var k2 := in_out_sine((u - 0.4) / 0.6)
		return {"pts": mix_pose(POSE.down, POSE.fold, k2 * 2.0) if k2 < 0.5 else mix_pose(POSE.fold, POSE.up, k2 * 2.0 - 1.0), "down": false, "u": u}
	var g := (t - GLIDE) / (D - GLIDE)
	return {"pts": mix_pose(mix_pose(POSE.up, POSE.glide, smoothx(0.0, 0.15, g)), POSE.up, smoothx(0.85, 1.0, g)), "down": false, "u": 0.0}


func lift(t: float) -> float:
	t = jmod(t, D)
	var y := 0.0
	for k in 6:
		if wing(t - k * 0.02).down:
			y -= 0.45
	if t >= GLIDE:
		y += 2.2 * sin(PI * ((t - GLIDE) / (D - GLIDE)))
	return y + 1.2


func make() -> void:
	# the wing a moment before, see-through, under the body on the downstroke
	smear("Smear", C[6], 0.42, func(i: int, t: float) -> PackedVector2Array:
		var w := wing(t)
		var out := PackedVector2Array()
		if not (w.down and w.u > 0.1):
			return out
		var s := t - 0.05
		var dy := jround(lift(s))
		for q in wing(s).pts:
			out.append(Vector2(1.0 + q[0], -2.0 + q[1] + dy))
		return out)
	critter()
	# the loose feather: five dots along its shaft and a darker tip, rocking as it drifts down
	var rows := []
	for i in NF:
		var t := ft(i)
		var fa := jmod(t - 0.45, D)
		var r := []
		if fa < 1.8:
			var fx := -6.0 - 14.0 * fa - 3.0 * sin(fa * 5.0)
			var fy := 4.0 + 9.0 * fa + 1.5 * cos(fa * 5.0) * fa
			var rock := sin(fa * 5.0) * 0.8
			var a := minf(1.0, (1.8 - fa) * 2.0)
			for j in range(-2, 3):
				r.append(dot_e(fx + j * cos(rock), fy + j * sin(rock) * 0.8, 5 if j < 0 else 4, a))
			r.append(dot_e(fx + 2.6 * cos(rock), fy + 2.6 * sin(rock) * 0.8, 3, a))
		rows.append(r)
	table("Feather", K_DOT, rows, {"light": false})
	glows("Moonlight", func(i: int, t: float) -> Array:
		return [{"c": C[5], "p": Vector2(2, lift(t) - 6.0), "r": 16.0, "k": 0.12}])
