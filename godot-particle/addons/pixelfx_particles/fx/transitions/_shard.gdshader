// shatter-wipe's shards (colour layer): frame-table particles (placed on their cell by fx/pickups/_ftp.gdshader), one
// shard each, in the original's draw order for that frame (still ones first, then the falling ones farthest first).
// `data`, 4 rows a frame: row 0 (cell x, cell y, shard id, still), row 1 (phi, psi, -, present), row 2 (cx, cy, spin
// a, z). `shape`: each shard's corners about its centre (row = id; x = corner), `info`: (corners, r).
// A shard is dark glass filled row by row (_lib.js fillConvex), tumbling about an axis in its plane and turning on
// screen; its edges lit where they face the light, a bright sliver edge-on; still in the pane, a lit crack line.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_shard.gdshaderinc"

void fragment() {
	vec2 d = floor((UV - 0.5) * quad + 0.5);
	vec2 q = cu.zw + d;
	if (q.x < 0.0 || q.y < 0.0 || q.x >= TR_W || q.y >= TR_H) {
		discard;
	}
	Sh s = sh_load();
	vec3 col = vec3(-1.0);
	if (sh_fill(s, q)) {
		col = s.face;
	}
	int e = sh_edges(s, q);
	if (e >= 0) {
		col = e == 8 ? vec3(1.0) : C[e].rgb;
	}
	if (col.r < 0.0) {
		discard;
	}
	COLOR = vec4(col, 1.0);
}
