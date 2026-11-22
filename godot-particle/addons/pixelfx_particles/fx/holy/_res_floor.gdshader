// holy/resurrection: the floor in front of the feet (colour layer): the pool of light the shaft leaves (a bright
// line and a pool fading into the stone, `kp` strong, `pw` px either side) and the ripple of light the downstroke
// sends out along the floor (`ru` 0..1 through it; < 0 none). Px from the origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(192.0, 10.0);
uniform vec2 center = vec2(0.0);
uniform float kp = 0.0;
uniform float pw = 1.0;
uniform float ru = -1.0;
uniform vec4 pal[8] : source_color;

void fragment() {
	vec2 cell = floor(floor((UV - 0.5) * size) + 0.5 + center);
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 c = vec4(0.0);
	if (kp > 0.0 && cell.y >= 0.0 && cell.y <= 3.0 && cell.x >= floor(-pw) && cell.x <= pw) {
		float u = length(vec2(cell.x / pw, cell.y / 4.0));
		if (u < 1.0) {
			float a = kp * (cell.y == 0.0 ? sqrt(1.0 - u) * 1.2 : (1.0 - u) * 0.9);
			if (a >= 1.0 || a > th) {
				c = u < 0.3 ? (cell.y > 0.0 ? pal[5] : vec4(1.0)) : u < 0.6 ? pal[5] : u < 0.85 ? pal[4] : pal[3];
			}
		}
	}
	if (ru >= 0.0 && cell.y == 0.0) {
		float fx = 10.0 + 70.0 * (1.0 - pow(1.0 - ru, 3.0));
		for (int s = -1; s <= 1; s += 2) {
			for (int d = 0; d < 12; d++) {
				if (floor(float(s) * (fx - float(d))) == cell.x) {
					float a = (1.0 - ru) * (1.0 - float(d) / 12.0) * 1.3;
					if (a >= 1.0 || a > th) {
						c = d < 2 ? vec4(1.0) : d < 5 ? pal[6] : pal[4];
					}
				}
			}
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
