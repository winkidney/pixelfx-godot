// Speed lines (uppercut.js, thrust.js), colour layer: up to 16 dotted lines, each a run of whole pixels trailing back
// from a head that moves: la[i] = (x0, y0, vx, vy) where the head starts (px from the effect's origin) and how fast it
// goes, lb[i] = (born, life, length, shrink). At effect time `q` (keyed) a line is k = (q - born) / life through its
// life; its pixels run d = 0, 1, 2 ... back from the head while d < length (1 - shrink k): white for the first 3,
// then c1 up to f1 of its length, then c2; dithered by (1 - d / length) (1 - k).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 la[16];
uniform vec4 lb[16];
uniform float count = 0.0;
uniform float q = 0.0;
uniform float f1 = 0.5;
uniform vec4 white : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 cell = floor((UV - 0.5) * size) + center;
	vec4 c = vec4(0.0);
	for (int i = 0; i < 16; i++) {
		if (float(i) >= count) {
			break;
		}
		vec4 b = lb[i];
		float age = q - b.x;
		if (age < 0.0 || age >= b.y) {
			continue;
		}
		float k = age / b.y;
		vec2 v = la[i].zw;
		vec2 head = la[i].xy + v * age;
		vec2 back = -normalize(v);
		float drawn = b.z * (1.0 - b.w * k);
		float d0 = floor(dot(cell + 0.5 - head, back));
		for (int j = -1; j <= 2; j++) {
			float d = d0 + float(j);
			if (d < 0.0 || d >= drawn) {
				continue;
			}
			if (floor(head + back * d) == cell) {
				vec4 cc = d < 3.0 ? white : d < b.z * f1 ? c1 : c2;
				cc.a = (1.0 - d / b.z) * (1.0 - k);
				c = cc;
			}
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
