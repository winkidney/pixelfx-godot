// The shadow lib's halo(): a ring of light hugging a black disc, k at radius r0 falling as (1 - (d - r0) / (r1 - r0))^2
// to nothing at r1, and none inside r0. squash < 1 flattens it (y scale). Light layer. Centred on the rect.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform float r0 = 8.0;
uniform float r1 = 20.0;
uniform float squash = 1.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.5;
uniform float alpha = 1.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float d = length(vec2(p.x, p.y / max(squash, 0.001)));
	float f = 0.0;
	if (d >= r0 && d < r1) {
		f = 1.0 - (d - r0) / max(r1 - r0, 0.001);
		f *= f;
	}
	COLOR = vec4(color.rgb * color.a * f * k * alpha * strength * COLOR.rgb * COLOR.a, 1.0);
}
