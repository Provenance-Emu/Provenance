#define SCANLINE_DEPTH 0.25
#define BLOOM 0.4

STATIC vec4 scale(sampler2D image, vec2 position, vec2 input_resolution, vec2 output_resolution)
{
    vec2 pixel = position * input_resolution - vec2(0.5, 0.5);

    vec4 q11 = texture(image, (floor(pixel) + 0.5) / input_resolution);
    vec4 q12 = texture(image, (vec2(floor(pixel.x), ceil(pixel.y)) + 0.5) / input_resolution);
    vec4 q21 = texture(image, (vec2(ceil(pixel.x), floor(pixel.y)) + 0.5) / input_resolution);
    vec4 q22 = texture(image, (ceil(pixel) + 0.5) / input_resolution);

    vec2 s = smoothstep(0., 1., fract(pixel));

    vec4 r1 = mix(q11, q21, s.x);
    vec4 r2 = mix(q12, q22, s.x);
    
    vec2 pos = fract(position * input_resolution);
    vec2 sub_pos = fract(position * input_resolution * 6);

    float multiplier = 1.0;
    
    if (pos.y < 1.0 / 6.0) {
        multiplier *= sub_pos.y * SCANLINE_DEPTH + (1 - SCANLINE_DEPTH);
    }
    else if (pos.y > 5.0 / 6.0) {
        multiplier *= (1.0 - sub_pos.y) * SCANLINE_DEPTH + (1 - SCANLINE_DEPTH);
    }
    
    if (pos.x < 1.0 / 6.0) {
        multiplier *= sub_pos.x * SCANLINE_DEPTH + (1 - SCANLINE_DEPTH);
    }
    else if (pos.x > 5.0 / 6.0) {
        multiplier *= (1.0 - sub_pos.x) * SCANLINE_DEPTH + (1 - SCANLINE_DEPTH);
    }

    vec4 pre_shadow = mix(texture(image, position) * multiplier, mix(r1, r2, s.y), BLOOM);
    pixel += vec2(-0.6, -0.8);
    
    q11 = texture(image, (floor(pixel) + 0.5) / input_resolution);
    q12 = texture(image, (vec2(floor(pixel.x), ceil(pixel.y)) + 0.5) / input_resolution);
    q21 = texture(image, (vec2(ceil(pixel.x), floor(pixel.y)) + 0.5) / input_resolution);
    q22 = texture(image, (ceil(pixel) + 0.5) / input_resolution);
   
    r1 = mix(q11, q21, fract(pixel.x));
    r2 = mix(q12, q22, fract(pixel.x));
    
    vec4 shadow = mix(r1, r2, fract(pixel.y));
    return mix(min(shadow, pre_shadow), pre_shadow, 0.75);
}
