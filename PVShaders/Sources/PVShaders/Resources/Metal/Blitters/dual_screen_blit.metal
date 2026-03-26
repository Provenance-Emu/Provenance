// dual_screen_blit.metal
// PVShaders
//
// Canonical Metal shaders for the dual-screen sub-rectangle renderer.
//
// These functions are the authoritative source for the shaders used in
// PVMetalViewController+DualScreen.  The identical source is also embedded
// as the inline string `PVMetalViewController.dualScreenShaderSource` so
// that it can be compiled at runtime via `device.makeLibrary(source:)` on
// any device regardless of bundle access.
//
// Vertex input: buffer(0) holds an array of float4 where
//   .xy = clip-space (NDC) position
//   .zw = texture UV coordinate
//
// A four-vertex triangle strip draws one screen quad per draw call.

#include <metal_stdlib>
using namespace metal;

struct DSVSOut {
    float4 position [[position]];
    float2 texCoord;
};

/// Pass-through vertex shader: unpacks (NDC.xy, UV.zw) from a flat float4 array.
vertex DSVSOut dual_screen_vs(
    uint             vid      [[vertex_id]],
    constant float4 *vertices [[buffer(0)]])
{
    DSVSOut out;
    out.position = float4(vertices[vid].xy, 0.0f, 1.0f);
    out.texCoord = vertices[vid].zw;
    return out;
}

/// Fragment shader: samples the combined DS framebuffer texture at the UV
/// interpolated by the vertex shader.  A constexpr sampler with linear
/// filtering and clamp-to-edge is used so there are no sampler bindings
/// required from the host.
fragment half4 dual_screen_ps(
    DSVSOut         in     [[stage_in]],
    texture2d<half> source [[texture(0)]])
{
    constexpr sampler s(coord::normalized,
                        address::clamp_to_edge,
                        filter::linear);
    half4 c = source.sample(s, in.texCoord);
    c.a = 1.0h;
    return c;
}
