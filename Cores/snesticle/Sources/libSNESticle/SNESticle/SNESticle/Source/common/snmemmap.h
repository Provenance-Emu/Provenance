
#ifndef _SNMEMMAP_H
#define _SNMEMMAP_H

enum SnesMemTypeE
{
	SNESMEM_TYPE_NONE,

	SNESMEM_TYPE_UNMAPPED,
	SNESMEM_TYPE_ROM,
	SNESMEM_TYPE_RAM,
	SNESMEM_TYPE_LORAM,
	SNESMEM_TYPE_SRAM,
	SNESMEM_TYPE_PPU0,
	SNESMEM_TYPE_PPU1,

	SNESMEM_TYPE_DSP1,

	SNESMEM_TYPE_NUM
};

struct SnesMemMapT
{
	Uint8			uStartBank;	// start and end bank (inclusive)
	Uint8			uEndBank;
	Uint16			uStartAddr;	// start and end address in each bank
	Uint16			uEndAddr;
	Uint8			uSpeed;
	SnesMemTypeE	eMemType;
	Uint32			uOffset;	// offset into data to start mapping
};



#endif
