// The original's p.glowLine(a, b, r, c, k) (light layer): light round a segment, (1 - d / r)^2 * k with d the
// distance to the segment. Coordinates are px from the effect's origin (build.gd shape() sets size and center);
// key a, b and alpha to move and fade it.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(10.0, 0.0);
uniform float radius = 8.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.3;
uniform float alpha = 1.0;
uniform float strength = 1.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 p = floor(UV * size) + 0.5 - size * 0.5 + center;
	vec2 ab = b - a;
	float L2 = max(dot(ab, ab), 1e-9);
	float u = clamp(dot(p - a, ab) / L2, 0.0, 1.0);
	float d = length(a + ab * u - p) / max(radius, 0.001);
	float f = max(0.0, 1.0 - d);
	COLOR = vec4(color.rgb * color.a * f * f * k * alpha * strength * tint.rgb * tint.a, 1.0);
}
