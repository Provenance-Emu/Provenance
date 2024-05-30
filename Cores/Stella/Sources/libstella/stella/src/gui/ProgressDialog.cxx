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

#include "bspf.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "EventHandler.hxx"
#include "TimerManager.hxx"
#include "Widget.hxx"
#include "Dialog.hxx"
#include "Font.hxx"
#include "DialogContainer.hxx"
#include "ProgressDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ProgressDialog::ProgressDialog(GuiObject* boss, const GUI::Font& font,
                               string_view message)
  : Dialog(boss->instance(), boss->parent(), font)
{
  const int lineHeight   = Dialog::lineHeight(),
            fontHeight   = Dialog::fontHeight(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("Cancel"),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  const int lwidth = font.getStringWidth(message);
  WidgetArray wid;

  // Calculate real dimensions
  _w = HBORDER * 2 + std::max(lwidth, buttonWidth);
  _h = VBORDER * 2 + lineHeight * 2 + buttonHeight + VGAP * 6;

  const int xpos = HBORDER;
  int ypos = VBORDER;
  myMessage = new StaticTextWidget(this, font, xpos, ypos, lwidth, fontHeight,
                                   message, TextAlign::Center);
  myMessage->setTextColor(kTextColorEm);

  ypos += lineHeight + VGAP * 2;
  mySlider = new SliderWidget(this, font, xpos, ypos, lwidth, lineHeight,
                              "", 0, 0);
  mySlider->setMinValue(1);
  mySlider->setMaxValue(100);

  ypos += lineHeight + VGAP * 4;
  auto* b = new ButtonWidget(this, font, (_w - buttonWidth) / 2, ypos,
                             buttonWidth, buttonHeight, "Cancel",
                             Event::UICancel);
  wid.push_back(b);
  addCancelWidget(b);
  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ProgressDialog::setMessage(string_view message)
{
  const int buttonWidth  = Dialog::buttonWidth("Cancel"),
            HBORDER      = Dialog::hBorder();
  const int lwidth = _font.getStringWidth(message);
  // Recalculate real dimensions
  _w = HBORDER * 2 + std::max(lwidth, buttonWidth);

  myMessage->setWidth(lwidth);
  myMessage->setLabel(message);
  mySlider->setWidth(lwidth);

  _cancelWidget->setPosX((_w - buttonWidth) / 2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ProgressDialog::setRange(int start, int finish, int step)
{
  myStart = start;
  myFinish = finish;
  myStep = static_cast<int>((step / 100.0) * (myFinish - myStart + 1));

  mySlider->setMinValue(myStart + myStep);
  mySlider->setMaxValue(myFinish);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ProgressDialog::resetProgress()
{
  myLastTick = TimerManager::getTicks();
  myProgress = 0;
  mySlider->setValue(0);
  myIsCancelled = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ProgressDialog::setProgress(int progress)
{
  // Only increase the progress bar if some time has passed
  if(TimerManager::getTicks() - myLastTick > 100000) // update every 1/10th second
  {
    myLastTick = TimerManager::getTicks();
    mySlider->setValue(progress % (myFinish - myStart + 1));

    // Since this dialog is usually called in a tight loop that doesn't
    // yield, we need to manually:
    // - tell the framebuffer that a redraw is necessary
    // - poll the events
    // This isn't really an ideal solution, since all redrawing and
    // event handling is suspended until the dialog is closed
    instance().frameBuffer().update();
    instance().eventHandler().poll(TimerManager::getTicks());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ProgressDialog::incProgress()
{
  setProgress(++myProgress);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ProgressDialog::handleCommand(CommandSender* sender, int cmd,
                                   int data, int id)
{
  if(cmd == Event::UICancel)
    myIsCancelled = true;
  else
    Dialog::handleCommand(sender, cmd, data, 0);
}
