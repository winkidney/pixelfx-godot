// ice/freeze's frozen character, laid over the stand-in pixel for pixel (the rect is the stand-in plus a `margin`
// px border): each pixel turns to its ice colour when the frost reaches it (`when`: the time in r + g / 255 of 8 s,
// b = 1 where the body is; `ice`: its colour), flashing white then pale as it does; rime feathers stand out from the
// outline after it (`feathers`: r, g its time, b = 1, a = 1 for a white tip); after `burst` the ice runs off from the
// top down to row `thaw` (the stand-in shows again above it, the thawing line pale). Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(30.0, 44.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D when : filter_nearest;
uniform sampler2D ice : filter_nearest;
uniform sampler2D feathers : filter_nearest;
uniform float margin = 3.0;
uniform float t = 0.0;
uniform float burst = 2.52;
uniform float thaw = -1.0;
uniform vec4 c6 : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform float alpha = 1.0;

float time_of(vec4 v) {
	return (floor(v.r * 255.0 + 0.5) + v.g) * 8.0 / 255.0;
}

void fragment() {
	vec4 tint = COLOR;
	ivec2 P = ivec2(floor(UV * size));
	float y = float(P.y) - margin;
	vec4 c = vec4(0.0);
	bool hit = false;
	vec4 w = texelFetch(when, P, 0);
	if (w.b > 0.5) {
		float age = t - time_of(w);
		if (age >= 0.0 && !(y < thaw)) {
			hit = true;
			c = (y < thaw + 1.2 && t >= burst) ? c7 : (age < 0.016 ? vec4(1.0) : (age < 0.045 ? c6 : texelFetch(ice, P, 0)));
		}
	}
	vec4 f = texelFetch(feathers, P, 0);
	if (t < burst && f.b > 0.5 && t >= time_of(f)) {
		hit = true;
		c = f.a > 0.75 ? vec4(1.0) : c6;
	}
	if (!hit) {
		discard;
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
