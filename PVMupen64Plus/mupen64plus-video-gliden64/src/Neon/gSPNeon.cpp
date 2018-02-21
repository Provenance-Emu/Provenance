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
#include "Config.h"
#include "Log.h"
#include "DisplayWindow.h"
#include <arm_neon.h>

using namespace std;

void gSPTransformVertex4NEON(u32 v, float mtx[4][4])
{
    GraphicsDrawer & drawer = dwnd().getDrawer();
    SPVertex & vtx = drawer.getVertex(v);
    void *ptr = &vtx.x;

    asm volatile (
    "vld1.32         {d0, d1}, [%1]          \n\t"    //q0 = {x,y,z,w}
    "add             %1, %1, %2              \n\t"    //q0 = {x,y,z,w}
    "vld1.32         {d2, d3}, [%1]          \n\t"    //q1 = {x,y,z,w}
    "add             %1, %1, %2              \n\t"    //q0 = {x,y,z,w}
    "vld1.32         {d4, d5}, [%1]          \n\t"    //q2 = {x,y,z,w}
    "add             %1, %1, %2              \n\t"    //q0 = {x,y,z,w}
    "vld1.32         {d6, d7}, [%1]          \n\t"    //q3 = {x,y,z,w}
    "sub             %1, %1, %3              \n\t"    //q0 = {x,y,z,w}

    "vld1.32         {d18-d21}, [%0]!        \n\t"    //q9 & q10 = m
    "vld1.32         {d22-d25}, [%0]         \n\t"    //q11 & q12 = m+8

    "vmov.f32        q13, q12                \n\t"    //q13 = q12
    "vmov.f32        q14, q12                \n\t"    //q14 = q12
    "vmov.f32        q15, q12                \n\t"    //q15 = q12

    "vmla.f32        q12, q9, d0[0]          \n\t"    //q12 = q9*d0[0]
    "vmla.f32        q13, q9, d2[0]          \n\t"    //q13 = q9*d0[0]
    "vmla.f32        q14, q9, d4[0]          \n\t"    //q14 = q9*d0[0]
    "vmla.f32        q15, q9, d6[0]          \n\t"    //q15 = q9*d0[0]
    "vmla.f32        q12, q10, d0[1]         \n\t"    //q12 = q10*d0[1]
    "vmla.f32        q13, q10, d2[1]         \n\t"    //q13 = q10*d0[1]
    "vmla.f32        q14, q10, d4[1]         \n\t"    //q14 = q10*d0[1]
    "vmla.f32        q15, q10, d6[1]         \n\t"    //q15 = q10*d0[1]
    "vmla.f32        q12, q11, d1[0]         \n\t"    //q12 = q11*d1[0]
    "vmla.f32        q13, q11, d3[0]         \n\t"    //q13 = q11*d1[0]
    "vmla.f32        q14, q11, d5[0]         \n\t"    //q14 = q11*d1[0]
    "vmla.f32        q15, q11, d7[0]         \n\t"    //q15 = q11*d1[0]

    "vst1.32         {d24, d25}, [%1]        \n\t"    //q12
    "add             %1, %1, %2              \n\t"    //q0 = {x,y,z,w}
    "vst1.32         {d26, d27}, [%1]        \n\t"    //q13
    "add             %1, %1, %2              \n\t"    //q0 = {x,y,z,w}
    "vst1.32         {d28, d29}, [%1]        \n\t"    //q14
    "add             %1, %1, %2              \n\t"    //q0 = {x,y,z,w}
    "vst1.32         {d30, d31}, [%1]        \n\t"    //q15

    : "+&r"(mtx), "+&r"(ptr)
    : "I"(sizeof(SPVertex)), "I"(3 * sizeof(SPVertex))
    : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7",
      "d18","d19", "d20", "d21", "d22", "d23", "d24",
      "d25", "d26", "d27", "d28", "d29", "d30", "d31", "memory"
    );
}

void gSPBillboardVertex4NEON(u32 v)
{
    int i = 0;
    GraphicsDrawer & drawer = dwnd().getDrawer();

    SPVertex & vtx0 = drawer.getVertex(v);
    SPVertex & vtx1 = drawer.getVertex(i);

    void *ptr0 = (void*)&vtx0.x;
    void *ptr1 = (void*)&vtx1.x;
    asm volatile (

    "vld1.32         {d0, d1}, [%0]          \n\t"    //q0 = {x,y,z,w}
    "add             %0, %0, %2              \n\t"    //q0 = {x,y,z,w}
    "vld1.32         {d2, d3}, [%0]          \n\t"    //q1 = {x,y,z,w}
    "add             %0, %0, %2              \n\t"    //q0 = {x,y,z,w}
    "vld1.32         {d4, d5}, [%0]          \n\t"    //q2 = {x,y,z,w}
    "add             %0, %0, %2              \n\t"    //q0 = {x,y,z,w}
    "vld1.32         {d6, d7}, [%0]          \n\t"    //q3 = {x,y,z,w}
    "sub             %0, %0, %3              \n\t"    //q0 = {x,y,z,w}

    "vld1.32         {d16, d17}, [%1]        \n\t"    //q2={x1,y1,z1,w1}
    "vadd.f32        q0, q0, q8              \n\t"    //q1=q1+q1
    "vadd.f32        q1, q1, q8              \n\t"    //q1=q1+q1
    "vadd.f32        q2, q2, q8              \n\t"    //q1=q1+q1
    "vadd.f32        q3, q3, q8              \n\t"    //q1=q1+q1
    "vst1.32         {d0, d1}, [%0]          \n\t"    //
    "add             %0, %0, %2              \n\t"    //q0 = {x,y,z,w}
    "vst1.32         {d2, d3}, [%0]          \n\t"    //
    "add             %0, %0, %2              \n\t"    //q0 = {x,y,z,w}
    "vst1.32         {d4, d5}, [%0]          \n\t"    //
    "add             %0, %0, %2              \n\t"    //q0 = {x,y,z,w}
    "vst1.32         {d6, d7}, [%0]          \n\t"    //
    : "+&r"(ptr0), "+&r"(ptr1)
    : "I"(sizeof(SPVertex)), "I"(3 * sizeof(SPVertex))
    : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7",
      "d16", "d17", "memory"
    );
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
    const float32x4_t _vec4 = _mtx.val[0];
    vec[0] = _vec4[0];                                              // store vec[0]
    vec[1] = _vec4[1];                                              // store vec[1]
    vec[2] = _vec4[2];                                              // store vec[2]
}

void DotProductMax7FullNeon( float v0[3], float v1[7][3], float lights[7][3], float _vtx[3])
{
    asm volatile (
    "pld            [%0]                           \n\t"	//preload lights
    "pld            [%0, #64]                      \n\t"	
    "pld            [%3]                           \n\t"	//preload vtx
    "vld3.32        {d2[0],d3[0],d4[0]}, [%1]      \n\t"	//load v0
    "vld3.32        {d6,d8,d10}, [%2]!             \n\t"	//load v1
    "vld3.32        {d7,d9,d11}, [%2]!             \n\t"	
    "vld3.32        {d18,d20,d22}, [%2]!           \n\t"	
    "vld3.32        {d19[0],d21[0],d23[0]}, [%2]   \n\t"	

    "vmul.f32       q0, q3, d2[0]                  \n\t"	//q0=v0[0]*v1[i][0]
    "vmul.f32       q6, q9, d2[0]                  \n\t"	//q6=v0[0]*v1[i+4][0]

    "vmla.f32       q0, q4, d3[0]                  \n\t"	//q0+=v0[0]*v1[i][1]
    "vmla.f32       q6, q10, d3[0]                 \n\t"	//q6+=v0[0]*v1[i+4][1]
    "vmov.f32       q15, #0.0                      \n\t"	//q15={0.0f,0.0f,0.0f,0.0f}
    "vmla.f32       q0, q5, d4[0]                  \n\t"	//q0+=v0[0]*v1[i][2]
    "vmla.f32       q6, q11, d4[0]                 \n\t"	//q6+=v0[0]*v1[i+4][2]
    "vld3.32        {d4,d6,d8}, [%0]!              \n\t"	//load lights
    "vld3.32        {d5,d7,d9}, [%0]!              \n\t"	

    "vmax.f32       q0, q0, q15                    \n\t"	//q0=max(q0,q15)
    "vmov.f32       d11, #0.0                      \n\t"	//d11={0.0f,0.0f}
    "vmov.f32       d15, #0.0                      \n\t"	//d15={0.0f,0.0f}
    "vmax.f32       q1, q6, q15                    \n\t"	//q1=max(q6,q15)
    "vmov.f32       d13, #0.0                      \n\t"	//d13={0.0f,0.0f}

    "vld3.32        {d10,d12,d14}, [%0]!           \n\t"	//d10={x1,y1}
    "vld3.32        {d11[0],d13[0],d15[0]}, [%0]   \n\t"	//d10={x1,y1}	

    "vmul.f32       q2, q2, q0                     \n\t"	//q2=light.x*intensity
    "vmul.f32       q3, q3, q0                     \n\t"	//q3=light.y*intensity
    "vmul.f32       q4, q4, q0                     \n\t"	//q4=light.z*intensity
    "vmul.f32       q5, q5, q1                     \n\t"	//q5=(light.x+4)*intensity
    "vmul.f32       q6, q6, q1                     \n\t"	//q6=(light.y+4)*intensity
    "vmul.f32       q7, q7, q1                     \n\t"	//q7=(light.z+4)*intensity
    "vld3.32        {d22[0],d23[0],d24[0]}, [%3]   \n\t"	//load vtx

    "vadd.f32       d4,d4,d5                       \n\t"	//add everything to vtx
    "vadd.f32       d6,d6,d7                       \n\t"
    "vadd.f32       d8,d8,d9                       \n\t"

    "vadd.f32       d10,d10,d11                    \n\t"
    "vadd.f32       d12,d12,d13                    \n\t"
    "vadd.f32       d14,d14,d15                    \n\t"

    "vpadd.f32      d4,d4,d4                       \n\t"
    "vpadd.f32      d10,d10,d10                    \n\t"
    "vpadd.f32      d5,d6,d6                       \n\t"
    "vpadd.f32      d11,d12,d12                    \n\t"
    "vpadd.f32      d6,d8,d8                       \n\t"
    "vpadd.f32      d12,d14,d14                    \n\t"

    "vadd.f32       d4,d4,d10                      \n\t"
    "vadd.f32       d5,d5,d11                      \n\t"
    "vadd.f32       d6,d6,d12                      \n\t"

    "vadd.f32       d4,d4,d22                      \n\t"
    "vadd.f32       d5,d5,d23                      \n\t"
    "vadd.f32       d6,d6,d24                      \n\t"

    "vst3.32        {d4[0],d5[0],d6[0]}, [%3]      \n\t"
    : "+r"(lights), "+r"(v0), "+r"(v1), "+r"(_vtx):
    : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10", "d11", "d12", "d13", "d14", 
    "d15", "d16", "d17", "d18", "d19", "d20", "d21", "d22", "d23", "d24", "memory"
    );
}

void DotProductMax4FullNeon( float v0[3], float v1[4][3], float _lights[4][3], float _vtx[3])
{
    asm volatile (
    "vld3.32        {d0[0],d2[0],d4[0]}, [%1]   \n\t"	//load v0
    "vld3.32        {d6,d8,d10}, [%2]!          \n\t"	//load v1
    "vld3.32        {d7,d9,d11}, [%2]           \n\t"	//

    "vmul.f32       q0, q3, d0[0]               \n\t"	//product=v0[0]*v1[0]
    "vld3.32        {d12,d14,d16}, [%0]!        \n\t"	//load lights
    "vmla.f32       q0, q4, d2[0]               \n\t"	//product+=v0[1]*v1[1]
    "vld3.32        {d13,d15,d17}, [%0]         \n\t"	//load lights +2
    "vmov.f32       q11, #0.0                   \n\t"	
    "vmla.f32       q0, q5, d4[0]               \n\t"	//product+=v0[2]*v1[2]

    "vmax.f32       q0, q0, q11                 \n\t"	//product=max(product,0.0f)
    "vld3.32        {d18[0],d19[0],d20[0]}, [%3]\n\t"	//load vtx
    "vmul.f32       q6, q6, q0                  \n\t"	//lights.r = lights.r * intensity
    "vmul.f32       q7, q7, q0                  \n\t"	//lights.g = lights.g * intensity
    "vmul.f32       q8, q8, q0                  \n\t"	//lights.b = lights.b * intensity

    "vadd.f32       d12,d12,d13                 \n\t"	//add all values
    "vadd.f32       d14,d14,d15                 \n\t"
    "vadd.f32       d16,d16,d17                 \n\t"

    "vpadd.f32      d12,d12,d12                 \n\t"
    "vpadd.f32      d13,d14,d14                 \n\t"
    "vpadd.f32      d14,d16,d16                 \n\t"

    "vadd.f32       d12,d12,d18                 \n\t"
    "vadd.f32       d13,d13,d19                 \n\t"
    "vadd.f32       d14,d14,d20                 \n\t"

    "vst3.32        {d12[0],d13[0],d14[0]}, [%3]\n\t"	//store vtx
    : "+r"(_lights), "+r"(v0), "+r"(v1), "+r"(_vtx):
    : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10", "d11", "d12", "d13", "memory"
    );
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
				if (intensity < 0.0f)
					intensity = 0.0f;
				vtx.r += gSP.lights.rgb[gSP.numLights - count - 1][R] * intensity;
				vtx.g += gSP.lights.rgb[gSP.numLights - count - 1][G] * intensity;
				vtx.b += gSP.lights.rgb[gSP.numLights - count - 1][B] * intensity;
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
