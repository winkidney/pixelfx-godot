# P0 spike: GPU particles under Xvfb + the Compatibility renderer, frame readback from a SubViewport, fixed-seed
# determinism, a Bayer-dithered alpha shader and a stepped colour ramp. Usage (run twice, then compare):
#   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/spike.gd -- <run>
extends SceneTree

const DITHER := """
shader_type canvas_item;
const float B[16] = float[](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float t = (B[p.y * 4 + p.x] + 0.5) / 16.0;
	if (COLOR.a < t) discard;
	COLOR.a = 1.0;
}
"""


func _initialize() -> void:
	var run := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() else "0"
	var props := []
	for p in ClassDB.class_get_property_list("GPUParticles2D", true):
		if "seed" in p.name or "fixed" in p.name or "fract" in p.name or "interp" in p.name:
			props.append(p.name)
	print("GPUParticles2D: ", props)
	print("renderer: ", RenderingServer.get_current_rendering_method(), " | adapter: ", RenderingServer.get_video_adapter_name())
	_run.call_deferred(run)


func _run(run: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#15131d")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)

	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var p := GPUParticles2D.new()
	p.position = Vector2(48, 84)
	p.amount = 80
	p.lifetime = 1.2
	p.fixed_fps = 30
	p.interpolate = false
	p.set("use_fixed_seed", true)
	p.set("seed", 12345)
	p.texture = ImageTexture.create_from_image(img)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 22.0
	m.initial_velocity_min = 22.0
	m.initial_velocity_max = 44.0
	m.gravity = Vector3(0, -6, 0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(6, 1, 0)
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.4, 0.7, 0.9])
	g.colors = PackedColorArray([Color("#ffffff"), Color("#ffe066"), Color("#ff8a3d"), Color("#c2361f"), Color(0.35, 0.1, 0.1, 0.4)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = DITHER
	sm.shader = sh
	p.material = sm
	vp.add_child(p)

	var dir := "res://records/spike/run" + run
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var t0 := Time.get_ticks_msec()
	for f in 60:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(dir + "/%03d.png" % f)
	print("60 frames in %d ms" % (Time.get_ticks_msec() - t0))
	quit()
