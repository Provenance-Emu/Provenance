/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <math.h>
#include <unistd.h>

#include "SDL.h"
#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"
#include "CPUWindow.h"

#include "HardIOWindow.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

static int HardIOWindow_InConfigs = 0;

GtkWindow *HardIOWindow;
static int HardIOWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkLabel *LabelRunFull;
static GtkScrolledWindow *HardIOSW;
static GtkBox *VBox2;
static GtkComboBox *ComboReg;
static GtkToggleButton *CheckRegData[8];
static GtkToggleButton *CheckAutoWrite;
static GtkButton *ButtonWrite;

// Locals
static uint8_t SelRegAddr = 0x00;

// Registers information table
// Bit type:
//  0 = Unused
//  1 = Read-Only
//  2 = Write-Only
//  3 = Read/Write
static const THardIOWindow_RegInfo HardIORegInfo[] = {
	{0x00, "SYS_CTRL1",{
		{3, "Start-up contrast (6-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "Cartridge IO power"},
		{3, "LCD IO power"},
	},"System Control 1"},
	{0x01, "SYS_CTRL2",{
		{3, "Ram vector (BIOS)"},
		{3, "Int abort (BIOS)"},
		{3, "Enable cart interrupts (BIOS)"},
		{3, "Power on reset (BIOS)"},
		{3, "Cart type (BIOS, 4-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	},"System Control 2"},
	{0x02, "SYS_CTRL3",{
		{3, "Cart power state (BIOS)"},
		{3, "Cart power required (BIOS)"},
		{3, "Suspend mode (BIOS)"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "RTC Time valid (BIOS)"},
		{3, "???"},
	},"System Control 3"},
	{0x08, "SEC_CTRL",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{2, "Reset"},
		{3, "Enable"},
	},"Second Counter Control"},
	{0x09, "SEC_CNT_LO",{
		{1, "Counter (Low 8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	},"Second Counter Low"},
	{0x0A, "SEC_CNT_MID",{
		{1, "Counter (Med. 8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	},"Second Counter Middle"},
	{0x0B, "SEC_CNT_HI",{
		{1, "Counter (High 8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	},"Second Counter High"},
	{0x10, "SYS_BATT",{
		{0, "Unused"},
		{0, "Unused"},
		{1, "Low Battery"},
		{3, "Battery ADC control"},
		{3, "Battery ADC threshold value (4-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	},"Battery Sensor"},
	{0x18, "TMR1_SCALE",{
		{3, "Enable Hi"},
		{3, "Hi Scalar (3-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "Enable Lo"},
		{3, "Lo Scalar (3-Bits)"},
		{3, "..."},
		{3, "..."},
	},"Timer 1 Prescalars"},
	{0x19, "TMR1_ENA_OSC",{
		{0, ""},
		{0, ""},
		{3, "Enable Osc. 1"},
		{3, "Enable Osc. 2"},
		{0, ""},
		{0, ""},
		{3, "2nd Osc. (Hi)"},
		{3, "2nd Osc. (Lo)"},
	},"Timers Osc. Enable, Timer 1 Osc. Select"},
	{0x1A, "TMR2_SCALE",{
		{3, "Enable Hi"},
		{3, "Hi Scalar (3-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "Enable Lo"},
		{3, "Lo Scalar (3-Bits)"},
		{3, "..."},
		{3, "..."},
	},"Timer 2 Prescalars"},
	{0x1B, "TMR2_OSC",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "2nd Osc. (Hi)"},
		{3, "2nd Osc. (Lo)"},
	},"Timer 2 Osc. Select"},
	{0x1C, "TMR3_SCALE",{
		{3, "Enable Hi"},
		{3, "Hi Scalar (3-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "Enable Lo"},
		{3, "Lo Scalar (3-Bits)"},
		{3, "..."},
		{3, "..."},
	},"Timer 3 Prescalars"},
	{0x1D, "TMR3_OSC",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "2nd Osc. (Hi)"},
		{3, "2nd Osc. (Lo)"},
	}, "Timer 3 Osc. Select"},
	{0x20, "IRQ_PRI1",{
		{3, "PRC IRQs ($03~$04)"},
		{3, "..."},
		{3, "Timer 2 IRQs ($05~$06)"},
		{3, "..."},
		{3, "Timer 1 IRQs ($07~$08)"},
		{3, "..."},
		{3, "Timer 3 IRQs ($09~$0A)"},
		{3, "..."},
	}, "IRQ Priority 1"},
	{0x21, "IRQ_PRI2",{
		{3, "256 Hz IRQs ($0B~$0E)"},
		{3, "..."},
		{3, "IR/Shock IRQs ($13~$14)"},
		{3, "..."},
		{3, "Keypad IRQs ($15~$1C)"},
		{3, "..."},
		{3, "Unknown IRQs ($1D~$1F)"},
		{3, "..."},
	}, "IRQ Priority 2"},
	{0x22, "IRQ_PRI3",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "Cartridge IRQs ($0F~$10)"},
		{3, "..."},
	}, "IRQ Priority 3"},
	{0x23, "IRQ_ENA1",{
		{3, "PRC Copy Complete ($03)"},
		{3, "PRC Frame Divider Overflow ($04)"},
		{3, "Timer 2-B Underflow ($05)"},
		{3, "Timer 2-A Underflow 8-Bits ($06)"},
		{3, "Timer 1-B Underflow ($07)"},
		{3, "Timer 1-A Underflow 8-Bits ($08)"},
		{3, "Timer 3 Underflow ($09)"},
		{3, "Timer 3 Pivot ($0A)"},
	}, "IRQ Enable 1"},
	{0x24, "IRQ_ENA2",{
		{0, ""},
		{0, ""},
		{3, "32 Hz ($05)"},
		{3, " 8 Hz ($06)"},
		{3, " 2 Hz ($07)"},
		{3, " 1 Hz ($08)"},
		{3, "IR Receiver ($13)"},
		{3, "Shock Sensor ($14)"},
	}, "IRQ Enable 2"},
	{0x25, "IRQ_ENA3",{
		{3, "Power Key ($15)"},
		{3, "Right Key ($16)"},
		{3, "Left Key ($17)"},
		{3, "Down Key ($18)"},
		{3, "Up Key ($19)"},
		{3, "C Key ($1A)"},
		{3, "B Key ($1B)"},
		{3, "A Key ($1C)"},
	}, "IRQ Enable 3"},
	{0x26, "IRQ_ENA4",{
		{3, "Cartridge Ejected ($0F)"},
		{3, "Cartridge IRQ ($10)"},
		{3, "???"},
		{3, "???"},
		{0, ""},
		{3, "Unknown 1 ($1D)"},
		{3, "Unknown 2 ($1E)"},
		{3, "Unknown 3 ($1F)"},
	}, "IRQ Enable 4"},
	{0x27, "IRQ_ACT1",{
		{2, "PRC Copy Complete ($03)"},
		{2, "PRC Frame Divider Overflow ($04)"},
		{2, "Timer 2-B Underflow ($05)"},
		{2, "Timer 2-A Underflow 8-Bits ($06)"},
		{2, "Timer 1-B Underflow ($07)"},
		{2, "Timer 1-A Underflow 8-Bits ($08)"},
		{2, "Timer 3 Underflow ($09)"},
		{2, "Timer 3 Pivot ($0A)"},
	}, "IRQ Active 1"},
	{0x28, "IRQ_ACT2",{
		{0, ""},
		{0, ""},
		{2, "32 Hz ($05)"},
		{2, " 8 Hz ($06)"},
		{2, " 2 Hz ($07)"},
		{2, " 1 Hz ($08)"},
		{2, "IR Receiver ($13)"},
		{2, "Shock Sensor ($14)"},
	}, "IRQ Active 2"},
	{0x29, "IRQ_ACT3",{
		{2, "Power Key ($15)"},
		{2, "Right Key ($16)"},
		{2, "Left Key ($17)"},
		{2, "Down Key ($18)"},
		{2, "Up Key ($19)"},
		{2, "C Key ($1A)"},
		{2, "B Key ($1B)"},
		{2, "A Key ($1C)"},
	}, "IRQ Active 3"},
	{0x2A, "IRQ_ACT4",{
		{2, "Cartridge Ejected ($0F)"},
		{2, "Cartridge IRQ ($10)"},
		{2, "???"},
		{2, "???"},
		{0, ""},
		{2, "Unknown 1 ($1D)"},
		{2, "Unknown 2 ($1E)"},
		{2, "Unknown 3 ($1F)"},
	}, "IRQ Active 4"},
	{0x30, "TMR1_CTRL_L",{
		{3, "16-Bits Mode"},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "Enable"},
		{3, "Reset"},
		{3, "???"},
	}, "Timer 1 Control (Lo)"},
	{0x31, "TMR1_CTRL_H",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "Enable"},
		{3, "Reset"},
		{3, "???"},
	}, "Timer 1 Control (Hi)"},
	{0x32, "TMR1_PRE_L",{
		{3, "Preset (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 1 Preset (Lo)"},
	{0x33, "TMR1_PRE_H",{
		{3, "Preset (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 1 Preset (Hi)"},
	{0x34, "TMR1_PVT_L",{
		{3, "Pivot (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 1 Pivot (Lo)"},
	{0x35, "TMR1_PVT_H",{
		{3, "Pivot (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 1 Pivot (Hi)"},
	{0x36, "TMR1_CNT_L",{
		{1, "Count (8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	}, "Timer 1 Count (Lo)"},
	{0x37, "TMR1_CNT_H",{
		{1, "Count (8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	}, "Timer 1 Count (Hi)"},
	{0x38, "TMR2_CTRL_L",{
		{3, "16-Bits Mode"},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "Enable"},
		{3, "Reset"},
		{3, "???"},
	}, "Timer 2 Control (Lo)"},
	{0x39, "TMR2_CTRL_H",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "Enable"},
		{3, "Reset"},
		{3, "???"},
	}, "Timer 2 Control (Hi)"},
	{0x3A, "TMR2_PRE_L",{
		{3, "Preset (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 2 Preset (Lo)"},
	{0x3B, "TMR2_PRE_H",{
		{3, "Preset (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 2 Preset (Hi)"},
	{0x3C, "TMR2_PVT_L",{
		{3, "Pivot (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 2 Pivot (Lo)"},
	{0x3D, "TMR2_PVT_H",{
		{3, "Pivot (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 2 Pivot (Hi)"},
	{0x3E, "TMR2_CNT_L",{
		{1, "Count (8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	}, "Timer 2 Count (Lo)"},
	{0x3F, "TMR2_CNT_H",{
		{1, "Count (8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	}, "Timer 2 Count (Hi)"},
	{0x40, "TMR256_CTRL",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{2, "Reset"},
		{3, "Enable"},
	}, "256Hz Timer Control"},
	{0x41, "TMR256_CNT",{
		{1, "Count (8-Bits)"},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
	}, "256Hz Timer Count"},
	{0x44, "UNKNOWN",{
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x45, "UNKNOWN",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x46, "UNKNOWN",{
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x47, "UNKNOWN",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x48, "TMR3_CTRL_L",{
		{3, "16-Bits Mode"},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "Enable"},
		{3, "Reset"},
		{3, "???"},
	}, "Timer 3 Control (Lo)"},
	{0x49, "TMR3_CTRL_H",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "Enable"},
		{3, "Reset"},
		{3, "???"},
	}, "Timer 3 Control (Hi)"},
	{0x4A, "TMR3_PRE_L",{
		{3, "Preset (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 3 Preset (Lo)"},
	{0x4B, "TMR3_PRE_H",{
		{3, "Preset (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 3 Preset (Hi)"},
	{0x4C, "TMR3_PVT_L",{
		{3, "Pivot (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 3 Pivot (Lo)"},
	{0x4D, "TMR3_PVT_H",{
		{3, "Pivot (8-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
		{3, "..."},
	}, "Timer 3 Pivot (Hi)"},
	{0x4E, "TMR3_CNT_L",{
		{1, "Count (8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	}, "Timer 3 Count (Lo)"},
	{0x4F, "TMR3_CNT_H",{
		{1, "Count (8-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{1, "..."},
	}, "Timer 3 Count (Hi)"},
	{0x50, "UNKNOWN",{
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x51, "UNKNOWN",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x52, "KEY_PAD",{
		{1, "!Power Key"},
		{1, "!Right Key"},
		{1, "!Left Key"},
		{1, "!Down Key"},
		{1, "!Up Key"},
		{1, "!C Key"},
		{1, "!B Key"},
		{1, "!A Key"},
	}, "Key-Pad Status (Active 0)"},
	{0x53, "CART_BUS",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{1, "!Cartrige power"},
		{0, ""},
	}, "Cart Bus (Active 0)"},
	{0x54, "UNKNOWN",{
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x55, "UNKNOWN",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Unknown"},
	{0x60, "IO_DIR",{
		{3, "???"},
		{3, "???"},
		{3, "IR Disable"},
		{3, "Rumble"},
		{3, "EEPROM Clock"},
		{3, "EEPROM Data"},
		{3, "IR Receive"},
		{3, "IR Transmit"},
	}, "I/O Direction Select"},
	{0x61, "IO_DATA",{
		{3, "???"},
		{3, "???"},
		{3, "IR Disable"},
		{3, "Rumble"},
		{3, "EEPROM Clock"},
		{3, "EEPROM Data"},
		{3, "IR Receive"},
		{3, "IR Transmit"},
	}, "I/O Data Register"},
	{0x62, "UNKNOWN",{
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{3, "???"},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
	}, "Unknown"},
	{0x70, "AUD_CTRL",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "???"},
		{3, "???"},
		{3, "???"},
	}, "Audio Control"},
	{0x71, "AUD_VOL",{
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "!Cart power"},
		{3, "Volume (2-Bits)"},
		{3, "..."},
	}, "Audio Volume"},
	{0x80, "PRC_MODE",{
		{0, ""},
		{0, ""},
		{3, "Map Size (2-Bits)"},
		{3, "..."},
		{3, "Enable Copy"},
		{3, "Enable Sprites"},
		{3, "Enable Map"},
		{3, "Invert Map"},
	}, "PRC Stage Control"},
	{0x81, "PRC_RATE",{
		{1, "Frame counter (4-Bits)"},
		{1, "..."},
		{1, "..."},
		{1, "..."},
		{3, "Rate divider (3-Bits)"},
		{3, "..."},
		{3, "..."},
		{3, "???"},
	}, "PRC Rate Control"},
	{0x82, "PRC_MAP_LO",{
		{3, "Map Tile Base (5-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{0, ""},
		{0, ""},
		{0, ""},
	}, "PRC Map Tile Base Low"},
	{0x83, "PRC_MAP_MID",{
		{3, "Map Tile Base (8-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "PRC Map Tile Base Middle"},
	{0x84, "PRC_MAP_HI",{
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "Map Tile Base (5-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "PRC Map Tile Base High"},
	{0x85, "PRC_SCROLL_Y",{
		{0, ""},
		{3, "Map Scroll Y (7-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "PRC Map Vertical Scroll"},
	{0x86, "PRC_SCROLL_X",{
		{0, ""},
		{3, "Map Scroll X (7-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "PRC Map Horizontal Scroll"},
	{0x87, "PRC_SPR_LO",{
		{3, "Sprite Tile Base (2-Bits)"},
		{3, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
		{0, ""},
	}, "PRC Sprite Tile Base Low"},
	{0x88, "PRC_SPR_MID",{
		{3, "Sprite Tile Base (8-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "PRC Sprite Tile Base Middle"},
	{0x89, "PRC_SPR_HI",{
		{0, ""},
		{0, ""},
		{0, ""},
		{3, "Sprite Tile Base (5-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "PRC Sprite Tile Base High"},
	{0x8A, "PRC_CNT",{
		{0, ""},
		{1, "Count (7-Bits)"},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
		{1, ""},
	}, "PRC Counter"},
	{0xFE, "LCD_CTRL",{
		{3, "LCD Control I/O (8-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "LCD Raw Control Byte"},
	{0xFF, "LCD_DATA",{
		{3, "LCD Data I/O (8-Bits)"},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
		{3, ""},
	}, "LCD Raw Data Byte"},
};
static int HardIORegInfo_Len = sizeof(HardIORegInfo) / sizeof(*HardIORegInfo);

static void HardIOWindow_Render(int force)
{
	uint8_t din;

	HardIOWindow_InConfigs = 1;

	din = MinxCPU_OnRead(0, 0x2000 + SelRegAddr);
	gtk_toggle_button_set_active(CheckRegData[0], din & 0x80);
	gtk_toggle_button_set_active(CheckRegData[1], din & 0x40);
	gtk_toggle_button_set_active(CheckRegData[2], din & 0x20);
	gtk_toggle_button_set_active(CheckRegData[3], din & 0x10);
	gtk_toggle_button_set_active(CheckRegData[4], din & 0x08);
	gtk_toggle_button_set_active(CheckRegData[5], din & 0x04);
	gtk_toggle_button_set_active(CheckRegData[6], din & 0x02);
	gtk_toggle_button_set_active(CheckRegData[7], din & 0x01);

	HardIOWindow_InConfigs = 0;
}

static void ButtonWrite_clicked(GtkButton *button, gpointer data)
{
	MinxCPU_OnWrite(0, 0x2000 + SelRegAddr,
		(gtk_toggle_button_get_active(CheckRegData[0]) ? 0x80 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[1]) ? 0x40 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[2]) ? 0x20 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[3]) ? 0x10 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[4]) ? 0x08 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[5]) ? 0x04 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[6]) ? 0x02 : 0) +
		(gtk_toggle_button_get_active(CheckRegData[7]) ? 0x01 : 0)
	);
	refresh_debug(1);
}

static void ComboReg_changed(GtkComboBox *widget, gpointer data)
{
	char tmp[PMTMPV];
	int i, bit;
	THardIOWindow_RegInfo *reginfo = (THardIOWindow_RegInfo *)&HardIORegInfo[gtk_combo_box_get_active(ComboReg)];
	SelRegAddr = reginfo->regaddr;
	for (i=0; i<8; i++) {
		bit = 7 - i;
		switch (reginfo->bit[i].type) {
			case 0: sprintf(tmp, "%i", bit);
				gtk_widget_set_sensitive(GTK_WIDGET(CheckRegData[i]), FALSE);
				break;
			case 1: sprintf(tmp, "%i (R): %s", bit, reginfo->bit[i].name);
				gtk_widget_set_sensitive(GTK_WIDGET(CheckRegData[i]), TRUE);
				break;
			case 2: sprintf(tmp, "%i (W): %s", bit, reginfo->bit[i].name);
				gtk_widget_set_sensitive(GTK_WIDGET(CheckRegData[i]), TRUE);
				break;
			case 3: sprintf(tmp, "%i (RW): %s", bit, reginfo->bit[i].name);
				gtk_widget_set_sensitive(GTK_WIDGET(CheckRegData[i]), TRUE);
				break;
		}
		gtk_button_set_label(GTK_BUTTON(CheckRegData[i]), tmp);
	}
	refresh_debug(1);
}

static void CheckRegData_toggled(GtkToggleButton *widget, gpointer data)
{
	int mask = 1 << (int)data;
	uint8_t din;

	if (HardIOWindow_InConfigs) return;
	if (!gtk_toggle_button_get_active(CheckAutoWrite)) return;

	din = MinxCPU_OnRead(0, 0x2000 + SelRegAddr);
	if (gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(widget))) {
		MinxCPU_OnWrite(0, 0x2000 + SelRegAddr, din | mask);
	} else {
		MinxCPU_OnWrite(0, 0x2000 + SelRegAddr, din & ~mask);
	}
	refresh_debug(1);
}

// --------------
// Menu callbacks
// --------------

static void HardIOW_RefreshNow(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void HardIOW_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (HardIOWindow_InConfigs) return;

	if (index >= 0) {
		dclc_hardiowin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(HardIOWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_hardiowin_refresh, 4, 0, 0, 1000)) {
			dclc_hardiowin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static gint HardIOWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_widget_hide(GTK_WIDGET(HardIOWindow));
	return TRUE;
}

static gboolean HardIOWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) HardIOWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static GtkItemFactoryEntry HardIOWindow_MenuItems[] = {
	{ "/_Debugger",                          NULL,           NULL,                     0, "<Branch>" },
	{ "/Debugger/Run full speed",            "F5",           Menu_Debug_RunFull,       0, "<Item>" },
	{ "/Debugger/Run debug frames (Sound)",  "<SHIFT>F5",    Menu_Debug_RunDFrameSnd,  0, "<Item>" },
	{ "/Debugger/Run debug frames",          "<CTRL>F5",     Menu_Debug_RunDFrame,     0, "<Item>" },
	{ "/Debugger/Run debug steps",           "<CTRL>F3",     Menu_Debug_RunDStep,      0, "<Item>" },
	{ "/Debugger/Single frame",              "F4",           Menu_Debug_SingleFrame,   0, "<Item>" },
	{ "/Debugger/Single step",               "F3",           Menu_Debug_SingleStep,    0, "<Item>" },
	{ "/Debugger/Step skip",                 "<SHIFT>F3",    Menu_Debug_StepSkip,      0, "<Item>" },
	{ "/Debugger/Stop",                      "F2",           Menu_Debug_Stop,          0, "<Item>" },

	{ "/_Refresh",                           NULL,           NULL,                     0, "<Branch>" },
	{ "/Refresh/Now!",                       NULL,           HardIOW_RefreshNow,       0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                     0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           HardIOW_Refresh,          0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           HardIOW_Refresh,          1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           HardIOW_Refresh,          2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           HardIOW_Refresh,          3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           HardIOW_Refresh,          5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           HardIOW_Refresh,          7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           HardIOW_Refresh,         11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           HardIOW_Refresh,         35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           HardIOW_Refresh,         71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           HardIOW_Refresh,         -1, "/Refresh/100% 72fps" },
};
static gint HardIOWindow_MenuItemsNum = sizeof(HardIOWindow_MenuItems) / sizeof(*HardIOWindow_MenuItems);

// ------------------
// Hardware IO Window
// ------------------

int HardIOWindow_Create(void)
{
	char tmp[PMTMPV];
	int i;

	// Window
	HardIOWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(HardIOWindow), "Hardware IO View");
	gtk_widget_set_size_request(GTK_WIDGET(HardIOWindow), 200, 100);
	gtk_window_set_default_size(HardIOWindow, 420, 280);
	g_signal_connect(HardIOWindow, "delete_event", G_CALLBACK(HardIOWindow_delete_event), NULL);
	g_signal_connect(HardIOWindow, "window-state-event", G_CALLBACK(HardIOWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(HardIOWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, HardIOWindow_MenuItemsNum, HardIOWindow_MenuItems, NULL);
	gtk_window_add_accel_group(HardIOWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Label that warn when running full speed
	LabelRunFull = GTK_LABEL(gtk_label_new("To view content you must stop emulation or run in debug frames/steps."));
	gtk_box_pack_start(VBox1, GTK_WIDGET(LabelRunFull), FALSE, TRUE, 0);

	// Scrolling window with vertical box
	HardIOSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(HardIOSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_container_add(GTK_CONTAINER(VBox1), GTK_WIDGET(HardIOSW));
	gtk_widget_show(GTK_WIDGET(HardIOSW));
	VBox2 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_scrolled_window_add_with_viewport(HardIOSW, GTK_WIDGET(VBox2));
	gtk_widget_show(GTK_WIDGET(VBox2));

	// Registers
	ComboReg = GTK_COMBO_BOX(gtk_combo_box_new_text());
	g_signal_connect(ComboReg, "changed", G_CALLBACK(ComboReg_changed), NULL);
	for (i=0; i<HardIORegInfo_Len; i++) {
		sprintf(tmp, "$%02X - %s - %s", HardIORegInfo[i].regaddr, HardIORegInfo[i].idname, HardIORegInfo[i].description);
		gtk_combo_box_append_text(ComboReg, tmp);
	}
	gtk_box_pack_start(VBox2, GTK_WIDGET(ComboReg), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(ComboReg));
	for (i=0; i<8; i++) {
		CheckRegData[i] = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("???"));
		g_signal_connect(CheckRegData[i], "toggled", G_CALLBACK(CheckRegData_toggled), (gpointer)(7-i));
		gtk_toggle_button_set_mode(CheckRegData[i], TRUE);
		gtk_box_pack_start(VBox2, GTK_WIDGET(CheckRegData[i]), FALSE, TRUE, 0);
		gtk_widget_show(GTK_WIDGET(CheckRegData[i]));
	}

	// Auto write & button
	CheckAutoWrite = GTK_TOGGLE_BUTTON(gtk_check_button_new_with_label("Auto write on change"));
	gtk_toggle_button_set_mode(CheckAutoWrite, TRUE);
	gtk_toggle_button_set_active(CheckAutoWrite, 1);
	gtk_box_pack_start(VBox1, GTK_WIDGET(CheckAutoWrite), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(CheckAutoWrite));
	ButtonWrite = GTK_BUTTON(gtk_button_new_with_label("Write"));
	g_signal_connect(ButtonWrite, "clicked", G_CALLBACK(ButtonWrite_clicked), NULL);
	gtk_box_pack_start(VBox1, GTK_WIDGET(ButtonWrite), FALSE, FALSE, 0);
	gtk_widget_show(GTK_WIDGET(ButtonWrite));

	return 1;
}

void HardIOWindow_Destroy(void)
{
	int x, y, width, height;
	if (gtk_widget_get_realized(GTK_WIDGET(HardIOWindow))) {
		gtk_widget_show(GTK_WIDGET(HardIOWindow));
		gtk_window_deiconify(HardIOWindow);
		gtk_window_get_position(HardIOWindow, &x, &y);
		gtk_window_get_size(HardIOWindow, &width, &height);
		dclc_hardiowin_winx = x;
		dclc_hardiowin_winy = y;
		dclc_hardiowin_winw = width;
		dclc_hardiowin_winh = height;
	}
}

void HardIOWindow_Activate(void)
{
	HardIOWindow_Render(1);
	gtk_widget_realize(GTK_WIDGET(HardIOWindow));
	if ((dclc_hardiowin_winx > -15) && (dclc_hardiowin_winy > -16)) {
		gtk_window_move(HardIOWindow, dclc_hardiowin_winx, dclc_hardiowin_winy);
	}
	if ((dclc_hardiowin_winw > 0) && (dclc_hardiowin_winh > 0)) {
		gtk_window_resize(HardIOWindow, dclc_hardiowin_winw, dclc_hardiowin_winh);
	}
	gtk_widget_show(GTK_WIDGET(HardIOWindow));
	gtk_window_present(HardIOWindow);
}

void HardIOWindow_UpdateConfigs(void)
{
	HardIOWindow_InConfigs = 1;

	gtk_combo_box_set_active(ComboReg, 0);

	switch (dclc_hardiowin_refresh) {
		case 0: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/100% 72fps")), 1);
			break;
		case 1: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 50% 36fps")), 1);
			break;
		case 2: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 33% 24fps")), 1);
			break;
		case 3: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 25% 18fps")), 1);
			break;
		case 5: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 17% 12fps")), 1);
			break;
		case 7: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 12%  9fps")), 1);
			break;
		case 11: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  8%  6fps")), 1);
			break;
		case 19: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  6%  3fps")), 1);
			break;
		default: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/Custom...")), 1);
			break;
	}

	HardIOWindow_InConfigs = 0;
}

void HardIOWindow_Sensitive(int enabled)
{
	if (enabled) {
		gtk_widget_hide(GTK_WIDGET(LabelRunFull));
		gtk_widget_show(GTK_WIDGET(HardIOSW));
		gtk_widget_show(GTK_WIDGET(CheckAutoWrite));
		gtk_widget_show(GTK_WIDGET(ButtonWrite));
	} else {
		gtk_widget_show(GTK_WIDGET(LabelRunFull));
		gtk_widget_hide(GTK_WIDGET(HardIOSW));
		gtk_widget_hide(GTK_WIDGET(CheckAutoWrite));
		gtk_widget_hide(GTK_WIDGET(ButtonWrite));
	}
}

void HardIOWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_hardiowin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(HardIOWindow)) || HardIOWindow_minimized) return;
		}
		HardIOWindow_Render(0);
	} else refreshcnt--;
}
