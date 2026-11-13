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
##   dir (degrees, 0 right, -90 up: default -90), spread (degrees either side), speed [min, max], gravity Vector2,
##   damping [min, max], radial [min, max] (acceleration away from the emitter), radial_speed [min, max] (velocity
##   away from it), life_random (0..1: lifetimes vary), tangential [min, max], orbit [min, max] (turns a second),
##   angle [min, max], spin [min, max] (degrees a second), scale [min, max], scale_curve [[t, v], ...],
##   alpha_curve [[t, a], ...], color, ramp (colour over life, from ramp()), initial (a random starting colour),
##   turbulence {strength, scale, speed, influence [min, max]: keep it 0.005..0.03, more stops a particle dead},
##   local (local coordinates), collide {bounce, friction, hide (vanish on contact), size}: needs a ground().
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
	var d: float = o.get("dir", -90.0)
	m.direction = Vector3(cos(deg_to_rad(d)), sin(deg_to_rad(d)), 0)
	m.spread = o.get("spread", 0.0)
	_range(m, "initial_velocity", o.get("speed", [0.0, 0.0]))
	_range(m, "damping", o.get("damping", [0.0, 0.0]))
	_range(m, "radial_accel", o.get("radial", [0.0, 0.0]))
	_range(m, "radial_velocity", o.get("radial_speed", [0.0, 0.0]))
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
	return p


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
	var path := "res://addons/pixelfx_particles/fx/%s/prop.png" % id
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
	for k in params:
		var v: Variant = params[k]
		if v is int:
			v = float(v)   # an int given to a float uniform is dropped when the scene is saved
		if v is PackedColorArray or (v is Array and v.size() and v.all(func(c): return c is Color)):
			# a vec4[] uniform needs a PackedVector4Array (colours arrive as zeros otherwise)
			var arr := PackedVector4Array()
			for c in v:
				arr.append(Vector4(c.r, c.g, c.b, c.a))
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
	for k in keys:
		var v: Variant = k[1]
		if v is int and prop.begins_with("material:shader_parameter/"):
			v = float(v)
		if node is Control and prop == "position" and v is Vector2:
			v = v - node.size / 2.0   # a shape's position is its centre, as where it was placed
		fx.track_insert_key(tr, float(k[0]), v)


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
		_own(c, owner_)
