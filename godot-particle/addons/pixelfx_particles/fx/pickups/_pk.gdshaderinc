// Shared by the pickups' canvas shaders (colour and light): the original's colour maths (src/core/color.js mix and
// scale, truncated to whole bytes as its rgb() does), its light falloffs (src/core/painter.js glow, glowRing,
// glowLine; _lib.js pool) added as its light buffer adds them (each add a whole byte, nothing under 0.004), and the
// render's edge fade of light (tools/lib/fxlib.mjs edgeFade).

// colour.js mix(a, b, t)
vec3 js_mix(vec3 a, vec3 b, float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 A = floor(a * 255.0 + 0.5);
	vec3 B = floor(b * 255.0 + 0.5);
	return floor(A + (B - A) * t + 1e-3) / 255.0;
}

// colour.js scale(c, k)
vec3 js_scale(vec3 c, float k) {
	return floor(min(vec3(255.0), floor(c * 255.0 + 0.5) * k) + 1e-3) / 255.0;
}

// Math.round
float js_round(float x) {
	return floor(x + 0.5);
}

int pk_imod(int a, int b) {
	return a - b * int(floor(float(a) / float(b)));
}

// one add() of colour c at strength k: whole bytes, nothing at or under 0.004
vec3 lt_add(vec3 c, float k) {
	if (k <= 0.004) {
		return vec3(0.0);
	}
	return floor(floor(c * 255.0 + 0.5) * k + 1e-4) / 255.0;
}

// painter.js glow(): (1 - d / r)^2 * k at pixel centre pc from a light at `at`
vec3 lt_glow(vec2 pc, vec2 at, float r, vec3 c, float k) {
	if (r < 1.0 || k <= 0.004) {
		return vec3(0.0);
	}
	float f = 1.0 - length(pc - at) / r;
	return f > 0.0 ? lt_add(c, f * f * k) : vec3(0.0);
}

// painter.js glowRing(): light hugging a circle of radius R, falling off over r
vec3 lt_glow_ring(vec2 pc, vec2 at, float R, float r, vec3 c, float k) {
	if (r < 1.0 || k <= 0.004) {
		return vec3(0.0);
	}
	float f = 1.0 - abs(length(pc - at) - R) / r;
	return f > 0.0 ? lt_add(c, f * f * k) : vec3(0.0);
}

// painter.js glowLine()
vec3 lt_glow_line(vec2 pc, vec2 a, vec2 b, float r, vec3 c, float k) {
	if (r < 1.0 || k <= 0.004) {
		return vec3(0.0);
	}
	vec2 e = b - a;
	float u = clamp(dot(pc - a, e) / max(dot(e, e), 1e-9), 0.0, 1.0);
	float f = 1.0 - length(a + e * u - pc) / r;
	return f > 0.0 ? lt_add(c, f * f * k) : vec3(0.0);
}

// _lib.js pool(): light in an ellipse, k (1 - sqrt(d))^2
vec3 lt_pool(vec2 pc, vec2 at, float rx, float ry, vec3 c, float k) {
	if (k <= 0.004 || rx < 1.0) {
		return vec3(0.0);
	}
	vec2 q = (pc - at) / vec2(rx, ry);
	float d = dot(q, q);
	if (d >= 1.0) {
		return vec3(0.0);
	}
	float f = 1.0 - sqrt(d);
	return lt_add(c, f * f * k);
}

// the render fades light over the 8 px next to the canvas's edges (canvas: top-left in effect px, size)
float lt_edge(vec2 pc, vec4 canvas) {
	vec2 q = floor(pc) - canvas.xy;
	float e = min(min(q.x, canvas.z - 1.0 - q.x), min(q.y, canvas.w - 1.0 - q.y));
	if (e >= 8.0) {
		return 1.0;
	}
	float u = (e + 0.5) / 8.0;
	return max(0.0, u * u * (3.0 - 2.0 * u));
}
