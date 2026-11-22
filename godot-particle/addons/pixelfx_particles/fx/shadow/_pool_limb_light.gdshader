// A tentacle's or an arm's light (see _pool_limb.gdshaderinc): a tentacle's tip catches the light (r 6), light runs
// along it (r 9 every 4 px), a pulse of light runs up it as it lashes (r 10); an arm's hand glows as it clenches
// (r 8). The original's p.glow: (1 - d / r)^2 * k. Light layer.
shader_type canvas_item;
render_mode blend_add;

#include "res://addons/pixelfx_particles/fx/shadow/_pool_limb.gdshaderinc"

uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c5 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform float strength = 1.0;

vec3 glow_at(vec2 p, vec2 at, float r, vec4 col, float k) {
	float d = length(p - at) / r;
	if (d >= 1.0) {
		return vec3(0.0);
	}
	return col.rgb * (1.0 - d) * (1.0 - d) * k;
}

void fragment() {
	vec2 p = floor((UV - 0.5) * size + center + 0.001) + 0.5;
	vec3 sum = vec3(0.0);
	int n = limb_n();
	float pulse = (t - t0) * 150.0;
	int pi = clamp(int(floor(pulse * 2.0 + 0.5)), 0, n);
	vec2 q;
	float th;
	vec2 tip;
	float tip_th;
	limb_start(q, th);
	for (int i = 0; i <= 200; i++) {
		if (i > n) {
			break;
		}
		float s = float(i) * 0.5;
		float u = s / len;
		tip = q;
		tip_th = th;
		if (mode == 0) {
			if (i % 8 == 0 && q.y < surf) {
				sum += glow_at(p, q, 9.0, c4, 0.1);
			}
			if (i == pi && pulse < len && q.y < surf) {
				sum += glow_at(p, q, 10.0, c6, 0.45);
			}
		}
		limb_step(q, th, s, u);
	}
	if (mode == 0) {
		if (tip.y <= surf) {
			sum += glow_at(p, tip, 6.0, c6, 0.25);
		}
	} else if (tip.y <= surf - 2.0) {
		vec2 cc = tip + vec2(cos(tip_th), sin(tip_th)) * 2.6;
		sum += glow_at(p, cc, 8.0, c5, 0.18 + 0.3 * max(0.0, grip));
	}
	COLOR = vec4(sum * strength * COLOR.a, 1.0);
}
