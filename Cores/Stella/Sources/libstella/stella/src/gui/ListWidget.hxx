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

#ifndef LIST_WIDGET_HXX
#define LIST_WIDGET_HXX

class GuiObject;
class ScrollBarWidget;

#include "Rect.hxx"
#include "Command.hxx"
#include "EditableWidget.hxx"

/** ListWidget */
class ListWidget : public EditableWidget
{
  public:
    enum {
      kDoubleClickedCmd    = 'LIdb',  // double click on item - 'data' will be item index
      kLongButtonPressCmd  = 'LIlb',  // long button press
      kActivatedCmd        = 'LIac',  // item activated by return/enter - 'data' will be item index
      kDataChangedCmd      = 'LIch',  // item data changed - 'data' will be item index
      kRClickedCmd         = 'LIrc',  // right click on item - 'data' will be item index
      kSelectionChangedCmd = 'Lsch',  // selection changed - 'data' will be item index
      kScrolledCmd         = 'Lscl',  // list scrolled - 'data' will be current position
      kParentDirCmd        = 'Lpdr'   // request to go to parent list, if applicable
    };

  public:
    ListWidget(GuiObject* boss, const GUI::Font& font,
               int x, int y, int w, int h, bool useScrollbar = true);
    ~ListWidget() override = default;

    int rows() const        { return _rows; }
    int currentPos() const  { return _currentPos; }
    void setHeight(int h) override;

    int getSelected() const { return _selectedItem; }
    void setSelected(int item);
    void setSelected(string_view item);

    int getHighlighted() const     { return _highlightedItem; }
    void setHighlighted(int item);

    const StringList& getList()	const { return _list; }
    const string& getSelectedString() const;

    void scrollTo(int item);
    void scrollToEnd() { scrollToCurrent(static_cast<int>(_list.size())); }

    // Account for the extra width of embedded scrollbar
    int getWidth() const override;

  protected:
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseWheel(int x, int y, int direction) override;
    bool handleText(char text) override;
    bool handleKeyDown(StellaKey key, StellaMod mod) override;
    void handleJoyDown(int stick, int button, bool longPress) override;
    void handleJoyUp(int stick, int button) override;
    bool handleEvent(Event::Type e) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    virtual void drawWidget(bool hilite) override  = 0;
    virtual Common::Rect getEditRect() const override = 0;

    int findItem(int x, int y) const;
    void recalc();
    void scrollBarRecalc();

    void startEditMode() override;
    void endEditMode() override;
    void abortEditMode() override;

    void lostFocusWidget() override;
    void scrollToSelected()    { scrollToCurrent(_selectedItem);    }
    void scrollToHighlighted() { scrollToCurrent(_highlightedItem); }

  private:
    void scrollToCurrent(int item);

  protected:
    int  _rows{0};
    int  _cols{0};
    int  _currentPos{0};
    int  _selectedItem{-1};
    int  _highlightedItem{-1};
    bool _useScrollbar{true};

    ScrollBarWidget* _scrollBar{nullptr};

    StringList _list;

  private:
    // Following constructors and assignment operators not supported
    ListWidget() = delete;
    ListWidget(const ListWidget&) = delete;
    ListWidget(ListWidget&&) = delete;
    ListWidget& operator=(const ListWidget&) = delete;
    ListWidget& operator=(ListWidget&&) = delete;
};

#endif
