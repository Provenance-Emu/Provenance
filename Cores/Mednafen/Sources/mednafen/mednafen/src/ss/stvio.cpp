/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* stvio.cpp - ST-V I/O Emulation
**  Copyright (C) 2022 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
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

#include "ss.h"
#include <mednafen/mednafen.h>
#include <mednafen/hash/crc.h>
#include <mednafen/hash/sha256.h>
#include "ak93c45.h"

#include "stvio.h"
#include "smpc.h"
#include "sound.h"

#include "input/gun.h"

#include "cart.h"
#include "cart/stv.h"

namespace MDFN_IEN_SS
{

static unsigned ControlScheme;

static uint8* DPtr[13];

static uint8 DataDir;
static uint8 DataOut[0x8];
static uint8 DataIn[0x8];

static uint32 CoinPending;
static int32 CoinActiveCounter;

static uint8 HammerX, HammerY;

static uint8 prev_sctrl;
static uint8 prev_ectrl;
static AK93C45 eep;

static IODevice_Gun gun;

void STVIO_SetInput(unsigned port, const char* type, uint8* ptr)
{
 assert(port < 13);

 if(port < 12)
 {
  if(ControlScheme == STV_CONTROL_HAMMER)
  {
   if(port != 0 || strcmp(type, "gun"))
    ptr = nullptr;
  }
  else if(port < 2 && strcmp(type, "gamepad"))
   ptr = nullptr;
 }

 DPtr[port] = ptr;
}

void STVIO_SetCrosshairsColor(unsigned port, uint32 color)
{
 if(!port)
  gun.SetCrosshairsColor(color);
}

void STVIO_TransformInput(void)
{
 *DPtr[12] &= ~0x01; // Zero SS reset button bit to SMPC.
}

void STVIO_UpdateInput(int32 elapsed_time)
{
 memset(DataIn, 0xFF, sizeof(DataIn));

 if(0)
 {
  //memset(DataIn, 0x00, sizeof(DataIn));
  //DataIn[0x2] = 0xFF;
 }
 else if(ControlScheme == STV_CONTROL_HAMMER)
 {
  uint8 tmp_data[2 + 2 + 1];
  int16 nom_x, nom_y;
  int x, y;

  memset(tmp_data, 0, sizeof(tmp_data));

  if(DPtr[0])
  {
   memcpy(tmp_data, DPtr[0], 4);
   tmp_data[4] = DPtr[0][4] & 0x1;
  }

  nom_x = (int16)MDFN_de16lsb(tmp_data + 0);
  nom_y = (int16)MDFN_de16lsb(tmp_data + 2);
  x = ((nom_x * 193) + 32768) >> 16;
  y = ((nom_y + 7) * 49 + 128) >> 8; //55;

  //   printf("%d %d\n", nom_x, nom_y);

  if((tmp_data[4] & 0x01) && x >= (0 - 3) && x <= (62 + 3) && y >= (0 - 3) && y <= (46 + 3))
  {
   HammerX = std::min<int32>(62, std::max<int32>(0, x));
   HammerY = std::min<int32>(46, std::max<int32>(0, y));

   // HAMMERTIME:
   DataIn[0x2] &= ~0x10;
  }

  DataIn[0x0] = ((HammerX >> 4) & 0x3) | ((HammerX & 0x1) << 5) | ((HammerX & 0x2) << 3) | ((HammerX & 0x4) << 5) | ((HammerX & 0x8) << 3);
  DataIn[0x1] = ((HammerY >> 4) & 0x3) | ((HammerY & 0x1) << 5) | ((HammerY & 0x2) << 3) | ((HammerY & 0x4) << 5) | ((HammerY & 0x8) << 3);

  //
  //
  //
  gun.UpdateInput(tmp_data, elapsed_time);
 }
 else
 {
  for(unsigned i = 0; i < 2; i++)
  {
   uint16 tmp = DPtr[i] ? MDFN_de16lsb(DPtr[i] + 0x0) : 0;
   {
    // SW1, SW2, SW3:
    DataIn[i] ^= (((tmp & 0xA0) >> 1) | ((tmp & 0x50) << 1)) | ((tmp >> 10) & 0x01) | ((tmp >> 7) & 0x06);

    if(ControlScheme == STV_CONTROL_RSG)
    {
     if(tmp & 0x1)
      DataIn[i] &= ~0x3;

     if(tmp & 0x2)
      DataIn[i] &= ~0x5;

     if(tmp & 0x4)
      DataIn[i] &= ~0x6;

     if(tmp & 0x8)
      DataIn[i] &= ~0x7;
    }
    else
    {
     // SW4, SW5, SW6:
     DataIn[0x5] ^= (((tmp >> 2) & 0x01) | (tmp & 0x02) | ((tmp << 2) & 0x04)) << (i << 2);
    }
   }
   //
   if(i < 2)
   {
    // Start:
    DataIn[0x2] ^= (tmp & 0x0800) >> (7 - i);
   }
  }
 }

 // Test, Service:
 DataIn[0x2] ^= DPtr[12][0] & 0xC;

 // Pause
 DataIn[0x2] ^= (DPtr[12][0] & 0x10) << 3;

 CoinActiveCounter = std::max<int32>(-75000, CoinActiveCounter - elapsed_time);

 if(CoinPending && CoinActiveCounter == -75000)
 {
  CoinActiveCounter = 75000;
  CoinPending--;
 }

 // Coin(1P)
 DataIn[0x2] ^= (CoinActiveCounter > 0);

 // ?
 DataIn[0x3] = 0x00;
}

void STVIO_Reset(bool powering_up)
{
 if(powering_up)
 {
  eep.Power();
  gun.Power();
 }
 //
 if(powering_up)
 {
  CoinPending = 0;
  CoinActiveCounter = 0;
 }

 DataDir = 0xFF;
 memset(DataOut, 0xFF, sizeof(DataOut));
}

/*
 EEPROM Notes:

 Offs,  Size:
  0x00, 4 bytes: 'SEGA'

  0x08, 2 bytes: CRC-16(poly 0x1021, MSB-first, initial=0x5A81 or prepend data with
		 "SEGA JIM!!!" for silliness), 0x0C ... 0x41, XOR CRC
		 value after calc with 16-bits at 0x42...0x43

  0x0F, 1 byte: EEPROM programming count? initially at 0x01

  0x1A, 2 byte: Settings
		 Bits 0...1: Cabinet type;
			1P=0x0
			2P=0x1 (Default)
			3P=0x2
			4P=0x3

		 Bit 5: Alone/Multi
			Multi=0	(Enables more fields in EEPROM, TODO)
			Alone=1 (Default)

		 Bit 6: Advertise sound
			Off=0
			On=1 (Default)

		 Bit 12: V/H switch
			Normal=0 (Default)
			Vertical=1

 0x1C: 2 byte: Game-ID?  Copied from 0xF40 in cart ROM space(*2 offset for 8-bit)

 0x1E, 8 byte: Game-specific settings?  Copied from 0xF48 in cart ROM space?
*/
static void InitEEPROM(const STVGameInfo* sgi)
{
 std::unique_ptr<uint8[]> rom_data(new uint8[0x1000]);
 unsigned cab_players = 2;
 uint16 crc16, settings;
 uint8 tmp[0x80];

 for(int i = 1; i >= 0; i--)
 {
  for(uint32 offs = 0; offs < 0x1000; offs++)
   rom_data[offs] = CART_STV_PeekROM((offs << i) | i | (!i << 21));

  if(!memcmp(rom_data.get(), "SEGA ST-V(TITAN)", 16))
   break;
  else if(!i)
  {
#ifdef MDFN_ENABLE_DEV_BUILD
   assert(0);
#endif
   return;
  }
 }

 const sha256_digest d = sha256(rom_data.get() + 0x100, 0xD00);
 if(d != "b4e6a81ce0979aed0f017c682bf142681e8d0a5e6a7d10932326ddc26073924d"_sha256)
 {
#ifdef MDFN_ENABLE_DEV_BUILD
  assert(0);
#endif
  return; 
 }

 // 0x01: 1P
 // 0x02: 1P or 2P
 // 0x03: 1P
 // 0x04: 2P
 // 0x05: 2P
 // 0x0C: 2P
 // 0x0F: 1P or 2P
 // 0x10: 3P
 // 0xFF: any
 switch(rom_data[0xF46])
 {
  case 0x01:
  case 0x03:
	cab_players = 1;
	break;

  case 0x10:
	cab_players = 3;
	break;
 }

 memset(tmp, 0xFF, sizeof(tmp));
 memcpy(tmp + 0x00, "SEGA", 4);

 assert(cab_players >= 1 && cab_players <= 4);
 settings = (sgi->rotate << 12) | (cab_players - 1) | (1U << 5) | (1U << 6) | 0x089C;

 tmp[0x0C] = 0x00; // ?
 tmp[0x0D] = 0x00; // ?
 tmp[0x0E] = 0x00; // ?
 tmp[0x0F] = 0x01 + (settings != 0x08FD);
 tmp[0x10] = 0x01; // ?
 tmp[0x11] = 0x00; // ?
 tmp[0x12] = 0x01; // ?
 tmp[0x13] = 0x01; // ?
 tmp[0x14] = 0x00; // ?
 tmp[0x15] = 0x00; // ?
 tmp[0x16] = 0x00; // ?
 tmp[0x17] = 0x00; // ?
 tmp[0x18] = 0x00; // ?
 tmp[0x19] = 0x08; // ?

 MDFN_en16msb(tmp + 0x1A, settings);

 memcpy(tmp + 0x1C, rom_data.get() + 0xF40, 0x2);
 memcpy(tmp + 0x1E, rom_data.get() + 0xF48, 0x8);

 crc16 = crc16_ccitt(0x5A81, tmp + 0x0C, 0x38 - 0x02);
 crc16 ^= MDFN_de16msb(tmp + 0x42);
 MDFN_en16msb(tmp + 0x8, crc16);

 memcpy(tmp + 0x44, tmp + 0x08, 0x3C);
 //
 for(unsigned addr = 0; addr < 0x40; addr++)
  eep.PokeMem(addr, MDFN_de16msb(tmp + (addr << 1)));
}

void STVIO_Init(const STVGameInfo* sgi)
{
 ControlScheme = sgi->control;

 eep.Init();

 InitEEPROM(sgi);
 //
 prev_sctrl = 0xFF;	// Don't change
 prev_ectrl = 0x1C;
}

void STVIO_LoadNV(Stream* s)
{
 uint8 tmp[0x80];

 s->read(tmp, sizeof(tmp));

 for(unsigned addr = 0; addr < 0x40; addr++)
  eep.PokeMem(addr, MDFN_de16msb(tmp + (addr << 1)));
}

void STVIO_SaveNV(Stream* s)
{
 uint8 tmp[0x80];

 for(unsigned addr = 0; addr < 0x40; addr++)
  MDFN_en16msb(tmp + (addr << 1), eep.PeekMem(addr));

 s->write(tmp, sizeof(tmp));
}

void STVIO_WriteIOGA(const sscpu_timestamp_t timestamp, uint8 A, uint8 V)
{
 //printf("[IOGA] Write: %02x %02x\n", A, V);

 if(A < 0x8)
 {
  DataOut[A & 0x7] = V;
 }
 else if(A == 0x8)
  DataDir = V;

 // 0x03: outputs, D0->D7: 1p coin counter, 2p coin counter, 1p coin lock, 2p coin lock, reserved 1, reserved 2, reserved 3, reserved 4
 // 0x04: port E
 // 0x05: port F

 // 0x08: port input/output control?
 //	Port E output, Port F input: 0xEF
 //	Port E output, Port G input: 0xEF
 //	Port F output, Port E input: 0xDF
}

uint8 STVIO_ReadIOGA(const sscpu_timestamp_t timestamp, uint8 A)
{
 uint8 ret = 0xFF;

 //printf("[IOGA] Read: %02x\n", A);
 //assert(A <= 0x8);

 if(A == 0x8)
  ret = DataDir;
 else
 {
  const size_t offs = A & 0x7;

  ret = DataIn[offs];

  if(!(DataDir & (1U << (offs))))
   ret &= DataOut[offs];
 }

 return ret;
}

void STVIO_InsertCoin(void)
{
 CoinPending++;
}

void STVIO_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(DataDir),
  SFVAR(DataOut),
  SFVAR(DataIn),
  SFVAR(CoinPending),
  SFVAR(CoinActiveCounter),
  //
  SFVAR(HammerX),
  SFVAR(HammerY),
  //
  SFVAR(prev_sctrl),
  SFVAR(prev_ectrl),
  //
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "STV_IO");

 eep.StateAction(sm, load, data_only, "STV_EEPROM");
}


template<bool sport>
class IODevice_STVSMPC final : public IODevice
{
 public:

 virtual void TransformInput(uint8* const data, float gun_x_scale, float gun_x_offs) const override;
 virtual void SetTSFreq(const int32 rate) override;

 virtual void ResetTS(void) override;

 virtual uint8 UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted) override;
 virtual void Draw(MDFN_Surface* surface, const MDFN_Rect& drect, const int32* lw, int ifield, float gun_x_scale, float gun_x_offs) const override;
};

template<bool sport>
void IODevice_STVSMPC<sport>::SetTSFreq(const int32 rate)
{
 if(!sport)
  eep.SetTSFreq(rate);
}

template<bool sport>
void IODevice_STVSMPC<sport>::ResetTS(void)
{
 if(!sport)
  eep.ResetTS();
}

template<bool sport>
void IODevice_STVSMPC<sport>::TransformInput(uint8* const data, float gun_x_scale, float gun_x_offs) const
{
 if((ControlScheme == STV_CONTROL_HAMMER) && !sport && DPtr[0])
  gun.TransformInput(DPtr[0], gun_x_scale, gun_x_offs);
}

template<bool sport>
void IODevice_STVSMPC<sport>::Draw(MDFN_Surface* surface, const MDFN_Rect& drect, const int32* lw, int ifield, float gun_x_scale, float gun_x_offs) const
{
 if((ControlScheme == STV_CONTROL_HAMMER) && !sport && DPtr[0])
 {
  gun.Draw(surface, drect, lw, ifield, gun_x_scale, gun_x_offs);
 }
}

template<bool sport>
uint8 IODevice_STVSMPC<sport>::UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted)
{
 uint8 tmp = 0x7F;

 if(!sport)
 {
  const uint8 cur_ectrl = smpc_out & 0x1C;

  eep.UpdateBus(timestamp, (bool)(cur_ectrl & 0x04), (bool)(cur_ectrl & 0x08), (bool)(cur_ectrl & 0x10));

  prev_ectrl = cur_ectrl;

  tmp &= ~0x23;
 }
 else
 {
  const uint8 cur_sctrl = smpc_out & 0x18;

  tmp = (tmp &~ 1) | eep.UpdateBus(timestamp, (bool)(prev_ectrl & 0x04), (bool)(prev_ectrl & 0x08), (bool)(prev_ectrl & 0x10));

  if(prev_sctrl != cur_sctrl)	// Be careful with prev_sctrl init value if changing this code.
  {
   if((prev_sctrl ^ cur_sctrl) & 0x10)
    SOUND_Reset68K();

   if((prev_sctrl ^ cur_sctrl) & 0x08)
    SOUND_ResetSCSP();

   SOUND_Set68KActive(cur_sctrl == 0x00); // FIXME: probably not totally correct.
  }

  prev_sctrl = cur_sctrl;
 }

 if((ControlScheme == STV_CONTROL_HAMMER) && !sport)
 {
  tmp &= gun.UpdateBus(timestamp, smpc_out, smpc_out_asserted) | ~0x40;
 }

 return (smpc_out & smpc_out_asserted) | (tmp &~ smpc_out_asserted);
}


IODevice* STVIO_GetSMPCDevice(bool sport)
{
 static IODevice_STVSMPC<0> p0;
 static IODevice_STVSMPC<1> p1;

 return sport ? (IODevice*)&p1 : (IODevice*)&p0;
}

}
