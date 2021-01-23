/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _DMA_H_
#define _DMA_H_

struct SDMA
{
	bool8	ReverseTransfer;
	bool8	HDMAIndirectAddressing;
	bool8	UnusedBit43x0;
	bool8	AAddressFixed;
	bool8	AAddressDecrement;
	uint8	TransferMode;
	uint8	BAddress;
	uint16	AAddress;
	uint8	ABank;
	uint16	DMACount_Or_HDMAIndirectAddress;
	uint8	IndirectBank;
	uint16	Address;
	uint8	Repeat;
	uint8	LineCount;
	uint8	UnknownByte;
	uint8	DoTransfer;
};

#define TransferBytes	DMACount_Or_HDMAIndirectAddress
#define IndirectAddress	DMACount_Or_HDMAIndirectAddress

extern struct SDMA	DMA[8];

bool8 S9xDoDMA (uint8);
void S9xStartHDMA (void);
uint8 S9xDoHDMA (uint8);
void S9xResetDMA (void);

#endif
