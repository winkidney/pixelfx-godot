// weather/aurora's brightest rays (aurora.js curtain(): where a ray peaks along a curtain), worked out at build time
// for every frame (build/fx/weather/aurora.gd) into `data`: row f = frame f, texel slot = (x, hem, h, k), k 0 for
// none. The particle sits on the strand's foot; CUSTOM.zw = (its height, its strength). Drawn by _ray.gdshader.
shader_type particles;
render_mode disable_velocity, disable_force;

#include "res://addons/pixelfx_particles/fx/weather/_wx.gdshaderinc"

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float frames = 360.0;

bool body(int i, out vec2 p, out vec4 cu, out vec4 col) {
	int f = clamp(int(floor(t * 30.0 + 0.5)), 0, int(frames) - 1);
	vec4 r = texelFetch(data, ivec2(i, f), 0);
	p = r.xy;
	cu = vec4(0.0, 0.0, r.z, r.w);
	col = vec4(1.0);
	return r.w > 0.0;
}

#include "res://addons/pixelfx_particles/fx/weather/_wx_place.gdshaderinc"
