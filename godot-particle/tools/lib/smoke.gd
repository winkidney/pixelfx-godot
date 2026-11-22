# ./pfxp smoke [ids]: every built effect through the nodes a game uses, for real (under xvfb-run): PixelFxParticles2D
# (pixel view, a recolour, flipped) played to its end, and PixelFxParticlesAct2D for the effects with an act. A
# one-shot must say `finished`; nothing may error (Godot prints errors itself; the exit code counts what this sees).
extends RefCounted


func run(tree: SceneTree, ids: PackedStringArray, flags: Dictionary) -> int:
	var REG: Script = load("res://addons/pixelfx_particles/fx/registry.gd")
	var effects: Dictionary = REG.EFFECTS
	var bad := 0
	var n := 0
	for id in ids:
		if not effects.has(id):
			continue
		n += 1
		var e: Dictionary = effects[id]
		var fx := Node2D.new()
		fx.set_script(load("res://addons/pixelfx_particles/nodes/pixel_fx_particles_2d.gd"))
		fx.zoom = 2
		fx.flip = true
		fx.palette_preset = "arcane"
		fx.position = Vector2(200, 200)
		var said := [false]
		fx.finished.connect(func(): said[0] = true)
		tree.root.add_child(fx)
		fx.effect = id
		var frames := int(ceil((float(e.duration) + 0.5) * 30.0))
		if e.loop:
			frames = 20
		for i in frames:
			await tree.process_frame
		if e.loop:
			fx.stop()
			for i in 15:
				await tree.process_frame
		if not said[0]:
			print("FAIL  %s: no finished signal" % id)
			bad += 1
		fx.queue_free()
		if e.act:
			var act := Node2D.new()
			act.set_script(load("res://addons/pixelfx_particles/nodes/pixel_fx_particles_act_2d.gd"))
			act.zoom = 2
			act.position = Vector2(300, 300)
			var done := [false]
			act.finished.connect(func(): done[0] = true)
			tree.root.add_child(act)
			act.effect = id
			for i in 900:
				await tree.process_frame
				if done[0]:
					break
			if not done[0]:
				print("FAIL  %s act: no finished signal" % id)
				bad += 1
			act.queue_free()
		await tree.process_frame
		if not flags.has("quiet"):
			print("ok    ", id)
	print("\n%d effects through the nodes, %d failed" % [n, bad])
	return 1 if bad else 0
