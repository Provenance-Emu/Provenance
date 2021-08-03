/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include <math.h>
#include "snes9x.h"
#include "memmap.h"

#define	C4_PI	3.14159265

int16	C4WFXVal;
int16	C4WFYVal;
int16	C4WFZVal;
int16	C4WFX2Val;
int16	C4WFY2Val;
int16	C4WFDist;
int16	C4WFScale;
int16	C41FXVal;
int16	C41FYVal;
int16	C41FAngleRes;
int16	C41FDist;
int16	C41FDistVal;

static double	tanval;
static double	c4x, c4y, c4z;
static double	c4x2, c4y2, c4z2;


void C4TransfWireFrame (void)
{
	c4x = (double) C4WFXVal;
	c4y = (double) C4WFYVal;
	c4z = (double) C4WFZVal - 0x95;

	// Rotate X
	tanval = -(double) C4WFX2Val * C4_PI * 2 / 128;
	c4y2 = c4y  *  cos(tanval) - c4z  * sin(tanval);
	c4z2 = c4y  *  sin(tanval) + c4z  * cos(tanval);

	// Rotate Y
	tanval = -(double) C4WFY2Val * C4_PI * 2 / 128;
	c4x2 = c4x  *  cos(tanval) + c4z2 * sin(tanval);
	c4z  = c4x  * -sin(tanval) + c4z2 * cos(tanval);

	// Rotate Z
	tanval = -(double) C4WFDist  * C4_PI * 2 / 128;
	c4x  = c4x2 *  cos(tanval) - c4y2 * sin(tanval);
	c4y  = c4x2 *  sin(tanval) + c4y2 * cos(tanval);

	// Scale
	C4WFXVal = (int16) (c4x * (double) C4WFScale / (0x90 * (c4z + 0x95)) * 0x95);
	C4WFYVal = (int16) (c4y * (double) C4WFScale / (0x90 * (c4z + 0x95)) * 0x95);
}

void C4TransfWireFrame2 (void)
{
	c4x = (double) C4WFXVal;
	c4y = (double) C4WFYVal;
	c4z = (double) C4WFZVal;

	// Rotate X
	tanval = -(double) C4WFX2Val * C4_PI * 2 / 128;
	c4y2 = c4y  *  cos(tanval) - c4z  * sin(tanval);
	c4z2 = c4y  *  sin(tanval) + c4z  * cos(tanval);

	// Rotate Y
	tanval = -(double) C4WFY2Val * C4_PI * 2 / 128;
	c4x2 = c4x  *  cos(tanval) + c4z2 * sin(tanval);
	c4z  = c4x  * -sin(tanval) + c4z2 * cos(tanval);

	// Rotate Z
	tanval = -(double) C4WFDist  * C4_PI * 2 / 128;
	c4x  = c4x2 *  cos(tanval) - c4y2 * sin(tanval);
	c4y  = c4x2 *  sin(tanval) + c4y2 * cos(tanval);

	// Scale
	C4WFXVal = (int16) (c4x * (double) C4WFScale / 0x100);
	C4WFYVal = (int16) (c4y * (double) C4WFScale / 0x100);
}

void C4CalcWireFrame (void)
{
	C4WFXVal = C4WFX2Val - C4WFXVal;
	C4WFYVal = C4WFY2Val - C4WFYVal;

	if (abs(C4WFXVal) > abs(C4WFYVal))
	{
		C4WFDist = abs(C4WFXVal) + 1;
		C4WFYVal = (int16) (256 * (double) C4WFYVal / abs(C4WFXVal));
		if (C4WFXVal < 0)
			C4WFXVal = -256;
		else
			C4WFXVal =  256;
	}
	else
	{
		if (C4WFYVal != 0)
		{
			C4WFDist = abs(C4WFYVal) + 1;
			C4WFXVal = (int16) (256 * (double) C4WFXVal / abs(C4WFYVal));
			if (C4WFYVal < 0)
				C4WFYVal = -256;
			else
				C4WFYVal =  256;
		}
		else
			C4WFDist = 0;
	}
}

void C4Op1F (void)
{
	if (C41FXVal == 0)
	{
		if (C41FYVal > 0)
			C41FAngleRes = 0x80;
		else
			C41FAngleRes = 0x180;
	}
	else
	{
		tanval = (double) C41FYVal / C41FXVal;
		C41FAngleRes = (int16) (atan(tanval) / (C4_PI * 2) * 512);
		if (C41FXVal< 0)
			C41FAngleRes += 0x100;
		C41FAngleRes &= 0x1FF;
	}
}

void C4Op15 (void)
{
	tanval = sqrt((double) C41FYVal * C41FYVal + (double) C41FXVal * C41FXVal);
	C41FDist = (int16) tanval;
}

void C4Op0D (void)
{
	tanval = sqrt((double) C41FYVal * C41FYVal + (double) C41FXVal * C41FXVal);
	tanval = C41FDistVal / tanval;
	C41FYVal = (int16) (C41FYVal * tanval * 0.99);
	C41FXVal = (int16) (C41FXVal * tanval * 0.98);
}

uint8 * S9xGetBasePointerC4 (uint16 Address)
{
	if (Address >= 0x7f40 && Address <= 0x7f5e)
		return (NULL);
	return (Memory.C4RAM - 0x6000);
}

uint8 * S9xGetMemPointerC4 (uint16 Address)
{
	if (Address >= 0x7f40 && Address <= 0x7f5e)
		return (NULL);
	return (Memory.C4RAM - 0x6000 + (Address & 0xffff));
}
