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

#ifndef CARTRIDGEFC_HXX
#define CARTRIDGEFC_HXX

class System;

#include "bspf.hxx"
#include "CartEnhanced.hxx"

#ifdef DEBUGGER_SUPPORT
  #include "CartFCWidget.hxx"
#endif

/**
  Cartridge class used for Amiga's 32K Power Play Arcade Video Game Album.
  There are eight 4K banks, writing to $1FF8 definies the two lowest bits
  of the wanted bank, writeing to $1FF9 defines the high bits. Accessing
  $1FFC triggers the bank switching

  @author  Thomas Jentzsch
*/
class CartridgeFC : public CartridgeEnhanced
{
  friend class CartridgeFCWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
                       (where 0 means variable-sized ROM)
    */
    CartridgeFC(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings, size_t bsSize = 0);
    ~CartridgeFC() override = default;

  public:
    /**
      Reset device to its power-on state
    */
    void reset() override;

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeFC"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
                                 const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeFCWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  public:
    /**
      Change the byte at the specified address to the given value

      @param address The address where the value should be stored
      @param value The value to be stored at the address
      @return  True if the poke changed the device address space, else false
    */
    bool poke(uInt16 address, uInt8 value) override;

  private:
    bool checkSwitchBank(uInt16 address, uInt8) override;

    uInt16 hotspot() const override { return 0x1FF8; }

    // Target bank defined by writing to $1FF8/9
    uInt16 myTargetBank{0};

  private:
    // Following constructors and assignment operators not supported
    CartridgeFC() = delete;
    CartridgeFC(const CartridgeFC&) = delete;
    CartridgeFC(CartridgeFC&&) = delete;
    CartridgeFC& operator=(const CartridgeFC&) = delete;
    CartridgeFC& operator=(CartridgeFC&&) = delete;
};

#endif
