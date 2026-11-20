// The pickups' big lights (build/fx/pickups/_pickups.gd glows()): up to 12 of the original's p.glow, p.glowRing,
// pool() and p.glowLine over the whole canvas, each added as the original's light buffer adds it. Per light j:
//   gl[j]: x, y, r, k (a glow; a ring's radius R; a pool's rx; a line's start and, in gx, its end)
//   gx[j]: type (-1 none, 0 glow, 1 ring, 2 pool, 3 line), ring width / pool ry / line end x, line end y / pool's
//   first row
//   gc[j]: its colour
// gl and gx are keyed every frame. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/pickups/_pk.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 gl[12];
uniform vec4 gx[12];
uniform vec4 gc[12] : source_color;
uniform int count = 0;
uniform vec4 canvas = vec4(-1e4, -1e4, 2e4, 2e4);
uniform float strength = 1.0;

void fragment() {
	vec2 pc = floor(center + (UV - 0.5) * size) + 0.5;
	float e = lt_edge(pc, canvas) * strength;
	vec3 l = vec3(0.0);
	for (int j = 0; j < 12; j++) {
		if (j >= count) {
			break;
		}
		int tp = int(gx[j].x + 0.5 * sign(gx[j].x));
		vec4 g = gl[j];
		if (tp == 0) {
			l += lt_glow(pc, g.xy, g.z, gc[j].rgb, g.w * e);
		} else if (tp == 1) {
			l += lt_glow_ring(pc, g.xy, g.z, gx[j].y, gc[j].rgb, g.w * e);
		} else if (tp == 2) {
			// gx.z: the first row the original's box reaches (light thrown only in front of the item)
			if (pc.y < gx[j].z) {
				continue;
			}
			l += lt_pool(pc, g.xy, g.z, gx[j].y, gc[j].rgb, g.w * e);
		} else if (tp == 3) {
			l += lt_glow_line(pc, g.xy, gx[j].yz, g.z, gc[j].rgb, g.w * e);
		}
	}
	COLOR = vec4(min(l, vec3(1.0)) * COLOR.a, 1.0);
}
