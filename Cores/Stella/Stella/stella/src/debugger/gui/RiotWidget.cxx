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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "Settings.hxx"
#include "DataGridWidget.hxx"
#include "EditTextWidget.hxx"
#include "FrameBuffer.hxx"
#include "GuiObject.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "RiotDebug.hxx"
#include "PopUpWidget.hxx"
#include "ToggleBitWidget.hxx"
#include "Widget.hxx"

#include "NullControlWidget.hxx"
#include "JoystickWidget.hxx"
#include "PaddleWidget.hxx"
#include "BoosterWidget.hxx"
#include "DrivingWidget.hxx"
#include "GenesisWidget.hxx"
#include "KeyboardWidget.hxx"
#include "AtariVoxWidget.hxx"
#include "SaveKeyWidget.hxx"
#include "AmigaMouseWidget.hxx"
#include "AtariMouseWidget.hxx"
#include "TrakBallWidget.hxx"
#include "QuadTariWidget.hxx"
#include "Joy2BPlusWidget.hxx"

#include "RiotWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RiotWidget::RiotWidget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss)
{
  const int fontWidth  = lfont.getMaxCharWidth(),
            fontHeight = lfont.getFontHeight(),
            lineHeight = lfont.getLineHeight();
  int xpos = 10, ypos = 25, lwidth = 8 * fontWidth, col = 0;
  StaticTextWidget* t = nullptr;
  VariantList items;

  // Set the strings to be used in the various bit registers
  // We only do this once because it's the state that changes, not the strings
  StringList off, on;
  for(int i = 0; i < 8; ++i)
  {
    off.push_back("0");
    on.push_back("1");
  }

  StringList labels;

#define CREATE_IO_REGS(desc, bits, bitsID, editable)                     \
  t = new StaticTextWidget(boss, lfont, xpos, ypos+2, lwidth, fontHeight,\
                           desc);                                        \
  xpos += t->getWidth() + 5;                                             \
  bits = new ToggleBitWidget(boss, nfont, xpos, ypos, 8, 1, 1, labels);  \
  bits->setTarget(this);                                                 \
  bits->setID(bitsID);                                                   \
  if(editable) addFocusWidget(bits); else bits->setEditable(false);      \
  bits->setList(off, on);

  // SWCHA bits in 'poke' mode
  labels.clear();
  CREATE_IO_REGS("SWCHA(W)", mySWCHAWriteBits, kSWCHABitsID, true)
  col = xpos + mySWCHAWriteBits->getWidth() + 25;  // remember this for adding widgets to the second column

  // SWACNT bits
  xpos = 10;  ypos += lineHeight + 5;
  CREATE_IO_REGS("SWACNT", mySWACNTBits, kSWACNTBitsID, true)

  // SWCHA bits in 'peek' mode
  xpos = 10;  ypos += lineHeight + 5;
  labels.clear();
  labels.push_back("Left right");
  labels.push_back("Left left");
  labels.push_back("Left down");
  labels.push_back("Left up");
  labels.push_back("Right right");
  labels.push_back("Right left");
  labels.push_back("Right down");
  labels.push_back("Right up");
  CREATE_IO_REGS("SWCHA(R)", mySWCHAReadBits, kSWCHARBitsID, true)

  // SWCHB bits in 'poke' mode
  xpos = 10;  ypos += 2 * lineHeight;
  labels.clear();
  CREATE_IO_REGS("SWCHB(W)", mySWCHBWriteBits, kSWCHBBitsID, true)

  // SWBCNT bits
  xpos = 10;  ypos += lineHeight + 5;
  CREATE_IO_REGS("SWBCNT", mySWBCNTBits, kSWBCNTBitsID, true)

  // SWCHB bits in 'peek' mode
  xpos = 10;  ypos += lineHeight + 5;
  labels.clear();
  labels.push_back("Right difficulty");
  labels.push_back("Left difficulty");
  labels.push_back("");
  labels.push_back("");
  labels.push_back("Color/B+W");
  labels.push_back("");
  labels.push_back("Select");
  labels.push_back("Reset");
  CREATE_IO_REGS("SWCHB(R)", mySWCHBReadBits, kSWCHBRBitsID, true)

  // Timer registers (R/W)
  static constexpr std::array<const char*, 4> writeNames = {
    "TIM1T", "TIM8T", "TIM64T", "T1024T"
  };
  xpos = 10;  ypos += 2*lineHeight;
  for(int row = 0; row < 4; ++row)
  {
    t = new StaticTextWidget(boss, lfont, xpos, ypos + row*lineHeight + 2,
                             lwidth, fontHeight, writeNames[row], TextAlign::Left);
  }
  xpos += t->getWidth() + 5;
  myTimWrite = new DataGridWidget(boss, nfont, xpos, ypos, 1, 4, 2, 8, Common::Base::Fmt::_16);
  myTimWrite->setTarget(this);
  myTimWrite->setID(kTimWriteID);
  addFocusWidget(myTimWrite);

  t = new StaticTextWidget(boss, lfont, myTimWrite->getRight() + _fontWidth, ypos + 2 , "#");
  myTimClocks = new DataGridWidget(boss, nfont, t->getRight() + _fontWidth / 2, ypos,
                                   1, 1, 6, 30, Common::Base::Fmt::_10_6);
  myTimClocks->setToolTip("Number of CPU cycles available for current timer interval.\n");
  myTimClocks->setTarget(this);
  myTimClocks->setEditable(false);

  // Timer registers (RO)
  static constexpr std::array<const char*, 5> readNames = {
    "INTIM", "TIMINT", "Total Clks", "INTIM Clks", "Divider  #"
  };
  xpos = 10;  ypos += myTimWrite->getHeight() + lineHeight / 2;
  for(int row = 0; row < 5; ++row)
  {
    t = new StaticTextWidget(boss, lfont, xpos, ypos + row * lineHeight + 2,
                             readNames[row]);
  }
  xpos += t->getWidth() + _fontWidth / 2;
  myTimRead = new DataGridWidget(boss, nfont, xpos, ypos, 1, 4, 4, 30, Common::Base::Fmt::_16);
  myTimRead->setToolTip(0, 1, "Timer interrupt flag in bit 7.\n");
  myTimRead->setToolTip(0, 2, "Number of CPU cycles since last TIMxxT write.\n");
  myTimRead->setTarget(this);
  myTimRead->setEditable(false);

  ypos += myTimRead->getHeight() - 1;
  myTimDivider = new DataGridWidget(boss, nfont, xpos, ypos, 1, 1, 4, 12, Common::Base::Fmt::_10_4);
  myTimDivider->setTarget(this);
  myTimDivider->setEditable(false);

  // Controller ports
  xpos = col;  ypos = 10;
  myLeftControl = addControlWidget(boss, lfont, xpos, ypos,
      instance().console().leftController());
  addToFocusList(myLeftControl->getFocusList());
  xpos += myLeftControl->getWidth() + 15;
  myRightControl = addControlWidget(boss, lfont, xpos, ypos,
      instance().console().rightController());
  addToFocusList(myRightControl->getFocusList());

  // TIA INPTx registers (R), left port
  static constexpr std::array<const char*, 3> contLeftReadNames = {
    "INPT0", "INPT1", "INPT4"
  };
  xpos = col;  ypos += myLeftControl->getHeight() + 2 * lineHeight;
  for(int row = 0; row < 3; ++row)
  {
    new StaticTextWidget(boss, lfont, xpos, ypos + row*lineHeight + 2,
                         5*fontWidth, fontHeight, contLeftReadNames[row], TextAlign::Left);
  }
  xpos += 5*fontWidth + 5;
  myLeftINPT = new DataGridWidget(boss, nfont, xpos, ypos, 1, 3, 2, 8, Common::Base::Fmt::_16);
  myLeftINPT->setTarget(this);
  myLeftINPT->setEditable(false);

  // TIA INPTx registers (R), right port
  static constexpr std::array<const char*, 3> contRightReadNames = {
    "INPT2", "INPT3", "INPT5"
  };
  xpos = col + myLeftControl->getWidth() + 15;
  for(int row = 0; row < 3; ++row)
  {
    new StaticTextWidget(boss, lfont, xpos, ypos + row*lineHeight + 2,
                         5*fontWidth, fontHeight, contRightReadNames[row], TextAlign::Left);
  }
  xpos += 5*fontWidth + 5;
  myRightINPT = new DataGridWidget(boss, nfont, xpos, ypos, 1, 3, 2, 8, Common::Base::Fmt::_16);
  myRightINPT->setTarget(this);
  myRightINPT->setEditable(false);

  // TIA INPTx VBLANK bits (D6-latch, D7-dump) (R)
  xpos = col + 20;  ypos += myLeftINPT->getHeight() + lineHeight;
  myINPTLatch = new CheckboxWidget(boss, lfont, xpos, ypos, "INPT latch (VBlank D6)");
  myINPTLatch->setTarget(this);
  myINPTLatch->setEditable(false);
  ypos += lineHeight + 5;
  myINPTDump = new CheckboxWidget(boss, lfont, xpos, ypos, "INPT dump to gnd (VBlank D7)");
  myINPTDump->setTarget(this);
  myINPTDump->setEditable(false);

  // PO & P1 difficulty switches
  int pwidth = lfont.getStringWidth("B/easy");
  lwidth = lfont.getStringWidth("Right Diff ");
  xpos = col;  ypos += 2 * lineHeight;
  const int col2_ypos = ypos;
  items.clear();
  VarList::push_back(items, "B/easy", "b");
  VarList::push_back(items, "A/hard", "a");
  myP0Diff = new PopUpWidget(boss, lfont, xpos, ypos, pwidth, lineHeight, items,
                             "Left Diff ", lwidth, kP0DiffChanged);
  myP0Diff->setTarget(this);
  addFocusWidget(myP0Diff);
  ypos += myP0Diff->getHeight() + 5;
  myP1Diff = new PopUpWidget(boss, lfont, xpos, ypos, pwidth, lineHeight, items,
                             "Right Diff ", lwidth, kP1DiffChanged);
  myP1Diff->setTarget(this);
  addFocusWidget(myP1Diff);

  // TV Type
  ypos += myP1Diff->getHeight() + 5;
  items.clear();
  VarList::push_back(items, "B&W", "bw");
  VarList::push_back(items, "Color", "color");
  myTVType = new PopUpWidget(boss, lfont, xpos, ypos, pwidth, lineHeight, items,
                             "TV Type ", lwidth, kTVTypeChanged);
  myTVType->setTarget(this);
  addFocusWidget(myTVType);

  // 2600/7800 mode
  lwidth = lfont.getStringWidth("Console") + 29;
  pwidth = lfont.getStringWidth("Atari 2600") + 6;
  new StaticTextWidget(boss, lfont, 10, ypos+1, "Console");
  myConsole = new EditTextWidget(boss, lfont, 10 + lwidth, ypos - 1, pwidth, lineHeight);
  myConsole->setEditable(false, true);
  addFocusWidget(myConsole);

  // Select and Reset
  xpos += myP0Diff->getWidth() + 20;  ypos = col2_ypos + 1;
  mySelect = new CheckboxWidget(boss, lfont, xpos, ypos, "Select",
                                CheckboxWidget::kCheckActionCmd);
  mySelect->setID(kSelectID);
  mySelect->setTarget(this);
  addFocusWidget(mySelect);

  ypos += myP0Diff->getHeight() + 5;
  myReset = new CheckboxWidget(boss, lfont, xpos, ypos, "Reset",
                               CheckboxWidget::kCheckActionCmd);
  myReset->setID(kResetID);
  myReset->setTarget(this);
  addFocusWidget(myReset);

  ypos += myP0Diff->getHeight() + 5;
  myPause = new CheckboxWidget(boss, lfont, xpos, ypos, "Pause",
                               CheckboxWidget::kCheckActionCmd);
  myPause->setID(kPauseID);
  myPause->setTarget(this);
  addFocusWidget(myPause);

  setHelpAnchor("IOTab", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RiotWidget::loadConfig()
{
#define IO_REGS_UPDATE(bits, s_bits)                          \
  changed.clear();                                            \
  for(uInt32 i = 0; i < state.s_bits.size(); ++i)             \
    changed.push_back(state.s_bits[i] != oldstate.s_bits[i]); \
  bits->setState(state.s_bits, changed);

  IntArray alist;
  IntArray vlist;
  BoolArray changed;

  // We push the enumerated items as addresses, and deal with the real
  // address in the callback (handleCommand)
  RiotDebug& riot = instance().debugger().riotDebug();
  const RiotState& state    = static_cast<const RiotState&>(riot.getState());
  const RiotState& oldstate = static_cast<const RiotState&>(riot.getOldState());

  // Update the SWCHA register booleans (poke mode)
  IO_REGS_UPDATE(mySWCHAWriteBits, swchaWriteBits)

  // Update the SWACNT register booleans
  IO_REGS_UPDATE(mySWACNTBits, swacntBits)

  // Update the SWCHA register booleans (peek mode)
  IO_REGS_UPDATE(mySWCHAReadBits, swchaReadBits)

  // Update the SWCHB register booleans (poke mode)
  IO_REGS_UPDATE(mySWCHBWriteBits, swchbWriteBits)

  // Update the SWBCNT register booleans
  IO_REGS_UPDATE(mySWBCNTBits, swbcntBits)

  // Update the SWCHB register booleans (peek mode)
  IO_REGS_UPDATE(mySWCHBReadBits, swchbReadBits)

  // Update TIA INPTx registers
  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(state.INPT0);
    changed.push_back(state.INPT0 != oldstate.INPT0);
  alist.push_back(1);  vlist.push_back(state.INPT1);
    changed.push_back(state.INPT1 != oldstate.INPT1);
  alist.push_back(4);  vlist.push_back(state.INPT4);
    changed.push_back(state.INPT4 != oldstate.INPT4);
  myLeftINPT->setList(alist, vlist, changed);
  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(2);  vlist.push_back(state.INPT2);
    changed.push_back(state.INPT2 != oldstate.INPT2);
  alist.push_back(3);  vlist.push_back(state.INPT3);
    changed.push_back(state.INPT3 != oldstate.INPT3);
  alist.push_back(5);  vlist.push_back(state.INPT5);
    changed.push_back(state.INPT5 != oldstate.INPT5);
  myRightINPT->setList(alist, vlist, changed);

  // Update TIA VBLANK bits
  myINPTLatch->setState(riot.vblank(6), state.INPTLatch != oldstate.INPTLatch);
  myINPTDump->setState(riot.vblank(7), state.INPTDump != oldstate.INPTDump);

  // Update timer write registers
  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(kTim1TID);  vlist.push_back(state.TIM1T);
    changed.push_back(state.TIM1T != oldstate.TIM1T);
  alist.push_back(kTim8TID);  vlist.push_back(state.TIM8T);
    changed.push_back(state.TIM8T != oldstate.TIM8T);
  alist.push_back(kTim64TID);  vlist.push_back(state.TIM64T);
    changed.push_back(state.TIM64T != oldstate.TIM64T);
  alist.push_back(kTim1024TID);  vlist.push_back(state.T1024T);
    changed.push_back(state.T1024T != oldstate.T1024T);
  myTimWrite->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);
  if(state.TIM1T)
    vlist.push_back((state.TIM1T  - 1) * 1);
  else if(state.TIM8T)
    vlist.push_back((state.TIM8T  - 1) * 8);
  else if(state.TIM64T)
    vlist.push_back((state.TIM64T - 1) * 64);
  else if(state.T1024T)
    vlist.push_back((state.T1024T - 1) * 1024);
  else
    vlist.push_back(0);
  changed.push_back(state.TIM1T != oldstate.TIM1T ||
                    state.TIM8T != oldstate.TIM8T ||
                    state.TIM64T != oldstate.TIM64T ||
                    state.T1024T != oldstate.T1024T);
  myTimClocks->setList(alist, vlist, changed);

  // Update timer read registers
  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(state.INTIM);
    changed.push_back(state.INTIM != oldstate.INTIM);
  alist.push_back(0);  vlist.push_back(state.TIMINT);
    changed.push_back(state.TIMINT != oldstate.TIMINT);
  alist.push_back(0);  vlist.push_back(state.TIMCLKS);
    changed.push_back(state.TIMCLKS != oldstate.TIMCLKS);
  alist.push_back(0);  vlist.push_back(state.INTIMCLKS);
    changed.push_back(state.INTIMCLKS != oldstate.INTIMCLKS);
  myTimRead->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(state.TIMDIV);
    changed.push_back(state.TIMDIV != oldstate.TIMDIV);
  myTimDivider->setList(alist, vlist, changed);

  // Console switches (inverted, since 'selected' in the UI
  // means 'grounded' in the system)
  myP0Diff->setSelectedIndex(riot.diffP0(), state.swchbReadBits[1] != oldstate.swchbReadBits[1]);
  myP1Diff->setSelectedIndex(riot.diffP1(), state.swchbReadBits[0] != oldstate.swchbReadBits[0]);

  bool devSettings = instance().settings().getBool("dev.settings");
  myConsole->setText(instance().settings().getString(devSettings ? "dev.console" : "plr.console") == "7800" ? "Atari 7800" : "Atari 2600");
  myConsole->setEditable(false, true);

  myTVType->setSelectedIndex(riot.tvType(), state.swchbReadBits[4] != oldstate.swchbReadBits[4]);
  myPause->setState(!riot.tvType(), state.swchbReadBits[4] != oldstate.swchbReadBits[4]);
  mySelect->setState(!riot.select(), state.swchbReadBits[6] != oldstate.swchbReadBits[6]);
  myReset->setState(!riot.reset(), state.swchbReadBits[7] != oldstate.swchbReadBits[7]);

  myLeftControl->loadConfig();
  myRightControl->loadConfig();

  handleConsole();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RiotWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  int value = -1;
  RiotDebug& riot = instance().debugger().riotDebug();

  switch(cmd)
  {
    case DataGridWidget::kItemDataChangedCmd:
      if(id == kTimWriteID)
      {
        switch(myTimWrite->getSelectedAddr())
        {
          case kTim1TID:
            riot.tim1T(myTimWrite->getSelectedValue());
            break;
          case kTim8TID:
            riot.tim8T(myTimWrite->getSelectedValue());
            break;
          case kTim64TID:
            riot.tim64T(myTimWrite->getSelectedValue());
            break;
          case kTim1024TID:
            riot.tim1024T(myTimWrite->getSelectedValue());
            break;
          default:
            break;
        }
      }
      break;

    case ToggleWidget::kItemDataChangedCmd:
      switch(id)
      {
        case kSWCHABitsID:
          value = Debugger::get_bits(mySWCHAWriteBits->getState());
          riot.swcha(value & 0xff);
          break;
        case kSWACNTBitsID:
          value = Debugger::get_bits(mySWACNTBits->getState());
          riot.swacnt(value & 0xff);
          break;
        case kSWCHBBitsID:
          value = Debugger::get_bits(mySWCHBWriteBits->getState());
          riot.swchb(value & 0xff);
          break;
        case kSWBCNTBitsID:
          value = Debugger::get_bits(mySWBCNTBits->getState());
          riot.swbcnt(value & 0xff);
          break;
        case kSWCHARBitsID:
        {
          value = Debugger::get_bits(mySWCHAReadBits->getState());
          ControllerLowLevel lport(instance().console().leftController());
          ControllerLowLevel rport(instance().console().rightController());
          lport.setPin(Controller::DigitalPin::One,   value & 0b00010000);
          lport.setPin(Controller::DigitalPin::Two,   value & 0b00100000);
          lport.setPin(Controller::DigitalPin::Three, value & 0b01000000);
          lport.setPin(Controller::DigitalPin::Four,  value & 0b10000000);
          rport.setPin(Controller::DigitalPin::One,   value & 0b00000001);
          rport.setPin(Controller::DigitalPin::Two,   value & 0b00000010);
          rport.setPin(Controller::DigitalPin::Three, value & 0b00000100);
          rport.setPin(Controller::DigitalPin::Four,  value & 0b00001000);
          break;
        }
        case kSWCHBRBitsID:
        {
          value = Debugger::get_bits(mySWCHBReadBits->getState());

          riot.reset( value & 0b00000001);
          riot.select(value & 0b00000010);
          riot.tvType(value & 0b00001000);
          riot.diffP0(value & 0b01000000);
          riot.diffP1(value & 0b10000000);
          break;
        }
        default:
          break;
      }
      break;

    case CheckboxWidget::kCheckActionCmd:
      switch(id)
      {
        case kSelectID:
          riot.select(!mySelect->getState());
          break;
        case kResetID:
          riot.reset(!myReset->getState());
          break;
        case kPauseID:
          handleConsole();
          break;
        default:
          break;
      }
      break;

    case kP0DiffChanged:
      riot.diffP0(myP0Diff->getSelectedTag().toString() != "b");
      break;

    case kP1DiffChanged:
      riot.diffP1(myP1Diff->getSelectedTag().toString() != "b");
      break;

    case kTVTypeChanged:
      handleConsole();
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ControllerWidget* RiotWidget::addControlWidget(GuiObject* boss, const GUI::Font& font,
        int x, int y, Controller& controller)
{
  switch(controller.type())
  {
    case Controller::Type::AmigaMouse:
      return new AmigaMouseWidget(boss, font, x, y, controller);
    case Controller::Type::AtariMouse:
      return new AtariMouseWidget(boss, font, x, y, controller);
    case Controller::Type::AtariVox:
      return new AtariVoxWidget(boss, font, x, y, controller);
    case Controller::Type::BoosterGrip:
      return new BoosterWidget(boss, font, x, y, controller);
    case Controller::Type::Driving:
      return new DrivingWidget(boss, font, x, y, controller);
    case Controller::Type::Genesis:
      return new GenesisWidget(boss, font, x, y, controller);
    case Controller::Type::Joy2BPlus:
      return new Joy2BPlusWidget(boss, font, x, y, controller);
    case Controller::Type::Joystick:
      return new JoystickWidget(boss, font, x, y, controller);
    case Controller::Type::Keyboard:
      return new KeyboardWidget(boss, font, x, y, controller);
//    case Controller::Type::KidVid:      // TODO - implement this
//    case Controller::Type::MindLink:    // TODO - implement this
//    case Controller::Type::Lightgun:    // TODO - implement this
    case Controller::Type::QuadTari:
      return new QuadTariWidget(boss, font, x, y, controller);
    case Controller::Type::Paddles:
      return new PaddleWidget(boss, font, x, y, controller);
    case Controller::Type::SaveKey:
      return new SaveKeyWidget(boss, font, x, y, controller);
    case Controller::Type::TrakBall:
      return new TrakBallWidget(boss, font, x, y, controller);
    default:
      return new NullControlWidget(boss, font, x, y, controller);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RiotWidget::handleConsole()
{
  RiotDebug& riot = instance().debugger().riotDebug();
  bool devSettings = instance().settings().getBool("dev.settings");
  bool is7800 = instance().settings().getString(devSettings ? "dev.console" : "plr.console") == "7800";

  myTVType->setEnabled(!is7800);
  myPause->setEnabled(is7800);
  if(is7800)
    myTVType->setSelectedIndex(myPause->getState() ? 0 : 1);
  else
    myPause->setState(myTVType->getSelected() == 0);
  riot.tvType(myTVType->getSelected());
}
