
#ifndef _SNROM_H
#define _SNROM_H

#include "emurom.h"

enum SNRomHdrTypeE
{
	SNROM_HDRTYPE_UNKNOWN,
	SNROM_HDRTYPE_SWC,
	SNROM_HDRTYPE_FIG,
	SNROM_HDRTYPE_GAMEDOCTOR,

	SNROM_HDRTYPE_NUM
};

enum SNRomVideoE
{
	SNROM_VIDEO_NTSC,
	SNROM_VIDEO_PAL,

	SNROM_VIDEO_NUM
};

enum SNRomMappingE
{
	SNROM_MAPPING_LOROM,
	SNROM_MAPPING_HIROM,

	SNROM_MAPPING_NUM
};

#define SNROM_FLAG_ROM		0x01
#define SNROM_FLAG_RAM		0x02
#define SNROM_FLAG_SAVERAM	0x04
#define SNROM_FLAG_DSP1		0x08
#define SNROM_FLAG_SUPERFX	0x10
#define SNROM_FLAG_GAMEBOY	0x20
#define SNROM_FLAG_DSP2		0x40

struct SNRomInfoT
{
	Uint8	Title[21];
	Uint8	RomMakeup;
	Uint8	RomType;
	Uint8	RomSize;
	Uint8	SRAMSize;
	Uint8	Country;
	Uint8	License;
	Uint8	GameVersion;
	Uint16	InverseChecksum;
	Uint16	Checksum;
};

struct SNRomHdrUnknownT
{
	Uint16	uSize;			// size in MegaBits * 16
};

struct SNRomHdrSWCT
{
	Uint16	uSize;			// size in MegaBits * 16
	Uint8	uImageInfo;		// image info flags
	Uint8	Reserved[5];			
	Uint8	Tag[3];			// AA BB 04
};

struct SNRomHdrFIGT
{
	Uint16	uSize;			// size in MegaBits * 16
	Uint8	uMultiImage;	// 40=Multi 00=LastImage
	Uint8	uHiRom;			// 80=HiROM 00=LoROM
	Uint8	uSRAM0;			// FD=SRAM,DSP 47=DSP 77=-
	Uint8	uSRAM1;			// 82=SRAM,DSP 83=DSP 83=-
};

union SNRomHdrU
{
	Uint8				uData[512];
	SNRomHdrUnknownT	Unknown;
	SNRomHdrSWCT		SWC;
	SNRomHdrFIGT		FIG;
};


class SnesRom  : public Emu::Rom
{
private:
	Uint32	m_uRomBytes;		// size of rom in bytes
	Uint8	*m_pRomMem;
	Uint8	*m_pRomData;	// pointer to rom data
	SNRomInfoT *m_pCartInfo;

public:
	Uint8			m_Name[256];	// Name of ROM
	Uint32			m_Flags;
	SNRomMappingE	m_eMapping;		// mapping (lo,hi rom)
	SNRomVideoE		m_eVideoType;
	Uint32			m_uROMSize;		// size of ROM (in kilobits)
	Uint32			m_uSRAMSize;	// size of SRAM (in kilobits)

public:
	SnesRom();
	~SnesRom();

	//SNRomErrorE	LoadRom(Char *pFileName, Uint8 *pBuffer = NULL, Uint32 nBufferBytes = 0);
	LoadErrorE LoadRom(class CDataIO *pFileIO, Uint8 *pBuffer = NULL, Uint32 nBufferBytes = 0);
	void	Unload();
	Bool	IsLoaded() {return m_bLoaded;}

	Uint8	*GetData() {return m_pRomData;}
	Uint32	GetBytes() {return m_uRomBytes;}
	Uint32	GetSRAMBytes() {return m_uSRAMSize * 1024 / 8;}

	SNRomInfoT *GetCartInfo(Uint32 uOffset);
	void SetCartInfo(SNRomInfoT *pCartInfo);

	static SNRomHdrTypeE SNRomGetHdrType(SNRomHdrU *pRomHdr);

	virtual Uint32  GetNumExts();
	virtual Char    *GetExtName(Uint32 uExt);
	virtual Uint32	GetNumRomRegions();
	virtual Char   *GetRomRegionName(Uint32 uRegion);
	virtual Uint32 	GetRomRegionSize(Uint32 uRegion);
	virtual Char   *GetRomTitle();
	virtual Char   *GetMapperName();
};




#endif
