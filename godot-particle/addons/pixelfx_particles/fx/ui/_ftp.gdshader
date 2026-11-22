// The ui effects' particles (build/fx/ui/_ui.gd table()): every slot of a frame is one thing the original draws that
// frame (a dot, a line, a glint, a ring, a shard, a glow...), worked out at build time by replaying the original's
// own update() and draw() at its 120 Hz steps and frame clock, kept in `data`: first each frame's first entry and
// count, then the entries packed one after another, 5 texels each (cell, kind and alpha; colours and quad size;
// three of the kind's own numbers), 1024 texels a row. Placed from the keyed clock `t` (the effect's own seconds),
// so a one-shot replays exactly. Each particle is a quad of its own odd size centred on its cell, so its pixels land
// on whole pixels; it hands its entry and cell to _bits.gdshader / _bits_light.gdshader in CUSTOM.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float t = 0.0;
uniform int nframes = 1;
uniform bool looped = false;

const int ROWS = 5;
const int TW = 1024;

vec4 texel(int k) {
	return texelFetch(data, ivec2(k % TW, k / TW), 0);
}

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
	vec4 ix = texel(f);
	int e = int(ix.x) + i;
	col = vec4(1.0);
	if (float(i) >= ix.y) {
		tr = at_(vec2(-1e5), 0.0);
		cu = vec4(0.0);
		return;
	}
	int base = int(ix.z) + e * ROWS;
	vec4 a = texel(base);
	vec4 b = texel(base + 1);
	if (a.z < 0.5) {
		tr = at_(vec2(-1e5), 0.0);
		cu = vec4(0.0);
		return;
	}
	tr = at_(a.xy + 0.5, b.w);
	// where its texels start as column and row: CUSTOM keeps only half floats' whole numbers (up to 2048)
	cu = vec4(float(base % TW), float(base / TW), a.xy);
}

void start() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}

void process() {
	VELOCITY = vec3(0.0);
	place(int(INDEX), TRANSFORM, COLOR, CUSTOM);
}
