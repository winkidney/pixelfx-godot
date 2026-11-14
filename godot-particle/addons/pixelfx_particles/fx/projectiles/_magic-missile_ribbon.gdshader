// The magic missile's ribbon (projectiles/magic-missile.js): a strip trailing the orb through the last 0.32 s of
// its path (pts: x, y, the time it was there, keyed every frame), twisting as it goes: its width follows
// |sin(26 t)|, its bright face (c6 rim, c5 / c4 body as it ages) and its dark back (c4 rim, c2 body) taking turns,
// thinning to nothing and dithering out at the tail. Newer stretches over older. Coordinates are px from the origin.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 pts[48];
uniform float count = 0.0;
uniform float now = 0.0;
uniform vec4 c2 : source_color = vec4(1.0);
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);

void fragment() {
	vec2 cell = floor(UV * size) - size * 0.5 + center;
	vec2 p = cell + 0.5;
	vec4 col = vec4(0.0);
	for (int i = 1; i < 48; i++) {
		if (float(i) >= count) {
			break;
		}
		vec4 a = pts[i - 1];
		vec4 b = pts[i];
		vec2 ab = b.xy - a.xy;
		float l = max(length(ab), 1e-4);
		vec2 u = ab / l;
		vec2 n = vec2(-u.y, u.x);
		float f = dot(p - a.xy, u) / l;
		if (f < -0.5 / l || f > 1.0 + 0.5 / l) {
			continue;
		}
		f = clamp(f, 0.0, 1.0);
		float tt = a.z + (b.z - a.z) * f;
		float k = 1.0 - (now - tt) / 0.32;
		float tw = sin(tt * 26.0);
		float w = 3.2 * k * abs(tw) + 0.4;
		float s = abs(dot(p - a.xy, n));
		if (s > w + 0.5) {
			continue;
		}
		bool edge = s > w - 0.8;
		vec4 c = tw > 0.0 ? (edge ? c6 : (k > 0.6 ? c5 : c4)) : (edge ? c4 : c2);
		c.a = k > 0.35 ? 1.0 : k / 0.35;
		col = c;
	}
	if (col.a <= 0.0) {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
