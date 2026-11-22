// ice/ice-lance's rings of cold air: an upright ellipse (`rx` wide, `ry` tall, centred on the rect's middle) dotted
// with 40 points, the near (right) half in `near`, the far half in `far`; points inside the spear (|y| < `hole`, x
// past `cut` px from the middle) are left out. Key rx, ry, cut, near, far and the position. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform float rx = 2.0;
uniform float ry = 5.0;
uniform float hole = 4.6;
uniform float cut = -100.0;
uniform vec4 near : source_color = vec4(1.0);
uniform vec4 far : source_color = vec4(1.0);
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 q = floor((UV - 0.5) * size);
	vec4 c = vec4(0.0);
	bool hit = false;
	for (int k = 0; k < 40; k++) {
		float an = float(k) / 40.0 * 6.2831853;
		vec2 pt = vec2(cos(an) * rx, sin(an) * ry);
		if (abs(pt.y) < hole && pt.x > cut) {
			continue;
		}
		if (floor(pt) == q) {
			c = cos(an) > 0.0 ? near : far;
			hit = true;
		}
	}
	if (!hit) {
		discard;
	}
	c.a *= alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
