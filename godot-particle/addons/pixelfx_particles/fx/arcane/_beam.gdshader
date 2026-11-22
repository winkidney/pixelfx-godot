// The arcane beam's body (after the original's draw()): banded across from a white core out to a dithered violet
// edge, its width wobbling and pulses running down it, three strands twisting round it, bright in front and gone
// behind. `t` runs 0..1 over the loop (keyed by the animation). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float x0 = 15.0;
uniform float len = 168.0;
uniform float y0 = -24.0;
uniform float width = 6.0;
// core to edge: white, C6, C5, C4, C3, C2
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c3 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);


vec4 level(int i) {
	return i <= 0 ? c0 : i == 1 ? c1 : i == 2 ? c2 : i == 3 ? c3 : i == 4 ? c4 : c5;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = floor(p.x) - x0 + 0.25;
	if (d < 0.0 || d > len) {
		discard;
	}
	float w = width * (1.0 + 0.12 * sin(d * 0.35 - t * TAU * 8.0)) * min(1.0, (d + 3.0) / 7.0);
	float q0 = floor(p.y) + 0.25 - y0;
	float q = abs(q0) / w;
	vec4 c = vec4(0.0);
	bool on = false;
	if (q <= 1.3) {
		int lv = q < 0.2 ? 0 : q < 0.4 ? 1 : q < 0.62 ? 2 : q < 0.85 ? 3 : q < 1.0 ? 4 : 5;
		if (fract(d * 0.025 - t * 4.0) < 0.07) {
			lv = max(0, lv - 1);
		}
		if (!(lv == 5 && pfx_threshold(FRAGCOORD.xy) > (1.3 - q) / 0.3)) {
			c = level(lv);
			on = true;
		}
	}
	for (int s = 0; s < 3; s++) {
		float a = d * 0.17 - t * TAU * 6.0 + float(s) * TAU / 3.0;
		float off = sin(a) * w * 1.05;
		float slope = abs(cos(a) * 0.17 * w * 1.05);
		if (cos(a) > -0.15 && abs(q0 - off) < 0.5 + 0.5 * slope) {
			c = cos(a) > 0.55 ? c0 : c1;
			on = true;
		}
	}
	if (!on) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
