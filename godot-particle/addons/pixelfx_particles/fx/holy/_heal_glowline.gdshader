// The original's p.glowLine(a, b, r, c, k): light round a segment, k (1 - d / r)^2 by the distance d to it (light
// layer). Coordinates are px from the effect's origin; key a, b and k.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(0.0);
uniform float radius = 12.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 ab = b - a;
	float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float f = 1.0 - length(a + ab * u - p) / radius;
	float kk = f > 0.0 ? f * f * k : 0.0;
	COLOR = vec4(color.rgb * kk * strength, 1.0);
}
