// dual_screen_blit.metal
// PVShaders
//
// Metal shaders for DS dual-screen sub-rectangle blitting.
//
// Each screen is rendered by a separate draw call in a single render pass.
// The vertex buffer carries interleaved (NDC-position, UV) data so the vertex
// function needs no uniforms — all per-screen geometry is baked in by the CPU.
//
// Usage pattern (per screen):
//   1. Compute 4 vertices of the form float4(ndcX, ndcY, srcU, srcV)
//      arranged as a triangle-strip  (TL, TR, BL, BR).
//   2. Call setVertexBytes(_:length:index:) with buffer index 0.
//   3. drawPrimitives(.triangleStrip, vertexStart: 0, vertexCount: 4)
//
// The fragment shader samples 'source' at the UV carried from the vertex stage.
// flipY is handled on the CPU (swap V0/V1 when the texture is OpenGL-origin).

#include <metal_stdlib>
using namespace metal;

struct DualScreenVSOut {
    float4 position [[position]];
    float2 texCoord;
};

// vertices[vid] = (NDC.x, NDC.y, UV.u, UV.v)
vertex DualScreenVSOut dual_screen_vs(
    uint              vid      [[vertex_id]],
    constant float4  *vertices [[buffer(0)]])
{
    DualScreenVSOut out;
    out.position = float4(vertices[vid].xy, 0.0f, 1.0f);
    out.texCoord = vertices[vid].zw;
    return out;
}

fragment half4 dual_screen_ps(
    DualScreenVSOut         in     [[stage_in]],
    texture2d<half>         source [[texture(0)]],
    sampler                 samp   [[sampler(0)]])
{
    half4 color = source.sample(samp, in.texCoord);
    color.a = 1.0h;
    return color;
}
