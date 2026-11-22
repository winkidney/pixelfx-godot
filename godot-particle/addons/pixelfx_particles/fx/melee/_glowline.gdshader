// The original's p.glowLine(a, b, r, color, k), light layer: light round a segment, k (1 - d / r)^2 where d is the
// distance to it. Coordinates are px from the effect's origin. Key a, b, k.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(0.0);
uniform float radius = 6.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 ab = b - a;
	float l2 = max(dot(ab, ab), 1e-9);
	float u = clamp(dot(p - a, ab) / l2, 0.0, 1.0);
	float d = length(a + ab * u - p) / radius;
	float f = max(0.0, 1.0 - d);
	COLOR = vec4(color.rgb * f * f * k * strength * COLOR.rgb * COLOR.a, 1.0);
}
