// The laser grid's dust (src/fx/scifi/laser-grid.js): 90 motes hanging in the air, drifting on slow loops (`motes`:
// each one's rand(seed, i) and rand(seed, i, 1)), invisible until a beam passes within 1.6 px: then a pixel, white
// in the beam's core, pale red at its edge. Placed from the keyed clock `t`; colour layer (dot1 texture).
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/scifi/_scifi_light.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/scifi/_jsrand.gdshaderinc"

uniform float t = 0.0;
uniform sampler2D motes : filter_nearest, repeat_disable;
uniform vec4 hi : source_color = vec4(1.0);
uniform vec4 lo : source_color = vec4(1.0);

#include "res://addons/pixelfx_particles/fx/scifi/_laser_grid.gdshaderinc"

void place(int i, inout mat4 tr, inout vec4 col) {
	vec4 r = texelFetch(motes, ivec2(i, 0), 0);
	float x = (r.x * 2.0 - 1.0) * (IN - 3.0) + 4.0 * sin(TAU * (t / D) + float(i));
	float y = -2.0 - r.y * 62.0 + 3.0 * sin(TAU * 2.0 * (t / D) + float(i) * 1.7);
	float d = 9.0;
	for (int b = 0; b < 5; b++) {
		d = min(d, near_beam(beam(t, b), vec2(x, y)));
	}
	float sc = d < 1.6 ? 1.0 : 0.0;
	tr = mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(vec2(x, y)) + 0.5, 0.0, 1.0));
	col = d < 0.9 ? hi : lo;
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR);
}
