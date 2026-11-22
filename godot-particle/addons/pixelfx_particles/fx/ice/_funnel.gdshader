// ice/blizzard-vortex's body: a translucent column of snow-filled air, `H` px tall, narrow at the foot and wide at
// the mouth, its axis swaying once a loop (`t` 0..1), densest at its edges where you look through more of it, with
// swirl bands climbing it. Coordinates are px from the effect's origin. Soft colour layer (translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float H = 80.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform float alpha = 1.0;


void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float h = -p.y;
	if (h < 0.0 || h > H + 4.0) {
		discard;
	}
	float R = 4.0 + 28.0 * pow(clamp(h / H, 0.0, 1.0), 1.35);
	float ax = (5.0 * sin(TAU * t + h * 0.05) + 1.5 * sin(TAU * t * 2.0 - h * 0.11)) * (h / H) - 2.0 * (h / H);
	float u = (p.x - ax) / R;
	if (u * u >= 1.0) {
		discard;
	}
	float k = h / H;
	float rim = pow(abs(u), 3.0);
	float swirl = sin(asin(u) * 3.0 - TAU * t * 2.0 + h * 0.2) * 0.5 + 0.5;
	float a = (0.07 + 0.24 * rim + 0.12 * swirl) * clamp((1.0 - abs(u)) / 0.18, 0.0, 1.0)
		* (k > 0.7 ? max(0.0, (1.0 - k) / 0.3) : 1.0) * (h < 4.0 ? h / 4.0 : 1.0);
	if (a < 0.03) {
		discard;
	}
	vec4 c = rim > 0.5 ? c6 : (swirl > 0.6 ? c5 : c4);
	c.a = a * alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
