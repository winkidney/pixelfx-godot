// A spent casing as the gun effects draw it (projectiles/_lib.js drawCasing(), muzzle-shotgun's shell), over a box
// that holds its whole flight (build/fx/projectiles/_muzzle.gd casing_node()): `pos` and `ang` keyed along _lib.js
// casing(). mode 0: a brass slug, three dots along its angle (c0 dark end, c1, c2 lit end), a white glint over it
// just after it hits; mode 1: a shotgun shell, a row of seven dots (c1 hull to c4 brass head) over a row of five
// (c0, c3 at the head). `fade` fades it (dithered). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform float mode = 0.0;
uniform vec2 pos = vec2(0.0);
uniform float ang = 0.0;
uniform float fade = 1.0;
uniform float glint = 0.0;
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);

bool at(vec2 cell, vec2 p) {
	return all(equal(cell, floor(p)));
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	float ca = cos(ang);
	float sa = sin(ang);
	vec4 col = vec4(0.0);
	if (mode < 0.5) {
		vec2 p = vec2(pos.x, pos.y - 0.5);
		if (at(cell, p - vec2(ca, sa))) {
			col = c0;
		}
		if (at(cell, p)) {
			col = c1;
		}
		if (at(cell, p + vec2(ca, sa))) {
			col = c2;
		}
		col.a *= fade;
		if (glint > 0.5 && at(cell, vec2(p.x + ca * 0.5, p.y - 1.0))) {
			col = vec4(1.0);
		}
	} else {
		for (int i = 0; i < 7; i++) {
			float d = -1.5 + float(i) * 0.5;
			if (at(cell, vec2(pos.x + ca * d, pos.y + sa * d - 0.5))) {
				col = d > 0.8 ? (d > 1.2 ? c4 : c3) : d > -0.6 ? c2 : c1;
			}
		}
		for (int i = 0; i < 5; i++) {
			float d = -1.0 + float(i) * 0.5;
			if (at(cell, vec2(pos.x + ca * d - sa, pos.y + sa * d + ca - 0.5))) {
				col = d > 0.6 ? c3 : c0;
			}
		}
		col.a *= fade;
	}
	if (col.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
