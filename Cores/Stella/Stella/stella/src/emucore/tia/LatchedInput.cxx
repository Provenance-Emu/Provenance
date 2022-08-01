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

#include "LatchedInput.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LatchedInput::reset()
{
  myModeLatched = false;
  myLatchedValue = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LatchedInput::vblank(uInt8 value)
{
  if (value & 0x40)
    myModeLatched = true;
  else {
    myModeLatched = false;
    myLatchedValue = 0x80;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 LatchedInput::inpt(bool pinState)
{
  uInt8 value = pinState ? 0 : 0x80;

  if (myModeLatched) {
    myLatchedValue &= value;
    value = myLatchedValue;
  }

  return value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool LatchedInput::save(Serializer& out) const
{
  try
  {
    out.putBool(myModeLatched);
    out.putByte(myLatchedValue);
  }
  catch(...)
  {
    cerr << "ERROR: TIA_LatchedInput::save" << endl;
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool LatchedInput::load(Serializer& in)
{
  try
  {
    myModeLatched = in.getBool();
    myLatchedValue = in.getByte();
  }
  catch(...)
  {
    cerr << "ERROR: TIA_LatchedInput::load" << endl;
    return false;
  }

  return true;
}
