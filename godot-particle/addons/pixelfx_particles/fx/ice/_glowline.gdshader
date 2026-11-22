// The original's glowLine(): light round a segment from `a` to `b` (px from the effect's origin; `center` is where
// the rect sits), falling off as (1 - d / radius)^2. Light layer (additive): key alpha, a, b.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(10.0, 0.0);
uniform float radius = 8.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 d = b - a;
	float u = clamp(dot(p - a, d) / max(dot(d, d), 1e-6), 0.0, 1.0);
	float e = length(a + d * u - p) / max(radius, 0.001);
	float k = 1.0 - clamp(e, 0.0, 1.0);
	COLOR = vec4((color.rgb * color.a * k * k * alpha * strength) * tint.rgb * tint.a, 1.0);
}
