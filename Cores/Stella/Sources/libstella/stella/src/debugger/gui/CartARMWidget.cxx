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

#include <cmath>

#include "OSystem.hxx"
//#include "EditTextWidget.hxx"
#include "PopUpWidget.hxx"
#include "DataGridWidget.hxx"
#include "CartARMWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeARMWidget::CartridgeARMWidget(
    GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
    int x, int y, int w, int h, CartridgeARM& cart)
  : CartDebugWidget(boss, lfont, nfont, x, y, w, h),
    myCart{cart}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::addCycleWidgets(int xpos, int ypos)
{
  constexpr int INDENT = 20, VGAP = 4;
  VariantList items;

  auto* s = new StaticTextWidget(_boss, _font, xpos, ypos + 1, "ARM emulation cycles:");
  s->setToolTip("Cycle count enabled by developer settings.");
  xpos += INDENT; ypos += myLineHeight + VGAP;
  myIncCycles = new CheckboxWidget(_boss, _font, xpos, ypos + 1, "Increase 6507 cycles",
                                   kIncCyclesChanged);
  myIncCycles->setToolTip("Increase 6507 cycles with approximated ARM cycles.");
  myIncCycles->setTarget(this);

  myCycleFactor = new SliderWidget(_boss, _font, myIncCycles->getRight() + _fontWidth * 2, ypos - 1,
                                   _fontWidth * 10, _lineHeight, "Cycle factor", _fontWidth * 14,
                                   kFactorChanged, _fontWidth * 4, "%");
  myCycleFactor->setMinValue(90); myCycleFactor->setMaxValue(110);
  myCycleFactor->setTickmarkIntervals(4);
  myCycleFactor->setToolTip("Correct approximated ARM cycles by factor.");
  myCycleFactor->setTarget(this);

  ypos += (myLineHeight + VGAP) * 2;
  myCyclesLabel = new StaticTextWidget(_boss, _font, xpos, ypos + 1, "Cycles #");

  myPrevThumbCycles = new DataGridWidget(_boss, _font, myCyclesLabel->getRight(), ypos - 1,
                                         1, 1, 6, 32, Common::Base::Fmt::_10_6);
  myPrevThumbCycles->setEditable(false);
  myPrevThumbCycles->setToolTip("Approximated CPU cycles of last but one ARM run.\n");

  myThumbCycles = new DataGridWidget(_boss, _font,
                                     myPrevThumbCycles->getRight() + _fontWidth / 2, ypos - 1,
                                     1, 1, 6, 32, Common::Base::Fmt::_10_6);

  myThumbCycles->setEditable(false);
  myThumbCycles->setToolTip("Approximated CPU cycles of last ARM run.\n");

  s = new StaticTextWidget(_boss, _font, myCycleFactor->getLeft(), ypos + 1,
                           "Instructions #");

  myPrevThumbInstructions = new DataGridWidget(_boss, _font, s->getRight(), ypos - 1,
                                               1, 1, 6, 32, Common::Base::Fmt::_10_6);
  myPrevThumbInstructions->setEditable(false);
  myPrevThumbInstructions->setToolTip("Instructions of last but one ARM run.\n");

  myThumbInstructions = new DataGridWidget(_boss, _font,
                                           myPrevThumbInstructions->getRight() + _fontWidth / 2, ypos - 1,
                                           1, 1, 6, 32, Common::Base::Fmt::_10_6);
  myThumbInstructions->setEditable(false);
  myThumbInstructions->setToolTip("Instructions of last ARM run.\n");

  // add later to allow aligning
  ypos -= myLineHeight + VGAP;
  int pwidth = myThumbCycles->getRight() - myPrevThumbCycles->getLeft()
    - PopUpWidget::dropDownWidth(_font);

  items.clear();
  VarList::push_back(items, "AUTO",                        static_cast<Int32>(Thumbulator::ChipType::AUTO));
  VarList::push_back(items, "LPC2101" + ELLIPSIS + "3",    static_cast<Int32>(Thumbulator::ChipType::LPC2101));
  VarList::push_back(items, "LPC2104" + ELLIPSIS + "6 OC", static_cast<Int32>(Thumbulator::ChipType::LPC2104_OC));
  VarList::push_back(items, "LPC2104" + ELLIPSIS + "6",    static_cast<Int32>(Thumbulator::ChipType::LPC2104));
  VarList::push_back(items, "LPC213x",                     static_cast<Int32>(Thumbulator::ChipType::LPC213x));
  myChipType = new PopUpWidget(_boss, _font, xpos, ypos, pwidth, myLineHeight, items,
                               "Chip    ", 0, kChipChanged);
  myChipType->setToolTip("Select emulated ARM chip.");
  myChipType->setTarget(this);

  myLockMamMode = new CheckboxWidget(_boss, _font, myCycleFactor->getLeft(), ypos + 1, "MAM Mode",
                                     kMamLockChanged);
  myLockMamMode->setToolTip("Check to lock Memory Accelerator Module (MAM) mode.");
  myLockMamMode->setTarget(this);

  pwidth = myThumbInstructions->getRight() - myPrevThumbInstructions->getLeft()
    - PopUpWidget::dropDownWidth(_font);
  items.clear();
  VarList::push_back(items, "Off (0)", static_cast<uInt32>(Thumbulator::MamModeType::mode0));
  VarList::push_back(items, "Partial (1)", static_cast<uInt32>(Thumbulator::MamModeType::mode1));
  VarList::push_back(items, "Full (2)", static_cast<uInt32>(Thumbulator::MamModeType::mode2));
  VarList::push_back(items, "1 Cycle (X)", static_cast<uInt32>(Thumbulator::MamModeType::modeX));
  myMamMode = new PopUpWidget(_boss, _font, myPrevThumbInstructions->getLeft(), ypos,
                              pwidth, myLineHeight, items, "", 0, kMamModeChanged);
  myMamMode->setToolTip("Select emulated Memory Accelerator Module (MAM) mode.");
  myMamMode->setTarget(this);

  // define the tab order
  addFocusWidget(myIncCycles);
  addFocusWidget(myCycleFactor);
  addFocusWidget(myChipType);
  addFocusWidget(myLockMamMode);
  addFocusWidget(myMamMode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::saveOldState()
{
  myOldState.armPrevRun.clear();
  myOldState.armRun.clear();

  myOldState.mamMode = static_cast<uInt32>(myCart.mamMode());

  myOldState.armPrevRun.push_back(myCart.prevCycles());
  myOldState.armPrevRun.push_back(myCart.prevStats().instructions);

  myOldState.armRun.push_back(myCart.cycles());
  myOldState.armRun.push_back(myCart.stats().instructions);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::loadConfig()
{
  const bool devSettings = instance().settings().getBool("dev.settings");
  IntArray alist;
  IntArray vlist;
  BoolArray changed;

  myChipType->setSelectedIndex(static_cast<Int32>(instance().settings().getInt("dev.thumb.chiptype")
    - static_cast<int>(Thumbulator::ChipType::AUTO)));
  handleChipType();

  const bool isChanged = static_cast<uInt32>(myCart.mamMode()) != myOldState.mamMode;
  myMamMode->setSelectedIndex(static_cast<uInt32>(myCart.mamMode()), isChanged);
  myMamMode->setEnabled(devSettings && myLockMamMode->getState());
  myLockMamMode->setEnabled(devSettings);

  // ARM cycles
  myIncCycles->setState(instance().settings().getBool("dev.thumb.inccycles"));
  myCycleFactor->setValue(std::round(instance().settings().getFloat("dev.thumb.cyclefactor") * 100.F));
  handleArmCycles();

  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(myCart.prevCycles());
  changed.push_back(myCart.prevCycles() !=
    static_cast<uInt32>(myOldState.armPrevRun[0]));
  myPrevThumbCycles->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(myCart.prevStats().instructions);
  changed.push_back(myCart.prevStats().instructions !=
    static_cast<uInt32>(myOldState.armPrevRun[1]));
  myPrevThumbInstructions->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(myCart.cycles());
  changed.push_back(myCart.cycles() !=
    static_cast<uInt32>(myOldState.armRun[0]));
  myThumbCycles->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  alist.push_back(0);  vlist.push_back(myCart.stats().instructions);
  changed.push_back(myCart.stats().instructions !=
    static_cast<uInt32>(myOldState.armRun[1]));
  myThumbInstructions->setList(alist, vlist, changed);

  CartDebugWidget::loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::handleCommand(CommandSender* sender,
                                       int cmd, int data, int id)
{
  switch(cmd)
  {
    case kChipChanged:
      handleChipType();
      break;

    case kMamLockChanged:
      handleMamLock();
      break;

    case kMamModeChanged:
      handleMamMode();
      break;

    case kIncCyclesChanged:
    case kFactorChanged:
      handleArmCycles();
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::handleChipType()
{
  const bool devSettings = instance().settings().getBool("dev.settings");

  myChipType->setEnabled(devSettings);

  if(devSettings)
  {
    instance().settings().setValue("dev.thumb.chiptype",
      myChipType->getSelectedTag().toInt());

    const Thumbulator::ChipPropsType chipProps =
      myCart.setChipType(static_cast<Thumbulator::ChipType>
      (myChipType->getSelectedTag().toInt()));

    // update tooltip with currently selecte chip's properties
    string tip = myChipType->getToolTip(Common::Point(0, 0));
    ostringstream buf;
    tip = tip.substr(0, 25);

    buf << tip << "\nCurrent: " << chipProps.name << "\n"
      << chipProps.flashBanks << " flash bank"
      << (chipProps.flashBanks > 1 ? "s" : "") << ", "
      << chipProps.MHz << " MHz, "
      << chipProps.flashCycles - 1 << " wait states";
    myChipType->setToolTip(buf.str());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::handleMamLock()
{
  const bool checked = myLockMamMode->getState();

  myMamMode->setEnabled(checked);
  myCart.lockMamMode(checked);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::handleMamMode()
{
  // override MAM mode set by ROM
  const Int32 mode = myMamMode->getSelected();

  const string name = myMamMode->getSelectedName();
  myMamMode->setSelectedName(name + "XXX");

  instance().settings().setValue("dev.thumb.mammode", mode);
  myCart.setMamMode(static_cast<Thumbulator::MamModeType>(mode));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARMWidget::handleArmCycles()
{
  const bool devSettings = instance().settings().getBool("dev.settings");
  const bool enable = myIncCycles->getState();
  const double factor = static_cast<double>(myCycleFactor->getValue()) / 100.0;

  if(devSettings)
  {
    instance().settings().setValue("dev.thumb.inccycles", enable);
    instance().settings().setValue("dev.thumb.cyclefactor", factor);
  }

  myIncCycles->setEnabled(devSettings);
  myCycleFactor->setEnabled(devSettings);
  myCyclesLabel->setEnabled(devSettings);
  myThumbCycles->setEnabled(devSettings);
  myPrevThumbCycles->setEnabled(devSettings);

  myCart.incCycles(devSettings && enable);
  myCart.cycleFactor(factor);
  myCart.enableCycleCount(devSettings);
}
