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

#ifndef PNGLIBRARY_HXX
#define PNGLIBRARY_HXX

#include <png.h>

class OSystem;
class FBSurface;

/**
  This class implements a thin wrapper around the libpng library, and
  abstracts all the irrelevant details other loading and saving an
  actual image.

  @author  Stephen Anthony
*/
class PNGLibrary
{
  public:
    explicit PNGLibrary(OSystem& osystem);

    /**
      Read a PNG image from the specified file into a FBSurface structure,
      scaling the image to the surface bounds.

      @param filename  The filename to load the PNG image
      @param surface   The FBSurface into which to place the PNG data
      @param metaData  The meta data of the PNG image

      @post  On success, the FBSurface containing image data, otherwise a
             runtime_error is thrown containing a more detailed
             error message.
    */
    void loadImage(const string& filename, FBSurface& surface,
                   VariantList& metaData);

    /**
      Save the current FrameBuffer image to a PNG file.  Note that in most
      cases this will be a TIA image, but it could actually be used for
      *any* mode.

      @param filename  The filename to save the PNG image
      @param metaData  The meta data s to add to the PNG image

      @post  On success, the PNG file has been saved to 'filename',
             otherwise a runtime_error is thrown containing a
             more detailed error message.
    */
    void saveImage(const string& filename,
                   const VariantList& metaData = VariantList{});

    /**
      Save the given surface to a PNG file.

      @param filename  The filename to save the PNG image
      @param surface   The surface data for the PNG image
      @param rect      The area of the surface to use
      @param metaData  The meta data to add to the PNG image

      @post  On success, the PNG file has been saved to 'filename',
             otherwise a runtime_error is thrown containing a
             more detailed error message.
    */
    static void saveImage(const string& filename, const FBSurface& surface,
                          const Common::Rect& rect = Common::Rect{},
                          const VariantList& metaData = VariantList{});

    /**
      Called at regular intervals, and used to determine whether a
      continuous snapshot is due to be taken.

      @param time  The current time in microseconds
    */
    void updateTime(uInt64 time);

    /**
      Answer whether continuous snapshot mode is enabled.
    */
    bool continuousSnapEnabled() const { return mySnapInterval > 0; }

    /**
      Enable/disable continuous snapshot mode.

      @param perFrame  Toggle snapshots every frame, or that specified by
                       'ssinterval' setting.
    */
    void toggleContinuousSnapshots(bool perFrame);

    /**
      Set the number of seconds between taking a snapshot in
      continuous snapshot mode.  Setting an interval of 0 disables
      continuous snapshots.

      @param interval  Interval in seconds between snapshots
    */
    void setContinuousSnapInterval(uInt32 interval);

    /**
      NOTE: This method will be made private soon, so all calls from
            external code should be refactored

      Create a new snapshot based on the name of the ROM, and also
      optionally using the number given as a parameter.

      @param number  Optional number to append to the snapshot name
    */
    void takeSnapshot(uInt32 number = 0);

  private:
    // Global OSystem object
    OSystem& myOSystem;

    // Used for continuous snapshot mode
    uInt32 mySnapInterval{0};
    uInt32 mySnapCounter{0};

    // The following data remains between invocations of allocateStorage,
    // and is only changed when absolutely necessary.
    struct ReadInfoType {
      vector<png_byte> buffer;
      vector<png_bytep> row_pointers;
      png_uint_32 width{0}, height{0}, pitch{0};
    };
    static ReadInfoType ReadInfo;

    /**
      Allocate memory for PNG read operations.  This is used to provide a
      basic memory manager, so that we don't constantly allocate and deallocate
      memory for each image loaded.

      The method fills the 'ReadInfo' struct with valid memory locations
      dependent on the given dimensions.  If memory has been previously
      allocated and it can accommodate the given dimensions, it is used directly.

      @param width   The width of the PNG image
      @param height  The height of the PNG image
    */
    static bool allocateStorage(size_t width, size_t height, bool hasAlpha);

    /** The actual method which saves a PNG image.

      @param out       The output stream for writing PNG data
      @param rows      Pointer into PNG RGB data for each row
      @param width     The width of the PNG image
      @param height    The height of the PNG image
      @param metaData  The meta data to add to the PNG image
    */
    static void saveImageToDisk(std::ofstream& out, const vector<png_bytep>& rows,
                                size_t width, size_t height,
                                const VariantList& metaData);

    /**
      Load the PNG data from 'ReadInfo' into the FBSurface.  The surface
      is resized as necessary to accommodate the data.

      @param surface  The FBSurface into which to place the PNG data
    */
    void loadImagetoSurface(FBSurface& surface, bool hasAlpha);

    /**
      Write PNG tEXt chunks to the image.
    */
    static void writeMetaData(const png_structp png_ptr, png_infop info_ptr,
                              const VariantList& metaData);

    /**
      Read PNG tEXt chunks from the image.
    */
    static void readMetaData(const png_structp png_ptr, png_infop info_ptr,
                             VariantList& metaData);

    /** PNG library callback functions */
    static void png_read_data(const png_structp ctx, png_bytep area,
                              png_size_t size);
    static void png_write_data(const png_structp ctx, png_bytep area,
                               png_size_t size);
    static void png_io_flush(const png_structp ctx);
    [[noreturn]] static void png_user_warn(const png_structp ctx,
                                           png_const_charp str);
    [[noreturn]] static void png_user_error(const png_structp ctx,
                                            png_const_charp str);

  private:
    // Following constructors and assignment operators not supported
    PNGLibrary() = delete;
    PNGLibrary(const PNGLibrary&) = delete;
    PNGLibrary(PNGLibrary&&) = delete;
    PNGLibrary& operator=(const PNGLibrary&) = delete;
    PNGLibrary& operator=(PNGLibrary&&) = delete;
};

#endif

#endif  // IMAGE_SUPPORT
