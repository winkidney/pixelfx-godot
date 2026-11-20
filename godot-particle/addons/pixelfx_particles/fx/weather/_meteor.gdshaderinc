// A meteor of weather/shooting-stars as the original draws it (shooting-stars.js meteor()), age seconds after it
// lights: the train it leaves along its whole path, glowing, widening, twisting and fading; the head, a white point
// with a trail cooling down the ramp; for the big ones a flare, little stars twinkling round it and fragments
// carrying on. meteor_px: the colour of cell Q (whole local px; thr: the screen's dither threshold there),
// meteor_light: the light at pixel centre p.
#include "res://addons/pixelfx_particles/fx/weather/_shooting.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_line.gdshaderinc"

uniform vec4 C[6] : source_color;
uniform vec4 white : source_color = vec4(1.0);

bool shows(float a, float thr) {
	return a > 0.0 && (a >= 1.0 || a > thr);
}

vec4 meteor_px(int i, vec2 Q, float thr) {
	float age = meteor_age(i);
	vec4 A = MA[i];
	vec4 B = MB[i];
	float ca = cos(A.w);
	float sa = sin(A.w);
	vec2 dir = vec2(ca, sa);
	float v = B.x;
	float life = B.y;
	float s = B.z;
	bool flare = B.w > 0.5;
	vec2 m = A.yz;
	int S = seed;
	if (age <= life + (flare ? 0.5 : 0.0)) {
		if (flare && age >= life * 0.82) {
			float f = (age - life * 0.82) / (life * 0.18 + 0.5);
			vec2 F = m + dir * v * life * 0.86;
			float g = 1.0 - f;
			if (g > 0.0) {
				for (int j = 3; j >= 0; j--) {
					float da = (rand4(S, i, j, 1) - 0.5) * 0.5;
					float sp = v * (0.5 + rand4(S, i, j, 2) * 0.4);
					float tt = f * (life * 0.18 + 0.5);
					vec2 e = vec2(cos(A.w + da), sin(A.w + da));
					vec2 x = F + e * sp * tt;
					if (Q == floor(x)) {
						return g > 0.5 ? white : C[4];
					}
					float u;
					if (shows(g, thr) && on_line(Q, floor(x - e * 5.0 * g), floor(x), u)) {
						return C[3];
					}
				}
			}
			for (int j = 6; j >= 0; j--) {
				float ang = rand4(S, i, j, 5) * TAU;
				float r = 5.0 + rand4(S, i, j, 6) * 16.0;
				float d0 = rand4(S, i, j, 7) * 0.3;
				float gg = (f - d0) / 0.45;
				if (gg <= 0.0 || gg >= 1.0) continue;
				vec2 sx = F + vec2(cos(ang), sin(ang)) * r * (0.6 + gg * 0.5) - vec2(0.0, gg * 3.0);
				float arm = floor(2.5 * sin(PI * gg) + 0.5);
				if (arm >= 1.0) {
					vec4 c = sparkle_px(Q, sx, arm, j % 3 != 0 ? C[4] : white, C[3], white);
					if (c.a > 0.0) return c;
				} else if (Q == floor(sx)) {
					return C[4];
				}
			}
			if (f < 0.35) {
				vec4 c = sparkle_px(Q, F, 9.0 * sin((PI * f) / 0.35) + 2.0, C[4], C[3], white);
				if (c.a > 0.0) return c;
			}
		}
		float u = age / life;
		float k = age < life ? min(1.0, u * 6.0) * (u > 0.75 ? 1.0 - (u - 0.75) / 0.25 : 1.0) : 0.0;
		if (k > 0.0) {
			vec2 h = meteor_head(i, age);
			vec2 hc = floor(h);
			if (Q == hc) return white;
			if (s > 0.9 && Q == floor(h + vec2(1.0, 0.0))) return white;
			if (s > 0.9 && Q == floor(h + vec2(0.0, 1.0))) return C[4];
			float L = (24.0 + 40.0 * s) * min(1.0, u * 3.0);
			float dd = -dot(Q + 0.5 - h, dir);
			int n = int(floor(L / 0.5 + 1e-6));
			int hi = min(n, int(floor((dd + 3.0) * 2.0)));
			int lo = max(0, int(floor((dd - 3.0) * 2.0)));
			for (int st = hi; st >= lo; st--) {
				float d = float(st) * 0.5;
				float vv = d / L;
				vec2 x = h - dir * d;
				if (s > 0.9 && vv < 0.4 && Q == floor(x + vec2(-sa, ca) * 0.9) && shows(k * (1.0 - vv / 0.4), thr)) {
					return vv < 0.15 ? C[4] : C[3];
				}
				if (Q == floor(x)) {
					float a = k * (vv < 0.6 ? 1.0 : (1.0 - vv) / 0.4);
					if (shows(a, thr)) {
						int ri = clamp(int(floor(vv * 0.95 * 5.0)), 0, 4);
						return vv < 0.08 ? white : C[5 - ri];
					}
				}
			}
		}
	}
	float trainK = age < life ? 1.0 : 1.0 - (age - life) / (TRAIN + (flare ? 0.5 : 0.0));
	if (trainK > 0.0) {
		float burn = min(age, life);
		float len = v * burn;
		float d0 = dot(Q + 0.5 - m, dir);
		int hi = min(int(ceil(len)) - 1, int(floor(d0 + 14.0)));
		int lo = max(0, int(floor(d0 - 14.0)));
		for (int di = hi; di >= lo; di--) {
			float d = float(di);
			if (d >= len) continue;
			float passed = age - d / v;
			if (passed < 0.08) continue;
			float g = trainK * min(1.0, (passed - 0.08) * 4.0) * (0.35 + 0.65 * sin((PI * d) / len)) * s;
			float tw = sin(d * 0.09 + passed * 1.7) * min(4.0, passed * 3.0);
			vec2 x = m + dir * d + vec2(-sa, ca) * tw + vec2(passed * 4.0, 0.0);
			if (Q == floor(x) && shows(g * 0.75, thr)) {
				return passed < 0.6 ? C[2] : C[1];
			}
		}
	}
	return vec4(0.0);
}

vec3 meteor_light(int i, vec2 p) {
	float age = meteor_age(i);
	vec4 A = MA[i];
	vec4 B = MB[i];
	float ca = cos(A.w);
	float sa = sin(A.w);
	vec2 dir = vec2(ca, sa);
	float v = B.x;
	float life = B.y;
	float s = B.z;
	bool flare = B.w > 0.5;
	vec2 m = A.yz;
	int S = seed;
	vec3 l = vec3(0.0);
	float trainK = age < life ? 1.0 : 1.0 - (age - life) / (TRAIN + (flare ? 0.5 : 0.0));
	if (trainK > 0.0) {
		float burn = min(age, life);
		float len = v * burn;
		for (int di = 0; di < 400; di += 6) {
			float d = float(di);
			if (d >= len) break;
			float passed = age - d / v;
			if (passed < 0.08) continue;
			float g = trainK * min(1.0, (passed - 0.08) * 4.0) * (0.35 + 0.65 * sin((PI * d) / len)) * s;
			float tw = sin(d * 0.09 + passed * 1.7) * min(4.0, passed * 3.0);
			vec2 x = m + dir * d + vec2(-sa, ca) * tw + vec2(passed * 4.0, 0.0);
			l += C[1].rgb * glow_(p, x, 6.0 + passed * 4.0, 0.12 * g);
		}
	}
	if (age > life + (flare ? 0.5 : 0.0)) {
		return l;
	}
	float u = age / life;
	float k = age < life ? min(1.0, u * 6.0) * (u > 0.75 ? 1.0 - (u - 0.75) / 0.25 : 1.0) : 0.0;
	if (k > 0.0) {
		vec2 h = meteor_head(i, age);
		float L = (24.0 + 40.0 * s) * min(1.0, u * 3.0);
		l += C[4].rgb * glow_(p, h, 8.0 + 10.0 * s, 0.45 * k);
		l += C[3].rgb * glow_(p, h - dir * L * 0.3, 10.0 + 8.0 * s, 0.2 * k);
	}
	if (!flare || age < life * 0.82) {
		return l;
	}
	float f = (age - life * 0.82) / (life * 0.18 + 0.5);
	vec2 F = m + dir * v * life * 0.86;
	if (f < 0.35) {
		float n = floor(9.0 * sin((PI * f) / 0.35) + 2.0 + 0.5);
		if (n >= 1.0) l += C[4].rgb * glow_(p, F, 4.0 + n * 2.0, 0.6);
		l += C[3].rgb * glow_(p, F, 40.0, 0.5 * (1.0 - f / 0.35));
	}
	for (int j = 0; j < 7; j++) {
		float ang = rand4(S, i, j, 5) * TAU;
		float r = 5.0 + rand4(S, i, j, 6) * 16.0;
		float d0 = rand4(S, i, j, 7) * 0.3;
		float gg = (f - d0) / 0.45;
		if (gg <= 0.0 || gg >= 1.0) continue;
		vec2 sx = F + vec2(cos(ang), sin(ang)) * r * (0.6 + gg * 0.5) - vec2(0.0, gg * 3.0);
		float arm = floor(2.5 * sin(PI * gg) + 0.5);
		if (arm >= 1.0) l += (j % 3 != 0 ? C[4] : white).rgb * glow_(p, sx, 4.0 + arm * 2.0, 0.3 * (1.0 - gg));
	}
	float g = 1.0 - f;
	if (g > 0.0) {
		for (int j = 0; j < 4; j++) {
			float da = (rand4(S, i, j, 1) - 0.5) * 0.5;
			float sp = v * (0.5 + rand4(S, i, j, 2) * 0.4);
			float tt = f * (life * 0.18 + 0.5);
			vec2 x = F + vec2(cos(A.w + da), sin(A.w + da)) * sp * tt;
			l += C[3].rgb * glow_(p, x, 5.0, 0.35 * g);
		}
	}
	return l;
}
