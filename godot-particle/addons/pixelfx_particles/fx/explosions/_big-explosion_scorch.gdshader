// The floor under explosions/big-explosion (the original's _lib.js scorch): a burn `rows` deep that spreads out in a
// blink, glows white-hot and cools down the heat ramp to soot over `cool` seconds; a few cracks hold their glow twice
// as long. Key `t` (seconds since the blast) and `fade`. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(120.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float rx0 = 52.0;
uniform float cool = 3.4;
uniform float rows = 3.0;
uniform float fade = 1.0;
uniform vec4 hr[10] : source_color;
uniform vec4 soot : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform vec4 soot2 : source_color = vec4(0.09, 0.07, 0.11, 1.0);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + 3.17) * 43758.5453);
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size + center);
	float rx = rx0 * min(1.0, t / 0.08);
	if (q.y < 0.0 || q.y >= rows || rx < 0.5 || fade <= 0.0) {
		discard;
	}
	float ry = rows + 1.5;
	float dx = (q.x + 0.5) / rx;
	float dy = (q.y + 0.5) / ry;
	float d = sqrt(dx * dx + dy * dy);
	if (d > 1.0) {
		discard;
	}
	float k = h(q);
	float T = pow(clamp(1.0 - t / cool, 0.0, 1.0), 1.4) * (1.25 - d) - k * 0.35;
	float crack = (k > 0.88 && d < 0.85) ? pow(clamp(1.0 - t / (cool * 2.0), 0.0, 1.0), 1.2) * (1.15 - d) * 0.8 : 0.0;
	float H = max(T, crack);
	vec4 c;
	if (H > 0.06) {
		c = hr[min(9, int(floor((1.0 - min(1.0, H)) * 9.0)))];
		c.a = fade;
	} else {
		c = d < 0.5 ? soot : soot2;
		c.a = (d < 0.95 - k * 0.3 ? 1.0 : 1.0 - d) * fade;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
