// One cloud's pixels (clouds.js cloud()'s column walk): which palette step a pixel takes, its alpha and its light.
#include "res://addons/pixelfx_particles/fx/weather/_clouds.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform vec4 C[8] : source_color;

// the pixel (x, y) (whole local px) of cloud g: its step (-1: none), alpha and light strength
int cloud_px(int g, float x, float y, out float a, out float lk) {
	a = 0.0;
	lk = 0.0;
	int j;
	int i;
	cloud_id(g, j, i);
	float grow;
	float w;
	float x0;
	float base;
	float H;
	if (!cloud_state(j, i, grow, w, x0, base, H)) {
		return -1;
	}
	float x1 = x0 - w / 2.0 - H;
	float x2 = x0 + w / 2.0 + H;
	if (x < floor(x1) || x > ceil(x2) || x < -160.0 || x > 159.0) {
		return -1;
	}
	float cx = x + 0.5;
	float fi = float(i);
	float top = 1e9;
	float top2 = 1e9;
	int n = 4 + int(floor(CR(j, i, 7) * 4.0));
	for (int k = 0; k < 7; k++) {
		if (k >= n) {
			break;
		}
		float f = (float(k) + 0.5) / float(n);
		float r = H * (0.5 + 0.35 * sin(PI * f)) * (0.75 + 0.5 * CR(j, i, 10 + k)) * (1.0 + 0.06 * sin((TAU * t) / D + float(k) + fi));
		float px = x0 + w * (f - 0.5) + (CR(j, i, 20 + k) - 0.5) * 6.0;
		float py = base - r * 0.3 - CR(j, i, 30 + k) * H * 0.15;
		float dx = cx - px;
		if (dx * dx >= r * r) continue;
		float yy = py - sqrt(r * r - dx * dx);
		if (yy < top) {
			top2 = top;
			top = yy;
		} else if (yy < top2) {
			top2 = yy;
		}
	}
	int nt = 1 + int(floor(CR(j, i, 8) * 3.0));
	for (int k = 0; k < 3; k++) {
		if (k >= nt) {
			break;
		}
		float f = 0.3 + CR(j, i, 40 + k) * 0.4;
		float r = H * (0.75 + 0.35 * CR(j, i, 50 + k)) * (1.0 + 0.05 * sin((TAU * t) / D + float(k) * 2.0 + fi));
		float px = x0 + w * (f - 0.5);
		float py = base - H * 0.55 - r * 0.2;
		float dx = cx - px;
		if (dx * dx >= r * r) continue;
		float yy = py - sqrt(r * r - dx * dx);
		if (yy < top) {
			top2 = top;
			top = yy;
		} else if (yy < top2) {
			top2 = yy;
		}
	}
	if (top > 1e8) {
		return -1;
	}
	float en = min(cx - x1, x2 - cx) / H;
	float bot = base + 1.5 + sin(cx * 0.21 + fi) * 0.8 - (en < 1.0 ? (1.0 - en) * 4.0 : 0.0);
	if (bot <= top || y < floor(top) || y >= bot) {
		return -1;
	}
	float h = bot - top;
	float inner = (top2 - top > 2.5 && top2 < bot - 2.0) ? floor(top2) : -999.0;
	ivec4 tone = LT[j];
	float d = y + 0.5 - top;
	float v = d / h;
	float th = bayer_(x, y) * 0.12;
	float md = length(vec2(cx - MX, y - MY));
	int c = d < 1.0 ? tone.w : v < 0.25 + th ? tone.z : v < 0.62 + th ? tone.y : tone.x;
	if (y == inner) c = max(c, tone.z);
	if (bot - y - 0.5 < 1.0 && v > 0.5) c = max(0, tone.x - 1);
	if (md < 46.0 && (d < 2.0 || y == inner || v < 0.3)) c = min(7, c + (md < 24.0 ? 2 : 1));
	a = LA[j] * min(1.0, grow * 1.5);
	if (d < 1.0 && md < 46.0) lk = 0.35 * (1.0 - md / 46.0);
	return c;
}
