// The start of a weather particle canvas shader (the body a _wx_place process shader placed): `d` is a fragment's
// pixel cell from the particle's cell, `cu` its CUSTOM (xy: the fraction of its place inside the cell), `pc` its
// COLOR. The quad is `quad` px (even), centred on the cell's corner, so its fragments are whole pixels.

uniform vec2 quad = vec2(16.0);

varying flat vec4 cu;
varying flat vec4 pc;

void vertex() {
	cu = INSTANCE_CUSTOM;
	pc = COLOR;
}

vec2 wx_cell(vec2 uv) {
	return floor((uv - 0.5) * quad);
}
