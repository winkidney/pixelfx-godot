// glitch-wipe.js draw(): torn bands of ink. `bands`: per band (index, top row, height, direction); `tears`: how far
// each band has torn at each frame (the original's stuttering tear(), worked out at build time), row = frame `f`.
// Everything else rolls from the original's hashes on the tick number `fr`.
uniform sampler2D bands : filter_nearest, repeat_disable;
uniform sampler2D tears : filter_nearest, repeat_disable;
uniform int nb = 0;
uniform float t = 0.0;
uniform float f = 0.0;
uniform float fr = 0.0;
uniform float outp = 0.0;
uniform vec4 C[8] : source_color;
uniform vec4 ink : source_color;
uniform vec4 red : source_color;

const float IN1 = 0.78;
const float OUT0 = 0.98;

float gl_round(float x) {
	return floor(x + 0.5);
}

float gl_r(int a, int b, int c) {
	return tr_rand3(a, b, c);
}

vec3 gl_pick(float u) {
	int k = int(floor(u * 4.0));
	return k == 0 ? vec3(1.0) : k == 1 ? C[6].rgb : k == 2 ? C[5].rgb : red.rgb;
}

// band n: its row (index, y, h, dir), its tear k, whether it's moving, its edge e (with the slip), and which side the
// ink is on
void gl_band(int n, out vec4 b, out float k, out bool moving, out float e, out bool behind) {
	b = texelFetch(bands, ivec2(n, 0), 0);
	k = texelFetch(tears, ivec2(n, int(f + 0.5)), 0).r;
	bool o = outp > 0.5;
	moving = k > 0.0 && k < 1.0;
	int bi = int(b.x + 0.5);
	int fi = int(fr + 0.5);
	float slip = (moving && gl_r(fi, bi, 11) < 0.12) ? gl_round((gl_r(fi, bi, 12) - 0.5) * 18.0) : 0.0;
	e = (b.w > 0.0 ? k * TR_W : TR_W - k * TR_W) + slip;
	behind = (b.w > 0.0) != o;
}

bool gl_shown(float k) {
	bool o = outp > 0.5;
	return !((!o && k <= 0.0) || (o && k >= 1.0));
}
