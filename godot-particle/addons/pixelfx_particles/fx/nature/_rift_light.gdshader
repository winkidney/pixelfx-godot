// The light-layer half of _rift.gdshader (nature/quake): a soft glow at every third point of the open rift, weaker
// toward its ends, as strong as `heat`. Same uniforms.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 color : source_color = vec4(1.0, 0.54, 0.16, 1.0);
uniform vec2 rift[80];
uniform float rift_count = 0.0;
uniform float reach = 118.0;
uniform float open = 0.0;
uniform float heat = 0.0;
uniform float jx = 0.0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center) + 0.5;
	float k = 0.0;
	for (int i = 1; i < 80; i++) {
		if (float(i) >= rift_count) {
			break;
		}
		if (i % 3 != 0 || abs(rift[i - 1].x) > open) {
			continue;
		}
		vec2 g = vec2(rift[i].x + jx, rift[i].y + 1.0);
		float d = length(p - g) / 9.0;
		if (d < 1.0) {
			k += (1.0 - d) * (1.0 - d) * 0.35 * (1.0 - abs(rift[i].x) / (reach * 1.2));
		}
	}
	COLOR = vec4(color.rgb * k * heat * strength, 1.0);
}
