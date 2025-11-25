#include <metal_stdlib>
using namespace metal;

constant bool FlipY [[function_constant(0)]];

#pragma pack(push,4)
struct Outputs
{
    float4 outPos [[position]];
    float2 fTexCoord [[user(TEXCOORD0)]];
};
#pragma pack(pop)

vertex Outputs fullscreen_vs(uint base [[base_vertex]], uint vid [[vertex_id]])
{
    uint in_vid = (vid - base);
    float2 uv = float2(float(((in_vid << 1u) & 2u)), float((in_vid & 2u)));
    float2 pos;
    if (FlipY) // For dealing with textures generated from OpenGL
        pos = ((uv * float2(2.0f, 2.0f)) + float2(-1.0f, -1.0f));
    else
        pos = ((uv * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f));
    
    Outputs O;
    O.outPos = float4(pos.x, pos.y, 0.0f, 1.0f);
    O.fTexCoord = uv;
    return O;
}

