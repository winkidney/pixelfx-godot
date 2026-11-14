// Light along a segment (light layer): the original's p.glow(x, y, radius, color, k) repeated every `step_px` px
// from a to b, summed: (1 - d / radius)^2 * k per glow, integrated along the line. Coordinates are px from the
// effect's origin (build.gd shape() sets size and center).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec2 a = vec2(0.0);
uniform vec2 b = vec2(10.0, 0.0);
uniform float radius = 16.0;
uniform float step_px = 4.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float k = 0.2;
// k is scaled by this at b (1 at a): a run of glows that fades along its length
uniform float k_end = 1.0;
uniform float alpha = 1.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 ab = b - a;
	float L = length(ab);
	vec2 u = L > 1e-4 ? ab / L : vec2(1.0, 0.0);
	vec2 nrm = vec2(-u.y, u.x);
	float along = dot(p - a, u);
	float across = abs(dot(p - a, nrm));
	float sum = 0.0;
	if (across < radius) {
		float w = sqrt(radius * radius - across * across);
		float s0 = max(0.0, along - w);
		float s1 = min(L, along + w);
		if (s1 > s0) {
			float ds = (s1 - s0) / 24.0;
			for (int i = 0; i < 24; i++) {
				float s = s0 + (float(i) + 0.5) * ds;
				float f = 1.0 - length(vec2(along - s, across)) / radius;
				sum += max(f, 0.0) * max(f, 0.0) * ds * mix(1.0, k_end, clamp(s / max(L, 1e-3), 0.0, 1.0));
			}
		}
		// a lone glow where the segment is a point
		if (L < 1e-3) {
			float f = 1.0 - length(p - a) / radius;
			sum = max(f, 0.0) * max(f, 0.0) * step_px;
		}
	}
	float kk = sum / max(step_px, 0.01) * k * alpha * strength;
	COLOR = vec4(color.rgb * color.a * kk, 1.0);
}
