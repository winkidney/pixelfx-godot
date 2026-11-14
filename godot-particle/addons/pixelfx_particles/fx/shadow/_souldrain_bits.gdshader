// Soul drain's small things as particles placed off the clock `t` (seconds, keyed), each slot one of the original's
// own (replayed from its cycle() choices): mode 0 the streaks racing down the funnel (a 1 px line from 0.06 s back to
// the head, stretched texture along it), 1 their glow at the head; 2 the pale haze where the souls are torn loose,
// 3 its glow; 4 the motes circling the vessel (bright in front, dim behind), 5 the front ones' glow. INDEX picks the
// slot; a slot not alive is scaled to nothing. The draw material does the layer.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform int mode = 0;
uniform float t = 0.0;
uniform float period = 3.2;
uniform float vy = -50.0;
uniform vec4 la[11];
uniform vec4 lb[11];
// mode 0, 1: born, life, line, u0; mode 2, 3: born, life, x, y
uniform vec4 slots[22];
uniform int count = 22;
uniform float tex_len = 10.0;
uniform vec4 c4 : source_color = vec4(1.0);
uniform vec4 c6 : source_color = vec4(1.0);
uniform vec4 c7 : source_color = vec4(1.0);
uniform vec4 s1 : source_color = vec4(1.0);
uniform vec4 s2 : source_color = vec4(1.0);

vec2 along(int i, float u) {
	float v = 1.0 - u;
	float a = v * v * v;
	float b = 3.0 * v * v * u;
	float c = 3.0 * v * u * u;
	float d = u * u * u;
	vec4 A = la[i];
	vec4 B = lb[i];
	return vec2(a * A.x + b * A.z + c * B.x, a * A.y + b * A.w + c * B.y + d * vy);
}

float wrapd(float x) {
	return mod(mod(x, period) + period, period);
}

void place(inout mat4 tr, inout vec4 col, int i) {
	vec2 pos = vec2(0.0);
	vec2 sc = vec2(0.0);
	float ang = 0.0;
	vec4 c = vec4(1.0);
	if (mode <= 1 && i < count) {
		vec4 s = slots[i];
		float age = wrapd(t - s.x);
		if (age < s.y) {
			int li = int(s.z);
			float q = s.w + (1.0 - s.w) * pow(age / s.y, 2.2);
			float q2 = s.w + (1.0 - s.w) * pow(max(0.0, age - 0.06) / s.y, 2.2);
			vec2 head = along(li, q);
			vec2 tail = along(li, q2);
			if (mode == 0) {
				// a line of cells from the tail's to the head's: centred between them, a cell longer than the gap
				vec2 a = floor(tail) + 0.5;
				vec2 b = floor(head) + 0.5;
				vec2 dv = b - a;
				float L = max(abs(dv.x), abs(dv.y));
				ang = L > 0.0 ? atan(dv.y, dv.x) : 0.0;
				float len = L > 0.0 ? length(dv) * (L + 1.0) / L : 1.0;
				pos = (a + b) * 0.5;
				sc = vec2(len / tex_len, 1.0);
			} else {
				pos = floor(head) + 0.5;
				sc = vec2(1.0);
				c = vec4(c6.rgb, 0.35);
			}
		}
	} else if ((mode == 2 || mode == 3) && i < count) {
		vec4 s = slots[i];
		float age = wrapd(t - s.x);
		if (age < s.y) {
			float u = age / s.y;
			pos = floor(vec2(s.z, s.w - age * 18.0)) + 0.5;
			sc = vec2(1.0);
			c = mode == 2 ? vec4(s2.rgb, (1.0 - u) * 0.8) : vec4(s1.rgb, 0.2 * (1.0 - u));
		}
	} else if (mode >= 4 && i < 6) {
		float y0 = vy + sin(TAU * t / period) * 1.5;
		float a = TAU * (2.0 * t) / period + float(i) * TAU / 6.0;
		float z = sin(a);
		pos = floor(vec2(cos(a) * 15.0, y0 + sin(a) * 5.0 - 2.0)) + 0.5;
		if (mode == 4) {
			sc = vec2(1.0);
			c = z > 0.0 ? c7 : c4;
		} else if (z > 0.0) {
			sc = vec2(1.0);
			c = vec4(c6.rgb, 0.35);
		}
	}
	float ca = cos(ang);
	float sa = sin(ang);
	tr = mat4(vec4(ca * sc.x, sa * sc.x, 0.0, 0.0), vec4(-sa * sc.y, ca * sc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0),
		vec4(pos, 0.0, 1.0));
	col = c;
}

void start() {
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, int(INDEX));
}

void process() {
	VELOCITY = vec3(0.0);
	place(TRANSFORM, COLOR, int(INDEX));
}
