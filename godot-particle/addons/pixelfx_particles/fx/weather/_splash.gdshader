// A raindrop's splash on the floor (src/fx/weather/_lib.js splash()), age seconds after it lands: a white crown for
// a frame or two, a flat ring spreading (its near arc brighter), droplets thrown up that fall back. Placed by
// _storm_rain.gdshader (layer 2); hot / cool by how much the flash lights it.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform int seed = 5;
uniform vec4 hot[3] : source_color;
uniform vec4 cool[3] : source_color;

bool shows(float a, float thr) {
	return a > 0.0 && (a >= 1.0 || a > thr);
}

void fragment() {
	vec2 Q = wx_cell(UV);
	vec2 X = cu.xy;
	float age = cu.z;
	float size = cu.w;
	int lit = int(pc.x + 0.5);
	vec4 H_ = hot[lit];
	vec4 C_ = cool[lit];
	float thr = pfx_threshold(FRAGCOORD.xy);
	float L = 0.3 + 0.12 * size;
	float u = age / L;
	vec4 c = vec4(0.0);
	if (u < 1.0) {
		// the drop's own number, floor(rand(S, i, jp, 4) * 1e6), worked out on whole uints
		uint hh = hash4(seed, int(pc.y + 0.5), int(pc.z + 0.5), 4);
		uint A = (hh >> 16u) * 15625u;
		int Hn = int((A >> 10u) + ((((A & 1023u) << 16u) + (hh & 65535u) * 15625u) >> 26u));
		int nd = size > 0.55 ? 3 : 2;
		bool done = false;
		for (int dI = 2; dI >= 0; dI--) {
			if (dI >= nd) continue;
			float vx = (rand3(Hn, dI, 1) - 0.5) * 2.0 * (25.0 + 35.0 * size);
			float vy = -(55.0 + rand3(Hn, dI, 2) * 70.0 * (0.5 + size));
			float y = X.y - 1.0 + vy * age + 475.0 * age * age;
			if (y > X.y - 0.5 || age > 0.34) continue;
			float xx = X.x + vx * age;
			if (vy + 950.0 * age < -40.0 && floor(vec2(xx - vx * 0.012, y + 1.0)) == Q && shows(0.7, thr)) {
				c = C_;
				done = true;
				break;
			}
			if (floor(vec2(xx, y)) == Q) {
				c = age < 0.12 ? H_ : C_;
				done = true;
				break;
			}
		}
		if (!done) {
			float rx = 1.0 + (1.2 + 3.6 * size) * sqrt(u);
			float ry = max(0.5, rx * 0.26);
			int n = int(ceil(rx * 6.5));
			for (int j = n - 1; j >= 0; j--) {
				float a = (float(j) / float(n)) * TAU;
				float s = sin(a);
				if (s < -0.25) continue;
				if (floor(X + vec2(cos(a) * rx, s * ry)) != Q) continue;
				float al = u < 0.45 ? (s > 0.2 ? 1.0 : 0.7) : (1.0 - u) * 1.6 * (s > 0.2 ? 1.0 : 0.6);
				if (!shows(al, thr)) continue;
				c = u < 0.3 && s > 0.0 ? H_ : C_;
				done = true;
				break;
			}
		}
		if (!done && age < 0.07) {
			vec2 b = floor(X);
			float up = age > 0.035 ? 1.0 : 0.0;
			if (size > 0.65 && age > 0.03 && (Q == b + vec2(-2.0, -2.0) || Q == b + vec2(2.0, -2.0))) c = C_;
			else if (size > 0.3 && (Q == b + vec2(-1.0, -1.0 - up) || Q == b + vec2(1.0, -1.0 - up))) c = H_;
			else if (Q == b + vec2(0.0, -1.0)) c = H_;
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.a = 1.0;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
