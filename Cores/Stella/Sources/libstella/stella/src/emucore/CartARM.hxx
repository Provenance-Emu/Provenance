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

#ifndef CARTRIDGE_ARM_HXX
#define CARTRIDGE_ARM_HXX

#include "Thumbulator.hxx"
#include "PlusROM.hxx"
#include "Cart.hxx"

/**
  Abstract base class for ARM carts.

  @author  Thomas Jentzsch
*/
class CartridgeARM : public Cartridge
{
  friend class CartridgeARMWidget;

  public:
    CartridgeARM(const Settings& settings, string_view md5);
    ~CartridgeARM() override = default;

    /**
      Reset device to its power-on state
    */
    void reset() override;

  protected:
    /**
      Notification method invoked by the system when the console type
      has changed.  We need this to inform the Thumbulator that the
      timing has changed.

      @param timing  Enum representing the new console type
    */
    void consoleChanged(ConsoleTiming timing) override;

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
      Sets the initial state of the MAM mode
    */
    virtual void setInitialState();

    void enableCycleCount(bool enable) const { myThumbEmulator->enableCycleCount(enable); }
    // Get number of memory accesses of last and last but one ARM runs.
    void updateCycles(int cycles);
  #ifdef DEBUGGER_SUPPORT
    const Thumbulator::Stats& stats() const { return myStats; }
    const Thumbulator::Stats& prevStats() const { return myPrevStats; }
    uInt32 cycles() const { return myCycles; }
    uInt32 prevCycles() const { return myPrevCycles; }
  #endif

    void incCycles(bool enable);
    void cycleFactor(double factor);
    double cycleFactor() const { return myThumbEmulator->cycleFactor(); }
    Thumbulator::ChipPropsType setChipType(Thumbulator::ChipType chipType) {
      return myThumbEmulator->setChipType(chipType);
    }
    void lockMamMode(bool lock) { myThumbEmulator->lockMamMode(lock); }
    void setMamMode(Thumbulator::MamModeType mamMode) { myThumbEmulator->setMamMode(mamMode); }
    Thumbulator::MamModeType mamMode() const { return myThumbEmulator->mamMode(); }

    /**
      Set the callback for displaying messages
    */
    void setMessageCallback(const messageCallback& callback) override
    {
      Cartridge::setMessageCallback(callback);
      if(myPlusROM->isValid())
        myPlusROM->setMessageCallback(myMsgCallback);
    }

  protected:
    // Pointer to the Thumb ARM emulator object
    unique_ptr<Thumbulator> myThumbEmulator;

    // Handle PlusROM functionality, if available
    unique_ptr<PlusROM> myPlusROM;

    // ARM code increases 6507 cycles
    bool myIncCycles{false};

    // Console clock rate
    double myClockRate{1193191.66666667};
  #ifdef DEBUGGER_SUPPORT
    Thumbulator::Stats myStats{0};
    Thumbulator::Stats myPrevStats{0};
    uInt32 myCycles{0};
    uInt32 myPrevCycles{0};
  #endif

  private:
    // Following constructors and assignment operators not supported
    CartridgeARM() = delete;
    CartridgeARM(const CartridgeARM&) = delete;
    CartridgeARM(CartridgeARM&&) = delete;
    CartridgeARM& operator=(const CartridgeARM&) = delete;
    CartridgeARM& operator=(CartridgeARM&&) = delete;
};

#endif
