// slime's puddle: a low dome of goo R px either side of the origin, hp px tall, lit along its top with glints
// sliding over it (the original's loop noise), darker where it meets the floor, a dark lip at its ends. Key R, hp
// and t (the effect's seconds). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/critters/_noise.gdshaderinc"

uniform vec2 size = vec2(80.0, 8.0);
uniform vec2 center = vec2(0.0);
uniform float t = 0.0;
uniform float period = 1.8;
uniform float R = 18.0;
uniform float hp = 2.0;
uniform vec4 pal[7] : source_color;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float x = cell.x;
	float y = cell.y;
	if (x < floor(-R) || x > ceil(R)) {
		discard;
	}
	float d = abs(x + 0.5) / R;
	if (d > 1.0) {
		discard;
	}
	float top = -1.0 - floor(sqrt(1.0 - d * d) * hp + 0.5);
	vec3 c;
	if (y == top - 1.0 && d > 0.96) {
		c = pal[1].rgb;
	} else if (y < top || y > 0.0) {
		discard;
	} else {
		c = y == top ? pal[5].rgb : (y == 0.0 ? pal[2].rgb : pal[4].rgb);
		if (d > 0.88) {
			c = y == top ? pal[4].rgb : pal[3].rgb;
		}
		if (y == top && d < 0.88) {
			float n = js_lnoise(t, period, 7.0, x * 0.18, 3.0) + js_lnoise(t, period, 4.0, x * 0.07, 4.0) * 0.6;
			if (n > 0.55) {
				c = pal[6].rgb;
			}
		} else if (y == top + 1.0 && d < 0.8 && js_lnoise(t, period, 3.0, x * 0.12, 5.0) > 0.3) {
			c = pal[5].rgb;
		}
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
