shader_type spatial;
// Mare leggero per il renderer Compatibilità: nessuna lettura della profondità né riflessi
// dello schermo. Il colore dipende dalla distanza dalla costa (campo precalcolato), le onde
// sono due campionamenti di una piccola texture di rumore che scorre.
// Nessun oggetto proietta ombre sul mare: shadows_disabled evita di leggere la mappa delle
// ombre su ogni pixel d'acqua.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, shadows_disabled;

uniform sampler2D fields_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_min = vec2(-271.6, -200.1);
uniform vec2 map_size = vec2(543.2, 400.3);
uniform vec3 shallow_color : source_color = vec3(0.12, 0.36, 0.42);
uniform vec3 deep_color : source_color = vec3(0.035, 0.12, 0.22);
uniform vec3 edge_color : source_color = vec3(0.03, 0.06, 0.09);
uniform float wave_scale = 0.09;
uniform float wave_strength = 0.35;
uniform float winter = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz - map_min) / map_size;
	bool inside = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	float coast = inside ? (texture(fields_tex, uv).g * 255.0 - 128.0) / 6.0 : -21.0;
	float depth = clamp(-coast / 9.0, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, sqrt(depth));
	col = mix(col, col * vec3(0.9, 0.95, 1.0), winter * 0.5);

	vec2 p = world_pos.xz * wave_scale;
	vec4 n1 = texture(noise_tex, p + vec2(TIME * 0.013, TIME * 0.007));
	vec4 n2 = texture(noise_tex, p * 2.3 - vec2(TIME * 0.011, -TIME * 0.016));
	vec2 slope = (n1.rg - 0.5) + (n2.ba - 0.5) * 0.6;
	// Schiuma sottile lungo la riva
	float foam = (1.0 - smoothstep(0.0, 1.4, -coast)) * smoothstep(0.35, 0.65, n2.r + 0.15 * sin(TIME * 1.3 + world_pos.x * 3.0));
	col = mix(col, vec3(0.75, 0.82, 0.82), foam * 0.35);

	vec2 e = min(uv, 1.0 - uv) * map_size;
	float edge_fade = inside ? smoothstep(0.0, 22.0, min(e.x, e.y)) : 0.0;
	col = mix(edge_color, col, edge_fade);

	ALBEDO = col;
	ROUGHNESS = 0.12;
	SPECULAR = 0.55;
	NORMAL_MAP = normalize(vec3(slope * wave_strength * 2.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
