// The magic missile's orb (projectiles/magic-missile.js): a violet rim, a bright body, a white heart a little up and
// left, and three sparks turning round it on a squashed ring. Coordinates are px from the effect's origin; key pos,
// r (the heart's radius, growing as it gathers) and ang (the sparks' turn).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 pos = vec2(0.0);
uniform float r = 4.0;
uniform float ang = 0.0;
uniform vec4 rim : source_color = vec4(1.0);
uniform vec4 body : source_color = vec4(1.0);
uniform vec4 spark : source_color = vec4(1.0);

bool disc(vec2 cell, vec2 c, float rr) {
	if (rr < 0.6) {
		return cell == floor(c);
	}
	vec2 d = cell + 0.5 - c;
	return dot(d, d) <= rr * rr;
}

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	vec4 col = vec4(0.0);
	if (disc(cell, pos, r + 1.4)) {
		col = rim;
	}
	if (disc(cell, pos, r + 0.4)) {
		col = body;
	}
	if (disc(cell, pos - 0.4, r * 0.55)) {
		col = vec4(1.0);
	}
	for (int i = 0; i < 3; i++) {
		float a = ang + float(i) * 6.28318530718 / 3.0;
		if (cell == floor(pos + vec2(cos(a) * (r + 3.0), sin(a) * (r + 3.0) * 0.6))) {
			col = i == 0 ? vec4(1.0) : spark;
		}
	}
	if (col.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
