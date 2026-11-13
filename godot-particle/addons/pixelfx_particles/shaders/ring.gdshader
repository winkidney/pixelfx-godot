// A disc, a ring or an ellipse lying on the floor (flashes, shock rings, ground bands, novas), on the colour layer.
// Draw it on a ColorRect of `size` px centred on the ring's middle (build.gd shape()); key the uniforms to animate.
shader_type canvas_item;

#include "pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
// outer radius in px; thickness 0 fills the disc
uniform float radius = 10.0;
uniform float thickness = 0.0;
// y scale: 1 is round, about 0.2 a ring lying on the floor
uniform float squash = 1.0;
uniform vec4 color : source_color = vec4(1.0);
// an outline `edge` px wide outside the ring (and inside it, for a ring), in edge_color
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge = 0.0;
// 1: only the far (upper) half, -1: only the near (lower) half; for a ring round a character's feet
uniform float side = 0.0;
// 0..1: how much of the rim is broken up (seeded by `grain`)
uniform float ragged = 0.0;
uniform float grain = 1.0;
uniform float alpha = 1.0;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + grain * 7.13) * 43758.5453);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	if ((side > 0.5 && p.y > 0.0) || (side < -0.5 && p.y < 0.0)) {
		discard;
	}
	float d = length(vec2(p.x, p.y / max(squash, 0.001)));
	float inner = thickness > 0.0 ? radius - thickness : -1e9;
	vec4 c;
	if (d <= radius && d >= inner) {
		c = color;
		if (ragged > 0.0 && h(floor(p)) < ragged * smoothstep(radius - max(thickness, 2.0), radius, d)) {
			discard;
		}
	} else if (edge > 0.0 && ((d > radius && d <= radius + edge) || (thickness > 0.0 && d < inner && d >= inner - edge))) {
		c = edge_color;
	} else {
		discard;
	}
	c.a *= alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
