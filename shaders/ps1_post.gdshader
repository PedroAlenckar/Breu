shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 target_resolution = vec2(320.0, 240.0);
uniform float color_depth = 24.0;
uniform float dither_strength = 0.025;
uniform float vignette_strength = 0.55;
uniform float scare_intensity : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 4x4 Bayer matrix for classic PS1 dithering
float bayer4x4(vec2 uv) {
	int x = int(mod(uv.x, 4.0));
	int y = int(mod(uv.y, 4.0));
	int index = x + y * 4;
	float bayer[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	);
	return (bayer[index] / 16.0) - 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// PS1 horror glitch/tearing during jumpscares or door struggles
	if (scare_intensity > 0.001) {
		float line_noise = hash12(vec2(floor(uv.y * 120.0), floor(TIME * 40.0))) - 0.5;
		uv.x += line_noise * 0.065 * scare_intensity;
	}
	
	vec2 grid_uv = floor(uv * target_resolution) / target_resolution;
	vec2 pixel_coord = floor(uv * target_resolution);
	
	vec4 col = texture(screen_texture, clamp(grid_uv, 0.001, 0.999));
	
	if (scare_intensity > 0.001) {
		float split = 0.012 * scare_intensity;
		col.r = texture(screen_texture, clamp(grid_uv + vec2(split, 0.0), 0.001, 0.999)).r;
		col.b = texture(screen_texture, clamp(grid_uv - vec2(split, 0.0), 0.001, 0.999)).b;
		float grain = (hash12(pixel_coord + vec2(TIME * 100.0)) - 0.5) * 0.45 * scare_intensity;
		col.rgb += vec3(grain);
	}
	
	float dither = bayer4x4(pixel_coord) * dither_strength;
	col.rgb += vec3(dither);
	col.rgb = floor(col.rgb * color_depth + 0.5) / color_depth;
	
	float scanline = sin(pixel_coord.y * 3.14159) * 0.04;
	col.rgb -= vec3(scanline);
	
	vec2 vig_uv = SCREEN_UV * (1.0 - SCREEN_UV.yx);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = pow(clamp(vig, 0.0, 1.0), vignette_strength);
	col.rgb *= vig;
	
	COLOR = vec4(clamp(col.rgb, 0.0, 1.0), 1.0);
}
