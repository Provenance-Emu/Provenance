//
//  Converters.metal
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 2/9/2022.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#pragma mark - Structs for pixel conversion

typedef struct
{
    simd_uint2  origin;
    uint        stride;
} BufferUniforms;

#pragma mark - filter kernels, texture to texture

kernel void convert_bgra4444_to_bgra8888(texture2d<ushort, access::read> in  [[ texture(0) ]],
                                         texture2d<half, access::write>  out [[ texture(1) ]],
                                         uint2                           gid [[ thread_position_in_grid ]])
{
    ushort pix  = in.read(gid).r;
    uchar4 pix2 = uchar4(
                         extract_bits(pix,  4, 4),
                         extract_bits(pix,  8, 4),
                         extract_bits(pix, 12, 4),
                         extract_bits(pix,  0, 4)
                         );
    
    out.write(half4(pix2) / 15.0, gid);
}

kernel void convert_rgb565_to_bgra8888(texture2d<ushort, access::read> in  [[ texture(0) ]],
                                       texture2d<half, access::write>  out [[ texture(1) ]],
                                       uint2                           gid [[ thread_position_in_grid ]])
{
    ushort pix  = in.read(gid).r;
    uchar4 pix2 = uchar4(
                         extract_bits(pix, 11, 5),
                         extract_bits(pix,  5, 6),
                         extract_bits(pix,  0, 5),
                         0xf
                         );
    
    out.write(half4(pix2) / half4(0x1f, 0x3f, 0x1f, 0xf), gid);
}

#pragma mark - filter kernels, buffer to texture

kernel void convert_bgra4444_to_bgra8888_buf(device ushort * in  [[ buffer(0) ]],
                                             constant BufferUniforms & uniforms  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid  [[ thread_position_in_grid ]])
{
    ushort pix  = in[(gid.y + uniforms.origin.y) * uniforms.stride + uniforms.origin.x + gid.x];
    uchar4 pix2 = uchar4(extract_bits(pix,  4, 4),
                         extract_bits(pix,  8, 4),
                         extract_bits(pix, 12, 4),
                         extract_bits(pix,  0, 4)
                         );

    out.write(half4(pix2) / 15.0, gid);
}

kernel void convert_bgra5551_to_bgra8888_buf(device ushort * in  [[ buffer(0) ]],
                                             constant BufferUniforms & uniforms  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid [[ thread_position_in_grid ]])
{
    ushort pix  = in[(gid.y + uniforms.origin.y) * uniforms.stride + uniforms.origin.x + gid.x];
    uchar4 pix2 = uchar4(extract_bits(pix,  0, 5),
                         extract_bits(pix,  5, 5),
                         extract_bits(pix, 10, 5),
                         extract_bits(pix, 15, 1)
                         );

    out.write(half4(pix2) / half4(0x1f, 0x1f, 0x1f, 1), gid);
}

kernel void convert_rgb565_to_bgra8888_buf(device ushort * in  [[ buffer(0) ]],
                                           constant BufferUniforms & uniforms  [[ buffer(1) ]],
                                           texture2d<half, access::write> out [[ texture(0) ]],
                                           uint2 gid [[ thread_position_in_grid ]])
{
    ushort pix  = in[(gid.y + uniforms.origin.y) * uniforms.stride + uniforms.origin.x + gid.x];
    uchar4 pix2 = uchar4(extract_bits(pix, 11, 5),
                         extract_bits(pix,  5, 6),
                         extract_bits(pix,  0, 5),
                         0xf
                         );

    out.write(half4(pix2) / half4(0x1f, 0x3f, 0x1f, 0xf), gid);
}


kernel void convert_rgba8888_to_bgra8888_buf(device uchar4 * in  [[ buffer(0) ]],
                                             constant BufferUniforms & uniforms  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid [[ thread_position_in_grid ]])
{
    uchar4 pix = in[(gid.y + uniforms.origin.y) * uniforms.stride + uniforms.origin.x + gid.x];
    out.write(half4(pix.abgr) / 255.0, gid);
}

kernel void convert_abgr8888_to_bgra8888_buf(device uchar4 * in  [[ buffer(0) ]],
                                             constant BufferUniforms & uniforms  [[ buffer(1) ]],
                                             texture2d<half, access::write> out [[ texture(0) ]],
                                             uint2 gid [[ thread_position_in_grid ]])
{
    uchar4 pix = in[(gid.y + uniforms.origin.y) * uniforms.stride + uniforms.origin.x + gid.x];
    out.write(half4(pix.rgba) / 255.0, gid);
}
