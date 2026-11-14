// spawn/egg-hatch's pieces of shell, tumbling (the original's per-piece map of cells, turned by the piece's angle):
// their lit outsides, their broken edges hot at first, crumbling away pixel by pixel as their life runs out (the
// original's hash). Colour layer.
//   head 1 (map row, ..); rows 0 (x, y, on, angle), 1 (life left, hot, id, reach)
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_track.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform sampler2D maps : filter_nearest;
uniform vec4 shell[8] : source_color;
uniform vec4 hot_c : source_color = vec4(1.0);
uniform vec4 cool_c : source_color = vec4(1.0);

void vertex() {
	tk_cu = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 h1 = tk_head(1);
	vec4 r0 = tk_row(0);
	vec4 r1 = tk_row(1);
	vec2 c = tk_cell(UV);
	float r = r1.w;
	if (abs(c.x) > r || abs(c.y) > r) {
		discard;
	}
	float c2 = cos(r0.w);
	float s2 = sin(r0.w);
	int ux = int(floor(c.x * c2 + c.y * s2 + 0.5));
	int uy = int(floor(-c.x * s2 + c.y * c2 + 0.5));
	if (ux < -8 || ux > 8 || uy < -8 || uy > 8) {
		discard;
	}
	vec4 m = texelFetch(maps, ivec2(ux + 8, int(h1.x + 0.5) * 17 + uy + 8), 0);
	if (m.w < 0.5 || js_rand3(ux, uy, int(r1.z + 0.5)) >= r1.x) {
		discard;
	}
	COLOR = vec4(m.y > 0.5 ? (r1.y > 0.5 ? hot_c.rgb : cool_c.rgb) : shell[int(m.x + 0.5)].rgb, 1.0);
}
