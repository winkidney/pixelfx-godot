// The ui effects' light (the original's p.glow, glowRing and glowLine, Lights and every particle's own glow), on the
// light layer: one entry per light per frame (packed as _ftp.gdshader reads them), placed by _ftp.gdshader on the cell under the light's centre, added as
// the original's light buffer adds it. Row 0: cell, kind (1 glow, 12 ring, 13 line, 14 one
// pixel); row 1: colour (packed
// 0xRRGGBB), quad size; row 2: x, y, r, k; row 3: ring width / line end.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

varying flat vec4 cu;

const int ROWS = 5;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	int b = int(cu.y + 0.5) * 1024 + int(cu.x + 0.5);
	vec4 r0 = texelFetch(data, ivec2(b % 1024, b / 1024), 0);
	vec4 r1 = texelFetch(data, ivec2((b + 1) % 1024, (b + 1) / 1024), 0);
	vec4 r2 = texelFetch(data, ivec2((b + 2) % 1024, (b + 2) / 1024), 0);
	vec4 r3 = texelFetch(data, ivec2((b + 3) % 1024, (b + 3) / 1024), 0);
	vec2 pc = cu.zw + 0.5 + floor((UV - 0.5) * r1.w + 0.5);
	int ci = int(r1.x);
	vec3 col = vec3(float((ci >> 16) & 255), float((ci >> 8) & 255), float(ci & 255)) / 255.0;
	float k = r2.w * strength * lt_edge(pc, canvas);
	int kd = int(r0.z + 0.5);
	vec3 l = vec3(0.0);
	if (kd == 14) {
		// painter.js light(): one pixel
		l = (floor(pc) == cu.zw) ? lt_add(col, k) : vec3(0.0);
	} else if (kd == 12) {
		l = lt_glow_ring(pc, r2.xy, r2.z, r3.x, col, k);
	} else if (kd == 13) {
		l = lt_glow_line(pc, r2.xy, r3.xy, r2.z, col, k);
	} else {
		l = lt_glow(pc, r2.xy, r2.z, col, k);
	}
	COLOR = vec4(l, 1.0);
}
