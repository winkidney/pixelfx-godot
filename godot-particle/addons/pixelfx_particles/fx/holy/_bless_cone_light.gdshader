// The light of the blessing's cone (holy/blessing, light layer): the same rays as _bless_cone, added.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/holy/_bless.gdshaderinc"

uniform vec2 size = vec2(52.0, 110.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float I = 0.0;
	if (p.y >= TOP && p.y <= 0.5) {
		I = bless_ray(p.x / bless_half(p.y), t) * (0.6 + 0.4 * smoothstep(TOP, 0.0, p.y));
	}
	COLOR = vec4(c4.rgb * I * 0.22 * strength, 1.0);
}
