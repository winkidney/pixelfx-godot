// The hammer head's smear (hammer-smash.js wedge()) along a swing, colour layer: a comet from u = T to U centred on
// plane radius Rm, HW px across at its hard white leading face, tapering to a hair behind it and cooling along the
// taper (edges first) down `ramp` (darkest first, `n` colours), thinning as it lands (`after`); and speed lines
// trailing the head along the arc, ln[i] = (radius offset, start px behind the head, length, 1: start past the comet's
// tail), dotted out at their ends. Key T, U, after.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/melee/_swing.gdshaderinc"

uniform float T = 0.0;
uniform float U = 0.0;
uniform float after = 0.0;
uniform float HW = 13.0;
uniform float Rm = 25.0;
uniform vec4 ramp[8];
uniform float n = 8.0;
uniform vec4 ln[6];

void fragment() {
	vec4 tint = COLOR;
	if (U - T < 0.03 || after >= 1.0) {
		discard;
	}
	vec2 p = sw_px(UV);
	vec2 ra = sw_plane(p);
	float r = ra.x;
	float len = (U - T) * Rm;
	vec4 c = vec4(0.0);
	float u = sw_u(ra.y, T, U);
	if (u >= 0.0 && r <= R + 2.0 && r >= R - HW - 2.0) {
		float lead = (U - u) * Rm;
		float f = lead / len;
		float w = HW * (lead < 3.0 ? 1.0 : pow(max(0.0, 1.0 - (lead - 3.0) / max(1.0, len - 3.0)), 0.85)) * (1.0 - after * 0.5);
		float off = (r - Rm) / (w / 2.0 + 0.01);
		if (w >= 0.6 && abs(off) <= 1.0) {
			float ci = lead < 2.0 ? 0.0 : floor(1.0 + f * 3.4 + abs(off) * 1.4 - (off > 0.55 ? 1.0 : 0.0) + after * 3.0 + 0.5);
			if (ci <= n - 3.0) {
				c = ramp[int(n) - 1 - int(max(0.0, ci))];
				c.a = 1.0;
			}
		}
	}
	if (after < 0.6) {
		float ub = sw_u(ra.y, 0.0, U);
		if (ub >= 0.0) {
			for (int i = 0; i < 6; i++) {
				float rl = Rm + ln[i].x;
				if (abs(r - rl) > 0.55) {
					continue;
				}
				float l0 = ln[i].y + (ln[i].w > 0.5 ? len : 0.0);
				float d = (U - ub) * rl;
				float k = (d - l0) / ln[i].z;
				if (d < l0 || d >= l0 + ln[i].z * (1.0 - after)) {
					continue;
				}
				vec4 cc = k < 0.25 ? ramp[6] : k < 0.6 ? ramp[5] : ramp[4];
				cc.a = (1.0 - k) * (1.0 - after);
				if (pfx_threshold(FRAGCOORD.xy) <= cc.a * alpha_scale) {
					c = vec4(cc.rgb, 1.0);
				}
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
