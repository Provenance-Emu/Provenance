#include <metal_stdlib>
using namespace metal;

struct Inputs
{
    float2 fTexCoord [[user(TEXCOORD0)]];
};

fragment half4 blit_ps(Inputs I [[stage_in]], texture2d<half> EmulatedImage [[texture(0)]], sampler Sampler [[sampler(0)]])
{
    half4 output;
    output.rgb = EmulatedImage.sample(Sampler, I.fTexCoord).rgb;
    output.a = 1.0;
    return output;
}
