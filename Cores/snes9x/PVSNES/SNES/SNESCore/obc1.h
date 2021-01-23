/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _OBC1_H_
#define _OBC1_H_

struct SOBC1
{
	uint16	address;
	uint16	basePtr;
	uint16	shift;
};

extern struct SOBC1	OBC1;

void S9xSetOBC1 (uint8, uint16);
uint8 S9xGetOBC1 (uint16);
void S9xResetOBC1 (void);
uint8 * S9xGetBasePointerOBC1 (uint16);
uint8 * S9xGetMemPointerOBC1 (uint16);

#endif
