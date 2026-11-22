# reimagined-from: src/fx/melee/double-slash.js@2aa6e6e0918f3e0f3083f611be9a4c5b2bd91962
# Double slash: a cut down and a cut back up cross in an X in front of the fighter; as the second closes the X both
# flash white, a star flares at the crossing and throws slivers, sparks and twinkles.
# Both strokes are lens-shaped crescents from the slash shader (fx/melee/_slash.gdshader) on the original's swings,
# keyed from its sweep / hold / trail (and its two-frame white flash), with their light and dotted traces; the
# crossing's star is fx/melee/_flare.gdshader, its slivers fx/melee/_slivers.gdshader; sparks, shavings and
# twinkles are the original's spawns replayed on GPU particles (fx/melee/_kinds.gdshader); lights flare and die.
extends "res://build/fx/melee/_melee.gd"

const UP := 0.14
const R0 := 62.0
const X := 34.0
const Y := -23.0


func make() -> void:
	var down := through(X, Y, 0.72, 1, R0, 0.84, 0.55, {"W": 10.0, "t0": 0.0, "sweep": 0.06, "hold": 0.07, "trail": 0.24, "lens": true})
	var up := through(X, Y, -0.66, -1, R0, 0.84, 0.55, {"W": 11.0, "t0": UP, "sweep": 0.06, "hold": 0.06, "trail": 0.26, "lens": true})
	var ends := [slash_end(down), slash_end(up)]
	var sl := []
	for a in [-2.4, -1.1, 0.2, 1.6]:
		sl.append([a + R.rf(-0.2, 0.2), R.rf(5, 8), R.rf(70, 120), R.rf(0.4, 0.7)])
	var CLOSE := UP + 0.012
	# both strokes flash white for two frames when the X closes
	var hot := func(t: float) -> float: return 1.0 if (t >= CLOSE and t < CLOSE + 0.07) else 0.0
	slash("Down", down, 0.0, {"hot": hot})
	slash("Up", up, 0.0, {"hot": hot})

	# glints at the ends of the strokes
	for j in 2:
		var s: Dictionary = [down, up][j]
		var e: Dictionary = ends[j]
		var g0: float = s.t0 + s.sweep * 0.6
		sparkle("Glint%d" % j, e.p, C[5], C[3], func(t: float) -> Array:
			var g := t - g0
			return [7.0 * out_back(minf(1.0, g / 0.05)) * (1.0 - g / 0.2), 0.5], g0, g0 + 0.2)
	# the crossing: a flare, slivers flying off it, light
	var at := Vector2(X, Y)
	flare("Flare", at, 24, func(t: float) -> Array:
		var k := (t - CLOSE) / 0.26
		return [22.0 * pow(1.0 - k, 1.4), 1.0 - k], CLOSE, CLOSE + 0.26)
	glow_path("FlareLight", 35, C[4], func(t: float) -> Array: return [at, 34.0, 0.35 * (1.0 - (t - CLOSE) / 0.26)], CLOSE, CLOSE + 0.26)
	slivers("Slivers", at, sl, CLOSE + 0.03, 0.12, C[6], C[5], C[4])
	# light rides each edge as it goes
	for j in 2:
		var s: Dictionary = [down, up][j]
		glow_path("Ride%d" % j, 41, C[3], func(t: float) -> Array:
			var u: float = t - s.t0
			var h := s.duplicate()
			h.span = s.span * out_expo(clamp01(u / s.sweep))
			return [slash_end(h).p, 40.0, 0.5 * (1.0 - u / 0.25) if u > 0.0 else 0.0], s.t0, s.t0 + 0.25)

	# the first cut lands: shavings and sparks off its end
	var e0: Dictionary = ends[0]
	var sparks := []
	for i in 6:
		var a: float = e0.d.angle() + R.rf(-0.5, 0.5)
		var v := R.rf(120, 300)
		sparks.append(sp(e0.p.x, e0.p.y, cos(a) * v, sin(a) * v, R.rf(0.12, 0.3)))
	burst("Shavings0", MOTE, down.sweep, shavings(down, 10, [C[4], C[5]]))
	burst("Sparks0", SPARK, down.sweep, sparks)
	# the X closes: light, sparks all round, twinkles
	light_burst("Flash", CLOSE, at, 56, C[3], 0.45, 0.4)
	light_burst("White", CLOSE, at, 18, Color.WHITE, 0.6, 0.08)
	var cross := []
	for i in 18:
		var a := R.rf(-PI, PI) * 0.8
		var v := R.rf(140, 360)
		cross.append(sp(X, Y, cos(a) * v, sin(a) * v - 40.0, R.rf(0.14, 0.4)))
	burst("Sparks1", SPARK, CLOSE, cross)
	var stars := []
	for i in 5:
		stars.append(sp(X + R.rf(-14, 14), Y + R.rf(-12, 12), 0, -4, R.rf(0.2, 0.4), C[5] if R.chance(0.5) else Color.WHITE, R.rf(1, 2.2), R.rf(0.05, 0.2)))
	burst("Stars", STAR, CLOSE, stars)
	burst("Shavings1", MOTE, UP + up.sweep, shavings(up, 12, [C[4], C[5]]))
