shader_type canvas_item;
// Sfondo dei menu: penombra calda, foschia che scorre lenta e vignettatura.
// Economico: poche operazioni per pixel, funziona anche col renderer Compatibilità.

uniform vec4 color_top : source_color = vec4(0.16, 0.12, 0.09, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.05, 0.04, 0.035, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.22, 0.16, 1.0);
uniform vec2 glow_center = vec2(0.72, 0.42);
uniform float speed = 0.015;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(color_top.rgb, color_bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	float aspect = 1.0 / max(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 0.0001);
	vec2 p = vec2(uv.x * aspect, uv.y);
	float d = distance(p, vec2(glow_center.x * aspect, glow_center.y));
	col += glow_color.rgb * 0.22 * exp(-d * 2.4);
	float t = TIME * speed;
	float mist = fbm(p * 2.2 + vec2(t, -t * 0.4));
	col += vec3(0.09, 0.07, 0.05) * smoothstep(0.45, 0.9, mist);
	// Grana leggera, come una pergamena.
	col *= 0.96 + 0.04 * hash(floor(FRAGCOORD.xy * 0.5));
	// Vignettatura
	vec2 c = uv - 0.5;
	col *= 1.0 - dot(c, c) * 1.1;
	COLOR = vec4(col, 1.0);
}
