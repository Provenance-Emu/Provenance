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
#include "Console.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Props.hxx"
#include "TIASurface.hxx"
#include "Version.hxx"
#include "PNGLibrary.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PNGLibrary::PNGLibrary(OSystem& osystem)
  : myOSystem{osystem}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::loadImage(const string& filename, FBSurface& surface,
                           VariantList& metaData)
{
  png_structp png_ptr{nullptr};
  png_infop info_ptr{nullptr};
  png_uint_32 iwidth{0}, iheight{0};
  int bit_depth{0}, color_type{0}, interlace_type{0};
  bool hasAlpha = false;

  const auto loadImageERROR = [&](string_view s) {
    if(png_ptr)
      png_destroy_read_struct(&png_ptr, info_ptr ? &info_ptr : nullptr, nullptr);
    throw runtime_error(string{s});
  };

  std::ifstream in(filename, std::ios_base::binary);
  if(!in.is_open())
    loadImageERROR("No image found");

  // Create the PNG loading context structure
  png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, nullptr,
                 png_user_error, png_user_warn);
  if(png_ptr == nullptr)
    loadImageERROR("Couldn't allocate memory for PNG image");

  // Allocate/initialize the memory for image information.  REQUIRED.
	info_ptr = png_create_info_struct(png_ptr);
  if(info_ptr == nullptr)
    loadImageERROR("Couldn't create image information for PNG image");

  // Set up the input control
  png_set_read_fn(png_ptr, &in, png_read_data);

  // Read PNG header info
  png_read_info(png_ptr, info_ptr);
  png_get_IHDR(png_ptr, info_ptr, &iwidth, &iheight, &bit_depth,
    &color_type, &interlace_type, nullptr, nullptr);

  // Tell libpng to strip 16 bit/color files down to 8 bits/color
  png_set_strip_16(png_ptr);

  // Extract multiple pixels with bit depths of 1, 2, and 4 from a single
  // byte into separate bytes (useful for paletted and grayscale images).
  png_set_packing(png_ptr);

  // Alpha channel is supported
  if(color_type == PNG_COLOR_TYPE_RGBA)
  {
    hasAlpha = true;
  }
  else if(color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
  {
    // TODO: preserve alpha
    png_set_gray_to_rgb(png_ptr);
  }
  else if(color_type == PNG_COLOR_TYPE_PALETTE)
  {
    if(png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
    {
      png_set_tRNS_to_alpha(png_ptr);
      hasAlpha = true;
    }
    else
      png_set_palette_to_rgb(png_ptr);
  }
  else if(color_type != PNG_COLOR_TYPE_RGB)
  {
    loadImageERROR("Unknown format in PNG image");
  }

  // Create/initialize storage area for the current image
  if(!allocateStorage(iwidth, iheight, hasAlpha))
    loadImageERROR("Not enough memory to read PNG image");

  // The PNG read function expects an array of rows, not a single 1-D array
  for(uInt32 irow = 0, offset = 0; irow < ReadInfo.height; ++irow, offset += ReadInfo.pitch)
    ReadInfo.row_pointers[irow] = ReadInfo.buffer.data() + offset;

  // Read the entire image in one go
  png_read_image(png_ptr, ReadInfo.row_pointers.data());

  // We're finished reading
  png_read_end(png_ptr, info_ptr);

  // Read the meta data we got
  readMetaData(png_ptr, info_ptr, metaData);

  // Load image into the surface, setting the correct dimensions
  loadImagetoSurface(surface, hasAlpha);

  // Cleanup
  if(png_ptr)
    png_destroy_read_struct(&png_ptr, info_ptr ? &info_ptr : nullptr, nullptr);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::saveImage(const string& filename, const VariantList& metaData)
{
  std::ofstream out(filename, std::ios_base::binary);
  if(!out.is_open())
    throw runtime_error("ERROR: Couldn't create snapshot file");

  const FrameBuffer& fb = myOSystem.frameBuffer();

  const Common::Rect& rectUnscaled = fb.imageRect();
  const Common::Rect rect(
    Common::Point(fb.scaleX(rectUnscaled.x()), fb.scaleY(rectUnscaled.y())),
    fb.scaleX(rectUnscaled.w()), fb.scaleY(rectUnscaled.h())
  );

  const size_t width = rect.w(), height = rect.h();

  // Get framebuffer pixel data (we get ABGR format)
  vector<png_byte> buffer(width * height * 4);
  fb.readPixels(buffer.data(), width * 4, rect);

  // Set up pointers into "buffer" byte array
  vector<png_bytep> rows(height);
  for(size_t k = 0; k < height; ++k)
    rows[k] = buffer.data() + k * width * 4;

  // And save the image
  saveImageToDisk(out, rows, width, height, metaData);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::saveImage(const string& filename, const FBSurface& surface,
                           const Common::Rect& rect, const VariantList& metaData)
{
  std::ofstream out(filename, std::ios_base::binary);
  if(!out.is_open())
    throw runtime_error("ERROR: Couldn't create snapshot file");

  // Do we want the entire surface or just a section?
  size_t width = rect.w(), height = rect.h();
  if(rect.empty())
  {
    width = surface.width();
    height = surface.height();
  }

  // Get the surface pixel data (we get ABGR format)
  vector<png_byte> buffer(width * height * 4);
  surface.readPixels(buffer.data(), static_cast<uInt32>(width), rect);

  // Set up pointers into "buffer" byte array
  vector<png_bytep> rows(height);
  for(size_t k = 0; k < height; ++k)
    rows[k] = buffer.data() + k * width * 4;

  // And save the image
  saveImageToDisk(out, rows, width, height, metaData);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::saveImageToDisk(std::ofstream& out, const vector<png_bytep>& rows,
  size_t width, size_t height, const VariantList& metaData)
{
  png_structp png_ptr{nullptr};
  png_infop info_ptr{nullptr};

  const auto saveImageERROR = [&](string_view s) {
    if(png_ptr)
      png_destroy_write_struct(&png_ptr, &info_ptr);
    throw runtime_error(string{s});
  };

  // Create the PNG saving context structure
  png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr,
                 png_user_error, png_user_warn);
  if(png_ptr == nullptr)
    saveImageERROR("Couldn't allocate memory for PNG file");

  // Allocate/initialize the memory for image information.  REQUIRED.
	info_ptr = png_create_info_struct(png_ptr);
  if(info_ptr == nullptr)
    saveImageERROR("Couldn't create image information for PNG file");

  // Set up the output control
  png_set_write_fn(png_ptr, &out, png_write_data, png_io_flush);

  // Write PNG header info
  png_set_IHDR(png_ptr, info_ptr,
      static_cast<png_uint_32>(width), static_cast<png_uint_32>(height), 8,
      PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT,
      PNG_FILTER_TYPE_DEFAULT);

  // Write meta data
  writeMetaData(png_ptr, info_ptr, metaData);

  // Write the file header information.  REQUIRED
  png_write_info(png_ptr, info_ptr);

  // Pack pixels into bytes
  png_set_packing(png_ptr);

  // Swap location of alpha bytes from ARGB to RGBA
  png_set_swap_alpha(png_ptr);

  // Pack ARGB into RGB
  png_set_filler(png_ptr, 0, PNG_FILLER_AFTER);

  // Flip BGR pixels to RGB
  png_set_bgr(png_ptr);

  // Write the entire image in one go
  png_write_image(png_ptr, const_cast<png_bytep*>(rows.data()));

  // We're finished writing
  png_write_end(png_ptr, info_ptr);

  // Cleanup
  if(png_ptr)
    png_destroy_write_struct(&png_ptr, &info_ptr);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::updateTime(uInt64 time)
{
  if(++mySnapCounter % mySnapInterval == 0)
    takeSnapshot(static_cast<uInt32>(time) >> 10);  // not quite milliseconds, but close enough
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::toggleContinuousSnapshots(bool perFrame)
{
  if(mySnapInterval == 0)
  {
    ostringstream buf;
    uInt32 interval = myOSystem.settings().getInt("ssinterval");
    if(perFrame)
    {
      buf << "Enabling snapshots every frame";
      interval = 1;
    }
    else
    {
      buf << "Enabling snapshots in " << interval << " second intervals";
      interval *= static_cast<uInt32>(myOSystem.frameRate());
    }
    myOSystem.frameBuffer().showTextMessage(buf.str());
    setContinuousSnapInterval(interval);
  }
  else
  {
    ostringstream buf;
    buf << "Disabling snapshots, generated "
      << (mySnapCounter / mySnapInterval)
      << " files";
    myOSystem.frameBuffer().showTextMessage(buf.str());
    setContinuousSnapInterval(0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::setContinuousSnapInterval(uInt32 interval)
{
  mySnapInterval = interval;
  mySnapCounter = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::takeSnapshot(uInt32 number)
{
  if(!myOSystem.hasConsole())
    return;

  // Figure out the correct snapshot name
  string filename;
  const string sspath = myOSystem.snapshotSaveDir().getPath() +
      (myOSystem.settings().getString("snapname") != "int"
        ? myOSystem.romFile().getNameWithExt("")
        : myOSystem.console().properties().get(PropType::Cart_Name));

  // Check whether we want multiple snapshots created
  if(number > 0)
  {
    ostringstream buf;
    buf << sspath << "_" << std::hex << std::setw(8) << std::setfill('0')
        << number << ".png";
    filename = buf.str();
  }
  else if(!myOSystem.settings().getBool("sssingle"))
  {
    // Determine if the file already exists, checking each successive filename
    // until one doesn't exist
    filename = sspath + ".png";
    const FSNode node(filename);
    if(node.exists())
    {
      ostringstream buf;
      for(uInt32 i = 1; ;++i)
      {
        buf.str("");
        buf << sspath << "_" << i << ".png";
        const FSNode next(buf.str());
        if(!next.exists())
          break;
      }
      filename = buf.str();
    }
  }
  else
    filename = sspath + ".png";

  // Some text fields to add to the PNG snapshot
  VariantList metaData;
  ostringstream version;
  VarList::push_back(metaData, "Title", "Snapshot");
  version << "Stella " << STELLA_VERSION << " (Build " << STELLA_BUILD << ") ["
          << BSPF::ARCH << "]";
  VarList::push_back(metaData, "Software", version.str());
  const string& name = (myOSystem.settings().getString("snapname") == "int")
      ? myOSystem.console().properties().get(PropType::Cart_Name)
      : myOSystem.romFile().getName();
  VarList::push_back(metaData, "ROM Name", name);
  VarList::push_back(metaData, "ROM MD5", myOSystem.console().properties().get(PropType::Cart_MD5));
  VarList::push_back(metaData, "TV Effects", myOSystem.frameBuffer().tiaSurface().effectsInfo());

  // Now create a PNG snapshot
  string message = "Snapshot saved";
  if(myOSystem.settings().getBool("ss1x"))
  {
    try
    {
      Common::Rect rect;
      const FBSurface& surface =
        myOSystem.frameBuffer().tiaSurface().baseSurface(rect);
      PNGLibrary::saveImage(filename, surface, rect, metaData);
    }
    catch(const runtime_error& e)
    {
      message = e.what();
    }
  }
  else
  {
    // Make sure we have a 'clean' image, with no onscreen messages
    myOSystem.frameBuffer().enableMessages(false);
    myOSystem.frameBuffer().tiaSurface().renderForSnapshot();

    try
    {
      PNGLibrary::saveImage(filename, metaData);
    }
    catch(const runtime_error& e)
    {
      message = e.what();
    }

    // Re-enable old messages
    myOSystem.frameBuffer().enableMessages(true);
  }
  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PNGLibrary::allocateStorage(size_t width, size_t height, bool hasAlpha)
{
  // Create space for the entire image (3(4) bytes per pixel in RGB(A) format)
  const size_t req_buffer_size = width * height * (hasAlpha ? 4 : 3);
  if(req_buffer_size > ReadInfo.buffer.capacity())
    ReadInfo.buffer.resize(req_buffer_size * 1.5);

  const size_t req_row_size = height;
  if(req_row_size > ReadInfo.row_pointers.capacity())
    ReadInfo.row_pointers.resize(req_row_size * 1.5);

  ReadInfo.width  = static_cast<png_uint_32>(width);
  ReadInfo.height = static_cast<png_uint_32>(height);
  ReadInfo.pitch  = static_cast<png_uint_32>(width * (hasAlpha ? 4 : 3));

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::loadImagetoSurface(FBSurface& surface, bool hasAlpha)
{
  // First determine if we need to resize the surface
  const uInt32 iw = ReadInfo.width, ih = ReadInfo.height;
  if(iw > surface.width() || ih > surface.height())
    surface.resize(iw, ih);

  // The source dimensions are set here; the destination dimensions are
  // set by whoever owns the surface
  surface.setSrcPos(0, 0);
  surface.setSrcSize(iw, ih);

  // Convert RGB triples into pixels and store in the surface
  uInt32 *s_buf{nullptr}, s_pitch{0};
  surface.basePtr(s_buf, s_pitch);
  const uInt8* i_buf = ReadInfo.buffer.data();
  const uInt32 i_pitch = ReadInfo.pitch;

  const FrameBuffer& fb = myOSystem.frameBuffer();
  for(uInt32 irow = 0; irow < ih; ++irow, i_buf += i_pitch, s_buf += s_pitch)
  {
    const uInt8* i_ptr = i_buf;
    uInt32* s_ptr = s_buf;
    if(hasAlpha)
      for(uInt32 icol = 0; icol < ReadInfo.width; ++icol, i_ptr += 4)
        *s_ptr++ = fb.mapRGBA(*i_ptr, *(i_ptr+1), *(i_ptr+2), *(i_ptr+3));
    else
      for(uInt32 icol = 0; icol < ReadInfo.width; ++icol, i_ptr += 3)
        *s_ptr++ = fb.mapRGB(*i_ptr, *(i_ptr+1), *(i_ptr+2));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::writeMetaData(
    const png_structp png_ptr, png_infop info_ptr,  // NOLINT
    const VariantList& metaData)
{
  const size_t numMetaData = metaData.size();
  if(numMetaData == 0)
    return;

  vector<png_text> text_ptr(numMetaData);
  for(size_t i = 0; i < numMetaData; ++i)
  {
    text_ptr[i].key = const_cast<char*>(metaData[i].first.c_str());
    text_ptr[i].text = const_cast<char*>(metaData[i].second.toCString());
    text_ptr[i].compression = PNG_TEXT_COMPRESSION_NONE;
    text_ptr[i].text_length = 0;
  }
  png_set_text(png_ptr, info_ptr, text_ptr.data(), static_cast<int>(numMetaData));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::readMetaData(
    const png_structp png_ptr, png_infop info_ptr,  // NOLINT
    VariantList& metaData)
{
  png_textp text_ptr{nullptr};
  int numMetaData{0};

  png_get_text(png_ptr, info_ptr, &text_ptr, &numMetaData);

  metaData.clear();
  for(int i = 0; i < numMetaData; ++i)
  {
    VarList::push_back(metaData, text_ptr[i].key, text_ptr[i].text);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::png_read_data(const png_structp ctx,  // NOLINT
                               png_bytep area, png_size_t size)
{
  (static_cast<std::ifstream*>(png_get_io_ptr(ctx)))->read(
    reinterpret_cast<char *>(area), size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::png_write_data(const png_structp ctx,  // NOLINT
                                png_bytep area, png_size_t size)
{
  (static_cast<std::ofstream*>(png_get_io_ptr(ctx)))->write(
    reinterpret_cast<const char *>(area), size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::png_io_flush(const png_structp ctx)  // NOLINT
{
  (static_cast<std::ofstream*>(png_get_io_ptr(ctx)))->flush();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::png_user_warn(const png_structp ctx,  // NOLINT
                               png_const_charp str)
{
  throw runtime_error(string("PNGLibrary warning: ") + str);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PNGLibrary::png_user_error(const png_structp ctx,  // NOLINT
                                png_const_charp str)
{
  throw runtime_error(string("PNGLibrary error: ") + str);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PNGLibrary::ReadInfoType PNGLibrary::ReadInfo;

#endif  // IMAGE_SUPPORT
