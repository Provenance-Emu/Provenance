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

#include "../shared.h"
#include "cart.h"
#include "map_rom.h"

class MD_Cart_Type_RMX3 : public MD_Cart_Type
{
	public:

        MD_Cart_Type_RMX3(const md_game_info *ginfo, const uint8 *ROM, const uint32 ROM_size);
        virtual ~MD_Cart_Type_RMX3() override;

        virtual void Write8(uint32 A, uint8 V) override;
        virtual void Write16(uint32 A, uint16 V) override;
        virtual uint8 Read8(uint32 A) override;
        virtual uint16 Read16(uint32 A) override;
        virtual int StateAction(StateMem *sm, int load, int data_only, const char *section_name) override;

        // In bytes
        virtual uint32 GetNVMemorySize(void) override;
        virtual void ReadNVMemory(uint8 *buffer) override;
        virtual void WriteNVMemory(const uint8 *buffer) override;

	private:

	const uint8 *rom;
	uint32 rom_size;
	
};


MD_Cart_Type_RMX3::MD_Cart_Type_RMX3(const md_game_info *ginfo, const uint8 *ROM, const uint32 ROM_size)
{
 this->rom = ROM;
 this->rom_size = ROM_size;
}

MD_Cart_Type_RMX3::~MD_Cart_Type_RMX3()
{

}


void MD_Cart_Type_RMX3::Write8(uint32 A, uint8 V)
{

}

void MD_Cart_Type_RMX3::Write16(uint32 A, uint16 V)
{

}

uint8 MD_Cart_Type_RMX3::Read8(uint32 A)
{
 if(A < 0x400000)
 {
  if(A >= rom_size)
  {
   MD_DBG(MD_DBG_WARNING, "[MAP_RMX3] Unknown read8 from 0x%08x\n", A);
   return(0);
  }
  return(READ_BYTE_MSB(rom, A));
 }

 if(A == 0xa13000)
  return(0x0C);
 if(A == 0x400004)
  return(0x88);

 MD_DBG(MD_DBG_WARNING, "[MAP_RMX3] Unknown read8 from 0x%08x\n", A);
 return(m68k_read_bus_8(A));
}

uint16 MD_Cart_Type_RMX3::Read16(uint32 A)
{
 if(A < 0x400000)
 {
  if(A >= rom_size)
  {
   MD_DBG(MD_DBG_WARNING, "[MAP_RMX3] Unknown read16 from 0x%08x\n", A);
   return(0);
  }
  return(READ_WORD_MSB(rom, A));
 }

 if(A == 0xa13000)
  return(0x0C);
 if(A == 0x400004)
  return(0x88);

 MD_DBG(MD_DBG_WARNING, "[MAP_RMX3] Unknown read16 from 0x%08x\n", A);
 return(m68k_read_bus_16(A));
}

int MD_Cart_Type_RMX3::StateAction(StateMem *sm, int load, int data_only, const char *section_name)
{
 return(1);
}

uint32 MD_Cart_Type_RMX3::GetNVMemorySize(void)
{
 return(0);
}

void MD_Cart_Type_RMX3::ReadNVMemory(uint8 *buffer)
{

}

void MD_Cart_Type_RMX3::WriteNVMemory(const uint8 *buffer)
{

}

MD_Cart_Type *MD_Make_Cart_Type_RMX3(const md_game_info *ginfo, const uint8 *ROM, const uint32 ROM_size, const uint32 iparam, const char *sparam)
{
 return(new MD_Cart_Type_RMX3(ginfo, ROM, ROM_size));
}
