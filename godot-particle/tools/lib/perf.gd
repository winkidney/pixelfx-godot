## Runtime cost of each effect on a real GPU: one instance, then a crowd of them, each played through its own
## duration (3 s for a loop) with the frame rate uncapped. The same file runs in both projects: in godot/ it plays
## PixelFx2D (mode live: the CPU rasterizes every frame; baked: frames rendered on first show, then replayed), in
## godot-particle/ PixelFxParticles2D (GPU particles and shaders). Needs a real display, not --headless or Xvfb:
##   ./pfxp perf [ids] [--stress 64] [--loop-secs 3] [--out res://records/perf/particle.json]
##   ./pfx perf [ids] --mode live|baked [--stress 64] [--out res://records/perf/pixel-live.json]
## Per frame: wall time between frames (what a game feels: with vsync off it waits on the GPU too), the measured
## render CPU and GPU time of every viewport (the window's and each pixel view's), draw calls. Written as mean / p95 / max per effect, plus an empty-scene baseline and the machine it ran on.
extends RefCounted

const WARM := 30
const PARTICLE_REG := "res://addons/pixelfx_particles/fx/registry.gd"
const PIXEL_REG := "res://addons/pixelfx/fx/registry.gd"

var particle := false
var effects := {}
var mode := "live"


func run(tree: SceneTree, ids: PackedStringArray, flags: Dictionary) -> int:
	particle = ResourceLoader.exists(PARTICLE_REG)
	effects = load(PARTICLE_REG if particle else PIXEL_REG).EFFECTS
	mode = String(flags.get("mode", "live"))
	var crowd := int(flags.get("stress", 64))
	var loop_secs := float(flags.get("loop-secs", 3.0))
	var port := "particle" if particle else "pixel-" + mode
	var out: String = flags.get("out", "res://records/perf/%s.json" % port)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 0
	var vp := tree.root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var host := Node2D.new()
	tree.root.add_child(host)
	var report := {
		"port": port,
		"machine": {
			"gpu": RenderingServer.get_video_adapter_name(),
			"vendor": RenderingServer.get_video_adapter_vendor(),
			"api": RenderingServer.get_video_adapter_api_version(),
			"driver": RenderingServer.get_current_rendering_driver_name(),
			"method": RenderingServer.get_current_rendering_method(),
			"cpu": OS.get_processor_name(),
			"threads": OS.get_processor_count(),
			"godot": Engine.get_version_info().string,
			"window": [1280, 720],
		},
		"stress": crowd,
		"baseline": await _measure(tree, host, 2.0),
		"effects": {},
	}
	var ok := 0
	for id in ids:
		if not effects.has(id):
			continue
		var e: Dictionary = effects[id]
		var secs: float = loop_secs if e.loop else float(e.duration)
		var row := {"loop": e.loop, "duration": e.duration, "size": e.size}
		if not particle and mode == "baked":
			# the first play renders every frame once (the bake); a second play only replays them
			_spawn(host, id, 1, 2)
			row["bake"] = await _measure(tree, host, secs, 0)
			_clear(host)
		_spawn(host, id, 1, 2)
		row["single"] = await _measure(tree, host, secs)
		_clear(host)
		_spawn(host, id, crowd, 1)
		row["crowd"] = await _measure(tree, host, secs)
		_clear(host)
		report.effects[id] = row
		ok += 1
		print("%-34s  1x %6.3f ms (gpu %6.3f)   %dx %7.3f ms (gpu %7.3f)" % [id, row.single.frame_ms.mean,
			row.single.gpu_ms.mean, crowd, row.crowd.frame_ms.mean, row.crowd.gpu_ms.mean])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("%d effects -> %s" % [ok, ProjectSettings.globalize_path(out)])
	return 0


## n instances of the effect laid out over the window, each its own take, at a whole-pixel zoom.
func _spawn(host: Node2D, id: String, n: int, zoom: int) -> void:
	var e: Dictionary = effects[id]
	var cols := int(ceil(sqrt(n)))
	for i in n:
		var fx := Node2D.new()
		if particle:
			fx.set_script(load("res://addons/pixelfx_particles/nodes/pixel_fx_particles_2d.gd"))
			fx.take = i
			fx.zoom = zoom
		else:
			fx.set_script(load("res://addons/pixelfx/nodes/pixel_fx_2d.gd"))
			fx.mode = 1 if mode == "live" else 0
			# baked nodes with the same options share one set of frames, as a game would use them; live ones each
			# simulate their own take
			fx.seed = (i + 1) if mode == "live" else -1
			fx.scale = Vector2(zoom, zoom)
		var cell := Vector2(1280.0 / cols, 720.0 / ceil(float(n) / cols))
		var at := Vector2((i % cols + 0.5) * cell.x, (floori(float(i) / cols) + 0.5) * cell.y)
		# the node sits on the effect's origin: put the middle of its canvas on the cell's middle
		fx.position = at + Vector2(e.origin[0] - e.size[0] / 2.0, e.origin[1] - e.size[1] / 2.0) * zoom
		host.add_child(fx)
		fx.effect = id


func _clear(host: Node2D) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.free()


## Frames over `secs` of real time after `warm` frames: wall frame time, render CPU / GPU time, draw calls.
func _measure(tree: SceneTree, host: Node2D, secs: float, warm := WARM) -> Dictionary:
	# the window's viewport plus every SubViewport an effect renders into (the particle node's pixel view): their
	# render times summed are the frame's
	var vps: Array[RID] = [tree.root.get_viewport_rid()]
	for sv in host.find_children("*", "SubViewport", true, false):
		vps.append(sv.get_viewport_rid())
		RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)
	if warm > 0:
		for i in warm:
			await tree.process_frame
		# the warm-up played some of each effect (with a slow crowd, all of a short one-shot): start them over so the
		# window measures the whole effect
		for fx in host.get_children():
			fx.play()
		await tree.process_frame
	var frame: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var calls: Array[float] = []
	var start := Time.get_ticks_usec()
	var last := start
	while true:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frame.append((now - last) / 1000.0)
		last = now
		var c := 0.0
		var g := 0.0
		for v in vps:
			c += RenderingServer.viewport_get_measured_render_time_cpu(v)
			g += RenderingServer.viewport_get_measured_render_time_gpu(v)
		cpu.append(c)
		gpu.append(g)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if (now - start) / 1e6 >= secs:
			break
	return {"frames": frame.size(), "secs": (last - start) / 1e6, "frame_ms": _stats(frame), "render_cpu_ms": _stats(cpu),
		"gpu_ms": _stats(gpu), "draw_calls": _stats(calls),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0}


static func _stats(a: Array[float]) -> Dictionary:
	if a.is_empty():
		return {"mean": 0.0, "p95": 0.0, "max": 0.0}
	var s := a.duplicate()
	s.sort()
	var total := 0.0
	for v in s:
		total += v
	return {"mean": snappedf(total / s.size(), 0.0001), "p95": snappedf(s[int(0.95 * (s.size() - 1))], 0.0001),
		"max": snappedf(s[-1], 0.0001)}
