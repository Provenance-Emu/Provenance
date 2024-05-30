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

#ifndef DISPATCH_RESULT_HXX
#define DISPATCH_RESULT_HXX

#include "bspf.hxx"

class DispatchResult
{
  public:
    enum class Status { invalid, ok, debugger, fatal };

  public:

    Status getStatus() const { return myStatus; }

    uInt64 getCycles() const { return myCycles; }

    const string& getMessage() const {
      assertStatus(Status::debugger, Status::fatal);
      return myMessage;
    }

    int getAddress() const {
      assertStatus(Status::debugger);
      return myAddress;
    }

    bool wasReadTrap() const {
      assertStatus(Status::debugger);
      return myWasReadTrap;
    }

    const string& getToolTip() const {
      assertStatus(Status::debugger, Status::fatal);
      return myToolTip;
    }

    bool isSuccess() const;

    void setOk(uInt64 cycles);

    void setDebugger(uInt64 cycles, string_view message = "",
                     string_view tooltip = "", int address = -1,
                     bool wasReadTrap = true);

    void setFatal(uInt64 cycles);

    void setMessage(string_view message);

  private:

    void assertStatus(Status status) const {
      if (myStatus != status) throw runtime_error("invalid status for operation");
    }

    template<typename ...Ts> void assertStatus(Status status, Ts... more) const {
      if (myStatus == status) return;

      assertStatus(more...);
    }

  private:

    Status myStatus{Status::invalid};

    uInt64 myCycles{0};

    string myMessage;

    int myAddress{0};

    bool myWasReadTrap{false};

    string myToolTip;
};

#endif // DISPATCH_RESULT_HXX
