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

#ifndef EVENT_MAPPING_WIDGET_HXX
#define EVENT_MAPPING_WIDGET_HXX

class DialogContainer;
class CommandSender;
class ButtonWidget;
class EditTextWidget;
class StaticTextWidget;
class StringListWidget;
class PopUpWidget;
class GuiObject;
class ComboDialog;
class InputDialog;

#include "Widget.hxx"
#include "Command.hxx"
#include "bspf.hxx"

class EventMappingWidget : public Widget, public CommandSender
{
  friend class InputDialog;

  public:
    EventMappingWidget(GuiObject* boss, const GUI::Font& font,
                       int x, int y, int w, int h);
    ~EventMappingWidget() override = default;

    bool remapMode() { return myRemapStatus; }

    void setDefaults();

  private:
    enum {
      kFilterCmd   = 'filt',
      kStartMapCmd = 'map ',
      kStopMapCmd  = 'smap',
      kEraseCmd    = 'eras',
      kResetCmd    = 'rest',
      kComboCmd    = 'cmbo'
    };

    bool handleKeyDown(StellaKey key, StellaMod mod) override;
    bool handleKeyUp(StellaKey key, StellaMod mod) override;
    void handleJoyDown(int stick, int button, bool longPress = false) override;
    void handleJoyUp(int stick, int button) override;
    void handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button) override;
    bool handleJoyHat(int stick, int hat, JoyHatDir hdir, int button) override;

    void loadConfig() override;
    void saveConfig();

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void updateActions();
    void startRemapping();
    void eraseRemapping();
    void resetRemapping();
    void stopRemapping();

    bool isRemapping() { return myRemapStatus; }

    void drawKeyMapping();
    void enableButtons(bool state);

  private:
    ButtonWidget*     myMapButton{nullptr};
    ButtonWidget*     myCancelMapButton{nullptr};
    ButtonWidget*     myEraseButton{nullptr};
    ButtonWidget*     myResetButton{nullptr};
    ButtonWidget*     myComboButton{nullptr};
    PopUpWidget*      myFilterPopup{nullptr};
    StringListWidget* myActionsList{nullptr};
    EditTextWidget*   myKeyMapping{nullptr};

    unique_ptr<ComboDialog> myComboDialog;

    // Since this widget can be used for different collections of events,
    // we need to specify exactly which group of events we are remapping
    EventMode myEventMode{EventMode::kEmulationMode};

    // Since we can filter events, the event mode is not specific enough
    Event::Group myEventGroup{Event::Group::Emulation};

    // Indicates the event that is currently selected
    int myActionSelected{-1};

    // Indicates if we're currently in remap mode
    // In this mode, the next event received is remapped to some action
    bool myRemapStatus{false};

    // Joystick axes and hats can be more problematic than ordinary buttons
    // or keys, in that there can be 'drift' in the values
    // Therefore, we map these events when they've been 'released', rather
    // than on their first occurrence (aka, when they're 'pressed')
    // As a result, we need to keep track of their old values
    int myLastStick{0}, myLastHat{0};
    JoyAxis myLastAxis{JoyAxis::NONE};
    JoyDir myLastDir{JoyDir::NONE};
    JoyHatDir myLastHatDir{JoyHatDir::CENTER};

    // Aggregates the modifier flags of the mapping
    int myMod{0};
    // Saves the last *pressed* key
    int myLastKey{0};
    // Saves the last *pressed* button
    int myLastButton{JOY_CTRL_NONE};

    bool myFirstTime{true};

  private:
    // Following constructors and assignment operators not supported
    EventMappingWidget() = delete;
    EventMappingWidget(const EventMappingWidget&) = delete;
    EventMappingWidget(EventMappingWidget&&) = delete;
    EventMappingWidget& operator=(const EventMappingWidget&) = delete;
    EventMappingWidget& operator=(EventMappingWidget&&) = delete;
};

#endif
