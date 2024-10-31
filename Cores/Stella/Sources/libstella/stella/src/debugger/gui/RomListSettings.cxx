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
#include "Settings.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "Dialog.hxx"
#include "DialogContainer.hxx"
#include "RomListWidget.hxx"
#include "RomListSettings.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomListSettings::RomListSettings(GuiObject* boss, const GUI::Font& font)
  : Dialog(boss->instance(), boss->parent()),
    CommandSender(boss)
{
  const int buttonWidth  = font.getStringWidth("Disassemble @ current line") + 20,
            buttonHeight = font.getLineHeight() + 4;
  int xpos = 8, ypos = 8;
  WidgetArray wid;

  // Set PC to current line
  auto* setPC =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                     "Set PC @ current line", RomListWidget::kSetPCCmd);
  wid.push_back(setPC);

  // RunTo PC on current line
  ypos += buttonHeight + 4;
  auto* runtoPC =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                     "RunTo PC @ current line", RomListWidget::kRuntoPCCmd);
  wid.push_back(runtoPC);

  // Toggle timer
  ypos += buttonHeight + 4;
  auto* setTimer =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
      "Set timer @ current line", RomListWidget::kSetTimerCmd);
  wid.push_back(setTimer);

  // Re-disassemble
  ypos += buttonHeight + 4;
  auto* disasm =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                     "Disassemble @ current line", RomListWidget::kDisassembleCmd);
  wid.push_back(disasm);

  // Settings for Distella
  xpos += 4;  ypos += buttonHeight + 8;
  myShowTentative = new CheckboxWidget(this, font, xpos, ypos,
                                       "Show tentative code", RomListWidget::kTentativeCodeCmd);
  myShowTentative->setToolTip("Check to differentiate between tentative code\n"
                              "vs. data sections via static code analysis.");
  wid.push_back(myShowTentative);
  ypos += buttonHeight + 4;
  myShowAddresses = new CheckboxWidget(this, font, xpos, ypos,
                                       "Show PC addresses", RomListWidget::kPCAddressesCmd);
  myShowAddresses->setToolTip("Check to show program counter addresses as labels.");
  wid.push_back(myShowAddresses);
  ypos += buttonHeight + 4;
  myShowGFXBinary = new CheckboxWidget(this, font, xpos, ypos,
                                       "Show GFX as binary", RomListWidget::kGfxAsBinaryCmd);
  myShowGFXBinary->setToolTip("Check to allow editing GFX sections in binary format.");
  wid.push_back(myShowGFXBinary);
  ypos += buttonHeight + 4;
  myUseRelocation = new CheckboxWidget(this, font, xpos, ypos,
                                       "Use address relocation", RomListWidget::kAddrRelocationCmd);
  myUseRelocation->setToolTip("Check to relocate calls out of address range.");
  wid.push_back(myUseRelocation);

  // Set real dimensions
  _w = buttonWidth + 20;
  _h = ypos + buttonHeight + 8;

  addToFocusList(wid);

  // We don't have a close/cancel button, but we still want the cancel
  // event to be processed
  processCancelWithoutWidget(true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListSettings::show(uInt32 x, uInt32 y, const Common::Rect& bossRect, int data)
{
  const uInt32 scale = instance().frameBuffer().hidpiScaleFactor();
  _xorig = bossRect.x() + x * scale;
  _yorig = bossRect.y() + y * scale;

  // Only show if we're inside the visible area
  if(!bossRect.contains(_xorig, _yorig))
    return;

  _item = data;
  open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListSettings::setPosition()
{
  // First set position according to original coordinates
  surface().setDstPos(_xorig, _yorig);

  // Now make sure that the entire menu can fit inside the screen bounds
  // If not, we reset its position
  if(!instance().frameBuffer().screenRect().contains(
      _xorig, _yorig, surface().dstRect()))
    surface().setDstPos(_xorig, _yorig);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListSettings::loadConfig()
{
  myShowTentative->setState(instance().settings().getBool("dis.resolve"));
  myShowAddresses->setState(instance().settings().getBool("dis.showaddr"));
  myShowGFXBinary->setState(instance().settings().getString("dis.gfxformat") == "2");
  myUseRelocation->setState(instance().settings().getBool("dis.relocate"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListSettings::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  // Close dialog if mouse click is outside it (simulates a context menu)
  // Otherwise let the base dialog class process it
  if(x >= 0 && x < _w && y >= 0 && y < _h)
    Dialog::handleMouseDown(x, y, b, clickCount);
  else
    close();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomListSettings::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  // We remove the dialog when the user has selected an item
  // Make sure the dialog is removed before sending any commands,
  // since one consequence of sending a command may be to add another
  // dialog/menu
  close();

  switch(cmd)
  {
    case RomListWidget::kSetPCCmd:
    case RomListWidget::kRuntoPCCmd:
    {
      sendCommand(cmd, _item, -1);
      break;
    }
    case RomListWidget::kSetTimerCmd:
    {
      sendCommand(cmd, _item, -1);
      break;
    }
    case RomListWidget::kDisassembleCmd:
    {
      sendCommand(cmd, _item, -1);
      break;
    }
    case RomListWidget::kTentativeCodeCmd:
    {
      sendCommand(cmd, myShowTentative->getState(), -1);
      break;
    }
    case RomListWidget::kPCAddressesCmd:
    {
      sendCommand(cmd, myShowAddresses->getState(), -1);
      break;
    }
    case RomListWidget::kGfxAsBinaryCmd:
    {
      sendCommand(cmd, myShowGFXBinary->getState(), -1);
      break;
    }
    case RomListWidget::kAddrRelocationCmd:
    {
      sendCommand(cmd, myUseRelocation->getState(), -1);
      break;
    }
    default:
      break;
  }
}
