
#include <math.h>
#include <string.h>
#include "types.h"
#include "snppucolor.h"

const float pi = 3.14159265358979323846f;
// factors are only accurate to three decimal places.
const float k_epsilon = 0.001f;


static Uint32 _SNPPUColor_Pal15to32[SNPPUCOLOR_NUM];

static void _SNPPUColorCalibrateColor(float& r, float& g, float& b, float fSin, float fCos, float fBrightness, float fMaxExcursion)
{
	// Convert from RGB to YUV space.
	float y = .299f * r + .587f * g + .114f * b;
	float u = 0.492f * (b - y);
	float v = 0.877f * (r - y);

	// Convert from YUV to YIQ space. This could be combined with
	// the RGB to YIQ conversion for better performance.
	float i = fCos * v - fSin * u;
	float q = fSin * v + fCos * u;

	// modulate brightness
	y *= fBrightness;

	// Calculate the amplitude of the chroma signal.
	float c = sqrtf(i * i + q * q);
	// See if the composite signal will go too high or too low.
	float maxComposite = y + c;
	float minComposite = y - c;

	if ((maxComposite > 1.0 + fMaxExcursion) || (minComposite < -fMaxExcursion))
	{
		// Convert into YIQ space, and convert c, the amplitude
		// of the chroma component.

		float coolant;
		// Calculate the ratio between the maximum chroma range allowed
		// and the current chroma range. 
		if (maxComposite > 1.0 + fMaxExcursion)
		{
			// The maximum chroma range is the maximum composite value
			// minus the luminance.
			coolant = (1.0f + fMaxExcursion - k_epsilon - y) / c;
		}
		else
		{
			// The maximum chroma range is the luminance minus the
			// minimum composite value.
			coolant = (y - -fMaxExcursion - k_epsilon) / c;
		}

		// Scale I and Q down, thus scaling chroma down and reducing the
		// saturation proportionally.
		i *= coolant;
		q *= coolant;
	}

	// convert yiq->rgb
	r = y + 0.956f * i + 0.620f * q;
	g = y - 0.272f * i - 0.647f * q;
	b = y - 1.108f * i + 1.705f * q;
}




Uint32 SNPPUColorConvert15to32(Uint16 uColor15)
{
	return _SNPPUColor_Pal15to32[uColor15 & 0x7FFF];
}

void SNPPUColorSetColors(const Uint32 *pColors, Int32 nColors)
{
	if (nColors > SNPPUCOLOR_NUM) nColors=SNPPUCOLOR_NUM;

	// copy color data
	memcpy(_SNPPUColor_Pal15to32, pColors, nColors * sizeof(Uint32)); 
}

Uint32 *SNPPUColorGetPalette()
{
	return _SNPPUColor_Pal15to32;
}


void SNPPUColorCalibrate(const SNPPUColorCalibT *pCalib)
{
	Uint32 uColor15;
	Float32 fSin, fCos;

	fCos = cosf(pCalib->fIQAngle * pi / 180.0f);
	fSin = sinf(pCalib->fIQAngle * pi / 180.0f);
	
	// go through all possible colors
	for (uColor15=0; uColor15 < SNPPUCOLOR_NUM; uColor15++)
	{
		Uint32 uColor32;
		Uint32 uR, uG, uB;
		Float32 fR, fG, fB;
		//		Float32 Y,I,Q;

		uR = ((uColor15 >>  0) & 0x1F);
		uG = ((uColor15 >>  5) & 0x1F);
		uB = ((uColor15 >>  10) & 0x1F);

		fR = ((Float32)uR) * (1.0f / 31.0f);
		fG = ((Float32)uG) * (1.0f / 31.0f);
		fB = ((Float32)uB) * (1.0f / 31.0f);

		//
		_SNPPUColorCalibrateColor(fR, fG, fB,  fSin, fCos, pCalib->fBrightness, pCalib->fMaxExcursion);

		// clamp R,G,B
		if (fR > 1.0f) fR = 1.0f; 
		if (fR < 0.0f) fR = 0.0f;
		if (fG > 1.0f) fG = 1.0f; 
		if (fG < 0.0f) fG = 0.0f;
		if (fB > 1.0f) fB = 1.0f; 
		if (fB < 0.0f) fB = 0.0f;

		// convert float -> int
		uR = (Uint8) (fR * 255.0f);
		uG = (Uint8) (fG * 255.0f);
		uB = (Uint8) (fB * 255.0f);

		// build 32-bit color
		uColor32 =  (uR << 0);
		uColor32|=  (uG << 8);
		uColor32|=  (uB << 16);

		// store color
		_SNPPUColor_Pal15to32[uColor15] = uColor32;
	}
}


