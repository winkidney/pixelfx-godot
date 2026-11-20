// weather/storm's per-pixel passes (src/fx/weather/storm.js): pass_ 0 the light only (the sky lit by each stroke,
// the sheet lightning's glow, the deck's and the floor's light); 1 the veil of rain sweeping across on the gusts;
// 2 the cloud deck seen from below, rows of rolls swelling, drifting and dissolving on their own clocks, lit from
// inside by the flashes; 3 the wet floor: mist low over it, a broken lip of light, pools that flash with the sky.
// The flashes' strengths are keyed: f (the strokes), sh (sheet lightning), src (what lights the deck: the bolt's
// root, the sheet, the far flicker, the farther one).
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 V[6] : source_color;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 veil_glow : source_color = vec4(1.0);
uniform vec4 sky_light : source_color = vec4(1.0);
uniform sampler2D F : filter_nearest;
uniform sampler2D M : filter_nearest;
// the floor's own field (F is the deck's, or the veil's)
uniform sampler2D FL : filter_nearest;
uniform int pass_ = 0;
uniform int seed = 5;
uniform float f = 0.0;
uniform float sh = 0.0;
uniform vec4 src = vec4(0.0);

const float D = 10.0;
const float SLANT = 0.42;
const float BX0 = 62.0;
const float BY0 = -136.0;
const float BX1 = 52.0;
const float BY1 = 3.0;

// base, n, rx0, rx1 / ry, drift, life0, life1
const vec4 RA[3] = vec4[](vec4(-161.0, 18.0, 16.0, 30.0), vec4(-150.0, 22.0, 10.0, 20.0), vec4(-140.0, 26.0, 7.0, 14.0));
const vec4 RB[3] = vec4[](vec4(0.8, 15.0, 4.0, 7.0), vec4(0.85, 10.0, 3.5, 6.5), vec4(0.9, 6.0, 3.0, 6.0));
const ivec4 RT[3] = ivec4[](ivec4(1, 2, 3, 4), ivec4(1, 2, 3, 5), ivec4(2, 2, 3, 5));

float lit_at(vec2 p) {
	float L = 0.0;
	vec3 s0 = vec3(BX0, BY0 - 6.0, 150.0);
	vec3 s1 = vec3(-96.0, -146.0, 120.0);
	vec3 s2 = vec3(128.0, -156.0, 80.0);
	vec3 s3 = vec3(-40.0, -160.0, 70.0);
	for (int i = 0; i < 4; i++) {
		vec3 s = i == 0 ? s0 : i == 1 ? s1 : i == 2 ? s2 : s3;
		float k = src[i];
		if (k <= 0.0) continue;
		float d = length(vec2(p.x - s.x, (p.y - s.y) * 1.5)) / s.z;
		if (d < 1.0) L += k * (1.0 - d) * (1.0 - d);
	}
	return min(1.0, L);
}

vec4 ramp9(int i) {
	return i <= 6 ? C[i] : i == 7 ? V[4] : white;
}

// mode: 0 nothing, 1 translucent (soft layer), 2 opaque or dithered (colour layer)
void storm_px(vec2 p, out vec4 c, out int mode, out vec3 l) {
	c = vec4(0.0);
	mode = 0;
	l = vec3(0.0);
	float x = p.x;
	float y = p.y;
	int S = seed;
	if (pass_ == 0) {
		float k = f * 0.36;
		if (k > 0.01) {
			float d = abs(x - (BX0 + BX1) / 2.0) / 230.0;
			l += sky_light.rgb * k * (0.2 + 0.8 * pow(max(0.0, 1.0 - d), 2.2));
		}
		if (sh > 0.05 && y < 1.0) {
			float d = length(vec2(x + 96.0, (y + 150.0) * 1.3)) / 170.0;
			if (d < 1.0) l += V[2].rgb * sh * 0.3 * (1.0 - d) * (1.0 - d);
		}
	}
	if (pass_ == 1) {
		if (y > 1.0) return;
		float n = fsample(F, (x - y * SLANT) * 1.9 - (256.0 * 2.0 * t) / D, y * 0.16 + 7.0);
		float dens = clamp(0.45 + (n - 0.5) * 2.6, 0.0, 1.0);
		vec3 col = C[1].rgb;
		if (f > 0.05) col = mix(C[1].rgb, veil_glow.rgb, min(1.0, f * dens * 0.7 * max(0.25, 1.0 - abs(x - BX1) / 220.0)));
		c = vec4(col, 0.4 + 0.38 * dens);
		mode = 1;
		return;
	}
	if (pass_ == 2 || pass_ == 0) {
		if (y < -40.0) {
			float drift = (256.0 * t) / D;
			float mo = pow(cos((PI * t) / D), 2.0);
			float cx = x;
			float bot[3];
			float bulge[3];
			for (int j = 0; j < 3; j++) {
				vec4 a = RA[j];
				vec4 b = RB[j];
				float fj = float(j);
				float und = (fsample(F, cx * 0.55 + fj * 91.0, 3.0) * mo + fsample(F, cx * 0.55 + fj * 91.0, 60.0) * (1.0 - mo) - 0.5) * 2.0;
				float sag = 9.0 * exp(-pow((cx - 40.0) / 95.0, 2.0)) - 3.0;
				float c0 = a.x + sag * (0.4 + fj * 0.3) + 7.0 * und + 3.0 * 2.0 * (fsample(F, cx * 1.8 + fj * 61.0 - drift * (0.5 - fj * 0.1), 20.0 + fj * 17.0) - 0.5);
				float bump = 0.0;
				for (int i = 0; i < 26; i++) {
					if (float(i) >= a.y) break;
					float L = b.z + rand4(S, j, i, 1) * (b.w - b.z);
					float age = mod(t - rand4(S, j, i, 2) * D, D);
					if (age >= L) continue;
					float u = age / L;
					float g = pow(sin(PI * u), 0.6);
					float rx = a.z + rand4(S, j, i, 3) * (a.w - a.z);
					float ry = rx * b.x;
					float bx = -200.0 + rand4(S, j, i, 4) * 400.0 + b.y * (age - L / 2.0);
					float h = ry * g * (0.6 + 0.4 * rand4(S, j, i, 5));
					float dx = (cx - bx) / (rx * (0.8 + 0.2 * g));
					if (dx * dx < 1.0) bump = max(bump, h * sqrt(1.0 - dx * dx));
				}
				bot[j] = c0 + bump;
				bulge[j] = bump;
			}
			int j = bot[0] > y ? 0 : bot[1] > y ? 1 : bot[2] > y ? 2 : 3;
			if (j < 3) {
				// where this row took over in the column: the first pixel below the rows before it
				float prevBot = -999.0;
				if (j > 0) {
					float mx = j == 1 ? bot[0] : max(bot[0], bot[1]);
					float first = ceil(mx - 0.5) + 0.5;
					if (first > -169.5) prevBot = first;
				}
				ivec4 tone = RT[j];
				float d = bot[j] - y;
				float th = bayer_(x, y);
				int i;
				if (d < 1.0) i = bulge[j] > 3.0 ? tone.w : tone.w - 1;
				else if (y - prevBot < 1.5 && j > 0) i = max(0, tone.x - 1);
				else if (d < 2.0 + bulge[j] * 0.25 + th * 2.0) i = tone.z;
				else if (d < 6.0 + bulge[j] * 0.4 + th * 3.0) i = tone.y;
				else {
					float fj = float(j);
					float nn = fsample(F, cx * 0.9 + fj * 77.0 - drift * (0.6 - fj * 0.12), y * 1.7 + fj * 31.0);
					i = tone.x + (j < 2 && nn > 0.6 ? 1 : 0);
				}
				float lk = 0.0;
				float Lv = lit_at(p);
				if (Lv > 0.02) {
					i = min(8, i + int(floor(Lv * (d < 1.0 ? 4.4 : d < 4.0 ? 3.8 : 3.1) + 0.5)));
					lk = Lv;
				}
				if (pass_ == 2) {
					c = ramp9(max(0, i));
					if (j == 2 && lk <= 0.0 && d >= 1.0) {
						c.a = 0.75;
						mode = 1;
					} else {
						mode = 2;
					}
					return;
				}
				if (lk > 0.03) l += V[3].rgb * lk * (d < 3.0 ? 0.4 : 0.22);
			}
		}
		if (pass_ == 2) return;
	}
	if (pass_ == 3 || pass_ == 0) {
		if (y > -14.0 && y < 0.0 && pass_ == 3) {
			float m = fsample(M, x * 1.1 - (256.0 * 3.0 * t) / D, y * 4.0 + 9.0) - 0.4;
			if (m > 0.0) {
				c = vec4((f > 0.1 ? mix(C[4], V[3], f) : C[4]).rgb, min(0.3, m * 0.9) * (1.0 + y / 14.0));
				mode = 1;
			}
			return;
		}
		if (y > 0.0) {
			bool wet = fsample(FL, x * 1.3 + 31.0, y * 9.0) > 0.6 - y * 0.006;
			bool lip = wet && !(fsample(FL, x * 1.3 + 31.0, (y - 1.0) * 9.0) > 0.6 - (y - 1.0) * 0.006);
			c = vec4(C[1].rgb, 0.5);
			mode = 1;
			if (y < 1.0) {
				c = fsample(FL, x * 2.0, 50.0) > 0.5 ? C[4] : C[3];
				mode = 2;
			} else if (wet) {
				float d = abs(x - BX1) / 150.0;
				if (f > 0.06) {
					c = vec4((((d < 0.25 && f > 0.5) || lip) ? V[4] : V[3]).rgb, clamp(f * (1.35 - d) * (lip ? 1.4 : 1.0), 0.0, 1.0));
					mode = 2;
				} else {
					c = vec4((lip ? C[5] : C[3]).rgb, lip ? 1.0 : 0.7);
				}
				l += V[3].rgb * f * 0.25 * max(0.0, 1.0 - d);
			}
		}
	}
}
