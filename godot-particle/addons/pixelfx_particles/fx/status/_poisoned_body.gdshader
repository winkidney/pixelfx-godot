// status/poisoned's sick body, on the stand-in (the Actor, its texture padded `margin` px left and right so rows can
// sway): every row pushed sideways by the sway and the tick's wobble, its own colours sickened toward the green ramp
// by waves rolling up it; dark veins creeping out of a wound on the forearm and back (`data`: r = when a pixel of
// vein shows, 0..1, 1 for none; g = 1 the wound, 0.5 its lip); on each tick three blisters swell, shine and pop
// (b0..b2 on even ticks, b3..b5 on odd: x, y in mask space, radius). Keyed: tw. Exact colours (the original mixes).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/fx/status/_poisoned.gdshaderinc"

uniform vec4 ramp[8] : source_color;
uniform vec4 vein : source_color;
uniform sampler2D data : filter_nearest;
uniform float margin = 2.0;
uniform vec3 b0;
uniform vec3 b1;
uniform vec3 b2;
uniform vec3 b3;
uniform vec3 b4;
uniform vec3 b5;

// a blister centred on c (mask space, a pixel corner) of radius r at pixel centre q: 0 none, 1 rim, 2 body, 3 shine
int blister(vec3 b, vec2 q, float gr) {
	vec2 c = vec2(b.x + p_off(b.y), b.y);
	float r = b.z * gr;
	int k = 0;
	if (length(q - c) <= r + 0.6) {
		k = 1;
	}
	if (r >= 0.6 && length(q - (c - 0.2)) <= r) {
		k = 2;
	}
	if (r > 0.8 && floor(q) == floor(c - vec2(0.5, 0.8))) {
		k = 3;
	}
	return k;
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 P = ivec2(floor(UV * vec2(sz)));
	float my = float(P.y);
	float mx = float(P.x) - margin;
	int sx = P.x - int(p_off(my));
	vec4 c = vec4(0.0);
	if (sx >= 0 && sx < sz.x) {
		vec4 s = texelFetch(TEXTURE, ivec2(sx, P.y), 0);
		if (s.a >= 0.5) {
			float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
			float wave = 0.5 + 0.5 * sin(TAU * (my / PH * 1.6 + tw * 2.0));
			vec3 sick = ramp[clamp(1 + int(floor(l * 6.2 + 0.5)), 1, 7)].rgb;
			float k = 0.22 + 0.4 * wave * wave;
			vec3 to = (wave > 0.85 && l > 0.4) ? mix(sick, ramp[6].rgb, 0.3) : sick;
			c = vec4(mix(s.rgb, to, k), 1.0);
			// veins and the wound live in mask space, carried with the row
			vec4 d = texelFetch(data, ivec2(sx - int(margin), P.y), 0);
			float t = tw * PD;
			float grow = smoothstep(0.0, PD * 0.55, t) * (1.0 - smoothstep(PD * 0.62, PD, t)) * 1.15;
			if (d.r < 0.99 && d.r < grow) {
				c.rgb = d.r > grow - 0.12 ? ramp[2].rgb : vein.rgb;
			}
			if (d.g > 0.75) {
				c.rgb = ramp[6].rgb;
			} else if (d.g > 0.25) {
				c.rgb = ramp[3].rgb;
			}
		}
	}
	// the blisters of this tick, swelling for 0.16 s, popping at 0.38 s
	float ph = p_ph();
	if (ph <= 0.38) {
		bool odd = mod(floor(tw * 2.0), 2.0) > 0.5;
		float gr = clamp(ph / 0.16, 0.0, 1.0);
		vec2 q = vec2(mx, my) + 0.5;
		int k = max(max(blister(odd ? b3 : b0, q, gr), blister(odd ? b4 : b1, q, gr)), blister(odd ? b5 : b2, q, gr));
		if (k == 1) {
			c = vec4(ramp[3].rgb, 1.0);
		} else if (k == 2) {
			c = vec4(ramp[5].rgb, 1.0);
		} else if (k == 3) {
			c = vec4(1.0);
		}
	}
	if (c.a < 0.5) {
		discard;
	}
	COLOR = c;
}
