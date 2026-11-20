// heart-pickup's heart (_lib.js pillow() over heartSdf() in a Layer, outlined in ink): a plump bevelled heart lit from
// the top left, squashed and stretched by the beat (hw, hh: its half-width and height), centred on (0, cy); then the
// thin ring of light snapping out on the big beat (painter.js ring, 1 px, dithered by ring_a). Keyed every frame.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color = vec4(0.07, 0.02, 0.05, 1.0);
uniform float cy = -18.0;
uniform float hw = 7.2;
uniform float hh = 7.2;
uniform float ring_r = 0.0;
uniform float ring_a = 0.0;
uniform vec4 ring_c : source_color = vec4(1.0);

float heart_sdf(vec2 p) {
	float S = hw / 1.14;
	float X = p.x / S;
	float Y = -(p.y - cy) / (hh / 1.14) + 0.12;
	float q = X * X + Y * Y - 1.0;
	float f = q * q * q - X * X * Y * Y * Y;
	float gx = 6.0 * X * q * q - 2.0 * X * Y * Y * Y;
	float gy = 6.0 * Y * q * q - 3.0 * X * X * Y * Y;
	return (f / max(length(vec2(gx, gy)), 0.6)) * S;
}

bool in_box(vec2 pc) {
	vec2 c = floor(pc);
	return c.x >= -12.0 && c.x <= 12.0 && c.y >= cy - 11.0 && c.y <= cy + 11.0;
}

bool inside(vec2 pc) {
	return in_box(pc) && heart_sdf(pc) <= 0.0;
}

vec3 shade(vec2 pc) {
	float e = -heart_sdf(pc);
	float gx = heart_sdf(pc + vec2(0.5, 0.0)) - heart_sdf(pc - vec2(0.5, 0.0));
	float gy = heart_sdf(pc + vec2(0.0, 0.5)) - heart_sdf(pc - vec2(0.0, 0.5));
	float gl = length(vec2(gx, gy));
	if (gl == 0.0) {
		gl = 1.0;
	}
	gx /= gl;
	gy /= gl;
	float k = max(0.0, 1.0 - e / 3.6) * 1.25;
	float lt = gx * sin(k) * -0.5 + gy * sin(k) * -0.6 + cos(k) * 0.62;
	if (lt > 0.92 && e > 1.2) {
		return vec3(1.0);
	}
	return lt > 0.8 ? C[6].rgb : lt > 0.6 ? C[5].rgb : lt > 0.38 ? C[4].rgb : lt > 0.12 ? C[3].rgb : C[2].rgb;
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	vec4 c = vec4(0.0);
	if (ring_r > 0.0) {
		vec2 q = pc - vec2(0.0, cy);
		float d2 = dot(q, q);
		float r0 = max(0.0, ring_r - 1.0);
		if (d2 <= ring_r * ring_r && d2 >= r0 * r0 && ring_a > pfx_threshold(FRAGCOORD.xy)) {
			c = vec4(ring_c.rgb, 1.0);
		}
	}
	if (c.a <= 0.0) {
		if (inside(pc)) {
			c = vec4(shade(pc), 1.0);
		} else if (abs(pc.y - cy) < 14.0 && (inside(pc + vec2(1.0, 0.0)) || inside(pc - vec2(1.0, 0.0)) || inside(pc + vec2(0.0, 1.0)) || inside(pc - vec2(0.0, 1.0)))) {
			c = vec4(ink.rgb, 1.0);
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
