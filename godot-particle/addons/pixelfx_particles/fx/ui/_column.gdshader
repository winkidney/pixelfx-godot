// level-up's pillar (src/fx/ui/level-up.js column()): one white-hot frame as it shoots up, then light standing on the
// hero: two flowing walls (dashes running up them), a white core, strands streaming up in dashes, every dot faded in
// at its foot and dithered as the original's. Its clock, top, bottom and width keyed every frame, with each row's
// wobble (the original's noise, worked out in doubles) and the strands' phases; the strands are the original's
// (rand-rolled) constants.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform bool on = false;
uniform bool hot = false;
uniform float t = 0.0;
uniform float age = 0.0;
uniform float top = 0.0;
uniform float bot = 0.0;
uniform float W = 0.0;
uniform bool held = true;
// strands: x, speed, period, duty | phase, level, end
uniform vec4 sa[9];
uniform vec4 sb[9];
// per row (y + 100): the wall's half-width; bit 0: the core's left dot is white, bit 1: its right dot draws; bits 2
// and 3: the left and right walls' dash is running (in doubles: it lands on its threshold now and then)
uniform float wrow[100];
uniform float nrow[100];
// per strand, its dash phase at y = 0 this frame
uniform float soff[9];
// per row, each wall's three dot cells (floor of xw, xw + s, xw - s; each + 64, 7 bits apiece), worked out in doubles
uniform float wcell[200];

const float TOP = 100.0;

float fract_(float x) {
	return x - floor(x);
}

// a dot of colour c at alpha a, at x on this row: does it draw on cell X
bool dot_(float X, float x, float a, float th) {
	return floor(x) == X && (a >= 1.0 || a > th);
}

// a dot on cell x (already whole)
bool dotc(float X, float x, float a, float th) {
	return x == X && (a >= 1.0 || a > th);
}

float wall(int row, int side, int which) {
	int v = int(wcell[side * 100 + row] + 0.5);
	return float((v >> (7 * which)) & 127) - 64.0;
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float X = cell.x;
	float y = cell.y;
	float th = pfx_threshold(FRAGCOORD.xy);
	if (!on) {
		discard;
	}
	vec3 c = vec3(0.0);
	bool hit = false;
	if (hot) {
		if (y < floor(top) || y >= bot) {
			discard;
		}
		float wr = W * 0.55 * (1.0 - 0.3 * (-y / TOP));
		if (X < floor(-wr) || X > ceil(wr)) {
			discard;
		}
		float a = clamp((y + TOP) / 20.0, 0.0, 1.0) * 1.5;
		if (!(a >= 1.0 || a > th)) {
			discard;
		}
		hit = true;
		c = abs(X + 0.5) < wr - 1.5 ? vec3(1.0) : C[6].rgb;
	} else {
		if (y < ceil(top) || y >= ceil(bot)) {
			discard;
		}
		float h = -y / TOP;
		float fade = clamp((y + TOP) / 16.0, 0.0, 1.0) * (held ? 1.0 : clamp((bot - y) / 10.0, 0.0, 1.0));
		bool head = y - top < 3.0 && age < 0.16;
		int row = clamp(int(y) + 100, 0, 99);
		float wr = wrow[row];
		int nb = int(nrow[row] + 0.5);
		// the strands, last drawn first
		for (int j = 8; j >= 0 && !hit; j--) {
			if (h > sb[j].z) {
				continue;
			}
			float ph = fract_(y / sa[j].z + soff[j]);
			if (ph > sa[j].w) {
				continue;
			}
			if (floor(sa[j].x * wr) == X) {
				float u = ph / sa[j].w;
				int lvl = int(sb[j].y + 0.5);
				hit = true;
				c = (head || u < 0.2) ? vec3(1.0) : u < 0.65 ? C[7 - lvl].rgb : C[6 - lvl].rgb;
			}
		}
		if (!hit && (nb & 2) != 0 && dot_(X, 1.0, fade * 1.2, th)) {
			hit = true;
			c = C[6].rgb;
		}
		if (!hit && dot_(X, -1.0, fade * 1.3, th)) {
			hit = true;
			c = (nb & 1) != 0 ? vec3(1.0) : C[6].rgb;
		}
		if (!hit && dot_(X, 0.0, fade * 1.6, th)) {
			hit = true;
			c = vec3(1.0);
		}
		for (int k = 1; k >= 0 && !hit; k--) {
			float s = k == 0 ? -1.0 : 1.0;
			bool run = (nb & (4 << k)) != 0;
			if (run && dotc(X, wall(row, k, 2), fade * 1.2, th)) {
				hit = true;
				c = C[5].rgb;
			} else if (dotc(X, wall(row, k, 1), fade * (run ? 0.5 : 0.25), th)) {
				hit = true;
				c = C[4].rgb;
			} else if (dotc(X, wall(row, k, 0), fade * 1.4, th)) {
				hit = true;
				c = head ? vec3(1.0) : run ? C[6].rgb : C[5].rgb;
			}
		}
	}
	if (!hit) {
		discard;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
