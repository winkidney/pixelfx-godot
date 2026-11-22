// Particles of explosions/big-explosion drawn as the original draws them (_lib.js), on a white square texture:
// mode 0, a column lobe (lobe(): a ball lit from the sky, burning in its heart, glowing from below): the particle's
// colour carries r = how hot its place in the column is (times `fire`), g = how much the cap lights it (times
// `glow`), b > 0.5 = a step darker, a = opacity. Mode 1, a fire puff (fireBall(): a darker rim, a lit core, a tongue
// on top, a hot heart): r = heat 0..1 down the fire ramp, a = opacity. Colour layer (set `translucent` for soft).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform float mode = 0.0;
uniform float fire = 1.0;
uniform float glow = 0.0;
uniform float style = 0.0;
uniform vec4 fr[9] : source_color;
uniform vec4 sm[5] : source_color;

vec4 D(int i, int dark) {
	return sm[min(4, i + dark)];
}

void fragment() {
	vec4 pc = COLOR;
	vec4 c;
	if (mode < 0.5) {
		vec2 P = (UV - 0.5) * 2.0;
		float r = 1.0 / max(abs(dFdx(P.x)), 1e-4);
		float d2 = dot(P, P);
		if (d2 > 1.0) {
			discard;
		}
		float dx = P.x;
		float dy = P.y;
		float d = sqrt(d2);
		float nz = sqrt(max(0.0, 1.0 - d2));
		float sky = -0.5 * dx - 0.66 * dy + 0.56 * nz;
		float f = clamp(fire * pc.r, 0.0, 1.0);
		float gl = glow * pc.g;
		int dark = pc.b > 0.5 ? 1 : 0;
		float a = pc.a;
		float rim = 1.0 - min(0.35, 1.6 / r);
		float seam = 1.0 - min(0.3, 1.3 / r);
		float soft = 0.55 + 0.4 * (1.0 - min(1.0, a));
		float v = f * (1.32 - 0.78 * d) + 0.14 * sky * f;
		bool solid = false;
		if (v > 0.44) {
			int i = clamp(int(floor((1.3 - v) * 8.0 * 0.78)), 0, 6);
			if (d > seam) {
				i = clamp(i + 2, 4, 6);
			} else if (d > seam - 0.22) {
				i = min(6, i + 1);
			}
			c = fr[i];
			solid = true;
		} else if (style > 0.5) {
			float lam = -0.42 * dx - 0.78 * dy + 0.46 * nz;
			if (lam > 0.66 && d > 0.4) {
				c = D(0, dark);
			} else if (lam > 0.16) {
				c = D(1, dark);
			} else if (lam > -0.3) {
				c = D(2, dark);
			} else {
				c = D(lam < -0.64 ? 4 : 3, dark);
				float g = gl * (0.6 + 0.4 * dy);
				if (g > 0.55) {
					c = fr[g > 0.8 ? 5 : 6];
				} else if (g > 0.34) {
					c = mix(c, fr[6], 0.6);
				} else if (g > 0.16) {
					c = mix(c, fr[7], 0.45);
				}
			}
		} else {
			float g = gl * (0.82 * dy + 0.3 * nz);
			if (g > 0.45) {
				c = fr[g > 0.66 ? 4 : 5];
			} else if (g > 0.3) {
				c = fr[6];
			} else if (g > 0.2) {
				c = fr[7];
			} else {
				float s = sky * 0.5 + 0.5;
				c = D(s > 0.8 ? 0 : (s > 0.62 ? 1 : (s > 0.42 ? 2 : (s > 0.22 ? 3 : 4))), dark);
			}
		}
		c.a = (solid || d <= rim) ? a : a * soft;
	} else {
		// the quad is 2.7 radii across, the ball in its middle: room for the tongue on top
		vec2 P = (UV - 0.5) * 2.7;
		float r = 1.0 / max(abs(dFdx(P.x)), 1e-4);
		int idx = min(7, int(floor(clamp(pc.r, 0.0, 0.999) * 8.0)));
		if (idx >= 7) {
			if (dot(P, P) > 1.0) {
				discard;
			}
			c = vec4(fr[idx].rgb, pc.a * 0.85);
		} else {
			vec4 hot = fr[idx];
			bool inside = false;
			if (r > 1.8 && idx <= 3 && length(P - vec2(-0.28, -0.34)) <= 0.36) {
				c = fr[max(0, idx - 1)];
			} else if (length(P - vec2(-0.16, -0.22)) <= 0.78 || (r > 1.6 && length(P - vec2(0.0, -0.9)) <= 0.42)) {
				c = hot;
			} else if (dot(P, P) <= 1.0) {
				c = fr[min(8, idx + (idx <= 2 ? 3 : 2))];
			} else {
				discard;
			}
			c.a = pc.a;
		}
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
