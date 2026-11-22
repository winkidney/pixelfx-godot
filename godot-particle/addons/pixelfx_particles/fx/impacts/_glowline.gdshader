// The original's p.glowLine (src/core/painter.js): light round a segment from a to b (px in the effect's
// coordinates), (1 - d / radius)^2 * k of color, on the light layer. Key a, b, k.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(0.0);
uniform float radius = 4.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.5;
uniform float strength = 1.0;

void fragment() {
	vec2 p = center + (UV - 0.5) * size;
	vec2 e = b - a;
	float l2 = max(dot(e, e), 1e-9);
	float u = clamp(dot(p - a, e) / l2, 0.0, 1.0);
	float d = length(a + e * u - p) / max(radius, 0.001);
	float f = max(0.0, 1.0 - d);
	COLOR = vec4(color.rgb * f * f * k * strength * COLOR.a, 1.0);
}
