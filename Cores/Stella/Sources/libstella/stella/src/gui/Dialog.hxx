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
//
//   Based on code from ScummVM - Scumm Interpreter
//   Copyright (C) 2002-2004 The ScummVM project
//============================================================================

#ifndef DIALOG_HXX
#define DIALOG_HXX

class FBSurface;
class OSystem;
class DialogContainer;
class TabWidget;
class CommandSender;
class ToolTip;

#include "Widget.hxx"
#include "GuiObject.hxx"
#include "StellaKeys.hxx"
#include "EventHandlerConstants.hxx"
#include "bspf.hxx"

/**
  This is the base class for all dialog boxes.

  @author  Stephen Anthony
*/
class Dialog : public GuiObject
{
  friend class DialogContainer;

  public:
    // Current Stella mode
    enum class AppMode { launcher, emulator, debugger };

    using RenderCallback = std::function<void()>;

    Dialog(OSystem& instance, DialogContainer& parent,
           int x = 0, int y = 0, int w = 0, int h = 0);
    Dialog(OSystem& instance, DialogContainer& parent, const GUI::Font& font,
           string_view title = "", int x = 0, int y = 0, int w = 0, int h = 0);
    ~Dialog() override;

    void clear();
    void open();
    void close();

    bool isVisible() const override { return _visible; }

    virtual void setPosition();
    virtual void drawDialog();
    virtual void loadConfig()  { }
    virtual void saveConfig()  { }
    virtual void setDefaults() { }

    void setDirty() override;
    void setDirtyChain() override;
    void redraw(bool force = false);
    void drawChain() override;
    void render();

    void tick() override;

    void addFocusWidget(Widget* w) override;
    int addToFocusList(const WidgetArray& list) override;
    int addToFocusList(const WidgetArray& list, const TabWidget* w, int tabId);
    void addBGroupToFocusList(const WidgetArray& list) { _buttonGroup = list; }
    void addTabWidget(TabWidget* w);
    void addDefaultWidget(ButtonWidget* w) { _defaultWidget = w; }
    void addExtraWidget(ButtonWidget* w)   { _extraWidget = w;   }
    void addOKWidget(ButtonWidget* w)      { _okWidget = w;      }
    void addCancelWidget(ButtonWidget* w)  { _cancelWidget = w;  }
    void setFocus(const Widget* w);

    /** Returns the base surface associated with this dialog. */
    FBSurface& surface() const { return *_surface; }

    /**
      This method is called each time the main Dialog::render is called.
      It is called *after* the dialog has been rendered, so it can be
      used to render another surface on top of it, among other things.
    */
    void addRenderCallback(const RenderCallback& callback);

    void setTitle(string_view title);
    bool hasTitle() { return !_title.empty(); }

    void initHelp();
    void setHelpAnchor(string_view helpAnchor, bool debugger = false);
    void setHelpURL(string_view helpURL);

    virtual bool isShading() const { return true; }

    /**
      Determine the maximum width/height of a dialog based on the minimum
      allowable bounds, also taking into account the current window size.
      Currently scales the width/height to 95% of allowable area when possible.

      NOTE: This method is meant to be used for dynamic, resizeable dialogs.
            That is, those that can change size during a program run, and
            *have* to take the current window size into account.

      @param w  The resulting width to use for the dialog
      @param h  The resulting height to use for the dialog

      @return  True if the dialog fits in the current window (scaled to 90%)
               False if the dialog is smaller than the current window, and
               has to be scaled down
    */
    bool getDynamicBounds(uInt32& w, uInt32& h) const;

    /**
      Checks if the dialogs fits into the actual sizes.

      @param w  The resulting width to use for the dialog
      @param h  The resulting height to use for the dialog

      @return  True if the dialog should be resized
    */
    bool shouldResize(uInt32& w, uInt32& h) const;

    ToolTip& tooltip() { return *_toolTip; }

    int lineHeight() const { return _font.getLineHeight(); }
    int fontHeight() const { return _font.getFontHeight(); }
    int fontWidth() const { return _font.getMaxCharWidth(); }
    int buttonHeight() const { return lineHeight() * 1.25; }
    int buttonWidth(string_view label) const {
      return _font.getStringWidth(label) + fontWidth() * 2.5;
    }
    int buttonGap() const { return fontWidth(); }
    int hBorder() const { return fontWidth() * 1.25; }
    int vBorder() const { return fontHeight() / 2; }
    int vGap() const { return fontHeight() / 4; }
    int indent() const { return fontWidth() * 2; }

  protected:
    enum {
      kHelpCmd = 'DlHp'
    };

    void draw() override { }
    void releaseFocus() override;

    virtual void handleText(char text);
    virtual void handleKeyDown(StellaKey key, StellaMod modifiers, bool repeated = false);
    virtual void handleKeyUp(StellaKey key, StellaMod modifiers);
    virtual void handleMouseDown(int x, int y, MouseButton b, int clickCount);
    virtual void handleMouseUp(int x, int y, MouseButton b, int clickCount);
    virtual void handleMouseWheel(int x, int y, int direction);
    virtual void handleMouseMoved(int x, int y);
    virtual bool handleMouseClicks(int x, int y, MouseButton b);
    virtual void handleJoyDown(int stick, int button, bool longPress = false);
    virtual void handleJoyUp(int stick, int button);
    virtual void handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button = JOY_CTRL_NONE);
    virtual bool handleJoyHat(int stick, int hat, JoyHatDir hdir, int button = JOY_CTRL_NONE);
    virtual void handleEvent(Event::Type event) {}
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    virtual Event::Type getJoyAxisEvent(int stick, JoyAxis axis, JoyDir adir, int button);

    Widget* findWidget(int x, int y) const; // Find the widget at pos x,y if any


    void addOKBGroup(WidgetArray& wid, const GUI::Font& font,
                     string_view okText = "OK",
                     int buttonWidth = 0);

    void addOKCancelBGroup(WidgetArray& wid, const GUI::Font& font,
                           string_view okText = "OK",
                           string_view cancelText = "Cancel",
                           bool focusOKButton = true,
                           int buttonWidth = 0);

    void addDefaultsOKCancelBGroup(WidgetArray& wid, const GUI::Font& font,
                                   string_view okText = "OK",
                                   string_view cancelText = "Cancel",
                                   string_view defaultsText = "Defaults",
                                   bool focusOKButton = true);

    // NOTE: This method, and the three above it, are due to be refactored at some
    //       point, since the parameter list is kind of getting ridiculous
    void addDefaultsExtraOKCancelBGroup(WidgetArray& wid, const GUI::Font& font,
                                        string_view extraText, int extraCmd,
                                        string_view okText = "OK",
                                        string_view cancelText = "Cancel",
                                        string_view defaultsText = "Defaults",
                                        bool focusOKButton = true);

    void processCancelWithoutWidget(bool state = true) { _processCancel = state; }
    virtual void processCancel() { close(); }

    /** Define the size (allowed) for the dialog. */
    void setSize(uInt32 w, uInt32 h, uInt32 max_w, uInt32 max_h);
    void positionAt(uInt32 pos);

    virtual bool repeatEnabled() { return true; }

  private:
    void buildCurrentFocusList(int tabID = -1);
    bool handleNavEvent(Event::Type e, bool repeated = false);
    void getTabIdForWidget(const Widget* w);
    bool cycleTab(int direction);
    string getHelpURL() const override;
    bool hasHelp() const override { return !getHelpURL().empty(); }
    void openHelp();

  protected:
    const GUI::Font& _font;

    Widget* _mouseWidget{nullptr};
    Widget* _focusedWidget{nullptr};
    Widget* _dragWidget{nullptr};
    ButtonWidget* _defaultWidget{nullptr};
    ButtonWidget* _extraWidget{nullptr};
    ButtonWidget* _okWidget{nullptr};
    ButtonWidget* _cancelWidget{nullptr};

    bool    _visible{false};
    bool    _processCancel{false};
    string  _title;
    int     _th{0};
    int     _layer{0};
    unique_ptr<ToolTip> _toolTip;
    string  _helpAnchor;
    string  _helpURL;
    bool    _debuggerHelp{false};
    ButtonWidget* _helpWidget{nullptr};

  private:
    struct Focus {
      Widget* widget{nullptr};
      WidgetArray list;

      explicit Focus(Widget* w = nullptr) : widget{w} { }
    };
    using FocusList = vector<Focus>;

    struct TabFocus {
      TabWidget* widget{nullptr};
      FocusList focus;
      uInt32 currentTab{0};

      explicit TabFocus(TabWidget* w = nullptr) : widget{w} { }

      void appendFocusList(WidgetArray& list);
      void saveCurrentFocus(Widget* w);
      Widget* getNewFocus();
    };
    using TabFocusList = vector<TabFocus>;

    Focus        _myFocus;    // focus for base dialog
    TabFocusList _myTabList;  // focus for each tab (if any)

    WidgetArray _buttonGroup;
    shared_ptr<FBSurface> _surface;
    shared_ptr<FBSurface> _shadeSurface;

    int _tabID{0};
    uInt32 _max_w{0}; // maximum wanted width
    uInt32 _max_h{0}; // maximum wanted height

    RenderCallback _renderCallback;

  private:
    // Following constructors and assignment operators not supported
    Dialog() = delete;
    Dialog(const Dialog&) = delete;
    Dialog(Dialog&&) = delete;
    Dialog& operator=(const Dialog&) = delete;
    Dialog& operator=(Dialog&&) = delete;
};

#endif
