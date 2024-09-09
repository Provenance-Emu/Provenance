
#ifndef _SNPPUCOLOR_H
#define _SNPPUCOLOR_H

#define SNPPUCOLOR_NUM (0x8000)

struct SNPPUColorCalibT
{
	float	fBrightness;
	float	fIQAngle;
	float	fMaxExcursion;
};

Uint32 SNPPUColorConvert15to32(Uint16 uColor15);
void SNPPUColorCalibrate(const SNPPUColorCalibT *pCalib);
void SNPPUColorSetColors(const Uint32 *pColors, Int32 nColors);
Uint32 *SNPPUColorGetPalette();


#endif
