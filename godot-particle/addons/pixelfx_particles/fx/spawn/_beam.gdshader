// spawn/respawn-beam's beam, as the original shades it row by row: a see-through column (`fill`, translucent) with
// hard bright edges flickering white, a white-hot core that fades as the writing starts, and strands of brighter
// light shimmering down it; before the slam, the dotted guide line it will drop along. Soft layer: the column blends,
// the edges and core are solid. The rect spans the beam's whole reach; `w` its half width, `y_end` its bottom.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

uniform vec2 size = vec2(48.0, 136.0);
uniform vec2 center = vec2(0.0);
uniform float top_y = -136.0;
uniform float w = 0.0;
uniform float y_end = -1.0;
uniform float fill = 0.2;
uniform float writing = 0.0;
uniform float core = 1.0;
uniform float t = 0.0;
// strands: offset, frequency, width
uniform vec3 strands[6];
uniform float guide = 0.0;
uniform float guide_odd = 0.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 white : source_color = vec4(1.0);

vec4 tk_over_px(vec4 dst, vec3 c, float a) {
	if (a <= 0.004) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	float k = a / oa;
	return vec4(c * k + dst.rgb * (1.0 - k), oa);
}

void fragment() {
	vec2 cell = floor(center + (UV - 0.5) * size);
	float th = pfx_threshold(FRAGCOORD.xy);
	vec4 o = vec4(0.0);
	float x = cell.x;
	float y = cell.y;
	if (guide > 0.0 && x == 0.0 && y < -1.0) {
		// a dot every other row, the pair stepping each 60th of a second
		float yy = y - guide_odd;
		if (mod(yy - top_y, 2.0) < 0.5 && yy < -1.0) {
			float a = guide * (0.35 + 0.65 * ((yy - top_y) / -top_y));
			if (a >= 1.0 || a > th) {
				o = vec4(c5.rgb, 1.0);
			}
		}
	}
	if (w > 0.2 && y <= y_end && y >= top_y && x >= floor(-w) && x <= ceil(w)) {
		float q = abs((x + 0.5) / w);
		if (q <= 1.0) {
			if (q > 0.86) {
				o = q > 0.94 && js_rand3(int(x), int(y), int(floor(t * 30.0))) < 0.7 ? white : c5;
			} else if (q < 0.7 * core) {
				bool hot = q < 0.35 * core;
				for (int i = 0; i < 6; i++) {
					vec3 s = strands[i];
					if (abs((x + 0.5) / w - s.x * 0.6 - 0.05 * sin(t * s.y * 3.0 + y * 0.05)) < 0.04) {
						hot = false;
					}
				}
				o = hot ? white : q < 0.5 * core ? c6 : c5;
			} else {
				float a = fill * (1.2 - q);
				vec3 c = c4.rgb;
				for (int i = 0; i < 6; i++) {
					vec3 s = strands[i];
					if (abs((x + 0.5) / w - s.x - 0.06 * sin(t * s.y + s.x * 7.0)) < 0.045 + 0.03 * s.z) {
						a = 0.55 - 0.25 * writing;
						c = c5.rgb;
					}
				}
				o = tk_over_px(o, c, a);
			}
		}
	}
	if (o.a <= 0.0) {
		discard;
	}
	float a = floor(o.a * 32.0 + th) / 32.0;
	if (a <= 0.0) {
		discard;
	}
	COLOR = vec4(o.rgb, a);
}
