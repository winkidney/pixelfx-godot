// Banks of mist, fog, haze, cloud: a seamless noise texture scrolled across a rect, thick where a vertical profile
// says, in two tones with a lit crest. Key `t` 0 -> 1 over the loop; `drift` (texture repeats per loop, whole numbers
// loop seamlessly) moves it. Coordinates are px from the effect's origin (`center` is the rect's middle, set by
// build.gd shape()). Colour layer, usually translucent (soft).
shader_type canvas_item;

#include "pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform vec2 drift = vec2(1.0, 0.0);
// px per noise-texture repeat, across and down
uniform vec2 period = vec2(256.0, 64.0);
// density profile in y (px from the origin): rises from y0 to y1, falls from y2 to y3
uniform vec4 profile = vec4(-22.0, -4.0, 7.0, 10.0);
uniform float density = 0.62;
uniform float contrast = 2.0;
uniform float threshold = 0.28;
uniform float body = 0.58;
uniform vec4 low : source_color = vec4(0.23, 0.33, 0.51, 1.0);
uniform vec4 high : source_color = vec4(0.34, 0.45, 0.66, 1.0);
uniform vec4 crest : source_color = vec4(0.52, 0.65, 0.84, 1.0);
uniform float alpha = 0.5;

float dens(vec2 p) {
	float prof = smoothstep(profile.x, profile.y, p.y) * (1.0 - smoothstep(profile.z, profile.w, p.y));
	vec2 uv = p / period + drift * t;
	return prof * (density + (texture(noise, uv).r - 0.5) * contrast);
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5 + center;
	float d = dens(p);
	if (d < threshold) {
		discard;
	}
	float th = pfx_threshold(FRAGCOORD.xy) * 0.06;
	vec4 c;
	if (d > threshold + 0.18 + th && dens(p - vec2(0.0, 1.0)) < threshold + 0.15) {
		c = vec4(crest.rgb, alpha);
	} else {
		c = vec4((d > body + th ? high : low).rgb, clamp((d - threshold) * 1.6, 0.0, 1.0) * alpha);
	}
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
