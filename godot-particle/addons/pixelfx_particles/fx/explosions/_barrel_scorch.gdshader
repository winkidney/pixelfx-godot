// The floor under the drum (explosions/barrel-explosion; the original's _lib scorch and fuel slick): a burn `rows`
// deep that spreads out in a blink to `rx0`, glows white-hot and cools down the heat ramp to soot over `cool`
// seconds (a few cracks hold their glow twice as long), and over it the spilled fuel: dark slicks (pool_x, pool_w)
// shrinking by `left` as they burn off, flecked with fire that flickers with `flick`. `u` is the time since the blast,
// `fade` 0..1. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float u = 0.0;
uniform float rx0 = 30.0;
uniform float cool = 2.2;
uniform float fade = 1.0;
uniform float rows = 3.0;
// the heat ramp, white-hot first, as a stepped gradient of `steps` colours
uniform sampler2D heat : filter_nearest, repeat_disable;
uniform float steps = 10.0;
uniform vec4 soot : source_color;
uniform vec4 soot2 : source_color;
uniform float pool_x[7];
uniform float pool_w[7];
uniform float left = 0.0;
uniform float flick = 0.0;
uniform vec4 oil : source_color;
uniform vec4 fleck : source_color;

float h(vec2 q) {
	return fract(sin(dot(q, vec2(12.9898, 78.233)) + 3.17) * 43758.5453);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + center;   // the pixel's corner: x, y as the original counts them
	vec4 c = vec4(0.0);
	bool hit = false;
	float rx = rx0 * min(1.0, u / 0.08);
	float ry = rows + 1.5;
	if (fade > 0.0 && rx > 0.0 && p.y >= 0.0 && p.y < rows && p.x >= floor(-rx) && p.x <= ceil(rx)) {
		float dx = (p.x + 0.5) / rx;
		float dy = (p.y + 0.5) / ry;
		float d = sqrt(dx * dx + dy * dy);
		if (d <= 1.0) {
			float k = h(p);
			float T = pow(clamp(1.0 - u / cool, 0.0, 1.0), 1.4) * (1.25 - d) - k * 0.35;
			float crack = (k > 0.88 && d < 0.85) ? pow(clamp(1.0 - u / (cool * 2.0), 0.0, 1.0), 1.2) * (1.15 - d) * 0.8 : 0.0;
			float H = max(T, crack);
			hit = true;
			if (H > 0.06) {
				float i = clamp(floor((1.0 - min(1.0, H)) * (steps - 1.0)), 0.0, steps - 1.0);
				c = texture(heat, vec2((i + 0.5) / steps, 0.5));
				c.a = fade;
			} else {
				c = d < 0.5 ? soot : soot2;
				c.a = (d < 0.95 - k * 0.3 ? 1.0 : 1.0 - d) * fade;
			}
		}
	}
	// the fuel slicks, drawn over the burn
	if (left > 0.0 && (p.y == 1.0 || p.y == 2.0)) {
		for (int i = 0; i < 7; i++) {
			float wl = pool_w[i] * left;
			float x = p.x - floor(pool_x[i]);
			if (x < floor(-wl) || x > ceil(wl)) {
				continue;
			}
			float e = abs(x) / (wl + 0.01);
			if (p.y == 1.0) {
				c = h(vec2(p.x, flick) + 0.37) < 0.25 ? fleck : oil;
				c.a = fade * (e < 0.8 ? 1.0 : 0.6);
				hit = true;
			} else if (e < 0.6) {
				c = oil;
				c.a = fade * 0.8;
				hit = true;
			}
		}
	}
	if (!hit || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
