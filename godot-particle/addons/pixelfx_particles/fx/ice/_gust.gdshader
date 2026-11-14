// ice/frost-breath's gust: a cone of turbulent, translucent cold air streaming right from the origin, `reach` px
// long, widening by `spread` px per px, sagging `sag` px at its end, densest down its heart near the mouth. The noise
// scrolls exactly one tile per loop (`t` 0..1) so it never seams. Soft colour layer: four steps of the ice ramp by
// density, translucent. (_gust_light.gdshader is its light.)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform float reach = 170.0;
uniform float spread = 0.23;
uniform float sag = 7.0;
// px per noise tile across (it scrolls one tile a loop) and down
uniform vec2 period = vec2(182.0, 68.0);
uniform float contrast = 1.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform float alpha = 1.0;

float density(vec2 p) {
	float u = p.x / reach;
	float hw = 2.5 + p.x * spread;
	float yc = sag * u * u;
	float v = (p.y - yc) / hw;
	if (v * v >= 1.0 || u >= 1.0 || p.x < 2.0) {
		return 0.0;
	}
	vec2 q = vec2(p.x / period.x - t, (p.y - yc) / period.y + 0.37);
	float n = (texture(noise, q).r * 0.65 + texture(noise, q * 2.0 + vec2(0.31, 0.17)).r * 0.35 - 0.5) * 2.0 * contrast;
	float edge = (1.0 - v * v) * (u < 0.08 ? u / 0.08 : 1.0) * pow(1.0 - u, 0.8);
	return clamp(0.5 + n * 1.3 + (1.0 - abs(v)) * 0.35 * pow(1.0 - u, 1.5), 0.0, 1.0) * edge;
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = density(p);
	if (d < 0.08) {
		discard;
	}
	vec4 c = d > 0.72 ? c7 : d > 0.52 ? c6 : d > 0.32 ? c5 : c4;
	c.a = min(0.78, d * 0.95) * clamp((d - 0.08) / 0.3, 0.0, 1.0) * alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
