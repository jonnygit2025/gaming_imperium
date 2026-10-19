shader_type spatial;
// Alberi della mappa di campagna (MultiMesh a blocchi). Un solo modello (tronco + doppio cono)
// diventa latifoglia, conifera o pino domestico secondo INSTANCE_CUSTOM.a:
//   0 latifoglia · 0,5 pino domestico (chioma piatta e alta) · 1 conifera (cono slanciato).
// INSTANCE_CUSTOM.r = tinta, .g = fase dell'ondeggiamento.
// Lontano dalla telecamera gli alberi si rimpiccioliscono fino a sparire: niente comparse
// improvvise e nessun costo di trasparenza.
render_mode diffuse_burley, cull_back;

uniform float fade_start = 18.0;
uniform float fade_end = 30.0;
uniform float winter = 0.0;

varying vec3 v_color;

void vertex() {
	float kind = INSTANCE_CUSTOM.a;
	float crown = UV.y;
	float t = UV.x; // altezza relativa nella chioma
	vec3 v = VERTEX;
	if (crown > 0.5) {
		if (kind > 0.75) {
			// conifera: anello largo in basso, punta alta e sottile
			if (t > 0.9) {
				v = vec3(0.0, 1.2, 0.0);
			} else if (t < 0.1) {
				v = vec3(0.0, 0.2, 0.0);
			} else {
				v = vec3(v.x * 0.8, 0.27, v.z * 0.8);
			}
		} else if (kind > 0.25) {
			// pino domestico: ombrello piatto in alto
			v.y = 0.82 + (v.y - 0.55) * 0.32;
			v.xz *= 1.35;
		}
	} else if (kind > 0.25 && kind < 0.75) {
		v.y *= 2.1; // tronco più alto per il pino
	}
	// ondeggiamento leggero della chioma
	v.x += sin(TIME * 1.3 + INSTANCE_CUSTOM.g * 6.28) * 0.015 * crown * t;
	// rimpicciolisce con la distanza
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - origin);
	float s = 1.0 - smoothstep(fade_start, fade_end, d);
	VERTEX = v * s;

	vec3 c = COLOR.rgb * INSTANCE_CUSTOM.r;
	if (crown > 0.5) {
		if (kind > 0.75) {
			c *= vec3(0.8, 0.9, 0.82); // aghi più scuri e freddi
		} else if (kind > 0.25) {
			c *= vec3(0.85, 0.95, 0.75);
		} else {
			// latifoglie d'inverno: rami spogli marrone-grigi
			c = mix(c, vec3(0.5, 0.44, 0.36), winter * 0.8);
		}
	}
	v_color = c;
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 0.9;
}
