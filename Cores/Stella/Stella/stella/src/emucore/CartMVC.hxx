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

#ifndef CARTRIDGEMVC_HXX
#define CARTRIDGEMVC_HXX

class System;
class MovieCart;

#include "bspf.hxx"
#include "Cart.hxx"

/**
  Implementation of MovieCart.
  1K of memory is presented on the bus, but is repeated to fill the 4K image space.
  Contents are dynamically altered with streaming image and audio content as specific
  128-byte regions are entered.
  Original implementation: github.com/lodefmode/moviecart

  @author  Rob Bairos
*/
class CartridgeMVC : public Cartridge
{
  public:
    static constexpr uInt32
      MVC_FIELD_SIZE     = 2560,  // round field to nearest 512 byte boundary
      MVC_FIELD_PAD_SIZE = 4096;  // round to nearest 4K

  public:
    /**
      Create a new cartridge using the specified image

      @param path      Path to the ROM image file
      @param size      The size of the ROM image (<= 2048 bytes)
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeMVC(const string& path, size_t size, const string& md5,
                 const Settings& settings, size_t bsSize = 8_KB);
    ~CartridgeMVC() override;

    /**
      Reset device to its power-on state
    */
    void reset() override;

    /**
      Install cartridge in the specified system.  Invoked by the system
      when the cartridge is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override;

    /**
      Access the internal ROM image for this cartridge.

      @param size  Set to the size of the internal ROM image data
      @return  A reference to the internal ROM image data
    */
    const ByteBuffer& getImage(size_t& size) const override;

    /**
      Patch the cartridge ROM.

      @param address  The ROM address to patch
      @param value    The value to place into the address
      @return    Success or failure of the patch operation
    */
    bool patch(uInt16 address, uInt8 value) override;

    /**
      Get the byte at the specified address.

      @return The byte at the specified address
    */
    uInt8 peek(uInt16 address) override;

    /**
      Change the byte at the specified address to the given value

      @param address The address where the value should be stored
      @param value The value to be stored at the address
      @return  True if the poke changed the device address space, else false
    */
    bool poke(uInt16 address, uInt8 value) override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeMVC"; }

    /**
      Save the current state of this cart to the given Serializer.

      @param out  The Serializer object to use
      @return  False on any errors, else true
    */
    bool save(Serializer& out) const override;

    /**
      Load the current state of this cart from the given Serializer.

      @param in  The Serializer object to use
      @return  False on any errors, else true
    */
    bool load(Serializer& in) override;

  private:
    // Currently not used:
    // Pointer to a dynamically allocated ROM image of the cartridge
    ByteBuffer myImage{nullptr};
    size_t mySize{0};

    unique_ptr<MovieCart> myMovie;
    string myPath;

  private:
    // Following constructors and assignment operators not supported
    CartridgeMVC() = delete;
    CartridgeMVC(const CartridgeMVC&) = delete;
    CartridgeMVC(CartridgeMVC&&) = delete;
    CartridgeMVC& operator=(const CartridgeMVC&) = delete;
    CartridgeMVC& operator=(CartridgeMVC&&) = delete;
};

#endif
