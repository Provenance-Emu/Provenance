/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* king_mix_body.inc:
**  Copyright (C) 2006-2016 Mednafen Team
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

    if(fx_vce.dot_clock) // No cellophane in 7.16MHz pixel mode
    {
     if(HighDotClockWidth == 341)
      for(unsigned int x = 0; x < 341; x++)
      {
       LAYER_MIX_BODY(x * 256 / 341, x);
       LAYER_MIX_FINAL_NOCELLO;
      }
     else if(HighDotClockWidth == 256)
      for(unsigned int x = 0; x < 256; x++)
      {
       LAYER_MIX_BODY(x, x * 341 / 256);
       LAYER_MIX_FINAL_NOCELLO;
      }
     else
      for(unsigned int x = 0; x < 1024; x++)
      {
       LAYER_MIX_BODY(x / 4, x / 3);
       LAYER_MIX_FINAL_NOCELLO;
      }
    }
    else if((vce_rendercache.BLE & 0xC000) == 0xC000) // Front cellophane
    {
     uint8 CCR_Y_front = vce_rendercache.coefficient_mul_table_y[(vce_rendercache.coefficients[0] >> 8) & 0xF][(vce_rendercache.CCR >> 8) & 0xFF];
     int8 CCR_U_front = vce_rendercache.coefficient_mul_table_uv[(vce_rendercache.coefficients[0] >> 4) & 0xF][(vce_rendercache.CCR & 0xF0)];
     int8 CCR_V_front = vce_rendercache.coefficient_mul_table_uv[(vce_rendercache.coefficients[0] >> 0) & 0xF][(vce_rendercache.CCR << 4) & 0xF0];

     BPC_Cache = 0x008080 | (LAYER_NONE << 28);

     for(unsigned int x = 0; x < 256; x++)
     {
      LAYER_MIX_BODY(x, x);
      LAYER_MIX_FINAL_FRONT_CELLO;
     }
    }
    else if((vce_rendercache.BLE & 0xC000) == 0x4000) // Back cellophane
    {
     BPC_Cache = ((vce_rendercache.CCR & 0xFF00) << 8) | ((vce_rendercache.CCR & 0xF0) << 8) | ((vce_rendercache.CCR & 0x0F) << 4) | (LAYER_NONE << 28);

     for(unsigned int x = 0; x < 256; x++)
     {
      LAYER_MIX_BODY(x, x);
      LAYER_MIX_FINAL_BACK_CELLO;
     }
    }
    else if(ble_cache_any)		     // No front/back cello, but cellophane on at least 1 layer
    {
     for(unsigned int x = 0; x < 256; x++)
     {
      LAYER_MIX_BODY(x, x);
      LAYER_MIX_FINAL_CELLO
     }
    }
    else				     // No cellophane at all
    {
     for(unsigned int x = 0; x < 256; x++)
     {
      LAYER_MIX_BODY(x, x);
      LAYER_MIX_FINAL_NOCELLO
     }
    }

