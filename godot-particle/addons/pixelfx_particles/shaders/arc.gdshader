// A crescent smear swept along a tilted ellipse (sword slashes, claw swipes, sweeps, spin slashes), after the
// original's crescent(): it runs from angle `tail` to angle `head` (degrees: 0 right, 90 down, either direction) on
// an ellipse of `radius` px squashed to `squash` in y and turned by `tilt` degrees. Thickest just behind the leading
// edge (sin(pi * v^peak)^0.6, v from tail 0 to head 1), `thickness` px inward from the rim; colour steps run down
// `ramp` (brightest first, `steps` colours) from the rim inward, darker with `age` (0..1) and toward the tail; the
// tail dissolves through the dither. Key head / tail / thickness / age to sweep it.
shader_type canvas_item;

#include "pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform float radius = 20.0;
uniform float squash = 1.0;
uniform float tilt = 0.0;
uniform float head = 90.0;
uniform float tail = -90.0;
uniform float thickness = 4.0;
uniform float peak = 2.2;
uniform float age = 0.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform float steps = 7.0;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float a = radians(-tilt);
	p = vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a));
	vec2 q = vec2(p.x, p.y / max(squash, 0.001));
	float r = length(q);
	if (r > radius + 0.5 || r < radius - thickness - 1.0) {
		discard;
	}
	float ang = degrees(atan(q.y, q.x));
	float span = head - tail;
	float dir = span >= 0.0 ? 1.0 : -1.0;
	float u = mod((ang - tail) * dir, 360.0);
	if (abs(span) < 1.0 || u > abs(span)) {
		discard;
	}
	float v = u / abs(span);
	float w = thickness * pow(sin(3.14159265 * pow(v, peak)), 0.6);
	if (w < 0.35) {
		discard;
	}
	float k = (radius - r) / w;
	if (k < 0.0 || k > 1.0) {
		discard;
	}
	float n = max(steps, 1.0);
	float ci = (k < 0.22 && age < 0.5) ? 0.0 : floor(k * (n - 1.0) * 0.75 + age * 2.4 - v * 0.8 + 0.4 + 0.5);
	ci = clamp(ci, 0.0, n - 1.0);
	vec4 c = texture(ramp, vec2((ci + 0.5) / n, 0.5));
	c.a *= min(1.0, v / 0.4) * alpha;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
