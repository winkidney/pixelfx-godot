// The crater a buried charge leaves (explosions/dirt-explosion, the original's _lib crater()): a dark pit in
// perspective with its far wall lit, dirt heaped in a lip either side and loose earth scattered round it. Key `open`
// (0..1, how far it has opened) and `alpha`. Colour layer, behind.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(160.0, 16.0);
uniform vec2 center = vec2(0.0);
uniform float reach = 28.0;
uniform float open = 1.0;
uniform float alpha = 1.0;
// the earth ramp: darkest pit, pit, near wall, lit heap side, lit rim
uniform vec4 e0 : source_color;
uniform vec4 e1 : source_color;
uniform vec4 e2 : source_color;
uniform vec4 e3 : source_color;
uniform vec4 e5 : source_color;

float h(float i, float s) {
	return fract(sin(i * 12.9898 + s * 78.233) * 43758.5453);
}

void fragment() {
	if (open <= 0.0) {
		discard;
	}
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 q = floor(p);
	float rx = reach * open;
	float ry = max(1.5, reach * 0.17 * open);
	vec4 c = vec4(0.0);
	bool hit = false;
	// the pit: darkest at its far side under the lit rim, the near wall a step lighter
	if (q.y >= -1.0 && q.y <= ceil(ry) + 1.0) {
		float dx = (q.x + 0.5) / rx;
		float dy = (q.y + 0.5 - ry * 0.35) / ry;
		float d = sqrt(dx * dx + dy * dy);
		if (d <= 1.08) {
			hit = true;
			c = d > 0.92 ? (dy < 0.0 ? e5 : e2) : (dy < -0.2 ? e0 : (dy < 0.35 ? e1 : e2));
		}
	}
	// the lip: dirt heaped up either side, lit on top
	if (q.y <= 0.0) {
		for (int s = -1; s <= 1; s += 2) {
			for (int i = 0; i < 9; i++) {
				float u = float(i) / 8.0;
				float hx = floor(float(s) * (rx * 0.82 + u * reach * 0.55));
				if (hx != q.x) {
					continue;
				}
				float hh = floor(sin(3.14159265 * u) * 2.2 * open + (h(float(i), s > 0 ? 3.0 : 4.0) < 0.4 ? 1.0 : 0.0) * open + 0.5);
				float j = -q.y;
				if (j <= hh) {
					hit = true;
					c = j == hh ? e5 : (j == hh - 1.0 ? e3 : e2);
				}
			}
		}
	}
	// and a scatter of loose earth
	for (int i = 0; i < 26; i++) {
		float fi = float(i);
		float s = h(fi, 7.0) < 0.5 ? -1.0 : 1.0;
		float x = floor(s * rx * (1.05 + h(fi, 8.0) * 1.4));
		float y = floor(h(fi, 9.0) * 3.0 + 0.5) - 1.0;
		if (x == q.x && y == q.y && h(fi, 10.0) < open) {
			hit = true;
			c = h(fi, 11.0) < 0.5 ? e3 : e2;
		}
	}
	if (!hit) {
		discard;
	}
	c.a = alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
