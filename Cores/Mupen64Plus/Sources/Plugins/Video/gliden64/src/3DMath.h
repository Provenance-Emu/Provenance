#ifndef _3DMATH_H
#define _3DMATH_H
#include <utility>
#include <memory.h>
#include <string.h>
#include <Types.h>
#include "GBI.h"

void MultMatrix(float m0[4][4], float m1[4][4], float dest[4][4]);
void MultMatrix2(float m0[4][4], float m1[4][4]);
void TransformVectorNormalize(float vec[3], float mtx[4][4]);
void InverseTransformVectorNormalize(float src[3], float dst[3], float mtx[4][4]);
void InverseTransformVectorNormalizeN(float src[][3], float dst[][3], float mtx[4][4], u32 count);
void Normalize(float v[3]);
float DotProduct(const float v0[3], const float v1[3]);
void CopyMatrix( float m0[4][4], float m1[4][4]);

inline float DotProduct(const float v0[3], const float v1[3])
{
	float	dot;
#ifdef WIN32_ASM
	__asm {
		mov		esi, dword ptr [v0]
		mov		edi, dword ptr [v1]
		lea		ebx, [dot]

		fld		dword ptr [esi]
		fmul	dword ptr [edi]
		fld		dword ptr [esi+04h]
		fmul	dword ptr [edi+04h]
		fld		dword ptr [esi+08h]
		fmul	dword ptr [edi+08h]
		fadd
		fadd
		fstp	dword ptr [ebx]
	}
#else // WIN32_ASM
	dot = v0[0]*v1[0] + v0[1]*v1[1] + v0[2]*v1[2];
#endif // WIN32_ASM
	return dot;
}

inline float GetFloatMatrixElement(s16 _int, u16 _fract)
{
	const s32 element = (_int << 16) | _fract;
	return _FIXED2FLOAT(element, 16);
}

inline std::pair<s16, u16> GetIntMatrixElement(f32 _elem)
{
	const s32 value = static_cast<s32>(_elem * 65536.0f);
	return std::pair<s16, u16>(static_cast<s16>(value >> 16), static_cast<u16>(value & 0xFFFF));
}

#endif
