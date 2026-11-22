// The hologram's light (src/fx/scifi/hologram.js), from the keyed clock `t`: the lens's glow, the stage's band, a
// glow on each near corner, the model's own glow and the scan bar's band (halved when it flickers), the pool on the
// projector. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"

uniform vec2 size = vec2(112.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform sampler2D data : filter_nearest, repeat_disable;
uniform vec4 pal[8] : source_color;
uniform float strength = 1.0;

#include "res://addons/pixelfx_particles/fx/scifi/_hologram.gdshaderinc"

void fragment() {
	Holo h = setup();
	vec2 pc = floor(center + (UV - 0.5) * size + 0.001) + 0.5;
	vec3 l = pal[5].rgb * glow_at(pc, vec2(0.0, LENS), 12.0) * 0.6;
	l += pal[4].rgb * glow_seg(pc, vec2(-RAD - 4.0, h.top), vec2(RAD + 4.0, h.top), 4.0) * 0.2;
	for (int i = 0; i < 8; i++) {
		if (h.V[i].z >= -0.15) {
			l += pal[5].rgb * glow_at(pc, h.V[i].xy, 4.0) * 0.3;
		}
	}
	float lk = h.flick ? 0.5 : 1.0;
	l += pal[4].rgb * glow_at(pc, vec2(h.cx, h.cy), RAD * 2.2) * 0.36 * lk;
	l += pal[5].rgb * glow_at(pc, vec2(h.cx, h.cy - RAD * 0.6), RAD) * 0.15 * lk;
	if (abs(h.scan - h.cy) < RAD * 1.4) {
		l += pal[5].rgb * glow_seg(pc, vec2(h.cx - RAD, h.scan), vec2(h.cx + RAD, h.scan), 5.0) * 0.3 * lk;
	}
	l += pal[4].rgb * glow_at(pc, vec2(0.0, -2.0), 22.0) * 0.2;
	COLOR = vec4(l * strength, 1.0);
}
