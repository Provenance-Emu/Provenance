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

#ifndef TIME_MACHINE_HXX
#define TIME_MACHINE_HXX

class OSystem;

#include "DialogContainer.hxx"

/**
  The base dialog for all time machine related UI items in Stella.

  @author  Stephen Anthony
*/
class TimeMachine : public DialogContainer
{
  public:
    explicit TimeMachine(OSystem& osystem);
    ~TimeMachine() override;

    /**
      This dialog has an adjustable size.  We need to make sure the
      dialog can fit within the given bounds.
    */
    void requestResize() override;

    /**
      Return (and possibly create) the bottom-most dialog of this container.
    */
    Dialog* baseDialog() override;

    /**
      Set number of winds when entering the dialog.
    */
    void setEnterWinds(Int32 numWinds);

  private:
    Dialog* myBaseDialog{nullptr};

    uInt32 myWidth{0};

  private:
    // Following constructors and assignment operators not supported
    TimeMachine() = delete;
    TimeMachine(const TimeMachine&) = delete;
    TimeMachine(TimeMachine&&) = delete;
    TimeMachine& operator=(const TimeMachine&) = delete;
    TimeMachine& operator=(TimeMachine&&) = delete;
};

#endif
