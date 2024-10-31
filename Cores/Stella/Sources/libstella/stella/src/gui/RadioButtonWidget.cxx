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

#include "FBSurface.hxx"
#include "Font.hxx"
#include "Dialog.hxx"
#include "RadioButtonWidget.hxx"

/*  Radiobutton bitmaps */
// small versions
static constexpr std::array<uInt32, 14> radio_img_outercircle = {
  0b00001111110000,  0b00110000001100,  0b01000000000010,
  0b01000000000010,  0b10000000000001,  0b10000000000001,
  0b10000000000001,  0b10000000000001,  0b10000000000001,
  0b10000000000001,  0b01000000000010,  0b01000000000010,
  0b00110000001100,  0b00001111110000
};
static constexpr std::array<uInt32, 12> radio_img_innercircle = {
  0b000111111000,  0b011111111110,  0b011111111110,  0b111111111111,
  0b111111111111,  0b111111111111,  0b111111111111,  0b111111111111,
  0b111111111111,  0b011111111110,  0b011111111110,  0b000111111000
};
static constexpr std::array<uInt32, 10> radio_img_active = {
  0b0011111100,  0b0111111110,  0b1111111111,  0b1111111111,  0b1111111111,
  0b1111111111,  0b1111111111,  0b1111111111,  0b0111111110,  0b0011111100,
};
static constexpr std::array<uInt32, 10> radio_img_inactive = {
  0b0011111100,  0b0111111110,  0b1111001111,  0b1110000111,  0b1100000011,
  0b1100000011,  0b1110000111,  0b1111001111,  0b0111111110,  0b0011111100
};

// large versions
static constexpr std::array<uInt32, 22> radio_img_outercircle_large = {
  // thinner version
  //0b0000000011111100000000,
  //0b0000001100000011000000,
  //0b0000110000000000110000,
  //0b0001000000000000001000,
  //0b0010000000000000000100,
  //0b0010000000000000000100,
  //0b0100000000000000000010,
  //0b0100000000000000000010,
  //0b1000000000000000000001,
  //0b1000000000000000000001,
  //0b1000000000000000000001,
  //0b1000000000000000000001,
  //0b1000000000000000000001,
  //0b1000000000000000000001,
  //0b0100000000000000000010,
  //0b0100000000000000000010,
  //0b0010000000000000000100,
  //0b0010000000000000000100,
  //0b0001000000000000001000,
  //0b0000110000000000110000,
  //0b0000001100000011000000,
  //0b0000000011111100000000

  0b0000000011111100000000,
  0b0000001110000111000000,
  0b0000111000000001110000,
  0b0001100000000000011000,
  0b0011000000000000001100,
  0b0010000000000000000100,
  0b0110000000000000000110,
  0b0100000000000000000010,
  0b1100000000000000000011,
  0b1000000000000000000001,
  0b1000000000000000000001,
  0b1000000000000000000001,
  0b1000000000000000000001,
  0b1100000000000000000011,
  0b0100000000000000000010,
  0b0110000000000000000110,
  0b0010000000000000000100,
  0b0011000000000000001100,
  0b0001100000000000011000,
  0b0000111000000001110000,
  0b0000001110000111000000,
  0b0000000011111100000000

};
static constexpr std::array<uInt32, 20> radio_img_innercircle_large = {
  //0b00000001111110000000,
  //0b00000111111111100000,
  //0b00011111111111111000,
  //0b00111111111111111100,
  //0b00111111111111111100,
  //0b01111111111111111110,
  //0b01111111111111111110,
  //0b11111111111111111111,
  //0b11111111111111111111,
  //0b11111111111111111111,
  //0b11111111111111111111,
  //0b11111111111111111111,
  //0b11111111111111111111,
  //0b01111111111111111110,
  //0b01111111111111111110,
  //0b00111111111111111100,
  //0b00111111111111111100,
  //0b00011111111111111000,
  //0b00000111111111100000,
  //0b00000001111110000000

  0b00000000111100000000,
  0b00000011111111000000,
  0b00001111111111110000,
  0b00011111111111111000,
  0b00111111111111111100,
  0b00111111111111111100,
  0b01111111111111111110,
  0b01111111111111111110,
  0b11111111111111111111,
  0b11111111111111111111,
  0b11111111111111111111,
  0b11111111111111111111,
  0b01111111111111111110,
  0b01111111111111111110,
  0b00111111111111111100,
  0b00111111111111111100,
  0b00011111111111111000,
  0b00001111111111110000,
  0b00000011111111000000,
  0b00000000111100000000

};
static constexpr std::array<uInt32, 18> radio_img_active_large = {
  //0b000000111111000000,
  //0b000011111111110000,
  //0b000111111111111000,
  //0b001111111111111100,
  //0b011111111111111110,
  //0b011111111111111110,
  //0b111111111111111111,
  //0b111111111111111111,
  //0b111111111111111111,
  //0b111111111111111111,
  //0b111111111111111111,
  //0b111111111111111111,
  //0b011111111111111110,
  //0b011111111111111110,
  //0b001111111111111100,
  //0b000111111111111000,
  //0b000011111111110000,
  //0b000000111111000000

  0b000000000000000000,
  0b000000111111000000,
  0b000011111111110000,
  0b000111111111111000,
  0b001111111111111100,
  0b001111111111111100,
  0b011111111111111110,
  0b011111111111111110,
  0b011111111111111110,
  0b011111111111111110,
  0b011111111111111110,
  0b011111111111111110,
  0b001111111111111100,
  0b001111111111111100,
  0b000111111111111000,
  0b000011111111110000,
  0b000000111111000000,
  0b000000000000000000
};
static constexpr std::array<uInt32, 18> radio_img_inactive_large = {
  //0b000001111111100000,
  //0b000111111111111000,
  //0b001111111111111100,
  //0b011111100001111110,
  //0b011110000000011110,
  //0b111100000000001111,
  //0b111100000000001111,
  //0b111000000000000111,
  //0b111000000000000111,
  //0b111000000000000111,
  //0b111000000000000111,
  //0b111100000000001111,
  //0b111100000000001111,
  //0b011110000000011110,
  //0b011111100001111110,
  //0b001111111111111100,
  //0b010111111111111000,
  //0b000001111111100000

  0b000000000000000000,
  0b000000111111000000,
  0b000011111111110000,
  0b000111111111111000,
  0b001111100001111100,
  0b001111000000111100,
  0b011110000000011110,
  0b011100000000001110,
  0b011100000000001110,
  0b011100000000001110,
  0b011100000000001110,
  0b011110000000011110,
  0b001111000000111100,
  0b001111100001111100,
  0b000111111111111000,
  0b000011111111110000,
  0b000000111111000000,
  0b000000000000000000
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RadioButtonWidget::RadioButtonWidget(GuiObject* boss, const GUI::Font& font,
                                     int x, int y, const string& label,
                                     RadioButtonGroup* group, int cmd)
  : CheckboxWidget(boss, font, x, y, label, cmd),
    myGroup{group},
    _buttonSize{buttonSize(font)} // 14 | 22
{
  _flags = Widget::FLAG_ENABLED;
  _bgcolor = _bgcolorhi = kWidColor;

  _editable = true;

  if(_buttonSize == 14)
  {
    _outerCircle = radio_img_outercircle.data();
    _innerCircle = radio_img_innercircle.data();
  }
  else
  {
    _outerCircle = radio_img_outercircle_large.data();
    _innerCircle = radio_img_innercircle_large.data();
  }

  if(label.empty())
    _w = _buttonSize;
  else
    _w = font.getStringWidth(label) + _buttonSize + font.getMaxCharWidth() * 0.75;
  _h = font.getFontHeight() < static_cast<int>(_buttonSize)
      ? _buttonSize : font.getFontHeight();

  // Depending on font size, either the font or box will need to be
  // centered vertically
  if(_h > static_cast<int>(_buttonSize))  // center box
    _boxY = (_h - _buttonSize) / 2;
  else         // center text
    _textY = (_buttonSize - _font.getFontHeight()) / 2;

  setFill(CheckboxWidget::FillType::Normal);  // NOLINT
  myGroup->addWidget(this);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  if(isEnabled() && _editable && x >= 0 && x < _w && y >= 0 && y < _h)
  {
    if(!_state)
      setState(true);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonWidget::setState(bool state, bool send)
{
  if(_state != state)
  {
    _state = state;
    setDirty();
    if(_state && send)
      sendCommand(_cmd, _state, _id);
    if (state)
      myGroup->select(this);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonWidget::setFill(FillType type)
{
  switch(type)
  {
    case CheckboxWidget::FillType::Normal:
      _img = _buttonSize == 14 ? radio_img_active.data() : radio_img_active_large.data();
      break;
    case CheckboxWidget::FillType::Inactive:
      _img = _buttonSize == 14 ? radio_img_inactive.data(): radio_img_inactive_large.data();
      break;
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();

  // Draw the outer bounding circle
  s.drawBitmap(_outerCircle, _x, _y + _boxY,
               hilite ? kWidColorHi : kColor,
               _buttonSize);

  // Draw the inner bounding circle with enabled color
  s.drawBitmap(_innerCircle, _x + 1, _y + _boxY + 1,
               isEnabled() ? _bgcolor : kColor,
               _buttonSize - 2);

  // draw state
  if(_state)
    s.drawBitmap(_img, _x + 2, _y + _boxY + 2, isEnabled()
                 ? hilite ? kWidColorHi : kCheckColor
                 : kColor, _buttonSize - 4);

  // Finally draw the label
  s.drawString(_font, _label, _x + _buttonSize + _font.getMaxCharWidth() * 0.75, _y + _textY, _w,
               isEnabled() ? kTextColor : kColor);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonGroup::addWidget(RadioButtonWidget* widget)
{
  myWidgets.push_back(widget);
  // set first button as default
  widget->setState(myWidgets.size() == 1, false);  // NOLINT
  mySelected = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonGroup::select(const RadioButtonWidget* widget)
{
  uInt32 i = 0;

  for(const auto& w : myWidgets)
  {
    if(w == widget)
    {
      setSelected(i);
      break;
    }
    ++i;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RadioButtonGroup::setSelected(uInt32 selected)
{
  uInt32 i = 0;

  mySelected = selected;
  for(const auto& w : myWidgets)
  {
    (static_cast<RadioButtonWidget*>(w))->setState(i == mySelected);
    ++i;
  }
}
