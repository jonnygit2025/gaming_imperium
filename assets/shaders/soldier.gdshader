shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Soldati disegnati con MultiMesh. L'animazione è fatta qui, sulla scheda video:
// la CPU non tocca i singoli soldati.
// INSTANCE_CUSTOM: rgb = colore della fazione, a = fase (0..0.5 fermo, 0.5..1 in marcia).
// UV.x = 1 sulle parti da tingere (tunica, scudo).

uniform float step_rate = 7.0;
uniform float leg_top = 0.8;
uniform bool quadruped = false;

varying vec3 v_color;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float moving = step(0.5, cd.a);
	float phase = fract(cd.a * 2.0) * 6.28318 + TIME * step_rate;
	float s = sin(phase);
	float leg = clamp((leg_top - VERTEX.y) / leg_top, 0.0, 1.0);
	float side = VERTEX.x > 0.0 ? 1.0 : -1.0;
	if (quadruped) {
		side *= VERTEX.z > 0.0 ? 1.0 : -1.0;
	}
	VERTEX.z += s * side * leg * 0.28 * moving;
	// Leggero dondolio del corpo, anche da fermi (respiro, peso che si sposta).
	float idle = sin(TIME * 1.7 + cd.a * 40.0) * 0.012;
	VERTEX.y += (abs(s) * 0.05 * moving + idle) * (1.0 - leg);
	vec3 base = COLOR.rgb;
	v_color = mix(base, cd.rgb * (0.55 + 0.45 * base.r), UV.x);
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 0.9;
}
