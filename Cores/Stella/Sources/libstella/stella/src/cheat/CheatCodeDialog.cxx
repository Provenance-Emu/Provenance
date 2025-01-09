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

#include "Cheat.hxx"
#include "CheatManager.hxx"
#include "CheckListWidget.hxx"
#include "DialogContainer.hxx"
#include "Dialog.hxx"
#include "Font.hxx"
#include "InputTextDialog.hxx"
#include "OSystem.hxx"
#include "Widget.hxx"

#include "CheatCodeDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CheatCodeDialog::CheatCodeDialog(OSystem& osystem, DialogContainer& parent,
                                 const GUI::Font& font)
  : Dialog(osystem, parent, font, "Cheat codes")
{
  const int lineHeight   = Dialog::lineHeight(),
            //fontHeight   = Dialog::fontHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("One shot "),
            VGAP         = Dialog::vGap(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();
  WidgetArray wid;
  ButtonWidget* b = nullptr;

  // Set real dimensions
  _w = 45 * fontWidth + HBORDER * 2;
  _h = _th + 11 * (lineHeight + 4) + VBORDER * 2;

  // List of cheats, with checkboxes to enable/disable
  int xpos = HBORDER, ypos = _th + VBORDER;
  myCheatList =
    new CheckListWidget(this, font, xpos, ypos, _w - buttonWidth - HBORDER * 2 - fontWidth,
                        _h - _th - buttonHeight - VBORDER * 3);
  myCheatList->setEditable(false);
  wid.push_back(myCheatList);

  xpos += myCheatList->getWidth() + fontWidth; ypos = _th + VBORDER;

  b = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                       "Add" + ELLIPSIS, kAddCheatCmd);
  wid.push_back(b);
  ypos += lineHeight + VGAP * 2;

  myEditButton =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                     "Edit" + ELLIPSIS, kEditCheatCmd);
  wid.push_back(myEditButton);
  ypos += lineHeight + VGAP * 2;

  myRemoveButton =
    new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                     "Remove", kRemCheatCmd);
  wid.push_back(myRemoveButton);
  ypos += lineHeight + VGAP * 2 * 3;

  b = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                       "One shot" + ELLIPSIS, kAddOneShotCmd);
  wid.push_back(b);

  // Inputbox which will pop up when adding/editing a cheat
  StringList labels;
  labels.emplace_back("Name       ");
  labels.emplace_back("Code (hex) ");
  myCheatInput = make_unique<InputTextDialog>(this, font, labels, "Cheat code");
  myCheatInput->setTarget(this);

  // Add filtering for each textfield
  const EditableWidget::TextFilter f0 = [](char c) {
    return isprint(c) && c != '\"' && c != ':';
  };
  myCheatInput->setTextFilter(f0, 0);

  const EditableWidget::TextFilter f1 = [](char c) {
    return (c >= 'a' && c <= 'f') || (c >= '0' && c <= '9');
  };
  myCheatInput->setTextFilter(f1, 1);
  myCheatInput->setToolTip("See Stella documentation for details.", 1);

  addToFocusList(wid);

  // Add OK and Cancel buttons
  wid.clear();
  addOKCancelBGroup(wid, font);
  addBGroupToFocusList(wid);

  setHelpAnchor("Cheats");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CheatCodeDialog::~CheatCodeDialog()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::loadConfig()
{
  // Load items from CheatManager
  // Note that the items are always in the same order/number as given in
  // the CheatManager, so the arrays will be one-to-one
  StringList l;
  BoolArray b;

  const CheatList& list = instance().cheat().list();
  for(const auto& c: list)
  {
    l.push_back(c->name());
    b.push_back(c->enabled());
  }
  myCheatList->setList(l, b);

  // Redraw the list, auto-selecting the first item if possible
  myCheatList->setSelected(!l.empty() ? 0 : -1);

  const bool enabled = !list.empty();
  myEditButton->setEnabled(enabled);
  myRemoveButton->setEnabled(enabled);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::saveConfig()
{
  // Inspect checkboxes for enable/disable codes
  const CheatList& list = instance().cheat().list();
  for(uInt32 i = 0; i < myCheatList->getList().size(); ++i)
  {
    if(myCheatList->getState(i))
      list[i]->enable();
    else
      list[i]->disable();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::addCheat()
{
  myCheatInput->show();    // Center input dialog over entire screen
  myCheatInput->setText("", 0);
  myCheatInput->setText("", 1);
  myCheatInput->setMessage("");
  myCheatInput->setFocus(0);
  myCheatInput->setEmitSignal(kCheatAdded);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::editCheat()
{
  const int idx = myCheatList->getSelected();
  if(idx < 0)
    return;

  const CheatList& list = instance().cheat().list();
  const string& name = list[idx]->name();
  const string& code = list[idx]->code();

  myCheatInput->show();    // Center input dialog over entire screen
  myCheatInput->setText(name, 0);
  myCheatInput->setText(code, 1);
  myCheatInput->setMessage("");
  myCheatInput->setFocus(1);
  myCheatInput->setEmitSignal(kCheatEdited);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::removeCheat()
{
  instance().cheat().remove(myCheatList->getSelected());
  loadConfig();  // reload the cheat list
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::addOneShotCheat()
{
  myCheatInput->show();    // Center input dialog over entire screen
  myCheatInput->setText("One-shot cheat", 0);
  myCheatInput->setText("", 1);
  myCheatInput->setMessage("");
  myCheatInput->setFocus(1);
  myCheatInput->setEmitSignal(kOneShotCheatAdded);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatCodeDialog::handleCommand(CommandSender* sender, int cmd,
                                    int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
      saveConfig();
      close();
      break;

    case GuiObject::kCloseCmd:
      close();
      break;

    case ListWidget::kDoubleClickedCmd:
      editCheat();
      break;

    case kAddCheatCmd:
      addCheat();
      break;

    case kEditCheatCmd:
      editCheat();
      break;

    case kCheatAdded:
    {
      const string& name = myCheatInput->getResult(0);
      const string& code = myCheatInput->getResult(1);
      if(CheatManager::isValidCode(code))
      {
        myCheatInput->close();
        instance().cheat().add(name, code);
        loadConfig();  // show changes onscreen
      }
      else
        myCheatInput->setMessage("Invalid code");
      break;
    }

    case kCheatEdited:
    {
      const string& name = myCheatInput->getResult(0);
      const string& code = myCheatInput->getResult(1);
      const bool enable = myCheatList->getSelectedState();
      const int idx = myCheatList->getSelected();
      if(CheatManager::isValidCode(code))
      {
        myCheatInput->close();
        instance().cheat().add(name, code, enable, idx);
        loadConfig();  // show changes onscreen
      }
      else
        myCheatInput->setMessage("Invalid code");
      break;
    }

    case kRemCheatCmd:
      removeCheat();
      break;

    case kAddOneShotCmd:
      addOneShotCheat();
      break;

    case kOneShotCheatAdded:
    {
      const string& name = myCheatInput->getResult(0);
      const string& code = myCheatInput->getResult(1);
      if(CheatManager::isValidCode(code))
      {
        myCheatInput->close();
        instance().cheat().addOneShot(name, code);
      }
      else
        myCheatInput->setMessage("Invalid code");
      break;
    }

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}
