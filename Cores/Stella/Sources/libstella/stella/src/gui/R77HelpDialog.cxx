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
#include "Dialog.hxx"
#include "Widget.hxx"
#include "Font.hxx"

#include "R77HelpDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
R77HelpDialog::R77HelpDialog(OSystem& osystem, DialogContainer& parent,
                             const GUI::Font& font)
  : Dialog(osystem, parent, font, "RetroN 77 help")
{
  const int lineHeight   = Dialog::lineHeight(),
            fontHeight   = Dialog::fontHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("Previous"),
            BUTTON_GAP = Dialog::buttonGap(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();
  WidgetArray wid;

  // Set real dimensions
  _w = 47 * fontWidth + HBORDER * 2;
  _h = (LINES_PER_PAGE + 2) * lineHeight + VBORDER * 2 + _th;

  // Add Previous, Next and Close buttons
  int xpos = HBORDER, ypos = _h - buttonHeight - VBORDER;
  myPrevButton =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
      "Previous", GuiObject::kPrevCmd);
  myPrevButton->clearFlags(Widget::FLAG_ENABLED);
  wid.push_back(myPrevButton);

  xpos += buttonWidth + BUTTON_GAP;
  myNextButton =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
      "Next", GuiObject::kNextCmd);
  wid.push_back(myNextButton);

  xpos = _w - buttonWidth - HBORDER;
  auto* b = new ButtonWidget(this, font, xpos, ypos,
                             buttonWidth, buttonHeight,
                             "Close", GuiObject::kCloseCmd);
  wid.push_back(b);
  addCancelWidget(b);

  xpos = HBORDER;  ypos = VBORDER + _th;
  myTitle = new StaticTextWidget(this, font, xpos, ypos, _w - HBORDER * 2, fontHeight,
    "", TextAlign::Center);

  const int jwidth = 11 * fontWidth, bwidth = jwidth;
  xpos = HBORDER;  ypos += lineHeight + 4;
  for (uInt8 i = 0; i < LINES_PER_PAGE; ++i)
  {
    myJoy[i] =
      new StaticTextWidget(this, font, xpos, ypos, jwidth,
        fontHeight, "", TextAlign::Left);
    myBtn[i] =
      new StaticTextWidget(this, font, xpos + jwidth, ypos, bwidth,
        fontHeight, "", TextAlign::Left);
    myDesc[i] =
      new StaticTextWidget(this, font, xpos + jwidth + bwidth, ypos, _w - jwidth - bwidth - HBORDER * 2,
        fontHeight, "", TextAlign::Left);
    ypos += fontHeight;
  }

  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void R77HelpDialog::loadConfig()
{
  displayInfo();
  setFocus(getFocusList()[1]); // skip initially disabled 'Previous' button
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void R77HelpDialog::updateStrings(uInt8 page, uInt8 lines, string& title)
{
  int i = 0;
  auto ADD_BIND = [&](const string & j = "", const string & b = "", const string & d = "")
  {
    myJoyStr[i] = j; myBtnStr[i] = b;  myDescStr[i] = d;  i++;
  };
  const auto ADD_TEXT = [&](const string & d) { ADD_BIND("", d.substr(0, 11), d.substr(11, 40)); };
  const auto ADD_LINE = [&]() { ADD_BIND("-----------", "-----------", "------------------------"); };

  switch (page)
  {
    case 1:
      title = "\\C\\c5Emulation commands";
      ADD_BIND("The joystic", "ks work nor", "mal and all console");
      ADD_BIND("buttons as ", "labeled exc", "ept of the following:");
      ADD_BIND();
      ADD_BIND("Joystick", "Console", "Command");
      ADD_LINE();
      ADD_BIND("\\c2Button 4", "4:3,16:9", "Open command dialog");
      ADD_BIND("\\c2Button 5", "FRY", "Return to launcher");
      ADD_BIND("\\c2Button 6", "\\c2-", "Open settings");
      ADD_BIND("\\c2Button 7", "\\c2-", "Rewind game");
      ADD_BIND("\\c2Button 8", "MODE", "Select");
      ADD_BIND("\\c2Button 9", "RESET", "Reset");
      break;

    case 2:
      title = "\\C\\c5Launcher commands";
      ADD_BIND("Joystick", "Console", "Command");
      ADD_LINE();
      ADD_BIND("Up", "SAVE", "Previous game");
      ADD_BIND("Down", "RESET", "Next game");
      ADD_BIND("Left", "LOAD", "Page up");
      ADD_BIND("Right", "MODE", "Page down");
      ADD_BIND("Button 1", "SKILL P1", "Start selected game");
      ADD_BIND("\\c2Button 2", "SKILL P2", "Open power-on options");
      ADD_BIND(" or hold Bu", "tton 1", "");
      ADD_BIND("\\c2Button 4", "Color,B/W", "Open settings");
      break;

    case 3:
      title = "\\C\\c5Dialog commands";
      ADD_BIND("Joystick", "Button", "Command");
      ADD_LINE();
      ADD_BIND("Up", "SAVE", "Increase current setting");
      ADD_BIND("Down", "RESET", "Decrease current setting");
      ADD_BIND("Left", "LOAD", "Previous dialog element");
      ADD_BIND("Right", "MODE", "Next dialog element");
      ADD_BIND("Button 1", "SKILL P1", "Select element");
      ADD_BIND("\\c2Button 2", "SKILL P2", "OK");
      ADD_BIND("\\c2Button 3", "4:3,16:9", "Previous tab");
      ADD_BIND(" or Button ", "1+Left", "");
      ADD_BIND("\\c2Button 4", "FRY", "Next tab");
      ADD_BIND(" or Button ", "1+Right", "");
      ADD_BIND("\\c2Button 6", "\\c2-", "Cancel");
      break;

    case 4:
      title = "\\C\\c5All commands";
      ADD_BIND();
      ADD_BIND("Remapped Ev", "ents", "");
      ADD_BIND();
      ADD_TEXT("Most commands can be remapped.");
      ADD_BIND();
      ADD_TEXT("Please use 'Advanced Settings'");
      ADD_TEXT("and consult the 'Options/Input" + ELLIPSIS + "'");
      ADD_TEXT("dialog for more information.");
      break;

    default:
      return;
  }

  while (i < lines) // NOLINT : i changes in lambda above
    ADD_BIND();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void R77HelpDialog::displayInfo()
{
  string titleStr;
  updateStrings(myPage, LINES_PER_PAGE, titleStr);

  formatWidget(titleStr, myTitle);
  for (uInt8 i = 0; i < LINES_PER_PAGE; ++i)
  {
    formatWidget(myJoyStr[i], myJoy[i]);
    formatWidget(myBtnStr[i], myBtn[i]);
    formatWidget(myDescStr[i], myDesc[i]);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void R77HelpDialog::formatWidget(const string& label, StaticTextWidget* widget)
{
  const char* str = label.c_str();
  TextAlign align = TextAlign::Left;
  ColorId color = kTextColor;

  while (str[0] == '\\')
  {
    switch (str[1])
    {
      case 'C':
        align = TextAlign::Center;
        break;

      case 'L':
        align = TextAlign::Left;
        break;

      case 'R':
        align = TextAlign::Right;
        break;

      case 'c':
        switch (str[2])
        {
          case '0':
            color = kTextColor;
            break;
          case '1':
            color = kTextColorHi;
            break;
          case '2':
            color = kColor;
            break;
          case '3':
            color = kShadowColor;
            break;
          case '4':
            color = kBGColor;
            break;
          case '5':
            color = kTextColorEm;
            break;
          default:
            break;
        }
        str++;
        break;

      default:
        break;
    }
    str += 2;
  }
  widget->setAlign(align);
  widget->setTextColor(color);
  widget->setLabel(str);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void R77HelpDialog::handleCommand(CommandSender * sender, int cmd,
  int data, int id)
{
  switch (cmd)
  {
    case GuiObject::kNextCmd:
      ++myPage;
      if (myPage >= myNumPages)
        myNextButton->clearFlags(Widget::FLAG_ENABLED);
      if (myPage >= 2)
        myPrevButton->setFlags(Widget::FLAG_ENABLED);

      displayInfo();
      break;

    case GuiObject::kPrevCmd:
      --myPage;
      if (myPage <= myNumPages)
        myNextButton->setFlags(Widget::FLAG_ENABLED);
      if (myPage <= 1)
        myPrevButton->clearFlags(Widget::FLAG_ENABLED);

      displayInfo();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}
