// The pickups' particles (build/fx/pickups/_pickups.gd table()): every slot is one of the original's glints, motes,
// sparks or flecks, worked out at build time from the original's own formulas for each frame it draws and kept in
// `data` (4 rows a frame: cell and size, colours, light, extras). Placed from the keyed clock `t` (the effect's own
// seconds), so a loop has no seam and a one-shot replays exactly. The particle sits on its cell's centre (its quad
// odd-sized, so it never lands between pixels) and hands its slot, frame and cell to _bits.gdshader /
// _bits_light.gdshader in CUSTOM.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float t = 0.0;
uniform int nframes = 1;
uniform bool looped = false;

mat4 at_(vec2 p, float sc) {
	return mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 0.0, 1.0));
}

void place(int i, inout mat4 tr, inout vec4 col, inout vec4 cu) {
	int f = int(floor(t * 30.0 + 0.5));
	if (looped) {
		f = f - nframes * int(floor(float(f) / float(nframes)));
	} else {
		f = clamp(f, 0, nframes - 1);
	}
	vec4 a = texelFetch(data, ivec2(i, f * 4), 0);
	vec4 b = texelFetch(data, ivec2(i, f * 4 + 1), 0);
	col = vec4(1.0);
	if (b.w < 0.5) {
		tr = at_(vec2(0.0), 0.0);
		cu = vec4(0.0);
		return;
	}
	tr = at_(a.xy + 0.5, 1.0);
	cu = vec4(float(i), float(f), a.xy);
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}
