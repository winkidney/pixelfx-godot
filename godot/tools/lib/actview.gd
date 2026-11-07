# ./pfx act: an effect acted out (the character, the target, the freeze on contact). Motion is what you are judging,
# so the strip shows consecutive 12 fps steps, not a sample.
#   ./pfx act melee/sword-slash            strip: records/act/melee-sword-slash.png
#   ./pfx act melee/sword-slash --webp     lossless animated WebP: records/act/melee-sword-slash.webp
#   ./pfx act melee/sword-slash --mp4      video: records/act/melee-sword-slash.mp4
#   ./pfx act melee/sword-slash --sheet    the whole act, character and all, as a transparent sprite sheet
# Options: --from S --to S (strip range) --step S (default 1/12) --cols N --zoom N --bg KIND --out FILE --no-target --seconds S
# port-of: tools/act.mjs (upstream)
extends RefCounted

const Px := preload("res://addons/pixelfx/core/px.gd")
const Lib := preload("fxlib.gd")


func run(ids: PackedStringArray, flags: Dictionary) -> int:
	if ids.is_empty():
		return 1
	for id in ids:
		var fx := Lib.loadEffect(id)
		if fx.has("error"):
			printerr(fx.error)
			return 1
		var base := "res://records/act/" + id.replace("/", "-")
		if flags.has("sheet"):
			var r := Lib.renderAct(fx, {"fps": fx.meta.fps, "bg": "none", "target": not flags.has("no-target"), "hold": 0.0})
			var name := id.get_file()
			var s := Lib.spriteSheet(fx, r, name)
			s.json.meta.pixelfx.pivot = r.pivot
			Lib.save_png(base + ".sheet.png", s.image)
			Lib.save_text(base + ".sheet.json", JSON.stringify(s.json, " "))
			print("%s  %d frames of %d x %d  ->  %s" % [id, r.n, r.w, r.h, ProjectSettings.globalize_path(base + ".sheet.png")])
			continue
		var r := Lib.renderAct(fx, {"fps": 60.0, "bg": flags.get("bg"), "target": not flags.has("no-target"), "seconds": float(flags.seconds) if flags.has("seconds") else null})
		if flags.has("mp4") or flags.has("webp"):
			var k := int(flags.get("zoom", maxi(2, mini(8, int(960.0 / maxi(r.w, r.h))))))
			var file: String = flags.get("out", base + (".webp" if flags.has("webp") else ".mp4"))
			Lib.writeVideo(file, r, k)
			print("%s  %d frames  %.2f s  ->  %s" % [id, r.frames.size(), r.frames.size() / r.fps, ProjectSettings.globalize_path(file)])
			continue
		var from := float(flags.get("from", r.frames[0].t))
		var to := float(flags.get("to", r.frames[r.frames.size() - 1].t))
		var step := float(flags.get("step", 1.0 / 12.0))
		var list := []
		for f in r.frames:
			if f.t < from - 1e-6 or f.t > to + 1e-6:
				continue
			if f.t + 1e-6 >= from + list.size() * step:
				list.append(f)
		var k := int(flags.get("zoom", 3))
		var cols := int(flags.get("cols", 8))
		var rows := ceili(list.size() / float(cols))
		var img := Lib.Canvas.new(cols * (r.w * k + 4), rows * (r.h * k + 18))
		for j in list.size():
			var x: int = (j % cols) * (r.w * k + 4)
			var y: int = floori(j / float(cols)) * (r.h * k + 18)
			img.text("%.2f" % list[j].t, x + 2, y + 3, 2)
			img.paste(Lib.upscale(list[j].color, r.w, r.h, k), r.w * k, r.h * k, x, y + 16)
		var file: String = flags.get("out", base + ".png")
		Lib.save_png(file, img.img)
		print("%s  %d steps  ->  %s" % [id, list.size(), ProjectSettings.globalize_path(file)])
	return 0
