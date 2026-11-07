# pixelfx command line for Godot. Run it through ./pfx (godot --headless --path godot -s res://tools/cli.gd -- ...).
#
#   ./pfx list [words]                    search ids, names, tags and descriptions
#   ./pfx render <ids> [--webp] [--gif] [--mp4] [--sheet] [--all] [--zoom N] [--bg KIND] [--seed N] [--opts JSON] [--no-actor]
#   ./pfx check [ids]                     catch spills, seams, unseeded randomness, slow frames, act mistakes
#   ./pfx act <ids> [--webp] [--mp4] [--sheet]   an effect acted out: consecutive 12 fps steps
#   ./pfx sheets [ids] [--spriteframes]   sprite sheets (PNG + JSON, and SpriteFrames .tres) for the library
#   ./pfx new <category>/<name> [--loop] [--sim]   a working starting point
#   ./pfx index                           regenerate fx/registry.gd and docs/CATALOG.md
#   ./pfx parity [ids] [--full] [--variants a,b] [--no-sheet] [--quiet]   check the port against the JS original
#   ./pfx parity [ids] --acts             the same for acts: body, target, freezes and shakes
#   ./pfx test                            core unit tests against the JS fixtures
#   ./pfx bench [ids]                     how long a frame takes to render LIVE (median and worst, ms)
#
# Outputs go to godot/records/ (git-ignored). Ids are "category/name"; a category or a pattern ("fire/*") works too.
extends SceneTree

const Px := preload("res://addons/pixelfx/core/px.gd")
const Lib := preload("res://tools/lib/fxlib.gd")
const Parity := preload("res://tools/lib/parity.gd")

const BOOL_FLAGS := ["webp", "gif", "mp4", "sheet", "all", "no-actor", "full", "no-sheet", "quiet", "loop", "sim", "spriteframes", "no-target", "help", "acts"]

var flags := {}
var pos := PackedStringArray()


func _initialize() -> void:
	var code: Variant = main()
	quit(code if code is int else 1)


func main() -> int:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--"):
			var k := a.substr(2)
			if k in BOOL_FLAGS or i + 1 >= args.size():
				flags[k] = true
			else:
				flags[k] = args[i + 1]
				i += 1
		else:
			pos.append(a)
		i += 1
	if pos.is_empty() or flags.has("help"):
		return help()
	var cmd := pos[0]
	pos = pos.slice(1)
	match cmd:
		"list": return cmd_list()
		"render": return cmd_render()
		"parity": return cmd_parity()
		"test": return cmd_test()
		"bench": return cmd_bench()
		"check": return load("res://tools/lib/check.gd").new().run(ids_or_all(), flags)
		"act": return load("res://tools/lib/actview.gd").new().run(ids(), flags)
		"sheets": return load("res://tools/lib/sheets.gd").new().run(ids_or_all(), flags)
		"new": return load("res://tools/lib/newfx.gd").new().run(pos, flags)
		"index": return load("res://tools/lib/index.gd").new().run()
		"help": return help()
	printerr("unknown command: ", cmd)
	return help(1)


func help(code: int = 0) -> int:
	var src := FileAccess.get_file_as_string("res://tools/cli.gd").split("\n")
	for line in src:
		if not line.begins_with("#"):
			break
		print(line.substr(2))
	return code


func ids() -> PackedStringArray:
	if pos.is_empty():
		printerr("which effects? give ids, categories or patterns")
		return PackedStringArray()
	return Lib.resolveIds(pos)


func ids_or_all() -> PackedStringArray:
	return Lib.allIds() if pos.is_empty() else Lib.resolveIds(pos)


func cmd_list() -> int:
	var words := pos
	var n := 0
	for id in Lib.allIds():
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			continue
		var m: Dictionary = fx.meta
		var hay := ("%s %s %s %s" % [id, m.get("name", ""), " ".join(m.get("tags", [])), m.get("desc", "")]).to_lower()
		var ok := true
		for w in words:
			if not (w.to_lower() in hay):
				ok = false
		if not ok:
			continue
		n += 1
		print("%-28s %s%s  %s" % [id, m.get("name", ""), " (loop)" if m.loop else "", m.get("desc", "")])
	print("%d effects" % n)
	return 0


func cmd_render() -> int:
	var list := ids()
	if list.is_empty():
		return 1
	var out: String = flags.get("out", "res://records")
	var failed := 0
	for id in list:
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			printerr(id, "  FAILED: ", fx.error)
			failed += 1
			continue
		var options: Dictionary = JSON.parse_string(flags.opts) if flags.has("opts") else {}
		var r := Lib.renderFrames(fx, {
			"fps": float(flags.fps) if flags.has("fps") else null,
			"seed": float(flags.seed) if flags.has("seed") else null,
			"bg": flags.get("bg"),
			"actor": false if flags.has("no-actor") else null,
			"options": options,
		})
		var dir: String = out.path_join(id)
		var made := []
		var zoom: Variant = int(flags.zoom) if flags.has("zoom") else null
		made.append(Lib.save_png(dir.path_join("contact.png"), Lib.contactSheet(fx, r, {"max": 400 if flags.has("all") else int(flags.get("max", 16)), "zoom": zoom})))
		var k := int(flags.get("scale", maxi(2, mini(8, int(480.0 / maxi(r.w, r.h))))))
		var loops := int(flags.get("loops", 2 if fx.meta.loop else 1))
		# an animated WebP loops by itself: one pass unless --loops says otherwise
		if flags.has("webp") and Lib.writeVideo(dir.path_join("anim.webp"), r, k, int(flags.get("loops", 1))):
			made.append(dir.path_join("anim.webp"))
		if flags.has("gif") and Lib.writeVideo(dir.path_join("anim.gif"), r, k, loops):
			made.append(dir.path_join("anim.gif"))
		if flags.has("mp4") and Lib.writeVideo(dir.path_join("anim.mp4"), r, k, maxi(loops, 3 if fx.meta.loop else 1)):
			made.append(dir.path_join("anim.mp4"))
		if flags.has("sheet"):
			var name := id.get_file()
			var s := Lib.spriteSheet(fx, r, name)
			made.append(Lib.save_png(dir.path_join(name + ".png"), s.image))
			made.append(Lib.save_text(dir.path_join(name + ".json"), JSON.stringify(s.json, " ")))
		print("%s  %d frames  ->  %s" % [id, r.n, "  ".join(made.map(func(f): return ProjectSettings.globalize_path(f)))])
	return 1 if failed else 0


func cmd_parity() -> int:
	var list := ids_or_all()
	var p := Parity.new()
	p.quiet = flags.has("quiet")
	p.sheets = not flags.has("no-sheet")
	var variants: Array = Parity.QUICK
	if flags.has("full"):
		variants = ["default", "flip", "angle", "pal4", "recolor", "seed7", "light", "stop"]
	if flags.has("variants"):
		variants = Array(String(flags.variants).split(","))
	if flags.has("acts"):
		return 1 if p.checkActs(list) else 0
	return 1 if p.check(list, variants) else 0


func cmd_bench() -> int:
	var total := 0.0
	var n := 0
	for id in ids_or_all():
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			continue
		var meta: Dictionary = fx.meta
		var frame := Px.createFrame(meta.size[0], meta.size[1])
		var inst := Px.createFx(fx.mod, {"x": float(meta.origin[0]), "y": float(meta.origin[1])})
		var frames := maxi(1, int(Px.round(meta.duration * meta.fps)))
		var ms := []
		for i in frames:
			var t0 := Time.get_ticks_usec()
			if i:
				inst.update(1.0 / meta.fps)
			frame.clear()
			inst.draw(frame)
			ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		ms.sort()
		var med: float = ms[ms.size() >> 1]
		total += med
		n += 1
		print("%-34s median %6.1f ms   worst %6.1f ms" % [id, med, ms[ms.size() - 1]])
	if n:
		print("%d effects, mean of medians %.1f ms" % [n, total / n])
	return 0


func cmd_test() -> int:
	var out := []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--no-header", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/core_test.gd"]), out, true)
	print("".join(out).strip_edges())
	return code
