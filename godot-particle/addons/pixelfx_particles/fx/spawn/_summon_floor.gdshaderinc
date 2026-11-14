// Shared by spawn/summon-rise's floor shaders (_summon_floor.gdshader, _summon_floor_light.gdshader).
uniform vec2 size = vec2(84.0, 30.0);
uniform vec2 center = vec2(0.0);
uniform sampler2D cracks : filter_nearest;
uniform sampler2D runes : filter_nearest;
uniform float t = 0.0;
uniform float heat_k = 0.0;
uniform float ck = 0.0;
uniform float cool = 0.0;
uniform float rk = 0.0;
uniform float inner = 0.0;
uniform float hole = 0.0;
uniform float ign_t = 0.5;
uniform float r0 = 36.0;
uniform float r1 = 27.0;
uniform float sy = 0.3;
uniform vec4 pal[8] : source_color;
uniform vec4 white : source_color = vec4(1.0);

#include "res://addons/pixelfx_particles/fx/spawn/_jsrand.gdshaderinc"

// whether cell is on the original's line() from cell a to cell b
bool seg_on(vec2 d, vec2 a, vec2 b) {
	vec2 e = b - a;
	float n = max(abs(e.x), abs(e.y));
	if (n < 0.5) {
		return all(equal(d, a));
	}
	if (abs(e.x) >= abs(e.y)) {
		if (d.x < min(a.x, b.x) - 0.1 || d.x > max(a.x, b.x) + 0.1) {
			return false;
		}
		float y = a.y + e.y * (d.x - a.x) / e.x;
		return abs(d.y - floor(y + 0.5)) < 0.1;
	}
	if (d.y < min(a.y, b.y) - 0.1 || d.y > max(a.y, b.y) + 0.1) {
		return false;
	}
	float x = a.x + e.x * (d.y - a.y) / e.y;
	return abs(d.x - floor(x + 0.5)) < 0.1;
}
