@tool
class_name PfxEffect
extends Node2D
## The root of every pixelfx particle effect scene (addons/pixelfx_particles/fx/<category>/<name>.tscn).
##
## A scene is GPUParticles2D emitters plus whatever else the effect needs (shader-drawn shapes, Line2D, sprites),
## timed by an AnimationPlayer named "AnimationPlayer" with an animation "fx" as long as the effect. This node plays
## it, stops it (a loop fades out), freezes it (speed 0, for hit-stop), flips it, recolours it by ramp name, and puts
## the stand-in character at its origin when the effect is about one. Its own position is the effect's origin:
## feet, point of impact, base of a torch.
##
## Layers: nodes with z_index < 0 draw behind the character, the rest in front. The colour layer uses the dither
## material (shaders/dither.gdshader: on/off alpha, palette snap), the light layer the light material
## (shaders/light.gdshader: additive).

signal finished

const FADE := 0.3
const DITHER := preload("../shaders/dither.gdshader")
const LIGHT := preload("../shaders/light.gdshader")
const STAND_INS := ["", "res://addons/pixelfx_particles/actor/stock/hero1.png", "res://addons/pixelfx_particles/actor/stock/hero2.png"]

@export_group("Original")
## The effect's id, "category/name".
@export var effect_id := ""
## The upstream file this scene reimagines, path@git-blob (port/sync.mjs reads it).
@export var source := ""
@export var duration := 1.0
@export var loop := false
@export var fps := 30
## The original's canvas, and where this node's origin sits on it.
@export var canvas_size := Vector2i(64, 64)
@export var origin := Vector2i(32, 32)
## The original's preview backdrop: dark, ground, sky, black or light.
@export var bg := "dark"
## 0, or which stand-in the effect is about: 1 (12 x 19) or 2 (the 24 x 38 knight at rest).
@export var actor := 0
## The colour ramps, by the original's option names: name -> PackedColorArray, darkest first as in the original.
@export var ramps := {}
## Colours the palette snap keeps besides the ramps (white flashes, black ink, ...).
@export var palette_extra := PackedColorArray()

@export_group("Play")
@export var autoplay := true
## Draw the stand-in at the origin (turn off when your own character is there).
@export var show_actor := true
@export var flip := false:
	set(v):
		flip = v
		scale.x = -absf(scale.x) if v else absf(scale.x)
## Strength of the additive light layer.
@export var light := 1.0:
	set(v):
		light = v
		_apply_light()
## Added to every emitter's own seed: another take of the same effect.
@export var take := 0:
	set(v):
		take = v
		_apply_seed()
## Time scale: 0 freezes everything (hit-stop), 1 is normal.
@export var speed := 1.0:
	set(v):
		speed = v
		_apply_speed()
## How visible the stand-in is (effects key it: a body that dissolves, a soul that leaves).
@export var actor_alpha := 1.0:
	set(v):
		actor_alpha = v
		if is_instance_valid(_stand_in):
			_stand_in.modulate.a = v

var t := 0.0
var _stop_at := -1.0
var _done := false
var _unique := false
var _particles: Array[GPUParticles2D] = []
var _seeds: Array[int] = []
var _anim: AnimationPlayer
var _stand_in: CanvasItem


func _ready() -> void:
	_collect()
	_apply_palette()
	_apply_light()
	_apply_seed()
	_apply_speed()
	if Engine.is_editor_hint():
		return
	if actor > 0 and show_actor and get_node_or_null("Actor") == null:
		var s := Sprite2D.new()
		s.name = "_StandIn"
		s.texture = load(STAND_INS[actor])
		s.centered = false
		s.offset = Vector2(-floorf(s.texture.get_width() / 2.0), -s.texture.get_height())
		s.modulate.a = actor_alpha
		add_child(s)
		_stand_in = s
	elif get_node_or_null("Actor") != null:
		_stand_in = get_node("Actor")
		_stand_in.visible = show_actor
	if autoplay:
		play()


func _collect() -> void:
	_particles.clear()
	_seeds.clear()
	for n in find_children("*", "GPUParticles2D", true, false):
		_particles.append(n)
		_seeds.append(n.seed)
	_anim = get_node_or_null("AnimationPlayer")


## Every ShaderMaterial in the scene whose shader has the given uniform (each shared one once).
func _materials(uniform: String) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for n in find_children("*", "CanvasItem", true, false):
		var m: Material = n.material
		if m is ShaderMaterial and m.shader and not out.has(m):
			for u in m.shader.get_shader_uniform_list():
				if u.name == uniform:
					out.append(m)
					break
	return out


## Start (or restart) from the beginning.
func play() -> void:
	t = 0.0
	_stop_at = -1.0
	_done = false
	modulate.a = 1.0
	for p in _particles:
		# restart() switches emitting on: put back what the scene says (the animation turns the rest on when due)
		var on := p.emitting
		p.restart(true)
		p.emitting = on
	if _anim and _anim.has_animation("fx"):
		_anim.play("fx")
		_anim.seek(0.0, true)


## Let it end: emitters stop, and everything fades out over FADE seconds.
func stop() -> void:
	if _stop_at >= 0.0 or _done:
		return
	_stop_at = t
	for p in _particles:
		p.emitting = false


func is_done() -> bool:
	return _done


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _done:
		return
	t += delta * speed
	if _stop_at >= 0.0:
		var k := 1.0 - (t - _stop_at) / FADE
		modulate.a = clampf(k, 0.0, 1.0)
		if k <= 0.0:
			_finish()
	elif not loop and t >= duration:
		_finish()


func _finish() -> void:
	_done = true
	finished.emit()


func _apply_speed() -> void:
	if not is_inside_tree():
		return
	if _anim:
		_anim.speed_scale = speed
	for p in _particles:
		p.speed_scale = speed


func _apply_seed() -> void:
	if not is_inside_tree():
		return
	for i in _particles.size():
		_particles[i].seed = _seeds[i] + take


func _apply_light() -> void:
	if not is_inside_tree():
		return
	for m in _materials("strength"):
		m.set_shader_parameter("strength", light)


## The palette the dither material snaps to: every ramp colour plus palette_extra.
func _apply_palette() -> void:
	if not is_inside_tree():
		return
	var cols: Array[Color] = []
	for k in ramps:
		for c in ramps[k]:
			if not cols.has(c):
				cols.append(c)
	for c in palette_extra:
		if not cols.has(c):
			cols.append(c)
	var mats := _materials("palette_size")
	if cols.is_empty():
		for m in mats:
			m.set_shader_parameter("palette_size", 0)
		return
	var img := Image.create(cols.size(), 1, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		img.set_pixel(i, 0, cols[i])
	var tex := ImageTexture.create_from_image(img)
	for m in mats:
		m.set_shader_parameter("palette", tex)
		m.set_shader_parameter("palette_size", cols.size())


## Recolour every gradient built from the ramp `name` (its stops keep their place along the ramp), and the palette.
## The first recolour makes this instance's materials its own, so other instances of the scene keep their colours.
func set_ramp(name: String, colors: PackedColorArray) -> void:
	if colors.is_empty():
		return
	_make_unique()
	ramps[name] = colors
	for g in _gradients():
		if String(g.get_meta("ramp", "")) != name:
			continue
		var at: PackedFloat32Array = g.get_meta("ramp_at", PackedFloat32Array())
		var cs := g.colors
		for i in cs.size():
			var u: float = at[i] if i < at.size() else (i / float(maxi(1, cs.size() - 1)))
			var c := colors[clampi(int(roundf(u * (colors.size() - 1))), 0, colors.size() - 1)]
			cs[i] = Color(c.r, c.g, c.b, cs[i].a)
		g.colors = cs
	_apply_palette()


## Recolour the effect's main ramp ("palette" in most effects, else its first ramp).
func set_palette(colors: PackedColorArray) -> void:
	if ramps.has("palette"):
		set_ramp("palette", colors)
	elif ramps.size():
		set_ramp(ramps.keys()[0], colors)


func _gradients() -> Array[Gradient]:
	var out: Array[Gradient] = []
	var add := func(tex: Variant) -> void:
		if tex is GradientTexture1D or tex is GradientTexture2D:
			if tex.gradient and not out.has(tex.gradient):
				out.append(tex.gradient)
	for n in find_children("*", "", true, false):
		if n is GPUParticles2D and n.process_material is ParticleProcessMaterial:
			add.call(n.process_material.color_ramp)
			add.call(n.process_material.color_initial_ramp)
		if n is Line2D and n.gradient and not out.has(n.gradient):
			out.append(n.gradient)
		if n is CanvasItem and n.material is ShaderMaterial:
			for u in n.material.shader.get_shader_uniform_list():
				add.call(n.material.get_shader_parameter(u.name))
		if "texture" in n:
			add.call(n.get("texture"))
	return out


func _make_unique() -> void:
	if _unique:
		return
	_unique = true
	var mats := {}
	for n in find_children("*", "", true, false):
		if n is GPUParticles2D and n.process_material:
			n.process_material = n.process_material.duplicate(true)
		if n is Line2D and n.gradient:
			n.gradient = n.gradient.duplicate(true)
		if n is CanvasItem and n.material:
			if not mats.has(n.material):
				mats[n.material] = n.material.duplicate(true)
			n.material = mats[n.material]
		if "texture" in n and n.get("texture") is GradientTexture1D:
			n.set("texture", n.get("texture").duplicate(true))
