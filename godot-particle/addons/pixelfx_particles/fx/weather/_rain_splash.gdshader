// A raindrop landing (rain.js layer()): _lib.js crown() on the floor (a crown for a few frames, a flat dash that
// spreads and breaks in two, a droplet or two arcing up and back) or rain.js rings() in a puddle (a bright point,
// then two short dashes sliding apart, twice). Placed by _rain.gdshader (layers 4, 5); the drop's own place is
// worked out again here from its slot and drop (COLOR.yz) so the pixels land on the original's whole cells.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_rain.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/weather/_wx_draw.gdshaderinc"

uniform int layer = 4;
uniform vec4 C[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);

void fragment() {
	int L = layer - 2;
	int sd = seed * 11 + L;
	int i = int(pc.y + 0.5);
	int jp = int(pc.z + 0.5);
	vec2 EN = L == 3 ? vec2(2.0, 6.5) : vec2(0.0, 1.4);
	float z = EN.x + rand4(sd, i, jp, 1) * (EN.y - EN.x);
	float xp = -166.0 + rand4(sd, i, jp, 2) * 332.0;
	vec2 A = floor(vec2(xp, z)) + wx_cell(UV);
	float age = cu.z;
	float size = cu.w;
	int pl = int(floor(pc.x + 0.5));
	float X = floor(xp + 0.5);
	vec4 c = vec4(0.0);
	if (pl >= 0) {
		vec3 P = pool(pl);
		if (A.y == P.z) {
			for (int r = 1; r >= 0 && c.a <= 0.0; r--) {
				float a = age - float(r) * 0.16;
				float u = a / 0.5;
				if (u <= 0.0 || u >= 1.0) continue;
				float w = floor(1.0 + 7.0 * sqrt(u) + 0.5);
				for (int s = -1; s <= 1; s += 2) {
					for (int dd = 0; dd < (u < 0.6 ? 2 : 1); dd++) {
						float px = X + float(s) * (w - float(dd));
						if (px > P.x && px < P.y && A.x == px) c = u < 0.4 && r == 0 ? C[6] : C[5];
					}
				}
			}
			if (c.a <= 0.0 && age < 0.05 && A.x == X) c = C[7];
		}
	} else {
		float Lc = 0.22 + 0.14 * size;
		float u = age / Lc;
		float Z = floor(z + 0.5);
		if (u < 1.0) {
			uint hh = hash4(sd, i, jp, 4);
			uint Ah = (hh >> 16u) * 15625u;
			int Hn = int((Ah >> 10u) + ((((Ah & 1023u) << 16u) + (hh & 65535u) * 15625u) >> 26u));
			int nd = size > 0.5 ? 2 : 1;
			for (int d = 1; d >= 0 && c.a <= 0.0; d--) {
				if (d >= nd) continue;
				float vx = (rand3(Hn, d, 1) - 0.5) * 2.0 * (20.0 + 30.0 * size);
				float vy = -(50.0 + rand3(Hn, d, 2) * 60.0 * (0.4 + size));
				float y = Z - 1.0 + vy * age + 475.0 * age * age;
				if (y < Z - 0.5 && age < 0.3 && floor(vec2(xp + vx * age, y)) == A) c = age < 0.1 ? white : C[6];
			}
			if (c.a <= 0.0 && u > 0.15 && A.y == Z) {
				float w = floor(1.0 + (1.5 + 3.5 * size) * sqrt(u) + 0.5);
				float gap = u > 0.55 ? max(0.0, w - 2.0) : -1.0;
				float d = A.x - X;
				if (abs(d) <= w && abs(d) > gap) c = abs(d) >= w - 1.0 && u < 0.6 ? C[6] : C[4];
			}
			if (c.a <= 0.0 && age < 0.1) {
				float up = age < 0.033 ? 1.0 : age < 0.067 ? 2.0 : 2.0 + (size > 0.5 ? 1.0 : 0.0);
				float top = min(up, size > 0.5 ? 3.0 : 1.0);
				float d = abs(A.x - X);
				if (d >= 1.0 && d <= top && A.y == Z - 1.0 - (d > 1.0 ? d - 1.0 : 0.0)) c = d == 1.0 ? C[6] : C[4];
				else if (A.x == X && A.y == Z - 1.0) c = age < 0.05 ? white : C[6];
			}
		}
	}
	if (c.a <= 0.0 || pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
