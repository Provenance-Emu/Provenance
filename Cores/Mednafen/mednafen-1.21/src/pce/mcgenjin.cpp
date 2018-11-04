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

#include "pce.h"
#include "mcgenjin.h"

using namespace MDFN_IEN_PCE;

MCGenjin_CS_Device::MCGenjin_CS_Device()
{

}

MCGenjin_CS_Device::~MCGenjin_CS_Device()
{

}

void MCGenjin_CS_Device::Power(void)
{

}

void MCGenjin_CS_Device::Update(int32 timestamp)
{

}

void MCGenjin_CS_Device::ResetTS(int32 ts_base)
{

}

int MCGenjin_CS_Device::StateAction(StateMem *sm, int load, int data_only, const char *sname)
{
 return 1;
}


uint8 MCGenjin_CS_Device::Read(int32 timestamp, uint32 A)
{
 return 0xFF;
}

void MCGenjin_CS_Device::Write(int32 timestamp, uint32 A, uint8 V)
{

}

uint32 MCGenjin_CS_Device::GetNVSize(void) const
{
 return 0;
}

const uint8* MCGenjin_CS_Device::ReadNV(void) const
{
 return NULL;
}

void MCGenjin_CS_Device::WriteNV(const uint8 *buffer, uint32 offset, uint32 count)
{

}

class MCGenjin_CS_Device_RAM : public MCGenjin_CS_Device
{
 public:

 MCGenjin_CS_Device_RAM(uint32 size, bool nv)
 {
  assert(round_up_pow2(size) == size);

  ram.resize(size);
  nonvolatile = nv;
 }

 virtual ~MCGenjin_CS_Device_RAM() override
 {

 }

 virtual void Power(void) override
 {
  if(!nonvolatile)
   ram.assign(ram.size(), 0xFF);

  bank_select = 0;
 }

 virtual int StateAction(StateMem *sm, int load, int data_only, const char *sname) override
 {
  SFORMAT StateRegs[] = 
  {
   SFPTR8(&ram[0], ram.size()),
   SFVAR(bank_select),
   SFEND
  };
  int ret = 1;

  ret &= MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

  return ret;
 }


 virtual uint8 Read(int32 timestamp, uint32 A) override
 {
  return ram[(A | (bank_select << 18)) & (ram.size() - 1)];
 }

 virtual void Write(int32 timestamp, uint32 A, uint8 V) override
 {
  if(!A)
   bank_select = V;

  ram[(A | (bank_select << 18)) & (ram.size() - 1)] = V;
 }

 virtual uint32 GetNVSize(void) const override
 {
  return nonvolatile ? ram.size() : 0;
 }

 virtual const uint8* ReadNV(void) const override
 {
  return &ram[0];
 }

 virtual void WriteNV(const uint8 *buffer, uint32 offset, uint32 count) override
 {
  while(count)
  {
   ram[offset % ram.size()] = *buffer;
   buffer++;
   offset++;
   count--;
  }
 }

 private:
 std::vector<uint8> ram;
 bool nonvolatile;
 uint8 bank_select;
};

void MCGenjin::Power(void)
{
 bank_select = 0;
 dlr = 0;

 stmode_control = 0x00;

 for(unsigned i = 0; i < 2; i++)
  cs[i]->Power();
}

void MCGenjin::Update(int32 timestamp)
{
 for(unsigned i = 0; i < 2; i++)
  cs[i]->Update(timestamp);
}

void MCGenjin::ResetTS(int32 ts_base)
{
 for(unsigned i = 0; i < 2; i++)
  cs[i]->ResetTS(ts_base);
}

uint32 MCGenjin::GetNVSize(const unsigned di) const
{
 return cs[di]->GetNVSize();
}

const uint8* MCGenjin::ReadNV(const unsigned di) const
{
 return cs[di]->ReadNV();
}

void MCGenjin::WriteNV(const unsigned di, const uint8 *buffer, uint32 offset, uint32 count)
{
 cs[di]->WriteNV(buffer, offset, count);
}

MCGenjin::MCGenjin(MDFNFILE* fp)
{
 const uint64 rr_size = fp->size();
 uint8 revision, num256_pages, region, cs_di[2];

 if(rr_size > 1024 * 1024 * 128)
  throw MDFN_Error(0, _("MCGenjin ROM size is too large!"));

 if(rr_size < 8192)
  throw MDFN_Error(0, _("MCGenjin ROM size is too small!"));

 rom.resize(round_up_pow2(rr_size));
 fp->read(&rom[0], rr_size);

 if(memcmp(&rom[0x1FD0], "MCGENJIN", 8))
  throw MDFN_Error(0, _("MC Genjin header magic missing!"));

 revision = rom[0x1FD8];
 num256_pages = rom[0x1FD9];
 region = rom[0x1FDA];
 cs_di[0] = rom[0x1FDB];
 cs_di[1] = rom[0x1FDC];

 MDFN_printf(_("MCGenjin Header:\n"));
 MDFN_indent(1);
 MDFN_printf(_("Revision: 0x%02x\n"), revision);
 MDFN_printf(_("ROM Size: %u\n"), num256_pages * 262144);
 MDFN_printf(_("Region: 0x%02x\n"), region);
 MDFN_printf(_("CS0 Type: 0x%02x\n"), cs_di[0]);
 MDFN_printf(_("CS1 Type: 0x%02x\n"), cs_di[1]);
 MDFN_indent(-1);

 // Don't set addr_write_mask to larger than 0xF unless code in mcgenjin.h is adjusted as well.
 if(revision >= 0x80)
  addr_write_mask = 0xF;
 else
  addr_write_mask = 0x3;

 for(unsigned i = 0; i < 2; i++)
 {
  if((cs_di[i] >= 0x10 && cs_di[i] <= 0x18) || (cs_di[i] >= 0x20 && cs_di[i] <= 0x28))
  {
   MDFN_printf(_("CS%d: %uKiB %sRAM\n"), i, 8 << (cs_di[i] & 0xF), (cs_di[i] & 0x20) ? "Nonvolatile " : "");
   cs[i].reset(new MCGenjin_CS_Device_RAM(8192 << (cs_di[i] & 0xF), (bool)(cs_di[i] & 0x20)));
  }
  else switch(cs_di[i])
  {
   default:
	throw MDFN_Error(0, _("Unsupported MCGENJIN device on CS%d: 0x%02x"), i, cs_di[i]);
	break;

   case 0x00:
	MDFN_printf(_("CS%d: Unused\n"), i);
	cs[i].reset(new MCGenjin_CS_Device());
	break;
  }
 }
}

MCGenjin::~MCGenjin()
{

}

int MCGenjin::StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(bank_select),
  SFVAR(dlr),
  SFEND
 };
 int ret = 1;

 ret &= MDFNSS_StateAction(sm, load, data_only, StateRegs, "MCGENJIN");

 for(unsigned i = 0; i < 2; i++)
  ret &= MDFNSS_StateAction(sm, load, data_only, StateRegs, i ? "MCGENJIN_CS1" : "MCGENJIN_CS0");

 return ret;
}

