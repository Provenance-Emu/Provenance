#version 150
uniform sampler2D image;
uniform sampler2D previous_image;
uniform int frame_blending_mode;

uniform vec2 output_resolution;
uniform vec2 origin;

#define equal(x, y) ((x) == (y))
#define inequal(x, y) ((x) != (y))
#define STATIC
#define GAMMA (2.2)

out vec4 frag_color;

vec4 _texture(sampler2D t, vec2 pos)
{
    return pow(texture(t, pos), vec4(GAMMA));
}

#define texture _texture

#line 1
{filter}


#define BLEND_BIAS (2.0/5.0)

#define DISABLED 0
#define SIMPLE 1
#define ACCURATE 2
#define ACCURATE_EVEN ACCURATE
#define ACCURATE_ODD 3

void main()
{
    vec2 position = gl_FragCoord.xy - origin;
    position /= output_resolution;
    position.y = 1 - position.y;
    vec2 input_resolution = textureSize(image, 0);

    float ratio;
    switch (frame_blending_mode) {
        default:
        case DISABLED:
            frag_color = pow(scale(image, position, input_resolution, output_resolution), vec4(1.0 / GAMMA));
            return;
        case SIMPLE:
            ratio = 0.5;
            break;
        case ACCURATE_EVEN:
            if ((int(position.y * input_resolution.y) & 1) == 0) {
                ratio = BLEND_BIAS;
            }
            else {
                ratio = 1 - BLEND_BIAS;
            }
            break;
        case ACCURATE_ODD:
            if ((int(position.y * input_resolution.y) & 1) == 0) {
                ratio = 1 - BLEND_BIAS;
            }
            else {
                ratio = BLEND_BIAS;
            }
            break;
    }

    frag_color = pow(mix(scale(image, position, input_resolution, output_resolution),
                         scale(previous_image, position, input_resolution, output_resolution), ratio), vec4(1.0 / GAMMA));

}
