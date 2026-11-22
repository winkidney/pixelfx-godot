// Shared by the hologram's shaders (_hologram.gdshader, _hologram_light.gdshader): the model's pose at the keyed
// clock `t` (turning, bobbing, jolted when it glitches: its corners in `data` rows 3..10) and the frame's glitch
// data (`data`: one column a frame).
// Declare `t` and `data` before including.

const float D = 4.0;
const float OY = -50.0;
const float RAD = 16.0;
const float LENS = -6.0;
const float TILT = 0.32;

struct Holo {
	vec3 V[8];
	float cx;
	float cy;
	float scan;
	float top;
	float ph;
	bool flick;
};

vec4 F(int row) {
	int f = clamp(int(floor(t * 30.0 + 0.5)), 0, 119);
	return texelFetch(data, ivec2(f, row), 0);
}

int tear_at(int y) {
	for (int i = 1; i <= 2; i++) {
		vec4 q = F(i);
		if (q.y > 0.5 && float(y) >= q.x && float(y) < q.x + q.y) {
			return int(q.z);
		}
	}
	return 0;
}

Holo setup() {
	Holo h;
	h.ph = t / D;
	vec4 m = F(0);
	h.flick = m.y > 0.5;
	h.cx = m.z;
	h.cy = OY + 1.5 * sin(TAU * h.ph * 2.0);
	h.top = h.cy + RAD * 1.3;
	// the crystal's corners, worked out per frame at build time in double precision (a corner turning through x = 0
	// lands on the side of the pixel grid the original's does)
	for (int i = 0; i < 8; i++) {
		h.V[i] = F(3 + i).xyz;
	}
	h.scan = mix(h.cy + RAD * 1.5, h.cy - RAD * 1.5, mod(h.ph * 2.0, 1.0) / 0.8);
	return h;
}

