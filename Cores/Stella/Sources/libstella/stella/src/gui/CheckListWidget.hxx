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

#ifndef CHECK_LIST_WIDGET_HXX
#define CHECK_LIST_WIDGET_HXX

class CheckboxWidget;

#include "ListWidget.hxx"

using CheckboxArray = vector<CheckboxWidget*>;


/** CheckListWidget */
class CheckListWidget : public ListWidget
{
  public:
    enum { kListItemChecked = 'LIct' /* checkbox toggled on current line*/ };

  public:
    CheckListWidget(GuiObject* boss, const GUI::Font& font,
                    int x, int y, int w, int h);
    ~CheckListWidget() override = default;

    void setList(const StringList& list, const BoolArray& state);
    void setLine(int line, string_view str, const bool& state);

    bool getState(int line) const;
    bool getSelectedState() const { return getState(_selectedItem); }

  private:
    bool handleEvent(Event::Type e) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void drawWidget(bool hilite) override;
    Common::Rect getEditRect() const override;

  protected:
    BoolArray     _stateList;
    CheckboxArray _checkList;

  private:
    // Following constructors and assignment operators not supported
    CheckListWidget() = delete;
    CheckListWidget(const CheckListWidget&) = delete;
    CheckListWidget(CheckListWidget&&) = delete;
    CheckListWidget& operator=(const CheckListWidget&) = delete;
    CheckListWidget& operator=(CheckListWidget&&) = delete;
};

#endif
