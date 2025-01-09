#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_math>

using namespace metal;

/* For GLSL compatibility */
typedef float2 vec2;
typedef float3 vec3;
typedef float4 vec4;
typedef texture2d<half> sampler2D;
#define equal(x, y) all((x) == (y))
#define inequal(x, y) any((x) != (y))
#define STATIC static
#define GAMMA (2.2)

typedef struct {
    float4 position [[position]];
    float2 texcoords;
} rasterizer_data;

// Vertex Function
vertex rasterizer_data vertex_shader(uint index [[ vertex_id ]],
                                     constant vector_float2 *vertices [[ buffer(0) ]])
{
    rasterizer_data out;

    out.position.xy = vertices[index].xy;
    out.position.z = 0.0;
    out.position.w = 1.0;
    out.texcoords = (vertices[index].xy + float2(1, 1)) / 2.0;

    return out;
}


static inline float4 texture(texture2d<half> texture, float2 pos)
{
    constexpr sampler texture_sampler;
    return pow(float4(texture.sample(texture_sampler, pos)), GAMMA);
}

#line 1
{filter}

#define BLEND_BIAS (2.0/5.0)

enum frame_blending_mode {
    DISABLED,
    SIMPLE,
    ACCURATE,
    ACCURATE_EVEN = ACCURATE,
    ACCURATE_ODD,
};

fragment float4 fragment_shader(rasterizer_data in [[stage_in]],
                                texture2d<half> image [[ texture(0) ]],
                                texture2d<half> previous_image [[ texture(1) ]],
                                constant enum frame_blending_mode *frame_blending_mode [[ buffer(0) ]],
                                constant float2 *output_resolution [[ buffer(1) ]])
{
    float2 input_resolution = float2(image.get_width(), image.get_height());

    in.texcoords.y = 1 - in.texcoords.y;
    float ratio;
    switch (*frame_blending_mode) {
        default:
        case DISABLED:
            return scale(image, in.texcoords, input_resolution, *output_resolution);
        case SIMPLE:
            ratio = 0.5;
            break;
        case ACCURATE_EVEN:
            if (((int)(in.texcoords.y * input_resolution.y) & 1) == 0) {
                ratio = BLEND_BIAS;
            }
            else {
                ratio = 1 - BLEND_BIAS;
            }
            break;
        case ACCURATE_ODD:
            if (((int)(in.texcoords.y * input_resolution.y) & 1) == 0) {
                ratio = 1 - BLEND_BIAS;
            }
            else {
                ratio = BLEND_BIAS;
            }
            break;
    }
    
    return pow(mix(scale(image, in.texcoords, input_resolution, *output_resolution),
               scale(previous_image, in.texcoords, input_resolution, *output_resolution), ratio), 1 / GAMMA);
}

