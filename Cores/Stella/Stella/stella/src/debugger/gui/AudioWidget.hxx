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

#ifndef AUDIO_WIDGET_HXX
#define AUDIO_WIDGET_HXX

class GuiObject;
class DataGridWidget;

#include "Widget.hxx"
#include "Command.hxx"

class AudioWidget : public Widget, public CommandSender
{
  public:
    AudioWidget(GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
                int x, int y, int w, int h);
    ~AudioWidget() override = default;

  private:
    // ID's for the various widgets
    // We need ID's, since there are more than one of several types of widgets
    enum {
      kAUDFID,
      kAUDCID,
      kAUDVID
    };

    DataGridWidget*   myAudF{nullptr};
    StaticTextWidget* myAud0F{nullptr};
    StaticTextWidget* myAud1F{nullptr};
    DataGridWidget*   myAudC{nullptr};
    DataGridWidget*   myAudV{nullptr};
    StaticTextWidget* myAudEffV{nullptr};

    // Audio channels
    enum
    {
      kAud0Addr,
      kAud1Addr
    };

  private:
    void changeFrequencyRegs();
    void changeControlRegs();
    void changeVolumeRegs();
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void loadConfig() override;

    void handleFrequencies();
    void handleVolume();
    uInt32 getEffectiveVolume();

    // Following constructors and assignment operators not supported
    AudioWidget() = delete;
    AudioWidget(const AudioWidget&) = delete;
    AudioWidget(AudioWidget&&) = delete;
    AudioWidget& operator=(const AudioWidget&) = delete;
    AudioWidget& operator=(AudioWidget&&) = delete;
};

#endif
