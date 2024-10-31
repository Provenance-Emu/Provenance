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

#ifdef IMAGE_SUPPORT

#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "nanojpeg_lib.hxx"
#include "tinyexif_lib.hxx"

#include "JPGLibrary.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
JPGLibrary::JPGLibrary(OSystem& osystem)
  : myOSystem{osystem}
{
  njInit();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JPGLibrary::loadImage(const string& filename, FBSurface& surface,
                           VariantList& metaData)
{
  std::ifstream in(filename, std::ios_base::binary | std::ios::ate);
  if(!in.is_open())
    throw runtime_error("No image found");
  const size_t size = in.tellg();
  in.clear();
  in.seekg(0);

  // Create space for the entire file
  if(size > myFileBuffer.capacity())
    myFileBuffer.reserve(size * 1.5);
  if(!in.read(myFileBuffer.data(), size))
    throw runtime_error("JPG image data reading failed");

  if(njDecode(myFileBuffer.data(), static_cast<int>(size)))
    throw runtime_error("Error decoding the JPG image");

  // Read the entire image in one go
  myReadInfo.buffer = njGetImage();
  myReadInfo.width = njGetWidth();
  myReadInfo.height = njGetHeight();
  myReadInfo.pitch = myReadInfo.width * 3;

  // Read the meta data we got
  readMetaData(filename, metaData);

  // Load image into the surface, setting the correct dimensions
  loadImagetoSurface(surface);

  // Cleanup
  njDone();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JPGLibrary::loadImagetoSurface(FBSurface& surface)
{
  // First determine if we need to resize the surface
  const uInt32 iw = myReadInfo.width, ih = myReadInfo.height;
  if(iw > surface.width() || ih > surface.height())
    surface.resize(iw, ih);

  // The source dimensions are set here; the destination dimensions are
  // set by whoever owns the surface
  surface.setSrcPos(0, 0);
  surface.setSrcSize(iw, ih);

  // Convert RGB triples into pixels and store in the surface
  uInt32 *s_buf{nullptr}, s_pitch{0};
  surface.basePtr(s_buf, s_pitch);
  const uInt8* i_buf = myReadInfo.buffer;
  const uInt32 i_pitch = myReadInfo.pitch;

  const FrameBuffer& fb = myOSystem.frameBuffer();
  for(uInt32 irow = 0; irow < ih; ++irow, i_buf += i_pitch, s_buf += s_pitch)
  {
    const uInt8* i_ptr = i_buf;
    uInt32* s_ptr = s_buf;
    for(uInt32 icol = 0; icol < myReadInfo.width; ++icol, i_ptr += 3)
      *s_ptr++ = fb.mapRGB(*i_ptr, *(i_ptr + 1), *(i_ptr + 2));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JPGLibrary::readMetaData(const string& filename, VariantList& metaData)
{
  metaData.clear();

  // open a stream to read just the necessary parts of the image file
  std::ifstream in(filename, std::ifstream::binary);

  // parse image EXIF metadata
  const TinyEXIF::EXIFInfo imageEXIF(in);
  if(imageEXIF.Fields)
  {
    // For now we only read the image description
    if(!imageEXIF.ImageDescription.empty())
      VarList::push_back(metaData, "ImageDescription", imageEXIF.ImageDescription);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::vector<char> JPGLibrary::myFileBuffer;

#endif  // IMAGE_SUPPORT
