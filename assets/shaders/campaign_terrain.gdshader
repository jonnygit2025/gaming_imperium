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
// details_tex R = distanza dalla strada (texel × road_scale), G = campi coltivati
uniform sampler2D details_tex : filter_linear, repeat_disable;
uniform float road_scale = 16.0;
// roads_tex RG = punto della strada più vicina (scarto dal centro del texel, texel × 32 + 128),
//           B = direzione del tratto (0..π), A = 1 vicino a una strada
uniform sampler2D roads_tex : filter_nearest, repeat_disable;
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

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Campi coltivati: appezzamenti (orientati secondo la provincia, righe sfalsate) divisi in
// 2-4 strisce; colori di grano, erba, terra arata e maggese; siepi fra gli appezzamenti.
// wpx = unità del mondo per pixel (calcolata fuori dai rami: le derivate dentro un ramo non valgono)
vec3 fields_color(vec2 wp, float province, float winter_amt, float wpx, out float hedge) {
	float ang = province * 2.39996;
	mat2 r = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = r * wp / vec2(0.34, 0.24);
	q.x += hash2(vec2(floor(q.y), 7.0 + province)) * 0.8;
	vec2 parcel = floor(q);
	vec2 f = fract(q);
	float hp = hash2(parcel + province * 0.37);
	float strips = 2.0 + floor(hp * 3.0);
	bool along_x = hash2(parcel * 1.9 + 4.2) > 0.5;
	float sc = along_x ? f.x : f.y;
	float strip = floor(sc * strips);
	float h = hash2(parcel * 3.1 + strip * 17.3 + province);
	vec3 c;
	if (h < 0.3) c = vec3(0.72, 0.64, 0.38);       // grano
	else if (h < 0.55) c = vec3(0.48, 0.55, 0.31); // erba
	else if (h < 0.78) c = vec3(0.52, 0.43, 0.32); // terra arata
	else c = vec3(0.60, 0.58, 0.40);               // maggese
	c *= 0.93 + 0.14 * hash2(parcel * 1.7 + strip + 3.1);
	c = mix(c, vec3(0.50, 0.44, 0.34), winter_amt * 0.65);
	vec2 fw = max(vec2(wpx) / vec2(0.34, 0.24), vec2(1e-4));
	vec2 e = min(f, 1.0 - f) / fw;
	hedge = 1.0 - smoothstep(0.7, 1.7, min(e.x, e.y));
	// confini fra le strisce: appena accennati
	float sf = fract(sc * strips);
	float se = min(sf, 1.0 - sf) / max((along_x ? fw.x : fw.y) * strips, 1e-4);
	hedge = max(hedge, (1.0 - smoothstep(0.5, 1.2, se)) * 0.35);
	return c;
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

	// Campi coltivati attorno agli abitati: solo avvicinandosi (lontano diventerebbero rumore);
	// da lontano non si legge nemmeno la texture.
	float wpx = length(fwidth(world_pos.xz)) * 0.7;          // unità del mondo per pixel
	float ffade = 1.0 - smoothstep(0.03, 0.07, wpx);
	vec2 tsize = vec2(textureSize(roads_tex, 0));
	vec2 tp = uv * tsize;
	float rpx = max(length(fwidth(tp)) * 0.7, 1e-4);          // texel per pixel
	float road_vis = 1.0 - smoothstep(0.9, 2.0, rpx);
	vec4 det = ffade > 0.0 ? texture(details_tex, uv) : vec4(0.0);
	if (det.g > 0.02 && own >= 1.0 && own <= 254.0) {
		float hedge;
		vec3 fc = fields_color(world_pos.xz, own, winter, wpx, hedge);
		float shade = dot(col, vec3(0.3, 0.55, 0.15)) / 0.5;
		fc = fc * clamp(shade, 0.6, 1.25);
		// i campi si fondono con il terreno: niente scacchiera
		fc = mix(col, fc, 0.5);
		fc = mix(fc, fc * 0.7, hedge * 0.7);
		float amt = smoothstep(0.05, 0.6, det.g) * ffade * land * (1.0 - smoothstep(0.25, 0.45, slope));
		col = mix(col, fc, amt);
	}

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

	// Strade: distanza esatta dalla linea (punto più vicino + direzione salvati per texel)
	if (road_vis > 0.0) {
		float vis = road_vis;
		vec4 rv = texture(roads_tex, uv);
		if (rv.a > 0.5) {
			vec2 q = floor(tp) + 0.5 + (rv.rg * 255.0 - 128.0) / 32.0;
			float a = rv.b * 3.14159265;
			vec2 t = vec2(cos(a), sin(a));
			vec2 dq = tp - q;
			float rd = abs(dq.x * t.y - dq.y * t.x);
			float w = max(0.08, 0.85 * rpx);
			float l = line_mask(rd, w, rpx * 0.75);
			float edge = line_mask(rd, w + max(0.05, 0.6 * rpx), rpx * 0.75) - l;
			vec3 road_c = mix(vec3(0.50, 0.41, 0.30), vec3(0.44, 0.39, 0.34), winter);
			col = mix(col, col * 0.7, edge * vis * land * 0.7);
			col = mix(col, road_c * clamp(dot(col, vec3(0.3, 0.55, 0.15)) / 0.45, 0.75, 1.0), l * vis * land);
		}
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
