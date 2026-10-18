shader_type spatial;
// Città ed eserciti della campagna (MultiMesh). Colori per vertice; le parti con UV.x = 1
// prendono il colore della fazione (INSTANCE_CUSTOM.rgb); quelle con UV.y = 1 sono stoffa e
// sventolano. INSTANCE_CUSTOM.a = fase casuale dell'animazione.
render_mode diffuse_burley;

varying vec3 v_color;

void vertex() {
	vec3 base = COLOR.rgb;
	v_color = mix(base, INSTANCE_CUSTOM.rgb * (0.6 + 0.4 * base.r), UV.x);
	if (UV.y > 0.5) {
		float ph = INSTANCE_CUSTOM.a * 6.2831;
		float k = max(VERTEX.x + 0.6, 0.0);
		VERTEX.z += sin(TIME * 3.2 + ph + VERTEX.x * 3.5) * 0.08 * k;
	}
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 0.85;
}
