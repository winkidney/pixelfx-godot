// wisp's soul-flame: its tail of three flame tongues (_lib.js tongue(), layer by layer, licking with the original's
// loop noise and streaming back as it flies), the head (a ball of cold fire, white at the heart, its rim flickering)
// and its face (eyes looking where it's going, a blink, a little mouth). Keyed: t (the effect's seconds), X, Y (where
// it is), lean, stretch, look, blink. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/critters/_noise.gdshaderinc"

uniform vec2 size = vec2(128.0, 104.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 3.2;
uniform float X = 0.0;
uniform float Y = 0.0;
uniform float lean = 0.0;
uniform float stretch = 0.0;
uniform float look = 0.0;
uniform bool blink = false;
uniform vec4 pal[7] : source_color;

const vec3 LAYERS[4] = vec3[](vec3(1.0, 1.0, 6.0), vec3(0.76, 0.86, 4.0), vec3(0.54, 0.68, 2.0), vec3(0.3, 0.42, 0.0));
// [dx, h, w, n]
const vec4 TAILS[3] = vec4[](vec4(-3.5, 13.0, 2.5, 3.0), vec4(3.5, 14.0, 2.5, 7.0), vec4(0.0, 20.0, 3.2, 11.0));

float jround(float x) {
	return floor(x + 0.5);
}

// the wisp's heat ramp (hot first): C6 C6 C5 C5 C4 C4 C3 C3 C3
vec3 heat(int i) {
	return pal[i <= 1 ? 6 : (i <= 3 ? 5 : (i <= 5 ? 4 : 3))].rgb;
}

int tail(vec2 cell) {
	float F1 = max(1.0, jround(9.0 * period));
	float F2 = max(1.0, jround(4.0 * period));
	for (int li = 3; li >= 0; li--) {
		vec3 L = LAYERS[li];
		for (int j = 2; j >= 0; j--) {
			vec4 tl = TAILS[j];
			float n = tl.w;
			float hh = (tl.y + 0.25 * tl.y * js_lnoise(t, period, 9.0, n, 5.0)) * (1.0 + stretch);
			float sw = js_lnoise(t, period, 6.0, n, 40.0) * 1.5 + lean * hh * 0.9;
			if (hh < 1.0) {
				continue;
			}
			float x = X + tl.x;
			float y = Y - 2.0;
			float H = hh * L.y;
			float r = jround(y) - cell.y;
			if (r < 0.0 || r > H) {
				continue;
			}
			float u = r / max(1.0, H);
			float half_ = tl.z * L.x * pow(1.0 - u, 0.85) * min(1.0, (r + 1.5) / 3.5) + js_lnoise(t, period, F1, r * 0.45, n) * 0.5;
			if (half_ < 0.3) {
				continue;
			}
			float cx = x + sw * u * u * L.y + js_lnoise(t, period, F2, r * 0.2, n + 7.0) * u * 1.1;
			if (cell.x >= jround(cx - half_) && cell.x <= jround(cx + half_)) {
				return int(L.z + 0.5);
			}
		}
	}
	return -1;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec3 c = vec3(-1.0);
	// the face, over the head
	float rx = jround(X);
	float ry = jround(Y);
	for (int s = -1; s <= 1; s += 2) {
		float ex = rx + float(s) * 2.0 - (s > 0 ? 0.0 : 1.0) + look;
		float ey = ry - 1.0;
		if (blink) {
			if (cell.y == ey + 1.0 && (cell.x == ex || cell.x == ex + 1.0)) {
				c = pal[1].rgb;
			}
		} else if (cell.y >= ey && cell.y <= ey + 2.0 && (cell.x == ex || cell.x == ex + 1.0)) {
			c = (cell.y == ey && cell.x == ex + (look > 0.0 ? 1.0 : 0.0)) ? pal[6].rgb : pal[1].rgb;
		}
	}
	if (cell.y == ry + 3.0 && (cell.x == rx + look || cell.x == rx - 1.0 + look)) {
		c = pal[2].rgb;
	}
	if (c.r < 0.0) {
		// the head
		float R = 7.5;
		vec2 p = cell + 0.5 - vec2(X, Y);
		if (cell.x >= floor(X - R - 2.0) && cell.x <= ceil(X + R + 2.0) && cell.y >= floor(Y - R - 2.0) && cell.y <= ceil(Y + R + 2.0)) {
			float ang = atan(p.y, p.x);
			float rr = R + 0.7 * js_lnoise(t, period, 16.0, ang * 1.6 + 10.0, 3.0) + (p.y > 0.0 ? -0.6 : 0.0);
			float d = length(p) / rr;
			if (d <= 1.0) {
				c = d < 0.42 ? pal[6].rgb : (d < 0.68 ? pal[5].rgb : (d < 0.88 ? pal[4].rgb : pal[3].rgb));
			}
		}
	}
	if (c.r < 0.0) {
		int h = tail(cell);
		if (h < 0) {
			discard;
		}
		c = heat(h);
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
