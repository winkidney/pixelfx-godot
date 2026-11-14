# What every build script extends. A build script (build/fx/<category>/<name>.gd) describes one effect in make(),
# with the helpers below, and `./pfxp build <id>` saves it as addons/pixelfx_particles/fx/<category>/<name>.tscn:
# an ordinary scene you can open, play and tweak in the editor. See docs/AUTHORING.md.
#
#   extends "res://addons/pixelfx_particles/core/build.gd"
#   func make() -> void:
#       var fire := particles("Flame", {"amount": 40, "lifetime": 0.8, "speed": [20, 40], "texture": "dot2",
#               "ramp": ramp("palette", {"reverse": true})})
#       key(fire, "amount_ratio", [[0.0, 1.0], [1.5, 0.4]])
#
# Coordinates are pixels on the original's canvas, relative to the effect's origin (feet, point of impact, base of a
# torch), y down. Angles are degrees, 0 pointing right, 90 down.
extends RefCounted

const EFFECT := preload("pfx_effect.gd")
const DITHER := preload("../shaders/dither.gdshader")
const LIGHT := preload("../shaders/light.gdshader")
const TEX := "res://addons/pixelfx_particles/textures/"
const META := "res://port/meta.json"
const STEP_EARLY := 0.001   # seconds a "nearest" key moves earlier than asked, so it lands on its own frame
const THIN_SPAN := 64   # most keys one kept key may stand for (thinning stays linear in the keys)

static var _meta := {}

var id := ""
var meta := {}
var root: Node2D
var anim: AnimationPlayer
var fx: Animation
## The scene's shared materials: the colour layer (dither: on/off alpha), the soft colour layer (translucent: smoke,
## dust, mist) and the light layer (additive).
var dither: ShaderMaterial
var soft: ShaderMaterial
var light: ShaderMaterial
## Props (the original's own still pixels, port/props.py) draw exactly as they are: no dither, no palette snap.
var prop_mat: CanvasItemMaterial
var _count := 0
var _twins := []   # [emitter, twin] pairs: the twin gets its emitter's keys at save()
var _cues := 0


static func meta_of(effect_id: String) -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	return _meta.get(effect_id, {})


static func ramps_of(m: Dictionary) -> Dictionary:
	var out := {}
	var opts: Dictionary = m.get("options", {})
	for k in opts:
		var v: Variant = opts[k]
		if v is Array and v.size() > 0 and v.all(func(c): return c is String and String(c).begins_with("#")):
			out[k] = PackedColorArray(v.map(func(c): return Color(c)))
	return out


## Called by the CLI before make().
func begin(effect_id: String) -> void:
	id = effect_id
	meta = meta_of(id)
	assert(not meta.is_empty(), "no meta for " + id)
	root = Node2D.new()
	root.set_script(EFFECT)
	root.name = id.get_file().capitalize().replace(" ", "")
	root.effect_id = id
	root.source = meta.source
	root.duration = meta.duration
	root.loop = meta.loop
	root.fps = meta.fps
	root.canvas_size = Vector2i(meta.size[0], meta.size[1])
	root.origin = Vector2i(meta.origin[0], meta.origin[1])
	root.bg = meta.bg
	root.actor = int(meta.actor)
	root.ramps = ramps_of(meta)
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	var lib := AnimationLibrary.new()
	fx = Animation.new()
	fx.length = meta.duration
	fx.loop_mode = Animation.LOOP_LINEAR if meta.loop else Animation.LOOP_NONE
	lib.add_animation("fx", fx)
	anim.add_animation_library("", lib)
	dither = ShaderMaterial.new()
	dither.shader = DITHER
	dither.resource_name = "Dither"
	soft = ShaderMaterial.new()
	soft.shader = DITHER
	soft.resource_name = "Soft"
	soft.set_shader_parameter("translucent", true)
	light = ShaderMaterial.new()
	light.shader = LIGHT
	light.resource_name = "Light"
	prop_mat = CanvasItemMaterial.new()
	prop_mat.resource_name = "Prop"


## Override: build the effect.
func make() -> void:
	pass


# ------------------------------------------------------------------ colours

## The original option `name` (a colour ramp, darkest first) as a stepped gradient for a colour over life or a lookup.
## o: from, to (the part of the ramp to use, 0..1), reverse (true: brightest first, the usual cooling over a
## particle's life), alpha ([[t, a], ...]: transparency along it, dithered by the colour layer), stops (how many).
func ramp(name: String, o: Dictionary = {}) -> GradientTexture1D:
	var cols: PackedColorArray = root.ramps.get(name, PackedColorArray())
	assert(cols.size() > 0, "%s has no colour ramp '%s' (options: %s)" % [id, name, root.ramps.keys()])
	var a: float = o.get("from", 0.0)
	var b: float = o.get("to", 1.0)
	var n: int = o.get("stops", maxi(1, int(roundf(absf(b - a) * (cols.size() - 1))) + 1))
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	var at := PackedFloat32Array()
	for i in n:
		var u := i / float(maxi(1, n - 1))
		var r := lerpf(a, b, (1.0 - u) if o.get("reverse", false) else u)
		var c := cols[clampi(int(roundf(r * (cols.size() - 1))), 0, cols.size() - 1)]
		c.a = _curve_at(o.get("alpha", []), i / float(n), 1.0)
		offs.append(i / float(n))
		cs.append(c)
		at.append(r)
	g.offsets = offs
	g.colors = cs
	g.set_meta("ramp", name)
	g.set_meta("ramp_at", at)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


## A stepped gradient from explicit colours (hex strings or Colors), evenly spaced unless offsets are given.
func gradient(colors: Array, offsets: Array = [], smooth := false) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR if smooth else Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var cs := PackedColorArray()
	var offs := PackedFloat32Array()
	for i in colors.size():
		cs.append(colors[i] if colors[i] is Color else Color(colors[i]))
		keep_colour(cs[i])
		offs.append(offsets[i] if i < offsets.size() else i / float(colors.size()) if not smooth else i / float(maxi(1, colors.size() - 1)))
	g.offsets = offs
	g.colors = cs
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


## Make the colour layer's palette snap keep this colour (colours that aren't in any of the effect's ramps).
func keep_colour(c: Color) -> void:
	var o := Color(c.r, c.g, c.b, 1.0)
	var extra: PackedColorArray = root.palette_extra
	for r in root.ramps.values():
		if o in r:
			return
	if not o in extra:
		extra.append(o)
		root.palette_extra = extra


## The colour at u (0..1) along ramp `name`.
func color(name: String, u: float) -> Color:
	var cols: PackedColorArray = root.ramps[name]
	return cols[clampi(int(roundf(clampf(u, 0.0, 1.0) * (cols.size() - 1))), 0, cols.size() - 1)]


## A curve through [[t, v], ...] (t in 0..1) as a CurveTexture, for scale and alpha over life.
func curve(points: Array, max_value := 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = max_value
	for p in points:
		c.add_point(Vector2(p[0], p[1]), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


static func _curve_at(points: Array, t: float, d: float) -> float:
	if points.is_empty():
		return d
	if t <= points[0][0]:
		return points[0][1]
	for i in range(1, points.size()):
		if t <= points[i][0]:
			var a: Array = points[i - 1]
			var b: Array = points[i]
			return lerpf(a[1], b[1], (t - a[0]) / maxf(1e-6, b[0] - a[0]))
	return points[-1][1]


# ------------------------------------------------------------------ nodes

func texture(name: Variant) -> Texture2D:
	if name is Texture2D:
		return name
	return load(TEX + String(name) + ".png")


func _place(n: CanvasItem, o: Dictionary, parent: Node = null) -> void:
	(parent if parent != null else root).add_child(n)
	if n is Node2D:
		n.position = o.get("at", Vector2.ZERO)
	# behind the character: -2 (colour) / -1 (light); in front: 1 (colour) / 2 (light). Light goes on top of colour,
	# as the original adds its light buffer over everything once the colour is drawn.
	var lit: bool = o.get("layer", "color") == "light"
	n.z_index = (-1 if lit else -2) if o.get("back", false) else (2 if lit else 1)
	if lit:
		n.material = light
	elif o.get("layer", "color") == "prop":
		n.material = prop_mat
	elif o.get("layer", "color") == "soft":
		n.material = soft
	elif o.get("layer", "color") == "color":
		n.material = dither
	if o.has("modulate"):
		n.modulate = o.modulate
	if o.has("visible"):
		n.visible = o.visible


## GPUParticles2D with a ParticleProcessMaterial. o (all optional):
##   at, back (behind the character), layer ("color": dithered alpha | "soft": real translucency, for smoke and
##   dust | "light": additive | "prop": exactly as drawn, for the original's still pixels), parent
##   amount (16), lifetime (1.0), one_shot, explosiveness, randomness, preprocess (loops: one lifetime), emitting
##   texture ("dot2", "disc5", "glow16", ... or a Texture2D), align (point the texture along the velocity)
##   emit: Vector2.ZERO (a point) | {"box": Vector2} | {"circle": r} | {"ring": [r, inner]} | {"points": PackedVector2Array}
##   | {"points": ..., "normals": PackedVector2Array} (with dir 0: each flies along its normal, length scales speed)
##   dir (degrees, 0 right, -90 up: default -90), spread (degrees either side), speed [min, max], gravity Vector2,
##   damping [min, max], radial [min, max] (acceleration away from the emitter), radial_speed [min, max] (velocity
##   away from it), life_random (0..1: lifetimes vary), tangential [min, max], orbit [min, max] (turns a second),
##   angle [min, max], spin [min, max] (degrees a second), scale [min, max], scale_curve [[t, v], ...],
##   alpha_curve [[t, a], ...], color, ramp (colour over life, from ramp()), initial (a random starting colour),
##   turbulence {strength, scale, speed, influence [min, max]: keep it 0.005..0.03, more stops a particle dead},
##   local (local coordinates), collide {bounce, friction, hide (vanish on contact), size}: needs a ground(),
##   drag (a number: the original's drag k, calibrated onto Godot's friction | true: Godot's own quadratic friction,
##   dv/dt = -0.05 * damping * v^2, on your damping), process_shader + process_params (your own
##   `shader_type particles` shader instead of the material; the canvas material still does the colour layer).
## No sub-emitters or trails: the Compatibility renderer (web, mobile) has neither. A splash where drops land is an
## emitter of its own along the floor; a fire where a brand lands is one that starts when it lands.
func particles(name: String, o: Dictionary = {}) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = name
	_place(p, o, o.get("parent"))
	p.amount = o.get("amount", 16)
	p.lifetime = o.get("lifetime", 1.0)
	p.one_shot = o.get("one_shot", false)
	p.explosiveness = o.get("explosiveness", 0.0)
	p.randomness = o.get("randomness", 0.0)
	p.preprocess = o.get("preprocess", p.lifetime if (root.loop and not p.one_shot) else 0.0)
	p.emitting = o.get("emitting", true)
	p.local_coords = o.get("local", false)
	p.fixed_fps = 60
	p.interpolate = true
	p.use_fixed_seed = true
	_count += 1
	p.seed = absi(hash(id + "/" + name)) % 1000003 + _count
	p.texture = texture(o.get("texture", "dot1"))
	var big: float = 2048.0
	p.visibility_rect = Rect2(-big / 2, -big / 2, big, big)
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.particle_flag_align_y = o.get("align", false)
	m.gravity = _v3(o.get("gravity", Vector2.ZERO))
	var e: Variant = o.get("emit", Vector2.ZERO)
	if e is Dictionary:
		if e.has("box"):
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = _v3(e.box)
		elif e.has("circle"):
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = e.circle
		elif e.has("ring"):
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3(0, 0, 1)
			m.emission_ring_height = 0.0
			m.emission_ring_radius = e.ring[0]
			m.emission_ring_inner_radius = e.ring[1] if e.ring.size() > 1 else e.ring[0]
		elif e.has("points"):
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
			m.emission_point_texture = _points_texture(e.points)
			m.emission_point_count = e.points.size()
			if e.has("normals"):
				# with dir 0, each particle flies along its point's normal, the normal's length scaling its speed
				m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
				m.emission_normal_texture = _points_texture(e.normals)
	var d: float = o.get("dir", -90.0)
	m.direction = Vector3(cos(deg_to_rad(d)), sin(deg_to_rad(d)), 0)
	m.spread = o.get("spread", 0.0)
	_range(m, "initial_velocity", o.get("speed", [0.0, 0.0]))
	_range(m, "damping", o.get("damping", [0.0, 0.0]))
	_range(m, "radial_accel", o.get("radial", [0.0, 0.0]))
	_range(m, "radial_velocity", o.get("radial_speed", [0.0, 0.0]))
	var dg: Variant = o.get("drag", false)
	if dg is bool:
		# true: Godot's friction, dv/dt = -0.05 * damping * v^2 (fast particles slow far more than slow ones)
		m.particle_flag_damping_as_friction = dg
	elif float(dg) > 0.0:
		# a number: the original's drag k (1/s, dv/dt = -k v). Godot has no such damping, only its quadratic friction:
		# pick the friction that carries a particle at the mean speed as far over its life as the original's drag
		var sp: Array = _pair(o.get("speed", [0.0, 0.0]))
		var rs: Array = _pair(o.get("radial_speed", [0.0, 0.0]))
		var v: float = maxf((sp[0] + sp[1]) / 2.0, absf(rs[0] + rs[1]) / 2.0)
		if v < 1.0:
			v = maxf(1.0, (o.get("gravity", Vector2.ZERO) as Vector2).length() * p.lifetime / 2.0)
		var c := friction_for(float(dg), v, p.lifetime)
		m.particle_flag_damping_as_friction = true
		m.damping_min = c / 0.05
		m.damping_max = c / 0.05
	m.lifetime_randomness = o.get("life_random", 0.0)
	_range(m, "tangential_accel", o.get("tangential", [0.0, 0.0]))
	_range(m, "orbit_velocity", o.get("orbit", [0.0, 0.0]))
	_range(m, "angle", o.get("angle", [0.0, 0.0]))
	_range(m, "angular_velocity", o.get("spin", [0.0, 0.0]))
	_range(m, "scale", o.get("scale", [1.0, 1.0]))
	if o.has("scale_curve"):
		var top := 8.0
		for pt in o.scale_curve:
			top = maxf(top, float(pt[1]))
		m.scale_curve = curve(o.scale_curve, top)
	if o.has("alpha_curve"):
		m.alpha_curve = curve(o.alpha_curve)
	if o.has("color"):
		m.color = o.color if o.color is Color else Color(o.color)
	if o.has("ramp"):
		m.color_ramp = o.ramp
	if o.has("initial"):
		m.color_initial_ramp = o.initial
	if o.has("collide"):
		# needs a ground() (or any LightOccluder2D with sdf_collision) under it
		var c: Dictionary = o.collide
		m.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT if c.get("hide", false) else ParticleProcessMaterial.COLLISION_RIGID
		m.collision_bounce = c.get("bounce", 0.2)
		m.collision_friction = c.get("friction", 0.6)
		m.collision_use_scale = true
		p.collision_base_size = c.get("size", 1.0)
	if o.has("turbulence"):
		var t: Dictionary = o.turbulence
		m.turbulence_enabled = true
		m.turbulence_noise_strength = t.get("strength", 1.0)
		m.turbulence_noise_scale = t.get("scale", 4.0)
		m.turbulence_noise_speed_random = t.get("speed", 0.2)
		# influence pulls the velocity toward the noise field every step: above ~0.03 it eats the initial speed
		_range(m, "turbulence_influence", t.get("influence", [0.01, 0.02]))
	p.process_material = m
	if o.has("process_shader"):
		# your own particle process shader (shader_type particles) where the material can't do it: a spiral, a path
		var ps := ShaderMaterial.new()
		ps.shader = load(o.process_shader) if o.process_shader is String else o.process_shader
		var kinds := {}
		for u in ps.shader.get_shader_uniform_list():
			kinds[u.name] = u.type
		for k in o.get("process_params", {}):
			var v: Variant = o.process_params[k]
			# an int given to a float uniform is dropped when the scene is saved; an int uniform keeps its int
			ps.set_shader_parameter(k, float(v) if v is int and kinds.get(k, TYPE_FLOAT) == TYPE_FLOAT else v)
		p.process_material = ps
	return p


## A copy of emitter p on another layer ("light" by default): the same material, seed and keys, so it emits the very
## same particles (a glow riding each ember, a bright head on each streak). o: layer, name, texture, modulate,
## scale (multiplies the particles' scale). p's keys are copied when the scene is saved, so key p whenever you like.
func twin(p: GPUParticles2D, o: Dictionary = {}) -> GPUParticles2D:
	var q: GPUParticles2D = p.duplicate()
	q.name = o.get("name", String(p.name) + "Light")
	q.seed = p.seed
	p.get_parent().add_child(q)
	var layer: String = o.get("layer", "light")
	var back := p.z_index < 0
	q.z_index = (-1 if layer == "light" else -2) if back else (2 if layer == "light" else 1)
	q.material = {"light": light, "soft": soft, "prop": prop_mat}.get(layer, dither)
	if o.has("texture"):
		q.texture = texture(o.texture)
	if o.has("modulate"):
		q.modulate = o.modulate
	if o.has("scale") and q.process_material is ParticleProcessMaterial:
		var m: ParticleProcessMaterial = q.process_material.duplicate()
		m.scale_min *= float(o.scale)
		m.scale_max *= float(o.scale)
		q.process_material = m
	_twins.append([p, q])
	return q


func _copy_twin_keys() -> void:
	for pair in _twins:
		var src := String(root.get_path_to(pair[0])) + ":"
		var dst := String(root.get_path_to(pair[1])) + ":"
		for tr in fx.get_track_count():
			var path := String(fx.track_get_path(tr))
			if not path.begins_with(src) or fx.find_track(NodePath(dst + path.substr(src.length())), Animation.TYPE_VALUE) >= 0:
				continue
			var nt := fx.add_track(Animation.TYPE_VALUE)
			fx.track_set_path(nt, NodePath(dst + path.substr(src.length())))
			fx.track_set_interpolation_type(nt, fx.track_get_interpolation_type(tr))
			fx.value_track_set_update_mode(nt, fx.value_track_get_update_mode(tr))
			fx.track_set_interpolation_loop_wrap(nt, false)
			for k in fx.track_get_key_count(tr):
				fx.track_insert_key(nt, fx.track_get_key_time(tr, k), fx.track_get_key_value(tr, k))


static func _pair(r: Variant) -> Array:
	return [float(r[0]), float(r[1])] if r is Array else [float(r), float(r)]


## The quadratic friction c (dv/dt = -c v^2) under which a particle starting at speed v travels as far in t seconds
## as under linear drag k (dv/dt = -k v): ln(1 + c v t) / c = v (1 - e^(-k t)) / k.
static func friction_for(k: float, v: float, t: float) -> float:
	var want := v * (1.0 - exp(-k * t)) / k
	var lo := 1e-9
	var hi := 1e3
	for i in 100:
		var c := sqrt(lo * hi)
		if log(1.0 + c * v * t) / c > want:
			lo = c
		else:
			hi = c
	return sqrt(lo * hi)


static func _v3(v: Vector2) -> Vector3:
	return Vector3(v.x, v.y, 0)


static func _range(m: ParticleProcessMaterial, prop: String, r: Variant) -> void:
	var a: float = r[0] if r is Array else r
	var b: float = r[1] if r is Array else r
	m.set(prop + "_min", a)
	m.set(prop + "_max", b)


static func _points_texture(points: PackedVector2Array) -> ImageTexture:
	var img := Image.create(points.size(), 1, false, Image.FORMAT_RGF)
	for i in points.size():
		img.set_pixel(i, 0, Color(points[i].x, points[i].y, 0))
	return ImageTexture.create_from_image(img)


## The stand-in as a node of the effect's own ("Actor", feet at the origin, between the back and front layers), with
## shaders/actor.gdshader so the effect can key its flash and tint: key(a, "material:shader_parameter/flash", ...).
## Effects that leave the body alone needn't: PfxEffect puts a plain stand-in there by itself.
func actor_node() -> Sprite2D:
	var tex: Texture2D = load(EFFECT.STAND_INS[maxi(1, root.actor)])
	var s := Sprite2D.new()
	s.name = "Actor"
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height())
	root.add_child(s)
	s.z_index = 0
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/shaders/actor.gdshader")
	s.material = m
	return s


## The stand-in's pixels (root.actor: 1 or 2) relative to its feet, for emitters that wrap the body:
## {"points": actor_points()} fills the silhouette, actor_points(true) only its outline (pixels next to empty ones).
func actor_points(edge := false, k := 0) -> PackedVector2Array:
	var which: int = k if k > 0 else maxi(1, root.actor)
	var img: Image = load(EFFECT.STAND_INS[which]).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var out := PackedVector2Array()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			if edge:
				var inner := true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or img.get_pixel(q.x, q.y).a < 0.5:
						inner = false
				if inner:
					continue
			out.append(Vector2(x - floorf(w / 2.0) + 0.5, y - h + 0.5))
	return out


## Frames lifted from the original (fx/<cat>/<name>/frames.png + frames.json, written by
## `cd godot && ./pfx sheets <id> --out ../godot-particle/addons/pixelfx_particles/fx` then moved by port/frames.py):
## a Sprite2D the "fx" animation steps through frame by frame. For bodies that aren't effects (critters, objects).
func frames(name: String = "Body", o: Dictionary = {}) -> Sprite2D:
	var dir := "res://addons/pixelfx_particles/fx/%s/" % id
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "frames.json"))
	var oo := {"centered": false, "layer": o.get("layer", "prop"), "hframes": int(j.cols), "vframes": int(j.rows)}
	oo.merge(o, true)
	var s := sprite(name, load(dir + "frames.png"), oo)
	s.offset = -Vector2(j.pivot[0], j.pivot[1])
	var keys := []
	var n: int = j.count
	for i in n:
		keys.append([i / float(j.fps), i])
	key(s, "frame", keys, "nearest")
	return s


## The effect's still pixels lifted from the original (port/props.py: fx/<cat>/<name>/prop.png), in place, exact.
func prop(o: Dictionary = {}) -> Sprite2D:
	# o.file: another lifted image in the effect's folder (a prop split into the part behind and the part in front)
	var path := "res://addons/pixelfx_particles/fx/%s/%s" % [id, o.get("file", "prop.png")]
	var oo := {"centered": false, "at": -Vector2(root.origin), "layer": "prop", "back": o.get("back", true)}
	oo.merge(o, true)
	return sprite(o.get("name", "Prop"), load(path), oo)


## A Sprite2D: texture (name or Texture2D), at, back, layer, centered (true), offset, scale, frames (hframes).
func sprite(name: String, tex: Variant, o: Dictionary = {}) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name
	s.texture = texture(tex) if tex is String else tex
	_place(s, o, o.get("parent"))
	s.centered = o.get("centered", true)
	s.offset = o.get("offset", Vector2.ZERO)
	s.scale = o.get("scale", Vector2.ONE)
	s.hframes = o.get("hframes", 1)
	s.vframes = o.get("vframes", 1)
	return s


## A shape drawn by a canvas shader over a w x h rect centred on `at` (rings, arcs, shockwaves, wipes...). The shader
## (a path under shaders/, or a Shader) should include pixel.gdshaderinc for the colour layer. params: uniforms.
func shape(name: String, shader: Variant, size: Vector2, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var r := ColorRect.new()
	r.name = name
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var at: Vector2 = o.get("at", Vector2.ZERO)
	(o.get("parent") if o.get("parent") != null else root).add_child(r)
	r.position = at - size / 2.0
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/shaders/" + shader + ".gdshader") if shader is String else shader
	var lit := m.shader.code.contains("blend_add")
	r.z_index = (-1 if lit else -2) if o.get("back", false) else (2 if lit else 1)
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("center", at)
	var types := {}
	for u in m.shader.get_shader_uniform_list():
		types[u.name] = u.type
	for k in params:
		var v: Variant = params[k]
		if v is int and types.get(k, TYPE_FLOAT) == TYPE_FLOAT:
			v = float(v)   # an int given to a float uniform is dropped when the scene is saved (int uniforms keep ints)
		if v is PackedColorArray or (v is Array and v.size() and v.all(func(c): return c is Color)):
			# a plain vec4[] uniform needs a PackedVector4Array (colours arrive as zeros otherwise); one hinted
			# source_color needs a PackedColorArray (it saves as null otherwise)
			var hinted: bool = types.get(k, TYPE_PACKED_COLOR_ARRAY) == TYPE_PACKED_COLOR_ARRAY
			var arr: Variant = PackedColorArray() if hinted else PackedVector4Array()
			for c in v:
				arr.append(c if hinted else Vector4(c.r, c.g, c.b, c.a))
				if not lit:
					keep_colour(c)
			v = arr
		if v is Color and not lit:
			keep_colour(v)
		m.set_shader_parameter(k, v)
	r.material = m
	return r


## A disc or ring (shaders/ring.gdshader, colour layer) centred on `at`, big enough for `reach` px of radius.
## params: radius, thickness, squash, color, edge_color, edge, side, ragged, alpha (key them to animate).
func ring(name: String, reach: float, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var sq: float = params.get("squash", 1.0)
	var e: float = params.get("edge", 0.0)
	return shape(name, "ring", Vector2(ceilf(reach + e + 2) * 2, ceilf((reach + e) * sq + 2) * 2), params, o)


## A plain rectangle (relative to the origin) in one colour: floors, bands, washes. o: layer ("soft" keeps alpha), back.
func rect(name: String, r: Rect2, c: Color, o: Dictionary = {}) -> ColorRect:
	var n := ColorRect.new()
	n.name = name
	n.size = r.size
	n.color = c
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(n, o, o.get("parent"))
	n.position = r.position
	keep_colour(c)
	return n


## Mist, fog, cloud banks (shaders/fog.gdshader) over a w x h rect centred on `at`, scrolling with the loop.
## params: noise (texture name, default noise256x64), drift, period, profile, density, contrast, threshold, body,
## low, high, crest, alpha. Soft (translucent) unless o.layer says otherwise.
func fog(name: String, size: Vector2, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var pr := params.duplicate()
	pr.noise = texture(pr.get("noise", "noise256x64"))
	if o.get("layer", "soft") == "soft":
		pr.translucent = true
	var r := shape(name, "fog", size, pr, o)
	loop_t(r)
	return r


## Key the shader uniform `t` on node from 0 to 1 over the whole effect (time for shaders: they never read TIME).
func loop_t(node: CanvasItem, uniform := "t") -> void:
	key(node, "material:shader_parameter/" + uniform, [[0.0, 0.0], [root.duration, 1.0]])


## A soft additive glow disc or band (shaders/ring_light.gdshader, light layer). params: radius, thickness, squash,
## color, alpha.
func glow(name: String, reach: float, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var sq: float = params.get("squash", 1.0)
	return shape(name, "ring_light", Vector2(ceilf(reach + 2) * 2, ceilf(reach * sq + 2) * 2), params, o)


## A floor particles can land on, bounce off or vanish into (collide): an invisible LightOccluder2D along y (relative
## to the origin; the original's floor is y = 0), as wide as anything needs. It casts no light shadows.
func ground(y := 0.0) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	occ.name = "Floor"
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-4096, y), Vector2(4096, y), Vector2(4096, y + 64), Vector2(-4096, y + 64)])
	occ.occluder = poly
	occ.sdf_collision = true
	occ.occluder_light_mask = 0
	root.add_child(occ)
	return occ


## A Line2D through points: width, color or gradient (along the line), layer, at, back, round (joints), soft (a soft
## cross-section, on by default on the light layer).
func line(name: String, points: PackedVector2Array, o: Dictionary = {}) -> Line2D:
	var l := Line2D.new()
	l.name = name
	if o.has("gradient") and points.size() >= 2:
		# a Line2D's gradient lands on its points: give it one a pixel so a stepped gradient stays stepped
		var dense := PackedVector2Array([points[0]])
		for i in range(1, points.size()):
			var a := points[i - 1]
			var b := points[i]
			var n := maxi(1, int(ceil(a.distance_to(b))))
			for k in range(1, n + 1):
				dense.append(a.lerp(b, k / float(n)))
		points = dense
	l.points = points
	l.width = o.get("width", 1.0)
	l.default_color = o.get("color", Color.WHITE)
	if o.has("gradient"):
		l.gradient = o.gradient.gradient if o.gradient is GradientTexture1D else o.gradient
	l.antialiased = false
	l.joint_mode = Line2D.LINE_JOINT_ROUND if o.get("round", false) else Line2D.LINE_JOINT_SHARP
	if o.get("soft", o.get("layer", "color") == "light"):
		# a soft cross-section (bright down the middle, fading to its edges): glows, beams
		l.texture = texture("beam16")
		l.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
	_place(l, o, o.get("parent"))
	return l


## A lightning bolt (core/bolt.gd): a jagged Line2D from `a` to `b` re-rolled `rate` times a second off the effect's
## clock. o: width, color, gradient, layer ("light" for a glow pass), jag, segments, rate, seed, branches,
## branch_length, branch_width, at, back. Key from / to / jag / visible to animate.
func bolt(name: String, a: Vector2, b: Vector2, o: Dictionary = {}) -> Line2D:
	var l := line(name, PackedVector2Array([a, b]), o)
	l.set_script(load("res://addons/pixelfx_particles/core/bolt.gd"))
	l.from = a
	l.to = b
	l.jag = o.get("jag", 4.0)
	l.segments = o.get("segments", 8)
	l.rate = o.get("rate", 15.0)
	l.bolt_seed = o.get("seed", absi(hash(id + name)) % 100000)
	l.branches = o.get("branches", 0)
	l.branch_length = o.get("branch_length", 0.35)
	l.branch_width = o.get("branch_width", 1.0)
	return l


## A word in the original's pixel fonts, drawn as its UI words are (core/pixel_text.gd): font ("mini" 3x5 | "big"
## 5x7), sx / sy (font pixel scale), slant, fill (colours bottom row to top), edge, under (bevel), outline, shadow,
## flash; at = the word's bottom middle; layer ("color": it dithers out as modulate:a falls), back. Key position,
## sx, sy, flash, modulate:a, text.
func text(name: String, s: String, o: Dictionary = {}) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.set_script(load("res://addons/pixelfx_particles/core/pixel_text.gd"))
	n.text = s
	n.font = o.get("font", "big")
	n.sx = o.get("sx", 1.0)
	n.sy = o.get("sy", 1.0)
	n.slant = o.get("slant", 0.0)
	var f: Variant = o.get("fill", [Color.WHITE])
	n.fill = PackedColorArray(Array(f).map(func(c): return c if c is Color else Color(c)))
	for k in ["edge", "under", "outline", "shadow"]:
		if o.has(k):
			n.set(k, o[k] if o[k] is Color else Color(o[k]))
	for c in n.fill:
		keep_colour(c)
	for c in [n.edge, n.under, n.outline, n.shadow]:
		if c.a > 0.0:
			keep_colour(c)
	var oo := {"layer": "color"}
	oo.merge(o, true)
	_place(n, oo, o.get("parent"))
	return n


## A crescent swept along a tilted ellipse (shaders/arc.gdshader) centred on `at`: slashes, swipes, sweeps.
## params: radius, squash, tilt, head, tail (degrees), thickness, inward, taper, ramp (a gradient, head first),
## alpha. Key head / tail (and thickness, alpha) to sweep it.
func arc(name: String, reach: float, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var e := ceilf(reach + params.get("thickness", 4.0) + 2.0) * 2.0
	return shape(name, "arc", Vector2(e, e), params, o)


## A closed ellipse as a Line2D (rx, ry, centred on o.at): thin floor rings that a squashed ring shader breaks up.
## o: width, color, layer, back, side (1: only the far half, -1: the near half), steps.
func ellipse(name: String, rx: float, ry: float, o: Dictionary = {}) -> Line2D:
	var pts := PackedVector2Array()
	var n: int = o.get("steps", maxi(16, int(ceil(TAU * maxf(rx, ry)))))
	var side: float = o.get("side", 0.0)
	for i in n + 1:
		var a := TAU * i / n
		var p := Vector2(cos(a) * rx, sin(a) * ry).round()
		if (side > 0.0 and p.y > 0.0) or (side < 0.0 and p.y < 0.0):
			continue
		pts.append(p)
	return line(name, pts, o)


## A texture made at build time (an Image you drew), saved beside the scene as fx/<id>/<file>.res so the .tscn stays
## small. Returns it, loaded, to use like any texture.
func asset(file: String, img: Image) -> Texture2D:
	var dir := "res://addons/pixelfx_particles/fx/%s/" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dir + file.get_basename() + ".res"
	ResourceSaver.save(ImageTexture.create_from_image(img), path)
	return load(path)


## A plain Node2D to group or move things (at, back, parent).
func group(name: String, o: Dictionary = {}) -> Node2D:
	var g := Node2D.new()
	g.name = name
	(o.get("parent") if o.get("parent") != null else root).add_child(g)
	g.position = o.get("at", Vector2.ZERO)
	g.z_index = -1 if o.get("back", false) else 0
	return g


# ------------------------------------------------------------------ time

## Keys on the "fx" animation: node.prop takes value v at time t for each [t, v] (seconds). interp: "linear",
## "nearest" (holds, for on/off and steps) or "cubic". A shader uniform is "shader_parameter/<name>" on the node.
func key(node: Node, prop: String, keys: Array, interp := "linear") -> void:
	var path := NodePath(String(root.get_path_to(node)) + ":" + prop)
	var tr := fx.find_track(path, Animation.TYPE_VALUE)
	if tr < 0:
		tr = fx.add_track(Animation.TYPE_VALUE)
		fx.track_set_path(tr, path)
	fx.track_set_interpolation_type(tr, {"linear": Animation.INTERPOLATION_LINEAR, "nearest": Animation.INTERPOLATION_NEAREST, "cubic": Animation.INTERPOLATION_CUBIC}[interp])
	fx.value_track_set_update_mode(tr, Animation.UPDATE_DISCRETE if interp == "nearest" else Animation.UPDATE_CONTINUOUS)
	# a looping track would otherwise blend from its last key back to its first over the loop's last stretch; the
	# original holds the last value until the loop wraps
	fx.track_set_interpolation_loop_wrap(tr, false)
	if keys.size() and float(keys[0][0]) > 0.0:
		# before its first key a track sets nothing (the node would keep its saved value): hold the first value from 0
		keys = [[0.0, keys[0][1]]] + keys
	keys = _thin(keys, interp)
	for k in keys:
		var v: Variant = k[1]
		if v is int and prop.begins_with("material:shader_parameter/"):
			v = float(v)
		if node is Control and prop == "position" and v is Vector2:
			v = v - node.size / 2.0   # a shape's position is its centre, as where it was placed
		var t := float(k[0])
		if interp == "nearest" and t > 0.0:
			# a step on a frame's time could land a frame late (the clock adds up 1/fps in floats): take it a hair early
			t = maxf(0.0, t - STEP_EARLY)
		fx.track_insert_key(tr, t, v)


## Keys sampled every frame are mostly redundant: drop the inside of runs that hold one value and, on linear tracks,
## keys the kept ones already interpolate. A key goes only when every key it skips stays within a hair of the line
## that replaces them (0.3% of the value's size, at most 0.1 px), so a smooth curve keeps its shape. The track plays
## the same; the scene file stays small.
static func _thin(keys: Array, interp: String) -> Array:
	var n := keys.size()
	if n < 3:
		return keys
	var out := [keys[0]]
	var i := 0
	while i < n - 1:
		var j := i + 1
		while j + 1 < n and j + 1 - i <= THIN_SPAN and _spans(keys, i, j + 1, interp):
			j += 1
		out.append(keys[j])
		i = j
	return out


## Whether the track gives every key strictly between i and j (near enough) with only keys i and j.
static func _spans(keys: Array, i: int, j: int, interp: String) -> bool:
	var a: Variant = keys[i][1]
	var c: Variant = keys[j][1]
	var lerps := interp == "linear" and typeof(c) == typeof(a) and (a is float or a is Vector2 or a is Vector3 or a is Color)
	if not lerps and interp != "nearest" and not _same(c, a):
		return false   # cubic (or a type that doesn't blend): only a run of one value goes
	for m in range(i + 1, j):
		var b: Variant = keys[m][1]
		if not lerps:
			if not _same(b, a):
				return false
			continue
		if typeof(b) != typeof(a):
			return false
		var u := (float(keys[m][0]) - float(keys[i][0])) / maxf(1e-6, float(keys[j][0]) - float(keys[i][0]))
		if not _near(lerpf(a, c, u) if a is float else a.lerp(c, u), b, a, c):
			return false
	return true


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is float:
		return is_equal_approx(a, b)
	if a is Vector2 or a is Vector3 or a is Color or a is Vector4:
		return a.is_equal_approx(b)
	return a == b


static func _near(x: Variant, y: Variant, a: Variant, c: Variant) -> bool:
	if x is float:
		return absf(x - y) <= clampf(0.003 * maxf(absf(a), absf(c)), 1e-3, 0.1)
	if x is Vector2 or x is Vector3:
		return (x - y).length() <= clampf(0.003 * maxf(a.length(), c.length()), 1e-3, 0.1)
	if x is Color:
		return absf(x.r - y.r) < 0.002 and absf(x.g - y.g) < 0.002 and absf(x.b - y.b) < 0.002 and absf(x.a - y.a) < 0.002
	return x == y


## Another effect played inside this one (the original's chain(): a move strings effects together). Its own scene is
## instanced, held until `t` (seconds) and played then; it keeps its own colours, seed and timing, and follows this
## effect's speed, take and light. o (all optional): t, until (cut it off then: it vanishes, as in the original),
## x, y (px from the origin, or a Callable of this effect's time for a projectile's flight), height (raise it: the
## original's `height` option), palette (PackedColorArray: its main ramp in other colours, the original's
## `palette`), flip.
func cue(fx_id: String, o: Dictionary = {}) -> Node2D:
	var scene: PackedScene = load("res://addons/pixelfx_particles/fx/%s.tscn" % fx_id)
	var inst: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var on: float = o.get("t", 0.0)
	_cues += 1
	inst.name = "%s%d" % [fx_id.get_file().to_pascal_case(), _cues]
	inst.set("autoplay", on <= 0.0)
	inst.set("show_actor", false)
	if o.get("flip", false):
		inst.set("flip", true)
	if o.has("palette"):
		inst.set("palette_override", PackedColorArray(o.palette))
	root.add_child(inst)
	var lift := Vector2(0.0, -float(o.get("height", 0.0)))
	var off: float = o.get("until", -1.0)
	var fx_x: Variant = o.get("x", 0.0)
	var fx_y: Variant = o.get("y", 0.0)
	if fx_x is Callable or fx_y is Callable:
		var end: float = off if off >= 0.0 else float(meta.duration)
		var keys := []
		var n := maxi(1, int(ceil((end - on) * 60.0)))
		for i in n + 1:
			var tt := on + (end - on) * i / float(n)
			var px: float = fx_x.call(tt) if fx_x is Callable else float(fx_x)
			var py: float = fx_y.call(tt) if fx_y is Callable else float(fx_y)
			keys.append([tt, Vector2(px, py) + lift])
		inst.position = keys[0][1]
		key(inst, "position", keys)
	else:
		inst.position = Vector2(float(fx_x), float(fx_y)) + lift
	show(inst, on, off)
	if on > 0.0:
		# a method key, called the moment the animation passes it (not deferred to the frame's end)
		anim.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
		var tr := fx.add_track(Animation.TYPE_METHOD)
		fx.track_set_path(tr, root.get_path_to(inst))
		fx.track_insert_key(tr, maxf(0.0, on - STEP_EARLY), {"method": "play", "args": []})
	return inst


## An emitter that starts at `on` (seconds) and, if `off` >= 0, stops at `off`. One-shot emitters burst at `on`.
func emit(p: GPUParticles2D, on: float, off := -1.0) -> void:
	p.emitting = on <= 0.0
	var keys := [[0.0, on <= 0.0]]
	if on > 0.0:
		keys.append([on, true])
	if off >= 0.0:
		keys.append([off, false])
	key(p, "emitting", keys, "nearest")


## Visible from `on` to `off` (seconds; off < 0: to the end).
func show(n: CanvasItem, on: float, off := -1.0) -> void:
	var keys := [[0.0, on <= 0.0]]
	if on > 0.0:
		keys.append([on, true])
	if off >= 0.0:
		keys.append([off, false])
	n.visible = on <= 0.0
	key(n, "visible", keys, "nearest")


# ------------------------------------------------------------------ save

func save(path: String) -> int:
	_copy_twin_keys()
	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(packed, path)
	root.free()
	return err


static func _own(n: Node, owner_: Node) -> void:
	for c in n.get_children():
		c.owner = owner_
		if c.scene_file_path == "":   # a cued effect is saved as an instance of its own scene, not copied in
			_own(c, owner_)
