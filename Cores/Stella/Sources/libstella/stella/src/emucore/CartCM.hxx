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

#ifndef CARTRIDGECM_HXX
#define CARTRIDGECM_HXX

class CompuMate;
class System;

#include "bspf.hxx"
#include "Cart.hxx"
#ifdef DEBUGGER_SUPPORT
  #include "CartCMWidget.hxx"
#endif

/**
  FIXME: This scheme is not yet fully implemented.  In particular, loading
         from and saving to the cassette is completely missing.

  Cartridge class used for SpectraVideo CompuMate bankswitched games.

  This is more than just a cartridge mapper - it's also a "computer" add-on.
  There's two 8K EPROMs soldered on top of each other.  There's two short
  wires with DB-9's on them which you plug into the two controller ports.
  A 42 or so key membrane keyboard with audio in and audio out, and 2K of RAM.

  There are 4 4K banks selectable at $1000 - $1FFF, and 2K RAM at
  $1800 - $1FFF (R/W 'line' is available at SWCHA D5, so there's no separate
  read and write ports).

  Bankswitching is done though the controller ports
    SWCHA: D7 = Audio input from tape player
           D6 = Audio out to tape player and 4017 CLK
                1 -> increase key column (0 to 9)
           D5 = 4017 RST, and RAM direction. (high = write, low = read)
                1 -> reset key column to 0 (if D4 = 0)
                0 -> enable RAM writing (if D4 = 1)
           D4 = RAM enable: 1 = disable RAM, 0 = enable RAM
           D3 = keyboard row 3 input (0 = key pressed)
           D2 = keyboard row 1 input (0 = key pressed)
           D1 = bank select high bit
           D0 = bank select low bit

    INPT0: D7 = FUNC key input (0 on startup / 1 = key pressed)
    INPT1: D7 = always HIGH input (pulled high thru 20K resistor)
    INPT2: D7 = always HIGH input (pulled high thru 20K resistor)
    INPT3: D7 = SHIFT key input (0 on startup / 1 = key pressed)
    INPT4: D7 = keyboard row 0 input (0 = key pressed)
    INPT5: D7 = keyboard row 2 input (0 = key pressed)

  The keyboard's composed of a 4017 1 of 10 counter, driving the 10 columns of
  the keyboard.  It has 4 rows.  The 4 row outputs are buffered by inverters.

  Bit 5 of portA controls the reset line on the 4017.  Pulling it high will reset
  scanning to column 0.  Pulling it low will allow the counter to be clocked.

  Bit 6 of portA clocks the 4017.  Each rising edge advances the column one
  count.

  There's 10 columns labelled 0-9, and 4 rows, labelled 0-3.

                           Column

    0     1     2     3     4     5     6     7     8     9
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+
  | 7 | | 6 | | 8 | | 2 | | 3 | | 0 | | 9 | | 5 | | 1 | | 4 |  0
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+
  | U | | Y | | I | | W | | E | | P | | O | | T | | Q | | R |  1
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+     Row
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+
  | J | | H | | K | | S | | D | |ent| | L | | G | | A | | F |  2
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+
  | M | | N | | < | | X | | C | |spc| | > | | B | | Z | | V |  3
  +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+

  Function and Shift are separate keys that are read by 2 of the paddle inputs.
  These two buttons pull the specific paddle input low when pressed.

  Because the inputs are inverted, a low indicates a pressed button, and a high
  is an unpressed one.

  The audio input/output are designed to drive a tape player.  The audio output is
  buffered through an inverter and 2 resistors and a capacitor to reduce the level
  to feed it into the tape player.

  The audio input is passed through a .1uf capacitor and is pulled to 1/2 supply
  by two 20K resistors, then it goes through a hex inverting schmitt trigger to
  square it up.  This then runs into bit 7 of portA.

  This code was heavily borrowed from z26.

  @author  Stephen Anthony & z26 team
*/
class CartridgeCM : public Cartridge
{
  friend class CartridgeCMWidget;

  public:
    /**
      Create a new cartridge using the specified image

      @param image     Pointer to the ROM image
      @param size      The size of the ROM image
      @param md5       The md5sum of the ROM image
      @param settings  A reference to the various settings (read-only)
    */
    CartridgeCM(const ByteBuffer& image, size_t size, string_view md5,
                const Settings& settings);
    ~CartridgeCM() override = default;

  public:
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
      Install pages for the specified bank in the system.

      @param bank     The bank that should be installed in the system
      @param segment  The segment the bank should be using

      @return  true, if bank has changed
    */
    bool bank(uInt16 bank, uInt16 segment = 0) override;

    /**
      Get the current bank.

      @param address The address to use when querying the bank
    */
    uInt16 getBank(uInt16 address = 0) const override;

    /**
      Query the number of banks supported by the cartridge.
    */
    uInt16 romBankCount() const override;

    /**
      Patch the cartridge ROM.

      @param address  The ROM address to patch
      @param value    The value to place into the address
      @return    Success or failure of the patch operation
    */
    bool patch(uInt16 address, uInt8 value) override;

    /**
      Access the internal ROM image for this cartridge.

      @param size  Set to the size of the internal ROM image data
      @return  A reference to the internal ROM image data
    */
    const ByteBuffer& getImage(size_t& size) const override;

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
    string name() const override { return "CartridgeCM"; }

  #ifdef DEBUGGER_SUPPORT
    /**
      Get debugger widget responsible for accessing the inner workings
      of the cart.
    */
    CartDebugWidget* debugWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w, int h) override
    {
      return new CartridgeCMWidget(boss, lfont, nfont, x, y, w, h, *this);
    }
  #endif

  public:
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
      Inform the cartridge about the parent CompuMate controller
    */
    void setCompuMate(const shared_ptr<CompuMate>& cmate) { myCompuMate = cmate; }

    /**
      Get the current keyboard column

      @return The column referenced by SWCHA D6 and D5
    */
    uInt8 column() const;

  private:
    // The CompuMate device which interacts with this cartridge
    shared_ptr<CompuMate> myCompuMate;

    // The 16K ROM image of the cartridge
    ByteBuffer myImage;

    // The 2K of RAM
    std::array<uInt8, 2_KB> myRAM{0};

    // Current copy of SWCHA (controls ROM/RAM accesses)
    uInt8 mySWCHA{0xFF};  // Port A all 1's

    // Indicates the offset into the ROM image (aligns to current bank)
    uInt16 myBankOffset{0};

  private:
    // Following constructors and assignment operators not supported
    CartridgeCM() = delete;
    CartridgeCM(const CartridgeCM&) = delete;
    CartridgeCM(CartridgeCM&&) = delete;
    CartridgeCM& operator=(const CartridgeCM&) = delete;
    CartridgeCM& operator=(CartridgeCM&&) = delete;
};

#endif
