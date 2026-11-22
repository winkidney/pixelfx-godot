# reimagined-from: src/fx/lightning/plasma-ball.js@e62a656394968869264a0276372ff743199ca767
# Plasma ball: A glass globe on a dark pedestal: wandering plasma tendrils reach from the core to the glass and fan out in bright feet where they touch it, lighting the stand and floor.
# loop, 3.00 s, 112x104 canvas, origin [56.0, 96.0], backdrop ground
# The pedestal, the glass's tint, rim and specular arc are the original's still pixels (port/props.py, the electrode
# cut out of it); the electrode is stacked discs pulsing; the nine filaments are fx/lightning/_tendril.gd lines whose
# ends wander over the glass on seamless loops computed here (front ones bright and flaring where they touch,
# back ones dim, drawn behind the electrode), jittered every frame; light pools on the floor, fills the glass and
# hugs its rim, all breathing with the pulse.
extends "res://build/fx/lightning/_base.gd"

const N := 90
const G := Vector2(0, -55)
const RG := 24.0
const TENDRILS := 9
const TENDRIL := preload("res://addons/pixelfx_particles/fx/lightning/_tendril.gd")

var _waves := {}


## A smooth value in about -1..1 that comes back to itself every loop (the original's loopNoise): a few sines with
## whole periods per loop, phases and weights fixed by the seed.
func loop_noise(ph: float, radius: float, seed: int) -> float:
	if not _waves.has(seed):
		var r := RandomNumberGenerator.new()
		r.seed = seed
		_waves[seed] = [r.randf_range(0, TAU), r.randf_range(0, TAU), r.randf_range(0, TAU), r.randf_range(0.6, 1.0), r.randf_range(0.2, 0.5)]
	var w: Array = _waves[seed]
	var k := 2 if radius > 1.0 else 1
	return clampf(w[3] * sin(TAU * ph * k + w[0]) * 0.8 + w[4] * sin(TAU * ph * (k + 1) + w[1]) * 0.6 + 0.15 * sin(TAU * ph * 3.0 + w[2]), -1.0, 1.0)


func make() -> void:
	var C := pal()
	var seed := 6
	prop()
	var floor_glow := glow("FloorLight", 54, {"radius": 52, "color": C[3]}, {"at": Vector2(0, -6), "back": true})
	var glass := glow("GlassLight", RG + 16, {"radius": RG + 14, "color": C[3]}, {"at": G})
	var rim := glow("RimLight", RG + 6, {"radius": RG - 1, "thickness": 5, "color": C[3]}, {"at": G})

	var back := []
	var front := []
	for i in TENDRILS:
		back.append(_tendril("Back%d" % i, i, false, C))
	var core := orb("Core", G, [[5.2, C[3]], [3.9, C[5]], [2.2, C[6], Vector2(-0.6, -0.6)], [1.0, Color.WHITE, Vector2(-0.8, -0.8)]])
	var core_glow := glow("CoreLight", 18, {"radius": 16, "color": C[5]}, {"at": G})
	for i in TENDRILS:
		front.append(_tendril("Front%d" % i, i, true, C))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31
	var K := {"fl": [], "gl": [], "rl": [], "cg": [], "c0": [], "c1": [], "c2": [], "c3": []}
	var T := []
	for i in TENDRILS:
		T.append({"end": [], "a": [], "w1": [], "w2": [], "front": [], "rim": []})
	for f in N + 1:
		var ff := f % N
		var ph := ff / float(N)
		var st := maxf(0.0, (f - 0.5) / FPS)
		var pulse := 0.85 + 0.15 * sin(ph * TAU * 6.0) + 0.1 * (rng.randf() - 0.5)
		if f == N:
			pulse = K.fl[0][1] / 0.22
		K.fl.append([st, 0.22 * pulse])
		K.gl.append([st, 0.32 * pulse])
		K.rl.append([st, 0.22 * pulse])
		K.cg.append([st, 0.65 * pulse])
		var cr := 3.6 + 0.5 * pulse
		K.c0.append([st, cr + 1.3])
		K.c1.append([st, cr])
		K.c2.append([st, cr * 0.55])
		K.c3.append([st, cr * 0.25])
		for i in TENDRILS:
			var a := (i + 0.5) / TENDRILS * TAU + 0.9 * loop_noise(ph, 0.9, seed + i * 7)
			var z := loop_noise(ph, 0.7, seed + i * 7 + 3)
			var rho := RG * (0.72 + 0.28 * sqrt(1.0 - minf(1.0, z * z * 1.6)))
			T[i].end.append([st, G + Vector2(cos(a), sin(a)) * rho])
			T[i].a.append([st, a])
			T[i].w1.append([st, loop_noise(ph, 1.1, seed + i * 7 + 5)])
			T[i].w2.append([st, loop_noise(ph, 1.3, seed + i * 7 + 6)])
			T[i].front.append([st, z > -0.15])
			T[i].rim.append([st, rho > RG * 0.93])
	key(floor_glow, "material:shader_parameter/alpha", K.fl, "nearest")
	key(glass, "material:shader_parameter/alpha", K.gl, "nearest")
	key(rim, "material:shader_parameter/alpha", K.rl, "nearest")
	key(core_glow, "material:shader_parameter/alpha", K.cg, "nearest")
	for j in 4:
		key(core[j], "material:shader_parameter/radius", K["c%d" % j], "nearest")
	for i in TENDRILS:
		for n in [back[i], front[i]]:
			key(n, "end", T[i].end, "nearest")
			key(n, "angle", T[i].a, "nearest")
			key(n, "w1", T[i].w1, "nearest")
			key(n, "w2", T[i].w2, "nearest")
			key(n, "rim", T[i].rim, "nearest")
		key(front[i], "visible", T[i].front, "nearest")
		key(back[i], "visible", T[i].front.map(func(k): return [k[0], not k[1]]), "nearest")


func _tendril(name: String, i: int, is_front: bool, C: PackedColorArray) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.set_script(TENDRIL)
	_place(n, {})
	n.centre = G
	n.radius = RG
	n.index = i
	n.front = is_front
	n.tseed = 17
	n.colors = C
	var l := Node2D.new()
	l.name = "Light"
	n.add_child(l)
	l.material = light
	l.z_index = 1
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return n
