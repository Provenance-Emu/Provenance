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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef CARTRIDGE_DETECTOR_HXX
#define CARTRIDGE_DETECTOR_HXX

#include "Bankswitch.hxx"
#include "FSNode.hxx"
#include "bspf.hxx"

/**
  Auto-detect cart type based on various attributes (file size, signatures,
  filenames, etc)

  @author  Stephen Anthony
*/
class CartDetector
{
  public:
    /**
      Try to auto-detect the bankswitching type of the cartridge

      @param image  A pointer to the ROM image
      @param size   The size of the ROM image

      @return The "best guess" for the cartridge type
    */
    static Bankswitch::Type autodetectType(const ByteBuffer& image, size_t size);

    /**
      MVC cartridges are of arbitary large length
      Returns size of frame if stream is probably an MVC movie cartridge
    */
    static size_t isProbablyMVC(const FSNode& rom);

    /**
      Returns true if the image is probably a HSC PlusROM
    */
    static bool isProbablyPlusROM(const ByteBuffer& image, size_t size);

  private:
    /**
      Search the image for the specified byte signature

      @param image      A pointer to the ROM image
      @param imagesize  The size of the ROM image
      @param signature  The byte sequence to search for
      @param sigsize    The number of bytes in the signature
      @param minhits    The minimum number of times a signature is to be found

      @return  True if the signature was found at least 'minhits' time, else false
    */
    static bool searchForBytes(const uInt8* image, size_t imagesize,
                               const uInt8* signature, uInt32 sigsize,
                               uInt32 minhits = 1);

    static bool searchForBytes(const ByteBuffer& image, size_t imagesize,
                               const uInt8* signature, uInt32 sigsize,
                               uInt32 minhits = 1)
    {
      return searchForBytes(image.get(), imagesize, signature, sigsize, minhits);
    }

    /**
      Returns true if the image is probably a SuperChip (128 bytes RAM)
      Note: should be called only on ROMs with size multiple of 4K
    */
    static bool isProbablySC(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image probably contains ARM code in the first 1K
    */
    static bool isProbablyARM(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a 0840 bankswitching cartridge
    */
    static bool isProbably0840(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a BRazilian bankswitching cartridge
    */
    static bool isProbably0FA0(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a 3E bankswitching cartridge
    */
    static bool isProbably3E(const ByteBuffer& image, size_t size);

    /**
    Returns true if the image is probably a 3EX bankswitching cartridge
    */
    static bool isProbably3EX(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a 3E+ bankswitching cartridge
    */
    static bool isProbably3EPlus(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a 3F bankswitching cartridge
    */
    static bool isProbably3F(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a 4A50 bankswitching cartridge
    */
    static bool isProbably4A50(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a 4K SuperChip (128 bytes RAM)
    */
    static bool isProbably4KSC(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a BF/BFSC bankswitching cartridge
    */
    static bool isProbablyBF(const ByteBuffer& image, size_t size, Bankswitch::Type& type);

    /**
      Returns true if the image is probably a BUS bankswitching cartridge
    */
    static bool isProbablyBUS(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a CDF bankswitching cartridge
    */
    static bool isProbablyCDF(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a CTY bankswitching cartridge
    */
    static bool isProbablyCTY(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a CV bankswitching cartridge
    */
    static bool isProbablyCV(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a DF/DFSC bankswitching cartridge
    */
    static bool isProbablyDF(const ByteBuffer& image, size_t size, Bankswitch::Type& type);

    /**
      Returns true if the image is probably a DPC+ bankswitching cartridge
    */
    static bool isProbablyDPCplus(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a E0 bankswitching cartridge
    */
    static bool isProbablyE0(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a E7 bankswitching cartridge
    */
    static bool isProbablyE7(const ByteBuffer& image, size_t size);

    /**
    Returns true if the image is probably a E78K bankswitching cartridge
    */
    static bool isProbablyE78K(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably an EF/EFSC bankswitching cartridge
    */
    static bool isProbablyEF(const ByteBuffer& image, size_t size, Bankswitch::Type& type);

    /**
      Returns true if the image is probably an F6 bankswitching cartridge
    */
    //static bool isProbablyF6(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably an FA2 bankswitching cartridge
    */
    static bool isProbablyFA2(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably an FC bankswitching cartridge
    */
    static bool isProbablyFC(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably an FE bankswitching cartridge
    */
    static bool isProbablyFE(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a MDM bankswitching cartridge
    */
    static bool isProbablyMDM(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably an MVC movie cartridge
    */
    static bool isProbablyMVC(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a SB bankswitching cartridge
    */
    static bool isProbablySB(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a TV Boy bankswitching cartridge
    */
    static bool isProbablyTVBoy(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a UA bankswitching cartridge
    */
    static bool isProbablyUA(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably a Wickstead Design bankswitching cartridge
    */
    static bool isProbablyWD(const ByteBuffer& image, size_t size);

    /**
      Returns true if the image is probably an X07 bankswitching cartridge
    */
    static bool isProbablyX07(const ByteBuffer& image, size_t size);

  private:
    // Following constructors and assignment operators not supported
    CartDetector() = delete;
    CartDetector(const CartDetector&) = delete;
    CartDetector(CartDetector&&) = delete;
    CartDetector& operator=(const CartDetector&) = delete;
    CartDetector& operator=(CartDetector&&) = delete;
};

#endif
