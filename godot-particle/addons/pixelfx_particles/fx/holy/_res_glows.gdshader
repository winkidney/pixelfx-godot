// holy/resurrection: up to 32 of the original's p.glow(x, y, r, color, k) at once (light layer), g[i] = (x, y, r, k)
// in px from the effect's origin, keyed every frame: the glow riding each loose feather.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(96.0);
uniform vec2 center = vec2(0.0);
uniform vec4 g[32];
uniform int count = 0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float s = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= count) {
			break;
		}
		if (g[i].z < 1.0 || g[i].w <= 0.004) {
			continue;
		}
		float f = 1.0 - length(p - g[i].xy) / g[i].z;
		if (f > 0.0) {
			s += f * f * g[i].w;
		}
	}
	COLOR = vec4(min(color.rgb * s, vec3(1.0)) * strength, 1.0);
}
