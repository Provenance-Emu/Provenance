/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mednafen/mednafen.h>
#include <mednafen/hash/md5.h>
#include <mednafen/general.h>
#include <mednafen/mempatcher.h>
#include <mednafen/SNSFLoader.h>
#include <mednafen/player.h>
#include <mednafen/FileStream.h>
#include <mednafen/resampler/resampler.h>

#include <vector>
#include <memory>

#include "src/base.hpp"

extern MDFNGI EmulatedSNES;

static void Cleanup(void);

static SpeexResamplerState *resampler = NULL;
static int32 ResampInPos;
static int16 ResampInBuffer[2048][2];
static bool PrevFrameInterlaced;
static int PrevLine;

static bSNES_v059::Interface Interface;
static SNSFLoader *snsf_loader = NULL;

static bool InProperEmu;
static bool SoundOn;
static double SoundLastRate = 0;

static int32 CycleCounter;
static MDFN_Surface *tsurf = NULL;
static int32 *tlw = NULL;
static MDFN_Rect *tdr = NULL;
static EmulateSpecStruct *es = NULL;

static int InputType[2];
static uint8 *InputPtr[8] = { NULL };
static uint16 PadLatch[8];
static bool MultitapEnabled[2];
static bool HasPolledThisFrame;

static int16 MouseXLatch[2];
static int16 MouseYLatch[2];
static uint8 MouseBLatch[2];

static int16 ScopeXLatch[2];
static int16 ScopeYLatch[2];
static uint8 ScopeBLatch[2];
static uint8 ScopeOSCounter[2];
static const uint8 ScopeOSCounter_StartVal = 10;
static const uint8 ScopeOSCounter_TriggerStartThresh = 6;
static const uint8 ScopeOSCounter_TriggerEndThresh = 2;

static std::vector<uint32> ColorMap;	// [32768]

static void BuildColorMap(MDFN_PixelFormat &format, uint8* CustomColorMap)
{
 for(int x = 0; x < 32768; x++) 
 {
  int r, g, b;

  r = (x & (0x1F <<  0)) << 3;
  g = (x & (0x1F <<  5)) >> (5 - 3);
  b = (x & (0x1F << 10)) >> (5 * 2 - 3);

  //r = ((((x >> 0) & 0x1F) * 255 + 15) / 31);
  //g = ((((x >> 5) & 0x1F) * 255 + 15) / 31);
  //b = ((((x >> 10) & 0x1F) * 255 + 15) / 31);

  if(CustomColorMap)
  {
   r = CustomColorMap[x * 3 + 0];
   g = CustomColorMap[x * 3 + 1];
   b = CustomColorMap[x * 3 + 2];
  }

  ColorMap[x] = format.MakeColor(r, g, b);
 }
}

static CustomPalette_Spec CPInfo[] =
{
 { gettext_noop("SNES 15-bit RGB colormap"), NULL, { 32768, 0 } },

 { NULL, NULL }
};

static void BlankMissingLines(int ystart, int ybound, const bool interlaced, const bool field)
{
 for(int y = ystart; y < ybound; y++)
 {
  //printf("Blanked: %d\n", y);
  uint32 *dest_line = tsurf->pixels + (field * tsurf->pitch32) + (y * tsurf->pitch32);
  dest_line[0] = tsurf->MakeColor(0, 0/*rand() & 0xFF*/, 0);
  tlw[(y << interlaced) + field] = 1;
 }
}

void bSNES_v059::Interface::video_scanline(uint16_t *data, unsigned line, unsigned width, unsigned height, bool interlaced, bool field)
{
 const int ppline = PrevLine;

 //if(rand() & 1)
 // return;

 if((int)line <= PrevLine || (PrevLine == -1 && line > 32)) // Second part for PAL 224 line mode
  return;

 PrevLine = line;
 PrevFrameInterlaced = interlaced;

 if(snsf_loader)
  return;

 if(!tsurf || !tlw || !tdr)
  return;

 if(es->skip && !interlaced)
  return;

 if(!interlaced)
  field = 0;


 BlankMissingLines(ppline + 1, line, interlaced, field);
 //if(line == 0)
 // printf("ZOOM: 0x%04x, %d %d, %d\n", data[0], interlaced, field, width);

 const unsigned y = line;
 const uint16 *source_line = data;
 uint32 *dest_line = tsurf->pixels + (field * tsurf->pitch32) + ((y << interlaced) * tsurf->pitch32);

 //if(rand() & 1)
 {
  tlw[(y << interlaced) + field] = width;
 }

 if(width == 512 && (source_line[0] & 0x8000))
 {
  tlw[(y << interlaced) + field] = 256;
  for(int x = 0; x < 256; x++)
  {
   uint16 p1 = source_line[(x << 1) | 0] & 0x7FFF;
   uint16 p2 = source_line[(x << 1) | 1] & 0x7FFF;
   dest_line[x] = ColorMap[(p1 + p2 - ((p1 ^ p2) & 0x0421)) >> 1];
  }
 }
 else
 {
  for(int x = 0; x < width; x++)
   dest_line[x] = ColorMap[source_line[x] & 0x7FFF];
 }

 tdr->w = width;
 tdr->h = height << interlaced;

 es->InterlaceOn = interlaced;
 es->InterlaceField = (interlaced && field);

 MDFN_MidLineUpdate(es, (y << interlaced) + field);
}

void bSNES_v059::Interface::audio_sample(uint16_t l_sample, uint16_t r_sample)
{
 CycleCounter++;

 if(!SoundOn)
  return;

 if(ResampInPos < 2048)
 {
  //l_sample = (rand() & 0x7FFF) - 0x4000;
  //r_sample = (rand() & 0x7FFF) - 0x4000;
  ResampInBuffer[ResampInPos][0] = (int16)l_sample;
  ResampInBuffer[ResampInPos][1] = (int16)r_sample;
  ResampInPos++;
 }
 else
 {
  MDFN_DispMessage("Buffer overflow?");
 }
}

#if 0
class Input {
public:
  enum Device {
    DeviceNone,
    DeviceJoypad,
    DeviceMultitap,
    DeviceMouse,
    DeviceSuperScope,
    DeviceJustifier,
    DeviceJustifiers,
  };

  enum JoypadID {
    JoypadB      =  0, JoypadY     =  1,
    JoypadSelect =  2, JoypadStart =  3,
    JoypadUp     =  4, JoypadDown  =  5,
    JoypadLeft   =  6, JoypadRight =  7,
    JoypadA      =  8, JoypadX     =  9,
    JoypadL      = 10, JoypadR     = 11,
  };
#endif

void bSNES_v059::Interface::input_poll()
{
 if(!InProperEmu)
  return;

 HasPolledThisFrame = true;

 for(int port = 0; port < 2; port++)
 {
  switch(InputType[port])
  {
   case bSNES_v059::Input::DeviceJoypad:
	PadLatch[port] = MDFN_de16lsb(InputPtr[port]);
	break;

   case bSNES_v059::Input::DeviceMultitap:
	for(int index = 0; index < 4; index++)
        {
         if(!index)
          PadLatch[port] = MDFN_de16lsb(InputPtr[port]);
         else
	 {
	  int pi = 2 + 3 * (port ^ 1) + (index - 1);
          PadLatch[pi] = MDFN_de16lsb(InputPtr[pi]);
	 }
        }
        break;

   case bSNES_v059::Input::DeviceMouse:
	MouseXLatch[port] = (int32)MDFN_de32lsb(InputPtr[port] + 0);
	MouseYLatch[port] = (int32)MDFN_de32lsb(InputPtr[port] + 4);
	MouseBLatch[port] = *(uint8 *)(InputPtr[port] + 8);
	break;

   case bSNES_v059::Input::DeviceSuperScope:
	{
	 bool old_ost = (ScopeBLatch[port] & 0x02);

	 ScopeXLatch[port] = (int16)MDFN_de16lsb(InputPtr[port] + 0);
	 ScopeYLatch[port] = (int16)MDFN_de16lsb(InputPtr[port] + 2);
	 ScopeBLatch[port] = *(uint8 *)(InputPtr[port] + 4);

	 if(!old_ost && (ScopeBLatch[port] & 0x02))
	  ScopeOSCounter[port] = ScopeOSCounter_StartVal;
	}
	break;
  }
 }
}

static INLINE int16 sats32tos16(int32 val)
{
 if(val > 32767)
  val = 32767;
 if(val < -32768)
  val = -32768;

 return(val);
}

int16_t bSNES_v059::Interface::input_poll(bool port, unsigned device, unsigned index, unsigned id)
{
 if(!HasPolledThisFrame)
  printf("input_poll(...) before input_poll() for frame, %d %d %d %d\n", port, device, index, id);

 switch(device)
 {
 	case bSNES_v059::Input::DeviceJoypad:
	{
	  return((PadLatch[port] >> id) & 1);
	}
	break;

	case bSNES_v059::Input::DeviceMultitap:
	{
	 if(!index)
          return((PadLatch[port] >> id) & 1);
         else
	  return((PadLatch[2 + 3 * (port ^ 1) + (index - 1)] >> id) & 1);
	}
	break;

	case bSNES_v059::Input::DeviceMouse:
	{
	 assert(port < 2);
	 switch(id)
	 {
	  case bSNES_v059::Input::MouseX:
		return(sats32tos16(MouseXLatch[port]));
		break;

	  case bSNES_v059::Input::MouseY:
		return(sats32tos16(MouseYLatch[port]));
		break;

	  case bSNES_v059::Input::MouseLeft:
		return((int)(bool)(MouseBLatch[port] & 1));
		break;

	  case bSNES_v059::Input::MouseRight:
		return((int)(bool)(MouseBLatch[port] & 2));
		break;
	 }
	}
	break;

	case bSNES_v059::Input::DeviceSuperScope:
	{
	 assert(port < 2);
	 switch(id)
	 {
	  case bSNES_v059::Input::SuperScopeX:
		return(ScopeOSCounter[port] ? 1000 : ScopeXLatch[port]);
		break;

	  case bSNES_v059::Input::SuperScopeY:
		return(ScopeOSCounter[port] ? 1000 : ScopeYLatch[port]);
		break;

	  case bSNES_v059::Input::SuperScopeTrigger:
		{
		 bool trigo = (bool)(ScopeBLatch[port] & 0x01);

		 if(ScopeOSCounter[port] >= ScopeOSCounter_TriggerEndThresh)
		  trigo = 1;

		 if(ScopeOSCounter[port] >= ScopeOSCounter_TriggerStartThresh)
		  trigo = 0;

		 return(trigo);
		}
		break;

	  case bSNES_v059::Input::SuperScopeCursor:
		return((bool)(ScopeBLatch[port] & 0x10));
		break;

	  case bSNES_v059::Input::SuperScopeTurbo:
		return((bool)(ScopeBLatch[port] & 0x08));
		break;

	  case bSNES_v059::Input::SuperScopePause:
		return((bool)(ScopeBLatch[port] & 0x04));
		break;
	 }
	}
	break;
 }

 return(0);
}

#if 0
void bSNES_v059::Interface::init()
{


}

void bSNES_v059::Interface::term()
{


}
#endif

#if 0

namespace memory {
  extern MappedRAM cartrom, cartram, cartrtc;
  extern MappedRAM bsxflash, bsxram, bsxpram;
  extern MappedRAM stArom, stAram;
  extern MappedRAM stBrom, stBram;
  extern MappedRAM gbrom, gbram;
};

#endif

static void SaveMemorySub(bool load, const char *extension, bSNES_v059::MappedRAM *memoryA, bSNES_v059::MappedRAM *memoryB = NULL)
{
 const std::string path = MDFN_MakeFName(MDFNMKF_SAV, 0, extension);
 const size_t total_size = ((memoryA && memoryA->size() != 0 && memoryA->size() != -1U) ? memoryA->size() : 0) +
		       	   ((memoryB && memoryB->size() != 0 && memoryB->size() != -1U) ? memoryB->size() : 0);


 if(!total_size)
  return;

 if(load)
 {
  try
  {
   std::unique_ptr<Stream> gp = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ total_size }));

   if(memoryA && memoryA->size() != 0 && memoryA->size() != -1U)
   {
    gp->read(memoryA->data(), memoryA->size());
   }

   if(memoryB && memoryB->size() != 0 && memoryB->size() != -1U)
   {
    gp->read(memoryB->data(), memoryB->size());
   }
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
 }
 else
 {
  std::vector<PtrLengthPair> MemToSave;

  if(memoryA && memoryA->size() != 0 && memoryA->size() != -1U)
   MemToSave.push_back(PtrLengthPair(memoryA->data(), memoryA->size()));

  if(memoryB && memoryB->size() != 0 && memoryB->size() != -1U)
   MemToSave.push_back(PtrLengthPair(memoryB->data(), memoryB->size()));

  MDFN_DumpToFile(path, MemToSave, true);
 }
}

static void SaveLoadMemory(bool load)
{
  if(bSNES_v059::cartridge.loaded() == false)
   return;

  switch(bSNES_v059::cartridge.mode())
  {
    case bSNES_v059::Cartridge::ModeNormal:
    case bSNES_v059::Cartridge::ModeBsxSlotted: 
    {
      SaveMemorySub(load, "srm", &bSNES_v059::memory::cartram);
      SaveMemorySub(load, "rtc", &bSNES_v059::memory::cartrtc);
    }
    break;

    case bSNES_v059::Cartridge::ModeBsx:
    {
      SaveMemorySub(load, "srm", &bSNES_v059::memory::bsxram );
      SaveMemorySub(load, "psr", &bSNES_v059::memory::bsxpram);
    }
    break;

    case bSNES_v059::Cartridge::ModeSufamiTurbo:
    {
     SaveMemorySub(load, "srm", &bSNES_v059::memory::stAram, &bSNES_v059::memory::stBram);
    }
    break;

    case bSNES_v059::Cartridge::ModeSuperGameBoy:
    {
     SaveMemorySub(load, "sav", &bSNES_v059::memory::gbram);
     SaveMemorySub(load, "rtc", &bSNES_v059::memory::gbrtc);
    }
    break;
  }
}


static bool TestMagic(MDFNFILE *fp)
{
 if(PSFLoader::TestMagic(0x23, fp->stream()))
  return(true);

 if(strcasecmp(fp->ext, "smc") && strcasecmp(fp->ext, "swc") && strcasecmp(fp->ext, "sfc") && strcasecmp(fp->ext, "fig") &&
        strcasecmp(fp->ext, "bs") && strcasecmp(fp->ext, "st"))
 {
  return(false);
 }

 return(true);
}

static void SetupMisc(bool PAL)
{
 PrevFrameInterlaced = false;

 bSNES_v059::video.set_mode(PAL ? bSNES_v059::Video::ModePAL : bSNES_v059::Video::ModeNTSC);

 // Nominal FPS values are a bit off, FIXME(and contemplate the effect on netplay sound buffer overruns/underruns)
 MDFNGameInfo->fps = PAL ? 838977920 : 1008307711;
 MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(32040.5);

 if(!snsf_loader)
 {
  MDFNGameInfo->nominal_width = MDFN_GetSettingB("snes.correct_aspect") ? (PAL ? 344/*354*/ : 292) : 256;
  MDFNGameInfo->nominal_height = PAL ? 239 : 224;
  MDFNGameInfo->lcm_height = MDFNGameInfo->nominal_height * 2;

  //
  // SuperScope coordinate translation stuff:
  //
  MDFNGameInfo->mouse_scale_x = 256.0 / MDFNGameInfo->nominal_width;
  MDFNGameInfo->mouse_scale_y = 1.0;
  MDFNGameInfo->mouse_offs_x = 0.0;
  MDFNGameInfo->mouse_offs_y = 0.0;
 }

 ResampInPos = 0;
 SoundLastRate = 0;
}

static void LoadSNSF(MDFNFILE *fp)
{
 bool PAL = false;

 bSNES_v059::system.init(&Interface);

 MultitapEnabled[0] = false;
 MultitapEnabled[1] = false;

 std::vector<std::string> SongNames;

 snsf_loader = new SNSFLoader(fp->stream());
 {
  uint8 *export_ptr;

  export_ptr = new uint8[8192 * 1024];
  memset(export_ptr, 0x00, 8192 * 1024);
  assert(snsf_loader->ROM_Data.size() <= 8192 * 1024);
  snsf_loader->ROM_Data.read(export_ptr, snsf_loader->ROM_Data.size());
  bSNES_v059::memory::cartrom.map(export_ptr, snsf_loader->ROM_Data.size());
  snsf_loader->ROM_Data.close();

  bSNES_v059::cartridge.load(bSNES_v059::Cartridge::ModeNormal);
 }
 SongNames.push_back(snsf_loader->tags.GetTag("title"));

 Player_Init(1, snsf_loader->tags.GetTag("game"), snsf_loader->tags.GetTag("artist"), snsf_loader->tags.GetTag("copyright"), SongNames);

 bSNES_v059::system.power();
 PAL = (bSNES_v059::system.region() == bSNES_v059::System::PAL);

 SetupMisc(PAL);
}

static void Cleanup(void)
{
 bSNES_v059::memory::cartrom.map(NULL, 0); // So it delete[]s the pointer it took ownership of.

 if(snsf_loader)
 {
  delete snsf_loader;
  snsf_loader = NULL;
 }

 ColorMap.resize(0);

 if(resampler)
 {
  speex_resampler_destroy(resampler);
  resampler = NULL;
 }
}

static const unsigned cheat_page_size = 1024;
template<typename T>
static void CheatMap(bool uics, uint32 addr, T& mr, uint32 offset)
{
 assert((offset + cheat_page_size) <= mr.size());
 MDFNMP_AddRAM(cheat_page_size, addr, mr.data() + offset, uics);
}

// Intended only for the MapLinear type.
template<typename T>
static void CheatMap(bool uics, uint8 bank_lo, uint8 bank_hi, uint16 addr_lo, uint16 addr_hi, T& mr, uint32 offset = 0, uint32 size = 0)
{
 assert(bank_lo <= bank_hi);
 assert(addr_lo <= addr_hi);
 if((int)mr.size() < cheat_page_size)
 {
  if((int)mr.size() > 0)
   printf("Boop: %d\n", mr.size());
  return;
 }

 uint8 page_lo = addr_lo / cheat_page_size;
 uint8 page_hi = addr_hi / cheat_page_size;
 unsigned index = 0;

 for(unsigned bank = bank_lo; bank <= bank_hi; bank++)
 {
  for(unsigned page = page_lo; page <= page_hi; page++)
  {
   if(size)
   {
    if(index >= size)
     uics = false;
    index %= size;
   }

   if((offset + index) >= mr.size())
    uics = false;

   CheatMap(uics, (bank << 16) + (page * cheat_page_size), mr, bSNES_v059::bus.mirror(offset + index, mr.size()));
   index += cheat_page_size;
  }
 }
}

static void Load(MDFNFILE *fp)
{
 bool PAL = FALSE;

 CycleCounter = 0;

 try
 {
  if(PSFLoader::TestMagic(0x23, fp->stream()))
  {
   LoadSNSF(fp);
   return;
  }

  bSNES_v059::system.init(&Interface);

  // Allocate 8MiB of space regardless of actual ROM image size, to prevent malformed or corrupted ROM images
  // from crashing the bsnes cart loading code.
  {
   static const uint64 max_rom_size = 8192 * 1024;
   const uint64 raw_size = fp->size();
   const unsigned header_adjust = (((raw_size & 0x7FFF) == 512) ? 512 : 0);
   const uint64 size = raw_size - header_adjust;
   md5_context md5;
   md5.starts();

   if(size > max_rom_size)
    throw MDFN_Error(0, _("SNES ROM image is too large."));

   if(header_adjust)
   {
    uint8 header_tmp[512];
    fp->read(header_tmp, 512);
    md5.update(header_tmp, 512);	// For Mednafen backwards compat
   }

   std::unique_ptr<uint8[]> export_ptr(new uint8[max_rom_size]);
   memset(export_ptr.get(), 0x00, max_rom_size);
   fp->read(export_ptr.get(), size);

   md5.update(export_ptr.get(), size);
   md5.finish(MDFNGameInfo->MD5);

   //
   // Mirror up to an 8MB boundary so we can implement HAPPY FUNTIME YAAAAAAAY optimizations(like with SuperFX).
   //
   for(uint32 a = (size + 255) &~255; a < max_rom_size; a += 256)
   {
    const uint32 oa = bSNES_v059::bus.mirror(a, size);
    //printf("%08x->%08x\n",a, oa);
    memcpy(&export_ptr[a], &export_ptr[oa], 256);
   }
   bSNES_v059::memory::cartrom.map(export_ptr.release(), size);
   bSNES_v059::cartridge.load(bSNES_v059::Cartridge::ModeNormal);
  }

  bSNES_v059::system.power();

  PAL = (bSNES_v059::system.region() == bSNES_v059::System::PAL);

  SetupMisc(PAL);

  MultitapEnabled[0] = MDFN_GetSettingB("snes.input.port1.multitap");
  MultitapEnabled[1] = MDFN_GetSettingB("snes.input.port2.multitap");

  SaveLoadMemory(true);

  //printf(" %d %d\n", FSettings.SndRate, resampler.max_write());

  MDFNMP_Init(cheat_page_size, (1U << 24) / cheat_page_size);

  //
  // Should more-or-less match what's in: src/memory/smemory/generic.cpp
  //
  if((int)bSNES_v059::memory::cartram.size() > 0 && (bSNES_v059::memory::cartram.size() % cheat_page_size) == 0)
  {
   if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::SuperFXROM)
   {

   }
   else if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::SA1ROM)
   {
    CheatMap(true,  0x00, 0x3f, 0x3000, 0x37ff, bSNES_v059::memory::iram);    //cpuiram); 
    CheatMap(false, 0x00, 0x3f, 0x6000, 0x7fff, bSNES_v059::memory::cartram); //cc1bwram);
    CheatMap(true,  0x40, 0x4f, 0x0000, 0xffff, bSNES_v059::memory::cartram); //cc1bwram);
    CheatMap(false, 0x80, 0xbf, 0x3000, 0x37ff, bSNES_v059::memory::iram);    //cpuiram);
    CheatMap(false, 0x80, 0xbf, 0x6000, 0x7fff, bSNES_v059::memory::cartram); //cc1bwram);
   }
   else if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::SPC7110ROM)
   {

   }
   else if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::BSXROM)
   {

   }
   else if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::BSCLoROM)
   {

   }
   else if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::BSCHiROM)
   {

   }
   else if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::STROM)
   {

   }
   else
   {
    if((int)bSNES_v059::memory::cartram.size() > 0)
    {
     CheatMap(false, 0x20, 0x3f, 0x6000, 0x7fff, bSNES_v059::memory::cartram);
     CheatMap(false, 0xa0, 0xbf, 0x6000, 0x7fff, bSNES_v059::memory::cartram);

     //research shows only games with very large ROM/RAM sizes require MAD-1 memory mapping of RAM
     //otherwise, default to safer, larger RAM address window
     uint16 addr_hi = (bSNES_v059::memory::cartrom.size() > 0x200000 || bSNES_v059::memory::cartram.size() > 32 * 1024) ? 0x7fff : 0xffff;
     const bool meowmeowmoocow = bSNES_v059::memory::cartram.size() <= ((addr_hi + 1) * 14) || bSNES_v059::cartridge.mapper() != bSNES_v059::Cartridge::LoROM;

     CheatMap(meowmeowmoocow, 0x70, 0x7f, 0x0000, addr_hi, bSNES_v059::memory::cartram);

     if(bSNES_v059::cartridge.mapper() == bSNES_v059::Cartridge::LoROM)
      CheatMap(!meowmeowmoocow, 0xf0, 0xff, 0x0000, addr_hi, bSNES_v059::memory::cartram);
    }
   }
  }

  //
  // System(WRAM) mappings should be done last, as they'll partially overwrite some of the cart mappings above, matching bsnes' internal semantics.
  //

  CheatMap(false, 0x00, 0x3f, 0x0000, 0x1fff, bSNES_v059::memory::wram, 0x000000, 0x002000);
  CheatMap(false, 0x80, 0xbf, 0x0000, 0x1fff, bSNES_v059::memory::wram, 0x000000, 0x002000);
  CheatMap(true,  0x7e, 0x7f, 0x0000, 0xffff, bSNES_v059::memory::wram);

  ColorMap.resize(32768);
 }
 catch(std::exception &e)
 {
  Cleanup();
  throw;
 }
}

static void CloseGame(void)
{
 if(!snsf_loader)
 {
  try
  {
   SaveLoadMemory(false);
  }
  catch(std::exception &e)
  {
   MDFN_PrintError("%s", e.what());
  }
 }
 Cleanup();
}

static void Emulate(EmulateSpecStruct *espec)
{
 tsurf = espec->surface;
 tlw = espec->LineWidths;
 tdr = &espec->DisplayRect;
 es = espec;

 for(unsigned i = 0; i < 2; i++)
  ScopeOSCounter[i] -= (bool)ScopeOSCounter[i];

 PrevLine = -1;

 if(!snsf_loader)
 {
  if(!espec->skip && tsurf && tlw)
  {
   tdr->x = 0;
   tdr->y = 0;
   tdr->w = 1;
   tdr->h = 1;
   tlw[0] = 0;	// Mark line widths as valid(ie != ~0; since field == 1 would skip it).
  }

  if(espec->VideoFormatChanged)
   BuildColorMap(espec->surface->format, espec->CustomPalette);
 }

 if(SoundLastRate != espec->SoundRate)
 {
  if(resampler)
  {
   speex_resampler_destroy(resampler);
   resampler = NULL;
  }
  int err = 0;
  int quality = MDFN_GetSettingUI("snes.apu.resamp_quality");

  resampler = speex_resampler_init_frac(2, 64081, 2 * (int)(espec->SoundRate ? espec->SoundRate : 48000),
					   32040.5, (int)(espec->SoundRate ? espec->SoundRate : 48000), quality, &err);
  SoundLastRate = espec->SoundRate;

  //printf("%f ms\n", 1000.0 * speex_resampler_get_input_latency(resampler) / 32040.5);
 }

 if(!snsf_loader)
 {
  MDFNMP_ApplyPeriodicCheats();
 }

 // Make sure to trash any leftover samples, generated from system.runtosave() in save state saving, if sound is now disabled.
 if(SoundOn && !espec->SoundBuf)
 {
  ResampInPos = 0;
 }

 SoundOn = espec->SoundBuf ? true : false;

 HasPolledThisFrame = false;
 InProperEmu = TRUE;

 // More aggressive frameskipping disabled until we can rule out undesirable side-effects and interactions.
 //bSNES_v059::ppu.enable_renderer(!espec->skip || PrevFrameInterlaced);
 bSNES_v059::system.run_mednafen_custom();
 bSNES_v059::ppu.enable_renderer(true);


 //
 // Blank out any missed lines(for e.g. display height change with PAL emulation)
 //
 if(!snsf_loader && !es->skip && tsurf && tlw)
 {
  //printf("%d\n", PrevLine + 1);
  BlankMissingLines(PrevLine + 1, tdr->h >> es->InterlaceOn, es->InterlaceOn, es->InterlaceField);
 }

 tsurf = NULL;
 tlw = NULL;
 tdr = NULL;
 es = NULL;
 InProperEmu = FALSE;

 espec->MasterCycles = CycleCounter;
 CycleCounter = 0;

 //if(!espec->MasterCycles)
 //{
 // puts("BOGUS GNOMES");
 // espec->MasterCycles = 1;
 //}
 //printf("%d\n", espec->MasterCycles);

 if(espec->SoundBuf)
 {
  spx_uint32_t in_len; // "Number of input samples in the input buffer. Returns the number of samples processed. This is all per-channel."
  spx_uint32_t out_len; // "Size of the output buffer. Returns the number of samples written. This is all per-channel."

  // Hrm, still crackly with some games(like MMX) when rewinding...
  if(espec->NeedSoundReverse)
  {
   for(unsigned lr = 0; lr < 2; lr++)
   {
    int16* p0 = &ResampInBuffer[0][lr];
    int16* p1 = &ResampInBuffer[ResampInPos - 1][lr];
    unsigned count = ResampInPos >> 1;

    while(MDFN_LIKELY(count--))
    {
     int16 tmp;

     tmp = *p0;
     *p0 = *p1;
     *p1 = tmp;
     p0 += 2;
     p1 -= 2;
    }
   }
   espec->NeedSoundReverse = false;
  }

  //printf("%d\n", ResampInPos);
  in_len = ResampInPos;
  out_len = 524288; //8192;     // FIXME, real size.

  speex_resampler_process_interleaved_int(resampler, (const spx_int16_t *)ResampInBuffer, &in_len, (spx_int16_t *)espec->SoundBuf, &out_len);

  assert(in_len <= ResampInPos);

  if((ResampInPos - in_len) > 0)
   memmove(ResampInBuffer, ResampInBuffer + in_len, (ResampInPos - in_len) * sizeof(int16) * 2);

  ResampInPos -= in_len;

  espec->SoundBufSize = out_len;
 }

 MDFNGameInfo->mouse_sensitivity = MDFN_GetSettingF("snes.mouse_sensitivity");

 if(snsf_loader)
 {
  if(!espec->skip)
  {
   espec->LineWidths[0] = ~0;
   Player_Draw(espec->surface, &espec->DisplayRect, 0, espec->SoundBuf, espec->SoundBufSize);
  }
 }


#if 0
 {
  static int skipframe = 3;

  if(skipframe)
   skipframe--;
  else
  {
   static unsigned fc = 0;
   static uint64 cc = 0;
   static uint64 cc2 = 0;

   fc++;
   cc += espec->MasterCycles;
   cc2 += espec->SoundBufSize;

   printf("%f %f\n", (double)fc / ((double)cc / 32040.5), (double)fc / ((double)cc2 / espec->SoundRate));
  }
 }
#endif
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 const uint32 length = bSNES_v059::system.serialize_size();
 bSNES_v059::Input* inpp = &bSNES_v059::input;

 SFORMAT ExtraStateRegs[] =
 {
   SFARRAY16(PadLatch, 8),

   SFARRAY16(MouseXLatch, 2),
   SFARRAY16(MouseYLatch, 2),
   SFARRAY(MouseBLatch, 2),

   SFARRAY16(ScopeXLatch, 2),
   SFARRAY16(ScopeYLatch, 2),
   SFARRAY(ScopeBLatch, 2),
   SFARRAY(ScopeOSCounter, 2),

   SFVAR(inpp->latchx),
   SFVAR(inpp->latchy),
#define INPP_HELPER(n)				\
   SFVAR(inpp->port[n].counter0),		\
   SFVAR(inpp->port[n].counter1),		\
   SFVAR(inpp->port[n].superscope.x),		\
   SFVAR(inpp->port[n].superscope.y),		\
   SFVAR(inpp->port[n].superscope.trigger),	\
   SFVAR(inpp->port[n].superscope.cursor),	\
   SFVAR(inpp->port[n].superscope.turbo),	\
   SFVAR(inpp->port[n].superscope.pause),	\
   SFVAR(inpp->port[n].superscope.offscreen),	\
   SFVAR(inpp->port[n].superscope.turbolock),	\
   SFVAR(inpp->port[n].superscope.triggerlock),	\
   SFVAR(inpp->port[n].superscope.pauselock)

   INPP_HELPER(0),
   INPP_HELPER(1),

#undef INPP_HELPER

   SFEND
 };

 if(load)
 {
  std::unique_ptr<uint8[]> ptr(new uint8[length]);

  SFORMAT StateRegs[] =
  {
   SFARRAYN(ptr.get(), length, "OmniCat"),
   { ExtraStateRegs, ~0U, 0, NULL },
   SFEND
  };

  MDFNSS_StateAction(sm, 1, data_only, StateRegs, "DATA");

  //srand(99);
  //for(int i = 16; i < length; i++)
  // ptr[i] = rand() & 0x3;

  serializer state(ptr.get(), length);

  if(!bSNES_v059::system.unserialize(state))
   throw MDFN_Error(0, _("bSNES core unserializer error."));
 }
 else // save:
 {
  if(bSNES_v059::scheduler.sync != bSNES_v059::Scheduler::SyncAll)
   bSNES_v059::system.runtosave();

  serializer state(length);

  bSNES_v059::system.serialize(state);

  assert(state.size() == length);

  uint8 *ptr = const_cast<uint8 *>(state.data());

  SFORMAT StateRegs[] =
  {
   SFARRAYN(ptr, length, "OmniCat"),
   { ExtraStateRegs, ~0U, 0, NULL },
   SFEND
  };

  MDFNSS_StateAction(sm, 0, data_only, StateRegs, "DATA");
 }
}

struct StrToBSIT_t
{
 const char *str;
 const int id;
};

static const StrToBSIT_t StrToBSIT[] =
{
 { "none",   	bSNES_v059::Input::DeviceNone },
 { "gamepad",   bSNES_v059::Input::DeviceJoypad },
 { "multitap",  bSNES_v059::Input::DeviceMultitap },
 { "mouse",   	bSNES_v059::Input::DeviceMouse },
 { "superscope",   bSNES_v059::Input::DeviceSuperScope },
 { "justifier",   bSNES_v059::Input::DeviceJustifier },
 { "justifiers",   bSNES_v059::Input::DeviceJustifiers },
 { NULL,	-1	},
};


static void SetInput(unsigned port, const char *type, uint8 *ptr)
{
 assert(port < 8);

 if(port < 2)
 {
  const StrToBSIT_t *sb = StrToBSIT;
  int id = -1;

  if(MultitapEnabled[port] && !strcmp(type, "gamepad"))
   type = "multitap";

  while(sb->str && id == -1)
  {
   if(!strcmp(type, sb->str))
    id = sb->id;
   sb++;
  }
  assert(id != -1);

  InputType[port] = id;

  if(port)
   bSNES_v059::config.controller_port2 = id;
  else
   bSNES_v059::config.controller_port1 = id;

  bSNES_v059::input.port_set_device(port, id);

#if 0
  switch(config().input.port1) { default:
    case ControllerPort1::None: mapper().port1 = 0; break;
    case ControllerPort1::Gamepad: mapper().port1 = &Controllers::gamepad1; break;
    case ControllerPort1::Asciipad: mapper().port1 = &Controllers::asciipad1; break;
    case ControllerPort1::Multitap: mapper().port1 = &Controllers::multitap1; break;
    case ControllerPort1::Mouse: mapper().port1 = &Controllers::mouse1; break;
  }

  switch(config().input.port2) { default:
    case ControllerPort2::None: mapper().port2 = 0; break;
    case ControllerPort2::Gamepad: mapper().port2 = &Controllers::gamepad2; break;
    case ControllerPort2::Asciipad: mapper().port2 = &Controllers::asciipad2; break;
    case ControllerPort2::Multitap: mapper().port2 = &Controllers::multitap2; break;
    case ControllerPort2::Mouse: mapper().port2 = &Controllers::mouse2; break;
    case ControllerPort2::SuperScope: mapper().port2 = &Controllers::superscope; break;
    case ControllerPort2::Justifier: mapper().port2 = &Controllers::justifier1; break;
    case ControllerPort2::Justifiers: mapper().port2 = &Controllers::justifiers; break;
  }
#endif

 }


 InputPtr[port] = (uint8 *)ptr;
}

static void SetLayerEnableMask(uint64 mask)
{

}


static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_RESET: bSNES_v059::system.reset(); break;
  case MDFN_MSC_POWER: bSNES_v059::system.power(); break;
 }
}

static const IDIISG GamepadIDII =
{
 { "b", "B (center, lower)", 7, IDIT_BUTTON_CAN_RAPID, NULL },
 { "y", "Y (left)", 6, IDIT_BUTTON_CAN_RAPID, NULL },
 { "select", "SELECT", 4, IDIT_BUTTON, NULL },
 { "start", "START", 5, IDIT_BUTTON, NULL },
 { "up", "UP ↑", 0, IDIT_BUTTON, "down" },
 { "down", "DOWN ↓", 1, IDIT_BUTTON, "up" },
 { "left", "LEFT ←", 2, IDIT_BUTTON, "right" },
 { "right", "RIGHT →", 3, IDIT_BUTTON, "left" },
 { "a", "A (right)", 9, IDIT_BUTTON_CAN_RAPID, NULL },
 { "x", "X (center, upper)", 8, IDIT_BUTTON_CAN_RAPID, NULL },
 { "l", "Left Shoulder", 10, IDIT_BUTTON, NULL },
 { "r", "Right Shoulder", 11, IDIT_BUTTON, NULL },
};

static const IDIISG MouseIDII =
{
 { "x_axis", "X Axis", -1, IDIT_X_AXIS_REL },
 { "y_axis", "Y Axis", -1, IDIT_Y_AXIS_REL },
 { "left", "Left Button", 0, IDIT_BUTTON, NULL },
 { "right", "Right Button", 1, IDIT_BUTTON, NULL },
};

static const IDIISG SuperScopeIDII =
{
 { "x_axis", "X Axis", -1, IDIT_X_AXIS },
 { "y_axis", "Y Axis", -1, IDIT_Y_AXIS },

 { "trigger", "Trigger", 0, IDIT_BUTTON, NULL  },
 { "offscreen_shot", "Offscreen Shot(Simulated)", 1, IDIT_BUTTON, NULL  },
 { "pause", "Pause", 2, IDIT_BUTTON, NULL },
 { "turbo", "Turbo", 3, IDIT_BUTTON, NULL },
 { "cursor", "Cursor", 4, IDIT_BUTTON, NULL },
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoSNESPort1 =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Gamepad
 {
  "gamepad",
  "Gamepad",
  NULL,
  GamepadIDII
 },

 // Mouse
 {
  "mouse",
  "Mouse",
  NULL,
  MouseIDII
 },
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoSNESPort2 =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Gamepad
 {
  "gamepad",
  "Gamepad",
  NULL,
  GamepadIDII
 },

 // Mouse
 {
  "mouse",
  "Mouse",
  NULL,
  MouseIDII
 },

 // Super Scope
 {
  "superscope",
  "Super Scope",
  gettext_noop("Monkey!"),
  SuperScopeIDII
 },
};


static const std::vector<InputDeviceInfoStruct> InputDeviceInfoTapPort =
{
 // Gamepad
 {
  "gamepad",
  "Gamepad",
  NULL,
  GamepadIDII,
 },
};


static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "port1", "Port 1/1A", InputDeviceInfoSNESPort1, "gamepad" },
 { "port2", "Port 2/2A", InputDeviceInfoSNESPort2, "gamepad" },
 { "port3", "Port 2B", InputDeviceInfoTapPort, "gamepad" },
 { "port4", "Port 2C", InputDeviceInfoTapPort, "gamepad" },
 { "port5", "Port 2D", InputDeviceInfoTapPort, "gamepad" },
 { "port6", "Port 1B", InputDeviceInfoTapPort, "gamepad" },
 { "port7", "Port 1C", InputDeviceInfoTapPort, "gamepad" },
 { "port8", "Port 1D", InputDeviceInfoTapPort, "gamepad" },
};

static void InstallReadPatch(uint32 address, uint8 value, int compare)
{
 bSNES_v059::CheatCode tc;

 tc.addr = address;
 tc.data = value;
 tc.compare = compare;

 //printf("%08x %02x %d\n", address, value, compare);

 bSNES_v059::cheat.enable(true);
 bSNES_v059::cheat.install_read_patch(tc);
}

static void RemoveReadPatches(void)
{
 bSNES_v059::cheat.enable(false);
 bSNES_v059::cheat.remove_read_patches();
}


static const MDFNSetting SNESSettings[] =
{
 { "snes.input.port1.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on SNES port 1."), NULL, MDFNST_BOOL, "0", NULL, NULL },
 { "snes.input.port2.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on SNES port 2."), NULL, MDFNST_BOOL, "0", NULL, NULL },

 { "snes.mouse_sensitivity", MDFNSF_NOFLAGS, gettext_noop("Emulated mouse sensitivity."), NULL, MDFNST_FLOAT, "0.50", NULL, NULL, NULL },

 { "snes.correct_aspect", MDFNSF_CAT_VIDEO, gettext_noop("Correct the aspect ratio."), gettext_noop("Note that regardless of this setting's value, \"512\" and \"256\" width modes will be scaled to the same dimensions for display."), MDFNST_BOOL, "0" },

 { "snes.apu.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("APU output resampler quality."), gettext_noop("0 is lowest quality and latency and CPU usage, 10 is highest quality and latency and CPU usage.\n\nWith a Mednafen sound output rate of about 32041Hz or higher: Quality \"0\" resampler has approximately 0.125ms of latency, quality \"5\" resampler has approximately 1.25ms of latency, and quality \"10\" resampler has approximately 3.99ms of latency."), MDFNST_UINT, "5", "0", "10" },

 { NULL }
};


static bool DecodeGG(const std::string& cheat_string, MemoryPatch* patch)
{
 if(cheat_string.size() != 8 && cheat_string.size() != 9)
  throw MDFN_Error(0, _("Game Genie code is of an incorrect length."));

 if(cheat_string.size() == 9 && (cheat_string[4] != '-' && cheat_string[4] != '_' && cheat_string[4] != ' '))
  throw MDFN_Error(0, _("Game Genie code is malformed."));

 uint32 ev = 0;

 for(unsigned i = 0; i < 8; i++)
 {
  int c = cheat_string[(i >= 4 && cheat_string.size() == 9) ? (i + 1) : i];
  static const uint8 subst_table[16] = { 0x4, 0x6, 0xD, 0xE, 0x2, 0x7, 0x8, 0x3,
				  	 0xB, 0x5, 0xC, 0x9, 0xA, 0x0, 0xF, 0x1 };
  ev <<= 4;

  if(c >= '0' && c <= '9')
   ev |= subst_table[c - '0'];
  else if(c >= 'a' && c <= 'f')
   ev |= subst_table[c - 'a' + 0xA];
  else if(c >= 'A' && c <= 'F')
   ev |= subst_table[c - 'A' + 0xA];
  else
  {
   if(c & 0x80)
    throw MDFN_Error(0, _("Invalid character in Game Genie code."));
   else
    throw MDFN_Error(0, _("Invalid character in Game Genie code: %c"), c);
  }
 }

 uint32 addr = 0;
 uint8 val = 0;;
 static const uint8 bm[24] = 
 {
  0x06, 0x07, 0x08, 0x09, 0x10, 0x11, 0x12, 0x13, 0x0e, 0x0f, 0x00, 0x01, 0x14, 0x15, 0x16, 0x17, 0x02, 0x03, 0x04, 0x05, 0x0a, 0x0b, 0x0c, 0x0d
 };


 val = ev >> 24;
 for(unsigned i = 0; i < 24; i++)
  addr |= ((ev >> bm[i]) & 1) << i;

 patch->addr = addr;
 patch->val = val;
 patch->length = 1;
 patch->type = 'S';

 //printf("%08x %02x\n", addr, val);

 return(false);
}

static bool DecodePAR(const std::string& cheat_string, MemoryPatch* patch)
{
 uint32 addr;
 uint8 val;

 if(cheat_string.size() != 8 && cheat_string.size() != 9)
  throw MDFN_Error(0, _("Pro Action Replay code is of an incorrect length."));

 if(cheat_string.size() == 9 && (cheat_string[6] != ':' && cheat_string[6] != ';' && cheat_string[6] != ' '))
  throw MDFN_Error(0, _("Pro Action Replay code is malformed."));


 uint32 ev = 0;

 for(unsigned i = 0; i < 8; i++)
 {
  int c = cheat_string[(i >= 6 && cheat_string.size() == 9) ? (i + 1) : i];

  ev <<= 4;

  if(c >= '0' && c <= '9')
   ev |= c - '0';
  else if(c >= 'a' && c <= 'f')
   ev |= c - 'a' + 0xA;
  else if(c >= 'A' && c <= 'F')
   ev |= c - 'A' + 0xA;
  else
  {
   if(c & 0x80)
    throw MDFN_Error(0, _("Invalid character in Pro Action Replay code."));
   else
    throw MDFN_Error(0, _("Invalid character in Pro Action Replay code: %c"), c);
  }
 }

 patch->addr = ev >> 8;
 patch->val = ev & 0xFF;
 patch->length = 1;
 patch->type = 'R';

 return(false);
}

static CheatFormatStruct CheatFormats[] =
{
 { "Game Genie", "", DecodeGG },
 { "Pro Action Replay", "", DecodePAR },
};

static CheatFormatInfoStruct CheatFormatInfo =
{
 2,
 CheatFormats
};


static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".smc", "Super Magicom ROM Image" },
 { ".swc", "Super Wildcard ROM Image" },
 { ".sfc", "Cartridge ROM Image" },
 { ".fig", "Cartridge ROM Image" },

 { ".bs", "BS-X EEPROM Image" },
 { ".st", "Sufami Turbo Cartridge ROM Image" },

 { NULL, NULL }
};

MDFNGI EmulatedSNES =
{
 "snes",
 "Super Nintendo Entertainment System/Super Famicom",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,						// Debugger
 PortInfo,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,
 SetLayerEnableMask,
 NULL,	// Layer names, null-delimited
 NULL,
 NULL,

 CPInfo,
 1 << 0,

 InstallReadPatch,
 RemoveReadPatches,
 NULL, //MemRead,
 &CheatFormatInfo,
 true,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
 SNESSettings,
 0,
 0,
 FALSE, // Multires

 512,   // lcm_width
 480,   // lcm_height           (replaced in game load)
 NULL,  // Dummy

 256,   // Nominal width	(replaced in game load)
 240,   // Nominal height	(replaced in game load)
 
 512,	// Framebuffer width
 512,	// Framebuffer height

 2,     // Number of output sound channels
};


