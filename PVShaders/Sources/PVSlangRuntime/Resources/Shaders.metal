// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <metal_stdlib>
#include <simd/simd.h>

typedef enum
{
    BufferIndexUniforms  = 1,
    BufferIndexPositions = 4,
} BufferIndex;

typedef enum
{
    VertexAttributePosition = 0,
    VertexAttributeTexcoord = 1,
    VertexAttributeColor    = 2,
} VertexAttribute;

typedef enum
{
    TextureIndexColor = 0,
} TextureIndex;

typedef enum
{
    SamplerIndexDraw = 0,
} SamplerIndex;

typedef struct
{
    simd_float4 position [[attribute(VertexAttributePosition)]];
    simd_float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct
{
    simd_float4 position [[position]];
    simd_float2 texCoord;
} ColorInOut;

typedef struct
{
    simd_float4x4   projectionMatrix;
    simd_float2     outputSize;
    float time;
    // Final-blit tunables. Field order MUST match the Swift mirror in
    // FilterChain.Uniforms (trailing floats, same order) or the buffer
    // upload misaligns.
    float brightness;   // multiplicative output scale (1.0 = unchanged)
    float gamma;        // pow(color, 1.0/gamma) (1.0 = unchanged)
    float hdrBoost;     // EDR paper-white scale applied once at final blit
} Uniforms;

// Shared final-blit grade: gamma then brightness. Applied in every final-blit
// fragment so brightness/gamma cover every HDR/SDR + shader-on/off combo.
static inline float3 applyGrade(float3 color, constant Uniforms &uniforms)
{
    float g = metal::max(uniforms.gamma, 1e-4);
    return metal::pow(metal::max(color, 0.0), 1.0 / g) * uniforms.brightness;
}


using namespace metal;

#pragma mark - functions using projected coordinates

vertex ColorInOut basic_vertex_proj_tex(const Vertex in [[ stage_in ]],
                                        const device Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;
    out.position = uniforms.projectionMatrix * in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 basic_fragment_proj_tex(ColorInOut in [[stage_in]],
                                        constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                                        texture2d<half> tex          [[ texture(TextureIndexColor) ]],
                                        sampler samp                 [[ sampler(SamplerIndexDraw) ]])
{
    half4 colorSample = tex.sample(samp, in.texCoord.xy);
    return float4(applyGrade(float3(colorSample.rgb), uniforms), float(colorSample.a));
}

// HDR variant: converts sRGB gamma source to linear for EDR/HDR display.
// The CAMetalLayer is RGBA16Float + extendedLinearDisplayP3.
// paperWhiteNits / 80.0 scales SDR content brightness (80 nits = SDR reference white).
fragment float4 basic_fragment_proj_tex_hdr(ColorInOut in [[stage_in]],
                                            constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                                            texture2d<half> tex          [[ texture(TextureIndexColor) ]],
                                            sampler samp                 [[ sampler(SamplerIndexDraw) ]])
{
    half4 sdr = tex.sample(samp, in.texCoord.xy);
    // sRGB gamma → linear (Dreamcast outputs sRGB)
    float3 linear = pow(max(float3(sdr.rgb), 0.0), 2.2);
    // EDR paper-white boost, now a tunable uniform (default 2.5 = 200/80 nits)
    // instead of a hardcoded constant.
    linear *= uniforms.hdrBoost;
    return float4(applyGrade(linear, uniforms), float(sdr.a));
}

// HDR blit for SHADER-CHAIN output on an rgba16Float (EDR) drawable: sRGB→linear
// then the SINGLE end-of-chain EDR boost. The per-pass intermediates are now
// allocated as rgba16Float when HDR is on (see FilterChain.resizeRenderTargets /
// pass.format), so values >1.0 survive the chain and the boost is applied exactly
// ONCE here — never per-pass. This is what was missing: previously the boost was
// disabled entirely to avoid the per-pass double-boost blow-out, which left the
// shader output un-boosted (HDR did nothing with shaders on).
fragment float4 basic_fragment_proj_tex_hdr_linear(ColorInOut in [[stage_in]],
                                            constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                                            texture2d<half> tex          [[ texture(TextureIndexColor) ]],
                                            sampler samp                 [[ sampler(SamplerIndexDraw) ]])
{
    half4 sdr = tex.sample(samp, in.texCoord.xy);
    float3 linear = pow(max(float3(sdr.rgb), 0.0), 2.2);
    linear *= uniforms.hdrBoost;
    return float4(applyGrade(linear, uniforms), float(sdr.a));
}
