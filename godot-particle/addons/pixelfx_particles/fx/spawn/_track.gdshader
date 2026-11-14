// The spawn effects' own bodies (smoke balls, coins, motes, shards, speed lines, the original's Particles): GPU
// particles that follow the original's motion, run at build time from its own update() at 120 Hz with its seeded
// draws (build/fx/spawn/_spawn.gd track()), and recorded `hz` times a second into `data`, packed: `head` header texels
// a particle (the first: its first sample, how many, where they start), then its samples one after another, `rows`
// texels each, row 0 = (x, y, on, ..). The effect's clock is the uniform `t`, keyed by the animation; between two
// samples the position glides. Each particle sits on the centre of the original's pixel cell; CUSTOM hands the canvas
// shader (index, sample, exact position), so it can read the rest of its rows and draw on whole cells.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D data : filter_nearest, repeat_disable;
uniform float t = 0.0;
uniform float hz = 60.0;
uniform float rows = 1.0;
uniform float samples = 1.0;
uniform float head = 1.0;
uniform float width = 2048.0;

vec4 fetch(int l) {
	int w = int(width + 0.5);
	return texelFetch(data, ivec2(l % w, l / w), 0);
}

// (index, sample, x, y) for CUSTOM, and z = 1 when the particle shows
vec4 now(int i, out bool on) {
	on = false;
	vec4 h = fetch(i * int(head + 0.5));
	int n = int(rows + 0.5);
	float sf = t * hz;
	int s0 = int(floor(sf + 1e-3));
	float w = clamp(sf - float(s0), 0.0, 1.0);
	s0 = clamp(s0, 0, int(samples + 0.5) - 1);
	int rel = s0 - int(h.x + 0.5);
	int cnt = int(h.y + 0.5);
	if (rel < 0 || rel >= cnt) {
		return vec4(float(i), float(s0), 0.0, 0.0);
	}
	vec4 a = fetch(int(h.z + 0.5) + rel * n);
	vec2 p = a.xy;
	if (w > 0.0 && rel + 1 < cnt) {
		vec4 b = fetch(int(h.z + 0.5) + (rel + 1) * n);
		if (b.z > 0.5) {
			p = mix(a.xy, b.xy, w);
		}
	}
	on = a.z > 0.5;
	return vec4(float(i), float(s0), p);
}

mat4 place(vec4 cu, bool on) {
	float sc = on ? 1.0 : 0.0;
	vec2 cell = floor(cu.zw) + 0.5;
	return mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(cell, 0.0, 1.0));
}

void start() {
	bool on;
	vec4 cu = now(int(INDEX), on);
	COLOR = vec4(1.0);
	TRANSFORM = place(cu, on);
	CUSTOM = cu;
	VELOCITY = vec3(0.0);
}

void process() {
	bool on;
	vec4 cu = now(int(INDEX), on);
	TRANSFORM = place(cu, on);
	CUSTOM = cu;
	VELOCITY = vec3(0.0);
}
