//============================================================================
//
// MM     MM  6666  555555  0000   2222
// MMMM MMMM 66  66 55     00  00 22  22
// MM MMM MM 66     55     00  00     22
// MM  M  MM 66666  55555  00  00  22222  --  "A 6502 Microprocessor Emulator"
// MM     MM 66  66     55 00  00 22
// MM     MM 66  66 55  55 00  00 22
// MM     MM  6666   5555   0000  222222
//
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef NULLDEVICE_HXX
#define NULLDEVICE_HXX

class System;

#include "bspf.hxx"
#include "Device.hxx"

/**
  Class that represents a "null" device.  The basic idea is that a
  null device is installed in a 6502 based system anywhere there are
  holes in the address space (i.e. no real device attached).

  @author  Bradford W. Mott
*/
class NullDevice : public Device
{
  public:
    NullDevice() = default;
    ~NullDevice() override = default;

  public:
    /**
      Install device in the specified system.  Invoked by the system
      when the device is attached to it.

      @param system The system the device should install itself in
    */
    void install(System& system) override { mySystem = &system; }

    /**
      Reset device to its power-on state
    */
    void reset() override { }

    /**
      Save the current state of this device to the given Serializer.

      @param out  The Serializer object to use
      @return  False on any errors, else true
    */
    bool save(Serializer& out) const override { return true; }

    /**
      Load the current state of this device from the given Serializer.

      @param in  The Serializer object to use
      @return  False on any errors, else true
    */
    bool load(Serializer& in) override { return true; }

  public:
    /**
      Get the byte at the specified address

      @return The byte at the specified address
    */
    uInt8 peek(uInt16 address) override {
      cerr << "NullDevice: peek(" << address << ")\n";
      return 0;
    }

    /**
      Change the byte at the specified address to the given value

      @param address The address where the value should be stored
      @param value The value to be stored at the address

      @return  True if the poke changed the device address space, else false
    */
    bool poke(uInt16 address, uInt8 value) override {
      cerr << "NullDevice: poke(" << address << "," << value << ")\n";
      return false;
    }

  private:
    // Following constructors and assignment operators not supported
    NullDevice(const NullDevice&) = delete;
    NullDevice(NullDevice&&) = delete;
    NullDevice& operator=(const NullDevice&) = delete;
    NullDevice& operator=(NullDevice&&) = delete;
};

#endif
