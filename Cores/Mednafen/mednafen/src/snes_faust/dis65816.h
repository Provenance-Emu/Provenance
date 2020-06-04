/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* dis65816.h:
**  Copyright (C) 2019 Mednafen Team
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

namespace Mednafen
{
 class Dis65816
 {
  public:
  Dis65816();
  ~Dis65816();

  void Disassemble(uint32& A, uint32 SpecialA, char* buf, bool CurM, bool CurX, uint8 (*Read)(uint32 addr));

  void ResetMXHints(void);
  void SetMXHint(uint32 addr, int M, int X);

  private:

  bool IsMXHintSet(uint32 addr);
  bool GetM(uint32 addr, bool CurM);
  bool GetX(uint32 addr, bool CurX);

  uint8 MXHints[(1U << 24) / 2];

  enum
  {
   AM_IMP,

   AM_IM_1,
   AM_IM_M,
   AM_IM_X,

   AM_AB,
   AM_ABL,
   AM_ABLX,
   AM_ABX,
   AM_ABY,
   AM_DP,
   AM_DPX,
   AM_DPY,
   AM_IND,
   AM_INDL,
   AM_IX,
   AM_IY,
   AM_ILY,
   AM_SR,
   AM_SRIY,

   AM_R,
   AM_RL,

   AM_BLOCK,
   AM_ABIND,
   AM_ABIX,
  };

  struct OpTableEntry
  {
   const char* mnemonic;
   uint8 address_mode;
  };
 
  static const OpTableEntry OpTable[256];
 };
}
