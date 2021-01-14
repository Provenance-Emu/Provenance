/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _C4_H_
#define _C4_H_

extern int16	C4WFXVal;
extern int16	C4WFYVal;
extern int16	C4WFZVal;
extern int16	C4WFX2Val;
extern int16	C4WFY2Val;
extern int16	C4WFDist;
extern int16	C4WFScale;
extern int16	C41FXVal;
extern int16	C41FYVal;
extern int16	C41FAngleRes;
extern int16	C41FDist;
extern int16	C41FDistVal;

void C4TransfWireFrame (void);
void C4TransfWireFrame2 (void);
void C4CalcWireFrame (void);
void C4Op0D (void);
void C4Op15 (void);
void C4Op1F (void);
void S9xInitC4 (void);
void S9xSetC4 (uint8, uint16);
uint8 S9xGetC4 (uint16);
uint8 * S9xGetBasePointerC4 (uint16);
uint8 * S9xGetMemPointerC4 (uint16);

static inline uint8 * C4GetMemPointer (uint32 Address)
{
	return (Memory.ROM + ((Address & 0xff0000) >> 1) + (Address & 0x7fff));
}

#endif
