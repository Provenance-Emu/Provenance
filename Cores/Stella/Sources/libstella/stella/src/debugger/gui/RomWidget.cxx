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
#include "Debugger.hxx"
#include "CartDebug.hxx"
#include "DiStella.hxx"
#include "CpuDebug.hxx"
#include "GuiObject.hxx"
#include "Font.hxx"
#include "DataGridWidget.hxx"
#include "EditTextWidget.hxx"
#include "RomListWidget.hxx"
#include "RomWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomWidget::RomWidget(GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
                     int x, int y, int w, int h)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss)
{
  // Show current bank state
  int xpos = x, ypos = y + 7;
  auto* t = new StaticTextWidget(boss, lfont, xpos, ypos, "Info ");

  xpos += t->getRight();
  myBank = new EditTextWidget(boss, nfont, xpos, ypos-2,
                              _w - 2 - xpos, nfont.getLineHeight());
  myBank->setEditable(false);

  // Create rom listing
  xpos = x;  ypos += myBank->getHeight() + 4;

  myRomList = new RomListWidget(boss, lfont, nfont, xpos, ypos, _w - 4, _h - ypos - 2);
  myRomList->setTarget(this);
  addFocusWidget(myRomList);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::loadConfig()
{
  const Debugger& dbg = instance().debugger();
  CartDebug& cart = dbg.cartDebug();
  const auto& state = static_cast<const CartState&>(cart.getState());
  const auto& oldstate = static_cast<const CartState&>(cart.getOldState());

  // Fill romlist the current bank of source or disassembly
  myListIsDirty |= cart.disassemblePC(myListIsDirty);
  if(myListIsDirty)
  {
    myRomList->setList(cart.disassembly());
    myListIsDirty = false;
  }

  // Update romlist to point to current PC (if it has changed)
  const int pcline = cart.addressToLine(dbg.cpuDebug().pc());

  if(pcline >= 0 && pcline != myRomList->getHighlighted())
    myRomList->setHighlighted(pcline);

  // Set current bank state
  myBank->setText(state.bank, state.bank != oldstate.bank);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch(cmd)
  {
    case RomListWidget::kBPointChangedCmd:
      // 'data' is the line in the disassemblylist to be accessed
      toggleBreak(data);
      break;

    case RomListWidget::kRomChangedCmd:
      // 'data' is the line in the disassemblylist to be accessed
      // 'id' is the base to use for the data to be changed
      patchROM(data, myRomList->getText(), Common::Base::Fmt{id});
      break;

    case RomListWidget::kSetPCCmd:
      // 'data' is the line in the disassemblylist to be accessed
      setPC(data);
      break;

    case RomListWidget::kRuntoPCCmd:
      // 'data' is the line in the disassemblylist to be accessed
      runtoPC(data);
      break;

    case RomListWidget::kSetTimerCmd:
      // 'data' is the line in the disassemblylist to be accessed
      setTimer(data);
      break;

    case RomListWidget::kDisassembleCmd:
      // 'data' is the line in the disassemblylist to be accessed
      disassemble(data);
      break;

    case RomListWidget::kTentativeCodeCmd:
    {
      // 'data' is the boolean value
      DiStella::settings.resolveCode = data;
      instance().settings().setValue("dis.resolve",
          DiStella::settings.resolveCode);
      invalidate();
      break;
    }

    case RomListWidget::kPCAddressesCmd:
      // 'data' is the boolean value
      DiStella::settings.showAddresses = data;
      instance().settings().setValue("dis.showaddr",
          DiStella::settings.showAddresses);
      invalidate();
      break;

    case RomListWidget::kGfxAsBinaryCmd:
      // 'data' is the boolean value
      if(data)
      {
        DiStella::settings.gfxFormat = Common::Base::Fmt::_2;
        instance().settings().setValue("dis.gfxformat", "2");
      }
      else
      {
        DiStella::settings.gfxFormat = Common::Base::Fmt::_16;
        instance().settings().setValue("dis.gfxformat", "16");
      }
      invalidate();
      break;

    case RomListWidget::kAddrRelocationCmd:
      // 'data' is the boolean value
      DiStella::settings.rFlag = data;
      instance().settings().setValue("dis.relocate",
          DiStella::settings.rFlag);
      invalidate();
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::toggleBreak(int disasm_line)
{
  const uInt16 address = getAddress(disasm_line);

  if (address != 0)
  {
    const Debugger& debugger = instance().debugger();

    debugger.toggleBreakPoint(address, debugger.cartDebug().getBank(address));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::setPC(int disasm_line)
{
  const uInt16 address = getAddress(disasm_line);

  if(address != 0)
  {
    ostringstream command;
    command << "pc #" << address;
    instance().debugger().run(command.str());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::runtoPC(int disasm_line)
{
  const uInt16 address = getAddress(disasm_line);

  if(address != 0)
  {
    ostringstream command;
    command << "runtopc #" << address;
    const string& msg = instance().debugger().run(command.str());
    instance().frameBuffer().showTextMessage(msg);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::setTimer(int disasm_line)
{
  const uInt16 address = getAddress(disasm_line);

  if(address != 0)
  {
    ostringstream command;
    command << "timer #" << address << " " << instance().debugger().cartDebug().getBank(address);
    const string& msg = instance().debugger().run(command.str());
    instance().frameBuffer().showTextMessage(msg);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::disassemble(int disasm_line)
{
  const uInt16 address = getAddress(disasm_line);

  if(address != 0)
  {
    CartDebug& cart = instance().debugger().cartDebug();

    cart.disassembleAddr(address, true);
    invalidate();
    scrollTo(cart.addressToLine(address)); // the line might have been changed
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::patchROM(int disasm_line, string_view bytes,
                         Common::Base::Fmt base)
{
  const uInt16 address = getAddress(disasm_line);

  if(address != 0)
  {
    ostringstream command;

    // Temporarily set to correct base, so we don't have to prefix each byte
    // with the type of data
    const Common::Base::Fmt oldbase = Common::Base::format();

    Common::Base::setFormat(base);
    command << "rom #" << address << " " << bytes;
    instance().debugger().run(command.str());

    // Restore previous base
    Common::Base::setFormat(oldbase);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 RomWidget::getAddress(int disasm_line)
{
  const CartDebug::DisassemblyList& list =
    instance().debugger().cartDebug().disassembly().list;

  if (disasm_line < static_cast<int>(list.size()) && list[disasm_line].address != 0)
    return list[disasm_line].address;
  else
    return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomWidget::scrollTo(int line)
{
  myRomList->setSelected(line);
}
