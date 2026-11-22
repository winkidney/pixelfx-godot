// flying-skull's crown of fire: _lib.js tongue() for each tongue on the crown, every layer (dark outer flame ..
// white-hot heart) laid down layer by layer so the tongues merge into one flame with one dark rim. Each tongue's
// height leaps and its tip licks with the original's own loop noise, and the crown follows the skull's bob (its
// lean, its stretch) worked out here from the keyed clock t (the effect's seconds). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/critters/_noise.gdshaderinc"

uniform vec2 size = vec2(96.0, 96.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 2.4;
uniform float hover = 40.0;
uniform bool front = false;
// the skull's cell (rounded at build time from the original's doubles: a .5 decides it now and then)
uniform float X = 0.0;
uniform float Y = 0.0;
// per tongue, in drawing order: x, y (its root, from the skull's centre), h, w; and its noise seed
uniform vec4 tg[16];
uniform float tn[16];
uniform int count = 0;
// the hot-first ramp: heat[0] white .. heat[8] smouldering
uniform vec4 heat[9] : source_color;

const vec3 LAYERS[4] = vec3[](vec3(1.0, 1.0, 6.0), vec3(0.76, 0.86, 4.0), vec3(0.54, 0.68, 2.0), vec3(0.3, 0.42, 0.0));

float jround(float x) {
	return floor(x + 0.5);
}

float height(int j, float k) {
	float h = tg[j].z;
	float n = tn[j];
	float leap = max(0.0, js_lnoise(t, period, 6.0, n * 3.1, 70.0) - 0.55) * 1.6;
	return (h + 0.25 * h * js_lnoise(t, period, 8.0, n * 1.7, 5.0) + h * leap) * (0.9 + 0.1 * k);
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float a = (t / period) * TAU;
	float vx = (3.0 * TAU * cos(a)) / period;
	float vy = (6.0 * TAU * cos(2.0 * a + 0.5)) / period;
	float k = 0.74 + 0.16 * js_lnoise(t, period, 18.0, 0.0, 1.0) + 0.1 * js_lnoise(t, period, 46.0, 0.0, 2.0);
	float lean = clamp(-vx / 60.0, -0.8, 0.8);
	float stretch = clamp(vy / 90.0, -0.3, 0.45);
	float F1 = max(1.0, jround(9.0 * period));
	float F2 = max(1.0, jround(4.0 * period));
	int hit = -1;
	// the last write wins: walk the layers and tongues backwards, stop at the first that covers this cell
	for (int li = 3; li >= 0 && hit < 0; li--) {
		vec3 L = LAYERS[li];
		for (int j = count - 1; j >= 0; j--) {
			float hj = height(j, k);
			float lick = js_lnoise(t, period, 5.0, tn[j], 40.0) * 2.0 + lean * hj * 0.9 - clamp(tg[j].x * 0.25, -2.0, 2.0);
			float x = X + tg[j].x;
			float y = Y + tg[j].y;
			float h = hj * (1.0 + stretch);
			float w = front ? tg[j].w : tg[j].w * (1.0 - 0.25 * abs(lean));
			float sw = front ? lick * 0.6 : lick;
			if (h < 1.0) {
				continue;
			}
			float H = h * L.y;
			float r = jround(y) - cell.y;
			if (r < 0.0 || r > H) {
				continue;
			}
			float u = r / max(1.0, H);
			float half_ = w * L.x * pow(1.0 - u, 0.85) * min(1.0, (r + 1.5) / 3.5) + js_lnoise(t, period, F1, r * 0.45, tn[j]) * 0.5;
			if (half_ < 0.3) {
				continue;
			}
			float cx = x + sw * u * u * L.y + js_lnoise(t, period, F2, r * 0.2, tn[j] + 7.0) * u * 1.1;
			if (cell.x >= jround(cx - half_) && cell.x <= jround(cx + half_)) {
				hit = int(L.z + 0.5);
				break;
			}
		}
	}
	if (hit < 0) {
		discard;
	}
	vec4 c = vec4(heat[hit].rgb, 1.0);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
