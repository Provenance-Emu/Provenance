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

#ifndef TIA_ZOOM_WIDGET_HXX
#define TIA_ZOOM_WIDGET_HXX

class GuiObject;
class ContextMenu;

#include "Widget.hxx"
#include "Command.hxx"

class TiaZoomWidget : public Widget, public CommandSender
{
  public:
    using Widget::setPos;

    TiaZoomWidget(GuiObject *boss, const GUI::Font& font,
                  int x, int y, int w, int h);
    ~TiaZoomWidget() override = default;

    void loadConfig() override;
    void setPos(int x, int y) override;

    string getToolTip(const Common::Point& pos) const override;
    bool changedToolTip(const Common::Point& oldPos, const Common::Point& newPos) const override;

  protected:
    bool hasToolTip() const override { return true; }
    Common::Point getToolTipIndex(const Common::Point& pos) const;

  private:
    void zoom(int level);
    void recalc();

    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseWheel(int x, int y, int direction) override;
    void handleMouseMoved(int x, int y) override;
    void handleMouseLeft() override;
    bool handleEvent(Event::Type event) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void drawWidget(bool hilite) override;
    bool wantsFocus() const override { return true; }

  private:
    unique_ptr<ContextMenu> myMenu;

    int myZoomLevel{2};
    int myNumCols{0}, myNumRows{0};
    int myOffX{0}, myOffY{0};
    int myOffXLo{0}, myOffYLo{0};

    bool myMouseMoving{false};
    int myClickX{0}, myClickY{0};

  private:
    // Following constructors and assignment operators not supported
    TiaZoomWidget() = delete;
    TiaZoomWidget(const TiaZoomWidget&) = delete;
    TiaZoomWidget(TiaZoomWidget&&) = delete;
    TiaZoomWidget& operator=(const TiaZoomWidget&) = delete;
    TiaZoomWidget& operator=(TiaZoomWidget&&) = delete;
};

#endif
