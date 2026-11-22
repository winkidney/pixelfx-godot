// weather/rain's drops (rain.js layer()): layer 0..3, far to near, slot i falls a whole number of times a loop
// (trips), somewhere new each time; gusts sweep sheets of heavier and lighter rain across the far two (a baked
// noise G); the far ones end in the air, the near two land: layers 4 / 5 are their splashes (three a slot: the
// drops before this one), a crown on the floor or rings sliding apart along a puddle. Streaks: _streak.gdshader
// (CUSTOM.z length, .w alpha; COLOR.xy direction, .w the near drops' light). Splashes: _rain_splash.gdshader (CUSTOM.z
// age, .w size; COLOR.x the puddle (-1: a crown), .y the slot, .z its drop, .w the crown's light).
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_rain.gdshaderinc"

uniform int layer = 0;
uniform sampler2D G : filter_nearest;

const vec2 MM[4] = vec2[](vec2(10.0, 13.0), vec2(14.0, 17.0), vec2(19.0, 23.0), vec2(25.0, 29.0));
const float NN[4] = float[](200.0, 150.0, 96.0, 42.0);
const float LEN[4] = float[](2.0, 4.0, 7.0, 13.0);
// the far two: where they end in the air; the near two: the depth they land at
const vec2 END[4] = vec2[](vec2(-80.0, -6.0), vec2(-45.0, -2.0), vec2(0.0, 1.4), vec2(2.0, 6.5));
const vec2 SIZE[4] = vec2[](vec2(0.0), vec2(0.0), vec2(0.15, 0.4), vec2(0.6, 1.0));

bool body(int ii, out vec2 p, out vec4 cu, out vec4 col) {
	p = vec2(0.0);
	cu = vec4(0.0);
	col = vec4(0.0);
	bool splash = layer >= 4;
	int L = splash ? layer - 2 : layer;
	int i = splash ? ii / 3 : ii;
	int sd = seed * 11 + L;
	float u;
	int k;
	int m;
	trip(t, D, i, sd, int(MM[L].x), int(MM[L].y), u, k, m);
	int j = imod(k, m);
	float hh = 1.0 / sqrt(SLANT * SLANT + 1.0);
	vec2 dir = vec2(SLANT * hh, hh);
	if (!splash) {
		if (L < 2 && rand4(sd, i, j, 7) > 0.35 + 1.3 * (fsample(G, (-166.0 + rand4(sd, i, j, 2) * 332.0) * 0.8 + (256.0 * t) / D, 9.0 + float(L) * 40.0) - 0.32)) {
			return false;
		}
		float len = LEN[L];
		float en = END[L].x + rand4(sd, i, j, 1) * (END[L].y - END[L].x);
		float y0 = -172.0 - len;
		float y = y0 + (en - y0) * u;
		float x = -166.0 + rand4(sd, i, j, 2) * 332.0 - (en - y) * SLANT;
		p = vec2(x, y);
		cu = vec4(0.0, 0.0, len, L >= 2 ? 1.0 : min(1.0, (1.0 - u) * 5.0));
		col = vec4(dir, 0.0, 0.12);
		return true;
	}
	int back = ii % 3 + 1;
	float dur = D / float(m);
	float age = u * dur + float(back - 1) * dur;
	if (age > 0.7) {
		return false;
	}
	bool near = L == 3;
	int jp = imod(k - back, m);
	if (rand4(sd, i, jp, 5) > (near ? 1.0 : 0.7)) {
		return false;
	}
	float z = END[L].x + rand4(sd, i, jp, 1) * (END[L].y - END[L].x);
	float xp = -166.0 + rand4(sd, i, jp, 2) * 332.0;
	float size = SIZE[L].x + ((z - END[L].x) / (END[L].y - END[L].x)) * (SIZE[L].y - SIZE[L].x);
	int pl = near ? pool_at(xp, z) : -1;
	if (pl < 0 && age >= 0.22 + 0.14 * size) {
		return false;
	}
	p = vec2(xp, z);
	cu = vec4(0.0, 0.0, age, size);
	col = vec4(float(pl), float(i), float(jp), (pl < 0 && near && age < 0.1) ? 0.3 * (1.0 - age / 0.1) : 0.0);
	return true;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
