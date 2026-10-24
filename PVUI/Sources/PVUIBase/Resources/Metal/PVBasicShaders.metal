// PVBasicShaders.metal
//
// Precompiled basic vertex/fragment pair used by PVMetalViewController to blit
// emulator framebuffers. Shipping this as a compiled .metallib lets the Swift
// code call `device.makeDefaultLibrary(bundle: Bundle.module)` instead of
// `device.makeLibrary(source:)`, dropping ~300–500 ms of cold-launch shader
// compilation on iPhone (see PROVENANCE-18N).
//
// The functions and their attribute layouts must stay identical to the inline
// source strings in PVMetalViewController.createBasicShaders /
// createBasicShadersWithDefaultLibrary, since both are interchangeable when
// the bundled library is missing and the runtime source compile kicks in.

#include <metal_stdlib>
using namespace metal;

// MARK: - Picture sampling

// Must stay identical to PVMetalViewController.pictureSamplingSource.
// Sharp bilinear draws each source texel as a flat block and blends only a
// one-output-pixel band at its edges; fwidth gives texels per output pixel.
static inline float4 pv_sample_picture(texture2d<float> tex, sampler s, float2 uv, uint sharpBilinear) {
    float2 texSize = float2(tex.get_width(), tex.get_height());
    float2 texel = uv * texSize;
    float2 scale = max(1.0 / max(fwidth(texel), float2(1e-5)), float2(1.0));
    if (sharpBilinear == 0) {
        return tex.sample(s, uv);
    }
    float2 regionRange = 0.5 - 0.5 / scale;
    float2 centerDist = fract(texel) - 0.5;
    float2 f = (centerDist - clamp(centerDist, -regionRange, regionRange)) * scale + 0.5;
    return tex.sample(s, (floor(texel) + f) / texSize);
}

// MARK: - Vertex / fragment used by createBasicShaders()

struct PVBasicVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex PVBasicVertexOut basic_vertex(uint vertexID [[vertex_id]],
                                     constant bool &flipY [[buffer(1)]]) {
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };

    float2 texCoords[4] = {
        float2(0.0, 0.0), // Bottom-left
        float2(1.0, 0.0), // Bottom-right
        float2(0.0, 1.0), // Top-left
        float2(1.0, 1.0)  // Top-right
    };

    if (flipY) {
        texCoords[0].y = 1.0 - texCoords[0].y;
        texCoords[1].y = 1.0 - texCoords[1].y;
        texCoords[2].y = 1.0 - texCoords[2].y;
        texCoords[3].y = 1.0 - texCoords[3].y;
    }

    PVBasicVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 basic_fragment(PVBasicVertexOut in [[stage_in]],
                               texture2d<float> texture [[texture(0)]],
                               sampler textureSampler [[sampler(0)]],
                               constant uint &sharpBilinear [[buffer(0)]]) {
    return pv_sample_picture(texture, textureSampler, in.texCoord, sharpBilinear);
}

// MARK: - Vertex / fragment used by createBasicShadersWithDefaultLibrary()

vertex PVBasicVertexOut vertexShader(uint vid [[vertex_id]]) {
    const float2 vertices[] = {
        float2(-1, -1),
        float2(-1,  1),
        float2( 1, -1),
        float2( 1,  1)
    };

    const float2 texCoords[] = {
        float2(0, 1),
        float2(0, 0),
        float2(1, 1),
        float2(1, 0)
    };

    PVBasicVertexOut out;
    out.position = float4(vertices[vid], 0, 1);
    out.texCoord = texCoords[vid];
    return out;
}

fragment float4 fragmentShader(PVBasicVertexOut in [[stage_in]],
                               texture2d<float> tex [[texture(0)]],
                               sampler s [[sampler(0)]],
                               constant uint &sharpBilinear [[buffer(0)]]) {
    return pv_sample_picture(tex, s, in.texCoord, sharpBilinear);
}
