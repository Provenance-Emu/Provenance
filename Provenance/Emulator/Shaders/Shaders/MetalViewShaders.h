//
//  MetalViewShaders.h
//  Wombat
//
//  Created by Todd Laney on 4/6/20.
//  Copyright © 2020 Todd Laney. All rights reserved.
//
#import <simd/SIMD.h>

// input 2D vertex
typedef struct {
    vector_float2 position;
    vector_float2 tex;
    vector_float4 color;
} VertexInput;

#ifdef __METAL_VERSION__
struct VertexOutput {
    vector_float4 position [[position]];
    vector_float2 tex;
    vector_float4 color;
};
#endif

// default vertex uniforms, just the matrix
typedef struct {
    matrix_float4x4 matrix;   // matrix to map into NDC
} VertexUniforms;


