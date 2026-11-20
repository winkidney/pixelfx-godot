// quest-complete's gold seal (src/fx/ui/quest-complete.js seal()): a scalloped rim, a lit face with an inner ring;
// white as it stamps and pops. Centre, squash (sx, sy) and white keyed every frame (the check mark is particles).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 G[8] : source_color;
uniform bool on = false;
uniform vec2 at = vec2(0.0);
uniform vec2 sc = vec2(1.0);
uniform bool white = false;

const float r = 11.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float M = r * 1.25 + 2.0;
	if (!on || cell.x < floor(at.x - M * sc.x) || cell.x > ceil(at.x + M * sc.x) || cell.y < floor(at.y - M * sc.y) || cell.y > ceil(at.y + M * sc.y)) {
		discard;
	}
	vec2 pc = cell + 0.5;
	float dx = (pc.x - at.x) / sc.x;
	float dy = (pc.y - at.y) / sc.y;
	float d = length(vec2(dx, dy));
	float an = atan(dy, dx);
	float edge = r * (1.0 + 0.09 * cos(an * 14.0));
	if (d > edge) {
		discard;
	}
	vec3 c;
	float l = -(dx * 0.6 + dy * 0.8) / r;
	if (white) {
		c = edge - d < 1.0 ? G[5].rgb : vec3(1.0);
	} else if (edge - d < 1.0) {
		c = G[0].rgb;
	} else if (edge - d < 3.0) {
		c = l > 0.3 ? G[6].rgb : l > -0.3 ? G[5].rgb : G[3].rgb;
	} else if (abs(d - r * 0.66) < 0.5) {
		c = l > 0.0 ? G[3].rgb : G[2].rgb;
	} else {
		c = l > 0.45 ? G[7].rgb : l > 0.1 ? G[6].rgb : l > -0.35 ? G[5].rgb : G[4].rgb;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
