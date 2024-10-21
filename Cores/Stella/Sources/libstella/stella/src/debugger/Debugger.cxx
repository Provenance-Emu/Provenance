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

#include "Version.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "EventHandler.hxx"
#include "FSNode.hxx"
#include "Settings.hxx"
#include "DebuggerDialog.hxx"
#include "PromptWidget.hxx"
#include "DebuggerParser.hxx"
#include "StateManager.hxx"
#include "RewindManager.hxx"

#include "Console.hxx"
#include "System.hxx"
#include "M6502.hxx"
#include "Cart.hxx"

#include "CartDebug.hxx"
#include "CpuDebug.hxx"
#include "RiotDebug.hxx"
#include "TIADebug.hxx"

#include "TiaInfoWidget.hxx"
#include "EditTextWidget.hxx"

#include "RomWidget.hxx"
#include "Expression.hxx"
#include "YaccParser.hxx"

#include "TIA.hxx"
#include "Debugger.hxx"
#include "DispatchResult.hxx"

using Common::Base;

Debugger* Debugger::myStaticDebugger = nullptr;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Debugger::Debugger(OSystem& osystem, Console& console)
  : DialogContainer(osystem),
    myConsole{console},
    mySystem{console.system()}
{
  // Init parser
  myParser = make_unique<DebuggerParser>(*this, osystem.settings());

  // Create debugger subsystems
  myCpuDebug  = make_unique<CpuDebug>(*this, myConsole);
  myCartDebug = make_unique<CartDebug>(*this, myConsole, osystem);
  myRiotDebug = make_unique<RiotDebug>(*this, myConsole);
  myTiaDebug  = make_unique<TIADebug>(*this, myConsole);

  // Allow access to this object from any class
  // Technically this violates pure OO programming, but since I know
  // there will only be ever one instance of debugger in Stella,
  // I don't care :)
  myStaticDebugger = this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Debugger::~Debugger()
{
  delete myDialog;  myDialog = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::initialize()
{
  mySize = myOSystem.settings().getSize("dbg.res");
  const Common::Size& d = myOSystem.frameBuffer().desktopSize(BufferType::Debugger);

  // The debugger dialog is resizable, within certain bounds
  // We check those bounds now
  mySize.clamp(static_cast<uInt32>(DebuggerDialog::kSmallFontMinW), d.w,
               static_cast<uInt32>(DebuggerDialog::kSmallFontMinH), d.h);

  myOSystem.settings().setValue("dbg.res", mySize);

  delete myDialog;  myDialog = nullptr;
  myDialog = new DebuggerDialog(myOSystem, *this, 0, 0, mySize.w, mySize.h);

  myCartDebug->setDebugWidget(&(myDialog->cartDebug()));

  saveOldState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBInitStatus Debugger::initializeVideo()
{
  const string title = string("Stella ") + STELLA_VERSION + ": Debugger mode";
  return myOSystem.frameBuffer().createDisplay(
      title, BufferType::Debugger, mySize
  );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::start(string_view message, int address, bool read,
                     string_view toolTip)
{
  if(myOSystem.eventHandler().enterDebugMode())
  {
    myFirstLog = true;
    // This must be done *after* we enter debug mode,
    // so the message isn't erased
    ostringstream buf;
    buf << message;
    if(address > -1)
      buf << cartDebug().getLabel(address, read, 4);
    myDialog->message().setText(buf.str());
    myDialog->message().setToolTip(toolTip);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::startWithFatalError(string_view message)
{
  if(myOSystem.eventHandler().enterDebugMode())
  {
    // This must be done *after* we enter debug mode,
    // so the dialog is properly shown
    myDialog->showFatalMessage(message);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::quit()
{
  if(myOSystem.settings().getBool("dbg.autosave")
     && myDialog->prompt().isLoaded())
    myParser->run("save");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::exit(bool exitrom)
{
  if(exitrom)
    myOSystem.eventHandler().handleEvent(Event::ExitGame);
  else
  {
    myOSystem.eventHandler().leaveDebugMode();
    myOSystem.console().tia().clearPendingFrame();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Debugger::autoExec(StringList* history)
{
  ostringstream buf;

  // autoexec.script is always run
  const FSNode autoexec(myOSystem.baseDir().getPath() + "autoexec.script");
  buf << "autoExec():\n"
      << myParser->exec(autoexec, history) << '\n';

  // Also, "romname.script" if present
  const string path = myOSystem.userDir().getPath() + myOSystem.romFile().getNameWithExt(".script");
  const FSNode romname(path);
  buf << myParser->exec(romname, history) << '\n';

  // Init builtins
  for(const auto& func: ourBuiltinFunctions)
  {
    // TODO - check this for memory leaks
    const int res = YaccParser::parse(func.defn);
    if(res == 0)
      addFunction(func.name, func.defn, YaccParser::getResult(), true);
    else
      cerr << "ERROR in builtin function!\n";
  }
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BreakpointMap& Debugger::breakPoints() const
{
  return mySystem.m6502().breakPoints();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TrapArray& Debugger::readTraps() const
{
  return mySystem.m6502().readTraps();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TrapArray& Debugger::writeTraps() const
{
  return mySystem.m6502().writeTraps();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Debugger::run(string_view command)
{
  return myParser->run(command);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Debugger::invIfChanged(int reg, int oldReg)
{
  string ret;

  const bool changed = reg != oldReg;
  if(changed) ret += "\177";
  ret += Common::Base::toString(reg, Common::Base::Fmt::_16_2);
  if(changed) ret += "\177";

  return ret;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::reset()
{
  unlockSystem();
  mySystem.reset();
  lockSystem();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
/* Element 0 of args is the address. The remaining elements are the data
   to poke, starting at the given address.
*/
string Debugger::setRAM(IntArray& args)
{
  ostringstream buf;

  const size_t count = args.size();
  int address = args[0];
  for(size_t i = 1; i < count; ++i)
    mySystem.poke(address++, args[i]);

  buf << "changed " << (count-1) << " location";
  if(count != 2)
    buf << "s";
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::saveState(int state)
{
  // Saving a state is implicitly a read-only operation, so we keep the
  // system locked, so no changes can occur
  myOSystem.state().saveState(state);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::saveAllStates()
{
  // Saving states is implicitly a read-only operation, so we keep the
  // system locked, so no changes can occur
  myOSystem.state().rewindManager().saveAllStates();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::loadState(int state)
{
  // We're loading a new state, so we start with a clean slate
  mySystem.clearDirtyPages();

  // State loading could initiate a bankswitch, so we allow it temporarily
  unlockSystem();
  myOSystem.state().loadState(state);
  lockSystem();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::loadAllStates()
{
  // We're loading new states, so we start with a clean slate
  mySystem.clearDirtyPages();

  // State loading could initiate a bankswitch, so we allow it temporarily
  unlockSystem();
  myOSystem.state().rewindManager().loadAllStates();
  lockSystem();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Debugger::step(bool save)
{
  if(save)
    saveOldState();

  const uInt64 startCycle = mySystem.cycles();

  unlockSystem();
  myOSystem.console().tia().updateScanlineByStep().flushLineCache();
  lockSystem();

  if(save)
    addState("step");
  return static_cast<int>(mySystem.cycles() - startCycle);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// trace is just like step, except it treats a subroutine call as one
// instruction.

// This implementation is not perfect: it just watches the program counter,
// instead of tracking (possibly) nested JSR/RTS pairs. In particular, it
// will fail for recursive subroutine calls. However, with 128 bytes of RAM
// to share between stack and variables, I doubt any 2600 games will ever
// use recursion...

int Debugger::trace()
{
  // 32 is the 6502 JSR instruction:
  if(mySystem.peek(myCpuDebug->pc()) == 32)
  {
    saveOldState();

    const uInt64 startCycle = mySystem.cycles();
    const int targetPC = myCpuDebug->pc() + 3; // return address

    // set temporary breakpoint at target PC (if not existing already)
    const Int8 bank = myCartDebug->getBank(targetPC);
    if(!checkBreakPoint(targetPC, bank))
    {
      // add temporary breakpoint and remove later
      setBreakPoint(targetPC, bank, BreakpointMap::ONE_SHOT);
    }

    unlockSystem();
    mySystem.m6502().execute(11900000); // max. ~10 seconds
    myOSystem.console().tia().flushLineCache();
    lockSystem();

    addState("trace");
    return static_cast<int>(mySystem.cycles() - startCycle);
  }
  else
    return step();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::setBreakPoint(uInt16 addr, uInt8 bank, uInt32 flags) const
{
  if(checkBreakPoint(addr, bank))
    return false;

  breakPoints().add(addr, bank, flags);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::clearBreakPoint(uInt16 addr, uInt8 bank) const
{
  if(!checkBreakPoint(addr, bank))
    return false;

  breakPoints().erase(addr, bank);
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::checkBreakPoint(uInt16 addr, uInt8 bank) const
{
  return breakPoints().check(addr, bank);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::toggleBreakPoint(uInt16 addr, uInt8 bank) const
{
  if(checkBreakPoint(addr, bank))
    clearBreakPoint(addr, bank);
  else
    setBreakPoint(addr, bank);

  return breakPoints().check(addr, bank);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::addReadTrap(uInt16 t) const
{
  readTraps().initialize();
  readTraps().add(t);
}

void Debugger::addWriteTrap(uInt16 t) const
{
  writeTraps().initialize();
  writeTraps().add(t);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::addTrap(uInt16 t) const
{
  addReadTrap(t);
  addWriteTrap(t);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::removeReadTrap(uInt16 t) const
{
  readTraps().initialize();
  readTraps().remove(t);
}

void Debugger::removeWriteTrap(uInt16 t) const
{
  writeTraps().initialize();
  writeTraps().remove(t);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::removeTrap(uInt16 t) const
{
  removeReadTrap(t);
  removeWriteTrap(t);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::readTrap(uInt16 t) const
{
  return readTraps().isInitialized() && readTraps().isSet(t);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::writeTrap(uInt16 t) const
{
  return writeTraps().isInitialized() && writeTraps().isSet(t);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::log(string_view triggerMsg)
{
  const int pc = myCpuDebug->pc();

  if(myFirstLog)
  {
    ostringstream msg;

    msg << "Trigger:  Frame Scn Cy Pxl | PS       A  X  Y  SP | ";
    if(myCartDebug->romBankCount() > 1)
    {
      if(myCartDebug->romBankCount() > 9)
        msg << "Bk/";
      else
        msg << "B/";
    }
    msg << "Addr Code     Disasm";
    Logger::log(msg.str());
    myFirstLog = false;
  }

  ostringstream msg;

  msg << std::left << std::setw(10) << std::setfill(' ') << triggerMsg
    << Base::toString(myTiaDebug->frameCount(), Base::Fmt::_10_5) << " "
    << Base::toString(myTiaDebug->scanlines(), Base::Fmt::_10_3) << " "
    << Base::toString(myTiaDebug->clocksThisLine() / 3, Base::Fmt::_10_02) << " "
    << Base::toString(myTiaDebug->clocksThisLine() - 68, Base::Fmt::_10_3) << " | "
    << (myCpuDebug->n() ? "N" : "n")
    << (myCpuDebug->v() ? "V" : "v") << "-"
    << (myCpuDebug->b() ? "B" : "b")
    << (myCpuDebug->d() ? "D" : "d")
    << (myCpuDebug->i() ? "I" : "i")
    << (myCpuDebug->z() ? "Z" : "z")
    << (myCpuDebug->c() ? "C" : "c") << " "
    << Base::HEX2 << myCpuDebug->a() << " "
    << Base::HEX2 << myCpuDebug->x() << " "
    << Base::HEX2 << myCpuDebug->y() << " "
    << Base::HEX2 << myCpuDebug->sp() << " |";

  if(myCartDebug->romBankCount() > 1)
  {
    if(myCartDebug->romBankCount() > 9)
      msg << Base::toString(myCartDebug->getBank(pc), Base::Fmt::_10) << "/";
    else
      msg << " " << myCartDebug->getBank(pc) << "/";
  }
  else
    msg << " ";

  // First find the lines in the range, and determine the longest string
  const CartDebug::Disassembly& disasm = myCartDebug->disassembly();
  const uInt16 start = pc & 0xFFF;
  const size_t list_size = disasm.list.size();
  size_t pos = 0;

  for(pos = 0; pos < list_size; ++pos)
  {
    const CartDebug::DisassemblyTag& tag = disasm.list[pos];

    if((tag.address & 0xfff) >= start)
    {
      msg << Base::HEX4 << pc << " "
        << std::left << std::setw(8) << std::setfill(' ') << tag.bytes << " "
        << tag.disasm.substr(0, 7);

      if(tag.disasm.length() > 8)
        msg << tag.disasm.substr(8);
      break;
    }
  }
  Logger::log(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Debugger::peek(uInt16 addr, Device::AccessFlags flags)
{
  return mySystem.peek(addr, flags);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 Debugger::dpeek(uInt16 addr, Device::AccessFlags flags)
{
  return static_cast<uInt16>(mySystem.peek(addr, flags) |
                            (mySystem.peek(addr+1, flags) << 8));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::poke(uInt16 addr, uInt8 value, Device::AccessFlags flags)
{
  mySystem.poke(addr, value, flags);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
M6502& Debugger::m6502() const
{
  return mySystem.m6502();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Debugger::peekAsInt(int addr, Device::AccessFlags flags)
{
  return mySystem.peek(static_cast<uInt16>(addr), flags);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Debugger::dpeekAsInt(int addr, Device::AccessFlags flags)
{
  return mySystem.peek(static_cast<uInt16>(addr), flags) |
      (mySystem.peek(static_cast<uInt16>(addr+1), flags) << 8);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Device::AccessFlags Debugger::getAccessFlags(uInt16 addr) const
{
  return mySystem.getAccessFlags(addr);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::setAccessFlags(uInt16 addr, Device::AccessFlags flags)
{
  mySystem.setAccessFlags(addr, flags);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 Debugger::getBaseAddress(uInt32 addr, bool read)
{
  if((addr & 0x1080) == 0x0000) // (addr & 0b 0001 0000 1000 0000) == 0b 0000 0000 0000 0000
  {
    if(read)
      // ADDR_TIA read (%xxx0 xxxx 0xxx ????)
      return addr & 0x000f; // 0b 0000 0000 0000 1111
    else
      // ADDR_TIA write (%xxx0 xxxx 0x?? ????)
      return addr & 0x003f; // 0b 0000 0000 0011 1111
  }

  // ADDR_ZPRAM (%xxx0 xx0x 1??? ????)
  if((addr & 0x1280) == 0x0080) // (addr & 0b 0001 0010 1000 0000) == 0b 0000 0000 1000 0000
    return addr & 0x00ff; // 0b 0000 0000 1111 1111

  // ADDR_ROM
  if(addr & 0x1000)
    return addr & 0x1fff; // 0b 0001 1111 1111 1111

  // ADDR_IO read/write I/O registers (%xxx0 xx1x 1xxx x0??)
  if((addr & 0x1284) == 0x0280) // (addr & 0b 0001 0010 1000 0100) == 0b 0000 0010 1000 0000
    return addr & 0x0283; // 0b 0000 0010 1000 0011

  // ADDR_IO write timers (%xxx0 xx1x 1xx1 ?1??)
  if(!read && (addr & 0x1294) == 0x0294) // (addr & 0b 0001 0010 1001 0100) == 0b 0000 0010 1001 0100
    return addr & 0x029f; // 0b 0000 0010 1001 1111

  // ADDR_IO read timers (%xxx0 xx1x 1xxx ?1x0)
  if(read && (addr & 0x1285) == 0x0284) // (addr & 0b 0001 0010 1000 0101) == 0b 0000 0010 1000 0100
    return addr & 0x028c; // 0b 0000 0010 1000 1100

  // ADDR_IO read timer/PA7 interrupt (%xxx0 xx1x 1xxx x1x1)
  if(read && (addr & 0x1285) == 0x0285) // (addr & 0b 0001 0010 1000 0101) == 0b 0000 0010 1000 0101
    return addr & 0x0285; // 0b 0000 0010 1000 0101

  // ADDR_IO write PA7 edge control (%xxx0 xx1x 1xx0 x1??)
  if(!read && (addr & 0x1294) == 0x0284) // (addr & 0b 0001 0010 1001 0100) == 0b 0000 0010 1000 0100
    return addr & 0x0287; // 0b 0000 0010 1000 0111

  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::nextScanline(int lines)
{
  ostringstream buf;
  buf << "scanline + " << lines;

  saveOldState();

  unlockSystem();
  while(lines)
  {
    myOSystem.console().tia().updateScanline();
    --lines;
  }
  lockSystem();

  addState(buf.str());
  myOSystem.console().tia().flushLineCache();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::nextFrame(int frames)
{
  ostringstream buf;
  buf << "frame + " << frames;

  saveOldState();

  unlockSystem();
  DispatchResult dispatchResult;
  while(frames)
  {
    do
      myOSystem.console().tia().update(dispatchResult, myOSystem.console().emulationTiming().maxCyclesPerTimeslice());
    while (dispatchResult.getStatus() == DispatchResult::Status::debugger);
    --frames;
  }
  lockSystem();

  addState(buf.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::updateRewindbuttons(const RewindManager& r)
{
  myDialog->rewindButton().setEnabled(!r.atFirst());
  myDialog->unwindButton().setEnabled(!r.atLast());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 Debugger::windStates(uInt16 numStates, bool unwind, string& message)
{
  RewindManager& r = myOSystem.state().rewindManager();

  saveOldState();

  unlockSystem();

  const uInt64 startCycles = myOSystem.console().tia().cycles();
  const uInt16 winds = r.windStates(numStates, unwind);
  message = r.getUnitString(myOSystem.console().tia().cycles() - startCycles);

  lockSystem();

  updateRewindbuttons(r);
  return winds;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 Debugger::rewindStates(const uInt16 numStates, string& message)
{
  return windStates(numStates, false, message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 Debugger::unwindStates(const uInt16 numStates, string& message)
{
  return windStates(numStates, true, message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::clearAllBreakPoints() const
{
  breakPoints().clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::clearAllTraps() const
{
  readTraps().clearAll();
  writeTraps().clearAll();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Debugger::showWatches()
{
  return myParser->showWatches();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Debugger::stringToValue(string_view stringval)
{
  return myParser->decipher_arg(stringval);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::patchROM(uInt16 addr, uInt8 value)
{
  return myConsole.cartridge().patch(addr, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::saveOldState(bool clearDirtyPages)
{
  if(clearDirtyPages)
    mySystem.clearDirtyPages();

  lockSystem();
  myCartDebug->saveOldState();
  myCpuDebug->saveOldState();
  myRiotDebug->saveOldState();
  myTiaDebug->saveOldState();
  unlockSystem();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::addState(string_view rewindMsg)
{
  // Add another rewind level to the Time Machine buffer
  RewindManager& r = myOSystem.state().rewindManager();
  r.addState(rewindMsg);
  updateRewindbuttons(r);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::setStartState()
{
  // Lock the bus each time the debugger is entered, so we don't disturb anything
  lockSystem();

  // Save initial state and add it to the rewind list (except when in currently rewinding)
  const RewindManager& r = myOSystem.state().rewindManager();
  // avoid invalidating future states when entering the debugger e.g. during rewind
  if(r.atLast() && (myOSystem.eventHandler().state() != EventHandlerState::TIMEMACHINE
     || myOSystem.state().mode() == StateManager::Mode::Off))
    addState("enter debugger");
  else
    updateRewindbuttons(r);

  // Set the 're-disassemble' flag, but don't do it until the next scheduled time
  myDialog->rom().invalidate(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::setQuitState()
{
  myDialog->saveConfig();
  saveOldState();

  // Bus must be unlocked for normal operation when leaving debugger mode
  unlockSystem();

  // execute one instruction on quit. If we're
  // sitting at a breakpoint/trap, this will get us past it.
  // Somehow this feels like a hack to me, but I don't know why
  mySystem.m6502().execute(1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::addFunction(string_view name, string_view definition,
                           Expression* exp, bool builtin)
{
  myFunctions.emplace(name, unique_ptr<Expression>(exp));
  myFunctionDefs.emplace(name, definition);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::isBuiltinFunction(string_view name)
{
  return std::any_of(ourBuiltinFunctions.cbegin(), ourBuiltinFunctions.cend(),
      [&](const auto& func) { return name == func.name; });
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::delFunction(string_view name)
{
  const auto& iter = myFunctions.find(name);
  if(iter == myFunctions.end())
    return false;

  // We never want to delete built-in functions
  if(isBuiltinFunction(name))
      return false;

  myFunctions.erase(string{name});

  const auto& def_iter = myFunctionDefs.find(name);
  if(def_iter == myFunctionDefs.end())
    return false;

  myFunctionDefs.erase(string{name});
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Expression& Debugger::getFunction(string_view name) const
{
  const auto& iter = myFunctions.find(name);
  return iter != myFunctions.end() ? *(iter->second) : EmptyExpression;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& Debugger::getFunctionDef(string_view name) const
{
  const auto& iter = myFunctionDefs.find(name);
  return iter != myFunctionDefs.end() ? iter->second : EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Debugger::FunctionDefMap Debugger::getFunctionDefMap() const
{
  return myFunctionDefs;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Debugger::builtinHelp()
{
  ostringstream buf;
  size_t c_maxlen = 0, i_maxlen = 0;

  // Get column widths for aligned output (functions)
  for(const auto& func: ourBuiltinFunctions)
  {
    size_t len = func.name.size();
    if(len > c_maxlen)  c_maxlen = len;
    len = func.defn.size();
    if(len > i_maxlen)  i_maxlen = len;
  }

  buf << std::setfill(' ') << "\nBuilt-in functions:\n";
  for(const auto& func: ourBuiltinFunctions)
  {
    buf << std::setw(static_cast<int>(c_maxlen)) << std::left << func.name
        << std::setw(2) << std::right << "{"
        << std::setw(static_cast<int>(i_maxlen)) << std::left << func.defn
        << std::setw(4) << "}"
        << func.help
        << '\n';
  }

  // Get column widths for aligned output (pseudo-registers)
  c_maxlen = 0;
  for(const auto& reg: ourPseudoRegisters)
  {
    const size_t len = reg.name.size();
    if(len > c_maxlen)  c_maxlen = len;
  }

  buf << "\nPseudo-registers:\n";
  for(const auto& reg: ourPseudoRegisters)
  {
    buf << std::setw(static_cast<int>(c_maxlen)) << std::left << reg.name
        << std::setw(2) << " "
        << std::setw(static_cast<int>(i_maxlen)) << std::left << reg.help
        << '\n';
  }

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::getCompletions(string_view in, StringList& list) const
{
  // skip if filter equals "_" only
  if(!BSPF::equalsIgnoreCase(in, "_"))
  {
    for(const auto& iter: myFunctions)
    {
      const string_view l = iter.first;
      if(BSPF::matchesCamelCase(l, in))
        list.emplace_back(l);
    }

    for(const auto& reg: ourPseudoRegisters)
      if(BSPF::matchesCamelCase(reg.name, in))
        list.emplace_back(reg.name);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::lockSystem()
{
  mySystem.lockDataBus();
  myConsole.cartridge().lockHotspots();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Debugger::unlockSystem()
{
  mySystem.unlockDataBus();
  myConsole.cartridge().unlockHotspots();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Debugger::canExit() const
{
  return baseDialogIsActive();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::array<Debugger::BuiltinFunction, 18> Debugger::ourBuiltinFunctions = { {
  // left joystick:
  { "_joy0Left",    "!(*SWCHA & $40)", "Left joystick moved left" },
  { "_joy0Right",   "!(*SWCHA & $80)", "Left joystick moved right" },
  { "_joy0Up",      "!(*SWCHA & $10)", "Left joystick moved up" },
  { "_joy0Down",    "!(*SWCHA & $20)", "Left joystick moved down" },
  { "_joy0Fire",    "!(*INPT4 & $80)", "Left joystick fire button pressed" },

  // right joystick:
  { "_joy1Left",    "!(*SWCHA & $04)", "Right joystick moved left" },
  { "_joy1Right",   "!(*SWCHA & $08)", "Right joystick moved right" },
  { "_joy1Up",      "!(*SWCHA & $01)", "Right joystick moved up" },
  { "_joy1Down",    "!(*SWCHA & $02)", "Right joystick moved down" },
  { "_joy1Fire",    "!(*INPT5 & $80)", "Right joystick fire button pressed" },

  // console switches:
  { "_select",    "!(*SWCHB & $02)",  "Game Select pressed" },
  { "_reset",     "!(*SWCHB & $01)",  "Game Reset pressed" },
  { "_color",     "*SWCHB & $08",     "Color/BW set to Color" },
  { "_bw",        "!(*SWCHB & $08)",  "Color/BW set to BW" },
  { "_diff0B",    "!(*SWCHB & $40)",  "Left diff. set to B (easy)" },
  { "_diff0A",    "*SWCHB & $40",     "Left diff. set to A (hard)" },
  { "_diff1B",    "!(*SWCHB & $80)",  "Right diff. set to B (easy)" },
  { "_diff1A",    "*SWCHB & $80",     "Right diff. set to A (hard)" }
} };

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Names are defined here, but processed in YaccParser
std::array<Debugger::PseudoRegister, 18> Debugger::ourPseudoRegisters = {{
// Debugger::PseudoRegister Debugger::ourPseudoRegisters[NUM_PSEUDO_REGS] = {
  { "_bank",          "Currently selected bank" },
  { "_cClocks",       "Color clocks on current scanline" },
  { "_cyclesHi",      "Higher 32 bits of number of cycles since emulation started" },
  { "_cyclesLo",      "Lower 32 bits of number of cycles since emulation started" },
  { "_fCount",        "Number of frames since emulation started" },
  { "_fCycles",       "Number of cycles since frame started" },
  { "_fTimReadCycles","Number of cycles used by timer reads since frame started" },
  { "_fWsyncCycles",  "Number of cycles skipped by WSYNC since frame started" },
  { "_iCycles",       "Number of cycles of last instruction" },
  { "_inTim",         "Curent INTIM value" },
  { "_scan",          "Current scanline count" },
  { "_scanEnd",       "Scanline count at end of last frame" },
  { "_sCycles",       "Number of cycles in current scanline" },
  { "_timInt",        "Current TIMINT value" },
  { "_timWrapRead",   "Timer read wrapped on this cycle" },
  { "_timWrapWrite",  "Timer write wrapped on this cycle" },
  { "_vBlank",        "Whether vertical blank is enabled (1 or 0)" },
  { "_vSync",         "Whether vertical sync is enabled (1 or 0)" }
  // CPU address access functions:
  /*{ "_lastRead", "last CPU read address" },
  { "_lastWrite", "last CPU write address" },
  { "__lastBaseRead", "last CPU read base address" },
  { "__lastBaseWrite", "last CPU write base address" }*/
} };
//
