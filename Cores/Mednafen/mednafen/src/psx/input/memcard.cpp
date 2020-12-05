/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* memcard.cpp:
**  Copyright (C) 2012-2016 Mednafen Team
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

// I could find no other commands than 'R', 'W', and 'S' (not sure what 'S' is for, however)

#include "../psx.h"
#include "../frontio.h"
#include "memcard.h"

namespace MDFN_IEN_PSX
{

class InputDevice_Memcard final : public InputDevice
{
 public:

 InputDevice_Memcard() MDFN_COLD;
 virtual ~InputDevice_Memcard() override MDFN_COLD;

 virtual void Power(void) override MDFN_COLD;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;

 //
 //
 //
 virtual void SetDTR(bool new_dtr) override;
 virtual bool GetDSR(void) override;
 virtual bool Clock(bool TxD, int32 &dsr_pulse_delay) override;

 //
 //
 virtual uint32 GetNVSize(void) const override;
 virtual const uint8* ReadNV(void) const override;
 virtual void WriteNV(const uint8 *buffer, uint32 offset, uint32 size) override;

 virtual uint64 GetNVDirtyCount(void) const override;
 virtual void ResetNVDirtyCount(void) override;

 private:

 void Format(void);

 bool presence_new;

 uint8 card_data[1 << 17];
 uint8 rw_buffer[128];
 uint8 write_xor;

 //
 // Used to avoid saving unused memory cards' card data in save states.
 // Set to false on object initialization, set to true when data is written to card_data that differs
 // from existing data(either from loading a memory card saved to disk, or from a game writing to the memory card).
 //
 // Save and load its state to/from save states.
 //
 bool data_used;

 //
 // Do not save dirty_count in save states!
 //
 uint64 dirty_count;

 bool dtr;
 int32 command_phase;
 uint32 bitpos;
 uint8 receive_buffer;

 uint8 command;
 uint16 addr;
 uint8 calced_xor;

 uint8 transmit_buffer;
 uint32 transmit_count;
};

void InputDevice_Memcard::Format(void)
{
 memset(card_data, 0x00, sizeof(card_data));

 card_data[0x00] = 0x4D;
 card_data[0x01] = 0x43;
 card_data[0x7F] = 0x0E;

 for(unsigned int A = 0x80; A < 0x800; A += 0x80)
 {
  card_data[A + 0x00] = 0xA0;
  card_data[A + 0x08] = 0xFF;
  card_data[A + 0x09] = 0xFF;
  card_data[A + 0x7F] = 0xA0;
 }

 for(unsigned int A = 0x0800; A < 0x1200; A += 0x80)
 {
  card_data[A + 0x00] = 0xFF;
  card_data[A + 0x01] = 0xFF;
  card_data[A + 0x02] = 0xFF;
  card_data[A + 0x03] = 0xFF;
  card_data[A + 0x08] = 0xFF;
  card_data[A + 0x09] = 0xFF;
 }
}

InputDevice_Memcard::InputDevice_Memcard()
{
 Power();

 data_used = false;
 dirty_count = 0;

 // Init memcard as formatted.
 assert(sizeof(card_data) == (1 << 17));
 Format();
}

InputDevice_Memcard::~InputDevice_Memcard()
{

}

void InputDevice_Memcard::Power(void)
{
 dtr = 0;

 //buttons[0] = buttons[1] = 0;

 command_phase = 0;

 bitpos = 0;

 receive_buffer = 0;

 command = 0;

 transmit_buffer = 0;

 transmit_count = 0;

 addr = 0;

 presence_new = true;
}

void InputDevice_Memcard::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 // Don't save dirty_count.
 SFORMAT StateRegs[] =
 {
  SFVAR(presence_new),

  SFVAR(rw_buffer),
  SFVAR(write_xor),

  SFVAR(dtr),
  SFVAR(command_phase),
  SFVAR(bitpos),
  SFVAR(receive_buffer),

  SFVAR(command),
  SFVAR(addr),
  SFVAR(calced_xor),

  SFVAR(transmit_buffer),
  SFVAR(transmit_count),

  SFVAR(data_used),

  SFEND
 };

 SFORMAT CD_StateRegs[] =
 {
  SFVAR(card_data),
  SFEND
 };

 //
 // Use sname_prefix directly here for backwards compatibility with < 0.9.36.*
 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, sname_prefix, true) && load)
  Power();	// We should technically also Format() here too for state consistency reasons, but I don't want to be murdered by an angry mob so we won't.
 else
 {
  if(data_used)
  {
   char aux_section_name[32];

   trio_snprintf(aux_section_name, sizeof(aux_section_name), "%s_DT", sname_prefix);
   MDFNSS_StateAction(sm, load, data_only, CD_StateRegs, aux_section_name);
  }

  if(load)
  {
   if(data_used)
    dirty_count++;
   else
   {
    //printf("Format: %s\n", section_name);
    Format();
   }
  }
 }
}


void InputDevice_Memcard::SetDTR(bool new_dtr)
{
 if(!dtr && new_dtr)
 {
  command_phase = 0;
  bitpos = 0;
  transmit_count = 0;
 }
 else if(dtr && !new_dtr)
 {
  if(command_phase > 0)
   PSX_WARNING("[MCR] Communication aborted on phase %d", command_phase);
 }
 dtr = new_dtr;
}

bool InputDevice_Memcard::GetDSR(void)
{
 if(!dtr)
  return(0);

 if(!bitpos && transmit_count)
  return(1);

 return(0);
}

bool InputDevice_Memcard::Clock(bool TxD, int32 &dsr_pulse_delay)
{
 bool ret = 1;

 dsr_pulse_delay = 0;

 if(!dtr)
  return(1);

 if(transmit_count)
  ret = (transmit_buffer >> bitpos) & 1;

 receive_buffer &= ~(1 << bitpos);
 receive_buffer |= TxD << bitpos;
 bitpos = (bitpos + 1) & 0x7;

 if(!bitpos)
 {
  //if(command_phase > 0 || transmit_count)
  // printf("[MCRDATA] Received_data=0x%02x, Sent_data=0x%02x\n", receive_buffer, transmit_buffer);

  if(transmit_count)
  {
   transmit_count--;
  }


  if(command_phase == 0)
  {
          if(receive_buffer != 0x81)
            command_phase = -1;
          else
          {
	   //printf("[MCR] Device selected\n");
           transmit_buffer = presence_new ? 0x08 : 0x00;
           transmit_count = 1;
           command_phase++;
          }
  }
  else if(command_phase == 1)
  {
        command = receive_buffer;
	//printf("[MCR] Command received: %c\n", command);
	if(command == 'R' || command == 'W')
	{
	 command_phase++;
         transmit_buffer = 0x5A;
         transmit_count = 1;
	}
	else
	{
	 if(command == 'S')
	 {
	  PSX_WARNING("[MCR] Memcard S command unsupported.");
	 }

	 command_phase = -1;
	 transmit_buffer = 0;
	 transmit_count = 0;
	}
  }
  else if(command_phase == 2)
  {
	transmit_buffer = 0x5D;
	transmit_count = 1;
	command_phase++;
  }
  else if(command_phase == 3)
  {
	transmit_buffer = 0x00;
	transmit_count = 1;
	if(command == 'R')
	 command_phase = 1000;
	else if(command == 'W')
	 command_phase = 2000;
  }
  //
  // Read
  //
  else if(command_phase == 1000)
  {
	addr = receive_buffer << 8;
	transmit_buffer = receive_buffer;
	transmit_count = 1;
	command_phase++;
  }
  else if(command_phase == 1001)
  {
	addr |= receive_buffer & 0xFF;
	transmit_buffer = '\\';
	transmit_count = 1;
	command_phase++;
  }
  else if(command_phase == 1002)
  {
	PSX_DBG(PSX_DBG_SPARSE, "[MCR] Read Command: 0x%04x\n", addr);
	if(addr >= (sizeof(card_data) >> 7))
	 addr = 0xFFFF;

	calced_xor = 0;
	transmit_buffer = ']';
	transmit_count = 1;
	command_phase++;

	// TODO: enable this code(or something like it) when CPU instruction timing is a bit better.
	//
	//dsr_pulse_delay = 32000;
	//goto SkipDPD;
	//
  }
  else if(command_phase == 1003)
  {
	transmit_buffer = addr >> 8;
	calced_xor ^= transmit_buffer;
	transmit_count = 1;
	command_phase++;
  }
  else if(command_phase == 1004)
  {
	transmit_buffer = addr & 0xFF;
	calced_xor ^= transmit_buffer;

	if(addr == 0xFFFF)
	{
	 transmit_count = 1;
	 command_phase = -1;
	}
	else
	{
	 transmit_count = 1;
	 command_phase = 1024;
	}
  }
  // Transmit actual 128 bytes data
  else if(command_phase >= (1024 + 0) && command_phase <= (1024 + 128 - 1))
  {
	transmit_buffer = card_data[(addr << 7) + (command_phase - 1024)];
	calced_xor ^= transmit_buffer;
	transmit_count = 1;
	command_phase++;
  }
  // XOR
  else if(command_phase == (1024 + 128))
  {
	transmit_buffer = calced_xor;
	transmit_count = 1;
	command_phase++;
  }
  // End flag
  else if(command_phase == (1024 + 129))
  {
	transmit_buffer = 'G';
	transmit_count = 1;
	command_phase = -1;
  }
  //
  // Write
  //
  else if(command_phase == 2000)
  {
	calced_xor = receive_buffer;
        addr = receive_buffer << 8;
        transmit_buffer = receive_buffer;
        transmit_count = 1;
        command_phase++;
  }
  else if(command_phase == 2001)
  {
	calced_xor ^= receive_buffer;
        addr |= receive_buffer & 0xFF;
	PSX_DBG(PSX_DBG_SPARSE, "[MCR] Write command: 0x%04x\n", addr);
        transmit_buffer = receive_buffer;
        transmit_count = 1;
        command_phase = 2048;
  }
  else if(command_phase >= (2048 + 0) && command_phase <= (2048 + 128 - 1))
  {
	calced_xor ^= receive_buffer;
	rw_buffer[command_phase - 2048] = receive_buffer;

        transmit_buffer = receive_buffer;
        transmit_count = 1;
        command_phase++;
  }
  else if(command_phase == (2048 + 128))	// XOR
  {
	write_xor = receive_buffer;
	transmit_buffer = '\\';
	transmit_count = 1;
	command_phase++;
  }
  else if(command_phase == (2048 + 129))
  {
	transmit_buffer = ']';
	transmit_count = 1;
	command_phase++;
  }
  else if(command_phase == (2048 + 130))	// End flag
  {
	//MDFN_DispMessage("%02x %02x", calced_xor, write_xor);
	//printf("[MCR] Write End.  Actual_XOR=0x%02x, CW_XOR=0x%02x\n", calced_xor, write_xor);

	if(calced_xor != write_xor)
	{
 	 transmit_buffer = 'N';
   	 PSX_WARNING("[MCR] Write end, calced_xor(0x%02x) != written_xor(0x%02x)", calced_xor, write_xor);
	}
	else if(addr >= (sizeof(card_data) >> 7))
	{
	 transmit_buffer = 0xFF;
	 PSX_WARNING("[MCR] Attempt to write to invalid block 0x%04x", addr);
	}
	else
	{
	 transmit_buffer = 'G';
	 presence_new = false;

	 // If the current data is different from the data to be written, increment the dirty count.
	 // memcpy()'ing over to card_data is also conditionalized here for a slight optimization.
         if(memcmp(&card_data[addr << 7], rw_buffer, 128))
	 {
	  memcpy(&card_data[addr << 7], rw_buffer, 128);
	  dirty_count++;
	  data_used = true;
	 }
	}

	transmit_count = 1;
	command_phase = -1;
  }

  //if(command_phase != -1 || transmit_count)
  // printf("[MCR] Receive: 0x%02x, Send: 0x%02x -- %d\n", receive_buffer, transmit_buffer, command_phase);
 }

 if(!bitpos && transmit_count)
  dsr_pulse_delay = 0x100;

 //SkipDPD: ;

 return(ret);
}

uint32 InputDevice_Memcard::GetNVSize(void) const
{
 return(sizeof(card_data));
}

const uint8* InputDevice_Memcard::ReadNV(void) const
{
 return card_data;
}

void InputDevice_Memcard::WriteNV(const uint8 *buffer, uint32 offset, uint32 size)
{
 if(size)
 {
  dirty_count++;
 }

 while(size--)
 {
  if(card_data[offset & (sizeof(card_data) - 1)] != *buffer)
   data_used = true;

  card_data[offset & (sizeof(card_data) - 1)] = *buffer;
  buffer++;
  offset++;
 }
}

uint64 InputDevice_Memcard::GetNVDirtyCount(void) const
{
 return(dirty_count);
}

void InputDevice_Memcard::ResetNVDirtyCount(void)
{
 dirty_count = 0;
}


InputDevice *Device_Memcard_Create(void)
{
 return new InputDevice_Memcard();
}

}
