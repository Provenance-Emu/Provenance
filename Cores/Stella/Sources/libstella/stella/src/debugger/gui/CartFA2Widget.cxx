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

#include "CartFA2.hxx"
#include "CartFA2Widget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeFA2Widget::CartridgeFA2Widget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeFA2& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart),
    myCartFA2{cart}
{
  int xpos = 2;
  const int ypos = initialize() + 12;

  const int bwidth = _font.getStringWidth("Erase") + 20;

  auto* t = new StaticTextWidget(boss, _font, xpos, ypos,
      _font.getStringWidth("Harmony flash memory "),
      myFontHeight, "Harmony flash memory ", TextAlign::Left);

  xpos += t->getWidth() + 4;
  myFlashErase =
    new ButtonWidget(boss, _font, xpos, ypos-4, bwidth, myButtonHeight,
                     "Erase", kFlashErase);
  myFlashErase->setTarget(this);
  addFocusWidget(myFlashErase);
  xpos += myFlashErase->getWidth() + 8;

  myFlashLoad =
    new ButtonWidget(boss, _font, xpos, ypos-4, bwidth, myButtonHeight,
                     "Load", kFlashLoad);
  myFlashLoad->setTarget(this);
  addFocusWidget(myFlashLoad);
  xpos += myFlashLoad->getWidth() + 8;

  myFlashSave =
    new ButtonWidget(boss, _font, xpos, ypos-4, bwidth, myButtonHeight,
                     "Save", kFlashSave);
  myFlashSave->setTarget(this);
  addFocusWidget(myFlashSave);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeFA2Widget::description()
{
  ostringstream info;

  info << "Modified FA RAM+, six or seven 4K banks\n"
       << "RAM+ can be loaded/saved to Harmony flash memory by accessing $"
       << Common::Base::HEX4 << 0xFFF4 << "\n"
       << CartridgeEnhancedWidget::description();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeFA2Widget::handleCommand(CommandSender* sender,
                                       int cmd, int data, int id)
{
  switch(cmd)
  {
    case kFlashErase:
      myCartFA2.flash(0);
      break;

    case kFlashLoad:
      myCartFA2.flash(1);
      break;

    case kFlashSave:
      myCartFA2.flash(2);
      break;

    default:
      CartridgeEnhancedWidget::handleCommand(sender, cmd, data, id);
  }
}
