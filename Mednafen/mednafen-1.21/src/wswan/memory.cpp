/******************************************************************************/
/* Mednafen WonderSwan Emulation Module(based on Cygne)                       */
/******************************************************************************/
/* memory.cpp:
**  Copyright (C) 2002 Dox dox@space.pl
**  Copyright (C) 2007-2017 Mednafen Team
**  Copyright (C) 2016 Alex 'trap15' Marshall - http://daifukkat.su/
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License version 2.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "wswan.h"
#include "gfx.h"
#include "memory.h"
#include "sound.h"
#include "eeprom.h"
#include "rtc.h"
#include "v30mz.h"
#include "comm.h"
#include <mednafen/mempatcher.h>
#include <mednafen/FileStream.h>
#include <time.h>
#include <trio/trio.h>

namespace MDFN_IEN_WSWAN
{

uint32 wsRAMSize;
uint8 wsRAM[65536];
static uint8 *wsSRAM = NULL;

uint8 *wsCartROM;
static uint32 sram_size;
uint32 eeprom_size;

static uint8 ButtonWhich, ButtonReadLatch;

static uint32 DMASource;
static uint16 DMADest;
static uint16 DMALength;
static uint8 DMAControl;

static uint32 SoundDMASource, SoundDMASourceSaved;
static uint32 SoundDMALength, SoundDMALengthSaved;
static uint8 SoundDMAControl;
static uint8 SoundDMATimer;

static uint8 BankSelector[4];

static bool language;

//
static bool IsWW;
static uint8 WW_FlashLock;

enum
{
 WW_FWSM_READ = 0,

 WW_FWSM_FPS0,
 WW_FWSM_FPS1,

 WW_FWSM_FP0,
 WW_FWSM_FP1,

 WW_FWSM_FPR0
};

static uint8 WW_FWSM;
//

extern uint16 WSButtonStatus;

template<bool WW>
static INLINE void WriteMem(uint32 A, uint8 V)
{
 uint32 offset, bank;

 offset = A & 0xffff;
 bank = (A>>16) & 0xF;

 //printf("WriteA: %08x %02x --- %02x %02x %02x %02x\n", A, V, BankSelector[0], BankSelector[1], BankSelector[2], BankSelector[3]);

 if(!bank) /*RAM*/
 {
  WSwan_SoundCheckRAMWrite(offset);
  wsRAM[offset] = V;

  WSWan_TCacheInvalidByAddr(offset);

  if(offset>=0xfe00) /*WSC palettes*/
   WSwan_GfxWSCPaletteRAMWrite(offset, V);
 }
 else if(bank == 1) /* SRAM */
 { 
  //if((offset | (BankSelector[1] << 16)) >= 0x38000)
  // printf("%08x\n", offset | (BankSelector[1] << 16));
  if(WW && (BankSelector[1] & 0x08))
  {
   if(WW_FlashLock != 0x00)
   {
    uint32 rom_addr = offset | (BankSelector[1] << 16);

    //printf("Write: %08x %02x\n", rom_addr, V);

    switch(WW_FWSM)
    {
     case WW_FWSM_READ:

	if((rom_addr & 0xFFF) == 0xAAA && V == 0xAA)
	 WW_FWSM = WW_FWSM_FPS0;

	break;

     case WW_FWSM_FPS0:

	if((rom_addr & 0xFFF) == 0x555 && V == 0x55)
	 WW_FWSM = WW_FWSM_FPS1;
	else
	 WW_FWSM = WW_FWSM_READ;

	break;

     case WW_FWSM_FPS1:
	if((rom_addr & 0xFFF) == 0xAAA && V == 0x20)
	 WW_FWSM = WW_FWSM_FP0;
	else
	 WW_FWSM = WW_FWSM_READ;
	break;

     case WW_FWSM_FP0:
	if((rom_addr & 0xFFF) == 0xBA && V == 0x90)
	 WW_FWSM = WW_FWSM_FPR0;
	else if(V == 0xA0)
	 WW_FWSM = WW_FWSM_FP1;
	break;

     case WW_FWSM_FP1:
	//printf("Program: %08x %02x\n", rom_addr, V);
	wsCartROM[rom_addr & 524287] = V;
	WW_FWSM = WW_FWSM_FP0;
	break;

     case WW_FWSM_FPR0:
	if(V == 0xF0)
	 WW_FWSM = WW_FWSM_READ;	
	break;
    }
   }
  }
  else if(sram_size)
   wsSRAM[(offset | (BankSelector[1] << 16)) & (sram_size - 1)] = V;
 }
}	

#if 0
 WW_FWSM_READ = 0,

 WW_FWSM_FPS0,
 WW_FWSM_FPS1,

 WW_FWSM_FP0,
 WW_FWSM_FP1,

 WW_FWSM_FPR0
#endif
template<bool WW>
static INLINE uint8 ReadMem(uint32 A)
{
 uint32	offset, bank;

 offset = A & 0xFFFF;
 bank = (A >> 16) & 0xF;
  
 switch(bank)
 {
	case 0:  return wsRAM[offset];

	case 1:  if(WW && (BankSelector[1] & 0x08))
		 {
		  uint32 rom_addr = (offset | (BankSelector[1] << 16));
		  uint8 ret = wsCartROM[rom_addr & 524287];

		  if(WW_FWSM != WW_FWSM_READ)
                   ret &= 0x80;

		  //printf("%08x %02x %02x\n", rom_addr, wsCartROM[rom_addr & 524287], ret);

		  return ret;
	 	 }
		 else if(sram_size)
		 {
		  return wsSRAM[(offset | (BankSelector[1] << 16)) & (sram_size - 1)];
		 }
		 else
		  return(0);

	default:
		{
		 uint32 rom_addr;

		 if(bank == 2 || bank == 3)
		  rom_addr = offset + ((BankSelector[bank] & ((rom_size >> 16) - 1)) << 16);
		 else
		 {
		  uint8 bank_num = (((BankSelector[0] & 0xF) << 4) | (bank & 0xf)) & ((rom_size >> 16) - 1);
		  rom_addr = (bank_num << 16) | offset; 
	         }

		 return wsCartROM[rom_addr];
		}
 }
}

static void ws_CheckDMA(void)
{
 if(DMAControl & 0x80)
 {
  while(DMALength)
  {
   WSwan_writemem20(DMADest, WSwan_readmem20(DMASource));
   WSwan_writemem20(DMADest+1, WSwan_readmem20(DMASource+1));

   if(DMAControl & 0x40)
   {
    DMASource -= 2;
    DMADest -= 2;
   }
   else
   {
    DMASource += 2;
    DMADest += 2;
   }
   DMASource &= 0x000FFFFE;
   DMALength -= 2;
  }
 }
 DMAControl &= ~0x80;
}

void WSwan_CheckSoundDMA(void)
{
 if(!(SoundDMAControl & 0x80))
  return;


 if(!SoundDMATimer)
 {
  uint8 zebyte = WSwan_readmem20(SoundDMASource);

  if(SoundDMAControl & 0x10)
   WSwan_SoundWrite(0x95, zebyte); // Pick a port, any port?!
  else
   WSwan_SoundWrite(0x89, zebyte);

  if(SoundDMAControl & 0x40)
   SoundDMASource--;
  else
   SoundDMASource++;
  SoundDMASource &= 0x000FFFFF;

  SoundDMALength--;
  SoundDMALength &= 0x000FFFFF;
  if(!SoundDMALength)
  {
   if(SoundDMAControl & 8)
   {
     SoundDMALength = SoundDMALengthSaved;
     SoundDMASource = SoundDMASourceSaved;
   }
   else
   {
    SoundDMAControl &= ~0x80;
   }
  }

  switch(SoundDMAControl & 3)
  {
    case 0: SoundDMATimer = 5; break;
    case 1: SoundDMATimer = 3; break;
    case 2: SoundDMATimer = 1; break;
    case 3: SoundDMATimer = 0; break;
  }
 }
 else
 {
  SoundDMATimer--;
 }
}

template<bool WW>
static INLINE uint8 ReadPort(uint32 number)
{
  number &= 0xFF;

  if((number >= 0x80 && number <= 0x9F) || (number == 0x6A) || (number == 0x6B))
   return(WSwan_SoundRead(number));
  else if(number <= 0x3F || (number >= 0xA0 && number <= 0xAF) || (number == 0x60))
   return(WSwan_GfxRead(number));
  else if((number >= 0xBA && number <= 0xBE) || (number >= 0xC4 && number <= 0xC8))
   return(WSwan_EEPROMRead(number));
  else if(number >= 0xCA && number <= 0xCB)
   return(RTC_Read(number));
  else switch(number)
  {
   //default: printf("Read: %04x\n", number); break;
   case 0x40: return(DMASource >> 0);
   case 0x41: return(DMASource >> 8);
   case 0x42: return(DMASource >> 16);

   case 0x44: return(DMADest >> 0);
   case 0x45: return(DMADest >> 8);

   case 0x46: return(DMALength >> 0);
   case 0x47: return(DMALength >> 8);

   case 0x48: return(DMAControl);

   case 0xB0:
   case 0xB2:
   case 0xB6: return(WSwan_InterruptRead(number));

   case 0xC0: return(BankSelector[0] | 0x20);
   case 0xC1: return(BankSelector[1]);
   case 0xC2: return(BankSelector[2]);
   case 0xC3: return(BankSelector[3]);

   case 0x4a: return(SoundDMASource >> 0);
   case 0x4b: return(SoundDMASource >> 8);
   case 0x4c: return(SoundDMASource >> 16);
   case 0x4e: return(SoundDMALength >> 0);
   case 0x4f: return(SoundDMALength >> 8);
   case 0x50: return(SoundDMALength >> 16);
   case 0x52: return(SoundDMAControl);

   case 0xB1:
   case 0xB3: return(Comm_Read(number));

   case 0xb5: 
	     {
	      uint8 ret = (ButtonWhich << 4) | ButtonReadLatch;
  	      return(ret);
	     }
 }

 if(WW && number == 0xCE)
  return WW_FlashLock;

 if(number >= 0xC8)
  return(0xD0 | language);

 return(0);
}

template<bool WW>
static INLINE void WritePort(uint32 IOPort, uint8 V)
{
 IOPort &= 0xFF;

	if((IOPort >= 0x80 && IOPort <= 0x9F) || (IOPort == 0x6A) || (IOPort == 0x6B))
	{
	 WSwan_SoundWrite(IOPort, V);
	}
	else if((IOPort >= 0x00 && IOPort <= 0x3F) || (IOPort >= 0xA0 && IOPort <= 0xAF) || (IOPort == 0x60))
	{
	 WSwan_GfxWrite(IOPort, V);
	}
	else if((IOPort >= 0xBA && IOPort <= 0xBE) || (IOPort >= 0xC4 && IOPort <= 0xC8))
	 WSwan_EEPROMWrite(IOPort, V);
	else if(IOPort >= 0xCA && IOPort <= 0xCB)
	 RTC_Write(IOPort, V);
	else switch(IOPort)
	{
		//default: printf("%04x %02x\n", IOPort, V); break;

		case 0x40: DMASource &= 0xFFFF00; DMASource |= (V << 0) & ~1; break;
		case 0x41: DMASource &= 0xFF00FF; DMASource |= (V << 8); break;
		case 0x42: DMASource &= 0x00FFFF; DMASource |= ((V & 0x0F) << 16); break;

		case 0x44: DMADest &= 0xFF00; DMADest |= (V << 0) & ~1; break;
		case 0x45: DMADest &= 0x00FF; DMADest |= (V << 8); break;

		case 0x46: DMALength &= 0xFF00; DMALength |= (V << 0) & ~1; break;
		case 0x47: DMALength &= 0x00FF; DMALength |= (V << 8); break;

		case 0x48: DMAControl = V & ~0x3F;
			   ws_CheckDMA(); 
			   break;

                case 0x4a: SoundDMASource &= 0xFFFF00; SoundDMASource |= (V << 0); SoundDMASourceSaved = SoundDMASource; break;
                case 0x4b: SoundDMASource &= 0xFF00FF; SoundDMASource |= (V << 8); SoundDMASourceSaved = SoundDMASource; break;
                case 0x4c: SoundDMASource &= 0x00FFFF; SoundDMASource |= ((V & 0xF) << 16); SoundDMASourceSaved = SoundDMASource; break;

                case 0x4e: SoundDMALength &= 0xFFFF00; SoundDMALength |= (V << 0); SoundDMALengthSaved = SoundDMALength; break;
                case 0x4f: SoundDMALength &= 0xFF00FF; SoundDMALength |= (V << 8); SoundDMALengthSaved = SoundDMALength; break;
                case 0x50: SoundDMALength &= 0x00FFFF; SoundDMALength |= ((V & 0xF) << 16); SoundDMALengthSaved = SoundDMALength; break;
		case 0x52: SoundDMAControl = V & ~0x20;
			   break;

	case 0xB0:
	case 0xB2:
	case 0xB6: WSwan_InterruptWrite(IOPort, V); break;

	case 0xB1: 
	case 0xB3: Comm_Write(IOPort, V); break;

	case 0xb5: ButtonWhich = V >> 4;
		   ButtonReadLatch = 0;

                   if(ButtonWhich & 0x4) /*buttons*/
		    ButtonReadLatch |= ((WSButtonStatus >> 8) << 1) & 0xF;

		   if(ButtonWhich & 0x2) /* H/X cursors */
		    ButtonReadLatch |= WSButtonStatus & 0xF;

		   if(ButtonWhich & 0x1) /* V/Y cursors */
		    ButtonReadLatch |= (WSButtonStatus >> 4) & 0xF;
                   break;

   case 0xC0: BankSelector[0] = V & 0xF; break;
   case 0xC1: BankSelector[1] = V; break;
   case 0xC2: BankSelector[2] = V; break;
   case 0xC3: BankSelector[3] = V; break;
 }

 if(WW && IOPort == 0xCE)
  WW_FlashLock = V;
}

MDFN_FASTCALL void WSwan_writemem20(uint32 A, uint8 V)
{
 WriteMem<false>(A, V);
}

MDFN_FASTCALL uint8 WSwan_readmem20(uint32 A)
{
 return ReadMem<false>(A);
}

MDFN_FASTCALL uint8 WSwan_readport(uint32 number)
{
 return ReadPort<false>(number);
}

MDFN_FASTCALL void WSwan_writeport(uint32 IOPort, uint8 V)
{
 WritePort<false>(IOPort, V);
}

MDFN_FASTCALL void WSwan_writemem20_WW(uint32 A, uint8 V)
{
 WriteMem<true>(A, V);
}

MDFN_FASTCALL uint8 WSwan_readmem20_WW(uint32 A)
{
 return ReadMem<true>(A);
}

MDFN_FASTCALL uint8 WSwan_readport_WW(uint32 number)
{
 return ReadPort<true>(number);
}

MDFN_FASTCALL void WSwan_writeport_WW(uint32 IOPort, uint8 V)
{
 WritePort<true>(IOPort, V);
}

#ifdef WANT_DEBUGGER
static void GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer)
{
 if(!strcmp(name, "ram"))
 {
  while(Length--)
  {
   Address &= wsRAMSize - 1;
   *Buffer = wsRAM[Address];
   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "physical"))
 {
  while(Length--)
  {
   Address &= 0xFFFFF;
   *Buffer = WSwan_readmem20(Address);
   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "cs") || !strcmp(name, "ds") || !strcmp(name, "ss") || !strcmp(name, "es"))
 {
  uint32 segment;
  uint32 phys_address;

  if(!strcmp(name, "cs"))
   segment = v30mz_get_reg(NEC_PS);
  else if(!strcmp(name, "ss"))
   segment = v30mz_get_reg(NEC_SS);
  else if(!strcmp(name, "ds"))
   segment = v30mz_get_reg(NEC_DS0);
  else if(!strcmp(name, "es"))
   segment = v30mz_get_reg(NEC_DS1);

  phys_address = (Address + (segment << 4)) & 0xFFFFF;

  GetAddressSpaceBytes("physical", phys_address, Length, Buffer);
 }
}

static void PutAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint32 Granularity, bool hl, const uint8 *Buffer)
{
 if(!strcmp(name, "ram"))
 {
  while(Length--)
  {
   Address &= wsRAMSize - 1;
   wsRAM[Address] = *Buffer;
   WSWan_TCacheInvalidByAddr(Address);
   if(Address >= 0xfe00)
    WSwan_GfxWSCPaletteRAMWrite(Address, *Buffer);

   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "physical"))
 {
  while(Length--)
  {
   uint32 offset, bank;

   Address &= 0xFFFFF;

   offset = Address & 0xFFFF;
   bank = (Address >> 16) & 0xF;
  
   switch(bank)
   {
    case 0:  wsRAM[offset & (wsRAMSize - 1)] = *Buffer;
	     WSWan_TCacheInvalidByAddr(offset & (wsRAMSize - 1));
	     if(Address >= 0xfe00)
	      WSwan_GfxWSCPaletteRAMWrite(offset & (wsRAMSize - 1), *Buffer);
	     break;
    case 1:  
	     if(IsWW && (BankSelector[1] & 0x08))
	     {
	      uint32 rom_addr = (offset | (BankSelector[1] << 16));
	      wsCartROM[rom_addr & 524287] = *Buffer;
	     }
	     else if(sram_size)
	       wsSRAM[(offset | (BankSelector[1] << 16)) & (sram_size - 1)] = *Buffer;
	     break;
    case 2:
    case 3:  wsCartROM[offset+((BankSelector[bank]&((rom_size>>16)-1))<<16)] = *Buffer;
	     break;

    default:
            {
             uint8 bank_num = ((BankSelector[0] & 0xF) << 4) | (bank & 0xf);
             bank_num &= (rom_size >> 16) - 1;
             wsCartROM[(bank_num << 16) | offset] = *Buffer;
            }
	    break;
   }

   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "cs") || !strcmp(name, "ds") || !strcmp(name, "ss") || !strcmp(name, "es"))
 {
  uint32 segment;
  uint32 phys_address;

  if(!strcmp(name, "cs"))
   segment = v30mz_get_reg(NEC_PS);
  else if(!strcmp(name, "ss"))
   segment = v30mz_get_reg(NEC_SS);
  else if(!strcmp(name, "ds"))
   segment = v30mz_get_reg(NEC_DS0);
  else if(!strcmp(name, "es"))
   segment = v30mz_get_reg(NEC_DS1);

  phys_address = (Address + (segment << 4)) & 0xFFFFF;

  PutAddressSpaceBytes("physical", phys_address, Length, Granularity, hl, Buffer);
 }
}

uint32 WSwan_MemoryGetRegister(const unsigned int id, char *special, const uint32 special_len)
{
 uint32 ret = 0;

 switch(id)
 {
  case MEMORY_GSREG_ROMBBSLCT:
        ret = BankSelector[0];

	if(special)
	{
         trio_snprintf(special, special_len, "((0x%02x * 0x100000) %% 0x%08x) + 20 bit address = 0x%08x + 20 bit address", BankSelector[0], rom_size, (BankSelector[0] * 0x100000) & (rom_size - 1));
	}
        break;

  case MEMORY_GSREG_BNK1SLCT:
        ret = BankSelector[1];
        break;

  case MEMORY_GSREG_BNK2SLCT:
        ret = BankSelector[2];
        break;

  case MEMORY_GSREG_BNK3SLCT:
        ret = BankSelector[3];
        break;
 }

 return(ret);
}

void WSwan_MemorySetRegister(const unsigned int id, uint32 value)
{
 switch(id)
 {
  case MEMORY_GSREG_ROMBBSLCT:
	BankSelector[0] = value;
	break;

  case MEMORY_GSREG_BNK1SLCT:
	BankSelector[1] = value;
	break;

  case MEMORY_GSREG_BNK2SLCT:
	BankSelector[2] = value;
	break;

  case MEMORY_GSREG_BNK3SLCT:
	BankSelector[3] = value;
	break;
 }
}

#endif

static void Cleanup(void)
{
 if(wsSRAM)
 {
  delete[] wsSRAM;
  wsSRAM = NULL;
 }
}

void WSwan_MemoryKill(void)
{
 Cleanup();
}

void WSwan_MemoryLoadNV(void)
{
 if(sram_size || eeprom_size)
 {
  try
  {
   const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, "sav");
   std::unique_ptr<Stream> savegame_fp = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ eeprom_size + sram_size }));
   const uint64 fp_size_tmp = savegame_fp->size();

   if(fp_size_tmp != ((uint64)eeprom_size + sram_size))
    throw MDFN_Error(0, _("Save game memory file \"%s\" is an incorrect size(%llu bytes).  The correct size is %llu bytes."), path.c_str(), (unsigned long long)fp_size_tmp, ((unsigned long long)eeprom_size + sram_size));

   if(eeprom_size)
    savegame_fp->read(wsEEPROM, eeprom_size);

   if(sram_size)
    savegame_fp->read(wsSRAM, sram_size);
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }

 if(IsWW)
 {
  try
  {
   const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, "flash");
   FileStream savegame_fp(path, FileStream::MODE_READ);
   const uint64 fp_size_tmp = savegame_fp.size();

   if(fp_size_tmp != 524288)
    throw MDFN_Error(0, _("Save game memory file \"%s\" is an incorrect size(%llu bytes).  The correct size is %llu bytes."), path.c_str(), (unsigned long long)fp_size_tmp, (unsigned long long)524288);

   savegame_fp.read(wsCartROM, 524288);
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }
}

void WSwan_MemorySaveNV(void)
{
 if(sram_size || eeprom_size)
 {
  std::vector<PtrLengthPair> EvilRams;

  if(eeprom_size)
   EvilRams.push_back(PtrLengthPair(wsEEPROM, eeprom_size));

  if(sram_size)
   EvilRams.push_back(PtrLengthPair(wsSRAM, sram_size));

  MDFN_DumpToFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), EvilRams);
 }

 if(IsWW)
 {
  MDFN_DumpToFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "flash"), wsCartROM, 524288);
 }
}

void WSwan_MemoryInit(bool lang, bool IsWSC, uint32 ssize, bool IsWW_arg)
{
 IsWW = IsWW_arg;

 try
 {
  const uint16 byear = MDFN_GetSettingUI("wswan.byear");
  const uint8 bmonth = MDFN_GetSettingUI("wswan.bmonth");
  const uint8 bday = MDFN_GetSettingUI("wswan.bday");
  const uint8 sex = MDFN_GetSettingI("wswan.sex");
  const uint8 blood = MDFN_GetSettingI("wswan.blood");

  language = lang;

  wsRAMSize = 65536;
  sram_size = ssize;

  #ifdef WANT_DEBUGGER
  {
   ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "physical", "CPU Physical", 20);
   ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "ram", "RAM", (int)(log(wsRAMSize) / log(2)));

   ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "cs", "Code Segment", 16);
   ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "ss", "Stack Segment", 16);
   ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "ds", "Data Segment", 16);
   ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "es", "Extra Segment", 16);
  }
  #endif

  // WSwan_EEPROMInit() will also clear wsEEPROM
  WSwan_EEPROMInit(MDFN_GetSettingS("wswan.name").c_str(), byear, bmonth, bday, sex, blood);

  if(sram_size)
  {
   wsSRAM = new uint8[sram_size];
   memset(wsSRAM, 0, sram_size);
  }

  MDFNMP_AddRAM(wsRAMSize, 0x00000, wsRAM);

  if(sram_size)
   MDFNMP_AddRAM(sram_size, 0x10000, wsSRAM);

  if(IsWW)
   v30mz_init(WSwan_readmem20_WW, WSwan_writemem20_WW, WSwan_readport_WW, WSwan_writeport_WW);
  else
   v30mz_init(WSwan_readmem20, WSwan_writemem20, WSwan_readport, WSwan_writeport);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

void WSwan_MemoryReset(void)
{
 memset(wsRAM, 0, 65536);

 wsRAM[0x75AC] = 0x41;
 wsRAM[0x75AD] = 0x5F;
 wsRAM[0x75AE] = 0x43;
 wsRAM[0x75AF] = 0x31;
 wsRAM[0x75B0] = 0x6E;
 wsRAM[0x75B1] = 0x5F;
 wsRAM[0x75B2] = 0x63;
 wsRAM[0x75B3] = 0x31;

 memset(BankSelector, 0, sizeof(BankSelector));
 ButtonWhich = 0;
 ButtonReadLatch = 0;
 DMASource = 0;
 DMADest = 0;
 DMALength = 0;
 DMAControl = 0;

 SoundDMASource = SoundDMASourceSaved = 0;
 SoundDMALength = SoundDMALengthSaved = 0;
 SoundDMAControl = 0;
 SoundDMATimer = 0;

 //
 WW_FlashLock = 0;
 WW_FWSM = 0;
}

void WSwan_MemoryStateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVARN(wsRAM, "RAM"),
  SFPTR8N(sram_size ? wsSRAM : NULL, sram_size, "SRAM"),
  SFVAR(ButtonWhich),
  SFVAR(ButtonReadLatch),
  SFVAR(WSButtonStatus),
  SFVAR(DMASource),
  SFVAR(DMADest),
  SFVAR(DMALength),
  SFVAR(DMAControl),

  SFVAR(SoundDMASource),
  SFVAR(SoundDMASourceSaved),
  SFVAR(SoundDMALength),
  SFVAR(SoundDMALengthSaved),
  SFVAR(SoundDMAControl),
  SFVAR(SoundDMATimer),

  SFVAR(BankSelector),

  SFPTR8N(IsWW ? wsCartROM : NULL, 524288, "WW flash"),
  SFVAR(WW_FlashLock),
  SFVAR(WW_FWSM),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MEMR");

 if(load)
 {
  if(load < 0x94100)
  {
   uint32 compat_DMADest = DMADest;
   uint16 compat_SoundDMALength = SoundDMALength;

   SFORMAT CompatStateRegs[] =
   {
    SFVARN(compat_DMADest, "DMADest"),
    SFVARN(compat_SoundDMALength, "SoundDMALength"),
    SFEND
   };

   MDFNSS_StateAction(sm, load, data_only, CompatStateRegs, "MEMR");

   DMADest = compat_DMADest;
   SoundDMALength = compat_SoundDMALength;
   SoundDMASourceSaved = SoundDMASource;
   SoundDMALengthSaved = SoundDMALength;
  }

  //
  //
  //
  DMADest &= 0xFFFE;
  DMALength &= 0xFFFE;
  DMASource &= 0x000FFFFE;
  SoundDMASource &= 0x000FFFFF;
  SoundDMASourceSaved &= 0x000FFFFF;
  SoundDMALength &= 0x000FFFFF;
  SoundDMALengthSaved &= 0x000FFFFF;

  for(uint32 A = 0xfe00; A <= 0xFFFF; A++)
  {
   WSwan_GfxWSCPaletteRAMWrite(A, wsRAM[A]);
  }
 }
}

}
