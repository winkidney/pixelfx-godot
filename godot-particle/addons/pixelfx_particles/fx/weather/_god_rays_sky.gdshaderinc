// weather/god-rays' air and beams (god-rays.js drawBack's rows pass): dark air, a dark floor, each beam posterized
// into a white-hot core, a gold body and a soft edge, fading as it falls; the sun's glare (light only).
#include "res://addons/pixelfx_particles/fx/weather/_god_rays.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[7] : source_color;
uniform vec4 L[7] : source_color;

void rays_px(vec2 p, out vec4 c, out vec3 l) {
	float y = p.y;
	bool fl = y > 0.0;
	c = vec4(C[0].rgb, fl ? 0.8 : 0.66);
	l = C[3].rgb * glow_(p, vec2(-168.0, -178.0), 130.0, 0.3) + C[5].rgb * glow_(p, vec2(-168.0, -178.0), 50.0, 0.35);
	float dy = y - SY;
	float r = (p.x - SX) * AX + dy * AY;
	float nn = (p.x - SX) * -AY + dy * AX;
	float ang = nn / r;
	float e = shafts_e(ang);
	if (e <= 0.0) {
		return;
	}
	float fall = 1.35 - (r - 200.0) / 330.0;
	float si = clamp(trunc((ang + 0.36) * 700.0), 0.0, 511.0);
	e *= clamp(fall, 0.0, 1.0) * (0.7 + 0.45 * strand(int(si))) * (fl ? 1.6 : 1.0);
	if (e < 0.06) {
		return;
	}
	int lv = e > 1.05 ? 6 : e > 0.78 ? 5 : e > 0.52 ? 4 : e > 0.3 ? 3 : 2;
	c = vec4((fl ? C[lv] : L[lv]).rgb, fl ? 0.85 : min(0.78, 0.12 + e * 0.5));
	l += C[4].rgb * e * (fl ? 0.32 : 0.26);
}
