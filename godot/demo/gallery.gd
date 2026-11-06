## The pixelfx gallery: browse every effect by category, play it (or act it out), recolor, reseed and mirror it.
## Run the project (F5) or: godot --path godot demo/gallery.tscn
extends Control

const Px := preload("res://addons/pixelfx/core/px.gd")
const Registry := preload("res://addons/pixelfx/fx/registry.gd")
const FxNode := preload("res://addons/pixelfx/nodes/pixel_fx_2d.gd")
const ActNode := preload("res://addons/pixelfx/nodes/pixel_fx_act_2d.gd")
const ZOOM := 3

var cats: ItemList
var list: ItemList
var info: Label
var palette: OptionButton
var seed_box: SpinBox
var flip_box: CheckBox
var act_box: CheckBox
var live_box: CheckBox
var stage: Node2D
var current := ""


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color8(21, 19, 29)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(340, 0)
	row.add_child(side)
	cats = ItemList.new()
	cats.custom_minimum_size = Vector2(0, 220)
	side.add_child(cats)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(list)
	var opts := GridContainer.new()
	opts.columns = 2
	side.add_child(opts)
	opts.add_child(_label("palette"))
	palette = OptionButton.new()
	palette.add_item("(its own)")
	for k in Px.PAL:
		palette.add_item(k)
	opts.add_child(palette)
	opts.add_child(_label("seed"))
	seed_box = SpinBox.new()
	seed_box.min_value = -1
	seed_box.max_value = 999
	seed_box.value = -1
	opts.add_child(seed_box)
	flip_box = CheckBox.new()
	flip_box.text = "flip"
	opts.add_child(flip_box)
	act_box = CheckBox.new()
	act_box.text = "act it out"
	opts.add_child(act_box)
	live_box = CheckBox.new()
	live_box.text = "LIVE (else BAKED)"
	opts.add_child(live_box)
	var replay := Button.new()
	replay.text = "replay"
	opts.add_child(replay)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	info = _label("")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(info)
	var view := Control.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.clip_contents = true
	right.add_child(view)
	stage = Node2D.new()
	stage.scale = Vector2(ZOOM, ZOOM)
	view.add_child(stage)
	view.resized.connect(func(): stage.position = view.size / 2.0 + Vector2(0, view.size.y * 0.2))
	for c in Registry.CATEGORIES:
		var n := Array(Registry.ids()).filter(func(id): return id.begins_with(c.id + "/")).size()
		if n:
			cats.add_item("%s (%d)" % [c.name, n])
			cats.set_item_metadata(cats.item_count - 1, c.id)
	cats.item_selected.connect(_show_category)
	list.item_selected.connect(func(i): _play(list.get_item_metadata(i)))
	for w in [palette]:
		w.item_selected.connect(func(_i): _play(current))
	seed_box.value_changed.connect(func(_v): _play(current))
	for b in [flip_box, act_box, live_box]:
		b.toggled.connect(func(_on): _play(current))
	replay.pressed.connect(func(): _play(current))
	if cats.item_count:
		cats.select(0)
		_show_category(0)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _show_category(i: int) -> void:
	var cat: String = cats.get_item_metadata(i)
	list.clear()
	for id in Registry.ids():
		if id.begins_with(cat + "/"):
			list.add_item("%s%s" % [Registry.EFFECTS[id].name, "  (act)" if Registry.EFFECTS[id].act else ""])
			list.set_item_metadata(list.item_count - 1, id)
	if list.item_count:
		list.select(0)
		_play(list.get_item_metadata(0))


func _play(id: String) -> void:
	if id.is_empty():
		return
	current = id
	for c in stage.get_children():
		c.queue_free()
	var e: Dictionary = Registry.EFFECTS[id]
	var mod: Script = Registry.load_effect(id)
	var meta := Px.Fx.metaOf(mod)
	info.text = "%s  (%s)\n%s\n%s, %ss, %dx%d" % [meta.get("name", id), id, meta.get("desc", ""), "loop" if meta.loop else "one-shot", str(meta.duration), meta.size[0], meta.size[1]]
	var pal := "" if palette.selected <= 0 else palette.get_item_text(palette.selected)
	if act_box.button_pressed and e.act:
		var a = ActNode.new()
		a.effect = id
		a.flip = flip_box.button_pressed
		a.seed = int(seed_box.value)
		a.palette_preset = pal
		a.loop_act = true
		stage.add_child(a)
		return
	var fx = FxNode.new()
	fx.effect = id
	fx.flip = flip_box.button_pressed
	fx.seed = int(seed_box.value)
	fx.palette_preset = pal
	fx.mode = FxNode.Mode.LIVE if live_box.button_pressed else FxNode.Mode.BAKED
	fx.show_actor = true
	stage.add_child(fx)
	fx.finished.connect(func(): if current == id: fx.play())
