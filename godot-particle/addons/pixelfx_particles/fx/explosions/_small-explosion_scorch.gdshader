// The floor under explosions/small-explosion (the original's scorch): three rows that spread out in a blink, glow
// white-hot and cool down the heat ramp (the palette, brightest first) to soot over `cool` seconds. Key `t` (seconds
// since the blast) and `fade`. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(48.0, 6.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float rx0 = 22.0;
uniform float cool = 2.5;
uniform float fade = 1.0;
uniform vec4 heat[8] : source_color;
uniform vec4 soot : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform vec4 soot2 : source_color = vec4(0.09, 0.07, 0.11, 1.0);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + 3.17) * 43758.5453);
}

void fragment() {
	vec2 q = floor((UV - 0.5) * size + center);
	float rx = rx0 * min(1.0, t / 0.08);
	if (q.y < 0.0 || q.y > 2.0 || rx < 0.5 || fade <= 0.0) {
		discard;
	}
	float dx = (q.x + 0.5) / rx;
	float dy = (q.y + 0.5) / 4.0;
	float d = sqrt(dx * dx + dy * dy);
	if (d > 1.0) {
		discard;
	}
	float k = h(q);
	float T = pow(clamp(1.0 - t / cool, 0.0, 1.0), 1.4) * (1.25 - d) - k * 0.35;
	vec4 c;
	if (T > 0.06) {
		c = heat[min(7, int(floor((1.0 - min(1.0, T)) * 7.0)))];
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
