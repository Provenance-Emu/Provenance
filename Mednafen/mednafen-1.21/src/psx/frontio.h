/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* frontio.h:
**  Copyright (C) 2011-2017 Mednafen Team
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

#ifndef __MDFN_PSX_FRONTIO_H
#define __MDFN_PSX_FRONTIO_H

namespace MDFN_IEN_PSX
{

class InputDevice_Multitap;

class InputDevice
{
 public:

 InputDevice() MDFN_COLD;
 virtual ~InputDevice() MDFN_COLD;

 virtual void Power(void) MDFN_COLD;
 virtual void UpdateInput(const void *data);
 virtual void UpdateOutput(void* data);
 virtual void TransformInput(void* data);
 virtual void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix);

 virtual bool RequireNoFrameskip(void);

 // Divide mouse X coordinate by pix_clock_divider in the lightgun code to get the coordinate in pixel(clocks).
 virtual pscpu_timestamp_t GPULineHook(const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider);

 virtual void Update(const pscpu_timestamp_t timestamp);	// Partially-implemented, don't rely on for timing any more fine-grained than a video frame for now.
 virtual void ResetTS(void);

 virtual void DrawCrosshairs(uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock); // Virtual for multitap chaining.
 //
 //
 //
 virtual void SetAMCT(bool enabled, uint16 compare);
 virtual void SetCrosshairsColor(uint32 color);

 //
 //
 //
 virtual void SetDTR(bool new_dtr);
 virtual bool GetDSR(void);	// Currently unused.

 virtual bool Clock(bool TxD, int32 &dsr_pulse_delay);

 //
 //
 virtual uint32 GetNVSize(void) const;
 virtual const uint8* ReadNV(void) const;	// Pointer returned should be considered temporary and assumed invalidated upon further calls to non-const functions on the object.
 virtual void WriteNV(const uint8 *buffer, uint32 offset, uint32 count);

 //
 // Dirty count should be incremented on each call to a method this class that causes at least 1 write to occur to the
 // nonvolatile memory(IE Clock() in the correct command phase, and WriteNV()).
 //
 virtual uint64 GetNVDirtyCount(void) const;
 virtual void ResetNVDirtyCount(void);

 private:
 unsigned chair_r, chair_g, chair_b;
 bool draw_chair;
 protected:
 int32 chair_x, chair_y;
};

class FrontIO
{
 public:

 FrontIO() MDFN_COLD;
 ~FrontIO() MDFN_COLD;

 void Reset(bool powering_up) MDFN_COLD;
 void Write(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 uint32 Read(pscpu_timestamp_t timestamp, uint32 A);
 pscpu_timestamp_t CalcNextEventTS(pscpu_timestamp_t timestamp, int32 next_event);
 pscpu_timestamp_t Update(pscpu_timestamp_t timestamp);
 void ResetTS(void);

 bool RequireNoFrameskip(void);
 void GPULineHook(const pscpu_timestamp_t timestamp, const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider);

 void UpdateInput(void);
 void TransformInput(void);
 void UpdateOutput(void);
 void SetInput(unsigned int port, const char *type, uint8 *ptr);
 void SetMultitap(unsigned int pport, bool enabled);
 void SetMemcard(unsigned int port, bool enabled);
 void SetAMCT(bool enabled, uint16 compare);
 void SetCrosshairsColor(unsigned port, uint32 color);

 uint64 GetMemcardDirtyCount(unsigned int which);
 void LoadMemcard(unsigned int which, const std::string& path);
 void SaveMemcard(unsigned int which, const std::string& path); //, bool force_save = false);

 void StateAction(StateMem* sm, const unsigned load, const bool data_only);

 private:

 void DoDSRIRQ(void);
 void CheckStartStopPending(pscpu_timestamp_t timestamp, bool skip_event_set = false);

 void MapDevicesToPorts(void);

 bool emulate_multitap[2] = { false, false };

 //
 // Configurable pointers to the various pre-allocated devices, and associated configuration data.
 //

 // Physical ports
 InputDevice *Ports[2];
 InputDevice *MCPorts[2];

 // Mednafen virtual ports
 InputDevice *Devices[8];
 void *DeviceData[8];
 InputDevice *MCDevices[8];

 //
 // Actual pre-allocated devices below:
 //
 std::unique_ptr<InputDevice> PossibleNone;
 std::unique_ptr<InputDevice_Multitap> PossibleMultitaps[2];

 struct
 {
  std::unique_ptr<InputDevice> Memcard;
  std::unique_ptr<InputDevice> Gamepad;
  std::unique_ptr<InputDevice> DualAnalog;
  std::unique_ptr<InputDevice> AnalogJoy;
  std::unique_ptr<InputDevice> DualShock;
  std::unique_ptr<InputDevice> Mouse;
  std::unique_ptr<InputDevice> neGcon;
  std::unique_ptr<InputDevice> GunCon;
  std::unique_ptr<InputDevice> Justifier;
 } PossibleDevices[8];

 //
 //
 //

 int32 ClockDivider;

 bool ReceivePending;
 bool TransmitPending;

 bool ReceiveInProgress;
 bool TransmitInProgress;

 bool ReceiveBufferAvail;

 uint8 ReceiveBuffer;
 uint8 TransmitBuffer;

 int32 ReceiveBitCounter;
 int32 TransmitBitCounter;

 uint16 Mode;
 uint16 Control;
 uint16 Baudrate;


 bool istatus;
 //
 //
 pscpu_timestamp_t irq10_pulse_ts[2];

 int32 dsr_pulse_delay[4];
 int32 dsr_active_until_ts[4];
 int32 lastts;
 //
 //
 bool amct_enabled;
 uint16 amct_compare;
 uint32 chair_colors[8];
};

extern const std::vector<InputPortInfoStruct> FIO_PortInfo;

}
#endif
