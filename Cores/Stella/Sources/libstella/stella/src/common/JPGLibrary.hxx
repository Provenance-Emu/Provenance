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

#ifndef JPG_LIBRARY_HXX
#define JPG_LIBRARY_HXX

class OSystem;
class FBSurface;

/**
  This class implements a thin wrapper around the nanojpeg library, and
  abstracts all the irrelevant details other loading an actual image.

  @author  Thomas Jentzsch
*/
class JPGLibrary
{
  public:
    explicit JPGLibrary(OSystem& osystem);

    /**
      Read a JPG image from the specified file into a FBSurface structure,
      scaling the image to the surface bounds.

      @param filename  The filename to load the JPG image
      @param surface   The FBSurface into which to place the JPG data
      @param metaData  The meta data of the JPG image

      @post  On success, the FBSurface containing image data, otherwise a
             runtime_error is thrown containing a more detailed
             error message.
    */
    void loadImage(const string& filename, FBSurface& surface,
                   VariantList& metaData);

  private:
    // Global OSystem object
    OSystem& myOSystem;

    // The following data remains between invocations of allocateStorage,
    // and is only changed when absolutely necessary.
    struct ReadInfoType {
      unsigned char* buffer{nullptr};
      uInt32 width{0}, height{0}, pitch{0};
    };
    ReadInfoType myReadInfo;
    static std::vector<char> myFileBuffer;

    /**
      Load the JPG data from 'ReadInfo' into the FBSurface.  The surface
      is resized as necessary to accommodate the data.

      @param surface  The FBSurface into which to place the JPG data
    */
    void loadImagetoSurface(FBSurface& surface);

    /**
      Read EXIF meta data chunks from the image.

      @param filename  The filename to load the JPG image
      @param metaData  The meta data of the JPG image
    */
    static void readMetaData(const string& filename, VariantList& metaData);

  private:
    // Following constructors and assignment operators not supported
    JPGLibrary() = delete;
    JPGLibrary(const JPGLibrary&) = delete;
    JPGLibrary(JPGLibrary&&) = delete;
    JPGLibrary& operator=(const JPGLibrary&) = delete;
    JPGLibrary& operator=(JPGLibrary&&) = delete;
};

#endif

#endif  // IMAGE_SUPPORT
