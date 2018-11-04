/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* v810_fp_ops.h:
**  Copyright (C) 2014-2016 Mednafen Team
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

#include <mednafen/mednafen.h>

class V810_FP_Ops
{
 public:

 uint32 mul(uint32 a, uint32 b);
 uint32 div(uint32 a, uint32 b);
 uint32 add(uint32 a, uint32 b);
 uint32 sub(uint32 a, uint32 b);
 int cmp(uint32 a, uint32 b);

 uint32 itof(uint32 v);
 uint32 ftoi(uint32 v, bool truncate);

 enum
 {
  flag_invalid = 0x0001,
  flag_divbyzero = 0x0002,
  flag_overflow = 0x0004,
  flag_underflow = 0x0008,
  flag_inexact = 0x0010,
  flag_reserved = 0x0020
 };

 inline uint32 get_flags(void)
 {
  return exception_flags;
 }

 inline void clear_flags(void)
 {
  exception_flags = 0;
 }

 private:

 unsigned exception_flags;

 struct fpim
 {
  uint64 f;
  int exp;
  bool sign;
 };

 bool fp_is_zero(uint32 v);
 bool fp_is_inf_nan_sub(uint32 v);

 unsigned clz64(uint64 v);
 void fpim_decode(fpim* df, uint32 v);
 void fpim_round(fpim* df);
 void fpim_round_int(fpim* df, bool truncate = false);
 uint32 fpim_encode(fpim* df);
};

