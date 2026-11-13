@tool
class_name PixelFxParticles2D
extends Node2D
## Plays one pixelfx particle effect by id. Its position is the effect's origin: feet, point of impact, base of a
## torch.
##
##     var fx := PixelFxParticles2D.new()
##     fx.effect = "ice/frost-nova"
##     fx.palette_preset = "arcane"       # any preset in core/palettes.gd, or set `palette` to your own colours
##     fx.flip = hero.facing < 0
##     fx.free_when_done = true
##     fx.position = hero.position
##     add_child(fx)
##
## pixel_view (default on) renders the effect at its native resolution in a SubViewport and scales it up by whole
## pixels (`zoom`), so it stays crisp in a high-resolution game. Turn it off when your game already renders at
## pixel scale; the effect is then an ordinary child.

signal finished

const REGISTRY := preload("../fx/registry.gd")
const Palettes := preload("../core/palettes.gd")

@export var effect := "":
	set(v):
		effect = v
		_reload()
@export var palette_preset := "":
	set(v):
		palette_preset = v
		_recolour()
## Your own colours for the effect's main ramp, dark to bright (wins over palette_preset).
@export var palette := PackedColorArray():
	set(v):
		palette = v
		_recolour()
@export var flip := false:
	set(v):
		flip = v
		if _fx:
			_fx.flip = v
## Another take of the same effect (added to every emitter's seed).
@export var take := 0:
	set(v):
		take = v
		if _fx:
			_fx.take = v
@export_range(0.0, 3.0, 0.05) var light := 1.0:
	set(v):
		light = v
		if _fx:
			_fx.light = v
## Time scale: 0 freezes it (hit-stop).
@export var speed := 1.0:
	set(v):
		speed = v
		if _fx:
			_fx.speed = v
## Draw the stand-in character the effect was made around (off: your own character is there).
@export var show_actor := false:
	set(v):
		show_actor = v
		_reload()
@export var autoplay := true
@export var free_when_done := false
@export var pixel_view := true:
	set(v):
		pixel_view = v
		_reload()
@export_range(1, 8) var zoom := 1:
	set(v):
		zoom = v
		_reload()

var _fx: Node2D
var _vp: SubViewport


func _validate_property(property: Dictionary) -> void:
	if property.name == "effect":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(REGISTRY.EFFECTS.keys())
	elif property.name == "palette_preset":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = "," + ",".join(Palettes.PAL.keys())


func _ready() -> void:
	_reload()


func _reload() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("pfx"):
			c.queue_free()
	_fx = null
	_vp = null
	if not REGISTRY.EFFECTS.has(effect):
		return
	var scene: PackedScene = load(REGISTRY.EFFECTS[effect].path)
	_fx = scene.instantiate()
	_fx.autoplay = autoplay and not Engine.is_editor_hint()
	_fx.show_actor = show_actor
	_fx.flip = flip
	_fx.take = take
	_fx.light = light
	_fx.speed = speed
	_fx.finished.connect(_on_finished)
	if pixel_view:
		_vp = SubViewport.new()
		_vp.size = _fx.canvas_size
		_vp.transparent_bg = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_vp.snap_2d_transforms_to_pixel = true
		_vp.snap_2d_vertices_to_pixel = true
		_vp.set_meta("pfx", true)
		add_child(_vp)
		_fx.position = Vector2(_fx.origin)
		_fx.flip = false
		_vp.add_child(_fx)
		var s := Sprite2D.new()
		s.set_meta("pfx", true)
		s.texture = _vp.get_texture()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(-zoom if flip else zoom, zoom)
		s.position = Vector2(_fx.origin.x * zoom if flip else -_fx.origin.x * zoom, -_fx.origin.y * zoom)
		add_child(s)
	else:
		_fx.set_meta("pfx", true)
		add_child(_fx)
	_recolour()


func _recolour() -> void:
	if not _fx:
		return
	if palette.size():
		_fx.set_palette(palette)
	elif palette_preset and Palettes.PAL.has(palette_preset):
		_fx.set_palette(Palettes.colors(palette_preset))


func play() -> void:
	if _fx:
		_fx.play()


## Let it end: a loop fades out; then `finished`.
func stop() -> void:
	if _fx:
		_fx.stop()


func _on_finished() -> void:
	finished.emit()
	if free_when_done and not Engine.is_editor_hint():
		queue_free()
