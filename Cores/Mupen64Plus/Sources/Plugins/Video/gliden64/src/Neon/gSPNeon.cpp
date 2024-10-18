#include <stdio.h>
#include <math.h>
#include <algorithm>
#include <assert.h>
#include "N64.h"
#include "GLideN64.h"
#include "Types.h"
#include "RSP.h"
#include "GBI.h"
#include "gSP.h"
#include "gDP.h"
#include "3DMath.h"
#include "CRC.h"
#include <string.h>
#include "convert.h"
#include "uCodes/S2DEX.h"
#include "VI.h"
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "../Config.h"
#include "Log.h"
#include "DisplayWindow.h"
#include <arm_neon.h>

using namespace std;

void gSPTransformVertex4NEON(u32 v, float mtx[4][4])
{
    GraphicsDrawer & drawer = dwnd().getDrawer();
    SPVertex & vtx0 = drawer.getVertex(v);
    SPVertex & vtx1 = drawer.getVertex(v + 1);
    SPVertex & vtx2 = drawer.getVertex(v + 2);
    SPVertex & vtx3 = drawer.getVertex(v + 3);
    
    // Load vtx
    float32x4x4_t _vtx;
    _vtx.val[0] = vld1q_f32(&vtx0.x);
    _vtx.val[1] = vld1q_f32(&vtx1.x);
    _vtx.val[2] = vld1q_f32(&vtx2.x);
    _vtx.val[3] = vld1q_f32(&vtx3.x);

    // Load mtx
    float32x4x4_t _mtx;
    _mtx.val[0] = vld1q_f32(mtx[0]);
    _mtx.val[1] = vld1q_f32(mtx[1]);
    _mtx.val[2] = vld1q_f32(mtx[2]);
    _mtx.val[3] = vld1q_f32(mtx[3]);

    float32x4x4_t _out;
    
    _out.val[0] = vmlaq_n_f32(_mtx.val[3], _mtx.val[0], _vtx.val[0][0]);
    _out.val[1] = vmlaq_n_f32(_mtx.val[3], _mtx.val[0], _vtx.val[1][0]);
    _out.val[2] = vmlaq_n_f32(_mtx.val[3], _mtx.val[0], _vtx.val[2][0]);
    _out.val[3] = vmlaq_n_f32(_mtx.val[3], _mtx.val[0], _vtx.val[3][0]);
    _out.val[0] = vmlaq_n_f32(_out.val[0], _mtx.val[1], _vtx.val[0][1]);
    _out.val[1] = vmlaq_n_f32(_out.val[1], _mtx.val[1], _vtx.val[1][1]);
    _out.val[2] = vmlaq_n_f32(_out.val[2], _mtx.val[1], _vtx.val[2][1]);
    _out.val[3] = vmlaq_n_f32(_out.val[3], _mtx.val[1], _vtx.val[3][1]);
    _out.val[0] = vmlaq_n_f32(_out.val[0], _mtx.val[2], _vtx.val[0][2]);
    _out.val[1] = vmlaq_n_f32(_out.val[1], _mtx.val[2], _vtx.val[1][2]);
    _out.val[2] = vmlaq_n_f32(_out.val[2], _mtx.val[2], _vtx.val[2][2]);
    _out.val[3] = vmlaq_n_f32(_out.val[3], _mtx.val[2], _vtx.val[3][2]);

    // Store vtx data
    vst1q_f32(&vtx0.x, _out.val[0]);
    vst1q_f32(&vtx1.x, _out.val[1]);
    vst1q_f32(&vtx2.x, _out.val[2]);
    vst1q_f32(&vtx3.x, _out.val[3]);
}

void gSPBillboardVertex4NEON(u32 v)
{
    GraphicsDrawer & drawer = dwnd().getDrawer();

    SPVertex & vtx = drawer.getVertex(0);

    SPVertex & vtx0 = drawer.getVertex(v);
    SPVertex & vtx1 = drawer.getVertex(v+1);
    SPVertex & vtx2 = drawer.getVertex(v+2);
    SPVertex & vtx3 = drawer.getVertex(v+3);

    // Load vtx[0]
    float32x4_t _vtx = vld1q_f32(&vtx.x);

    // Load vtx v, v+1, v+2, v+3
    float32x4_t _vtx0 = vld1q_f32(&vtx0.x);
    float32x4_t _vtx1 = vld1q_f32(&vtx1.x);
    float32x4_t _vtx2 = vld1q_f32(&vtx2.x);
    float32x4_t _vtx3 = vld1q_f32(&vtx3.x);

    // Add vtx[0] with vtx[n]./.[n+3] quad registers
    _vtx0 = vaddq_f32(_vtx0, _vtx);
    _vtx1 = vaddq_f32(_vtx1, _vtx);
    _vtx2 = vaddq_f32(_vtx2, _vtx);
    _vtx3 = vaddq_f32(_vtx3, _vtx);

    // Store quad registers
    vst1q_f32(&vtx0.x, _vtx0);
    vst1q_f32(&vtx1.x, _vtx1);
    vst1q_f32(&vtx2.x, _vtx2);
    vst1q_f32(&vtx3.x, _vtx3);
}

void gSPTransformVector_NEON(float vtx[4], float mtx[4][4])
{
    // Load vtx
    float32x4_t _vtx = vld1q_f32(vtx);

    // Load mtx
    float32x4_t _mtx0 = vld1q_f32(mtx[0]);
    float32x4_t _mtx1 = vld1q_f32(mtx[1]);
    float32x4_t _mtx2 = vld1q_f32(mtx[2]);
    float32x4_t _mtx3 = vld1q_f32(mtx[3]);

    // Multiply and add
    _mtx0 = vmlaq_n_f32(_mtx3, _mtx0, _vtx[0]);    // _mtx0 = _mtx3 + _mtx0 * _vtx[0]
    _mtx0 = vmlaq_n_f32(_mtx0, _mtx1, _vtx[1]);    // _mtx0 = _mtx0 + _mtx1 * _vtx[1]
    _mtx0 = vmlaq_n_f32(_mtx0, _mtx2, _vtx[2]);    // _mtx0 = _mtx0 + _mtx2 * _vtx[2]

    // Store vtx
    vst1q_f32(vtx, _mtx0);
}

void gSPInverseTransformVector_NEON(float vec[3], float mtx[4][4])
{
    float32x4x4_t _mtx = vld4q_f32(mtx[0]);                         // load 4x4 mtx interleaved

    _mtx.val[0] = vmulq_n_f32(_mtx.val[0], vec[0]);                 // mtx[0][0]=mtx[0][0]*_vtx[0]
                                                                    // mtx[0][1]=mtx[0][1]*_vtx[0]
                                                                    // mtx[0][2]=mtx[0][2]*_vtx[0]
    _mtx.val[0] = vmlaq_n_f32(_mtx.val[0], _mtx.val[1], vec[1]);    // mtx[0][0]+=mtx[1][0]*_vtx[1]
                                                                    // mtx[0][1]+=mtx[1][1]*_vtx[1]
                                                                    // mtx[0][2]+=mtx[1][2]*_vtx[1]
    _mtx.val[0] = vmlaq_n_f32(_mtx.val[0], _mtx.val[2], vec[2]);    // mtx[0][0]+=mtx[2][0]*_vtx[2]
                                                                    // mtx[0][1]+=mtx[2][1]*_vtx[2]
                                                                    // mtx[0][2]+=mtx[2][2]*_vtx[2]

    vec[0] = _mtx.val[0][0];                                              // store vec[0]
    vec[1] = _mtx.val[0][1];                                              // store vec[1]
    vec[2] = _mtx.val[0][2];                                              // store vec[2]
}

void DotProductMax7FullNeon( float v0[3], float v1[7][3], float lights[7][3], float _vtx[3])
{
    // load v1
    float32x4x3_t _v10 = vld3q_f32(v1[0]);               // load 4x3 mtx interleaved
    float32x2x3_t _v11 = vld3_f32(v1[4]);                // load 2x3 mtx interleaved
    float32x2x3_t _v12 = vld3_dup_f32(v1[6]);            // load 1x3 mtx interleaved
    for(int i = 0; i< 3; i++){
        _v12.val[i][1]=0.0;
    }
    
    // load lights
    float32x4x3_t _lights0 = vld3q_f32(lights[0]);       // load 4x3 mtx interleaved
    float32x2x3_t _lights1 = vld3_f32(lights[4]);        // load 2x3 mtx interleaved
    float32x2x3_t _lights2 = vld3_dup_f32(lights[6]);    // load 1x3 mtx interleaved

    float32x4_t product0;
    float32x2_t product1;
    float32x2_t product2;
    float32x4_t max = vmovq_n_f32(0.0);
    float32x2_t max1 = vmov_n_f32(0.0);

    // calc product
    product0 = vmulq_n_f32(_v10.val[0],v0[0]);
    product1 = vmul_n_f32(_v11.val[0],v0[0]);
    product2 = vmul_n_f32(_v12.val[0],v0[0]);
    product0 = vmlaq_n_f32(product0, _v10.val[1],v0[1]);
    product1 = vmla_n_f32(product1, _v11.val[1],v0[1]);
    product2 = vmla_n_f32(product2, _v12.val[1],v0[1]);
    product0 = vmlaq_n_f32(product0, _v10.val[2],v0[2]);
    product1 = vmla_n_f32(product1, _v11.val[2],v0[2]);
    product2 = vmla_n_f32(product2, _v12.val[2],v0[2]);
    
    product0 = vmaxq_f32(product0, max);
    product1 = vmax_f32(product1, max1);
    product2 = vmax_f32(product2, max1);

    // multiply product with lights
    _lights0.val[0] = vmulq_f32(_lights0.val[0],product0);
    _lights1.val[0] = vmul_f32(_lights1.val[0],product1);
    _lights1.val[0] = vmla_f32(_lights1.val[0],_lights2.val[0],product2);
    _lights0.val[1] = vmulq_f32(_lights0.val[1],product0);
    _lights1.val[1] = vmul_f32(_lights1.val[1],product1);
    _lights1.val[1] = vmla_f32(_lights1.val[1],_lights2.val[1],product2);
    _lights0.val[2] = vmulq_f32(_lights0.val[2],product0);
    _lights1.val[2] = vmul_f32(_lights1.val[2],product1);
    _lights1.val[2] = vmla_f32(_lights1.val[2],_lights2.val[2],product2);

    // add x, y and z values
    float32x2_t d00 = vadd_f32(vget_high_f32(_lights0.val[0]),vget_low_f32(_lights0.val[0]));
    float32x2_t d10 = vadd_f32(vget_high_f32(_lights0.val[1]),vget_low_f32(_lights0.val[1]));
    float32x2_t d20 = vadd_f32(vget_high_f32(_lights0.val[2]),vget_low_f32(_lights0.val[2]));
    d00 = vadd_f32(d00,_lights1.val[0]);
    d10 = vadd_f32(d10,_lights1.val[1]);
    d20 = vadd_f32(d20,_lights1.val[2]);
    d00 = vpadd_f32(d00,d00);
    d10 = vpadd_f32(d10,d10);
    d20 = vpadd_f32(d20,d20);

    _vtx[0] += d00[0];
    _vtx[1] += d10[0];
    _vtx[2] += d20[0];
}

void DotProductMax4FullNeon( float v0[3], float v1[4][3], float lights[4][3], float vtx[3])
{
    float32x4x3_t _v1 = vld3q_f32(v1[0]);               // load 4x3 mtx interleaved
    float32x4x3_t _lights = vld3q_f32(lights[0]);       // load 4x3 mtx interleaved

    float32x4_t product;
    float32x4_t max = vmovq_n_f32(0.0);

    product = vmulq_n_f32(_v1.val[0],v0[0]);
    product = vmlaq_n_f32(product, _v1.val[1],v0[1]);
    product = vmlaq_n_f32(product, _v1.val[2],v0[2]);
    
    product = vmaxq_f32(product, max);
    
    _lights.val[0] = vmulq_f32(_lights.val[0],product);
    _lights.val[1] = vmulq_f32(_lights.val[1],product);
    _lights.val[2] = vmulq_f32(_lights.val[2],product);

    float32x2_t d00 = vadd_f32(vget_high_f32(_lights.val[0]),vget_low_f32(_lights.val[0]));
    float32x2_t d10 = vadd_f32(vget_high_f32(_lights.val[1]),vget_low_f32(_lights.val[1]));
    float32x2_t d20 = vadd_f32(vget_high_f32(_lights.val[2]),vget_low_f32(_lights.val[2]));
    d00 = vpadd_f32(d00,d00);
    d10 = vpadd_f32(d10,d10);
    d20 = vpadd_f32(d20,d20);

    vtx[0] += d00[0];
    vtx[1] += d10[0];
    vtx[2] += d20[0];
}

void gSPLightVertex_NEON(u32 vnum, u32 v, SPVertex * spVtx)
{
	if (!isHWLightingAllowed()) {
		for(int j = 0; j < vnum; ++j) {
			SPVertex & vtx = spVtx[v + j];
			vtx.r = gSP.lights.rgb[gSP.numLights][R];
			vtx.g = gSP.lights.rgb[gSP.numLights][G];
			vtx.b = gSP.lights.rgb[gSP.numLights][B];
			vtx.HWLight = 0;

			s32 count = gSP.numLights-1;
			while (count >= 6) {
				DotProductMax7FullNeon(&vtx.nx,(float (*)[3])gSP.lights.i_xyz[gSP.numLights - count - 1],(float (*)[3])gSP.lights.rgb[gSP.numLights - count - 1],&vtx.r);
				count -= 7;
			}
			while (count >= 3) {
				DotProductMax4FullNeon(&vtx.nx,(float (*)[3])gSP.lights.i_xyz[gSP.numLights - count - 1],(float (*)[3])gSP.lights.rgb[gSP.numLights - count - 1],&vtx.r);
				count -= 4;
			}
			while (count >= 0)
			{
				f32 intensity = DotProduct( &vtx.nx, gSP.lights.i_xyz[gSP.numLights - count - 1] );
				if (intensity > 0.0f){
					vtx.r += gSP.lights.rgb[gSP.numLights - count - 1][R] * intensity;
					vtx.g += gSP.lights.rgb[gSP.numLights - count - 1][G] * intensity;
					vtx.b += gSP.lights.rgb[gSP.numLights - count - 1][B] * intensity;
				}
				count -= 1;
			}
			vtx.r = min(1.0f, vtx.r);
			vtx.g = min(1.0f, vtx.g);
			vtx.b = min(1.0f, vtx.b);
		}
	} else {
		for(int j = 0; j < vnum; ++j) {
			SPVertex & vtx = spVtx[v+j];
			TransformVectorNormalize(&vtx.r, gSP.matrix.modelView[gSP.matrix.modelViewi]);
			vtx.HWLight = gSP.numLights;
		}
	}
}
