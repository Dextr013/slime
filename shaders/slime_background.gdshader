shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.1, 0.1, 0.25, 1.0);
uniform vec4 color2 : source_color = vec4(0.15, 0.15, 0.35, 1.0);
uniform float wave_speed = 0.5;
uniform float wave_frequency = 5.0;
uniform float wave_amplitude = 0.02;

// Функция шума
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Perlin-подобный шум
float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    f = f * f * (3.0 - 2.0 * f);
    
    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    
    // Волны слизи
    float wave1 = sin(uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
    float wave2 = cos(uv.y * wave_frequency * 0.7 + TIME * wave_speed * 0.8) * wave_amplitude;
    
    uv.y += wave1;
    uv.x += wave2;
    
    // Шум для органической текстуры
    float n = smooth_noise(uv * 10.0 + TIME * 0.1);
    n += smooth_noise(uv * 20.0 - TIME * 0.15) * 0.5;
    n += smooth_noise(uv * 40.0 + TIME * 0.2) * 0.25;
    n /= 1.75;
    
    // Градиент сверху вниз
    float gradient = uv.y;
    
    // Смешиваем цвета
    vec4 color = mix(color1, color2, gradient + n * 0.3);
    
    // Добавляем легкое свечение
    float glow = sin(TIME * 2.0 + uv.x * 3.0 + uv.y * 2.0) * 0.05 + 0.95;
    color.rgb *= glow;
    
    COLOR = color;
}