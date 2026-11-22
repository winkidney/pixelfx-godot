// The original's simulated particles (core/sim.js Particles and Bits) on a GPUParticles2D: each particle reads its
// spawn (where, how fast, how long, after what delay, what colour) from `table`, a column per particle, filled by the
// build script with the original's own spawn rules; then it moves by the original's rules for its kind, stepped at
// 120 Hz as the original steps. Several emitters share a table and each draws one `part` of it with its own canvas
// material: 0 a streak's tail (or the particle itself), 1 a streak's head (or a second piece), 2 its glow (light),
// 3 a third piece. `t0` is when the burst goes off (the original's particle clock: s since the effect began).
//   table rows: 0 (x, y, vx, vy), 1 (life, delay, size, seed), 2 colour, 3 (g, drag, bounce, spin) for debris
//   kinds: 0 SPARK, 1 MOTE, 2 STREAK, 4 VAPOUR, 5 DUST, 6 STAR, 7 EMBER, 8 SMOKE (flag BIG: 9), 11 GRIT,
//          20 SHARD, 21 CHUNK, 22 DRIP (core/sim.js Bits)
shader_type particles;
render_mode disable_velocity, disable_force;

uniform sampler2D table : filter_nearest, repeat_disable;
uniform float kind_ = 0.0;
uniform float part_ = 0.0;
uniform float t0 = 0.0;
// how much later than its emitter's first frame the burst really went off (s): the particles wait that long
uniform float lag = 0.0;
uniform float floor_y = 0.0;
uniform float has_floor = 1.0;
// SPARK colours, head first
uniform vec4 s0 : source_color = vec4(1.0, 0.95, 0.65, 1.0);
uniform vec4 s1 : source_color = vec4(1.0, 0.89, 0.42, 1.0);
uniform vec4 s2 : source_color = vec4(1.0, 0.54, 0.16, 1.0);
uniform vec4 s3 : source_color = vec4(0.95, 0.34, 0.11, 1.0);
// SMOKE_RAMP (core/sim.js) for smoke cooling
uniform vec4 smoke[5];

const float G = 950.0;
const vec4 WHITE = vec4(1.0);

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

mat4 hidden(vec2 p) {
	return mat4(vec4(0.0), vec4(0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 0.0, 1.0));
}

// the original's 1 px line from the cell holding a to the cell holding b: a 1 px wide quad through the cell centres
mat4 seg(vec2 a, vec2 b) {
	vec2 pa = floor(a) + 0.5;
	vec2 pb = floor(b) + 0.5;
	vec2 d = pb - pa;
	float L = length(d);
	vec2 e = L > 0.01 ? d / L : vec2(1.0, 0.0);
	return mat4(vec4(e * (L + 1.0), 0.0, 0.0), vec4(-e.y, e.x, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4((pa + pb) * 0.5, 0.0, 1.0));
}

// a w x h block of pixels with its top-left cell at the one holding p
mat4 block(vec2 p, float w, float h) {
	return mat4(vec4(w, 0.0, 0.0, 0.0), vec4(0.0, h, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(p) + vec2(w, h) * 0.5, 0.0, 1.0));
}

// a quad 2r across centred on p (glows, discs: their shaders round it off)
mat4 disc(vec2 p, float r) {
	return mat4(vec4(2.0 * r, 0.0, 0.0, 0.0), vec4(0.0, 2.0 * r, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 0.0, 1.0));
}

void start() {
	int i = int(INDEX);
	vec4 a = texelFetch(table, ivec2(i, 0), 0);
	vec4 b = texelFetch(table, ivec2(i, 1), 0);
	// CUSTOM: x, y, age (since the burst, delay included), life left. VELOCITY: vx, vy, spin angle.
	CUSTOM = vec4(a.x, a.y, -lag, b.x);
	VELOCITY = vec3(a.z, a.w, hash(b.w) * 6.2831853);
	TRANSFORM = hidden(a.xy);
	COLOR = vec4(0.0);
}

void process() {
	int kind = int(kind_ + 0.5);
	int part = int(part_ + 0.5);
	int i = int(INDEX);
	vec4 b = texelFetch(table, ivec2(i, 1), 0);
	vec4 col = texelFetch(table, ivec2(i, 2), 0);
	vec4 dbr = texelFetch(table, ivec2(i, 3), 0);
	float max_life = b.x;
	float delay = b.y;
	float size = b.z;
	float seed = b.w;
	vec2 x = CUSTOM.xy;
	float age = CUSTOM.z;
	float left = CUSTOM.w;
	vec2 v = VELOCITY.xy;
	float ang = VELOCITY.z;
	int n = max(1, int(ceil(DELTA * 120.0 - 1e-3)));
	float dt = DELTA / float(n);
	for (int s = 0; s < n; s++) {
		age += dt;
		if (age <= delay + 1e-6 || left <= 0.0) {
			continue;
		}
		left -= dt;
		if (left <= 0.0) {
			break;
		}
		float T = t0 + age;
		float gy = floor_y;
		if (kind == 0) {
			v.y += G * 0.45 * dt;
			v -= v * 2.2 * dt;
			float ny = x.y + v.y * dt;
			x.x += v.x * dt;
			if (has_floor > 0.5 && v.y > 0.0 && x.y <= gy && ny >= gy) {
				v.y = -v.y * 0.45;
				v.x *= 0.7;
				x.y = gy - 0.25;
			} else {
				x.y = ny;
			}
			continue;
		} else if (kind == 11) {
			v.y += G * dt;
			v.x -= v.x * 0.8 * dt;
			float ny = x.y + v.y * dt;
			x.x += v.x * dt;
			if (has_floor > 0.5 && v.y > 0.0 && x.y <= gy && ny >= gy) {
				x.y = gy - 0.25;
				if (v.y > 130.0 && hash(seed + x.x * 0.37) < 0.4) {
					v.y = -v.y * 0.25;
					v.x = v.x * 0.5 + (hash(seed * 1.7 + 3.0) * 20.0 - 10.0);
				} else {
					v = vec2(0.0);
					left = min(left, 0.5);
				}
			} else {
				x.y = ny;
			}
			continue;
		} else if (kind >= 20 && kind < 30) {
			// debris (Bits): falls, drags, bounces off the floor and comes to rest
			if (v == vec2(0.0) && x.y >= gy - 0.02) {
				continue;
			}
			v.y += G * dbr.x * dt;
			v -= v * dbr.y * dt;
			x += v * dt;
			ang += dbr.w * dt;
			float sp = v.y;
			if (has_floor > 0.5 && dbr.x > 0.0 && x.y >= gy && sp > 0.0) {
				x.y = gy - 0.01;
				if (kind == 22) {
					left = 0.0;
					break;
				} else if (dbr.z > 0.0 && sp > 70.0) {
					v.y = -sp * dbr.z;
					v.x *= 0.7;
				} else {
					v = vec2(0.0);
				}
			}
			continue;
		} else if (kind == 30) {
			// a wisp (scythe-reap.js): rises, sways and curls
			float a = age - delay;
			v.y -= 30.0 * dt;
			v.x += sin(a * 9.0 + seed) * 120.0 * dt;
			v.x -= v.x * 2.0 * dt;
			v.y -= v.y * 1.2 * dt;
		} else if (kind == 1) {
			v -= v * 0.6 * dt;
		} else if (kind == 2) {
			v += v * 3.0 * dt;
		} else if (kind == 7) {
			v.y += (-30.0 + sin(T * 3.0 + seed) * 20.0) * dt;
			v.x += cos(T * 2.3 + seed) * 45.0 * dt;
			v -= v * 1.6 * dt;
		} else if (kind == 8 || kind == 9) {
			v.y -= (kind == 9 ? 23.0 : 16.0) * dt;
			v.x += sin(T * 1.3 + seed) * 8.0 * dt;
			v.x -= v.x * 1.6 * dt;
			v.y -= v.y * 1.2 * dt;
		} else {
			float drag = (kind == 4 || kind == 5) ? 4.0 : 1.6;
			v.x -= v.x * drag * dt;
			v.y -= v.y * drag * dt + 5.0 * dt;
		}
		x += v * dt;
	}
	CUSTOM = vec4(x, age, left);
	VELOCITY = vec3(v, ang);
	bool dead = age > delay + 1e-6 && left <= 0.0;
	if (dead) {
		ACTIVE = false;
	}
	bool waiting = age <= delay + 1e-6;
	if (dead || waiting) {
		kind = -1;
	}
	float k = clamp(left / max_life, 0.0, 1.0);
	float T = t0 + age;
	float sp = length(v);
	vec2 u = sp > 0.0 ? v / sp : vec2(0.0);
	sp = max(sp, 1.0);
	TRANSFORM = hidden(x);
	COLOR = vec4(0.0);
	if (kind == 0) {
		vec4 head = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
		float len = min(9.0, 1.0 + sp * 0.022);
		if (part == 0) {
			TRANSFORM = seg(x - u * len, x - u * len * 0.4);
			COLOR = k > 0.5 ? head : s3;
		} else if (part == 1) {
			TRANSFORM = seg(x - u * len * 0.45, x);
			COLOR = head;
		} else if (part == 2) {
			TRANSFORM = disc(x, 3.0);
			COLOR = vec4(head.rgb, 0.45 * k);
		}
	} else if (kind == 1) {
		float len = min(16.0, 0.5 + sp * 0.026) * size;
		float a = k < 0.35 ? k / 0.35 : 1.0;
		if (part == 0) {
			TRANSFORM = seg(x - u * len, x - u * len * 0.35);
			COLOR = vec4(col.rgb * 0.55, a);
		} else if (part == 1) {
			TRANSFORM = seg(x - u * len * 0.4, x);
			COLOR = vec4(col.rgb, a);
		} else if (part == 2) {
			TRANSFORM = disc(x, 2.5 + size);
			COLOR = vec4(col.rgb, 0.4 * k);
		}
	} else if (kind == 2) {
		float L = clamp(sp / 30.0, 1.0, 7.0);
		if (part == 0) {
			TRANSFORM = seg(x - u * L, x - u * L * 0.5);
			COLOR = vec4(col.rgb * 0.6, 0.6);
		} else if (part == 1) {
			TRANSFORM = seg(x - u * L * 0.5, x - u);
			COLOR = col;
		} else if (part == 3) {
			TRANSFORM = block(x, 1.0, 1.0);
			COLOR = WHITE;
		} else if (part == 2) {
			TRANSFORM = disc(x, 4.0);
			COLOR = vec4(col.rgb, 0.4);
		}
	} else if (kind == 6) {
		// a twinkling cross: arms of size * twinkle; the sparkle shader reads the arm from the alpha ((n + 1) / 16)
		float tw = 0.6 + 0.4 * sin(T * (8.0 + mod(seed, 5.0)) + seed);
		if (size < 1.0) {
			if (part == 0 && tw * k > 0.25) {
				TRANSFORM = block(x, 1.0, 1.0);
				COLOR = vec4(tw > 0.8 ? WHITE.rgb : col.rgb, 0.5 / 16.0 + 1.0 / 16.0);
			} else if (part == 2) {
				TRANSFORM = disc(x, 3.0);
				COLOR = vec4(col.rgb, 0.4 * k * tw);
			}
		} else {
			float arm = floor(size * tw * min(1.0, k * 3.0) + 0.5);
			if (arm >= 1.0) {
				if (part == 0) {
					float w = 2.0 * arm + 1.0;
					TRANSFORM = mat4(vec4(w, 0.0, 0.0, 0.0), vec4(0.0, w, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(x) + 0.5, 0.0, 1.0));
					COLOR = vec4(col.rgb, (arm + 1.0 + 0.5) / 16.0);
				} else if (part == 2) {
					TRANSFORM = disc(x, 4.0 + arm * 2.0);
					COLOR = vec4(col.rgb, 0.5 * k * tw);
				}
			}
		}
	} else if (kind == 7) {
		vec4 c = k > 0.6 ? s0 : k > 0.3 ? s1 : s2;
		bool on = !(k < 0.25 && sin(T * 40.0 + seed) < 0.0);
		if (on && part == 0) {
			TRANSFORM = block(x, 1.0, 1.0);
			COLOR = c;
		} else if (on && part == 1 && size > 1.5) {
			TRANSFORM = block(x + vec2(0.0, 1.0), 1.0, 1.0);
			COLOR = s3;
		} else if (on && part == 2) {
			TRANSFORM = disc(x, 3.0 + size);
			COLOR = vec4(c.rgb, 0.35 * k);
		}
	} else if (kind == 30) {
		// its thread: the path of its last 14 steps, pale at the head, fading down it
		if (part == 0) {
			TRANSFORM = seg(x - v * 0.117, x - v * 0.045);
			COLOR = vec4(s3.rgb, k * 0.45);
		} else if (part == 1) {
			TRANSFORM = seg(x - v * 0.07, x - v * 0.03);
			COLOR = vec4(s1.rgb, k * 0.75);
		} else if (part == 3) {
			TRANSFORM = seg(x - v * 0.03, x);
			COLOR = vec4(s0.rgb, k);
		} else if (part == 2 && k > 0.5) {
			TRANSFORM = disc(x, 5.0);
			COLOR = vec4(s1.rgb, 0.25 * k);
		}
	} else if (kind == 11) {
		if (part == 0 && k > 0.125) {
			TRANSFORM = block(x, size >= 2.0 ? 2.0 : 1.0, size >= 2.0 ? 2.0 : 1.0);
			COLOR = col;
		}
	} else if (kind == 5) {
		if (part == 0) {
			TRANSFORM = disc(x, size * (0.6 + (1.0 - k) * 0.9));
			COLOR = vec4(col.rgb, pow(k, 1.3) * 0.7);
		}
	} else if (kind == 4) {
		float r = size * (0.6 + (1.0 - k) * 0.9);
		if (part == 0) {
			TRANSFORM = disc(x, r);
			COLOR = vec4(col.rgb, pow(k, 1.3) * 0.45);
		} else if (part == 2) {
			TRANSFORM = disc(x, r * 1.8);
			COLOR = vec4(texelFetch(table, ivec2(i, 3), 0).rgb, 0.16 * k);
		}
	} else if (kind == 8 || kind == 9) {
		// three soft discs: a body, a denser core sitting low, a lit cap while it's young
		float ag = 1.0 - k;
		bool big = kind == 9;
		float r = size * (0.65 + min(1.0, ag * 2.5) * 0.45 + ag * (big ? 0.5 : 0.4));
		float a = min(1.0, ag * 12.0) * min(1.0, k * 2.4) * (big ? 0.7 : 0.58);
		vec4 sr = smoke[int(clamp(floor(ag * 5.0), 0.0, 4.0))];
		vec4 c = col.a > 0.0 ? mix(col, sr, ag) : smoke[int(clamp(floor(ag * 1.05 * 5.0), 0.0, 4.0))];
		if (part == 0) {
			TRANSFORM = disc(x, r);
			COLOR = vec4(c.rgb, a * 0.45);
		} else if (part == 1) {
			TRANSFORM = disc(x + vec2(r * 0.05, r * 0.06), r * 0.74);
			COLOR = vec4(c.rgb, a * 0.62);
		} else if (part == 3 && ag < 0.5) {
			TRANSFORM = disc(x - vec2(r * 0.22, r * 0.3), r * 0.5);
			COLOR = vec4(mix(c.rgb, vec3(1.0), 0.12), a * 0.4 * (1.0 - ag * 2.0));
		}
	} else if (kind >= 20) {
		float fade = min(1.0, left / (kind == 21 ? 0.5 : 0.4));
		if (kind == 22) {
			if (part == 0) {
				TRANSFORM = block(x, 1.0, 1.0);
				COLOR = vec4(col.rgb, fade);
			} else if (part == 1) {
				TRANSFORM = block(x - vec2(0.0, 1.0), 1.0, 1.0);
				COLOR = vec4(col.rgb, fade * 0.5);
			}
		} else if (kind == 21) {
			// a rock: the rock shader reads its angle, size and fade from the colour
			if (part == 0) {
				float s = size;
				float w = 2.0 * (ceil(s) + 1.0) + 1.0;
				TRANSFORM = mat4(vec4(w, 0.0, 0.0, 0.0), vec4(0.0, w, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(floor(x + 0.5) + 0.5, 0.0, 1.0));
				COLOR = vec4(fract(ang / 6.2831853), s / 4.0, fade, 1.0);
			}
		} else {
			// a hot chip (hammer-smash): cools through the spark ramp, a dark pixel trailing while it flies
			vec4 c = k > 0.7 ? s0 : k > 0.45 ? s1 : k > 0.25 ? s2 : s3;
			bool rest = length(v) < 1e-3;
			if (part == 0) {
				TRANSFORM = block(x, 1.0, 1.0);
				COLOR = vec4(c.rgb, min(1.0, k * 4.0));
			} else if (part == 1 && !rest) {
				TRANSFORM = block(x - v * 0.012, 1.0, 1.0);
				COLOR = vec4(s3.rgb, min(1.0, k * 4.0));
			} else if (part == 2) {
				TRANSFORM = disc(x, 4.0);
				COLOR = vec4(c.rgb, 0.35 * k);
			}
		}
	}
}
