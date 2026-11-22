// The ribbon's light (projectiles/magic-missile.js): a small glow on every third point of the trail (pts, as
// _magic-missile_ribbon.gdshader's), (1 - d / 6)^2 * 0.25 * (1 - age / 0.32). Light layer.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 pts[48];
uniform float count = 0.0;
uniform float now = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor(UV * size) - size * 0.5 + center + 0.5;
	float sum = 0.0;
	for (int i = 3; i < 48; i += 3) {
		if (float(i) >= count) {
			break;
		}
		vec4 b = pts[i];
		float f = max(0.0, 1.0 - length(p - b.xy) / 6.0);
		sum += f * f * 0.25 * (1.0 - (now - b.z) / 0.32);
	}
	COLOR = vec4(color.rgb * sum * strength, 1.0);
}
