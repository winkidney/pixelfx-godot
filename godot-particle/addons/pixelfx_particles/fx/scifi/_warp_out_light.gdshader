// Warp out's light (src/fx/scifi/warp-out.js), from the effect's clock `t`: the hero's glow as it charges, the
// flash's star, light down the beam every 8 px. (The flashes of the flash and the lift are keyed glows.) Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(128.0, 168.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

const float FLASH = 0.42;
const float BREAK0 = 0.5;
const float LIFT = 1.3;
const float GONE = 1.62;
const float TOP = -128.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	vec3 l = vec3(0.0);
	float w = t < BREAK0 ? 0.0 : t < LIFT ? 2.0 + 7.0 * e_out_cubic((t - BREAK0) / 0.35) : mix(9.0, 0.6, e_in_cubic((t - LIFT) / (GONE - LIFT)));
	float f = t < LIFT ? 0.0 : mix(0.0, TOP, e_in_quad((t - LIFT) / (GONE - LIFT)));
	if (w > 0.3 && t < GONE) {
		for (float y = TOP; y < f; y += 8.0) {
			l += pal[4].rgb * glow_at(pc, vec2(0.0, y), min(w * 2.5 + 6.0, y - TOP + 2.0)) * 0.28;
		}
	}
	if (t < FLASH) {
		l += pal[4].rgb * glow_at(pc, vec2(0.0, -20.0), 26.0) * 0.4 * clamp(t / FLASH, 0.0, 1.0);
	}
	if (t >= FLASH && t < FLASH + 0.12) {
		float n = floor(10.0 * (1.0 - (t - FLASH) / 0.12) + 0.5);
		if (n >= 1.0) {
			l += pal[6].rgb * glow_at(pc, vec2(0.0, -20.0), 4.0 + n * 2.0) * 0.6;
		}
	}
	COLOR = vec4(l * strength, 1.0);
}
