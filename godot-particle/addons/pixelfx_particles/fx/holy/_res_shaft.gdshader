// holy/resurrection: the shaft of light pouring down on the fallen (soft colour layer, behind the character): a
// translucent cream veil shaped by its rays, the two brightest rays as fine dotted lines with light running down
// them, the white head of the pour, and dust motes lit where they cross a ray. `t` seconds (keyed).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/holy/_res_shaft.gdshaderinc"

uniform vec4 pal[8] : source_color;
// the two brightest rays: (offset, shimmer rate, phase, -)
uniform vec4 core[2];
// the motes: (q, y, speed, sway) and (phase, rate)
uniform vec4 mote_a[34];
uniform vec2 mote_b[34];

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	float th = pfx_threshold(FRAGCOORD.xy);
	float I = shaft_at(p);
	vec4 c = vec4(pal[6].rgb, I > 0.01 ? I * 0.24 : 0.0);
	float k = shaft_k();
	float front = front_y();
	// the brightest rays as fine lines, light running down them
	if (k > 0.0 && cell.y >= TOP && cell.y < min(front, 0.0)) {
		for (int i = 0; i < 2; i++) {
			float sh = 0.75 + 0.25 * sin(t * core[i].y + core[i].z);
			float x = floor(core[i].x * half_w(cell.y));
			if (cell.x == x) {
				float pulse = 0.5 + 0.5 * sin(cell.y * 0.13 - t * 11.0 + core[i].z);
				float a = k * sh * (0.15 + 0.55 * pulse) * r_smooth(front, front - 10.0, cell.y);
				if (a > th) {
					c = vec4(pulse > 0.8 ? vec3(1.0) : pal[6].rgb, 1.0);
				}
			}
		}
	}
	// the head of the pour
	if (t < POUR + 0.05 && front > TOP + 14.0) {
		float fy = min(front, 0.0);
		for (int d = -6; d <= 0; d++) {
			if (cell.x == 0.0 && cell.y == floor(fy + float(d)) && 1.0 + float(d) / 7.0 > th) {
				c = vec4(d > -3 ? vec3(1.0) : pal[6].rgb, 1.0);
			}
		}
	}
	// dust motes lit where they cross a ray
	if (k > 0.0) {
		for (int i = 0; i < 34; i++) {
			float y = TOP + mod(mote_a[i].y * -TOP + t * mote_a[i].z, -TOP);
			if (y > front || floor(y) != cell.y) {
				continue;
			}
			float w = half_w(y);
			float x = mote_a[i].x * w + sin(t * mote_b[i].y + mote_b[i].x) * mote_a[i].w;
			if (floor(x) != cell.x) {
				continue;
			}
			float m = profile(x / w) * k;
			if (m < 0.25 || min(1.0, m * 1.4) <= th) {
				continue;
			}
			c = vec4(m > 0.75 ? vec3(1.0) : m > 0.5 ? pal[6].rgb : pal[5].rgb, 1.0);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
