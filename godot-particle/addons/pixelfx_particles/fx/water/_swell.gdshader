// Still dark water seen at a low angle (water/ripples' surface): a see-through patch `patch` px across, squashed by
// `sy`, shading with the slope of the swell each ripple carries so the rings read as waves catching the light from
// the far left. The ripples are born every `every` s at the middle and live `life` s, out to `rmax` px: the same
// clock as the rings drawn over it. Key `t` 0 -> 1 over the loop. Soft (translucent).
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/water/_water.gdshaderinc"

uniform vec2 size = vec2(128.0, 36.0);
uniform float t = 0.0;
uniform float dur = 2.0;
uniform float every = 0.5;
uniform float life = 2.0;
uniform float rmax = 60.0;
uniform float patch_r = 64.0;
uniform float sy = 0.26;
uniform float body = 0.55;

void fragment() {
	vec2 p = floor((UV - 0.5) * size) + 0.5;
	float z = p.y / sy;
	float r = length(vec2(p.x, z));
	float e = r / patch_r;
	if (e > 1.0) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.6, 1.0, e);
	float now = t * dur;
	float slope = 0.0;
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		if (fi * every >= life) {
			break;
		}
		float a = mod(now - fi * every, dur);
		if (a >= life) {
			continue;
		}
		float u = a / life;
		float R = 2.0 + (rmax - 2.0) * (1.0 - pow(1.0 - u, 3.0));
		float k = pow(1.0 - u, 1.5) * min(1.0, a / 0.08);
		float w = 3.0 + a * 2.2;
		float d = r - R;
		if (abs(d) > 2.2 * w) {
			continue;
		}
		slope += k * exp(-(d / w) * (d / w)) * -sin(d * 1.15) * 1.15;
	}
	vec3 cb = pal[1].rgb;
	float ab = body * edge;
	vec3 cf = vec3(0.0);
	float af = 0.0;
	if (slope != 0.0) {
		float face = slope * (-(p.x * -0.55 + z * -0.84) / max(1.0, r));
		if (face > 0.18) {
			cf = (face > 0.6 ? pal[5] : pal[4]).rgb;
			af = min(0.9, (face - 0.18) * 2.2) * edge;
		} else if (face < -0.25) {
			cf = pal[0].rgb;
			af = min(0.8, (-face - 0.25) * 2.0) * edge;
		}
	}
	float A = ab + af * (1.0 - ab);
	if (A <= 0.0) {
		discard;
	}
	vec4 c = vec4((cb * ab * (1.0 - af) + cf * af) / A, A);
	if (pfx_pixel(c, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = c;
}
