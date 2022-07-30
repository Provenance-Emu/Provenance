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

#ifndef TIA_LATCHED_INPUT
#define TIA_LATCHED_INPUT

#include "bspf.hxx"
#include "Serializable.hxx"

class LatchedInput : public Serializable
{
  public:
    LatchedInput() = default;

  public:

    void reset();

    void vblank(uInt8 value);
    bool vblankLatched() const { return myModeLatched; }

    uInt8 inpt(bool pinState);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

  private:
    bool myModeLatched{false};
    uInt8 myLatchedValue{0};

  private:
    LatchedInput(const LatchedInput&) = delete;
    LatchedInput(LatchedInput&&) = delete;
    LatchedInput& operator=(const LatchedInput&) = delete;
    LatchedInput& operator=(LatchedInput&&) = delete;
};

#endif // TIA_LATCHED_INPUT
