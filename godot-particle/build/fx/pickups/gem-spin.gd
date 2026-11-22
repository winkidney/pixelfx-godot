# reimagined-from: src/fx/pickups/gem-spin.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Gem spin: A brilliant-cut ruby turning on its axis: real facets catch the light in turn, flashes roll over the crown, refracted light slides across the floor, sparkles wink round it.
# loop, 2.40 s, 64x64 canvas, origin [32, 56], backdrop ground
# ramp palette: #16040e #3e0a1e #760e2e #b8163c #ec3250 #ff7482 #ffc4c8 #ffffff
# The ruby is a canvas shader ray-casting the original's brilliant cut facet by facet (fx/pickups/_gem.gdshader),
# its hover and turn keyed every frame; the halo and heart light are keyed lights; the refracted spots sliding over
# the floor, the star flaring on the crown and the sparkles winking round it are particles placed frame by frame
# where the original draws them, each with its glow.
extends "res://build/fx/pickups/_pickups.gd"

const HOVER := 19.0


func pose(t: float) -> Dictionary:
	return {"y": -HOVER - 1.8 * sin((t / D) * TAU), "spin": (t / D) * PI}


func make() -> void:
	var seed_ := 6
	var gem := brilliant({"r": 7.5, "crown": 3.2, "table": 0.5, "pavilion": 9.5, "girdle": 0.9})
	# behind: the shadow and the light refracted onto the floor
	shadow("Shadow", func(i: int, t: float) -> Array:
		var lift: float = (-pose(t).y - HOVER + 2.0) / 4.0
		return [0.0, 8.0 - lift * 1.5, 0.75 - lift * 0.2], {"span": 12})
	var spots := []
	for i in NF:
		var spin: float = pose(ft(i)).spin
		var r := []
		for k in 3:
			var a := spin * 4.0 + (k * TAU) / 3.0
			var x := sin(a) * 9.0
			var k2 := 0.5 + 0.5 * cos(a)
			if k2 < 0.15:
				r += [null, null, null]
				continue
			r.append(dot_e(x, 0.0, 6 if k2 > 0.7 else 5, k2 * 1.2, [x + 0.5, 0.0, 6.0, C[5], 0.3 * k2]))
			r.append(dot_e(x + 1.0, 0.0, 4, k2 * 0.8))
			r.append(dot_e(x - 1.0, 0.0, 4, k2 * 0.6))
		spots.append(r)
	table("Refraction", K_DOT, spots, {"back": true})
	glows("Glow", func(i: int, t: float) -> Array:
		var y: float = pose(t).y
		return [{"t": G_RING, "c": C[4], "p": Vector2(0, y - 1), "r": 5.0, "w": 15.0, "k": 0.34},
			{"c": C[3], "p": Vector2(0, y), "r": 26.0, "k": 0.14}])
	gem_body("Gem", gem, func(i: int, t: float) -> Array:
		var q := pose(t)
		return [0.0, q.y, q.spin], {"tilt": 0.22})
	# the star flaring on the crown twice a loop, then the sparkles winking round it one after another
	var rows := []
	for i in NF:
		var t := ft(i)
		var q := pose(t)
		var y: float = q.y
		var r := []
		var f := fmod((q.spin * 4.0) / TAU, 1.0)
		var fk := maxf(0.0, 1.0 - absf(f - 0.5) / 0.08)
		r.append(glint_e(-3.0, y - 3.0, 3.4 * out_quad(fk), 6, 0.45 * fk) if fk > 0.0 else null)
		for j in 8:
			var life := 0.4
			var age := jmod(t - (j / 8.0) * D - rand([j, seed_, 3]) * 0.1, D)
			if age > life:
				r.append(null)
				continue
			var a := rand([j, seed_, 1]) * TAU + j * 2.4
			var d := 10.0 + rand([j, seed_, 2]) * 7.0
			var k := sin((age / life) * PI)
			r.append(glint_e(cos(a) * d, y + sin(a) * d * 0.8 - age * 6.0, jround(2.4 * k * (0.6 + 0.4 * rand([j, 9]))), 6 if j % 3 else 8, 0.4 * k))
		rows.append(r)
	table("Glints", K_GLINT, rows)
