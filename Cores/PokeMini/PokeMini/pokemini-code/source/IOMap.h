/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

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

#ifndef IO_MAP_H
#define IO_MAP_H

#include "PokeMini.h"

// Pokemon-Mini I/O Registers
#define PM_IO			(&PM_RAM[0x1000])

#define PMR_SYS_CTRL1		(PM_RAM[0x1000])
#define PMR_SYS_CTRL2		(PM_RAM[0x1001])
#define PMR_SYS_CTRL3		(PM_RAM[0x1002])

#define PMR_SEC_CTRL		(PM_RAM[0x1008])
#define PMR_SEC_CNT_LO		(PM_RAM[0x1009])
#define PMR_SEC_CNT_MID		(PM_RAM[0x100A])
#define PMR_SEC_CNT_HI		(PM_RAM[0x100B])

#define PMR_SYS_BATT		(PM_RAM[0x1010])

#define PMR_TMR1_SCALE		(PM_RAM[0x1018])
#define PMR_TMR1_ENA_OSC	(PM_RAM[0x1019])
#define PMR_TMR1_OSC		(PM_RAM[0x1019])
#define PMR_TMR2_SCALE		(PM_RAM[0x101A])
#define PMR_TMR2_OSC		(PM_RAM[0x101B])
#define PMR_TMR3_SCALE		(PM_RAM[0x101C])
#define PMR_TMR3_OSC		(PM_RAM[0x101D])

#define PMR_IRQ_PRI1		(PM_RAM[0x1020])
#define PMR_IRQ_PRI2		(PM_RAM[0x1021])
#define PMR_IRQ_PRI3		(PM_RAM[0x1022])
#define PMR_IRQ_ENA1		(PM_RAM[0x1023])
#define PMR_IRQ_ENA2		(PM_RAM[0x1024])
#define PMR_IRQ_ENA3		(PM_RAM[0x1025])
#define PMR_IRQ_ENA4		(PM_RAM[0x1026])
#define PMR_IRQ_ACT1		(PM_RAM[0x1027])
#define PMR_IRQ_ACT2		(PM_RAM[0x1028])
#define PMR_IRQ_ACT3		(PM_RAM[0x1029])
#define PMR_IRQ_ACT4		(PM_RAM[0x102A])

#define PMR_TMR1_CTRL_L		(PM_RAM[0x1030])
#define PMR_TMR1_CTRL_H		(PM_RAM[0x1031])
#define PMR_TMR1_PRE_L		(PM_RAM[0x1032])
#define PMR_TMR1_PRE_H		(PM_RAM[0x1033])
#define PMR_TMR1_PVT_L		(PM_RAM[0x1034])
#define PMR_TMR1_PVT_H		(PM_RAM[0x1035])
#define PMR_TMR1_CNT_L		(PM_RAM[0x1036])
#define PMR_TMR1_CNT_H		(PM_RAM[0x1037])

#define PMR_TMR2_CTRL_L		(PM_RAM[0x1038])
#define PMR_TMR2_CTRL_H		(PM_RAM[0x1039])
#define PMR_TMR2_PRE_L		(PM_RAM[0x103A])
#define PMR_TMR2_PRE_H		(PM_RAM[0x103B])
#define PMR_TMR2_PVT_L		(PM_RAM[0x103C])
#define PMR_TMR2_PVT_H		(PM_RAM[0x103D])
#define PMR_TMR2_CNT_L		(PM_RAM[0x103E])
#define PMR_TMR2_CNT_H		(PM_RAM[0x103F])

#define PMR_TMR256_CTRL		(PM_RAM[0x1040])
#define PMR_TMR256_CNT		(PM_RAM[0x1041])

#define PMR_REG_44		(PM_RAM[0x1044])
#define PMR_REG_45		(PM_RAM[0x1045])
#define PMR_REG_46		(PM_RAM[0x1046])
#define PMR_REG_47		(PM_RAM[0x1047])

#define PMR_TMR3_CTRL_L		(PM_RAM[0x1048])
#define PMR_TMR3_CTRL_H		(PM_RAM[0x1049])
#define PMR_TMR3_PRE_L		(PM_RAM[0x104A])
#define PMR_TMR3_PRE_H		(PM_RAM[0x104B])
#define PMR_TMR3_PVT_L		(PM_RAM[0x104C])
#define PMR_TMR3_PVT_H		(PM_RAM[0x104D])
#define PMR_TMR3_CNT_L		(PM_RAM[0x104E])
#define PMR_TMR3_CNT_H		(PM_RAM[0x104F])

#define PMR_REG_50		(PM_RAM[0x1050])
#define PMR_REG_51		(PM_RAM[0x1051])
#define PMR_KEY_PAD		(PM_RAM[0x1052])
#define PMR_REG_53		(PM_RAM[0x1053])
#define PMR_REG_54		(PM_RAM[0x1054])
#define PMR_REG_55		(PM_RAM[0x1055])

#define PMR_IO_DIR		(PM_RAM[0x1060])
#define PMR_IO_DATA		(PM_RAM[0x1061])
#define PMR_REG_62		(PM_RAM[0x1062])

#define PMR_AUD_CTRL		(PM_RAM[0x1070])
#define PMR_AUD_VOL		(PM_RAM[0x1071])

#define PMR_PRC_MODE		(PM_RAM[0x1080])
#define PMR_PRC_RATE		(PM_RAM[0x1081])
#define PMR_PRC_MAP_LO		(PM_RAM[0x1082])
#define PMR_PRC_MAP_MID		(PM_RAM[0x1083])
#define PMR_PRC_MAP_HI		(PM_RAM[0x1084])
#define PMR_PRC_SCROLL_Y	(PM_RAM[0x1085])
#define PMR_PRC_SCROLL_X	(PM_RAM[0x1086])
#define PMR_PRC_SPR_LO		(PM_RAM[0x1087])
#define PMR_PRC_SPR_MID		(PM_RAM[0x1088])
#define PMR_PRC_SPR_HI		(PM_RAM[0x1089])
#define PMR_PRC_CNT		(PM_RAM[0x108A])

#define PMR_LCD_CTRL		(PM_RAM[0x10FE])
#define PMR_LCD_DATA		(PM_RAM[0x10FF])

#endif
