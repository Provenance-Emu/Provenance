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

#include "psx.h"
#include "frontio.h"

#include "input/gamepad.h"
#include "input/dualanalog.h"
#include "input/dualshock.h"
#include "input/mouse.h"
#include "input/negcon.h"
#include "input/guncon.h"
#include "input/justifier.h"

#include "input/memcard.h"

#include "input/multitap.h"

#define PSX_FIODBGINFO(format, ...) { /* printf(format " -- timestamp=%d -- PAD temp\n", ## __VA_ARGS__, timestamp); */  }

namespace MDFN_IEN_PSX
{

InputDevice::InputDevice() : chair_r(0), chair_g(0), chair_b(0), draw_chair(0), chair_x(-1000), chair_y(-1000)
{
}

InputDevice::~InputDevice()
{
}

void InputDevice::Power(void)
{
}

void InputDevice::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{

}


void InputDevice::Update(const pscpu_timestamp_t timestamp)
{

}

void InputDevice::ResetTS(void)
{

}

void InputDevice::SetAMCT(bool)
{

}

void InputDevice::SetCrosshairsColor(uint32 color)
{
 chair_r = (color >> 16) & 0xFF;
 chair_g = (color >>  8) & 0xFF;
 chair_b = (color >>  0) & 0xFF;

 draw_chair = (color != (1 << 24));
}

void InputDevice::DrawCrosshairs(uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock)
{
 if(draw_chair && chair_y >= -8 && chair_y <= 8)
 {
  int32 ic;
  int32 x_start, x_bound;

  if(chair_y == 0)
   ic = pix_clock / 762925;
  else
   ic = 0;

  x_start = std::max<int32>(0, chair_x - ic);
  x_bound = std::min<int32>(width, chair_x + ic + 1);

  for(int32 x = x_start; x < x_bound; x++)
  {
   int r, g, b, a;
   int nr, ng, nb;

   format->DecodeColor(pixels[x], r, g, b, a);

   nr = (r + chair_r * 3) >> 2;
   ng = (g + chair_g * 3) >> 2;
   nb = (b + chair_b * 3) >> 2;

   if((int)((abs(r - nr) - 0x40) & (abs(g - ng) - 0x40) & (abs(b - nb) - 0x40)) < 0)
   {
    if((nr | ng | nb) & 0x80)
    {
     nr >>= 1;
     ng >>= 1;
     nb >>= 1;
    }
    else
    {
     nr ^= 0x80;
     ng ^= 0x80;
     nb ^= 0x80;
    }
   }

   pixels[x] = format->MakeColor(nr, ng, nb, a);
  }
 }
}

bool InputDevice::RequireNoFrameskip(void)
{
 return(false);
}

pscpu_timestamp_t InputDevice::GPULineHook(const pscpu_timestamp_t timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider)
{
 return(PSX_EVENT_MAXTS);
}


void InputDevice::UpdateInput(const void *data)
{
}


void InputDevice::SetDTR(bool new_dtr)
{

}

bool InputDevice::GetDSR(void)
{
 return(0);
}

bool InputDevice::Clock(bool TxD, int32 &dsr_pulse_delay)
{
 dsr_pulse_delay = 0;

 return(1);
}

uint32 InputDevice::GetNVSize(void) const
{
 return(0);
}

const uint8* InputDevice::ReadNV(void) const
{
 return NULL;
}

void InputDevice::WriteNV(const uint8 *buffer, uint32 offset, uint32 count)
{

}

uint64 InputDevice::GetNVDirtyCount(void) const
{
 return(0);
}

void InputDevice::ResetNVDirtyCount(void)
{

}

static unsigned EP_to_MP(bool emulate_multitap[2], unsigned ep)
{
 if(!emulate_multitap[0] && emulate_multitap[1])
 {
  if(ep == 0 || ep >= 5)
   return(0);
  else
   return(1);
 }
 else
  return(ep >= 4);
}

static INLINE unsigned EP_to_SP(bool emulate_multitap[2], unsigned ep)
{
 if(!emulate_multitap[0] && emulate_multitap[1])
 {
  if(ep == 0)
   return(0);
  else if(ep < 5)
   return(ep - 1);
  else
   return(ep - 4);
 }
 else
  return(ep & 0x3);
}

void FrontIO::MapDevicesToPorts(void)
{
 if(emulate_multitap[0] && emulate_multitap[1])
 {
  for(unsigned i = 0; i < 2; i++)
  {
   Ports[i] = PossibleMultitaps[i].get();
   MCPorts[i] = PossibleNone.get();
  }
 }
 else if(!emulate_multitap[0] && emulate_multitap[1])
 {
  Ports[0] = Devices[0];
  MCPorts[0] = MCDevices[0];

  Ports[1] = PossibleMultitaps[1].get();
  MCPorts[1] = PossibleNone.get();
 }
 else if(emulate_multitap[0] && !emulate_multitap[1])
 {
  Ports[0] = PossibleMultitaps[0].get();
  MCPorts[0] = PossibleNone.get();

  Ports[1] = Devices[4];
  MCPorts[1] = MCDevices[4];
 }
 else
 {
  for(unsigned i = 0; i < 2; i++)
  {
   Ports[i] = Devices[i];
   MCPorts[i] = MCDevices[i];
  }
 }

 //printf("\n");
 for(unsigned i = 0; i < 8; i++)
 {
  unsigned mp = EP_to_MP(emulate_multitap, i);
  
  if(emulate_multitap[mp])
   PossibleMultitaps[mp]->SetSubDevice(EP_to_SP(emulate_multitap, i), Devices[i], MCDevices[i]);
  else
   PossibleMultitaps[mp]->SetSubDevice(EP_to_SP(emulate_multitap, i), PossibleNone.get(), PossibleNone.get());

  //printf("%d-> multitap: %d, sub-port: %d\n", i, mp, EP_to_SP(emulate_multitap, i));
 }
}

FrontIO::FrontIO()
{
 PossibleNone.reset(new InputDevice());

 for(unsigned i = 0; i < 8; i++)
 {
  PossibleDevices[i].Memcard.reset(Device_Memcard_Create());
  PossibleDevices[i].Gamepad.reset(Device_Gamepad_Create());
  PossibleDevices[i].DualAnalog.reset(Device_DualAnalog_Create(false));
  PossibleDevices[i].AnalogJoy.reset(Device_DualAnalog_Create(true));
  PossibleDevices[i].DualShock.reset(Device_DualShock_Create());
  PossibleDevices[i].Mouse.reset(Device_Mouse_Create());
  PossibleDevices[i].neGcon.reset(Device_neGcon_Create());
  PossibleDevices[i].GunCon.reset(Device_GunCon_Create());
  PossibleDevices[i].Justifier.reset(Device_Justifier_Create());
 }

 for(unsigned i = 0; i < 8; i++)
 {
  Devices[i] = PossibleNone.get();
  DeviceData[i] = NULL;
  MCDevices[i] = PossibleNone.get();
  chair_colors[i] = 1 << 24;
  Devices[i]->SetCrosshairsColor(chair_colors[i]);
 }

 for(unsigned i = 0; i < 2; i++)
 {
  PossibleMultitaps[i].reset(new InputDevice_Multitap());
 }

 MapDevicesToPorts();
}

void FrontIO::SetMultitap(unsigned int pport, bool enabled)
{
 assert(pport < 2);

 if(emulate_multitap[pport] != enabled)
 {
  emulate_multitap[pport] = enabled;
  MapDevicesToPorts();  
  PossibleMultitaps[pport]->Power();
 }
}

void FrontIO::SetAMCT(bool enabled)
{
 for(unsigned i = 0; i < 8; i++)
 {
  Devices[i]->SetAMCT(enabled);
 }
 amct_enabled = enabled;
}

void FrontIO::SetCrosshairsColor(unsigned port, uint32 color)
{
 assert(port < 8);

 chair_colors[port] = color;
 Devices[port]->SetCrosshairsColor(color);
}

FrontIO::~FrontIO()
{

}

pscpu_timestamp_t FrontIO::CalcNextEventTS(pscpu_timestamp_t timestamp, int32 next_event)
{
 pscpu_timestamp_t ret;

 if(ClockDivider > 0 && ClockDivider < next_event)
  next_event = ClockDivider;

 for(int i = 0; i < 4; i++)
  if(dsr_pulse_delay[i] > 0 && next_event > dsr_pulse_delay[i])
   next_event = dsr_pulse_delay[i];

 ret = timestamp + next_event;

 if(irq10_pulse_ts[0] < ret)
  ret = irq10_pulse_ts[0];

 if(irq10_pulse_ts[1] < ret)
  ret = irq10_pulse_ts[1];

 return(ret);
}

static const uint8 ScaleShift[4] = { 0, 0, 4, 6 };

void FrontIO::CheckStartStopPending(pscpu_timestamp_t timestamp, bool skip_event_set)
{
 //const bool prior_ReceiveInProgress = ReceiveInProgress;
 //const bool prior_TransmitInProgress = TransmitInProgress;
 bool trigger_condition = false;

 trigger_condition = (ReceivePending && (Control & 0x4)) || (TransmitPending && (Control & 0x1));

 if(trigger_condition)
 {
  if(ReceivePending)
  {
   ReceivePending = false;
   ReceiveInProgress = true;
   ReceiveBufferAvail = false;
   ReceiveBuffer = 0;
   ReceiveBitCounter = 0;
  }

  if(TransmitPending)
  {
   TransmitPending = false;
   TransmitInProgress = true;
   TransmitBitCounter = 0;
  }

  ClockDivider = std::max<uint32>(0x20, (Baudrate << ScaleShift[Mode & 0x3]) & ~1); // Minimum of 0x20 is an emulation sanity check to prevent severe performance degradation.
  //printf("CD: 0x%02x\n", ClockDivider);
 }

 if(!(Control & 0x5))
 {
  ReceiveInProgress = false;
  TransmitInProgress = false;
 }

 if(!ReceiveInProgress && !TransmitInProgress)
  ClockDivider = 0;

 if(!(skip_event_set))
  PSX_SetEventNT(PSX_EVENT_FIO, CalcNextEventTS(timestamp, 0x10000000));
}

// DSR IRQ bit setting appears(from indirect tests on real PS1) to be level-sensitive, not edge-sensitive
INLINE void FrontIO::DoDSRIRQ(void)
{
 if(Control & 0x1000)
 {
  PSX_FIODBGINFO("[DSR] IRQ");
  istatus = true;
  IRQ_Assert(IRQ_SIO, true);
 }
}


void FrontIO::Write(pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 PSX_FIODBGINFO("[FIO] Write: %08x %08x", A, V);

 V <<= (A & 1) * 8;

 Update(timestamp);

 switch(A & 0xE)
 {
  case 0x0:
  case 0x2:
        V <<= (A & 2) * 8;
	TransmitBuffer = V;
	TransmitPending = true;
	TransmitInProgress = false;
	break;

  case 0x8:
	Mode = V & 0x013F;
	break;

  case 0xa:
	if(ClockDivider > 0 && ((V & 0x2000) != (Control & 0x2000)) && ((Control & 0x2) == (V & 0x2))  )
	 PSX_DBG(PSX_DBG_WARNING, "FIO device selection changed during comm %04x->%04x\n", Control, V);

	//printf("Control: %d, %04x\n", timestamp, V);
	Control = V & 0x3F2F;

	if(V & 0x10)
        {
	 istatus = false;
	 IRQ_Assert(IRQ_SIO, false);
	}

	if(V & 0x40)	// Reset
	{
	 istatus = false;
	 IRQ_Assert(IRQ_SIO, false);

	 ClockDivider = 0;
	 ReceivePending = false;
	 TransmitPending = false;

	 ReceiveInProgress = false;
	 TransmitInProgress = false;

	 ReceiveBufferAvail = false;

	 TransmitBuffer = 0;
	 ReceiveBuffer = 0;

	 ReceiveBitCounter = 0;
	 TransmitBitCounter = 0;

	 Mode = 0;
	 Control = 0;
	 Baudrate = 0;
	}

	Ports[0]->SetDTR((Control & 0x2) && !(Control & 0x2000));
        MCPorts[0]->SetDTR((Control & 0x2) && !(Control & 0x2000));
	Ports[1]->SetDTR((Control & 0x2) && (Control & 0x2000));
        MCPorts[1]->SetDTR((Control & 0x2) && (Control & 0x2000));

#if 1
if(!((Control & 0x2) && !(Control & 0x2000)))
{
 dsr_pulse_delay[0] = 0;
 dsr_pulse_delay[2] = 0;
 dsr_active_until_ts[0] = -1;
 dsr_active_until_ts[2] = -1;
}

if(!((Control & 0x2) && (Control & 0x2000)))
{
 dsr_pulse_delay[1] = 0;
 dsr_pulse_delay[3] = 0;
 dsr_active_until_ts[1] = -1;
 dsr_active_until_ts[3] = -1;
}

#endif
	// TODO: Uncomment out in the future once our CPU emulation is a bit more accurate with timing, to prevent causing problems with games
	// that may clear the IRQ in an unsafe pattern that only works because its execution was slow enough to allow DSR to go inactive.  (Whether or not
	// such games even exist though is unknown!)
	//if(timestamp < dsr_active_until_ts[0] || timestamp < dsr_active_until_ts[1] || timestamp < dsr_active_until_ts[2] || timestamp < dsr_active_until_ts[3])
	// DoDSRIRQ();

	break;

  case 0xe:
	Baudrate = V;
	//printf("%02x\n", V);
	//MDFN_DispMessage("%02x\n", V);
	break;
 }

 CheckStartStopPending(timestamp, false);
}


uint32 FrontIO::Read(pscpu_timestamp_t timestamp, uint32 A)
{
 uint32 ret = 0;

 Update(timestamp);

 switch(A & 0xE)
 {
  case 0x0:
  case 0x2:
	//printf("FIO Read: 0x%02x\n", ReceiveBuffer);
	ret = ReceiveBuffer | (ReceiveBuffer << 8) | (ReceiveBuffer << 16) | (ReceiveBuffer << 24);
	ReceiveBufferAvail = false;
	ReceivePending = true;
	ReceiveInProgress = false;
	CheckStartStopPending(timestamp, false);
	ret >>= (A & 2) * 8;
	break;

  case 0x4:
	ret = 0;

	if(!TransmitPending && !TransmitInProgress)
	 ret |= 0x1;

	if(ReceiveBufferAvail)
	 ret |= 0x2;

	if(timestamp < dsr_active_until_ts[0] || timestamp < dsr_active_until_ts[1] || timestamp < dsr_active_until_ts[2] || timestamp < dsr_active_until_ts[3])
	 ret |= 0x80;

	if(istatus)
	 ret |= 0x200;

	break;

  case 0x8:
	ret = Mode;
	break;

  case 0xa:
	ret = Control;
	break;

  case 0xe:
	ret = Baudrate;
	break;
 }

 ret >>= (A & 1) * 8;

 if((A & 0xF) != 0x4)
  PSX_FIODBGINFO("[FIO] Read: %08x %08x", A, ret);

 return(ret);
}

pscpu_timestamp_t FrontIO::Update(pscpu_timestamp_t timestamp)
{
 int32 clocks = timestamp - lastts;
 bool need_start_stop_check = false;

 for(int i = 0; i < 4; i++)
  if(dsr_pulse_delay[i] > 0)
  {
   dsr_pulse_delay[i] -= clocks;
   if(dsr_pulse_delay[i] <= 0)
   {
    dsr_active_until_ts[i] = timestamp + 32 + dsr_pulse_delay[i];
    DoDSRIRQ();
   }
  }

 for(int i = 0; i < 2; i++)
 {
  if(timestamp >= irq10_pulse_ts[i])
  {
   //printf("Yay: %d %u\n", i, timestamp);
   irq10_pulse_ts[i] = PSX_EVENT_MAXTS;
   IRQ_Assert(IRQ_PIO, true);
   IRQ_Assert(IRQ_PIO, false);
  }
 }

 if(ClockDivider > 0)
 {
  ClockDivider -= clocks;

  while(ClockDivider <= 0)
  {
   if(ReceiveInProgress || TransmitInProgress)
   {
    bool rxd = 0, txd = 0;
    const uint32 BCMask = 0x07;

    if(TransmitInProgress)
    {
     txd = (TransmitBuffer >> TransmitBitCounter) & 1;
     TransmitBitCounter = (TransmitBitCounter + 1) & BCMask;
     if(!TransmitBitCounter)
     {
      need_start_stop_check = true;
      PSX_FIODBGINFO("[FIO] Data transmitted: %08x", TransmitBuffer);
      TransmitInProgress = false;

      if(Control & 0x400)
      {
       istatus = true;
       IRQ_Assert(IRQ_SIO, true);
      }
     }
    }

    rxd = Ports[0]->Clock(txd, dsr_pulse_delay[0]) & Ports[1]->Clock(txd, dsr_pulse_delay[1]) &
	  MCPorts[0]->Clock(txd, dsr_pulse_delay[2]) & MCPorts[1]->Clock(txd, dsr_pulse_delay[3]);

    if(ReceiveInProgress)
    {
     ReceiveBuffer &= ~(1 << ReceiveBitCounter);
     ReceiveBuffer |= rxd << ReceiveBitCounter;

     ReceiveBitCounter = (ReceiveBitCounter + 1) & BCMask;

     if(!ReceiveBitCounter)
     {
      need_start_stop_check = true;
      PSX_FIODBGINFO("[FIO] Data received: %08x", ReceiveBuffer);

      ReceiveInProgress = false;
      ReceiveBufferAvail = true;

      if(Control & 0x800)
      {
       istatus = true;
       IRQ_Assert(IRQ_SIO, true);
      }
     }
    }
    ClockDivider += std::max<uint32>(0x20, (Baudrate << ScaleShift[Mode & 0x3]) & ~1); // Minimum of 0x20 is an emulation sanity check to prevent severe performance degradation.
   }
   else
    break;
  }
 }


 lastts = timestamp;


 if(need_start_stop_check)
 {
  CheckStartStopPending(timestamp, true);
 }

 return(CalcNextEventTS(timestamp, 0x10000000));
}

void FrontIO::ResetTS(void)
{
 for(unsigned i = 0; i < 2; i++)
 {
  Ports[i]->Update(lastts);	// Maybe eventually call Update() from FrontIO::Update() and remove this(but would hurt speed)?
  Ports[i]->ResetTS();

  MCPorts[i]->Update(lastts);	// Maybe eventually call Update() from FrontIO::Update() and remove this(but would hurt speed)?
  MCPorts[i]->ResetTS();
 }

 for(int i = 0; i < 2; i++)
 {
  if(irq10_pulse_ts[i] != PSX_EVENT_MAXTS)
   irq10_pulse_ts[i] -= lastts;
 }

 for(int i = 0; i < 4; i++)
 {
  if(dsr_active_until_ts[i] >= 0)
  {
   dsr_active_until_ts[i] -= lastts;
   //printf("SPOOONY: %d %d\n", i, dsr_active_until_ts[i]);
  }
 }
 lastts = 0;
}


void FrontIO::Reset(bool powering_up)
{
 for(int i = 0; i < 4; i++)
 {
  dsr_pulse_delay[i] = 0;
  dsr_active_until_ts[i] = -1;
 }

 for(int i = 0; i < 2; i++)
 {
  irq10_pulse_ts[i] = PSX_EVENT_MAXTS;
 }

 lastts = 0;

 //
 //

 ClockDivider = 0;

 ReceivePending = false;
 TransmitPending = false;

 ReceiveInProgress = false;
 TransmitInProgress = false;

 ReceiveBufferAvail = false;

 TransmitBuffer = 0;
 ReceiveBuffer = 0;

 ReceiveBitCounter = 0;
 TransmitBitCounter = 0;

 Mode = 0;
 Control = 0;
 Baudrate = 0;

 if(powering_up)
 {
  for(unsigned i = 0; i < 2; i++)
  {
   Ports[i]->Power();
   MCPorts[i]->Power();
  }
 }

 istatus = false;
}

void FrontIO::UpdateInput(void)
{
 for(unsigned i = 0; i < 8; i++)
  Devices[i]->UpdateInput(DeviceData[i]);
}

// Take care to call ->Power() only if the device actually changed.
void FrontIO::SetInput(unsigned int port, const char *type, uint8 *ptr)
{
 InputDevice* nd = PossibleNone.get();

 if(!strcmp(type, "gamepad") || !strcmp(type, "dancepad"))
  nd = PossibleDevices[port].Gamepad.get();
 else if(!strcmp(type, "dualanalog"))
  nd = PossibleDevices[port].DualAnalog.get();
 else if(!strcmp(type, "analogjoy"))
  nd = PossibleDevices[port].AnalogJoy.get();
 else if(!strcmp(type, "dualshock"))
  nd = PossibleDevices[port].DualShock.get();
 else if(!strcmp(type, "mouse"))
  nd = PossibleDevices[port].Mouse.get();
 else if(!strcmp(type, "negcon"))
  nd = PossibleDevices[port].neGcon.get();
 else if(!strcmp(type, "guncon"))
  nd = PossibleDevices[port].GunCon.get();
 else if(!strcmp(type, "justifier"))
  nd = PossibleDevices[port].Justifier.get();
 else if(strcmp(type, "none"))
  abort();

 if(Devices[port] != nd)
 {
  if(port < 2)
   irq10_pulse_ts[port] = PSX_EVENT_MAXTS;

  Devices[port] = nd;
// ResetTS?
  Devices[port]->Power();
  Devices[port]->SetAMCT(amct_enabled);
  Devices[port]->SetCrosshairsColor(chair_colors[port]);
  DeviceData[port] = ptr;

  MapDevicesToPorts();
 }
}

// Take care to call ->Power() only if the device actually changed.
void FrontIO::SetMemcard(unsigned int port, bool enabled)
{
 assert(port < 8);
 InputDevice* nd = enabled ? PossibleDevices[port].Memcard.get() : PossibleNone.get();

 if(MCDevices[port] != nd)
 {
  MCDevices[port] = nd;
  MCDevices[port]->Power();
  MapDevicesToPorts();
 }
}

//
// The memcard functions here should access PossibleDevices[which].Memcard, and NOT MCDevices, so that dynamically disabling/enabling
// memory cards will work properly and not cause data loss(when we add the feature in the future).
//
uint64 FrontIO::GetMemcardDirtyCount(unsigned int which)
{
 assert(which < 8);

 return(PossibleDevices[which].Memcard->GetNVDirtyCount());
}

void FrontIO::LoadMemcard(unsigned int which, const std::string& path)
{
 assert(which < 8);

 try
 {
  if(PossibleDevices[which].Memcard->GetNVSize())
  {
   FileStream mf(path, FileStream::MODE_READ);
   std::vector<uint8> tmpbuf;

   tmpbuf.resize(PossibleDevices[which].Memcard->GetNVSize());

   if(mf.size() != tmpbuf.size())
    throw(MDFN_Error(0, _("Memory card file \"%s\" is an incorrect size(%d bytes).  The correct size is %d bytes."), path.c_str(), (int)mf.size(), (int)tmpbuf.size()));

   mf.read(&tmpbuf[0], tmpbuf.size());

   PossibleDevices[which].Memcard->WriteNV(&tmpbuf[0], 0, tmpbuf.size());
   PossibleDevices[which].Memcard->ResetNVDirtyCount();		// There's no need to rewrite the file if it's the same data.
  }
 }
 catch(MDFN_Error &e)
 {
  if(e.GetErrno() != ENOENT)
   throw(e);
 }
}

void FrontIO::SaveMemcard(unsigned int which, const std::string& path)
{
 assert(which < 8);

 if(PossibleDevices[which].Memcard->GetNVSize() && PossibleDevices[which].Memcard->GetNVDirtyCount())
 {
  FileStream mf(path, FileStream::MODE_WRITE_INPLACE);

  mf.write(PossibleDevices[which].Memcard->ReadNV(), PossibleDevices[which].Memcard->GetNVSize());
  mf.close();	// Call before resetting the NV dirty count!

  PossibleDevices[which].Memcard->ResetNVDirtyCount();
 }
}

void FrontIO::StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(ClockDivider),

  SFVAR(ReceivePending),
  SFVAR(TransmitPending),

  SFVAR(ReceiveInProgress),
  SFVAR(TransmitInProgress),

  SFVAR(ReceiveBufferAvail),

  SFVAR(ReceiveBuffer),
  SFVAR(TransmitBuffer),

  SFVAR(ReceiveBitCounter),
  SFVAR(TransmitBitCounter),

  SFVAR(Mode),
  SFVAR(Control),
  SFVAR(Baudrate),

  SFVAR(istatus),

  // FIXME: Step mode save states.
  SFARRAY32(irq10_pulse_ts, sizeof(irq10_pulse_ts) / sizeof(irq10_pulse_ts[0])),
  SFARRAY32(dsr_pulse_delay, sizeof(dsr_pulse_delay) / sizeof(dsr_pulse_delay[0])),
  SFARRAY32(dsr_active_until_ts, sizeof(dsr_active_until_ts) / sizeof(dsr_active_until_ts[0])),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "FIO");

 for(unsigned i = 0; i < 2; i++)
 {
  char tmpbuf[32];

  trio_snprintf(tmpbuf, sizeof(tmpbuf), "FIOP%u", i);
  Ports[i]->StateAction(sm, load, data_only, tmpbuf);
 }

 for(unsigned i = 0; i < 2; i++)
 {
  char tmpbuf[32];

  trio_snprintf(tmpbuf, sizeof(tmpbuf), "FIOMC%u", i);
  MCPorts[i]->StateAction(sm, load, data_only, tmpbuf);
 }

 if(load)
 {
  IRQ_Assert(IRQ_SIO, istatus);
 }
}

bool FrontIO::RequireNoFrameskip(void)
{
 bool ret = false;

 for(unsigned i = 0; i < 2; i++)
 {
  ret |= Ports[i]->RequireNoFrameskip();
 }
 
 return(ret);
}

void FrontIO::GPULineHook(const pscpu_timestamp_t timestamp, const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider)
{
 Update(timestamp);

 for(unsigned i = 0; i < 2; i++)
 {
  pscpu_timestamp_t plts = Ports[i]->GPULineHook(line_timestamp, vsync, pixels, format, width, pix_clock_offset, pix_clock, pix_clock_divider);

  irq10_pulse_ts[i] = plts;

  if(irq10_pulse_ts[i] <= timestamp)
  {
   irq10_pulse_ts[i] = PSX_EVENT_MAXTS;
   IRQ_Assert(IRQ_PIO, true);
   IRQ_Assert(IRQ_PIO, false);
  }
 }

 //
 // Draw crosshairs in a separate pass so the crosshairs won't mess up the color evaluation of later lightun GPULineHook()s.
 //
 if(pixels && pix_clock)
 {
  for(unsigned i = 0; i < 2; i++)
  {
   Ports[i]->DrawCrosshairs(pixels, format, width, pix_clock);
  }
 }

 PSX_SetEventNT(PSX_EVENT_FIO, CalcNextEventTS(timestamp, 0x10000000));
}

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoPSXPort =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 // Gamepad(SCPH-1080)
 {
  "gamepad",
  "Digital Gamepad",
  "PlayStation digital gamepad; SCPH-1080.",
  Device_Gamepad_IDII,
 },

 // Dual Shock Gamepad(SCPH-1200)
 {
  "dualshock",
  "DualShock",
  "DualShock gamepad; SCPH-1200.  Emulation in Mednafen includes the analog mode toggle button.  Rumble is emulated, but currently only supported on Linux, and MS Windows via the XInput API and XInput-compatible gamepads/joysticks.  If you're having trouble getting rumble to work on Linux, see if Mednafen is printing out error messages during startup regarding /dev/input/event*, and resolve the issue(s) as necessary.",
  Device_DualShock_IDII,
 },

 // Dual Analog Gamepad(SCPH-1180), forced to analog mode.
 {
  "dualanalog",
  "Dual Analog",
  "Dual Analog gamepad; SCPH-1180.  It is the predecessor/prototype to the more advanced DualShock.  Emulated in Mednafen as forced to analog mode, and without rumble.",
  Device_DualAnalog_IDII,
 },


 // Analog joystick(SCPH-1110), forced to analog mode - emulated through a tweak to dual analog gamepad emulation.
 {
  "analogjoy",
  "Analog Joystick",
  "Flight-game-oriented dual-joystick controller; SCPH-1110.   Emulated in Mednafen as forced to analog mode.",
  Device_AnalogJoy_IDII,
 },

 {
  "mouse",
  "Mouse",
  NULL,
  Device_Mouse_IDII,
 },

 {
  "negcon",
  "neGcon",
  "Namco's unconventional twisty racing-game-oriented gamepad; NPC-101.",
  Device_neGcon_IDII,
 },

 {
  "guncon",
  "GunCon",
  "Namco's light gun; NPC-103.",
  Device_GunCon_IDII,
 },

 {
  "justifier",
  "Konami Justifier",
  "Konami's light gun; SLUH-00017.  Rumored to be wrought of the coagulated rage of all who tried to shoot The Dog.  If the game you want to play supports the \"GunCon\", you should use that instead. NOTE: Currently does not work properly when on any of ports 1B-1D and 2B-2D.",
  Device_Justifier_IDII,
 },

 {
  "dancepad",
  "Dance Pad",
  "Dingo Dingo Rodeo!",
  Device_Dancepad_IDII,
 },

};

const std::vector<InputPortInfoStruct> FIO_PortInfo =
{
 { "port1", "Virtual Port 1", InputDeviceInfoPSXPort, "gamepad" },
 { "port2", "Virtual Port 2", InputDeviceInfoPSXPort, "gamepad" },
 { "port3", "Virtual Port 3", InputDeviceInfoPSXPort, "gamepad" },
 { "port4", "Virtual Port 4", InputDeviceInfoPSXPort, "gamepad" },
 { "port5", "Virtual Port 5", InputDeviceInfoPSXPort, "gamepad" },
 { "port6", "Virtual Port 6", InputDeviceInfoPSXPort, "gamepad" },
 { "port7", "Virtual Port 7", InputDeviceInfoPSXPort, "gamepad" },
 { "port8", "Virtual Port 8", InputDeviceInfoPSXPort, "gamepad" },
};

}
