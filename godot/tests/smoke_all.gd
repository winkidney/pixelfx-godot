# Every effect as a PixelFx2D (BAKED) and every act as a PixelFxAct2D, a few frames each, then a clean quit.
#   godot --headless --path godot -s res://tests/smoke_all.gd [-- ids...]
extends SceneTree

const Registry := preload("res://addons/pixelfx/fx/registry.gd")
const FxNode := preload("res://addons/pixelfx/nodes/pixel_fx_2d.gd")
const ActNode := preload("res://addons/pixelfx/nodes/pixel_fx_act_2d.gd")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = Array(Registry.ids())
	var shown := 0
	for id in ids:
		var fx = FxNode.new()
		fx.effect = id
		root.add_child(fx)
		for i in 3:
			await process_frame
		if fx._color.texture != null:
			shown += 1
		fx.queue_free()
		if Registry.EFFECTS[id].act:
			var a = ActNode.new()
			a.effect = id
			root.add_child(a)
			for i in 3:
				await process_frame
			a.queue_free()
	await process_frame
	print("smoke: %d effects, %d showed a frame" % [ids.size(), shown])
	quit(0)
