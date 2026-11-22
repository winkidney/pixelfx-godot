// spawn/spawn-portal's rift, as the original draws it (hole() and lip()): a void with a lit far wall and three arms
// of light spiralling down into it, a ragged ring of white-hot light round it with a dark cut outside, on the floor
// plane (squashed by SY). rift_px() gives this cell's colour (a = 0: nothing); mode 0 the hole and the lip's far half
// (behind), 1 the lip's near half (in front). rift_light() its light: the hole's glow and the lip's.
uniform vec2 size = vec2(72.0, 28.0);
uniform vec2 center = vec2(0.0);
uniform int mode = 0;
uniform float rx = 0.0;
uniform float spin = 0.0;
uniform float heat = 1.0;
uniform float heat_hole = 1.0;
uniform float wind = 2.3;
uniform float sy = 0.34;
uniform vec4 pal[8] : source_color;
uniform vec4 void_c : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 white : source_color = vec4(1.0);

#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

float lip_at(float th) {
	return 1.0 + 0.05 * js_noise(th * 3.0 + spin * 0.6, 5) + 0.035 * js_noise(th * 8.0 - spin * 1.3, 9);
}

bool dot_at(vec2 cell, vec2 p) {
	return all(equal(cell, floor(p)));
}

vec4 rift_px(vec2 cell, float th_px) {
	vec4 o = vec4(0.0);
	if (rx < 1.0) {
		return o;
	}
	float ry = rx * sy;
	if (mode == 0) {
		vec2 c = cell + 0.5;
		if (cell.x >= floor(-rx - 2.0) && cell.x <= ceil(rx + 2.0) && cell.y >= floor(-ry - 2.0) && cell.y <= ceil(ry + 2.0)) {
			float u = c.x / rx;
			float v = c.y / ry;
			float q = length(vec2(u, v));
			float th = atan(v, u);
			float l = lip_at(th);
			if (q <= l) {
				float w = q / l;
				o = v < 0.0 && w > 0.72 ? (w > 0.86 ? pal[2] : pal[1]) : w > 0.55 ? pal[0] : void_c;
			}
		}
		// the arms
		int n = max(40, int(floor(rx * 5.0 + 0.5)));
		for (int i = 0; i < 3; i++) {
			for (int j = 0; j <= 400; j++) {
				if (j > n) {
					break;
				}
				float q = 0.14 + 0.82 * (float(j) / float(n));
				float th = spin + float(i) * TAU / 3.0 - wind * log(q);
				float l = lip_at(th);
				vec2 p = vec2(cos(th) * q * l * rx, sin(th) * q * l * ry);
				if (dot_at(cell, p)) {
					float a = q > 0.3 ? 1.0 : q / 0.3;
					if (a >= 1.0 || a > th_px) {
						o = q > 0.8 ? (heat_hole > 1.1 ? white : pal[6]) : q > 0.55 ? pal[5] : q > 0.32 ? pal[4] : pal[3];
					}
				}
				if (q > 0.4 && j % 2 == 0) {
					float t2 = th - 0.32;
					vec2 p2 = vec2(cos(t2) * q * 0.94 * l * rx, sin(t2) * q * 0.94 * l * ry);
					if (dot_at(cell, p2) && 0.85 > th_px) {
						o = q > 0.7 ? pal[4] : pal[3];
					}
				}
			}
		}
	}
	// the lip: far half (mode 0) or near half (mode 1)
	bool near = mode == 1;
	int m = int(ceil(rx * 7.0));
	for (int j = 0; j < 400; j++) {
		if (j >= m) {
			break;
		}
		float th = (float(j) / float(m)) * TAU;
		float s = sin(th);
		if ((s >= 0.0) != near) {
			continue;
		}
		float l = lip_at(th);
		if (dot_at(cell, vec2(cos(th) * (rx * l + 1.2), s * (ry * l + 1.0)))) {
			o = pal[1];
		}
		if (dot_at(cell, vec2(cos(th) * rx * l, s * ry * l))) {
			float f = js_noise(th * 9.0 + spin * 3.0, 13);
			o = near ? (f > -0.3 || heat > 1.1 ? white : pal[6]) : f > 0.2 ? pal[6] : pal[5];
		}
	}
	return o;
}

float glow_at(vec2 q, vec2 c, float r) {
	if (r < 1.0) {
		return 0.0;
	}
	float f = 1.0 - length(q - c) / r;
	return f > 0.0 ? f * f : 0.0;
}

vec3 rift_light(vec2 cell) {
	if (rx < 1.0) {
		return vec3(0.0);
	}
	vec2 q = cell + 0.5;
	float ry = rx * sy;
	vec3 l = pal[3].rgb * glow_at(q, vec2(0.0), rx * 0.45) * 0.35 * heat_hole;
	int m = int(ceil(rx * 7.0));
	for (int j = 0; j < 400; j += 6) {
		if (j >= m) {
			break;
		}
		float th = (float(j) / float(m)) * TAU;
		float s = sin(th);
		float lp = lip_at(th);
		l += pal[5].rgb * glow_at(q, vec2(cos(th) * rx * lp, s * ry * lp), 7.0) * (s >= 0.0 ? 0.3 : 0.2) * min(1.4, heat);
	}
	return l;
}
