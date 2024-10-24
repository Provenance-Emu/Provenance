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
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "DispatchResult.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DispatchResult::isSuccess() const
{
  return myStatus == Status::debugger || myStatus == Status::ok;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DispatchResult::setOk(uInt64 cycles)
{
  myStatus = Status::ok;
  myCycles = cycles;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DispatchResult::setDebugger(uInt64 cycles, string_view message,
                                 string_view tooltip, int address,
                                 bool wasReadTrap)
{
  myStatus = Status::debugger;
  myCycles = cycles;
  myMessage = message;
  myToolTip = tooltip;
  myAddress = address;
  myWasReadTrap = wasReadTrap;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DispatchResult::setFatal(uInt64 cycles)
{
  myCycles = cycles;

  myStatus = Status::fatal;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DispatchResult::setMessage(string_view message)
{
  myMessage = message;
}
