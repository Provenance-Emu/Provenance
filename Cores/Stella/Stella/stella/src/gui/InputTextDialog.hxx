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

#ifndef INPUT_TEXT_DIALOG_HXX
#define INPUT_TEXT_DIALOG_HXX

class GuiObject;
class StaticTextWidget;
class EditTextWidget;

#include "Dialog.hxx"
#include "Command.hxx"
#include "EditableWidget.hxx"

class InputTextDialog : public Dialog, public CommandSender
{
  public:
    InputTextDialog(GuiObject* boss, const GUI::Font& font,
                    const StringList& labels, const string& title = "");
    InputTextDialog(GuiObject* boss, const GUI::Font& lfont,
                    const GUI::Font& nfont, const StringList& labels,
                    const string& title = "");
    InputTextDialog(OSystem& osystem, DialogContainer& parent, const GUI::Font& font,
                    const string& label, const string& title, int numInput = 0);

    ~InputTextDialog() override = default;

    /** Place the input dialog onscreen and center it */
    void show();

    /** Show input dialog onscreen at the specified coordinates */
    void show(uInt32 x, uInt32 y, const Common::Rect& bossRect);

    const string& getResult(int idx = 0);

    void setText(const string& str, int idx = 0);
    void setTextFilter(const EditableWidget::TextFilter& f, int idx = 0);
    void setToolTip(const string& str, int idx = 0);

    void setEmitSignal(int cmd) { myCmd = cmd; }
    void setMessage(const string& title);

    void setFocus(int idx = 0);

  protected:
    void initialize(const GUI::Font& lfont, const GUI::Font& nfont,
                    const StringList& labels, int widthChars = 39, int numInput = 0);
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    /** This dialog uses its own positioning, so we override Dialog::center() */
    void setPosition() override;

  private:
    vector<StaticTextWidget*> myLabel;
    vector<EditTextWidget*> myInput;
    StaticTextWidget* myMessage{nullptr};

    bool myEnableCenter{true};
    bool myErrorFlag{false};
    int	 myCmd{0};

    uInt32 myXOrig{0}, myYOrig{0};

  private:
    // Following constructors and assignment operators not supported
    InputTextDialog() = delete;
    InputTextDialog(const InputTextDialog&) = delete;
    InputTextDialog(InputTextDialog&&) = delete;
    InputTextDialog& operator=(const InputTextDialog&) = delete;
    InputTextDialog& operator=(InputTextDialog&&) = delete;
};

#endif
