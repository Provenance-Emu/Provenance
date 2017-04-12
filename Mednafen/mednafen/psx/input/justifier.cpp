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
#include "justifier.h"

namespace MDFN_IEN_PSX
{

class InputDevice_Justifier final : public InputDevice
{
 public:

 InputDevice_Justifier(void);
 virtual ~InputDevice_Justifier() override;

 virtual void Power(void) override;
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix) override;
 virtual void UpdateInput(const void *data) override;
 virtual bool RequireNoFrameskip(void) override;
 virtual pscpu_timestamp_t GPULineHook(const pscpu_timestamp_t timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider) override;

 //
 //
 //
 virtual void SetDTR(bool new_dtr) override;
 virtual bool GetDSR(void) override;
 virtual bool Clock(bool TxD, int32 &dsr_pulse_delay) override;

 private:

 bool dtr;

 uint8 buttons;
 bool trigger_eff;
 bool trigger_noclear;

 bool need_hit_detect;

 int16 nom_x, nom_y;
 int32 os_shot_counter;
 bool prev_oss;

 int32 command_phase;
 uint32 bitpos;
 uint8 receive_buffer;

 uint8 command;

 uint8 transmit_buffer[16];
 uint32 transmit_pos;
 uint32 transmit_count;

 //
 // Video timing stuff
 bool prev_vsync;
 int line_counter;
};

InputDevice_Justifier::InputDevice_Justifier(void)
{
 Power();
}

InputDevice_Justifier::~InputDevice_Justifier()
{

}

void InputDevice_Justifier::Power(void)
{
 dtr = 0;

 buttons = 0;
 trigger_eff = 0;
 trigger_noclear = 0;

 need_hit_detect = false;

 nom_x = 0;
 nom_y = 0;

 os_shot_counter = 0;
 prev_oss = 0;

 command_phase = 0;

 bitpos = 0;

 receive_buffer = 0;

 command = 0;

 memset(transmit_buffer, 0, sizeof(transmit_buffer));

 transmit_pos = 0;
 transmit_count = 0;

 prev_vsync = 0;
 line_counter = 0;
}

void InputDevice_Justifier::UpdateInput(const void *data)
{
 uint8 *d8 = (uint8 *)data;

 nom_x = (int16)MDFN_de16lsb(&d8[0]);
 nom_y = (int16)MDFN_de16lsb(&d8[2]);

 trigger_noclear = (bool)(d8[4] & 0x1);
 trigger_eff |= trigger_noclear;

 buttons = (d8[4] >> 1) & 0x3;

 if(os_shot_counter > 0)	// FIXME if UpdateInput() is ever called more than once per video frame(at ~50 or ~60Hz).
  os_shot_counter--;

 if((d8[4] & 0x8) && !prev_oss && os_shot_counter == 0)
  os_shot_counter = 10;
 prev_oss = d8[4] & 0x8;
}

void InputDevice_Justifier::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(dtr),

  SFVAR(buttons),
  SFVAR(trigger_eff),
  SFVAR(trigger_noclear),

  SFVAR(need_hit_detect),

  SFVAR(nom_x),
  SFVAR(nom_y),
  SFVAR(os_shot_counter),
  SFVAR(prev_oss),

  SFVAR(command_phase),
  SFVAR(bitpos),
  SFVAR(receive_buffer),

  SFVAR(command),

  SFARRAY(transmit_buffer, sizeof(transmit_buffer)),
  SFVAR(transmit_pos),
  SFVAR(transmit_count),

  SFVAR(prev_vsync),
  SFVAR(line_counter),

  SFEND
 };
 char section_name[32];
 trio_snprintf(section_name, sizeof(section_name), "%s_Justifier", sname_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
  Power();
 else if(load)
 {
  if((transmit_pos + transmit_count) > sizeof(transmit_buffer))
  {
   transmit_pos = 0;
   transmit_count = 0;
  }
 }
}


bool InputDevice_Justifier::RequireNoFrameskip(void)
{
 return(true);
}

pscpu_timestamp_t InputDevice_Justifier::GPULineHook(const pscpu_timestamp_t timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width,
				     const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider)
{
 pscpu_timestamp_t ret = PSX_EVENT_MAXTS;

 if(vsync && !prev_vsync)
  line_counter = 0;

 if(pixels && pix_clock)
 {
  const int avs = 16; // Not 16 for PAL, fixme.
  int32 gx;
  int32 gy;
  int32 gxa;

  gx = (nom_x * 2 + pix_clock_divider) / (pix_clock_divider * 2);
  gy = nom_y;
  gxa = gx; // - (pix_clock / 400000);
  //if(gxa < 0 && gx >= 0)
  // gxa = 0;

  if(!os_shot_counter && need_hit_detect)
  {
   for(int32 ix = gxa; ix < (gxa + (int32)(pix_clock / 762925)); ix++)
   {
    if(ix >= 0 && ix < (int)width && line_counter >= (avs + gy - 6) && line_counter <= (avs + gy + 6))
    {
     int r, g, b, a;

     format->DecodeColor(pixels[ix], r, g, b, a);

     if((r + g + b) >= 0x40)	// Wrong, but not COMPLETELY ABSOLUTELY wrong, at least. ;)
     {
      ret = timestamp + (int64)(ix + pix_clock_offset) * (44100 * 768) / pix_clock - 177;
      break;
     }
    }
   }
  }

  chair_x = gx;
  chair_y = (avs + gy) - line_counter;
 }

 line_counter++;

 return(ret);
}

void InputDevice_Justifier::SetDTR(bool new_dtr)
{
 if(!dtr && new_dtr)
 {
  command_phase = 0;
  bitpos = 0;
  transmit_pos = 0;
  transmit_count = 0;
 }
 else if(dtr && !new_dtr)
 {
  //if(bitpos || transmit_count)
  // printf("[PAD] Abort communication!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
 }

 dtr = new_dtr;
}

bool InputDevice_Justifier::GetDSR(void)
{
 if(!dtr)
  return(0);

 if(!bitpos && transmit_count)
  return(1);

 return(0);
}

bool InputDevice_Justifier::Clock(bool TxD, int32 &dsr_pulse_delay)
{
 bool ret = 1;

 dsr_pulse_delay = 0;

 if(!dtr)
  return(1);

 if(transmit_count)
  ret = (transmit_buffer[transmit_pos] >> bitpos) & 1;

 receive_buffer &= ~(1 << bitpos);
 receive_buffer |= TxD << bitpos;
 bitpos = (bitpos + 1) & 0x7;

 if(!bitpos)
 {
  //printf("[PAD] Receive: %02x -- command_phase=%d\n", receive_buffer, command_phase);

  if(transmit_count)
  {
   transmit_pos++;
   transmit_count--;
  }


  switch(command_phase)
  {
   case 0:
 	  if(receive_buffer != 0x01)
	    command_phase = -1;
	  else
	  {
	   transmit_buffer[0] = 0x31;
	   transmit_pos = 0;
	   transmit_count = 1;
	   command_phase++;
	  }
	  break;

   case 2:
	//if(receive_buffer)
	// printf("%02x\n", receive_buffer);
	command_phase++;
	break;

   case 3:
	need_hit_detect = receive_buffer & 0x10;	// TODO, see if it's (val&0x10) == 0x10, or some other mask value.
	command_phase++;
	break;

   case 1:
	command = receive_buffer;
	command_phase++;

	transmit_buffer[0] = 0x5A;

	//if(command != 0x42)
	// fprintf(stderr, "Justifier unhandled command: 0x%02x\n", command);
	//assert(command == 0x42);
	if(command == 0x42)
	{
	 transmit_buffer[1] = 0xFF ^ ((buttons & 2) << 2);
	 transmit_buffer[2] = 0xFF ^ (trigger_eff << 7) ^ ((buttons & 1) << 6);

	 if(os_shot_counter > 0)
	 {
	  transmit_buffer[2] |= (1 << 7);
	  if(os_shot_counter == 6 || os_shot_counter == 5)
	  {
	   transmit_buffer[2] &= ~(1 << 7);
	  }
	 }

         transmit_pos = 0;
         transmit_count = 3;

	 trigger_eff = trigger_noclear;
	}
	else
	{
	 command_phase = -1;
	 transmit_buffer[1] = 0;
	 transmit_buffer[2] = 0;
         transmit_pos = 0;
         transmit_count = 0;
	}
	break;

  }
 }

 if(!bitpos && transmit_count)
  dsr_pulse_delay = 200;

 return(ret);
}

InputDevice *Device_Justifier_Create(void)
{
 return new InputDevice_Justifier();
}


IDIISG Device_Justifier_IDII =
{
 { "x_axis", "X Axis", -1, IDIT_X_AXIS },
 { "y_axis", "Y Axis", -1, IDIT_Y_AXIS },

 { "trigger", "Trigger", 0, IDIT_BUTTON, NULL  },

 { "o",	"O",		 1, IDIT_BUTTON,	NULL },
 { "start", "Start",	 2, IDIT_BUTTON,	NULL },

 { "offscreen_shot", "Offscreen Shot(Simulated)", 3, IDIT_BUTTON, NULL },
};



}
