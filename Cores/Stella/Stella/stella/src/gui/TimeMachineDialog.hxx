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

#ifndef TIME_MACHINE_DIALOG_HXX
#define TIME_MACHINE_DIALOG_HXX

class CommandSender;
class DialogContainer;
class OSystem;
class TimeLineWidget;

#include "Dialog.hxx"

class TimeMachineDialog : public Dialog
{
  public:
    TimeMachineDialog(OSystem& osystem, DialogContainer& parent, int width);
    ~TimeMachineDialog() override = default;

    /** set/get number of winds when entering the dialog */
    void setEnterWinds(Int32 numWinds) { _enterWinds = numWinds; }
    Int32 getEnterWinds() const { return _enterWinds; }

  private:
    void loadConfig() override;
    void handleKeyDown(StellaKey key, StellaMod mod, bool repeated) override;
    void handleKeyUp(StellaKey key, StellaMod mod) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    /** initialize timeline bar */
    void initBar();

    /** This dialog uses its own positioning, so we override Dialog::setPosition() */
    void setPosition() override;

    /** convert cycles into time */
    string getTimeString(uInt64 cycles) const;
    /** re/unwind and update display */
    void handleWinds(Int32 numWinds = 0);
    /** toggle Time Machine mode */
    void handleToggle();

  private:
    enum
    {
      kTimeline  = 'TMtl',
      kToggle    = 'TMtg',
      kExit      = 'TMex',
      kPlayBack  = 'TMpb',
      kRewindAll = 'TMra',
      kRewind10  = 'TMr1',
      kRewind1   = 'TMre',
      kUnwindAll = 'TMua',
      kUnwind10  = 'TMu1',
      kUnwind1   = 'TMun',
      kSaveAll   = 'TMsv',
      kLoadAll   = 'TMld',
    };

    TimeLineWidget* myTimeline{nullptr};

    ButtonWidget* myToggleWidget{nullptr};
    ButtonWidget* myExitWidget{ nullptr };
    ButtonWidget* myPlayBackWidget{nullptr};
    ButtonWidget* myRewindAllWidget{nullptr};
    ButtonWidget* myRewind1Widget{nullptr};
    ButtonWidget* myUnwind1Widget{nullptr};
    ButtonWidget* myUnwindAllWidget{nullptr};
    ButtonWidget* mySaveAllWidget{nullptr};
    ButtonWidget* myLoadAllWidget{nullptr};

    StaticTextWidget* myCurrentTimeWidget{nullptr};
    StaticTextWidget* myLastTimeWidget{nullptr};

    StaticTextWidget* myCurrentIdxWidget{nullptr};
    StaticTextWidget* myLastIdxWidget{nullptr};
    StaticTextWidget* myMessageWidget{nullptr};

    Int32 _enterWinds{0};

  private:
    // Following constructors and assignment operators not supported
    TimeMachineDialog() = delete;
    TimeMachineDialog(const TimeMachineDialog&) = delete;
    TimeMachineDialog(TimeMachineDialog&&) = delete;
    TimeMachineDialog& operator=(const TimeMachineDialog&) = delete;
    TimeMachineDialog& operator=(TimeMachineDialog&&) = delete;
};

#endif
