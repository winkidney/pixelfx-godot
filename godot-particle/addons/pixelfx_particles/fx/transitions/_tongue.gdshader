// burn-away's flames (colour layer): frame-table particles (fx/pickups/_ftp.gdshader), each a tongue standing on one
// pixel of the white-hot line (burn-away.js tongue(): four layers of the ramp, each narrower, shorter and hotter,
// swaying at the tip, wobbling with the original's noise). `data`, 4 rows a frame: row 0 (cell x, cell y (the row
// under the line pixel), -, -), row 1 (-, -, -, present), row 2 (height, half-width, sway, n). `t`: the clock.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float quad = 9.0;
uniform float t = 0.0;
uniform vec4 F[9] : source_color;

varying flat vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec4 r2 = texelFetch(data, ivec2(int(cu.x + 0.5), int(cu.y + 0.5) * 4 + 2), 0);
	float h = r2.x;
	float w = r2.y;
	float sway = r2.z;
	int n = int(r2.w + 0.5);
	float x = cu.z + 0.5;
	// tongue(p, F, x + 0.5, y + 1, ...): the row r up from its root lands on row y + 1 - r
	float r = -d.y;
	vec3 col = vec3(-1.0);
	if (r >= 0.0) {
		for (int l = 0; l < 4; l++) {
			float lw = l == 0 ? 1.0 : l == 1 ? 0.76 : l == 2 ? 0.54 : 0.3;
			float lh = l == 0 ? 1.0 : l == 1 ? 0.86 : l == 2 ? 0.68 : 0.42;
			int ri = l == 0 ? 2 : l == 1 ? 4 : l == 2 ? 6 : 8;
			float Ht = h * lh;
			if (r > Ht) {
				continue;
			}
			float u = r / max(1.0, Ht);
			float half_ = w * lw * pow(1.0 - u, 0.85) * min(1.0, (r + 1.5) / 3.5) + tr_noise(t * 9.0 + r * 0.45, n) * 0.5;
			if (half_ < 0.3) {
				continue;
			}
			float cx = x + sway * u * u * lh + tr_noise(t * 4.0 + r * 0.2, n + 7) * u * 1.1;
			float qx = cu.z + d.x;
			if (qx >= floor(cx - half_ + 0.5) && qx <= floor(cx + half_ + 0.5)) {
				col = F[ri].rgb;
			}
		}
	}
	if (col.r < 0.0) {
		discard;
	}
	vec4 o = vec4(col, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
