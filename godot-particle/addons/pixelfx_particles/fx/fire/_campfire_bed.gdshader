// The campfire's glowing bits: mode 0, the bed of coals under the logs (an ellipse of lumps breathing on their own
// phase, dimmer toward the rim); mode 1, the embers breathing in the cracks of the two logs' charred near halves.
// The original's still pixels (the prop) sit over these, so only the pixels the original lit show through.
// Coordinates are px from the effect's origin; key `t` 0 -> 1 over the loop.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float mode = 0.0;
uniform vec4 c_white : source_color = vec4(1.0);
uniform vec4 c_yellow : source_color = vec4(1.0);
uniform vec4 c_gold : source_color = vec4(1.0);
uniform vec4 c_orange : source_color = vec4(1.0);
uniform vec4 c_red : source_color = vec4(1.0);

float h2(vec2 p, float s) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + s * 17.17) * 43758.5453);
}

// along / across one log from its near end (x0, y0) to (x1, y1), radius r: vec3(u, s, along)
vec3 on_log(vec2 p, vec2 a, vec2 b, float r) {
	vec2 ax = normalize(b - a);
	vec2 n = vec2(-ax.y, ax.x);
	if (n.y < 0.0) {
		n = -n;
	}
	float along = dot(p - a, ax);
	return vec3(along / length(b - a), dot(p - a, n) / r, along);
}

void fragment() {
	vec2 p = floor(UV * size) + 0.5 + center - size * 0.5;
	vec4 c = vec4(0.0);
	if (mode < 0.5) {
		float dx = p.x / 14.0;
		float dy = (p.y + 0.3) / 2.2;
		float d = dx * dx + dy * dy;
		if (d > 1.0) {
			discard;
		}
		float h = h2(vec2(floor(p.x / 2.0), floor(p.y)), 20.0);
		float g = (0.5 + 0.5 * sin(t * 6.2831853 * 2.0 + h * 40.0)) * (1.1 - d);
		c = g > 0.7 ? c_yellow : g > 0.5 ? c_gold : g > 0.3 ? c_orange : c_red;
	} else {
		bool hit = false;
		float g = 0.0;
		for (int i = 0; i < 2; i++) {
			vec2 a = i == 0 ? vec2(-19.0, 2.0) : vec2(19.0, 2.0);
			vec2 b = i == 0 ? vec2(15.0, -12.0) : vec2(-15.0, -12.0);
			vec3 q = on_log(p, a, b, 3.4);
			float lane = floor(q.y * 3.4 * 0.85 + 0.5);
			float burn = clamp(1.2 - abs(p.x) / 8.0, 0.0, 1.0);
			if (q.x >= 0.0 && q.x <= 0.56 && abs(q.y) <= 1.0 - 1.05 / 3.4 && burn > 0.35 && lane < 2.0 && lane > -2.0) {
				hit = true;
				g = 0.5 + 0.5 * sin(t * 6.2831853 * 3.0 + h2(vec2(floor(q.z / 2.0), lane), 12.0) * 6.3);
			}
		}
		if (!hit) {
			discard;
		}
		c = g > 0.72 ? c_gold : g > 0.4 ? c_orange : c_red;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
