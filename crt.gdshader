shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float glitch_frequency : hint_range(0.1, 10.0) = 2.0;
uniform float glitch_duration : hint_range(0.01, 0.5) = 0.1;

uniform float red_displacement : hint_range(0.0, 0.1) = 0.02;
uniform float green_displacement : hint_range(0.0, 0.1) = 0.02;
uniform float blue_displacement : hint_range(0.0, 0.1) = 0.02;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float slice_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float ghost_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float negative_intensity : hint_range(0.0, 1.0) = 0.0;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = SCREEN_UV;

    vec4 base_color = texture(screen_texture, uv);
    vec4 final_color = base_color;
    
    float glitch_time = TIME * glitch_frequency;
    float glitch_noise = noise(vec2(glitch_time, 0.0));
    float glitch_active = step(1.0 - intensity, glitch_noise);
    
    if (glitch_active > 0.5) {
        float slice_y = random(vec2(glitch_time * 10.0, 0.0));
        if (abs(uv.y - slice_y) < 0.02 * slice_intensity) {
            float slice_offset = (random(vec2(glitch_time * 15.0, 0.0)) - 0.5) * 0.1 * slice_intensity;
            uv.x += slice_offset;
        }
        
        float vertical_shift = random(vec2(glitch_time * 8.0, 0.0)) * 0.05 * intensity;
        uv.y += vertical_shift;
        
        float wave = sin(uv.y * 100.0 + glitch_time * 5.0) * 0.01 * intensity;
        uv.x += wave;
        
        final_color = texture(screen_texture, uv);
    }
    
    float shift_amount = red_displacement * glitch_active;
    vec4 red_channel   = texture(screen_texture, uv + vec2( shift_amount, 0.0));
    vec4 green_channel = texture(screen_texture, uv + vec2(-green_displacement * glitch_active, 0.0));
    vec4 blue_channel  = texture(screen_texture, uv + vec2( blue_displacement * glitch_active, 0.0));
    
    final_color.r = mix(final_color.r, red_channel.r, glitch_active);
    final_color.g = mix(final_color.g, green_channel.g, glitch_active);
    final_color.b = mix(final_color.b, blue_channel.b, glitch_active);
    
    float scanline = sin(uv.y * 300.0 + glitch_time * 2.0) * 0.5 + 0.5;
    final_color.rgb *= 1.0 - scanline * scanline_intensity * intensity;
    
    float static_noise = random(uv + glitch_time) * noise_intensity * glitch_active;
    final_color.rgb += static_noise;
    
    if (ghost_intensity > 0.0) {
        vec4 ghost_color = texture(screen_texture, uv + vec2(0.01, 0.01)) * ghost_intensity;
        final_color.rgb = mix(final_color.rgb, ghost_color.rgb, ghost_intensity * 0.5);
    }
    
    if (negative_intensity > 0.0) {
        vec4 negative_color = vec4(1.0 - final_color.rgb, final_color.a);
        final_color.rgb = mix(final_color.rgb, negative_color.rgb, negative_intensity * glitch_active);
    }
    
    float glow = glitch_active * 0.2 * intensity;
    final_color.rgb += glow;
    
    COLOR = final_color;
}