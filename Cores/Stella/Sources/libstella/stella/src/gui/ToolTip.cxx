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

#include "OSystem.hxx"
#include "Dialog.hxx"
#include "DialogContainer.hxx"
#include "Font.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Widget.hxx"

#include "ToolTip.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ToolTip::ToolTip(Dialog& dialog, const GUI::Font& font)
  : myDialog{dialog}
{
  myScale = myDialog.instance().frameBuffer().hidpiScaleFactor();

  setFont(font);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ToolTip::~ToolTip()
{
  myDialog.instance().frameBuffer().deallocateSurface(mySurface);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::setFont(const GUI::Font& font)
{
  myFont = &font;

  const int fontWidth = myFont->getMaxCharWidth(),
    fontHeight = myFont->getFontHeight();

  myTextXOfs = fontHeight < 24 ? 5 : 8;
  myTextYOfs = fontHeight < 24 ? 2 : 3;
  myWidth = fontWidth * MAX_COLUMNS + myTextXOfs * 2;
  myHeight = fontHeight * MAX_ROWS + myTextYOfs * 2;

  // unallocate
  myDialog.instance().frameBuffer().deallocateSurface(mySurface);
  mySurface = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const shared_ptr<FBSurface>& ToolTip::surface()
{
  if(mySurface == nullptr)
    mySurface = myDialog.instance().frameBuffer().allocateSurface(myWidth, myHeight);

  return mySurface;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::request()
{
  // Called each frame when a tooltip is wanted
  if(myFocusWidget && myTimer < DELAY_TIME * RELEASE_SPEED)
  {
    const string tip = myFocusWidget->getToolTip(myMousePos);

    if(!tip.empty())
    {
      myTipWidget = myFocusWidget;
      myTimer += RELEASE_SPEED;
      if(myTimer >= DELAY_TIME * RELEASE_SPEED)
        show(tip);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::update(const Widget* widget, const Common::Point& pos)
{
  // Called each mouse move
  myMousePos = pos;
  myFocusWidget = widget;

  if(myTipWidget != widget)
    release(false);

  if(!myTipShown)
    release(true);
  else
  {
    if(myTipWidget->changedToolTip(myTipPos, myMousePos))
    {
      const string tip = myTipWidget->getToolTip(myMousePos);

      if(!tip.empty())
        show(tip);
      else
        release(true);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::hide()
{
  if(myTipShown)
  {
    myTimer = 0;
    myTipWidget = myFocusWidget = nullptr;
    myTipShown = false;
    myDialog.instance().frameBuffer().setPendingRender();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::release(bool emptyTip)
{
  if(myTipShown)
  {
    myTipShown = false;
    myDialog.instance().frameBuffer().setPendingRender();
  }

  // After displaying a tip, slowly reset the timer to 0
  //  until a new tip is requested
  if((emptyTip || myTipWidget != myFocusWidget) && myTimer)
    myTimer--;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::show(string_view tip)
{
  myTipPos = myMousePos;

  const uInt32 maxWidth = std::min(myWidth - myTextXOfs * 2,
                                   static_cast<uInt32>(myFont->getStringWidth(tip)));

  surface()->fillRect(1, 1, maxWidth + myTextXOfs * 2 - 2, myHeight - 2, kWidColor);
  const int lines = std::min(MAX_ROWS,
      static_cast<uInt32>(surface()->drawString(*myFont, tip, myTextXOfs, myTextYOfs,
                                                maxWidth, myHeight - myTextYOfs * 2,
                                                kTextColor)));
  // Calculate maximum width of drawn string lines
  uInt32 width = 0;
  string inStr{tip};
  for(int i = 0; i < lines; ++i)
  {
    string leftStr, rightStr;

    surface()->splitString(*myFont, inStr, maxWidth, leftStr, rightStr);
    width = std::max(width, static_cast<uInt32>(myFont->getStringWidth(leftStr)));
    inStr = rightStr;
  }
  width += myTextXOfs * 2;

  // Calculate and set surface size and position
  const uInt32 height = std::min(myHeight, myFont->getFontHeight() * lines + myTextYOfs * 2);
  constexpr uInt32 V_GAP = 1;
  constexpr uInt32 H_CURSOR = 18;
  // Note: The rects include HiDPI scaling
  const Common::Rect& imageRect = myDialog.instance().frameBuffer().imageRect();
  const Common::Rect& dialogRect = myDialog.surface().dstRect();
  // Limit position to app size and adjust accordingly
  const Int32 xAbs = myTipPos.x + dialogRect.x() / myScale;
  const uInt32 yAbs = myTipPos.y + dialogRect.y() / myScale;
  Int32 x = std::min(xAbs, static_cast<Int32>(imageRect.w() / myScale - width));
  const uInt32 y = (yAbs + height + H_CURSOR > imageRect.h() / myScale)
    ? yAbs - height - V_GAP
    : yAbs + H_CURSOR / myScale + V_GAP;

  if(x < 0)
  {
    x = 0;
    width = std::min(width, imageRect.w() / myScale);
  }

  surface()->setSrcSize(width, height);
  surface()->setDstSize(width * myScale, height * myScale);
  surface()->setDstPos(x * myScale, y * myScale);
  surface()->frameRect(0, 0, width, height, kColor);

  myTipShown = true;
  myDialog.instance().frameBuffer().setPendingRender();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ToolTip::render()
{
  if(myTipShown)
    surface()->render();
}
