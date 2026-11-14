// The original's sparkle(p, x, y, arm, c, tip): a cross of `arm` px arms (c, tip beyond 0.6 of it), diagonal
// pixels once it's 3 and 6 long, a white heart. Centred on the rect (key "arm"). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(41.0);
uniform float arm = 0.0;
uniform vec4 c : source_color = vec4(1.0);
uniform vec4 tip : source_color = vec4(1.0);
uniform vec4 heart : source_color = vec4(1.0);

void fragment() {
	vec2 p = floor((UV - 0.5) * size + 0.001);
	float n = floor(arm + 0.5);
	if (n < 1.0) {
		discard;
	}
	vec2 a = abs(p);
	vec4 col = vec4(0.0);
	if (a.x == 0.0 && a.y == 0.0) {
		col = heart;
	} else if ((a.x == 0.0 && a.y <= n) || (a.y == 0.0 && a.x <= n)) {
		col = max(a.x, a.y) > n * 0.6 ? tip : c;
	} else if (n >= 3.0 && a.x == 1.0 && a.y == 1.0) {
		col = c;
	} else if (n >= 6.0 && a.x == 2.0 && a.y == 2.0) {
		col = tip;
	} else {
		discard;
	}
	if (pfx_pixel(col, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = col;
}
