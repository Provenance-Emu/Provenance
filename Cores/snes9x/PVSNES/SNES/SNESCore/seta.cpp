/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "seta.h"

uint8	(*GetSETA) (uint32)        = &S9xGetST010;
void	(*SetSETA) (uint32, uint8) = &S9xSetST010;


uint8 S9xGetSetaDSP (uint32 Address)
{
	return (GetSETA(Address));
}

void S9xSetSetaDSP (uint8 Byte, uint32 Address)
{
	SetSETA (Address, Byte);
}
