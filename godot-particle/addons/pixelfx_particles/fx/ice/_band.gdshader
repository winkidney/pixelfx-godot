// The originals' band(): a ring lying on the floor (`radius` px, squashed to `squash` in y), `width` px thick inward,
// bright at its outer edge (`hot`: white) and cooling inward through the ramp's top steps, fading by `alpha` (k),
// dithered. `side` 1 keeps the far (upper) half, -1 the near half, 0 both. Centred on the rect's middle. Colour layer;
// `ramp` is the ramp the original passes (dark to bright, its top four steps are used).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 10.0;
uniform float squash = 0.16;
uniform float width = 4.0;
uniform float hot = 0.0;
uniform float side = 0.0;
uniform float alpha = 1.0;
uniform float steps = 8.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 R(float i) {
	return texture(ramp, vec2((i + 0.5) / steps, 0.5));
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if ((side > 0.5 && p.y > 0.0) || (side < -0.5 && p.y < 0.0)) {
		discard;
	}
	float sq = max(squash, 0.001);
	float d = max(length(vec2(p.x, p.y / sq)), 0.001);
	// how far the pixel's centre is from the band's outer and inner edges, in screen px (the original's dots fill
	// every cell the band passes through, so a band thinner than a pixel still draws an unbroken line)
	float g = max(length(vec2(p.x, p.y / (sq * sq))) / d, 0.001);
	if ((d - radius) / g > 0.5 || (radius - width - d) / g > 0.5) {
		discard;
	}
	float u = clamp((radius - d) / max(width, 0.001), 0.0, 1.0);
	float n = steps;
	vec4 c = u < 0.15 ? (hot > 0.5 ? vec4(1.0) : R(n - 1.0)) : (u < 0.4 ? R(n - 2.0) : (u < 0.7 ? R(n - 3.0) : R(n - 4.0)));
	c.a = alpha * (u < 0.4 ? 1.2 : 1.15 - u);
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
