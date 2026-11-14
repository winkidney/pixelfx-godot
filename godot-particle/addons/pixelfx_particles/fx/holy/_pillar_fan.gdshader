// The holy pillar's fan of shafts (holy/holy-pillar, soft layer): pale light where the shafts are, summed where they
// cross, and a fine bright line down the middle of each.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/holy/_pillar_fan.gdshaderinc"

uniform vec2 size = vec2(192.0, 204.0);
uniform vec2 center = vec2(0.0);
uniform vec4 c6 : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 f = fan_at(p);
	if (f.x < 0.02) {
		discard;
	}
	vec4 c = vec4(c6.rgb, min(0.6, f.x * 0.38));
	if (f.y > 0.0 && min(1.0, f.y / 180.0) >= pfx_threshold(FRAGCOORD.xy)) {
		c = f.y > 150.0 ? vec4(1.0) : c6;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
