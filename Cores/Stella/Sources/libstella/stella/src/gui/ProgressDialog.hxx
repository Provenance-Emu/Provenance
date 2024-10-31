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

#ifndef PROGRESS_DIALOG_HXX
#define PROGRESS_DIALOG_HXX

class GuiObject;
class StaticTextWidget;
class SliderWidget;
class ButtonWidget;

#include "bspf.hxx"
#include "Dialog.hxx"

class ProgressDialog : public Dialog
{
  public:
    ProgressDialog(GuiObject* boss, const GUI::Font& font,
                   string_view message = "");
    ~ProgressDialog() override = default;

    void setMessage(string_view message);
    void setRange(int start, int finish, int step);
    void resetProgress();
    void setProgress(int progress);
    void incProgress();
    bool isCancelled() const { return myIsCancelled; }

  private:
    StaticTextWidget* myMessage{nullptr};
    SliderWidget*     mySlider{nullptr};

    int myStart{0}, myFinish{0}, myStep{0};
    int myProgress{0};
    uInt64 myLastTick{0};
    bool myIsCancelled{false};

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    // Following constructors and assignment operators not supported
    ProgressDialog() = delete;
    ProgressDialog(const ProgressDialog&) = delete;
    ProgressDialog(ProgressDialog&&) = delete;
    ProgressDialog& operator=(const ProgressDialog&) = delete;
    ProgressDialog& operator=(ProgressDialog&&) = delete;
};

#endif
