// A leaf as the original draws it (falling-leaves.js leaf()): one of three outlines (beech, maple, willow) squashed
// across by its flip (the sign says which face shows), tilted, rimmed, a midrib down the middle, the face lit on
// one side, the back paler and duller; a glint on one turned full face to the light. Placed by _leaves.gdshader.
// P: 6 colour sets (the three ramps, then the litter's duller copies) of 11: rim, vein, face 0..2, the back's vein,
// back 0..2, the glint, the glow.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 P[66] : source_color;

float outline(int sh, float u, float v) {
	if (sh == 0) {
		return abs(u) >= 1.0 ? 9.0 : (v * v) / (0.36 * (1.0 - u * u) * (1.15 - 0.3 * u));
	}
	if (sh == 1) {
		float r = length(vec2(u, v * 1.1));
		float a = atan(v, u);
		return r / (0.62 + 0.38 * pow(abs(cos(2.5 * a)), 1.5));
	}
	return abs(u) >= 1.0 ? 9.0 : (v * v) / (0.16 * (1.0 - u * u));
}

void fragment() {
	vec2 d = wx_cell(UV);
	vec2 q = d + 0.5;
	vec2 xy = cu.xy;
	float size = cu.z;
	float ang = cu.w;
	float flip = pc.x;
	int code = int(pc.y + 0.5);
	int sh = code % 3;
	int base = (code / 3) * 11;
	float a = pc.z;
	vec4 c = vec4(0.0);
	float cs = cos(ang);
	float sn = sin(ang);
	if (flip > 0.86 && d == floor(xy - vec2(cs, sn) * size * 0.3 - vec2(0.0, 1.0))) {
		c = P[base + 9];
	} else {
		bool back = flip < -0.25;
		float fs = 0.35 + 0.65 * abs(flip);
		float L = size;
		float Wd = size * 0.9;
		float ext = L + 1.5;
		if (q.x < floor(xy.x - ext) || q.x > ceil(xy.x + ext) + 1.0 || q.y < floor(xy.y - ext) || q.y > ceil(xy.y + ext) + 1.0) {
			discard;
		}
		vec2 dd = q - xy;
		float lu = (dd.x * cs + dd.y * sn) / L;
		float lv = (-dd.x * sn + dd.y * cs) / (Wd * fs);
		float dn = outline(sh, lu, lv);
		if (lu >= -1.25 && lu <= 1.1) {
			if (lu < -0.92 && abs(lv * Wd * fs) < 0.5) {
				c = P[base];
			} else if (dn <= 1.32) {
				if (dn > 1.0) {
					c = P[base];
				} else if (abs(lv * Wd * fs) < 0.45 && lu > -0.9 && lu < 0.75) {
					c = P[base + (back ? 5 : 1)];
				} else {
					int f = lv < -0.15 ? 2 : lv < 0.35 ? 1 : 0;
					c = P[base + (back ? 6 : 2) + f];
				}
			}
		}
		c.a *= a;
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
