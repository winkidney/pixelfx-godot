# The Godot side: SpriteFrames baking, PixelFx2D (BAKED and LIVE) and PixelFxAct2D in a running scene tree.
#   godot --headless --path godot -s res://tests/node_test.gd [-- ids...]
extends SceneTree

const Px := preload("res://addons/pixelfx/core/px.gd")
const Baker := preload("res://addons/pixelfx/bake/baker.gd")
const Lib := preload("res://tools/lib/fxlib.gd")
# by path, so the test runs before the editor has registered the class names
const FxNode := preload("res://addons/pixelfx/nodes/pixel_fx_2d.gd")
const ActNode := preload("res://addons/pixelfx/nodes/pixel_fx_act_2d.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		push_error("PFX_FAIL " + what)
		print("FAIL ", what)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var ids := OS.get_cmdline_user_args()
	var list: PackedStringArray = Lib.resolveIds(ids) if ids.size() else PackedStringArray(["melee/sword-slash"])
	for id in list:
		var mod: Script = load(Lib.pathOf(id))
		var meta := Px.Fx.metaOf(mod)
		# bake -> SpriteFrames -> file -> back
		var baked := Baker.bake(mod)
		var path := "user://pfx_test_%s.res" % id.replace("/", "-")
		check(Baker.save_sprite_frames(baked, path) == OK, id + " save SpriteFrames")
		var sf: SpriteFrames = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(sf != null and sf.get_frame_count("default") == baked.n, id + " SpriteFrames frame count")
		if sf:
			check(is_equal_approx(sf.get_animation_speed("default"), meta.fps) and sf.get_animation_loop("default") == meta.loop, id + " SpriteFrames fps/loop")
			var mid: int = baked.n >> 1
			var tex := sf.get_frame_texture("default", mid)
			check(tex != null and tex.get_size() == Vector2(baked.size), id + " SpriteFrames frame size")
			# a headless run has no renderer to read a texture back from; compare pixels when there is one
			var img: Image = tex.get_image() if tex else null
			if img != null:
				img.convert(Image.FORMAT_RGBA8)
				check(img.get_data() == (baked.combined[mid] as Image).get_data(), id + " SpriteFrames pixels survive the round trip")
		# the nodes, in a tree
		for mode in [FxNode.Mode.BAKED, FxNode.Mode.LIVE]:
			var fx = FxNode.new()
			fx.effect = id
			fx.mode = mode
			var ended := [false]
			fx.finished.connect(func(): ended[0] = true)
			root.add_child(fx)
			for i in 40:
				await process_frame
			check(fx._color.texture != null or ended[0], "%s PixelFx2D %s shows a frame" % [id, ["BAKED", "LIVE"][mode]])
			if not meta.loop:
				var waited := 0
				while not ended[0] and waited < 600:
					await process_frame
					waited += 1
				check(ended[0], "%s PixelFx2D %s finishes" % [id, ["BAKED", "LIVE"][mode]])
			fx.queue_free()
		if Px.Fx.actOf(mod) != null:
			var act = ActNode.new()
			act.effect = id
			var hits := [0]
			act.hit.connect(func(_h): hits[0] += 1)
			root.add_child(act)
			for i in 400:
				await process_frame
			check(hits[0] > 0 or Px.Fx.actOf(mod).get("hits", []).is_empty(), id + " PixelFxAct2D emits hit")
			act.queue_free()
		print("ok   ", id)
	print("nodes: %d failed" % fails)
	quit(1 if fails else 0)
