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

#include "Cart.hxx"
#include "Widget.hxx"
#include "Dialog.hxx"
#include "ToolTip.hxx"
#include "Settings.hxx"
#include "StellaKeys.hxx"
#include "EventHandler.hxx"
#include "TabWidget.hxx"
#include "TiaInfoWidget.hxx"
#include "TiaOutputWidget.hxx"
#include "TiaZoomWidget.hxx"
#include "AudioWidget.hxx"
#include "PromptWidget.hxx"
#include "CpuWidget.hxx"
#include "RiotRamWidget.hxx"
#include "RiotWidget.hxx"
#include "RomWidget.hxx"
#include "TiaWidget.hxx"
#include "CartDebugWidget.hxx"
#include "CartRamWidget.hxx"
#include "DataGridOpsWidget.hxx"
#include "EditTextWidget.hxx"
#include "MessageBox.hxx"
#include "Debugger.hxx"
#include "DebuggerParser.hxx"
#include "ConsoleFont.hxx"
#include "ConsoleBFont.hxx"
#include "ConsoleMediumFont.hxx"
#include "ConsoleMediumBFont.hxx"
#include "StellaMediumFont.hxx"
#include "OptionsDialog.hxx"
#include "BrowserDialog.hxx"
#include "StateManager.hxx"
#include "FrameManager.hxx"
#include "OSystem.hxx"
#include "Console.hxx"
#include "DebuggerDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DebuggerDialog::DebuggerDialog(OSystem& osystem, DialogContainer& parent,
                               int x, int y, int w, int h)
  : Dialog(osystem, parent, x, y, w, h)
{
  createFont();  // Font is sized according to available space

  addTiaArea();
  addTabArea();
  addStatusArea();
  addRomArea();

  // Inform the TIA output widget about its associated zoom widget
  myTiaOutput->setZoomWidget(myTiaZoom);

  setHelpAnchor(" ", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DebuggerDialog::~DebuggerDialog()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::loadConfig()
{
  if(myFocusedWidget == nullptr)
    // Set initial focus to prompt tab
    myFocusedWidget = myPrompt;
  // Restore focus
  setFocus(myFocusedWidget);

  myTab->loadConfig();
  myTiaInfo->loadConfig();
  myTiaOutput->loadConfig();
  myTiaZoom->loadConfig();
  myCpu->loadConfig();
  myRam->loadConfig();
  myRomTab->loadConfig();

  myMessageBox->setText("");
  myMessageBox->setToolTip("");
}

void DebuggerDialog::saveConfig()
{
  myFocusedWidget = _focusedWidget;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  if(key == KBDK_GRAVE && !StellaModTest::isShift(mod))
  {
    // Swallow backtick, so we don't see it when exiting the debugger
    instance().eventHandler().enableTextEvents(false);
  }

  // Process widget keys first
  if(_focusedWidget && _focusedWidget->handleKeyDown(key, mod))
    return;

  // special debugger keys first (cannot be remapped)
  if (StellaModTest::isControl(mod))
  {
    switch (key)
    {
      case KBDK_S:
        doStep();
        return;
      case KBDK_T:
        doTrace();
        return;
      case KBDK_L:
        doScanlineAdvance();
        return;
      case KBDK_F:
        doAdvance();
        return;
      default:
        break;
    }
  }

  // Do not handle emulation events which have the same mapping as menu events
  if(!instance().eventHandler().checkEventForKey(EventMode::kMenuMode, key, mod))
  {
    // handle emulation keys second (can be remapped)
    const Event::Type event = instance().eventHandler().eventForKey(EventMode::kEmulationMode, key, mod);
    switch(event)
    {
      case Event::ExitMode:
        // make consistent, exit debugger on key UP
        if(!repeated)
          myExitPressed = true;
        return;

        // events which can be handled 1:1
      case Event::ToggleP0Collision:
      case Event::ToggleP0Bit:
      case Event::ToggleP1Collision:
      case Event::ToggleP1Bit:
      case Event::ToggleM0Collision:
      case Event::ToggleM0Bit:
      case Event::ToggleM1Collision:
      case Event::ToggleM1Bit:
      case Event::ToggleBLCollision:
      case Event::ToggleBLBit:
      case Event::TogglePFCollision:
      case Event::TogglePFBit:
      case Event::ToggleFixedColors:
      case Event::ToggleCollisions:
      case Event::ToggleBits:

      case Event::ToggleTimeMachine:

      case Event::SaveState:
      case Event::SaveAllStates:
      case Event::PreviousState:
      case Event::NextState:
      case Event::LoadState:
      case Event::LoadAllStates:

      case Event::ConsoleColor:
      case Event::ConsoleBlackWhite:
      case Event::ConsoleColorToggle:
      case Event::Console7800Pause:
      case Event::ConsoleLeftDiffA:
      case Event::ConsoleLeftDiffB:
      case Event::ConsoleLeftDiffToggle:
      case Event::ConsoleRightDiffA:
      case Event::ConsoleRightDiffB:
      case Event::ConsoleRightDiffToggle:
        if(!repeated)
          instance().eventHandler().handleEvent(event);
        return;

        // events which need special handling in debugger
      case Event::TakeSnapshot:
        if(!repeated)
          instance().debugger().parser().run("saveSnap");
        return;

      case Event::Rewind1Menu:
        doRewind();
        return;

      case Event::Rewind10Menu:
        doRewind10();
        return;

      case Event::RewindAllMenu:
        doRewindAll();
        return;

      case Event::Unwind1Menu:
        doUnwind();
        return;

      case Event::Unwind10Menu:
        doUnwind10();
        return;

      case Event::UnwindAllMenu:
        doUnwindAll();
        return;

      default:
        break;
    }
  }
  Dialog::handleKeyDown(key, mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::handleKeyUp(StellaKey key, StellaMod mod)
{
  if(myExitPressed
     && Event::ExitMode == instance().eventHandler().eventForKey(EventMode::kEmulationMode, key, mod))
  {
    myExitPressed = false;
    instance().debugger().parser().run("run");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::handleCommand(CommandSender* sender, int cmd,
                                   int data, int id)
{
  // We reload the tabs in the cases where the actions could possibly
  // change their contents
  switch(cmd)
  {
    case kDDStepCmd:
      doStep();
      break;

    case kDDTraceCmd:
      doTrace();
      break;

    case kDDAdvCmd:
      doAdvance();
      break;

    case kDDSAdvCmd:
      doScanlineAdvance();
      break;

    case kDDRewindCmd:
      doRewind();
      break;

    case kDDUnwindCmd:
      doUnwind();
      break;

    case kDDRunCmd:
      doExitDebugger();
      break;

    case kDDExitFatalCmd:
      doExitRom();
      break;

    case kDDOptionsCmd:
      saveConfig();

      if(myOptions == nullptr)
      {
        uInt32 w = 0, h = 0;

        getDynamicBounds(w, h);
        myOptions = make_unique<OptionsDialog>(instance(), parent(), this, w, h,
                                               AppMode::debugger);
      }
      myOptions->open();

      loadConfig();
      break;

    case RomWidget::kInvalidateListing:
      // Only do a full redraw if the disassembly tab is actually showing
      myRom->invalidate(myRomTab->getActiveTab() == 0);
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doStep()
{
  instance().debugger().parser().run("step");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doTrace()
{
  instance().debugger().parser().run("trace");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doAdvance()
{
  instance().debugger().parser().run("frame #1");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doScanlineAdvance()
{
  instance().debugger().parser().run("scanLine #1");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doRewind()
{
  instance().debugger().parser().run("rewind");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doUnwind()
{
  instance().debugger().parser().run("unwind");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doRewind10()
{
  instance().debugger().parser().run("rewind #10");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doUnwind10()
{
  instance().debugger().parser().run("unwind #10");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doRewindAll()
{
  instance().debugger().parser().run("rewind #1000");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doUnwindAll()
{
  instance().debugger().parser().run("unwind #1000");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doExitDebugger()
{
  instance().debugger().parser().run("run");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::doExitRom()
{
  instance().debugger().parser().run("exitRom");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::createFont()
{
  const string fontSize = instance().settings().getString("dbg.fontsize");
  const int fontStyle = instance().settings().getInt("dbg.fontstyle");

  if(fontSize == "large")
  {
    // Large font doesn't use fontStyle at all
    myLFont = make_unique<GUI::Font>(GUI::stellaMediumDesc);
    myNFont = make_unique<GUI::Font>(GUI::stellaMediumDesc);
  }
  else if(fontSize == "medium")
    {
      switch(fontStyle)
      {
        case 1:
          myLFont = make_unique<GUI::Font>(GUI::consoleMediumBDesc);
          myNFont = make_unique<GUI::Font>(GUI::consoleMediumDesc);
          break;
        case 2:
          myLFont = make_unique<GUI::Font>(GUI::consoleMediumDesc);
          myNFont = make_unique<GUI::Font>(GUI::consoleMediumBDesc);
          break;
        case 3:
          myLFont = make_unique<GUI::Font>(GUI::consoleMediumBDesc);
          myNFont = make_unique<GUI::Font>(GUI::consoleMediumBDesc);
          break;
        default: // default to zero
          myLFont = make_unique<GUI::Font>(GUI::consoleMediumDesc);
          myNFont = make_unique<GUI::Font>(GUI::consoleMediumDesc);
          break;
      }
    }
  else
  {
    switch(fontStyle)
    {
      case 1:
        myLFont = make_unique<GUI::Font>(GUI::consoleBDesc);
        myNFont = make_unique<GUI::Font>(GUI::consoleDesc);
        break;
      case 2:
        myLFont = make_unique<GUI::Font>(GUI::consoleDesc);
        myNFont = make_unique<GUI::Font>(GUI::consoleBDesc);
        break;
      case 3:
        myLFont = make_unique<GUI::Font>(GUI::consoleBDesc);
        myNFont = make_unique<GUI::Font>(GUI::consoleBDesc);
        break;
      default: // default to zero
        myLFont = make_unique<GUI::Font>(GUI::consoleDesc);
        myNFont = make_unique<GUI::Font>(GUI::consoleDesc);
        break;
    }
  }
  tooltip().setFont(*myNFont);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::showFatalMessage(string_view msg)
{
  myFatalError = make_unique<GUI::MessageBox>(this, *myLFont, msg, _w-20, _h-20,
                                              kDDExitFatalCmd, "Exit ROM", "Continue", "Fatal error");
  myFatalError->show();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::addTiaArea()
{
  const Common::Rect& r = getTiaBounds();
  myTiaOutput =
    new TiaOutputWidget(this, *myNFont, r.x(), r.y(), r.w(), r.h());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::addTabArea()
{
  const Common::Rect& r = getTabBounds();
  constexpr int vBorder = 4;

  // The tab widget
  // Since there are two tab widgets in this dialog, we specifically
  // assign an ID of 0
  myTab = new TabWidget(this, *myLFont, r.x(), r.y() + vBorder,
                        r.w(), r.h() - vBorder);
  myTab->setID(0);
  addTabWidget(myTab);

  const int widWidth  = r.w() - vBorder;
  const int widHeight = r.h() - myTab->getTabHeight() - vBorder - 4;

  // The Prompt/console tab
  int tabID = myTab->addTab("Prompt");
  myPrompt = new PromptWidget(myTab, *myNFont,
                              2, 2, widWidth - 4, widHeight);
  myTab->setParentWidget(tabID, myPrompt);
  addToFocusList(myPrompt->getFocusList(), myTab, tabID);

  // The TIA tab
  tabID = myTab->addTab("TIA");
  auto* tia = new TiaWidget(myTab, *myLFont, *myNFont,
                            2, 2, widWidth, widHeight);
  myTab->setParentWidget(tabID, tia);
  addToFocusList(tia->getFocusList(), myTab, tabID);

  // The input/output tab (includes RIOT and INPTx from TIA)
  tabID = myTab->addTab("I/O");
  auto* riot = new RiotWidget(myTab, *myLFont, *myNFont,
                              2, 2, widWidth, widHeight);
  myTab->setParentWidget(tabID, riot);
  addToFocusList(riot->getFocusList(), myTab, tabID);

  // The Audio tab
  tabID = myTab->addTab("Audio");
  auto* aud = new AudioWidget(myTab, *myLFont, *myNFont,
                              2, 2, widWidth, widHeight);
  myTab->setParentWidget(tabID, aud);
  addToFocusList(aud->getFocusList(), myTab, tabID);

  myTab->setActiveTab(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::addStatusArea()
{
  const int lineHeight = myLFont->getLineHeight();
  const Common::Rect& r = getStatusBounds();
  constexpr int HBORDER = 10;
  const int VGAP = lineHeight / 3;

  const int xpos = r.x() + HBORDER;
  int ypos = r.y();
  myTiaInfo = new TiaInfoWidget(this, *myLFont, *myNFont, xpos, ypos, r.w() - HBORDER);

  ypos = myTiaInfo->getBottom() + VGAP;
  myTiaZoom = new TiaZoomWidget(this, *myNFont, xpos, ypos,
                                r.w() - HBORDER, r.h() - ypos - VGAP - lineHeight + 3);
  addToFocusList(myTiaZoom->getFocusList());

  ypos = myTiaZoom->getBottom() + VGAP;
  myMessageBox = new EditTextWidget(this, *myLFont, xpos, ypos,
                                    myTiaZoom->getWidth(), lineHeight);
  myMessageBox->setEditable(false, false);
  myMessageBox->clearFlags(Widget::FLAG_RETAIN_FOCUS);
  myMessageBox->setTextColor(kTextColorEm);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerDialog::addRomArea()
{
  static constexpr std::array<uInt32, 11> LEFT_ARROW = {
    0b0000010,
    0b0000110,
    0b0001110,
    0b0011110,
    0b0111110,
    0b1111110,
    0b0111110,
    0b0011110,
    0b0001110,
    0b0000110,
    0b0000010
  };
  static constexpr std::array<uInt32, 11> RIGHT_ARROW = {
    0b0100000,
    0b0110000,
    0b0111000,
    0b0111100,
    0b0111110,
    0b0111111,
    0b0111110,
    0b0111100,
    0b0111000,
    0b0110000,
    0b0100000
  };

  const Common::Rect& r = getRomBounds();
  constexpr int VBORDER = 4;
  WidgetArray wid1, wid2;
  ButtonWidget* b = nullptr;

  int bwidth  = myLFont->getStringWidth("Frame +1 "),
      bheight = myLFont->getLineHeight() + 2;
  int buttonX = r.x() + r.w() - bwidth - 5, buttonY = r.y() + 5;

  b = new ButtonWidget(this, *myLFont, buttonX, buttonY,
                       bwidth, bheight, "Step", kDDStepCmd, true);
  b->setToolTip("Ctrl+S");
  b->setHelpAnchor("GlobalButtons", true);
  wid2.push_back(b);
  buttonY += bheight + 4;
  b = new ButtonWidget(this, *myLFont, buttonX, buttonY,
                       bwidth, bheight, "Trace", kDDTraceCmd, true);
  b->setToolTip("Ctrl+T");
  b->setHelpAnchor("GlobalButtons", true);
  wid2.push_back(b);
  buttonY += bheight + 4;
  b = new ButtonWidget(this, *myLFont, buttonX, buttonY,
                       bwidth, bheight, "Scan +1", kDDSAdvCmd, true);
  b->setToolTip("Ctrl+L");
  b->setHelpAnchor("GlobalButtons", true);
  wid2.push_back(b);
  buttonY += bheight + 4;
  b = new ButtonWidget(this, *myLFont, buttonX, buttonY,
                       bwidth, bheight, "Frame +1", kDDAdvCmd, true);
  b->setToolTip("Ctrl+F");
  b->setHelpAnchor("GlobalButtons", true);
  wid2.push_back(b);
  buttonY += bheight + 4;
  b = new ButtonWidget(this, *myLFont, buttonX, buttonY,
                       bwidth, bheight, "Run", kDDRunCmd);
  b->setToolTip("Escape");
  b->setHelpAnchor("GlobalButtons", true);
  wid2.push_back(b);

  bwidth = bheight; // 7 + 12;
  bheight = bheight * 3 + 4 * 2;
  buttonX -= (bwidth + 5);
  buttonY = r.y() + 5;

  myRewindButton =
    new ButtonWidget(this, *myLFont, buttonX, buttonY,
                     bwidth, bheight, LEFT_ARROW.data(), 7, 11, kDDRewindCmd, true);
  myRewindButton->setToolTip("Alt[+Shift]+Left");
  myRewindButton->setHelpAnchor("GlobalButtons", true);
  myRewindButton->clearFlags(Widget::FLAG_ENABLED);

  buttonY += bheight + 4;
  bheight = (myLFont->getLineHeight() + 2) * 2 + 4 * 1;

  myUnwindButton =
    new ButtonWidget(this, *myLFont, buttonX, buttonY,
                     bwidth, bheight, RIGHT_ARROW.data(), 7, 11, kDDUnwindCmd, true);
  myUnwindButton->setToolTip("Alt[+Shift]+Right");
  myUnwindButton->setHelpAnchor("GlobalButtons", true);
  myUnwindButton->clearFlags(Widget::FLAG_ENABLED);

  int xpos = buttonX - 8*myLFont->getMaxCharWidth() - 20, ypos = 30;

  bwidth = myLFont->getStringWidth("Options " + ELLIPSIS);
  bheight = myLFont->getLineHeight() + 2;

  b = new ButtonWidget(this, *myLFont, xpos, r.y() + 5, bwidth, bheight,
                       "Options" + ELLIPSIS, kDDOptionsCmd);
  wid1.push_back(b);
  wid1.push_back(myRewindButton);
  wid1.push_back(myUnwindButton);

  auto* ops = new DataGridOpsWidget(this, *myLFont, xpos, ypos);

  const int max_w = xpos - r.x() - 10;
  xpos = r.x() + 10;  ypos = 5;
  myCpu = new CpuWidget(this, *myLFont, *myNFont, xpos, ypos, max_w);
  addToFocusList(myCpu->getFocusList());

  addToFocusList(wid1);
  addToFocusList(wid2);

  xpos = r.x() + 10;  ypos += myCpu->getHeight() + 10;
  myRam = new RiotRamWidget(this, *myLFont, *myNFont, xpos, ypos, r.w() - 10);
  //myRam->setHelpAnchor("M6532", true); // TODO: doesn't work
  addToFocusList(myRam->getFocusList());

  // Add the DataGridOpsWidget to any widgets which contain a
  // DataGridWidget which we want controlled
  myCpu->setOpsWidget(ops);
  myRam->setOpsWidget(ops);

  ////////////////////////////////////////////////////////////////////
  // Disassembly area

  xpos = r.x() + VBORDER;  ypos += myRam->getHeight() + 5;
  const int tabWidth  = r.w() - VBORDER - 1;
  const int tabHeight = r.h() - ypos - 1;

  // Since there are two tab widgets in this dialog, we specifically
  // assign an ID of 1
  myRomTab = new TabWidget(
      this, *myLFont, xpos, ypos, tabWidth, tabHeight);
  myRomTab->setID(1);
  addTabWidget(myRomTab);

  // The main disassembly tab
  int tabID = myRomTab->addTab("  Disassembly  ", TabWidget::AUTO_WIDTH);
  myRom = new RomWidget(myRomTab, *myLFont, *myNFont, 2, 2, tabWidth - 1,
                        tabHeight - myRomTab->getTabHeight() - 2);
  myRom->setHelpAnchor("Disassembly", true);
  myRomTab->setParentWidget(tabID, myRom);
  addToFocusList(myRom->getFocusList(), myRomTab, tabID);

  // The 'cart-specific' information tab (optional)
  tabID = myRomTab->addTab(" " + instance().console().cartridge().name() + " ", TabWidget::AUTO_WIDTH);
  myCartInfo = instance().console().cartridge().infoWidget(
    myRomTab, *myLFont, *myNFont, 2, 2, tabWidth - 1,
    tabHeight - myRomTab->getTabHeight() - 2);
  if(myCartInfo != nullptr)
  {
    //myCartInfo->setHelpAnchor("BankswitchInformation", true); // TODO: doesn't work
    myRomTab->setParentWidget(tabID, myCartInfo);
    addToFocusList(myCartInfo->getFocusList(), myRomTab, tabID);
    tabID = myRomTab->addTab("    States    ", TabWidget::AUTO_WIDTH);
  }

  // The 'cart-specific' state tab
  myCartDebug = instance().console().cartridge().debugWidget(
        myRomTab, *myLFont, *myNFont, 2, 2, tabWidth - 1,
        tabHeight - myRomTab->getTabHeight() - 2);
  if(myCartDebug)  // TODO - make this always non-null
  {
    myRomTab->setHelpAnchor("BankswitchInformation", true);
    myRomTab->setParentWidget(tabID, myCartDebug);
    addToFocusList(myCartDebug->getFocusList(), myRomTab, tabID);

    // The cartridge RAM tab
    if (myCartDebug->internalRamSize() > 0)
    {
      tabID = myRomTab->addTab(myCartDebug->tabLabel(), TabWidget::AUTO_WIDTH);
      myCartRam =
        new CartRamWidget(myRomTab, *myLFont, *myNFont, 2, 2, tabWidth - 1,
                tabHeight - myRomTab->getTabHeight() - 2, *myCartDebug);
      if(myCartRam)  // TODO - make this always non-null
      {
        myCartRam->setHelpAnchor("CartridgeRAMInformation", true);
        myRomTab->setParentWidget(tabID, myCartRam);
        addToFocusList(myCartRam->getFocusList(), myRomTab, tabID);
        myCartRam->setOpsWidget(ops);
      }
    }
  }

  myRomTab->setActiveTab(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect DebuggerDialog::getTiaBounds() const
{
  // The area showing the TIA image (NTSC and PAL supported, up to 274 lines without scaling)
  return {
    0, 0, 320,
    std::max<uInt32>(FrameManager::Metrics::baseHeightPAL, _h * 0.35)
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect DebuggerDialog::getRomBounds() const
{
  // The ROM area is the full area to the right of the tabs
  const Common::Rect& status = getStatusBounds();
  return {
    status.x() + status.w() + 1, 0,
    static_cast<uInt32>(_w), static_cast<uInt32>(_h)
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect DebuggerDialog::getStatusBounds() const
{
  // The status area is the full area to the right of the TIA image
  // extending as far as necessary
  // 30% of any space above 1030 pixels will be allocated to this area
  const Common::Rect& tia = getTiaBounds();

  return {
      tia.x() + tia.w() + 1,
      0,
      tia.x() + tia.w() + 225 + (_w > 1030 ? static_cast<int>(0.35 * (_w - 1030)) : 0),
      tia.y() + tia.h()
  };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Rect DebuggerDialog::getTabBounds() const
{
  // The tab area is the full area below the TIA image
  const Common::Rect& tia    = getTiaBounds();
  const Common::Rect& status = getStatusBounds();

  return {
    0, tia.y() + tia.h() + 1,
    status.x() + status.w() + 1, static_cast<uInt32>(_h)
  };
}
