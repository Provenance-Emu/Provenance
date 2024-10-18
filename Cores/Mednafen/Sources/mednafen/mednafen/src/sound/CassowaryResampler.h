/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CassowaryResampler.h:
**  Copyright (C) 2023 Mednafen Team
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

// Intended for input rates around 2MHz, output rates of >= 44.1KHz
// Resamples 2MHz -> 500KHz -> 125KHz -> 62.5KHz -> (ratio * 2MHz)
class CassowaryResampler final
{
 public:

 CassowaryResampler(double input_rate_);
 ~CassowaryResampler();

 // Set output/input rates
 void SetOutputRate(double output_rate, bool force_recalc = false);

 uint32 Resample(float* MDFN_RESTRICT src, uint32 src_count, int16* MDFN_RESTRICT dest, uint32 dest_max, uint32* MDFN_RESTRICT leftover);

 INLINE uint32 GetDelay(void)
 {
  assert(num_coeffs[0] && num_coeffs[1] && num_coeffs[2] && div[0] && div[1] && div[2]);
  return ((num_coeffs[0] + num_coeffs[1] * div[0] + num_coeffs[2] * div[0] * div[1] + phaseip_num_coeffs * div[0] * div[1] * div[2]) + 1) / 2;
 }

 private:

 // Should probably be 8 or 9 instead of 7, but it's not cache-friendly and has
 // diminishing returns.
 enum : int { phaseip_num_phases_log2 = 7 };
 enum : int { phaseip_num_phases = 1 << phaseip_num_phases_log2 };
 enum : int { phaseip_num_coeffs = 32 };

 uint32 num_coeffs[3];
 uint32 div[3];

 // Must be multiples of 16.
 enum : size_t { max_coeffs_stage0 =  48 };
 enum : size_t { max_coeffs_stage1 =  48 };
 enum : size_t { max_coeffs_stage2 = 256 };

 alignas(16) float coeffs_stage0[max_coeffs_stage0];
 alignas(16) float coeffs_stage1[max_coeffs_stage1];
 alignas(16) float coeffs_stage2[max_coeffs_stage2];

 alignas(16) float coeffs_phaseip[phaseip_num_phases + 1][phaseip_num_coeffs];	// 62.5KHz -> (ratio * 2MHz)

 const double input_rate;
 double coeffs_halve_ratio;
 uint64 phase_accum_inc;

 struct State
 {
  uint32 buf0_offs;
  uint32 buf1_offs;
  uint32 buf2_offs;
  uint64 phase_accum;

  float buf0[16384 + max_coeffs_stage0]; // 65536 / 4
  float buf1[ 4370 + max_coeffs_stage1]; // 65536 / 5 / 3
  float buf2[ 2185 + max_coeffs_stage2]; // 65536 / 5 / 3 / 2
 } state;

 void ResampleStage012(float* MDFN_RESTRICT src, uint32 src_count, uint32* MDFN_RESTRICT leftover);
 uint32 ResampleStage3(int16* MDFN_RESTRICT dest, uint32 dest_max);
};

}
