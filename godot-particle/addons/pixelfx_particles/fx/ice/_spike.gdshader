// The originals' crystal(): a faceted crystal spike standing on (`x`, `base`), `h` tall, `w` wide at the base,
// leaning `lean` px at the tip, shaded in `ramp` (8 steps, dark to bright): a lit ridge, a bright left face, a darker
// right face, a white tip, a dark rim. `white` flashes it, `glint` (0..1 or -1) sweeps a highlight up it. Coordinates
// are px from the effect's origin (`center` is where the rect sits). Key h, w, lean, white, glint. Colour layer.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"

uniform vec2 size = vec2(64.0);
uniform vec2 center = vec2(0.0);
uniform float x = 0.0;
uniform float base = 0.0;
uniform float h = 10.0;
uniform float w = 6.0;
uniform float lean = 0.0;
uniform float white = 0.0;
uniform float glint = -1.0;
uniform float alpha = 1.0;
uniform sampler2D ramp : filter_nearest, repeat_disable;

vec4 R(float i) {
	return texture(ramp, vec2((i + 0.5) / 8.0, 0.5));
}

// C(i) of the original: the ramp counted from its bright end
vec4 Cb(float i) {
	return R(max(0.0, 7.0 - i));
}

bool inside(vec2 q) {
	float u = (base - (q.y + 0.5)) / h;
	return u >= 0.0 && u <= 1.0 && abs(q.x + 0.5 - (x + lean * u)) <= (w / 2.0) * (1.0 - u) + 0.35;
}

void fragment() {
	vec4 tint = COLOR;   // the node's modulate: fade a group, tint a copy
	if (h < 1.5) {
		discard;
	}
	vec2 q = floor((UV - 0.5) * size) + center;
	// q: the pixel's top-left corner, as the original's px, py
	if (q.y < floor(base - h) - 1.0 || q.y >= ceil(base)) {
		discard;
	}
	vec4 c;
	if (!inside(q)) {
		if (inside(q - vec2(1.0, 0.0)) || inside(q + vec2(1.0, 0.0)) || inside(q + vec2(0.0, 1.0)) || (inside(q - vec2(0.0, 1.0)) && q.y < base - 1.0)) {
			c = R(0.0);
		} else {
			discard;
		}
	} else if (white > 0.5) {
		c = vec4(1.0);
	} else {
		float ridge0 = x - w * 0.14;
		float u = (base - (q.y + 0.5)) / h;
		float rx = ridge0 + (x + lean - ridge0) * u;
		float cx = x + lean * u;
		float hw = (w / 2.0) * (1.0 - u) + 0.35;
		float fx = q.x + 0.5;
		if (u > 0.9) {
			c = vec4(1.0);
		} else if (abs(fx - rx) < 0.55) {
			c = Cb(1.0);
		} else if (fx < rx) {
			c = fx - (cx - hw) < 1.0 ? Cb(1.0) : ((fx - (cx - hw)) / max(1.0, rx - (cx - hw)) > 0.55 ? Cb(2.0) : Cb(3.0));
		} else {
			c = cx + hw - fx < 1.2 ? Cb(6.0) : ((fx - rx) / max(1.0, cx + hw - rx) > 0.5 ? Cb(5.0) : Cb(4.0));
		}
		if (glint >= 0.0 && fx <= rx + 0.6) {
			float g = abs(u - glint);
			if (g < 0.05) {
				c = vec4(1.0);
			} else if (g < 0.1) {
				c = Cb(1.0);
			}
		}
	}
	c.a = alpha;
	c *= tint;
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
