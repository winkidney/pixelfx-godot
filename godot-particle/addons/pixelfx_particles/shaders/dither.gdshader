// The colour layer of a pixelfx particle effect (the original's `color` buffer): no translucency, as in pixel art.
// Alpha becomes on/off through a 4x4 Bayer matrix on the screen's pixel grid, and colours snap to the effect's
// palette so a filtered colour ramp can't leave in-between colours. Put it on particles, sprites and lines.
shader_type canvas_item;

#include "pixel.gdshaderinc"

void fragment() {
	vec4 c = COLOR;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
