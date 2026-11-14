// The light of the holy pillar's fan (holy/holy-pillar, light layer), and the glow where the shafts converge.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/holy/_pillar_fan.gdshaderinc"

uniform vec2 size = vec2(192.0, 204.0);
uniform vec2 center = vec2(0.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 f = fan_at(p);
	vec3 l = f.x >= 0.02 ? c4.rgb * min(0.9, f.x * 0.32) : vec3(0.0);
	if (t > HIT - 0.05) {
		float g = max(0.0, 1.0 - length(p - vec2(0.0, PY - 3.0)) / 20.0);
		l += c5.rgb * g * g * 0.5 * fan_fade();
	}
	COLOR = vec4(min(l, vec3(1.0)) * strength, 1.0);
}
