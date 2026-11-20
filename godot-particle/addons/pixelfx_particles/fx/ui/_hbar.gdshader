// health-bar-hit's HUD (src/fx/ui/health-bar-hit.js draw): the plate (_lib.js panel, red on the hit), the segmented
// bar (the fill lit on top and dark below, the white chunk that drains, the cell dividers, the new edge's glint, the
// draining edge's hot rect) and the heart (_lib.js HEART, `heart`: 1 k .. 6 d), white on the hit. Everything keyed
// every frame from the original's jolt, dip, unfold and drain. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/ui/_panel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 ink[5] : source_color;
uniform vec4 track[3] : source_color;
uniform vec4 pale : source_color;
uniform sampler2D heart : filter_nearest, repeat_disable;
uniform bool open_on = false;
uniform vec4 prc = vec4(0.0);
uniform float pr = 5.0;
uniform bool red = false;
uniform bool bar_on = false;
uniform vec2 off = vec2(0.0);
uniform float val = 0.8;
uniform float ghost = 0.8;
uniform bool white = false;
uniform bool edge_on = false;
uniform float val_x = 0.0;
uniform bool drain_on = false;
uniform vec2 drain_x = vec2(0.0);
uniform vec2 heart_at = vec2(0.0);
uniform bool heart_white = false;

const float BX = -48.0;
const float BW = 104.0;
const float BY = -4.0;
const float BH = 8.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 pc = cell + 0.5;
	vec3 c = vec3(0.0);
	bool hit = false;
	if (open_on && bar_on) {
		vec2 hq = cell - heart_at;
		if (hq.x >= 0.0 && hq.y >= 0.0 && hq.x < 13.0 && hq.y < 12.0) {
			int k = int(texelFetch(heart, ivec2(hq), 0).r * 255.0 + 0.5);
			if (k > 0) {
				hit = true;
				vec3 hc[7] = vec3[](vec3(0.0), C[0].rgb, vec3(1.0), C[5].rgb, C[4].rgb, C[3].rgb, C[2].rgb);
				c = hc[k];
				if (heart_white && k > 1) {
					c = k == 6 ? C[6].rgb : vec3(1.0);
				}
			}
		}
		float bx0 = BX + off.x;
		float by0 = BY + off.y;
		if (!hit && drain_on && cell.x >= drain_x.x && cell.x < drain_x.y && cell.y >= by0 - 1.0 && cell.y < by0 + BH + 1.0) {
			hit = true;
			c = vec3(1.0);
		}
		bool in_bar = cell.y >= by0 && cell.y < by0 + BH;
		if (!hit && edge_on && in_bar && cell.x == val_x) {
			hit = true;
			c = C[7].rgb;
		}
		if (!hit && in_bar) {
			for (int i = 1; i < 10; i++) {
				if (cell.x == bx0 + floor(BW * float(i) / 10.0 + 0.5)) {
					hit = true;
					c = track[0].rgb;
				}
			}
		}
		if (!hit && cell.x >= bx0 && cell.x <= bx0 + BW && cell.y >= by0 && cell.y <= by0 + BH) {
			hit = true;
			float u = (pc.x - bx0) / BW;
			float v = pc.y - by0;
			if (u < val) {
				c = v < 1.0 ? C[6].rgb : v < 2.0 ? C[5].rgb : v < 5.0 ? C[4].rgb : v < 7.0 ? C[3].rgb : C[2].rgb;
			} else if (u < ghost) {
				c = white ? vec3(1.0) : v < 1.0 ? vec3(1.0) : v < 6.0 ? pale.rgb : C[5].rgb;
			} else {
				c = v < 1.0 ? track[1].rgb : track[2].rgb;
			}
		}
	}
	if (!hit && open_on) {
		int k = panel_px(pc, prc, pr, false, 0.0);
		if (k >= 0) {
			hit = true;
			c = ink[k].rgb;
			if (red && k == 0) {
				c = C[4].rgb;
			} else if (red && k == 1) {
				c = C[6].rgb;
			}
		}
	}
	if (!hit) {
		discard;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
