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

#ifndef CARTRIDGETVBOY_HXX
#define CARTRIDGETVBOY_HXX

#include "bspf.hxx"
#include "CartEnhanced.hxx"
#include "System.hxx"
#ifdef DEBUGGER_SUPPORT
#include "CartTVBoyWidget.hxx"
#endif

/**
  Cartridge class used for TV Boy
  There are 128 4K banks, accessing $F800..$F87F selects bank and locks any
  further bankswitching.

  @author  Thomas Jentzsch
*/
class CartridgeTVBoy : public CartridgeEnhanced
{
  friend class CartridgeTVBoyWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
      @param bsSize    The size specified by the bankswitching scheme
    */
    CartridgeTVBoy(const ByteBuffer& image, size_t size, string_view md5,
                 const Settings& settings, size_t bsSize = 512_KB);
    ~CartridgeTVBoy() override = default;

  public:
    /**
      Install pages for the specified bank in the system.

      @param bank     The bank that should be installed in the system
      @param segment  The segment the bank should be using

      @return  true, if bank has changed
    */
    bool bank(uInt16 bank, uInt16 segment = 0) override;

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

    /**
      Get a descriptor for the device name (used in error checking).

      @return The name of the object
    */
    string name() const override { return "CartridgeTVBoy"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
                                 const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeTVBoyWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  private:
    bool checkSwitchBank(uInt16 address, uInt8 value) override;

    uInt16 hotspot() const override { return 0x1800; }

  private:
    // Indicates whether banking has been disabled due to a bankswitch
    bool myBankingDisabled{false};

  private:
    // Following constructors and assignment operators not supported
    CartridgeTVBoy() = delete;
    CartridgeTVBoy(const CartridgeTVBoy&) = delete;
    CartridgeTVBoy(CartridgeTVBoy&&) = delete;
    CartridgeTVBoy& operator=(const CartridgeTVBoy&) = delete;
    CartridgeTVBoy& operator=(CartridgeTVBoy&&) = delete;
};

#endif
