// The smite's hammer of light (holy/smite, colour layer): a heavy blunt beam falling down x = 0, its wider white-hot
// head and the speed lines over it (mode 0), or the thread it leaves from the sky to the mark (mode 1). Coordinates
// are px from the effect's origin; key the ends.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(32.0);
uniform vec2 center = vec2(0.0);
uniform float mode = 0.0;
// the body: a capsule from y0 to y1, `width` px across
uniform float y0 = 0.0;
uniform float y1 = 0.0;
uniform float width = 9.0;
uniform float body_on = 0.0;
// the head
uniform float hy0 = 0.0;
uniform float hy1 = 0.0;
uniform float head_w = 13.0;
uniform float head_on = 0.0;
// speed lines from ly0 down to ly1, alpha up to lk
uniform float ly0 = 0.0;
uniform float ly1 = 0.0;
uniform float lk = 0.0;
uniform float white = 0.0;
// the thread's fade (1 - ai * 0.5)
uniform float fade = 1.0;
uniform vec4 c4 : source_color;
uniform vec4 c5 : source_color;
uniform vec4 c6 : source_color;

// a capsule x = 0, ya..yb, radius r: v (0 on the axis, 1 at the rim), u along; false when outside
bool capsule(vec2 p, float ya, float yb, float r, out float u, out float v) {
	float L = yb - ya;
	u = clamp((p.y - ya) / max(L, 1e-4), 0.0, 1.0);
	vec2 q = vec2(0.0, ya + L * u) - p;
	float d2 = dot(q, q);
	v = sqrt(d2) / max(r, 1e-4);
	return d2 <= r * r;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	vec2 cell = floor(p);
	vec4 c = vec4(0.0);
	float u;
	float v;
	if (mode < 0.5) {
		if (lk > 0.0 && ly1 > ly0) {
			for (int i = 0; i < 4; i++) {
				float dx = i == 0 ? -5.0 : i == 1 ? -2.0 : i == 2 ? 2.0 : 5.0;
				float k = i == 0 ? 0.6 : i == 1 ? 0.9 : i == 2 ? 0.8 : 0.5;
				if (cell.x == dx && cell.y >= floor(ly0) && cell.y <= floor(ly1)) {
					float uu = (cell.y - floor(ly0)) / max(floor(ly1) - floor(ly0), 1.0);
					vec4 cc = uu > 0.7 ? c6 : c4;
					if (uu * k * lk >= pfx_threshold(FRAGCOORD.xy) && uu * k * lk > 0.0) {
						c = vec4(cc.rgb, 1.0);
					}
				}
			}
		}
		if (body_on > 0.5 && capsule(p, y0, y1, width / 2.0, u, v)) {
			c = white > 0.5 || v < 0.35 ? vec4(1.0) : v < 0.7 ? c6 : c5;
		}
		if (head_on > 0.5 && capsule(p, hy0, hy1, head_w / 2.0, u, v)) {
			c = v < 0.6 || white > 0.5 ? vec4(1.0) : c6;
		}
	} else if (body_on > 0.5 && capsule(p, y0, y1, width / 2.0, u, v)) {
		c = v < 0.5 ? vec4(1.0) : c5;
		c.a = (0.3 + 0.7 * u) * fade;
	}
	if (c.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
