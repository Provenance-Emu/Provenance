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

#ifndef TIA_OUTPUT_WIDGET_HXX
#define TIA_OUTPUT_WIDGET_HXX

class GuiObject;
class ContextMenu;
class TiaZoomWidget;
class FBSurface;

#include "Widget.hxx"
#include "Command.hxx"

class TiaOutputWidget : public Widget, public CommandSender
{
  public:
    TiaOutputWidget(GuiObject *boss, const GUI::Font& font,
                    int x, int y, int w, int h);
    ~TiaOutputWidget() override = default;

    void loadConfig() override;
    void setZoomWidget(TiaZoomWidget* w) { myZoom = w; }

    void saveSnapshot(int execDepth = 0, string_view execPrefix = EmptyString,
                      bool mark = true);

// Eventually, these methods will enable access to the onscreen TIA image
// For example, clicking an area may cause an action
// (fill to this scanline, etc).
/*
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseWheel(int x, int y, int direction) override;
    bool handleKeyDown(StellaKey key, StellaMod mod) override;
    bool handleKeyUp(StellaKey key, StellaMod mod) override;
*/
    string getToolTip(const Common::Point& pos) const override;
    bool changedToolTip(const Common::Point& oldPos, const Common::Point& newPos) const override;

  protected:
    bool hasToolTip() const override { return true; }
    Common::Point getToolTipIndex(const Common::Point& pos) const;

  private:
    unique_ptr<ContextMenu> myMenu;
    TiaZoomWidget* myZoom{nullptr};

    int myClickX{0}, myClickY{0};

    // Create this buffer once, instead of allocating it each time the
    // TIA image is redrawn
    std::array<uInt32, 320> myLineBuffer;

  private:
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    void drawWidget(bool hilite) override;
    bool wantsFocus() const override { return false; }

    // Following constructors and assignment operators not supported
    TiaOutputWidget() = delete;
    TiaOutputWidget(const TiaOutputWidget&) = delete;
    TiaOutputWidget(TiaOutputWidget&&) = delete;
    TiaOutputWidget& operator=(const TiaOutputWidget&) = delete;
    TiaOutputWidget& operator=(TiaOutputWidget&&) = delete;
};

#endif
