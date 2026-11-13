@tool
class_name PixelFxParticlesAct2D
extends Node2D
## An effect acted out (one of the 73 with an act): the knight winds up, lets go and recovers, the straw target takes
## the hit, everything freezes on contact and shakes. Its position is the knight's feet. `hit` fires at each contact;
## timing(id) gives the same timing as data for your own character. Rendered crisp at `zoom` (pixel_view) like
## PixelFxParticles2D.

signal hit(index: int)
signal finished

const ACTS := "res://addons/pixelfx_particles/actor/acts/"

@export var effect := "":
	set(v):
		effect = v
		_reload()
@export var show_target := true:
	set(v):
		show_target = v
		_reload()
@export var shake := true:
	set(v):
		shake = v
		_reload()
@export var loop_act := false
@export var pixel_view := true:
	set(v):
		pixel_view = v
		_reload()
@export_range(1, 8) var zoom := 1:
	set(v):
		zoom = v
		_reload()

var _act: Node2D


## The act as data: { fps, pivot, hits: [{t, stop, shake, amp, ...}], frames: [{t, frozen, shake, ...}] }, effect
## time in seconds (negative while winding up). Start your attack animation so its t = 0 lines up with the effect's.
static func timing(id: String) -> Dictionary:
	var path := ACTS + id.replace("/", "-") + "/act.json"
	if not FileAccess.file_exists(path):
		return {}
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var frames: Array = d.frames
	return {"windup": -float(frames[0].t), "recovery": float(frames[-1].t), "hits": d.hits, "fps": d.fps}


func _ready() -> void:
	_reload()


func _reload() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	_act = null
	if effect == "" or not FileAccess.file_exists(ACTS + effect.replace("/", "-") + "/act.json"):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTS + effect.replace("/", "-") + "/act.json"))
	_act = Node2D.new()
	_act.set_script(load("res://addons/pixelfx_particles/core/pfx_act.gd"))
	_act.autoplay = not Engine.is_editor_hint()
	_act.show_target = show_target
	_act.shake = shake
	_act.hit.connect(func(i): hit.emit(i))
	_act.finished.connect(_on_finished)
	var pivot := Vector2(data.pivot[0], data.pivot[1])
	if pixel_view:
		var vp := SubViewport.new()
		vp.size = Vector2i(data.w, data.h)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vp.snap_2d_transforms_to_pixel = true
		vp.snap_2d_vertices_to_pixel = true
		add_child(vp)
		_act.position = pivot
		vp.add_child(_act)
		_act.effect_id = effect
		var s := Sprite2D.new()
		s.texture = vp.get_texture()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(zoom, zoom)
		s.position = -pivot * zoom
		add_child(s)
	else:
		add_child(_act)
		_act.effect_id = effect


func play() -> void:
	if _act:
		_act.play()


func _on_finished() -> void:
	finished.emit()
	if loop_act and _act:
		_act.play()
