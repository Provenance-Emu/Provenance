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
#include "FSNode.hxx"
#include "GuiObject.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "Settings.hxx"
#include "PopUpWidget.hxx"
#include "StringListWidget.hxx"
#include "BrowserDialog.hxx"
#include "StringParser.hxx"
#include "Widget.hxx"
#include "Font.hxx"
#include "Logger.hxx"
#include "LoggerDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LoggerDialog::LoggerDialog(OSystem& osystem, DialogContainer& parent,
                           const GUI::Font& font, int max_w, int max_h,
                           bool uselargefont)
  : Dialog(osystem, parent, font, "System logs")
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("Save log to disk" + ELLIPSIS),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  WidgetArray wid;

  // Set real dimensions
  // This is one dialog that can take as much space as is available
  setSize(4000, 4000, max_w, max_h);

  // Test listing of the log output
  int xpos = HBORDER, ypos = VBORDER + _th;
  myLogInfo = new StringListWidget(this, uselargefont ? font :
                  instance().frameBuffer().infoFont(), xpos, ypos, _w - 2 * xpos,
                  _h - buttonHeight - ypos - VBORDER - lineHeight - VGAP * 4, false);
  myLogInfo->setEditable(false);
  wid.push_back(myLogInfo);
  ypos += myLogInfo->getHeight() + VGAP * 2;

  // Level of logging (how much info to print)
  VariantList items;
  VarList::push_back(items, "None", static_cast<int>(Logger::Level::ERR));
  VarList::push_back(items, "Basic", static_cast<int>(Logger::Level::INFO));
  VarList::push_back(items, "Verbose", static_cast<int>(Logger::Level::DEBUG));
  myLogLevel =
    new PopUpWidget(this, font, xpos, ypos, font.getStringWidth("Verbose"),
                    lineHeight, items, "Log level ",
                    font.getStringWidth("Log level "));
  wid.push_back(myLogLevel);

  // Should log output also be shown on the console?
  xpos += myLogLevel->getWidth() + fontWidth * 4;
  myLogToConsole = new CheckboxWidget(this, font, xpos, ypos + 1, "Print to console");
  wid.push_back(myLogToConsole);

  // Add Save, OK and Cancel buttons
  auto* b = new ButtonWidget(this, font, HBORDER, _h - buttonHeight - VBORDER,
      buttonWidth, buttonHeight, "Save log to disk" + ELLIPSIS,
      GuiObject::kDefaultsCmd);
  wid.push_back(b);
  addOKCancelBGroup(wid, font);

  addToFocusList(wid);

  setHelpAnchor("Logs");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LoggerDialog::loadConfig()
{
  const StringParser parser(Logger::instance().logMessages());
  myLogInfo->setList(parser.stringList());
  myLogInfo->setSelected(0);
  myLogInfo->scrollToEnd();

  myLogLevel->setSelected(instance().settings().getString("loglevel"),
    static_cast<int>(Logger::Level::INFO));
  myLogToConsole->setState(instance().settings().getBool("logtoconsole"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LoggerDialog::saveConfig()
{
  const int loglevel = myLogLevel->getSelectedTag().toInt();
  const bool logtoconsole = myLogToConsole->getState();

  instance().settings().setValue("loglevel", loglevel);
  instance().settings().setValue("logtoconsole", logtoconsole);

  Logger::instance().setLogParameters(loglevel, logtoconsole);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LoggerDialog::saveLogFile(const FSNode& node)
{
  try
  {
    stringstream out;
    out << Logger::instance().logMessages();
    node.write(out);
    instance().frameBuffer().showTextMessage("System log saved");
  }
  catch(...)
  {
    instance().frameBuffer().showTextMessage("Error saving system log");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LoggerDialog::handleCommand(CommandSender* sender, int cmd,
                                 int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
      saveConfig();
      close();
      break;

    case GuiObject::kDefaultsCmd:
      BrowserDialog::show(this, _font, "Save Log as",
                          instance().userDir().getPath() + "stella.log",
                          BrowserDialog::Mode::FileSave,
                          [this](bool OK, const FSNode& node) {
                            if(OK) saveLogFile(node);
                          });
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}
