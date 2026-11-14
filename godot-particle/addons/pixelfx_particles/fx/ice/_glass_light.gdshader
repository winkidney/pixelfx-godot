// The light of ice/freeze's block (_glass.gdshader, same uniforms): each pane lights up as a sweep passes it.
// Light layer (additive).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(36.0, 53.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D facets : filter_nearest;
uniform float at[13];
uniform float delay[13];
uniform float lit[13];
uniform vec2 sweeps = vec2(1.12, 1.82);
uniform float t = 0.0;
uniform float white = 0.0;
uniform vec4 c5 : source_color = vec4(0.65, 0.93, 1.0, 1.0);
uniform float strength = 1.0;
uniform float alpha = 1.0;

void fragment() {
	vec4 tint = COLOR;
	ivec2 P = ivec2(floor(UV * size));
	vec4 m = texelFetch(facets, P, 0);
	vec3 c = vec3(0.0);
	if (m.b > 0.5 && white < 0.5) {
		int i = int(floor(m.r * 255.0 + 0.5));
		if (t >= at[i] + 0.03) {
			float g = max(sin(PI * clamp((t - sweeps.x - delay[i] * 0.32) / 0.13, 0.0, 1.0)), sin(PI * clamp((t - sweeps.y - delay[i] * 0.32) / 0.13, 0.0, 1.0)));
			g *= 0.35 + 0.65 * lit[i];
			if (g > 0.05) {
				c = c5.rgb * 0.42 * g;
			}
		}
	}
	COLOR = vec4(c * alpha * strength * tint.rgb * tint.a, 1.0);
}
