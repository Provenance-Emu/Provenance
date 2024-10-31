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

#ifndef TAB_WIDGET_HXX
#define TAB_WIDGET_HXX

#include "bspf.hxx"

#include "Command.hxx"
#include "Widget.hxx"

class TabWidget : public Widget, public CommandSender
{
  public:
    static constexpr int NO_WIDTH = 0;
    static constexpr int AUTO_WIDTH = -1;

    enum {
      kTabChangedCmd = 'TBCH'
    };

  public:
    TabWidget(GuiObject* boss, const GUI::Font& font, int x, int y, int w, int h);
    ~TabWidget() override;

// use Dialog::releaseFocus() when changing to another tab

// Problem: how to add items to a tab?
// First off, widget should allow non-dialog bosses, (i.e. also other widgets)
// Could add a common base class for Widgets and Dialogs.
// Then you add tabs using the following method, which returns a unique ID
    int addTab(string_view title, int tabWidth = NO_WIDTH);
// Maybe we need to remove tabs again? Hm
    //void removeTab(int tabID);
// Setting the active tab:
    void setActiveTab(int tabID, bool show = false);
    void enableTab(int tabID, bool enable = true);
    void activateTabs();
    void cycleTab(int direction);
// setActiveTab changes the value of _firstWidget. This means Widgets added afterwards
// will be added to the active tab.
    void setParentWidget(int tabID, Widget* parent);
    Widget* parentWidget(int tabID);

    int getTabWidth()  { return _tabWidth;  }
    int getTabHeight() { return _tabHeight; }
    int getActiveTab() { return _activeTab; }

    void loadConfig() override;

  protected:
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseEntered() override {}
    void handleMouseLeft() override {}

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    bool handleEvent(Event::Type event) override;

    void drawWidget(bool hilite) override;
    Widget* findWidget(int x, int y) override;
    int getChildY() const override;

  private:
    struct Tab {
      string title;
      Widget* firstWidget{nullptr};
      Widget* parentWidget{nullptr};
      bool enabled{true};
      int tabWidth{0};

      explicit Tab(string_view t, int tw = NO_WIDTH,
          Widget* first = nullptr, Widget* parent = nullptr, bool e = true)
        : title{t}, firstWidget{first}, parentWidget{parent}, enabled{e},
          tabWidth{tw} { }
    };
    using TabList = vector<Tab>;

    TabList _tabs;
    int     _tabWidth{40};
    int     _tabHeight{1};
    int     _activeTab{-1};
    bool    _firstTime{true};

    enum {
      kTabLeftOffset = 0,
      kTabSpacing = 1,
      kTabPadding = 4
    };

  private:
    void updateActiveTab();

  private:
    // Following constructors and assignment operators not supported
    TabWidget() = delete;
    TabWidget(const TabWidget&) = delete;
    TabWidget(TabWidget&&) = delete;
    TabWidget& operator=(const TabWidget&) = delete;
    TabWidget& operator=(TabWidget&&) = delete;
};

#endif
