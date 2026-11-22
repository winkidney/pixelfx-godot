# reimagined-from: src/fx/scifi/jetpack.js@922e0d1df966cbb7758a494d6c11cda60c9b4c7b
# Jetpack: Twin thrusters fire straight down: white-hot cores with shock diamonds inside ragged flames, puffs that cool into smoke billowing below, lit by the fire.
# loop, 2.00 s, 96x116 canvas, origin [48.0, 30.0], backdrop dark
# The exhaust is the original's own Ghosts (_ghost.gdshader): flame puffs shed off each plume's tip cooling down the
# fire ramp and turning into smoke that billows below (worked out here from each puff's flight, as the original
# does when it dies), more smoke driven down, sparks spat out, embers drifting off. The plumes (cones of heat torn
# by the original's tileFbm noise, shock diamonds breathing in their cores) and the pack (tanks, spine, glowing
# nozzles, bobbing with the thrust) are shaders keyed by the loop clock and each frame's jitter
# (fx/scifi/_jetpack.gdshader); the fire's light is _jetpack_light.gdshader.
extends "res://build/fx/scifi/_scifi.gd"

const GAP := 8.0


func make() -> void:
	var D: float = root.duration
	var S: int = meta.options.seed
	var LEN: float = meta.options.length
	var H: PackedColorArray = fit(root.ramps.metal, 6)
	var NF := int(round(D * 30.0))
	var canvas := Vector2(root.canvas_size)
	var mid := -Vector2(root.origin) + canvas / 2.0

	# each frame's jitter: the plumes' x and length, the pack's bob
	var data := Image.create(NF, 2, false, Image.FORMAT_RGBAF)
	for i in NF:
		var t := frame_t(i)
		var ph := t / D
		var f := int(floor(t * 30.0)) % NF
		var v := []
		for s in [-1, 1]:
			var cx: float = s * GAP + (s * 0.5 if rand([S, f, s]) < 0.15 else 0.0)
			var L: float = LEN * (0.92 + 0.08 * sin(TAU * 7.0 * ph + s) + 0.06 * (rand([S, f, s, 1]) - 0.5))
			v += [cx, L]
		data.set_pixel(i, 0, Color(v[0], v[1], v[2], v[3]))
		data.set_pixel(i, 1, Color(floorf(sin(TAU * 12.0 * ph) * 0.6 + 0.5), 0, 0, 0))
	var dtex := asset("_jitter", data)

	# the exhaust, as the original's ghosts() lays it out
	ghosts_begin(D)
	var rn := JsRng.new(S)
	var F := C
	for s in [-1.0, 1.0]:
		for i in 26:
			var born := rn.range(0, D)
			var x: float = s * GAP + rn.range(-1.5, 1.5)
			var y := LEN * rn.range(0.55, 0.85)
			var vx := rn.range(-10, 10)
			var vy := rn.range(70, 130)
			var life := rn.range(0.22, 0.4)
			var sz := rn.range(2.2, 3.4)
			ghost(born, FIRE, x, y, vx, vy, life, null, sz, PF_SMOKES | (PF_BIG if rn.chance(0.5) else 0))
		for i in 10:
			var born := rn.range(0, D)
			var x: float = s * GAP + rn.range(-3, 3)
			var y := LEN + rn.range(2, 8)
			var vx: float = s * rn.range(0, 14)
			var vy := rn.range(40, 80)
			var life := rn.range(1.1, 1.6)
			ghost(born, SMOKE, x, y, vx, vy, life, null, rn.range(3, 5), PF_BIG)
		for i in 10:
			var born := rn.range(0, D)
			var x: float = s * GAP + rn.range(-1, 1)
			var y := LEN * rn.range(0.3, 0.7)
			var vx: float = s * rn.range(-40, 60)
			var vy := rn.range(80, 200)
			ghost(born, SPARK, x, y, vx, vy, rn.range(0.2, 0.45))
		for i in 5:
			var born := rn.range(0, D)
			var x: float = s * GAP + rn.range(-2, 2)
			var y := LEN * rn.range(0.6, 1.0)
			var vx: float = s * rn.range(10, 40)
			var vy := rn.range(20, 60)
			var life := rn.range(0.6, 1.1)
			ghost(born, EMBER, x, y, vx, vy, life, F[4], rn.range(0.8, 1.6))
	var o := {"sparks": [Color.WHITE, F[6], F[5], F[4]], "box": [-46, -28, 46, 84], "back": false}
	var ob := o.duplicate()
	ob.only = "back"
	ghosts(ob)
	var params := {"t": 0.0, "seed": S, "data": dtex, "pal": C, "metal": H}
	var pl := params.duplicate()
	pl.mode = 0
	var plumes := shape("Plumes", sh("jetpack"), canvas, pl, {"at": mid})
	var pk := params.duplicate()
	pk.mode = 1
	var pack := shape("Pack", sh("jetpack"), canvas, pk, {"at": mid})
	var of := o.duplicate()
	of.only = "front"
	ghosts(of)
	var lit := shape("Light", sh("jetpack_light"), canvas, {"t": 0.0, "length_": LEN, "data": dtex, "pal": C}, {"at": mid})
	for n in [plumes, pack, lit]:
		clock(n)
