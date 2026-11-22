// diamond-wipe's diamonds (colour layer): faceted, rims lit from the top left, ridges with a sheen, cooling to ink.
shader_type canvas_item;

#include "res://addons/pixelfx_particles/shaders/pixel.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_tr.gdshaderinc"
#include "res://addons/pixelfx_particles/fx/transitions/_diamond.gdshaderinc"

void fragment() {
	vec2 px = floor(UV * vec2(TR_W, TR_H));
	vec3 col = vec3(-1.0);
	for (int n = 0; n < count; n++) {
		vec4 d = texelFetch(lat, ivec2(n, 0), 0);
		float hd;
		float heat;
		dw_state(d, hd, heat);
		if (hd < 0.5 || !dw_in(px, d, hd)) {
			continue;
		}
		if (heat <= 0.0) {
			col = ink.rgb;
			continue;
		}
		float dy = px.y + 0.5 - d.y;
		float dx = px.x + 0.5 - d.x;
		float e = hd - abs(dx) - abs(dy);
		int q = (dy < 0.0 ? 0 : 2) + (dx < 0.0 ? 0 : 1);
		bool vr = dx > -1.0 && dx <= 0.0;
		bool hr = dy > -1.0 && dy <= 0.0;
		int st = heat > 0.66 ? 0 : heat > 0.33 ? 1 : 2;
		vec3 c;
		if (e < 1.0) {
			vec3 r;
			bool hot = heat > 0.5;
			if (q == 0) {
				r = hot ? vec3(1.0) : C[6].rgb;
			} else if (q == 1) {
				r = hot ? C[6].rgb : C[5].rgb;
			} else if (q == 2) {
				r = hot ? C[5].rgb : C[4].rgb;
			} else {
				r = hot ? C[4].rgb : C[3].rgb;
			}
			c = heat > 0.15 ? r : ink.rgb;
		} else if (e < 2.0 && q == 0 && heat > 0.4) {
			c = C[5].rgb;
		} else if ((vr || hr) && heat > 0.3) {
			bool tip = vr && dy < -hd + 4.0;
			bool sheen = abs(mod(px.x + px.y - t * 260.0, 90.0) - 45.0) < 3.0;
			c = (tip || (sheen && heat > 0.5)) ? vec3(1.0) : (vr && dy < 0.0) ? (heat > 0.6 ? C[6].rgb : C[5].rgb) : (heat > 0.6 ? C[3].rgb : C[2].rgb);
		} else if (heat > 0.15) {
			// the faces: top left, top right, bottom left, bottom right, each cooling a step at a time
			int f = q * 3 + st;
			vec3 face[12] = vec3[](C[2].rgb, C[1].rgb, C[0].rgb, C[1].rgb, C[0].rgb, C[0].rgb, C[1].rgb, C[0].rgb, C[0].rgb, C[0].rgb, C[0].rgb, ink.rgb);
			c = face[f];
		} else {
			c = ink.rgb;
		}
		col = c;
	}
	if (col.r < 0.0) {
		discard;
	}
	vec4 o = vec4(col, 1.0);
	if (pfx_pixel(o, FRAGCOORD.xy)) {
		discard;
	}
	COLOR = o;
}
