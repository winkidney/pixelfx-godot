// countdown's timer (src/fx/ui/countdown.js timer()): part 0, the dark socket ring (R + 4, 8 px, darker at its
// edges); part 1, the burning fuse, the lit arc from the head round to the top (white at the head, cooling along it).
// Its centre (the slam's shake), the fuse's head and fill and the flash keyed every frame. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform int part = 0;
uniform bool on = false;
uniform vec2 at = vec2(0.0);
uniform float head = 0.0;
uniform float f = 1.0;
uniform bool flash = false;

const float R = 30.0;
const float TOP = -PI / 2.0;

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	vec2 q = cell + 0.5 - at;
	float d = length(q);
	vec3 c;
	if (!on) {
		discard;
	}
	if (part == 0) {
		float r = R + 4.0;
		float r0 = r - 8.0;
		if (d > r || d < r0) {
			discard;
		}
		float v = (d - r0) / 8.0;
		c = (v < 0.13 || v > 0.87) ? C[0].rgb : C[1].rgb;
	} else {
		float r = R + 2.0;
		float w = 5.0;
		if (d > r || d < r - w) {
			discard;
		}
		float span = TOP + TAU - head;
		float ang = atan(q.y, q.x) - head;
		ang -= floor(ang / TAU) * TAU;
		if (ang > span) {
			discard;
		}
		float u = ang / span;
		float v = (d - (r - w)) / w;
		float dd = u * TAU * f;
		if (flash || dd < 0.1) {
			c = vec3(1.0);
		} else if (dd < 0.32) {
			c = v > 0.5 ? vec3(1.0) : C[6].rgb;
		} else {
			c = v > 0.75 ? C[6].rgb : v > 0.4 ? C[5].rgb : v > 0.15 ? C[4].rgb : C[3].rgb;
		}
	}
	vec4 o = vec4(c, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
