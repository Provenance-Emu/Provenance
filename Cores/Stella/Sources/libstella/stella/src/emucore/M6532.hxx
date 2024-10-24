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

#ifndef M6532_HXX
#define M6532_HXX

class ConsoleIO;
class RiotDebug;
class System;
class Settings;

#include "bspf.hxx"
#include "Device.hxx"

/**
  This class models the M6532 RAM-I/O-Timer (aka RIOT) chip in the 2600
  console.  Note that since the M6507 CPU doesn't contain an interrupt line,
  the following functionality relating to the RIOT IRQ line is not emulated:

    - A3 to enable/disable interrupt from timer to IRQ
    - A1 to enable/disable interrupt from PA7 to IRQ

  @author  Bradford W. Mott and Stephen Anthony
*/
class M6532 : public Device
{
  public:
    /**
      The RIOT debugger class is a friend who needs special access
    */
    friend class RiotDebug;

  public:
    /**
      Create a new 6532 for the specified console

      @param console  The console the 6532 is associated with
      @param settings The settings used by the system
    */
    M6532(const ConsoleIO& console, const Settings& settings);
    ~M6532() override = default;

   public:
    /**
      Reset cartridge to its power-on state
    */
    void reset() override;

    /**
      Update the entire digital and analog pin state of ports A and B.
    */
    void update();

    /**
      Install 6532 in the specified system.  Invoked by the system
      when the 6532 is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override;

    /**
      Install 6532 in the specified system and device.  Invoked by
      the system when the 6532 is attached to it.  All devices
      which invoke this method take responsibility for chaining
      requests back to *this* device.

      @param system The system the device should install itself in
      @param device The device responsible for this address space
    */
    void installDelegate(System& system, Device& device);

    /**
      Save the current state of this device to the given Serializer.

      @param out  The Serializer object to use
      @return  False on any errors, else true
    */
    bool save(Serializer& out) const override;

    /**
      Load the current state of this device from the given Serializer.

      @param in  The Serializer object to use
      @return  False on any errors, else true
    */
    bool load(Serializer& in) override;

   public:
    /**
      Get the byte at the specified address

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
     * Update RIOT state to the current timestamp.
     */
    void updateEmulation();

    /**
      Get a pointer to the RAM contents.

      @return  Pointer to RAM array.
    */
    const uInt8* getRAM() const { return myRAM.data(); }

  #ifdef DEBUGGER_SUPPORT
    /**
      Query the access counters

      @return  The access counters as comma separated string
    */
    string getAccessCounters() const override;

    /**
      Reset the timer read CPU cycle counter
    */
    void resetTimReadCylces() { myTimReadCycles = 0; }
  #endif

  private:

    void setTimerRegister(uInt8 value, uInt8 interval);
    void setPinState(bool swcha);

  #ifdef DEBUGGER_SUPPORT
    // The following are used by the debugger to read INTIM/TIMINT
    // We need separate methods to do this, so the state of the system
    // isn't changed
    uInt8 intim();
    uInt8 timint();
    Int32 intimClocks();
    uInt32 timerClocks() const;

    void createAccessBases();

    /**
      Query the given address type for the associated access flags.

      @param address  The address to query
    */
    Device::AccessFlags getAccessFlags(uInt16 address) const override;
    /**
      Change the given address to use the given access flags.

      @param address  The address to modify
      @param flags    A bitfield of AccessType directives for the given address
    */
    void setAccessFlags(uInt16 address, Device::AccessFlags flags) override;

    /**
      Increase the given address's access counter

      @param address The address to modify
    */
    void increaseAccessCounter(uInt16 address, bool isWrite) override;
  #endif // DEBUGGER_SUPPORT

  private:
    // Reference to the console
    const ConsoleIO& myConsole;

    // Reference to the settings
    const Settings& mySettings;

    // An amazing 128 bytes of RAM
    std::array<uInt8, 128> myRAM;

    // Current value of the timer
    uInt8 myTimer{0};

    // Current number of clocks "queued" for the divider
    uInt32 mySubTimer{0};

    // The divider
    uInt32 myDivider{1};

    // Has the timer wrapped this very cycle?
    bool myWrappedThisCycle{false};

    // Cycle when the timer set. Debugging only.
    uInt64 mySetTimerCycle{0};

    // Last cycle considered in emu updates
    uInt64 myLastCycle{0};

    // Data Direction Register for Port A
    uInt8 myDDRA{0};

    // Data Direction Register for Port B
    uInt8 myDDRB{0};

    // Last value written to Port A
    uInt8 myOutA{0};

    // Last value written to Port B
    uInt8 myOutB{0};

    // Interrupt Flag Register
    uInt8 myInterruptFlag{0};

    // Used to determine whether an active transition on PA7 has occurred
    // True is positive edge-detect, false is negative edge-detect
    bool myEdgeDetectPositive{false};

    // Last value written to the timer registers
    std::array<uInt8, 4> myOutTimer{0};

    // Accessible bits in the interrupt flag register
    // All other bits are always zeroed
    static constexpr uInt8 TimerBit = 0x80, PA7Bit = 0x40;

#ifdef DEBUGGER_SUPPORT
    static constexpr uInt16
      RAM_SIZE = 0x80, RAM_MASK = RAM_SIZE - 1,
      STACK_SIZE = RAM_SIZE, STACK_MASK = RAM_MASK, STACK_BIT = 0x100,
      IO_SIZE = 0x20, IO_MASK = IO_SIZE - 1, IO_BIT = 0x200,
      ZP_DELAY = 1 * 2;

    // The arrays containing information about every byte of RIOT
    // indicating whether and how (RW) it is used.
    std::array<Device::AccessFlags, RAM_SIZE>   myRAMAccessBase;
    std::array<Device::AccessFlags, STACK_SIZE> myStackAccessBase;
    std::array<Device::AccessFlags, IO_SIZE>    myIOAccessBase;
    // The arrays containing information about every byte of RIOT
    // indicating how often it is accessed.
    std::array<Device::AccessCounter, RAM_SIZE * 2>   myRAMAccessCounter;
    std::array<Device::AccessCounter, STACK_SIZE * 2> myStackAccessCounter;
    std::array<Device::AccessCounter, IO_SIZE * 2>    myIOAccessCounter;
    // The array used to skip the first ZP access tracking
    std::array<uInt8, RAM_SIZE>   myZPAccessDelay;

    // Detect timer being accessed on wraparound
    bool myTimWrappedOnRead{false};
    bool myTimWrappedOnWrite{false};
    // Timer read CPU cycles
    uInt16 myTimReadCycles{0};
#endif // DEBUGGER_SUPPORT

  private:
    // Following constructors and assignment operators not supported
    M6532() = delete;
    M6532(const M6532&) = delete;
    M6532(M6532&&) = delete;
    M6532& operator=(const M6532&) = delete;
    M6532& operator=(M6532&&) = delete;
};

#endif
