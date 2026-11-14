// A soft beam of light along a segment (the original's glowLine): additive, falling off as (1 - d / r)^2 from the
// segment from `a` to `b` (px from the rect's centre). The light layer's counterpart of a line.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(10.0, 0.0);
uniform float radius = 12.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float d = length(a + ab * u - p) / radius;
	float k = 1.0 - clamp(d, 0.0, 1.0);
	COLOR = vec4(color.rgb * color.a * k * k * alpha * strength, 1.0);
}
