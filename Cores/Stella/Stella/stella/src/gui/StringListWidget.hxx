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

#ifndef STRING_LIST_WIDGET_HXX
#define STRING_LIST_WIDGET_HXX

#include "ListWidget.hxx"

/** StringListWidget */
class StringListWidget : public ListWidget
{
  public:
    StringListWidget(GuiObject* boss, const GUI::Font& font,
                     int x, int y, int w, int h, bool hilite = true,
                     bool useScrollbar = true);
    ~StringListWidget() override = default;

    void setList(const StringList& list);
    bool wantsFocus() const override { return true; }

    string getToolTip(const Common::Point& pos) const override;
    bool changedToolTip(const Common::Point& oldPos, const Common::Point& newPos) const override;

  protected:
    // display depends on _hasFocus so we have to redraw when focus changes
    void receivedFocusWidget() override { setDirty(); }
    void lostFocusWidget() override { setDirty(); }

    bool hasToolTip() const override { return true; }
    int getToolTipIndex(const Common::Point& pos) const;

    void drawWidget(bool hilite) override;
    virtual int drawIcon(int i, int x, int y, ColorId color) { return 0; }
    Common::Rect getEditRect() const override;

  protected:
    bool _hilite{false};
    int  _textOfs{0};

  private:
    // Following constructors and assignment operators not supported
    StringListWidget() = delete;
    StringListWidget(const StringListWidget&) = delete;
    StringListWidget(StringListWidget&&) = delete;
    StringListWidget& operator=(const StringListWidget&) = delete;
    StringListWidget& operator=(StringListWidget&&) = delete;
};

#endif
