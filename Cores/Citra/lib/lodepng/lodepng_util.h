/*
LodePNG Utils

Copyright (c) 2005-2022 Lode Vandevenne

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software
    in a product, an acknowledgment in the product documentation would be
    appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.

    3. This notice may not be removed or altered from any source
    distribution.
*/

/*
Extra C++ utilities for LodePNG, for convenience.
Not part of the stable API of lodepng, more loose separate utils.
*/

#ifndef LODEPNG_UTIL_H
#define LODEPNG_UTIL_H

#include <string>
#include <vector>
#include "lodepng.h"

namespace lodepng {

/*
Returns info from the header of the PNG by value, purely for convenience.
Does NOT check for errors. Returns bogus info if the PNG has an error.
Does not require cleanup of allocated memory because no palette or text chunk
info is in the LodePNGInfo object after checking only the header of the PNG.
*/
LodePNGInfo getPNGHeaderInfo(const std::vector<unsigned char>& png);

/*
Get the names and sizes of all chunks in the PNG file.
Returns 0 if ok, non-0 if error happened.
*/
unsigned getChunkInfo(std::vector<std::string>& names, std::vector<size_t>& sizes,
                      const std::vector<unsigned char>& png);

/*
Returns the names and full chunks (including the name and everything else that
makes up the chunk) for all chunks except IHDR, PLTE, IDAT and IEND.
It separates the chunks into 3 separate lists, representing the chunks between
certain critical chunks: 0: IHDR-PLTE, 1: PLTE-IDAT, 2: IDAT-IEND
Returns 0 if ok, non-0 if error happened.
*/
unsigned getChunks(std::vector<std::string> names[3],
                   std::vector<std::vector<unsigned char> > chunks[3],
                   const std::vector<unsigned char>& png);

/*
Inserts chunks into the given png file. The chunks must be fully encoded,
including length, type, content and CRC.
The array index determines where it goes:
0: between IHDR and PLTE, 1: between PLTE and IDAT, 2: between IDAT and IEND.
They're appended at the end of those locations within the PNG.
Returns 0 if ok, non-0 if error happened.
*/
unsigned insertChunks(std::vector<unsigned char>& png,
                      const std::vector<std::vector<unsigned char> > chunks[3]);

/*
Get the filtertypes of each scanline in this PNG file.
Returns 0 if ok, 1 if PNG decoding error happened.

For a non-interlaced PNG, it returns one filtertype per scanline, in order.

For interlaced PNGs, it returns a result as if it's not interlaced. It returns
one filtertype per scanline, in order. The values match pass 6 and 7 of the
Adam7 interlacing, alternating between the two, so that the values correspond
the most to their scanlines.
*/
unsigned getFilterTypes(std::vector<unsigned char>& filterTypes, const std::vector<unsigned char>& png);

/*
Get the filtertypes of each scanline in every interlace pass this PNG file.
Returns 0 if ok, 1 if PNG decoding error happened.

For a non-interlaced PNG, it returns one filtertype per scanline, in order, in
a single std::vector in filterTypes.

For an interlaced PNG, it returns 7 std::vectors in filterTypes, one for each
Adam7 pass. The amount of values per pass can be calculated as follows, where
w and h are the size of the image and all divisions are integer divisions:
pass 1: (h + 7) / 8
pass 2: w <= 4 ? 0 : (h + 7) / 8
pass 3: h <= 4 ? 0 : (h + 7) / 8
pass 4: w <= 2 ? 0 : (h + 3) / 4
pass 5: h <= 2 ? 0 : (h + 3) / 4
pass 6: w <= 1 ? 0 : (h + 1) / 2
pass 7: h <= 1 ? 0 : (h + 1) / 2
*/
unsigned getFilterTypesInterlaced(std::vector<std::vector<unsigned char> >& filterTypes,
                                  const std::vector<unsigned char>& png);

/*
Returns the value of the i-th pixel in an image with 1, 2, 4 or 8-bit color.
E.g. if bits is 4 and i is 5, it returns the 5th nibble (4-bit group), which
is the second half of the 3th byte, in big endian (PNG's endian order).
*/
int getPaletteValue(const unsigned char* data, size_t i, int bits);

#ifdef LODEPNG_COMPILE_ANCILLARY_CHUNKS

/* Similar to convertRGBModel, but the 'to' model is sRGB. The pixel format
of in and out must be the same and is given by state_in->info_raw. An
error may occur if the pixel format cannot contain the new colors (e.g. palette) */
unsigned convertToSrgb(unsigned char* out, const unsigned char* in,
                       unsigned w, unsigned h,
                       const LodePNGState* state_in);

/* Similar to convertRGBModel, but the 'from' model is sRGB. The pixel format
of in and out must be the same and is given by state_out->info_raw. An
error may occur if the pixel format cannot contain the new colors (e.g. palette) */
unsigned convertFromSrgb(unsigned char* out, const unsigned char* in,
                         unsigned w, unsigned h,
                         const LodePNGState* state_out);

/*
Converts from one RGB model to another RGB model.
Similar to calling convertToXYZ followed by convertFromXYZ, but may be
more efficient and more precise (e.g. no computation needed when both models
are the same). See their documentation for more info.

Parameters:

*) out: output pixel data
*) in: input pixel data
*) w, h: image size
*) state_out: output RGB color model in state_out->info_png and byte format in state_out->info_raw.
*) state_in: output RGB color model in state_in->info_png and byte format in state_in->info_raw
*) return value: 0 if ok, positive value if error
*) rendering_intent: 1 for relative, 3 for absolute, should be relative for standard behavior.
   See description at convertFromXYZ.
*/
unsigned convertRGBModel(unsigned char* out, const unsigned char* in,
                         unsigned w, unsigned h,
                         const LodePNGState* state_out,
                         const LodePNGState* state_in,
                         unsigned rendering_intent);

/*
Converts the RGB color to the absolute XYZ color space given the RGB color profile
chunks in the PNG info.

Color space here refers to the different possible RGB spaces with different
possible chromaticities or whitepoint and XYZ color from colorimetry, not the
LodePNGColorType that describes the byte based encoding.

You need this function only if the PNG could contain data in an arbitrary RGB
color space and you wish to output to a display or format that does not provide
color management for you (so you need to convert rather than pass on the profile
to it) but expects a certain RGB format (e.g. sRGB). See the background info below.

Supports the gAMA, cHRM, sRGB and iCCP colorimetry chunks. If no colometry chunks are present
(that is, in state->info_png, the fields gama_defined, chrm_defined, srgb_defined and
iccp_defined are all 0), it assumes the format is sRGB.
For more information, see the chunk specifications in the PNG specification.

Some background:

A PNG image contains RGB data inside, but this data may use a specific RGB model (by default sRGB but
different if colorimetry chunks are given).
The computer display and/or operating system can have another RGB model (typically sRGB, or wider gamut
or HDR formats).

The PNG chunks describe what format the data inside has, not the format of the display. To correctly
display a PNG image on a display, a conversion is needed from the PNG model to the display model if their
models differ. Some options to achieve that are:
*) If your use case already supports color management on its own, you can give it the RGB values straight from
   the PNG image and give it the information from the cHRM, gAMA, sRGB and iCCP chunks (which you can find
   in the LodePNGInfo), and the color management should then handle it correctly for you. You don't need
   this function here in that case.
*) If your use case does not support color management, you may instead want to give it the RGB values in a
   consistent color model, such as sRGB, but the PNG does not necessarily have it in this desired model.
   In that case, use the function below (or a similar one from a CMS library if you prefer) to convert it to
   the absolute color space XYZ, and then you can convert it to the target RGB with the counterpart convertFromXYZ
   further below.

Parameters:

*) out: 4 floats per pixel, X,Y,Z,alpha color format, in range 0-1 (normally, not clipped if beyond), must
   be allocated to have 4 * w * h floats available.
*) whitepoint: output argument, the whitepoint the original RGB data used, given in absolute XYZ. Needed for
   relative rendering intents: give these values to counterpart function convertFromXYZ.
*) in: input RGB color, in byte format given by state->info_raw and RGB color profile given by info->info_png
*) w, h: image size
*) state (when using a LodePNG decode function that takes a LodePNGState parameter, can directly use that one):
   state->info_png: PNG info with possibly an RGB color model in cHRM,gAMA and/or sRGB chunks
   state->info_raw: byte format of in (amount of channels, bit depth)
*) return value: 0 if ok, positive value if error
*/
unsigned convertToXYZ(float* out, float whitepoint[3],
                      const unsigned char* in, unsigned w, unsigned h,
                      const LodePNGState* state);

/*
Same as convertToXYZ but takes floating point input. Slower.
The main black..white range in 0..1. Does not clip values that are outside that range.
*/
unsigned convertToXYZFloat(float* out, float whitepoint[3], const float* in,
                           unsigned w, unsigned h, const LodePNGState* state);

/*
Converts XYZ to RGB in the RGB color model given by info and byte format by mode_out.
If info has no coloremtry chunks, converts to sRGB.
Parameters:
*) out: output color in byte format given by state->info_raw and RGB color profile given
   by info->info_png. Must have enough bytes allocated to contain pixels in the given byte format.
*) in: 4 floats per pixel, X,Y,Z,alpha color format, in range 0-1 (normally).
*) whitepoint: input argument, the original whitepoint in absolute XYZ that the pixel data
   in "in" had back when it was in a previous RGB space. Needed to preserve the whitepoint
   in the new target RGB space for relative rendering intent.
*) rendering_intent: the desired rendering intent, with numeric meaning matching the
   values used by ICC: 0=perceptual, 1=relative, 2=saturation, 3=absolute.
   Should be 1 for normal use cases, it adapts white to match that of different RGB
   models which is the best practice. Using 3 may change the color of white and may
   turn grayscale into colors of a certain tone. Using 0 and 2 will have the same
   effect as 1 because using those requires more data than the matrix-based RGB profiles
   supporetd here have.
*) w, h: image size
*) state:
   state->info_png: PNG info with possibly an RGB color profile in cHRM,gAMA and/or sRGB chunks
   state->info_raw: byte format of out (amount of channels, bit depth)
*) return value: 0 if ok, positive value if error
*/
unsigned convertFromXYZ(unsigned char* out, const float* in, unsigned w, unsigned h,
                        const LodePNGState* state,
                        const float whitepoint[3], unsigned rendering_intent);

/*
Same as convertFromXYZ but outputs the RGB colors in floating point.
The main black..white range in 0..1. Does not clip values that are outside that range.
*/
unsigned convertFromXYZFloat(float* out, const float* in, unsigned w, unsigned h,
                             const LodePNGState* state,
                             const float whitepoint[3], unsigned rendering_intent);
#endif /*LODEPNG_COMPILE_ANCILLARY_CHUNKS*/

/*
The information for extractZlibInfo.
*/
struct ZlibBlockInfo {
  int btype; //block type (0-2)
  size_t compressedbits; //size of compressed block in bits
  size_t uncompressedbytes; //size of uncompressed block in bytes

  // only filled in for block type 2
  size_t treebits; //encoded tree size in bits
  int hlit; //the HLIT value that was filled in for this tree
  int hdist; //the HDIST value that was filled in for this tree
  int hclen; //the HCLEN value that was filled in for this tree
  std::vector<int> clcl; //19 code length code lengths (compressed tree's tree)
  std::vector<int> treecodes; //N tree codes, with values 0-18. Values 17 or 18 are followed by the repetition value.
  std::vector<int> litlenlengths; //288 code lengths for lit/len symbols
  std::vector<int> distlengths; //32 code lengths for dist symbols

  // only filled in for block types 1 or 2
  std::vector<int> lz77_lcode; //LZ77 codes. 0-255: literals. 256: end symbol. 257-285: length code of length/dist pairs
  // the next vectors have the same size as lz77_lcode, but an element only has meaningful value if lz77_lcode contains a length code.
  std::vector<int> lz77_dcode;
  std::vector<int> lz77_lbits;
  std::vector<int> lz77_dbits;
  std::vector<int> lz77_lvalue;
  std::vector<int> lz77_dvalue;
  size_t numlit; //number of lit codes in this block
  size_t numlen; //number of len codes in this block
};

//Extracts all info needed from a PNG file to reconstruct the zlib compression exactly.
// Returns 0 if no error, non-zero value if error
unsigned extractZlibInfo(std::vector<ZlibBlockInfo>& zlibinfo, const std::vector<unsigned char>& in);

} // namespace lodepng

#endif /*LODEPNG_UTIL_H inclusion guard*/
