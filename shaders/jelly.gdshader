shader_type canvas_item;

uniform float wobble_amount = 0.1;
uniform float wobble_speed = 5.0;
uniform vec4 slime_color : source_color = vec4(0.4, 1.0, 0.4, 1.0);
uniform float shine_intensity = 0.3;
uniform float squish_x = 1.0;
uniform float squish_y = 1.0;

void fragment() {
    vec2 uv = UV;
    
    // Применяем сквош
    uv.x = (uv.x - 0.5) / squish_x + 0.5;
    uv.y = (uv.y - 0.5) / squish_y + 0.5;
    
    // Желейное колебание
    float wobble = sin(TIME * wobble_speed + uv.y * 10.0) * wobble_amount;
    uv.x += wobble;
    
    // Рассчитываем расстояние от центра для круглой формы
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    
    // Создаем круглую маску
    float circle = smoothstep(0.5, 0.45, dist);
    
    // Базовый цвет слайма
    vec4 color = slime_color;
    
    // Добавляем блеск (светлая область сверху)
    float shine_pos = uv.y - 0.2 + wobble * 0.5;
    float shine = smoothstep(0.3, 0.1, shine_pos) * shine_intensity;
    color.rgb += vec3(shine);
    
    // Добавляем градиент (затемнение снизу)
    float gradient = smoothstep(0.8, 0.3, uv.y);
    color.rgb *= 0.7 + gradient * 0.3;
    
    // Добавляем контур
    float outline = smoothstep(0.48, 0.45, dist) - smoothstep(0.5, 0.48, dist);
    color.rgb = mix(color.rgb, color.rgb * 0.5, outline);
    
    // Применяем маску и альфа
    color.a *= circle;
    
    COLOR = color;
}