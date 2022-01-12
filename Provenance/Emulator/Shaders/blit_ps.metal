#include <metal_stdlib>
using namespace metal;

struct Inputs
{
    float2 fTexCoord [[user(TEXCOORD0)]];
};

fragment float4 blit_ps(Inputs I [[stage_in]], texture2d<float> EmulatedImage [[texture(0)]], sampler Sampler [[sampler(0)]])
{
    float4 output;
    output.rgb = EmulatedImage.sample(Sampler, I.fTexCoord, level(0.0)).rgb;
    output.a = 1.0;
    return output;
}
