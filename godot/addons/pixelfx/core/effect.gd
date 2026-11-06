# The base of a simulated effect (the JS `create(o)` that returns { update, draw, drawBack }). An effect script
# that keeps state extends this, keeps what the JS closure captured as member variables, and overrides:
#   func create(o: Dictionary) -> void      set up (the body of the JS create)
#   func update(dt: float) -> void          step (the runtime calls it at 120 Hz or finer)
#   func draw(p: Painter) -> void           what goes in front of a character
#   func drawBack(p: Painter) -> void       what goes behind (optional)
# A script may instead export `static func create(o) -> <an object with these methods>` (moves use chain()).
extends RefCounted

const Painter := preload("painter.gd")


func create(_o: Dictionary) -> void:
	pass


func update(_dt: float) -> void:
	pass


func draw(_p: Painter) -> void:
	pass


func drawBack(_p: Painter) -> void:
	pass
