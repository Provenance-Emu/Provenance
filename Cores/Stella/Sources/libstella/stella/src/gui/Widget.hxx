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

#ifndef WIDGET_HXX
#define WIDGET_HXX

class Dialog;

#include <cassert>

#include "bspf.hxx"
#include "Rect.hxx"
#include "Event.hxx"
#include "EventHandlerConstants.hxx"
#include "FrameBufferConstants.hxx"
#include "StellaKeys.hxx"
#include "GuiObject.hxx"
#include "Font.hxx"
#include "Icon.hxx"

/**
  This is the base class for all widgets.

  @author  Stephen Anthony
*/
class Widget : public GuiObject
{
  friend class Dialog;

  public:
    Widget(GuiObject* boss, const GUI::Font& font, int x, int y, int w, int h);
    ~Widget() override;

    int getAbsX() const override { return _x + _boss->getChildX(); }
    int getAbsY() const override { return _y + _boss->getChildY(); }
    virtual int getLeft() const { return _x; }
    virtual int getTop() const { return _y; }
    virtual int getRight() const { return _x + getWidth(); }
    virtual int getBottom() const { return _y + getHeight(); }
    virtual void setPosX(int x);
    virtual void setPosY(int y);
    virtual void setPos(int x, int y);
    virtual void setPos(const Common::Point& pos);
    void setWidth(int w) override;
    void setHeight(int h) override;
    virtual void setSize(int w, int h);
    virtual void setSize(const Common::Point& pos);

    virtual bool handleText(char text)                        { return false; }
    virtual bool handleKeyDown(StellaKey key, StellaMod mod)  { return false; }
    virtual bool handleKeyUp(StellaKey key, StellaMod mod)    { return false; }
    virtual void handleMouseDown(int x, int y, MouseButton b, int clickCount) { }
    virtual void handleMouseUp(int x, int y, MouseButton b, int clickCount) { }
    virtual void handleMouseEntered();
    virtual void handleMouseLeft();
    virtual void handleMouseMoved(int x, int y) { }
    virtual void handleMouseWheel(int x, int y, int direction) { }
    virtual bool handleMouseClicks(int x, int y, MouseButton b) { return false; }
    virtual void handleJoyDown(int stick, int button, bool longPress = false) { }
    virtual void handleJoyUp(int stick, int button) { }
    virtual void handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button = JOY_CTRL_NONE) { }
    virtual bool handleJoyHat(int stick, int hat, JoyHatDir hdir, int button = JOY_CTRL_NONE) { return false; }
    virtual bool handleEvent(Event::Type event) { return false; }

    void tick() override;

    void setDirty() override;
    void setDirtyChain() override;
    void draw() override;
    void drawChain() override;
    void receivedFocus();
    void lostFocus();
    void addFocusWidget(Widget* w) override { _focusList.push_back(w); }
    int addToFocusList(const WidgetArray& list) override {
      Vec::append(_focusList, list);
      return static_cast<int>(_focusList.size());
    }

    /** Set/clear FLAG_ENABLED */
    virtual void setEnabled(bool e);

    bool isEnabled() const          { return _flags & FLAG_ENABLED;         }
    bool isVisible() const override { return !(_flags & FLAG_INVISIBLE);    }
    bool isHighlighted() const      { return _flags & FLAG_HILITED; }
    bool hasMouseFocus() const      { return _flags & FLAG_MOUSE_FOCUS; }
    virtual bool wantsFocus() const { return _flags & FLAG_RETAIN_FOCUS;    }
    bool wantsTab() const           { return _flags & FLAG_WANTS_TAB;       }
    bool wantsRaw() const           { return _flags & FLAG_WANTS_RAWDATA;   }

    virtual void setID(uInt32 id) { _id = id;   }
    uInt32 getID() const  { return _id; }

    virtual const GUI::Font& font() const { return _font; }

    void setTextColor(ColorId color)   { _textcolor = color;   setDirty(); }
    void setTextColorHi(ColorId color) { _textcolorhi = color; setDirty(); }
    void setBGColor(ColorId color)     { _bgcolor = color;     setDirty(); }
    void setBGColorHi(ColorId color)   { _bgcolorhi = color;   setDirty(); }
    void setShadowColor(ColorId color) { _shadowcolor = color; setDirty(); }

    void setToolTip(string_view text,
      Event::Type event1 = Event::Type::NoType, EventMode = EventMode::kEmulationMode);
    void setToolTip(string_view text,
      Event::Type event1, Event::Type event2, EventMode = EventMode::kEmulationMode);
    void setToolTip(Event::Type event1, EventMode mode = EventMode::kEmulationMode);
    void setToolTip(Event::Type event1, Event::Type event2,
      EventMode mode = EventMode::kEmulationMode);
    virtual string getToolTip(const Common::Point& pos) const;
    virtual bool changedToolTip(const Common::Point& oldPos,
                                const Common::Point& newPos) const { return false; }

    void setHelpAnchor(string_view helpAnchor, bool debugger = false);
    void setHelpURL(string_view helpURL);

    virtual void loadConfig() { }

  protected:
    virtual void drawWidget(bool hilite) { }

    virtual void receivedFocusWidget() { }
    virtual void lostFocusWidget() { }

    virtual Widget* findWidget(int x, int y) { return this; }

    void releaseFocus() override { assert(_boss); _boss->releaseFocus(); }

    virtual bool wantsToolTip() const { return hasMouseFocus() && hasToolTip(); }
    virtual bool hasToolTip() const;

    // By default, delegate unhandled commands to the boss
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override
         { assert(_boss); _boss->handleCommand(sender, cmd, data, id); }

    string getHelpURL() const override;
    bool hasHelp() const override { return !getHelpURL().empty(); }

  protected:
    GuiObject*  _boss{nullptr};
    const GUI::Font& _font;
    Widget*     _next{nullptr};
    uInt32      _id{0};
    bool        _hasFocus{false};
    int         _fontWidth{0};
    int         _lineHeight{0};
    ColorId     _bgcolor{kWidColor};
    ColorId     _bgcolorhi{kWidColor};
    ColorId     _bgcolorlo{kBGColorLo};
    ColorId     _textcolor{kTextColor};
    ColorId     _textcolorhi{kTextColorHi};
    ColorId     _textcolorlo{kBGColorLo};
    ColorId     _shadowcolor{kShadowColor};
    string      _toolTipText;
    Event::Type _toolTipEvent1{Event::NoType};
    Event::Type _toolTipEvent2{Event::NoType};
    EventMode   _toolTipMode{EventMode::kEmulationMode};
    string      _helpAnchor;
    string      _helpURL;
    bool        _debuggerHelp{false};

  public:
    static Widget* findWidgetInChain(Widget* start, int x, int y);

    /** Determine if 'find' is in the chain pointed to by 'start' */
    static bool isWidgetInChain(Widget* start, const Widget* find);

    /** Determine if 'find' is in the widget array */
    static bool isWidgetInChain(const WidgetArray& list, Widget* find);

    /** Select either previous, current, or next widget in chain to have
        focus, and deselects all others */
    static Widget* setFocusForChain(const GuiObject* boss, WidgetArray& arr,
                                    const Widget* w, int direction,
                                    bool emitFocusEvents = true);

    /** Sets all widgets in this chain to be dirty (must be redrawn) */
    static void setDirtyInChain(Widget* start);

  private:
    // Following constructors and assignment operators not supported
    Widget() = delete;
    Widget(const Widget&) = delete;
    Widget(Widget&&) = delete;
    Widget& operator=(const Widget&) = delete;
    Widget& operator=(Widget&&) = delete;
};

/* StaticTextWidget */
class StaticTextWidget : public Widget, public CommandSender
{
  public:
    enum {
      kClickedCmd = 'STcl',
      kOpenUrlCmd = 'STou'
    };

  public:
    StaticTextWidget(GuiObject* boss, const GUI::Font& font,
                     int x, int y, int w, int h,
                     string_view text = "", TextAlign align = TextAlign::Left,
                     ColorId shadowColor = kNone);
    StaticTextWidget(GuiObject* boss, const GUI::Font& font,
                     int x, int y,
                     string_view text = "", TextAlign align = TextAlign::Left,
                     ColorId shadowColor = kNone);
    ~StaticTextWidget() override = default;

    void setCmd(int cmd) { _cmd = cmd; }

    virtual void setValue(int value);
    void setLabel(string_view label);
    void setAlign(TextAlign align) { _align = align; setDirty(); }
    const string& getLabel() const { return _label; }
    bool isEditable() const { return _editable; }

    void setLink(size_t start = string::npos, int len = 0, bool underline = false);
    bool setUrl(string_view url = EmptyString, string_view label = EmptyString,
                string_view placeHolder = EmptyString);
    const string& getUrl() const { return _url; }

  protected:
    void handleMouseEntered() override;
    void handleMouseLeft() override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;

    void drawWidget(bool hilite) override;

  protected:
    string    _label;
    bool      _editable{false};
    TextAlign _align{TextAlign::Left};
    int       _cmd{0};
    size_t    _linkStart{string::npos};
    int       _linkLen{0};
    bool      _linkUnderline{false};
    string    _url;

  private:
    // Following constructors and assignment operators not supported
    StaticTextWidget() = delete;
    StaticTextWidget(const StaticTextWidget&) = delete;
    StaticTextWidget(StaticTextWidget&&) = delete;
    StaticTextWidget& operator=(const StaticTextWidget&) = delete;
    StaticTextWidget& operator=(StaticTextWidget&&) = delete;
};

/* ButtonWidget */
class ButtonWidget : public StaticTextWidget
{
  public:
    ButtonWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y, int w, int h,
                 string_view label, int cmd = 0, bool repeat = false);
    ButtonWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y, int dw,
                 string_view label, int cmd = 0, bool repeat = false);
    ButtonWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y,
                 string_view label, int cmd = 0, bool repeat = false);
    ButtonWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y, int dw, int dh,
                 const uInt32* bitmap, int bmw, int bmh,
                 int cmd = 0, bool repeat = false);
    ButtonWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y, int dw, int dh,
                 const GUI::Icon& icon,
                 int cmd = 0, bool repeat = false);
    ButtonWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y, int w, int h,
                 const GUI::Icon& icon, int bmx,
                 string_view label,
                 int cmd = 0, bool repeat= false);
    ~ButtonWidget() override = default;

    bool handleEvent(Event::Type event) override;

    /* Sets/changes the button's bitmap **/
    void setBitmap(const uInt32* bitmap, int bmw, int bmh);
    void setIcon(const GUI::Icon& icon);

  protected:
    bool handleMouseClicks(int x, int y, MouseButton b) override;
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseEntered() override;
    void handleMouseLeft() override;

    void drawWidget(bool hilite) override;

  protected:
    bool _repeat{false}; // button repeats
    bool _useText{true};
    bool _useBitmap{false};
    const uInt32* _bitmap{nullptr};
    int  _bmw{0}, _bmh{0}, _bmx{0};

  private:
    // Following constructors and assignment operators not supported
    ButtonWidget() = delete;
    ButtonWidget(const ButtonWidget&) = delete;
    ButtonWidget(ButtonWidget&&) = delete;
    ButtonWidget& operator=(const ButtonWidget&) = delete;
    ButtonWidget& operator=(ButtonWidget&&) = delete;
};

/* CheckboxWidget */
class CheckboxWidget : public ButtonWidget
{
  public:
    enum { kCheckActionCmd  = 'CBAC' };
    enum class FillType { Normal, Inactive, Circle };

  public:
    CheckboxWidget(GuiObject* boss, const GUI::Font& font, int x, int y,
                   string_view label, int cmd = 0);
    ~CheckboxWidget() override = default;

    void setEditable(bool editable);
    virtual void setFill(FillType type);

    virtual void setState(bool state, bool changed = false);
    void toggleState()     { setState(!_state); }
    bool getState() const  { return _state;     }

    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;

    static int boxSize(const GUI::Font& font)
    {
      return font.getFontHeight() < 24 ? 14 : 22; // box is square
    }
    static int prefixSize(const GUI::Font& font)
    {
      return boxSize(font) + font.getMaxCharWidth() * 0.75;
    }

  protected:
    void drawWidget(bool hilite) override;

  protected:
    bool _state{false};
    bool _holdFocus{true};
    bool _drawBox{true};
    bool _changed{false};

    const uInt32* _outerCircle{nullptr};
    const uInt32* _innerCircle{nullptr};
    const uInt32* _img{nullptr};
    ColorId _fillColor{kColor};
    int _boxY{0};
    int _textY{0};
    int _boxSize{14};

  private:
    // Following constructors and assignment operators not supported
    CheckboxWidget() = delete;
    CheckboxWidget(const CheckboxWidget&) = delete;
    CheckboxWidget(CheckboxWidget&&) = delete;
    CheckboxWidget& operator=(const CheckboxWidget&) = delete;
    CheckboxWidget& operator=(CheckboxWidget&&) = delete;
};

/* SliderWidget */
class SliderWidget : public ButtonWidget
{
  public:
    SliderWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y, int w, int h,
                 string_view label = "", int labelWidth = 0, int cmd = 0,
                 int valueLabelWidth = 0, string_view valueUnit = "",
                 int valueLabelGap = 0, bool forceLabelSign = false);
    SliderWidget(GuiObject* boss, const GUI::Font& font,
                 int x, int y,
                 string_view label = "", int labelWidth = 0, int cmd = 0,
                 int valueLabelWidth = 0, string_view valueUnit = "",
                 int valueLabelGap = 0, bool forceLabelSign = false);
    ~SliderWidget() override = default;

    void setValue(int value) override;
    int getValue() const { return BSPF::clamp(_value, _valueMin, _valueMax); }

    void setMinValue(int value);
    int  getMinValue() const { return _valueMin; }
    void setMaxValue(int value);
    int  getMaxValue() const { return _valueMax; }
    void setStepValue(int value);
    int  getStepValue() const { return _stepValue; }
    void setValueLabel(string_view valueLabel);
    void setValueLabel(int value);
    const string& getValueLabel() const { return _valueLabel; }
    void setValueUnit(string_view valueUnit);

    void setTickmarkIntervals(int numIntervals);

  protected:
    void handleMouseMoved(int x, int y) override;
    void handleMouseDown(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleMouseWheel(int x, int y, int direction) override;
    bool handleEvent(Event::Type event) override;

    void drawWidget(bool hilite) override;

    int valueToPos(int value) const;
    int posToValue(int pos) const;

  protected:
    int    _value{-INT_MAX}, _stepValue{1};
    int    _valueMin{0}, _valueMax{100};
    bool   _isDragging{false};
    int    _labelWidth{0};
    string _valueLabel;
    string _valueUnit;
    int    _valueLabelGap{0};
    int    _valueLabelWidth{0};
    bool   _forceLabelSign{false};
    int    _numIntervals{0};

  private:
    // Following constructors and assignment operators not supported
    SliderWidget() = delete;
    SliderWidget(const SliderWidget&) = delete;
    SliderWidget(SliderWidget&&) = delete;
    SliderWidget& operator=(const SliderWidget&) = delete;
    SliderWidget& operator=(SliderWidget&&) = delete;
};

#endif
