# Shared by the lightning build scripts: core/build.gd plus what every lightning effect needs.
#   volt()    a bolt inked as the originals ink one (fx/lightning/_volt.gd): halo, body, white core, forks, light
#   flash()   a light that flares and dies (the original's Lights.add), keyed frame by frame
#   orb()     stacked discs (the originals' layered circles: a halo, a body, a white heart)
#   sparks()  the originals' SPARK particles: streaks thrown, falling and bouncing, white cooling to cyan
#   frames_keys() helps key a value every frame from the original's formula.
extends "res://addons/pixelfx_particles/core/build.gd"

const VOLT := preload("res://addons/pixelfx_particles/fx/lightning/_volt.gd")
const FPS := 30.0


## The effect's eight palette colours (the original's C = fit(o.palette, 8)).
func pal() -> PackedColorArray:
	return root.ramps.palette


## A bolt from a to b. o: style (0 stroke, 1 crackle, 2 trace), k, thick, hero, jag, forks, bow, rate (re-rolls a
## second off the clock; 0: key "step"), seed, light (strength along it; 0: no light node), light_reach, core,
## trace_color, up_to, head (a white head at the tip while up_to < 1), head_light, head_reach, alpha, back, at, parent, visible.
func volt(name: String, a: Vector2, b: Vector2, o: Dictionary = {}) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.set_script(VOLT)
	_place(n, o, o.get("parent"))
	n.from = a
	n.to = b
	n.colors = pal()
	n.style = o.get("style", 0)
	n.k = o.get("k", 1.0)
	n.thick = o.get("thick", 1.0)
	n.hero = o.get("hero", false)
	n.jag = o.get("jag", 0.3)
	n.forks = o.get("forks", 0.35)
	n.bow = o.get("bow", 0.0)
	n.rate = o.get("rate", 15.0)
	n.bolt_seed = o.get("seed", absi(hash(id + name)) % 100000)
	n.light = o.get("light", 0.5 if n.style == 0 else 0.35)
	n.light_reach = o.get("light_reach", 1.0)
	n.core = o.get("core", 0.0)
	n.up_to = o.get("up_to", 1.0)
	n.head = o.get("head", 0.0)
	n.trunk_only = o.get("trunk_only", false)
	n.drift = o.get("drift", 0.0)
	n.drift_top = o.get("drift_top", -224.0)
	n.keep_w = o.get("keep_w", 0.0)
	n.head_light = o.get("head_light", 0.6)
	n.head_reach = o.get("head_reach", 14.0)
	n.alpha = o.get("alpha", 1.0)
	if o.has("trace_color"):
		n.trace_color = o.trace_color
		keep_colour(n.trace_color)
	if o.has("light_color"):
		n.light_color = o.light_color
	if n.light > 0.0 and n.style != 2:
		var l := Node2D.new()
		l.name = "Light"
		n.add_child(l)
		l.material = light
		l.z_index = 1
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return n


## A light that flares at t0 and dies over `life` (the original's Lights.add(x, y, r, c, k, life)): its radius
## shrinks to 0.55 of r and its strength falls as the square of what's left.
func flash(name: String, at: Vector2, r: float, c: Color, k0: float, life: float, t0: float, o: Dictionary = {}) -> ColorRect:
	var g := glow(name, r + 2, {"radius": r, "color": c, "alpha": 0.0}, {"at": at, "back": o.get("back", false)})
	var rad := [[0.0, r]]
	var al := [[0.0, 0.0]]
	if t0 > 0.0:
		al.append([t0 - 0.001, 0.0])
	var n := int(ceil(life * FPS))
	for i in n + 1:
		var tt := minf(life, i / FPS)
		var kk := 1.0 - tt / life
		rad.append([t0 + tt, r * (0.55 + 0.45 * kk)])
		al.append([t0 + tt, k0 * kk * kk])
	key(g, "material:shader_parameter/radius", rad)
	key(g, "material:shader_parameter/alpha", al)
	return g


## Stacked discs at `at`: layers [[radius, colour], ...] biggest first (a halo, a body, a heart). Returns the rings.
func orb(name: String, at: Vector2, layers: Array, o: Dictionary = {}) -> Array:
	var reach: float = o.get("reach", layers[0][0] + 2.0)
	var out := []
	var i := 0
	for L in layers:
		var c: Color = L[1]
		var off: Vector2 = L[2] if L.size() > 2 else Vector2.ZERO
		var oo := {"at": at + off, "back": o.get("back", false)}
		if o.has("parent"):
			oo.parent = o.parent
		out.append(ring("%s%d" % [name, i], reach, {"radius": L[0], "color": c}, oo))
		i += 1
	return out


## The originals' SPARK: a short streak along its flight, white-hot at first, cooling through the sparks ramp,
## falling (0.45 g) with drag and bouncing on the floor. o as particles(); at, amount, dir, spread, speed, lifetime.
func sparks(name: String, o: Dictionary) -> GPUParticles2D:
	var S: PackedColorArray = root.ramps.sparks
	var d := {"texture": "streak3", "align": true, "one_shot": true, "explosiveness": 1.0, "gravity": Vector2(0, 427),
		"damping": [90, 180], "randomness": 0.4, "emitting": false,
		"ramp": gradient([S[0], S[1], S[2], S[3]], [0.0, 0.3, 0.55, 0.85]), "collide": {"bounce": 0.45, "friction": 0.3}}
	d.merge(o, true)
	return particles(name, d)


## f(t) for every frame from t0 to t1 (seconds), keyed half a frame early so a stepped ("nearest") track holds the
## right value however the clock rounds.
func frames_keys(t0: float, t1: float, f: Callable) -> Array:
	var out := []
	var i0 := int(roundf(t0 * FPS))
	var i1 := int(roundf(t1 * FPS))
	for i in range(i0, i1 + 1):
		out.append([maxf(0.0, (i - 0.5) / FPS), f.call(i / FPS)])
	return out


## As core's key(), but a loop's track holds its last key to the end instead of easing back round to its first.
func key(node: Node, prop: String, keys: Array, interp := "linear") -> void:
	super(node, prop, keys, interp)
	var tr := fx.find_track(NodePath(String(root.get_path_to(node)) + ":" + prop), Animation.TYPE_VALUE)
	if tr >= 0:
		fx.track_set_interpolation_loop_wrap(tr, false)


const FIRE := ["#ffffff", "#fff3a6", "#ffe26b", "#ffc23d", "#ff8a2a", "#f2561d", "#c9281f", "#8a1f17", "#4a1712"]


func fire_ramp() -> PackedColorArray:
	var out := PackedColorArray()
	for c in FIRE:
		out.append(Color(c))
		keep_colour(Color(c))
	return out


## Heat left on the floor at x (fx/lightning/_scorch.gdshader): key "heat" (1 fresh .. 0 cold) and "fade".
func scorch(name: String, x: float, rx: float, o: Dictionary = {}) -> ColorRect:
	var ry := maxf(2.5, rx * 0.12)
	var w := ceilf(rx + 1) * 2.0
	keep_colour(Color("#110c16"))
	keep_colour(Color("#1c1522"))
	return shape(name, load("res://addons/pixelfx_particles/fx/lightning/_scorch.gdshader"), Vector2(w, ceilf(ry + 1) * 2.0),
		{"rx": rx, "ry": ry, "fire": fire_ramp(), "soot": Color("#110c16"), "soot2": Color("#1c1522"), "heat": 0.0, "fade": 0.0},
		{"at": Vector2(x, 0), "back": o.get("back", true)})


## The stand-in as the effect's Actor with fx/lightning/_shock_actor.gdshader: key "jolt" / "lift" (an electric
## silhouette) and "flash" / "flash_color" (lit white). Its own colours stay its own (core's actor shader samples
## the texture twice and darkens it).
func shocked_actor() -> Sprite2D:
	var body := actor_node()
	var C := pal()
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/fx/lightning/_shock_actor.gdshader")
	m.set_shader_parameter("ramp", PackedColorArray([C[1], C[2], C[3], C[4], C[5], C[6], C[7]]))
	body.material = m
	return body


## A band round an ellipse centred on `at` (fx/lightning/_band.gdshader), big enough for `reach` px of radius.
## params: radius, thickness, squash, c0..c3 (rim to inside), k, even, side, clip.
func band(name: String, reach: float, params: Dictionary, o: Dictionary = {}) -> ColorRect:
	var sq: float = params.get("squash", 1.0)
	return shape(name, load("res://addons/pixelfx_particles/fx/lightning/_band.gdshader"),
		Vector2(ceilf(reach + 2) * 2, ceilf(reach * sq + 2) * 2), params, o)


## An 8-ray flare at `at` (fx/lightning/_flare.gdshader): key "reach" and "k".
func flare(name: String, reach: float, o: Dictionary = {}) -> ColorRect:
	var C := pal()
	var s := ceilf(reach + 2) * 2
	var oo := o.duplicate()
	oo.at = o.get("at", Vector2.ZERO) + Vector2(0.5, 0.5)
	return shape(name, load("res://addons/pixelfx_particles/fx/lightning/_flare.gdshader"), Vector2(s + 1, s + 1),
		{"reach": 0.0, "k": 1.0, "c6": C[6], "c5": C[5]}, oo)
