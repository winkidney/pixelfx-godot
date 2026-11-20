// crit-number's CRIT tag (src/fx/ui/crit-number.js tag()): a dark plate leaning `lean` px over its height, a lit top
// edge; white all over as it bursts. rc (x, y, w, h) keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform bool on = false;
uniform vec4 rc = vec4(0.0);
uniform float lean = 3.0;
uniform bool white = false;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float x = rc.x;
	float y = rc.y;
	float w = rc.z;
	float h = rc.w;
	if (!on || cell.x < floor(x - 1.0) || cell.x > ceil(x + w + lean + 1.0) || cell.y < floor(y - 1.0) || cell.y > ceil(y + h + 1.0)) {
		discard;
	}
	vec2 pc = cell + 0.5;
	float lx = pc.x - x - lean * ((y + h - pc.y) / h);
	if (pc.y < y || pc.y > y + h || lx < 0.0 || lx > w) {
		discard;
	}
	vec3 c;
	if (lx < 1.0 || lx > w - 1.0 || pc.y < y + 1.0 || pc.y > y + h - 1.0) {
		c = white ? vec3(1.0) : C[0].rgb;
	} else {
		c = white ? vec3(1.0) : pc.y < y + 2.0 ? C[4].rgb : pc.y < y + h * 0.55 ? C[3].rgb : C[2].rgb;
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
