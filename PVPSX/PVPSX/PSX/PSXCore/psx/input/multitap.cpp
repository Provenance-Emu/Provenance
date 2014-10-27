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

#include "../psx.h"
#include "../frontio.h"
#include "multitap.h"

/*
 TODO: PS1 multitap appears to have some internal knowledge of controller IDs, so it won't get "stuck" waiting for data from a controller that'll never
       come.  We currently sort of "cheat" due to how the dsr_pulse_delay stuff works, but in the future we should try to emulate this multitap functionality.

       Also, full-mode read startup and subport controller ID read timing isn't quite right, so we should fix that too.
*/

/*
 Notes from tests on real thing(not necessarily emulated the same way here):

	Manual port selection read mode:
		Write 0x01-0x04 instead of 0x01 as first byte, selects port(1=A,2=B,3=C,4=D) to access.

		Ports that don't exist(0x00, 0x05-0xFF) or don't have a device plugged in will not respond(no DSR pulse).

	Full read mode:
		Bit0 of third byte(from-zero-index=0x02) should be set to 1 to enter full read mode, on subsequent reads.

		Appears to require a controller to be plugged into the port specified by the first byte as per manual port selection read mode,
		to write the byte necessary to enter full-read mode; but once the third byte with the bit set has been written, no controller in
		that port is required for doing full reads(and the manual port selection is ignored when doing a full read).

		However, if there are no controllers plugged in, the returned data will be short:
			% 0: 0xff
			% 1: 0x80
			% 2: 0x5a

		Example full-read bytestream(with controllers plugged into port A, port B, and port C, with port D empty):
			% 0: 0xff
			% 1: 0x80
			% 2: 0x5a

			% 3: 0x73	(Port A controller data start)
			% 4: 0x5a
			% 5: 0xff
			% 6: 0xff
			% 7: 0x80
			% 8: 0x8c
			% 9: 0x79
			% 10: 0x8f

			% 11: 0x53	(Port B controller data start)
			% 12: 0x5a
			% 13: 0xff
			% 14: 0xff
			% 15: 0x80
			% 16: 0x80
			% 17: 0x75
			% 18: 0x8e

			% 19: 0x41	(Port C controller data start)
			% 20: 0x5a
			% 21: 0xff
			% 22: 0xff
			% 23: 0xff
			% 24: 0xff
			% 25: 0xff
			% 26: 0xff

			% 27: 0xff	(Port D controller data start)
			% 28: 0xff
			% 29: 0xff
			% 30: 0xff
			% 31: 0xff
			% 32: 0xff
			% 33: 0xff
			% 34: 0xff

*/

namespace MDFN_IEN_PSX
{

InputDevice_Multitap::InputDevice_Multitap()
{
 for(int i = 0; i < 4; i++)
 {
  pad_devices[i] = NULL;
  mc_devices[i] = NULL;
 }
 Power();
}

InputDevice_Multitap::~InputDevice_Multitap()
{
}

void InputDevice_Multitap::SetSubDevice(unsigned int sub_index, InputDevice *device, InputDevice *mc_device)
{
 assert(sub_index < 4);

 //printf("%d\n", sub_index);

 pad_devices[sub_index] = device;
 mc_devices[sub_index] = mc_device;
}


void InputDevice_Multitap::Power(void)
{
 selected_device = -1;
 bit_counter = 0;
 receive_buffer = 0;
 byte_counter = 0;

 mc_mode = false;
 full_mode = false;
 full_mode_setting = false;

 fm_dp = 0;
 memset(fm_buffer, 0, sizeof(fm_buffer));
 fm_deferred_error_temp = false;
 fm_deferred_error = false;
 fm_command_error = false;

 for(int i = 0; i < 4; i++)
 {
  if(pad_devices[i])
   pad_devices[i]->Power();

  if(mc_devices[i])
   mc_devices[i]->Power();
 } 
}

int InputDevice_Multitap::StateAction(StateMem* sm, int load, int data_only, const char* section_name)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(dtr),

  SFVAR(selected_device),
  SFVAR(full_mode_setting),

  SFVAR(full_mode),
  SFVAR(mc_mode),

  SFVAR(fm_dp),
  SFARRAY(&fm_buffer[0][0], sizeof(fm_buffer) / sizeof(fm_buffer[0][0])),

  SFVAR(fm_deferred_error_temp),
  SFVAR(fm_deferred_error),
  SFVAR(fm_command_error),

  SFVAR(command),
  SFVAR(receive_buffer),
  SFVAR(bit_counter),
  SFVAR(byte_counter),

  SFEND
 };
 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name);

 if(load)
 {

 }

 return(ret);
}


void InputDevice_Multitap::SetDTR(bool new_dtr)
{
 bool old_dtr = dtr;
 dtr = new_dtr;

 if(!dtr)
 {
  if(old_dtr)
  {
   //printf("Multitap stop.\n");
  }

  bit_counter = 0;
  receive_buffer = 0;
  selected_device = -1;
  mc_mode = false;
  full_mode = false;
 }

 if(!old_dtr && dtr)
 {
  full_mode = full_mode_setting;

  byte_counter = 0;

  //if(full_mode)
  // printf("Multitap start: %d\n", full_mode);
 }

 for(int i = 0; i < 4; i++)
 {
  pad_devices[i]->SetDTR(dtr);
  mc_devices[i]->SetDTR(dtr);
 }
}

bool InputDevice_Multitap::GetDSR(void)
{
 return(0);
}

bool InputDevice_Multitap::Clock(bool TxD, int32 &dsr_pulse_delay)
{
 if(!dtr)
  return(1);

 bool ret = 1;
 int32 tmp_pulse_delay[2][4] = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } };

 //printf("Receive bit: %d\n", TxD);
 //printf("TxD %d\n", TxD);

 receive_buffer &= ~ (1 << bit_counter);
 receive_buffer |= TxD << bit_counter;

 if(1)
 {
  if(byte_counter == 0)
  {
   bool mangled_txd = TxD;

   if(bit_counter < 4)
    mangled_txd = (0x01 >> bit_counter) & 1;

   for(unsigned i = 0; i < 4; i++)
   {
    pad_devices[i]->Clock(mangled_txd, tmp_pulse_delay[0][i]);
    mc_devices[i]->Clock(mangled_txd, tmp_pulse_delay[1][i]);
   }
  }
  else
  {
   if(full_mode)
   {
    if(byte_counter == 1)
    {
     ret = (0x80 >> bit_counter) & 1;

     for(unsigned i = 0; i < 4; i++)
     { 
      fm_buffer[i][0] &= (pad_devices[i]->Clock(TxD, tmp_pulse_delay[0][i]) << bit_counter) | (~(1U << bit_counter));
     }
    }
    else if(byte_counter == 2)
    {
     ret = (0x5A >> bit_counter) & 1;
    }
    // || byte_counter == (0x03 + 0x08 * 1) || byte_counter == (0x03 + 0x08 * 2) || byte_counter == (0x03 + 0x08 * 3))
    else if(byte_counter >= 0x03 && byte_counter < 0x03 + 0x08 * 4)
    {
     if(!fm_command_error && byte_counter >= (0x03 + 1) && byte_counter < (0x03 + 0x08))
     {
      for(unsigned i = 0; i < 4; i++)
      { 
       fm_buffer[i][byte_counter - 0x03] &= (pad_devices[i]->Clock(0, tmp_pulse_delay[0][i]) << bit_counter) | (~(1U << bit_counter));
      }
     }
     ret &= ((&fm_buffer[0][0])[byte_counter - 0x03] >> bit_counter) & 1;
    }
   }
   else // to if(full_mode)
   {
    if((unsigned)selected_device < 4)
    {
     ret &= pad_devices[selected_device]->Clock(TxD, tmp_pulse_delay[0][selected_device]);
     ret &= mc_devices[selected_device]->Clock(TxD, tmp_pulse_delay[1][selected_device]);
    }
   }
  } // end else to if(byte_counter == 0)
 }

 //
 //
 //

 bit_counter = (bit_counter + 1) & 0x7;
 if(bit_counter == 0)
 {
  //printf("Receive: 0x%02x\n", receive_buffer);
  if(byte_counter == 0)
  {
   mc_mode = (bool)(receive_buffer & 0xF0);
   if(mc_mode)
    full_mode = false;

   //printf("Zoomba: 0x%02x\n", receive_buffer);
   //printf("Full mode: %d %d %d\n", full_mode, bit_counter, byte_counter);

   if(full_mode)
   {
    memset(fm_buffer, 0xFF, sizeof(fm_buffer));
    selected_device = 0;
   }
   else
   {
    //printf("Device select: %02x\n", receive_buffer);
    fm_deferred_error = false;
    selected_device = ((receive_buffer & 0xF) - 1) & 0xFF;
   }
  }

  if(byte_counter == 1)
  {
   command = receive_buffer;

   //printf("Multitap sub-command: %02x\n", command);

   if(full_mode)
   {
    if(command != 0x42)
     fm_command_error = true;
    else
     fm_command_error = fm_deferred_error;
   }
   else
   {
    fm_command_error = false;
   }
   fm_deferred_error = false;
  }

  if((!mc_mode || full_mode) && byte_counter == 2)
  {
   //printf("Full mode setting: %02x\n", receive_buffer);
   full_mode_setting = receive_buffer & 0x01;
  }

  if(full_mode)
  {
   if(byte_counter == (3 + 8 * 0) || byte_counter == (3 + 8 * 1) || byte_counter == (3 + 8 * 2) || byte_counter == (3 + 8 * 3))
   {
    unsigned index = (byte_counter - 3) >> 3;
    assert(index < 4);

    if(index == 0)
     fm_deferred_error_temp = false;     

    if((fm_dp & (1U << index)) && receive_buffer != 0x42)
    {
     //printf("Multitap command check failed: %u, 0x%02x\n", byte_counter, receive_buffer);
     fm_deferred_error_temp = true;
    }
   }

   if(byte_counter == 33)
    fm_deferred_error = fm_deferred_error_temp;
  }

  // Handle DSR stuff
  if(full_mode)
  {
   if(byte_counter == 0)	// Next byte: 0x80
   {
    dsr_pulse_delay = 1000;

    fm_dp = 0;
    for(unsigned i = 0; i < 4; i++)
     fm_dp |= (((bool)(tmp_pulse_delay[0][i])) << i);
   }
   else if(byte_counter == 1)	// Next byte: 0x5A
    dsr_pulse_delay = 0x40;
   else if(byte_counter == 2)	// Next byte(typically, controller-dependent): 0x41
   {
    if(fm_dp)
     dsr_pulse_delay = 0x40;
    else
     dsr_pulse_delay = 0;
   }
   else if(byte_counter >= 3 && byte_counter < 34)	// Next byte when byte_counter==3 (typically, controller-dependent): 0x5A
   {
    if(byte_counter < 10)
    { 
     int d = 0x40;

     for(unsigned i = 0; i < 4; i++)
      if(tmp_pulse_delay[0][i] > d)
       d = tmp_pulse_delay[0][i];

     dsr_pulse_delay = d;
    }
    else
     dsr_pulse_delay = 0x20;

    if(byte_counter == 3 && fm_command_error)
     dsr_pulse_delay = 0;
   }
  } // end if(full_mode)
  else
  {
   if((unsigned)selected_device < 4)
   {
    dsr_pulse_delay = std::max<int32>(tmp_pulse_delay[0][selected_device], tmp_pulse_delay[1][selected_device]);
   }
  }


  //
  //
  //

  //printf("Byte Counter Increment\n");
  if(byte_counter < 255)
   byte_counter++;
 }



 return(ret);
}

}
