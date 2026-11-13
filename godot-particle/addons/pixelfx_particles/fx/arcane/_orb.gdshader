// The arcane orb (after the original's orb()): smoky violet glass thickening to its rim, two bright swirl arms with
// a lit edge and two faint ones turning round a pulsing white heart, a double rim, a highlight arc and spot top left
// and a glint bottom right. `t` runs 0..1 over the loop. Centred on the rect. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(44.0);
uniform float t = 0.0;
uniform float rad = 17.0;
uniform vec4 c1 : source_color = vec4(0.17, 0.07, 0.32, 1.0);
uniform vec4 c2 : source_color = vec4(0.28, 0.11, 0.53, 1.0);
uniform vec4 c4 : source_color = vec4(0.6, 0.28, 0.93, 1.0);
uniform vec4 c5 : source_color = vec4(0.78, 0.52, 1.0, 1.0);
uniform vec4 c6 : source_color = vec4(0.93, 0.78, 1.0, 1.0);
uniform vec4 white : source_color = vec4(1.0);

float wrapd(float a) {
	return abs(mod(a + PI, TAU) - PI);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float r = length(p);
	float th = atan(p.y, p.x);
	vec4 c = vec4(0.0);
	vec4 glass = vec4(0.0);
	// the glass: translucent (the original blends it), thicker towards the rim
	if (r <= rad) {
		float d = r / rad;
		glass = vec4((d > 0.82 ? c2 : c1).rgb, 0.32 + 0.5 * d * d);
	}
	// the swirl: two bright arms (each with a lit edge trailing it) and two faint ones
	float u = r / (rad * 0.92);
	if (u >= 0.08 && u <= 0.85) {
		float fade = u < 0.6 ? 1.0 : 1.0 - (u - 0.6) / 0.25;
		float w = 0.62 / max(r, 0.5);
		for (int k = 0; k < 2; k++) {
			float a = t * TAU * 2.0 + float(k) * PI + u * 3.4;
			if (wrapd(th - (a - 0.16)) < w) {
				c = vec4((u < 0.4 ? c6 : c5).rgb, fade);
			}
			if (wrapd(th - a) < w) {
				c = vec4((u < 0.3 ? white : u < 0.55 ? c6 : c5).rgb, fade);
			}
		}
		for (int k = 0; k < 2; k++) {
			float a = t * TAU * 2.0 + PI * 0.5 + float(k) * PI + u * 3.4;
			if (wrapd(th - a) < w) {
				c = vec4(c4.rgb, fade * 0.8);
			}
		}
	}
	// the heart
	float pulse = 0.85 + 0.15 * sin(t * TAU * 3.0);
	if (r <= 3.6 * pulse + 1.0) {
		c = r <= 1.7 * pulse ? white : r <= 2.8 * pulse ? c6 : c5;
	}
	// the rim: a bright line just inside a dark one
	if (r <= rad + 0.4 && r >= rad - 0.6) {
		c = c5;
	}
	if (r <= rad + 1.3 && r >= rad + 0.3) {
		c = vec4(c2.rgb, 0.8);
	}
	// the highlight arc and spot top left, a glint bottom right
	float ang = th < 0.0 ? th + TAU : th;
	if (abs(r - (rad - 2.4)) < 0.55 && ang > 3.5 && ang < 4.7) {
		c = ang > 3.85 && ang < 4.35 ? white : c6;
	}
	if (length(p - vec2(-rad * 0.42, -rad * 0.5)) <= 1.3) {
		c = white;
	}
	if (floor(p) == floor(vec2(rad * 0.52, rad * 0.55))) {
		c = c6;
	}
	if (c.a > 0.0 && !pfx_pixel(c, FRAGCOORD.xy)) {
		COLOR = c;
	} else if (glass.a > 0.0) {
		COLOR = vec4(pfx_snap(glass.rgb), floor(glass.a * 8.0 + 0.5) / 8.0);
	} else {
		discard;
	}
}
