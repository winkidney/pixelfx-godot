// coin-spin's coin (_lib.js coin3d in a Layer, outlined in C[1]): centred on cell corner (cx, cy), turned by theta
// (ct, st: its cos and sin); keyed every frame. Colour layer, over the whole canvas.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/pickups/_coin3d.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform float cx = 0.0;
uniform float cy = 0.0;
uniform float ct = 1.0;
uniform float st = 0.0;
uniform float radius = 7.0;
uniform float thick = 3.0;

int px_at(vec2 pc) {
	return coin3d_px(pc, cx, cy, radius, thick, ct, st);
}

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	if (abs(pc.x - cx) > radius + thick + 3.0 || abs(pc.y - cy) > radius + 3.0) {
		discard;
	}
	int k = px_at(pc);
	vec4 c;
	if (k >= 0) {
		c = k == 8 ? vec4(1.0) : C[k];
	} else if (px_at(pc + vec2(1.0, 0.0)) >= 0 || px_at(pc - vec2(1.0, 0.0)) >= 0 || px_at(pc + vec2(0.0, 1.0)) >= 0 || px_at(pc - vec2(0.0, 1.0)) >= 0) {
		c = C[1];
	} else {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
