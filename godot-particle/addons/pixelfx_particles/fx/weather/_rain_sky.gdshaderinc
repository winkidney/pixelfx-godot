// weather/rain's wet floor and mist (rain.js floor(), mist()): pass_ 1 the floor (a lit lip over a dark line, a
// dark sheen, the puddles holding the sky, a glint sliding along each); 2 the mist kicked up by the rain, drifting
// low along the ground in soft bands with lit crests; 0 the light of both.
#include "res://addons/pixelfx_particles/fx/weather/_rain.gdshaderinc"

uniform vec2 size = vec2(320.0, 180.0);
uniform vec2 center = vec2(0.0);
uniform vec4 C[8] : source_color;
uniform vec4 crest : source_color = vec4(1.0);
uniform sampler2D M : filter_nearest;
uniform int pass_ = 0;

float mdens(float x, float y) {
	float prof = smooth_(-22.0, -4.0, y) * (1.0 - smooth_(7.0, 10.0, y));
	return prof * (0.62 + (fsample(M, x * 0.45 + (256.0 * t) / D, y * 4.0 + 30.0) - 0.5) * 2.0);
}

// mode: 0 nothing, 1 translucent, 2 opaque
void rain_px(vec2 p, out vec4 c, out int mode, out vec3 l) {
	c = vec4(0.0);
	mode = 0;
	l = vec3(0.0);
	float x = p.x;
	float y = p.y;
	if ((pass_ == 1 || pass_ == 0) && y > 0.0) {
		if (y < 1.0) {
			c = C[4];
			mode = 2;
			l += C[5].rgb * 0.08;
		} else if (y < 2.0) {
			c = C[1];
			mode = 2;
		} else {
			c = vec4(C[0].rgb, 0.55);
			mode = 1;
			for (int i = 0; i < 5; i++) {
				vec3 P = pool(i);
				if (x >= P.x && x < P.y && floor(y) == P.z) {
					bool edge = x < P.x + 2.0 || x >= P.y - 2.0;
					c = edge ? C[3] : C[4];
					mode = 2;
					l = C[5].rgb * 0.06;
				}
			}
		}
		vec2 cell = floor(p);
		for (int i = 0; i < 5; i++) {
			vec3 P = pool(i);
			float gx = floor(P.x + 3.0 + (P.y - P.x - 6.0) * (0.5 + 0.5 * sin((TAU * t) / D + float(i) * 1.9)) + 0.5);
			if (cell == vec2(gx, P.z)) {
				c = C[6];
				mode = 2;
			}
			if (pass_ == 0) l += C[5].rgb * glow_(p, vec2(gx, P.z), 4.0, 0.2);
		}
		if (pass_ == 1) return;
	}
	if ((pass_ == 2 || pass_ == 0) && y > -20.0 && y < 10.0) {
		float d = mdens(x, y);
		if (d < 0.28) return;
		float th = bayer_(x, y) * 0.06;
		if (pass_ == 0) {
			if (d > 0.3) l += C[4].rgb * (d - 0.3) * 0.1;
			return;
		}
		mode = 1;
		if (d > 0.46 + th && mdens(x, y - 1.0) < 0.43) c = vec4(crest.rgb, 0.5);
		else c = vec4((d > 0.58 + th ? C[4] : C[3]).rgb, clamp((d - 0.28) * 1.6, 0.0, 1.0) * 0.5);
	}
}
