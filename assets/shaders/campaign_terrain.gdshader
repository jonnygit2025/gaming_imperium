shader_type spatial;
// Terreno della mappa di campagna (compatibile con il renderer Compatibilità / OpenGL 3.3).
// Colori delle fazioni con UNA tavolozza: ids_tex dice di quale provincia è il pixel,
// palette_tex dice chi la possiede. Cambiare padrone = aggiornare un pixel della tavolozza.
//   ids_tex    R = provincia (0 mare, 255 terre esterne), G = provincia oltre il confine più vicino
//   fields_tex R = distanza dal confine (texel × 15,9), G = distanza dalla costa (128 ± texel × 6),
//              B = laghi
//   palette_tex riga 0: colore del padrone + indice del padrone in A
//               riga 1: R = nemica del giocatore, G = del giocatore
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D ids_tex : filter_nearest, repeat_disable;
uniform sampler2D fields_tex : filter_linear, repeat_disable;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_min = vec2(-271.6, -200.1);
uniform vec2 map_size = vec2(543.2, 400.3);
uniform float vertical_units_per_km = 0.6;
uniform float selected_index = -1.0;
uniform float hover_index = -1.0;
uniform float tint_strength = 0.3;
uniform float winter = 0.0;
uniform float facets = 0.4;
uniform float enemy_highlight = 1.0;
uniform bool debug_grey = false;
uniform vec3 shallow_color : source_color = vec3(0.12, 0.36, 0.42);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float idx(float v) {
	return floor(v * 255.0 + 0.5);
}

vec4 pal(float index, float row) {
	return texture(palette_tex, vec2((index + 0.5) / 256.0, (row + 0.5) / 2.0));
}

// Linea di larghezza `w` texel attorno a distanza 0, antialiasing con la derivata.
float line_mask(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

void fragment() {
	vec2 uv = (world_pos.xz - map_min) / map_size;
	vec3 col = texture(albedo_tex, uv).rgb;
	// un po' più di contrasto e saturazione rispetto alla texture di base
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = clamp(mix(vec3(lum), col, 1.25) * 1.02, 0.0, 1.0);
	vec4 ids = texture(ids_tex, uv);
	vec4 fld = texture(fields_tex, uv);
	float own = idx(ids.r);
	float nb = idx(ids.g);
	float bd = max(fld.r * 255.0 / 15.9 - 0.5, 0.0);   // texel dal confine
	float coast = (fld.g * 255.0 - 128.0) / 6.0;        // texel dalla costa (+ terra)
	float lake = fld.b;

	// Dettaglio fine da vicino (la texture dei colori ha 2,6 km per pixel)
	float near_f = 1.0 - smoothstep(0.02, 0.12, length(fwidth(uv)) * 512.0);
	float detail = texture(detail_tex, world_pos.xz * 0.35).r * 0.6 + texture(detail_tex, world_pos.xz * 1.3).b * 0.4;
	col *= 1.0 + (detail - 0.5) * 0.35 * near_f;

	// Pendenza e quota: roccia sui versanti ripidi, neve in alto (più bassa d'inverno e a nord)
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float km = world_pos.y / vertical_units_per_km;
	col = mix(col, vec3(0.43, 0.40, 0.36), smoothstep(0.18, 0.42, slope) * 0.6);
	float north = clamp(-world_pos.z / 200.0, -1.0, 1.0);
	float snow_line = mix(2.9, 1.7, winter) - north * 0.45;
	float snow = smoothstep(snow_line, snow_line + 0.5, km + (detail - 0.5) * 0.3) * (1.0 - smoothstep(0.35, 0.6, slope) * 0.6);
	col = mix(col, vec3(0.93, 0.94, 0.97), clamp(snow, 0.0, 1.0));

	// Costa netta dal campo di distanza (non dalla mesh): sotto lo zero è acqua bassa.
	float land = smoothstep(-0.35, 0.25, coast);
	float px = max(fwidth(bd), 1e-4);                     // texel per pixel sullo schermo

	bool is_prov = own >= 1.0 && own <= 254.0;
	bool nb_prov = nb >= 1.0 && nb <= 254.0;
	vec4 me = pal(own, 0.0);
	vec4 other = pal(nb, 0.0);
	vec4 flags = pal(own, 1.0);
	float same_owner = (is_prov && nb_prov && abs(me.a - other.a) < 0.002) ? 1.0 : 0.0;
	bool outer = own > 254.5;

	if (outer) {
		float grey = dot(col, vec3(0.3, 0.55, 0.15));
		col = mix(col, vec3(grey), 0.55) * 0.62;
	}
	if (is_prov) {
		col = mix(col, me.rgb, tint_strength * land);
		// alone interno lungo i confini tra fazioni diverse
		float glow = (1.0 - smoothstep(0.0, 6.0, bd)) * (1.0 - same_owner);
		col = mix(col, me.rgb, glow * glow * 0.6 * land);
		// province nemiche del giocatore: alone rosso pulsante
		float enemy = flags.r * enemy_highlight;
		float pulse = 0.75 + 0.25 * sin(TIME * 2.5);
		col = mix(col, vec3(0.85, 0.12, 0.08), enemy * (1.0 - smoothstep(0.0, 12.0, bd)) * 0.35 * pulse * land);
	}

	// Provincia sotto il mouse e provincia selezionata (riempimento, prima delle linee)
	bool sel_in = is_prov && abs(own - selected_index) < 0.5;
	bool sel_out = abs(nb - selected_index) < 0.5;
	if (is_prov && abs(own - hover_index) < 0.5) {
		col = mix(col, vec3(1.0, 0.95, 0.8), 0.12 * land);
	}
	if (sel_in) {
		col = mix(col, vec3(1.0, 0.93, 0.7), 0.16 * land);
	}

	// Confini: sottili tra province della stessa fazione, spessi e colorati tra fazioni diverse.
	if (is_prov || (outer && nb_prov)) {
		if (same_owner > 0.5) {
			float l = line_mask(bd, max(0.7 * px, 0.35), px * 0.75);
			col = mix(col, vec3(0.2, 0.17, 0.12), l * 0.6 * land);
		} else {
			float w = max(2.6 * px, 1.1);
			float l = line_mask(bd, w, px * 0.75);
			// linea scura centrale: copre il passaggio netto tra i due colori
			float edge = line_mask(bd, max(0.9 * px, 0.6), px * 0.75);
			vec3 c = outer ? vec3(0.12, 0.11, 0.1) : me.rgb * 1.2 + 0.06;
			col = mix(col, c, l * land);
			col = mix(col, vec3(0.04), edge * 0.9 * land);
		}
	}

	// selezione: riempimento chiaro dentro, contorno dorato disegnato da entrambi i lati del
	// confine (così segue il campo liscio e non i pixel della mappa degli id)
	if (sel_in || sel_out) {
		float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
		float w = max(1.8 * px, 0.8);
		float l = line_mask(bd, w, px * 0.75);
		// anche lungo la costa della provincia selezionata
		if (sel_in) {
			float pc = max(fwidth(coast), 1e-4);
			l = max(l, line_mask(abs(coast - 0.6), max(1.5 * pc, 0.6), pc * 0.75));
		}
		col = mix(col, vec3(1.0, 0.82, 0.3) * pulse, l * land);
	}

	// Laghi e acqua bassa lungo la costa
	col = mix(col, vec3(0.2, 0.36, 0.44), lake * 0.8);
	col = mix(shallow_color, col, land);

	// Bordo della mappa: sfuma nella nebbia scura
	vec2 e = min(uv, 1.0 - uv) * map_size;
	float edge_fade = smoothstep(0.0, 22.0, min(e.x, e.y));
	col *= mix(0.25, 1.0, edge_fade);

	ALBEDO = debug_grey ? vec3(0.5) : col;
	ROUGHNESS = mix(0.95, 0.25, max(lake, 1.0 - land));
	SPECULAR = mix(0.15, 0.5, max(lake, 1.0 - land));
	// Aspetto low-poly: mescola la normale liscia con quella della faccetta.
	vec3 flat_n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	flat_n *= sign(dot(flat_n, NORMAL) + 1e-4);
	NORMAL = normalize(mix(NORMAL, flat_n, facets));
}
