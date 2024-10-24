//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

/*
 * Atari TIA NTSC video filter
 * Based on nes_ntsc 0.2.2. http://www.slack.net/~ant
 *
 * Copyright (C) 2006-2009 Shay Green. This module is free software; you
 * can redistribute it and/or modify it under the terms of the GNU Lesser
 * General Public License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version. This
 * module is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details. You should have received a copy of the GNU Lesser General Public
 * License along with this module; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/**
  The class is basically a thin wrapper around atari_ntsc_xxx structs
  and methods, so that the rest of the codebase isn't affected by
  updated versions of Blargg code.
*/

#ifndef ATARI_NTSC_HXX
#define ATARI_NTSC_HXX

#include <cmath>
#include <thread>

#include "FrameBufferConstants.hxx"
#include "bspf.hxx"

class AtariNTSC
{
  public:
    // By default, threading is turned off and palette is blank
    AtariNTSC() { enableThreading(false); myRGBPalette.fill(0); }

    // Image parameters, ranging from -1.0 to 1.0. Actual internal values shown
    // in parenthesis and should remain fairly stable in future versions.
    struct Setup
    {
      // Basic parameters
      float sharpness{0.F};  // edge contrast enhancement/blurring

      // Advanced parameters
      float resolution{0.F}; // image resolution
      float artifacts{0.F};  // artifacts caused by color changes
      float fringing{0.F};   // color artifacts caused by brightness changes
      float bleed{0.F};      // color bleed (color resolution reduction)
    };

    // Video format presets
    static constexpr Setup TV_Composite = { // color bleeding + artifacts
      0.0F, 0.15F, 0.0F, 0.0F, 0.0F
    };
    static constexpr Setup TV_SVideo = {    // color bleeding only
      0.0F, 0.45F, -1.0F, -1.0F, 0.0F
    };
    static constexpr Setup TV_RGB = {       // crisp image
      0.2F, 0.70F, -1.0F, -1.0F, -1.0F
    };
    static constexpr Setup TV_Bad = {       // badly adjusted TV
      0.2F, 0.1F, 0.5F, 0.5F, 0.5F
    };

    // Initializes and adjusts parameters
    // Note that this must be called before setting a palette
    void initialize(const Setup& setup);

    // Set palette for normal Blarrg mode
    void setPalette(const PaletteArray& palette);

    // Set up threading
    void enableThreading(bool enable);

    // Filters one or more rows of pixels. Input pixels are 8-bit Atari
    // palette colors.
    //  In_row_width is the number of pixels to get to the next input row.
    //  Out_pitch is the number of *bytes* to get to the next output row.
    void render(const uInt8* atari_in, const uInt32 in_width, const uInt32 in_height,
                void* rgb_out, const uInt32 out_pitch, uInt32* rgb_in = nullptr);

    // Number of output pixels written by blitter for given input width.
    // Width might be rounded down slightly; use inWidth() on result to
    // find rounded value. Guaranteed not to round 160 down at all.
    static constexpr uInt32 outWidth(uInt32 in_width) {
      return ((((in_width) - 1) / PIXEL_in_chunk + 1)* PIXEL_out_chunk) + 8;
    }

  private:
    // Generate kernels from raw RGB palette
    void generateKernels();

    // Threaded rendering
    void renderThread(const uInt8* atari_in, const uInt32 in_width,
      const uInt32 in_height, const uInt32 numThreads, const uInt32 threadNum, void* rgb_out, const uInt32 out_pitch);
    void renderWithPhosphorThread(const uInt8* atari_in, const uInt32 in_width,
      const uInt32 in_height, const uInt32 numThreads, const uInt32 threadNum, uInt32* rgb_in, void* rgb_out, const uInt32 out_pitch);

  private:
    static constexpr Int32
      PIXEL_in_chunk  = 2,   // number of input pixels read per chunk
      PIXEL_out_chunk = 7,   // number of output pixels generated per chunk
      NTSC_black      = 0,   // palette index for black

      palette_size    = 256,
      entry_size      = 2 * 14,
      alignment_count = 2,
      burst_count     = 1,
      rescale_in      = 8,
      rescale_out     = 7,

      burst_size  = entry_size / burst_count,
      kernel_half = 16,
      kernel_size = kernel_half * 2 + 1,

      rgb_builder = ((1 << 21) | (1 << 11) | (1 << 1)),
      rgb_kernel_size = burst_size / alignment_count,
      rgb_bits = 8,
      rgb_unit = (1 << rgb_bits),
      rgb_bias = rgb_unit * 2 * rgb_builder,

      std_decoder_hue = 0,
      ext_decoder_hue = std_decoder_hue + 15,

      atari_ntsc_clamp_mask = rgb_builder * 3 / 2,
      atari_ntsc_clamp_add  = rgb_builder * 0x101
    ;

    static constexpr float
      artifacts_mid = 1.5F,
      artifacts_max = 2.5F,
      fringing_mid  = 1.0F,
      fringing_max  = 2.0F,
      rgb_offset    = (rgb_unit * 2 + 0.5F),
      luma_cutoff   = 0.20F
    ;

    std::array<uInt8, palette_size*3> myRGBPalette;
    BSPF::array2D<uInt32, palette_size, entry_size> myColorTable;

    // Rendering threads
    unique_ptr<std::thread[]> myThreads;  // NOLINT
    // Number of rendering and total threads
    uInt32 myWorkerThreads{0}, myTotalThreads{0};

    struct init_t
    {
      std::array<float, burst_count * 6> to_rgb{0.F};
      float artifacts{0.F};
      float fringing{0.F};
      std::array<float, rescale_out * kernel_size * 2> kernel{0.F};

      init_t() {
        to_rgb.fill(0.0);
        kernel.fill(0.0);
      }
    };
    init_t myImpl;

    struct pixel_info_t
    {
      int offset{0};
      float negate{0.F};
      std::array<float, 4> kernel{0.F};
    };
    static const std::array<pixel_info_t, alignment_count> atari_ntsc_pixels;

    static constexpr std::array<float, 6> default_decoder = {
      0.9563F, 0.6210F, -0.2721F, -0.6474F, -1.1070F, 1.7046F
    };

    static void init(init_t& impl, const Setup& setup);
    static void initFilters(init_t& impl, const Setup& setup);
    // Generate pixel at all burst phases and column alignments
    static void genKernel(init_t& impl, float y, float i, float q, uInt32* out);

    // Begins outputting row and starts two pixels. First pixel will be cut
    // off a bit.  Use atari_ntsc_black for unused pixels.
    #define ATARI_NTSC_BEGIN_ROW( pixel0, pixel1 ) \
      constexpr unsigned atari_ntsc_pixel0_ = (pixel0);\
      uInt32 const* kernel0  = myColorTable[atari_ntsc_pixel0_].data();\
      unsigned const atari_ntsc_pixel1_ = (pixel1);\
      uInt32 const* kernel1  = myColorTable[atari_ntsc_pixel1_].data();\
      uInt32 const* kernelx0;\
      uInt32 const* kernelx1 = kernel0

    // Begins input pixel
    #define ATARI_NTSC_COLOR_IN( index, color ) {\
      uintptr_t color_;\
      kernelx##index = kernel##index;\
      kernel##index = (color_ = (color), myColorTable[color_].data());\
    }

    // Generates output in the specified 32-bit format.
    //  8888:   00000000 RRRRRRRR GGGGGGGG BBBBBBBB (8-8-8-8 32-bit ARGB)
    #define ATARI_NTSC_RGB_OUT_8888( index, rgb_out ) {\
      uInt32 raw_ =\
        kernel0  [index       ] + kernel1  [(index+10)%7+14] +\
        kernelx0 [(index+7)%14] + kernelx1 [(index+ 3)%7+14+7];\
      ATARI_NTSC_CLAMP( raw_, 0 );\
      rgb_out = (raw_>>5 & 0x00FF0000)|(raw_>>3 & 0x0000FF00)|(raw_>>1 & 0x000000FF);\
    }

    // Common ntsc macros
    static constexpr void ATARI_NTSC_CLAMP( uInt32& io, uInt32 shift ) {
      const uInt32 sub = io >> (9-(shift)) & atari_ntsc_clamp_mask;
      uInt32 clamp = atari_ntsc_clamp_add - sub;
      io |= clamp;
      clamp -= sub;
      io &= clamp;
    }

    static constexpr void RGB_TO_YIQ(float r, float g, float b,
        float& y, float& i, float& q) {
      y = r * 0.299F + g * 0.587F + b * 0.114F;
      i = r * 0.595716F - g * 0.274453F - b * 0.321263F;
      q = r * 0.211456F - g * 0.522591F + b * 0.311135F;
    }
    static constexpr void YIQ_TO_RGB(float y, float i, float q,
        const float* to_rgb, int& ir, int& ig, int& ib) {
      ir = static_cast<int>(y + to_rgb[0] * i + to_rgb[1] * q);
      ig = static_cast<int>(y + to_rgb[2] * i + to_rgb[3] * q);
      ib = static_cast<int>(y + to_rgb[4] * i + to_rgb[5] * q);
    }

    static constexpr uInt32 PACK_RGB( int r, int g, int b ) {
      return r << 21 | g << 11 | b << 1;
    }

    // Converted from C-style macros; I don't even pretend to understand the logic here :)
    static constexpr int PIXEL_OFFSET1( int ntsc, int scaled ) {
      return (kernel_size / 2 + ((ntsc) - (scaled) / rescale_out * rescale_in) +
        ((((scaled) + rescale_out * 10) % rescale_out) != 0) +
        (rescale_out - (((scaled) + rescale_out * 10) % rescale_out)) % rescale_out +
        (kernel_size * 2 * (((scaled) + rescale_out * 10) % rescale_out)));
    }
    static constexpr float PIXEL_OFFSET2( int ntsc ) {
      return 1.0F - (((ntsc) + 100) & 2);
    }

  #if 0  // DEAD CODE
    // Number of input pixels that will fit within given output width.
    // Might be rounded down slightly; use outWidth() on result to find
    // rounded value.
    static constexpr uInt32 inWidth( uInt32 out_width ) {
      return (((out_width - 8) / PIXEL_out_chunk - 1) * PIXEL_in_chunk + 1);
    }

    #define ROTATE_IQ( i, q, sin_b, cos_b ) {\
      float t;\
      t = i * cos_b - q * sin_b;\
      q = i * sin_b + q * cos_b;\
      i = t;\
    }

    #define DISTRIBUTE_ERROR( a, b, c ) {\
      uInt32 fourth = (error + 2 * rgb_builder) >> 2;\
      fourth &= (rgb_bias >> 1) - rgb_builder;\
      fourth -= rgb_bias >> 2;\
      out [a] += fourth;\
      out [b] += fourth;\
      out [c] += fourth;\
      out [i] += error - (fourth * 3);\
    }

    #define RGB_PALETTE_OUT( rgb, out_ ) {\
      unsigned char* out = (out_);\
      uInt32 clamped = (rgb);\
      ATARI_NTSC_CLAMP( clamped, (8 - rgb_bits) );\
      out [0] = (unsigned char) (clamped >> 21);\
      out [1] = (unsigned char) (clamped >> 11);\
      out [2] = (unsigned char) (clamped >>  1);\
    }
  #endif
};

#endif
