shader_type canvas_item;
// Minimappa: sfondo precalcolato + colori delle fazioni dalla stessa tavolozza del terreno.

uniform sampler2D ids_tex : filter_nearest, repeat_disable;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;
uniform float selected_index = -1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 ids = texture(ids_tex, UV);
	float own = floor(ids.r * 255.0 + 0.5);
	float land = ids.b;
	vec3 col = base.rgb;
	if (land > 0.5 && own >= 1.0 && own <= 254.0) {
		vec4 p = texture(palette_tex, vec2((own + 0.5) / 256.0, 0.25));
		col = mix(col, p.rgb, 0.55);
		// bordo tra province: confronta con i vicini a un passo di texel della minimappa
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n1 = floor(texture(ids_tex, UV + vec2(px.x, 0.0)).r * 255.0 + 0.5);
		float n2 = floor(texture(ids_tex, UV + vec2(0.0, px.y)).r * 255.0 + 0.5);
		if (n1 != own || n2 != own) {
			col *= 0.55;
		}
		if (abs(own - selected_index) < 0.5) {
			col = mix(col, vec3(1.0, 0.86, 0.45), 0.55);
		}
	} else if (land > 0.5 && own > 254.5) {
		col *= 0.55;
	}
	COLOR = vec4(col, 1.0);
}
