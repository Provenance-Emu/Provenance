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
#include "FrameBuffer.hxx"
#include "EventHandler.hxx"
#include "Dialog.hxx"
#include "DialogContainer.hxx"
#include "Widget.hxx"
#include "EmulationDialog.hxx"
#include "VideoAudioDialog.hxx"
#include "InputDialog.hxx"
#include "UIDialog.hxx"
#include "SnapshotDialog.hxx"
#include "RomAuditDialog.hxx"
#include "GameInfoDialog.hxx"
#include "LoggerDialog.hxx"
#include "DeveloperDialog.hxx"
#include "HelpDialog.hxx"
#include "AboutDialog.hxx"
#include "OptionsDialog.hxx"
#include "Launcher.hxx"
#include "Settings.hxx"
#include "OptionsMenu.hxx"

#ifdef CHEATCODE_SUPPORT
  #include "CheatCodeDialog.hxx"
#endif

#include "bspf.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
OptionsDialog::OptionsDialog(OSystem& osystem, DialogContainer& parent,
                             GuiObject* boss, int max_w, int max_h, AppMode mode)
  : Dialog(osystem, parent, osystem.frameBuffer().font(), "Options"),
    myBoss{boss},
    myMode{mode}
{
  // do not show basic settings options in debugger
  const bool minSettings = osystem.settings().getBool("minimal_ui")
    && mode != AppMode::debugger;
  const int buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  const int HGAP      = Dialog::buttonGap(),
            rowHeight = buttonHeight + VGAP;
  int buttonWidth = Dialog::buttonWidth("Game Properties" + ELLIPSIS);
  _w = 2 * buttonWidth + HBORDER * 2 + HGAP;
  _h = 7 * rowHeight + VBORDER * 2 - VGAP + _th;

  int xoffset = HBORDER, yoffset = VBORDER + _th;
  WidgetArray wid;
  ButtonWidget* b{nullptr};

  if (minSettings)
  {
    auto* bw = new ButtonWidget(this, _font, xoffset, yoffset,
        _w - HBORDER * 2, buttonHeight, "Use Basic Settings", kBasSetCmd);
    wid.push_back(bw);
    yoffset += rowHeight + VGAP * 2;
    _h += rowHeight + VGAP * 2;
  }

  const auto ADD_OD_BUTTON = [&](string_view label, int cmd, string_view toolTip = EmptyString)
  {
    auto* bw = new ButtonWidget(this, _font, xoffset, yoffset,
                                buttonWidth, buttonHeight, label, cmd);
    bw->setToolTip(toolTip);
    yoffset += rowHeight;
    return bw;
  };

  b = ADD_OD_BUTTON("Video & Audio" + ELLIPSIS, kVidCmd,
    "Change display modes, colors, TV effects,\n"
    "volume, stereo mode" + ELLIPSIS);
  wid.push_back(b);

  b = ADD_OD_BUTTON("Emulation" + ELLIPSIS, kEmuCmd,
    "Change emulation speed, save state settings" + ELLIPSIS);
  wid.push_back(b);

  b = ADD_OD_BUTTON("Input" + ELLIPSIS, kInptCmd,
    "Map and configure keyboard, mouse and controllers.");
  wid.push_back(b);

  b = ADD_OD_BUTTON("User Interface" + ELLIPSIS, kUsrIfaceCmd,
    "Change themes, fonts, launcher layout\n"
    "and paths for ROMs and images.");
  wid.push_back(b);

  b = ADD_OD_BUTTON("Snapshots" + ELLIPSIS, kSnapCmd,
    "Define snapshot save location, format" + ELLIPSIS);
  wid.push_back(b);

  //yoffset += rowHeight;
  b = ADD_OD_BUTTON("Developer" + ELLIPSIS, kDevelopCmd,
    "Change options which support programming Atari 2600 games.");
  wid.push_back(b);

  // Move to second column
  xoffset += buttonWidth + HGAP;
  yoffset = minSettings ? VBORDER + _th + rowHeight + VGAP * 2 : VBORDER + _th;

  myGameInfoButton = ADD_OD_BUTTON("Game Properties" + ELLIPSIS, kInfoCmd,
    "Change game-specific info and options (TV format,\n"
    "console switches, controllers" + ELLIPSIS + ")");
  wid.push_back(myGameInfoButton);

  myCheatCodeButton = ADD_OD_BUTTON("Cheat Codes" + ELLIPSIS, kCheatCmd,
    "Use and manage cheat codes.");
#ifndef CHEATCODE_SUPPORT
  myCheatCodeButton->clearFlags(Widget::FLAG_ENABLED);
#endif
  wid.push_back(myCheatCodeButton);

  myRomAuditButton = ADD_OD_BUTTON("Audit ROMs" + ELLIPSIS, kAuditCmd,
    "Rename your ROMs according to Stella's internal database.");
  wid.push_back(myRomAuditButton);

  b = ADD_OD_BUTTON("System Logs" + ELLIPSIS, kLoggerCmd,
    "Configure, view and save Stella's system log.");
  wid.push_back(b);

  b = ADD_OD_BUTTON("Help" + ELLIPSIS, kHelpCmd,
    "Display Stella's essential keyboard commands.");
  wid.push_back(b);

  b = ADD_OD_BUTTON("About" + ELLIPSIS, kAboutCmd,
    "Display info about the installed Stella version.");
  wid.push_back(b);

  buttonWidth = Dialog::buttonWidth("   Close   ");
  xoffset -= (buttonWidth + HGAP) / 2;
  b = ADD_OD_BUTTON("Close", kExitCmd);
  wid.push_back(b);
  addCancelWidget(b);

  addToFocusList(wid);

  // Certain buttons are disabled depending on mode
  if(myMode == AppMode::launcher)
  {
    myCheatCodeButton->clearFlags(Widget::FLAG_ENABLED);
  }
  else
  {
    myRomAuditButton->clearFlags(Widget::FLAG_ENABLED);
  }

  setHelpAnchor("Options");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
OptionsDialog::~OptionsDialog()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OptionsDialog::loadConfig()
{
  // Determine whether we should show the 'Game Information' button
  // We always show it in emulation mode, or if a valid ROM is selected
  // in launcher mode
  switch(instance().eventHandler().state())
  {
    case EventHandlerState::EMULATION:
      myGameInfoButton->setFlags(Widget::FLAG_ENABLED);
      break;
    case EventHandlerState::LAUNCHER:
      if(!instance().launcher().selectedRomMD5().empty())
        myGameInfoButton->setFlags(Widget::FLAG_ENABLED);
      else
        myGameInfoButton->clearFlags(Widget::FLAG_ENABLED);
      break;
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OptionsDialog::handleCommand(CommandSender* sender, int cmd,
                                  int data, int id)
{
  switch(cmd)
  {
    case kBasSetCmd:
      // enable basic settings
      instance().settings().setValue("basic_settings", true);
      if (myMode != AppMode::emulator)
        close();
      else
        instance().eventHandler().leaveMenuMode();
      break;

    case kVidCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<VideoAudioDialog>(instance(), parent(), _font, w, h);
      myDialog->open();
      break;
    }
    case kEmuCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<EmulationDialog>(instance(), parent(), _font, w, h);
      myDialog->open();
      break;
    }
    case kInptCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<InputDialog>(instance(), parent(), _font, w, h);
      myDialog->open();
      break;
    }

    case kUsrIfaceCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<UIDialog>(instance(), parent(), _font, myBoss, w, h);
      myDialog->open();
      break;
    }

    case kSnapCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<SnapshotDialog>(instance(), parent(), _font, w, h);
      myDialog->open();
      break;
    }

    case kDevelopCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<DeveloperDialog>(instance(), parent(), _font, w, h);
      myDialog->open();
      break;
    }

    case kInfoCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<GameInfoDialog>(instance(), parent(), _font, this, w, h);
      myDialog->open();
      break;
    }

#ifdef CHEATCODE_SUPPORT
    case kCheatCmd:
      myDialog = make_unique<CheatCodeDialog>(instance(), parent(), _font);
      myDialog->open();
      break;
#endif

    case kAuditCmd:
    {
      uInt32 w = 0, h = 0;

      getDynamicBounds(w, h);
      myDialog = make_unique<RomAuditDialog>(instance(), parent(), _font, w, h);
      myDialog->open();
      break;
    }
    case kLoggerCmd:
    {
      uInt32 w = 0, h = 0;
      const bool uselargefont = getDynamicBounds(w, h);

      myDialog = make_unique<LoggerDialog>(instance(), parent(), _font, w, h, uselargefont);
      myDialog->open();
      break;
    }

    case kHelpCmd:
      myDialog = make_unique<HelpDialog>(instance(), parent(), _font);
      myDialog->open();
      break;

    case kAboutCmd:
      myDialog = make_unique<AboutDialog>(instance(), parent(), _font);
      myDialog->open();
      break;

    case kExitCmd:
      if(myMode != AppMode::emulator)
        close();
      else
        instance().eventHandler().leaveMenuMode();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}
