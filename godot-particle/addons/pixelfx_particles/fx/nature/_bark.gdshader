// A particle process shader for chips thrown off with the original's own numbers (root snare's bark): particle i
// starts at launch[i].xy with velocity launch[i].zw, turns from spin[i].x at spin[i].y rad/s, is drawn at spin[i].z of
// the texture's size and lives spin[i].w s, fading over its last 0.25 s. It falls under `gravity`, hits the floor at
// y = 0 and bounces once (back up at 0.3 of its speed, half its run) if it lands faster than 110 px/s, then lies
// still, half sunk, as the original's chips do. Its age is counted in CUSTOM.y from DELTA (no clock). Use it on a
// one-shot emitter (explosiveness 1) with `amount` = the number of chips. The draw material is the usual dither.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform vec4 launch[64];
uniform vec4 spin[64];
uniform float gravity = 950.0;

void place(inout mat4 tr, inout vec4 col, float age, int i) {
	vec4 p = launch[i];
	vec4 q = spin[i];
	float g = gravity;
	float t1 = (-p.w + sqrt(max(0.0, p.w * p.w - 2.0 * g * p.y))) / g;
	vec2 pos;
	float turn;
	if (age < t1) {
		pos = vec2(p.x + p.z * age, p.y + p.w * age + 0.5 * g * age * age);
		turn = age;
	} else {
		float vy1 = p.w + g * t1;
		float x1 = p.x + p.z * t1;
		if (vy1 > 110.0) {
			float vy2 = -vy1 * 0.3;
			float vx2 = p.z * 0.5;
			float t2 = -2.0 * vy2 / g;
			float e = age - t1;
			if (e < t2) {
				pos = vec2(x1 + vx2 * e, vy2 * e + 0.5 * g * e * e);
				turn = age;
			} else {
				pos = vec2(x1 + vx2 * t2, 0.0);
				turn = t1 + t2;
			}
		} else {
			pos = vec2(x1, 0.0);
			turn = t1;
		}
	}
	float a = clamp((q.w - age) / 0.25, 0.0, 1.0);
	float s = age < q.w ? q.z : 0.0;
	float ang = q.x + q.y * turn;
	float ca = cos(ang);
	float sa = sin(ang);
	tr = mat4(vec4(ca * s, sa * s, 0.0, 0.0), vec4(-sa * s, ca * s, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 0.0, 1.0));
	col = vec4(1.0, 1.0, 1.0, a);
}

void start() {
	CUSTOM = vec4(0.0);
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, 0.0, int(INDEX));
}

void process() {
	CUSTOM.y += DELTA;
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, CUSTOM.y, int(INDEX));
}
