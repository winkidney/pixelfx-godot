// spawn/egg-hatch's egg, as the original shades it pixel by pixel (its p.shade over the egg's box): the shell in its
// own pixels (`egg`: colour step, how lit, which crack stage, `near`: how far from an open crack at each stage), rocked
// about its base by `angle`; cracks that open stage by stage, white the moment they open, then deep orange light
// flickering in the gap with their lips in shadow; light through the shell round them; after the pop the cup with its
// broken rim burning; and the opening flooding white. egg_px() gives the colour (a = 0: nothing) and the light.
uniform vec2 size = vec2(25.0, 26.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D egg : filter_nearest;
uniform sampler2D near : filter_nearest;
// shell colours by step: white, C1..C5, speckle, dark speckle
uniform vec4 shell[8] : source_color;
uniform vec4 c0 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 g0 : source_color = vec4(1.0);
uniform vec4 g1 : source_color = vec4(1.0);
uniform vec4 g2 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);
uniform float angle = 0.0;
uniform float popped = 0.0;
uniform float stage = 0.0;
uniform float glow_in = 0.0;
uniform float t = 0.0;
uniform vec3 wobbles = vec3(0.3, 0.85, 1.4);
uniform float zig_y = 11.0;
uniform float flood = 0.0;

#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

vec4 egg_at(int x, int y) {
	if (x < -8 || x > 7 || y < 0 || y > 19) {
		return vec4(-1.0);
	}
	return texelFetch(egg, ivec2(x + 8, y), 0);
}

bool has(int x, int y) {
	return egg_at(x, y).w > 0.5;
}

int zig_at(int x) {
	int i = clamp(x + 8, 0, 15);
	int m = (i) % 3;
	return int(zig_y) + (m == 0 ? 1 : m == 1 ? 0 : -1);
}

bool shell_on(int x, int y) {
	return has(x, y) && !(popped > 0.5 && y >= zig_at(x));
}

float crack_at(int x, int y) {
	vec4 e = egg_at(x, y);
	return e.w > 0.5 ? e.z : -1.0;
}

vec3 mix8(vec3 a, vec3 b, float k) {
	vec3 a8 = floor(a * 255.0 + 0.5);
	vec3 b8 = floor(b * 255.0 + 0.5);
	return floor(a8 + (b8 - a8) * k) / 255.0;
}

// colour (a = 0: nothing) of this cell (the effect's coordinates); light: colour * amount
vec4 egg_px(vec2 cell, out vec3 light) {
	light = vec3(0.0);
	float ca = cos(angle);
	float sa = sin(angle);
	vec2 p = cell + 0.5;
	int ux = int(floor(p.x * ca + p.y * sa));
	int uy = int(floor(-(-p.x * sa + p.y * ca)));
	float g = glow_in;
	int st = int(stage + 0.5);
	vec4 o = vec4(0.0);
	if (!shell_on(ux, uy)) {
		bool n = shell_on(ux + 1, uy) || shell_on(ux - 1, uy) || shell_on(ux, uy + 1) || shell_on(ux, uy - 1);
		if (n && !(popped > 0.5 && uy >= zig_at(ux) && uy <= zig_at(ux) + 1)) {
			o = c0;
		}
	} else {
		vec4 e = egg_at(ux, uy);
		vec3 ec = shell[int(e.x + 0.5)].rgb;
		float cs = e.z;
		if (popped > 0.5) {
			bool rim = uy >= zig_at(ux) - 1;
			o = vec4(rim ? (g > 0.9 ? white.rgb : g > 0.4 ? g2.rgb : g > 0.12 ? g1.rgb : c4.rgb) : ec, 1.0);
			if (rim) {
				light = g1.rgb * 0.25 * g;
			}
		} else if (cs > -0.5 && cs < float(st)) {
			float w0 = cs < 0.5 ? wobbles.x : cs < 1.5 ? wobbles.y : wobbles.z;
			bool fresh = t - w0 < 0.17;
			o = fresh ? white : js_rand3(ux, uy, int(floor(t * 20.0))) < 0.25 + 0.1 * float(st) ? g1 : g0;
			light = g1.rgb * (0.14 + 0.06 * float(st));
		} else {
			float cu = crack_at(ux, uy + 1);
			float cr = crack_at(ux + 1, uy);
			if ((cu > -0.5 && cu < float(st)) || (cr > -0.5 && cr < float(st))) {
				o = e.y > 0.3 ? c2 : c1;
			} else {
				vec4 nn = texelFetch(near, ivec2(ux + 8, uy), 0);
				float dn = st == 1 ? nn.x : st == 2 ? nn.y : st == 3 ? nn.z : 9.0;
				float k = min(1.0, g * 1.5);
				bool spk = int(e.x + 0.5) == 6;
				vec3 base = st > 0 && !spk ? mix8(ec, g0.rgb, 0.05 * float(st) * k) : ec;
				vec3 c = dn < 1.6 ? mix8(base, g1.rgb, (st >= 2 ? 0.32 : 0.2) * k) : dn < 2.7 && st >= 2 ? mix8(base, g1.rgb, 0.14 * k) : base;
				o = vec4(c, 1.0);
			}
		}
	}
	if (flood > 0.5) {
		// the opening floods with light: an ellipse round (0, -zig + 0.5)
		float oy = -zig_y + 0.5;
		float y = cell.y - floor(oy - 2.0) - 2.0;
		float x = cell.x;
		if (x >= -7.0 && x <= 7.0 && y >= -2.0 && y <= 2.0) {
			float d = length(vec2((x + 0.5) / 7.0, (y + 0.5) / 2.2));
			if (d <= 1.0 && !(g < 0.6 && d > 0.75)) {
				o = g > 1.0 ? (d < 0.7 ? white : g2) : g > 0.6 ? (d < 0.5 ? g2 : g1) : d < 0.45 ? g1 : g0;
			}
		}
	}
	return o;
}
