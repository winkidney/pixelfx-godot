extends Control
## Every particle effect, by category: pick one to play it on the original's backdrop, crisp at 3x. Recolour it,
## flip it, try another take, or watch it acted out by the knight. Space replays.

const REGISTRY := preload("res://addons/pixelfx_particles/fx/registry.gd")
const Palettes := preload("res://addons/pixelfx_particles/core/palettes.gd")
const Backdrop := preload("res://addons/pixelfx_particles/core/backdrop.gd")
const ZOOM := 3

var list: Tree
var stage: Control
var info: Label
var preset: OptionButton
var flip_box: CheckBox
var act_box: CheckBox
var take_spin: SpinBox
var current := ""


func _ready() -> void:
	var root := HSplitContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.split_offset = 260
	add_child(root)
	list = Tree.new()
	list.hide_root = true
	list.custom_minimum_size = Vector2(240, 0)
	list.item_selected.connect(_on_pick)
	root.add_child(list)
	var right := VBoxContainer.new()
	root.add_child(right)
	var bar := HBoxContainer.new()
	right.add_child(bar)
	preset = OptionButton.new()
	preset.add_item("(own colours)")
	for k in Palettes.PAL:
		preset.add_item(k)
	preset.item_selected.connect(func(_i): _play())
	bar.add_child(preset)
	flip_box = CheckBox.new()
	flip_box.text = "flip"
	flip_box.toggled.connect(func(_b): _play())
	bar.add_child(flip_box)
	act_box = CheckBox.new()
	act_box.text = "acted out"
	act_box.toggled.connect(func(_b): _play())
	bar.add_child(act_box)
	take_spin = SpinBox.new()
	take_spin.prefix = "take"
	take_spin.max_value = 99
	take_spin.value_changed.connect(func(_v): _play())
	bar.add_child(take_spin)
	var again := Button.new()
	again.text = "replay (space)"
	again.pressed.connect(_play)
	bar.add_child(again)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(info)
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	right.add_child(stage)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://port/meta.json"))
	var cats := {}
	var top := list.create_item()
	for id in REGISTRY.EFFECTS:
		var cat: String = id.get_slice("/", 0)
		if not cats.has(cat):
			cats[cat] = list.create_item(top)
			cats[cat].set_text(0, cat)
			cats[cat].set_selectable(0, false)
		var it := list.create_item(cats[cat])
		it.set_text(0, REGISTRY.EFFECTS[id].name)
		it.set_metadata(0, id)
		it.set_tooltip_text(0, meta.get(id, {}).get("desc", ""))
	set_meta("descs", meta)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		_play()


func _on_pick() -> void:
	current = list.get_selected().get_metadata(0)
	_play()


func _play() -> void:
	for c in stage.get_children():
		c.queue_free()
	if current == "":
		return
	var e: Dictionary = REGISTRY.EFFECTS[current]
	var m: Dictionary = get_meta("descs").get(current, {})
	info.text = "%s  (%s)  %s, %.2f s\n%s" % [e.name, current, "loop" if e.loop else "one-shot", e.duration, m.get("desc", "")]
	var centre := stage.size / 2.0
	if act_box.button_pressed and e.act:
		var act := PixelFxParticlesAct2D.new()
		act.zoom = ZOOM
		act.loop_act = true
		var d: Dictionary = PixelFxParticlesAct2D.timing(current)
		act.position = (centre + Vector2(0, 60)).floor()
		stage.add_child(act)
		act.effect = current
		return
	var size := Vector2(e.size[0], e.size[1])
	var origin := Vector2(e.origin[0], e.origin[1])
	var top_left := (centre - size * ZOOM / 2.0).floor()
	var bg := TextureRect.new()
	bg.texture = Backdrop.texture(m.get("bg", "dark"), int(size.x), int(size.y), origin.y)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.position = top_left
	bg.size = size * ZOOM
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(bg)
	var fx := PixelFxParticles2D.new()
	fx.zoom = ZOOM
	fx.show_actor = true
	fx.flip = flip_box.button_pressed
	fx.take = int(take_spin.value)
	fx.position = top_left + origin * ZOOM
	if preset.selected > 0:
		fx.palette_preset = preset.get_item_text(preset.selected)
	stage.add_child(fx)
	fx.effect = current
	fx.finished.connect(func(): if is_instance_valid(fx) and not e.loop: fx.play())
