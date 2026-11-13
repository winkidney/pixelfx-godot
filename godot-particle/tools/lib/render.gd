# ./pfxp render: an effect's frames the way the reference renders them (godot/tools/lib/fxlib.gd renderFrames): the
# original's canvas, the effect at its origin, the original's backdrop (floor at the origin), the stand-in between the
# back and front layers, 30 fps, round(duration * 30) frames for a loop and one more for a one-shot.
# Needs a renderer (./pfxp runs it under xvfb-run with --fixed-fps 30). Writes records/render/<id>/0000.png ...
extends RefCounted

const Backdrop := preload("res://addons/pixelfx_particles/core/backdrop.gd")


func run(tree: SceneTree, ids: PackedStringArray, flags: Dictionary) -> int:
	if DisplayServer.get_name() == "headless":
		printerr("render needs a renderer: run it through ./pfxp (xvfb-run)")
		return 1
	var out_root: String = flags.get("out", "res://records/render")
	var failed := 0
	for id in ids:
		var path := "res://addons/pixelfx_particles/fx/%s.tscn" % id
		if not ResourceLoader.exists(path):
			printerr("%s: no scene (./pfxp build %s)" % [id, id])
			failed += 1
			continue
		var t0 := Time.get_ticks_msec()
		var n: int = await render_one(tree, id, path, out_root.path_join(id))
		if n < 0:
			failed += 1
		elif not flags.has("quiet"):
			print("%s  %d frames  %d ms" % [id, n, Time.get_ticks_msec() - t0])
	return 1 if failed else 0


func render_one(tree: SceneTree, id: String, path: String, dir: String) -> int:
	var packed: PackedScene = load(path)
	var fx: Node2D = packed.instantiate()
	var w: int = fx.canvas_size.x
	var h: int = fx.canvas_size.y
	var n := maxi(1, int(roundf(fx.duration * fx.fps)) + (0 if fx.loop else 1))
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	var bg := TextureRect.new()
	var bgimg := Backdrop.image(fx.bg, w, h, fx.origin.y)
	bg.texture = ImageTexture.create_from_image(bgimg)
	bg.z_index = -100
	vp.add_child(bg)
	fx.position = Vector2(fx.origin)
	# frame 0 is the effect at t = 0, as the reference's is: held still until it's captured
	fx.speed = 0.0
	vp.add_child(fx)
	tree.root.add_child(vp)
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	bgimg.save_png(abs_dir.path_join("backdrop.png"))
	for i in n:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(abs_dir.path_join("%04d.png" % i))
		if i == 0:
			fx.speed = 1.0
	vp.queue_free()
	await tree.process_frame
	return n
