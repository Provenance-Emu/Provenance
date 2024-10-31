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
#include "System.hxx"
#include "M6502.hxx"
#include "FSNode.hxx"
#include "DiStella.hxx"
#include "Debugger.hxx"
#include "DebuggerParser.hxx"
#include "CpuDebug.hxx"
#include "OSystem.hxx"
#include "Settings.hxx"
#include "Version.hxx"
#include "Cart.hxx"
#include "CartDebug.hxx"
#include "CartDebugWidget.hxx"
#include "CartRamWidget.hxx"
#include "RomWidget.hxx"
#include "Base.hxx"
#include "Device.hxx"
#include "TIA.hxx"
#include "M6532.hxx"

using Common::Base;
using std::hex;
using std::dec;
using std::setfill;
using std::setw;
using std::left;
using std::right;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartDebug::CartDebug(Debugger& dbg, Console& console, const OSystem& osystem)
  : DebuggerSystem(dbg, console),
    myOSystem{osystem}
{
  // Add case sensitive compare for user labels
  // TODO - should user labels be case insensitive too?
  const auto usrCmp = [](const string& a, const string& b) { return a < b; };
  myUserAddresses = LabelToAddr(usrCmp);

  // Add case insensitive compare for system labels
  const auto sysCmp = [](const string& a, const string& b) {
      return BSPF::compareIgnoreCase(a, b) < 0;
  };
  mySystemAddresses = LabelToAddr(sysCmp);

  // Add Zero-page RAM addresses
  for(uInt16 i = 0x80; i <= 0xFF; ++i)
  {
    myState.rport.push_back(i);
    myState.wport.push_back(i);
    myOldState.rport.push_back(i);
    myOldState.wport.push_back(i);
  }

  // Create bank information for each potential bank, and an extra one for ZP RAM
  // ROM sizes greater than 4096 indicate multi-bank ROMs, but we handle only
  // 4K pieces at a time
  // ROM sizes less than 4K use the actual value
  size_t romSize = 0;
  myConsole.cartridge().getImage(romSize);

  BankInfo info;
  info.size = std::min<size_t>(romSize, myConsole.cartridge().bankSize());

  for(uInt32 i = 0; i < myConsole.cartridge().romBankCount(); ++i)
    myBankInfo.push_back(info);

  for(uInt32 i = 0; i < myConsole.cartridge().ramBankCount(); ++i)
    myBankInfo.push_back(info);

  info.size = 128;  // ZP RAM
  myBankInfo.push_back(info);

  // We know the address for the startup bank right now
  myBankInfo[myConsole.cartridge().startBank()].addressList.push_front(
    myDebugger.dpeek(0xfffc));
  addLabel("Start", myDebugger.dpeek(0xfffc, Device::DATA)); // TODO: ::CODE???

  // Add system equates
  for(uInt16 addr = 0x00; addr <= 0x0F; ++addr)
  {
    mySystemAddresses.emplace(ourTIAMnemonicR[addr], addr);
    myReserved.TIARead[addr] = false;
  }
  for(uInt16 addr = 0x00; addr <= 0x3F; ++addr)
  {
    mySystemAddresses.emplace(ourTIAMnemonicW[addr], addr);
    myReserved.TIAWrite[addr] = false;
  }
  for(uInt16 addr = 0x280; addr <= 0x29F; ++addr)
  {
    mySystemAddresses.emplace(ourIOMnemonic[addr-0x280], addr);
    myReserved.IOReadWrite[addr-0x280] = false;
  }
  for(uInt16 addr = 0x80; addr <= 0xFF; ++addr)
  {
    mySystemAddresses.emplace(ourZPMnemonic[addr-0x80], addr);
    myReserved.ZPRAM[addr-0x80] = false;
  }

  myReserved.Label.clear();
  myDisassembly.list.reserve(2048);

  // Add settings for Distella
  DiStella::settings.gfxFormat =
    myOSystem.settings().getInt("dis.gfxformat") == 16 ? Base::Fmt::_16 : Base::Fmt::_2;
  DiStella::settings.resolveCode =
    myOSystem.settings().getBool("dis.resolve");
  DiStella::settings.showAddresses =
    myOSystem.settings().getBool("dis.showaddr");
  DiStella::settings.aFlag = false; // Not currently configurable
  DiStella::settings.fFlag = true;  // Not currently configurable
  DiStella::settings.rFlag = myOSystem.settings().getBool("dis.relocate");
  DiStella::settings.bFlag = true;  // Not currently configurable
  DiStella::settings.bytesWidth = 8+1;  // TODO - configure based on window size
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const DebuggerState& CartDebug::getState()
{
  myState.ram.clear();
  for(auto addr: myState.rport)
    myState.ram.push_back(myDebugger.peek(addr));

  if(myDebugWidget)
    myState.bank = myDebugWidget->bankState();

  return myState;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebug::saveOldState()
{
  myOldState.ram.clear();
  for(auto addr: myOldState.rport)
    myOldState.ram.push_back(myDebugger.peek(addr));

  if(myDebugWidget)
  {
    myOldState.bank = myDebugWidget->bankState();
    myDebugWidget->saveOldState();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::lastReadAddress()
{
  return mySystem.m6502().lastReadAddress();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::lastWriteAddress()
{
  return mySystem.m6502().lastWriteAddress();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::lastReadBaseAddress()
{
  return mySystem.m6502().lastReadBaseAddress();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::lastWriteBaseAddress()
{
  return mySystem.m6502().lastWriteBaseAddress();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::toString()
{
  ostringstream buf;
  uInt32 bytesPerLine = 0;

  switch(Base::format())
  {
    case Base::Fmt::_16:
    case Base::Fmt::_10:
      bytesPerLine = 0x10;
      break;

    case Base::Fmt::_2:
      bytesPerLine = 0x04;
      break;

    case Base::Fmt::_DEFAULT:
    default:
      return DebuggerParser::red("invalid base, this is a BUG");
  }

  const auto& state    = static_cast<const CartState&>(getState());
  const auto& oldstate = static_cast<const CartState&>(getOldState());

  uInt32 curraddr = 0, bytesSoFar = 0;
  for(uInt32 i = 0; i < state.ram.size(); i += bytesPerLine, bytesSoFar += bytesPerLine)
  {
    // We detect different 'pages' of RAM when the addresses jump by
    // more than the number of bytes on the previous line, or when 256
    // bytes have been previously output
    if(state.rport[i] - curraddr > bytesPerLine || bytesSoFar >= 256)
    {
      char port[37];  // NOLINT (convert to stringstream)
      std::ignore = std::snprintf(port, 36, "%04x: (rport = %04x, wport = %04x)\n",
              state.rport[i], state.rport[i], state.wport[i]);
      port[2] = port[3] = 'x';
      buf << DebuggerParser::red(port);
      bytesSoFar = 0;
    }
    curraddr = state.rport[i];
    buf << Base::HEX2 << (curraddr & 0x00ff) << ": ";

    for(uInt32 j = 0; j < bytesPerLine; ++j)
    {
      buf << Debugger::invIfChanged(state.ram[i+j], oldstate.ram[i+j]) << " ";

      if(j == 0x07) buf << " ";
    }
    buf << '\n';
  }

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::disassembleAddr(uInt16 address, bool force)
{
  const Cartridge& cart = myConsole.cartridge();
  const int segCount = cart.segmentCount();
  // ROM/RAM bank or ZP-RAM?
  const int addrBank = (address & 0x1000)
    ? getBank(address) : static_cast<int>(myBankInfo.size()) - 1;

  if(segCount > 1)
  {
    bool changed = false;
    // myDisassembly.list must be cleared before calling disassemble(),
    // else the lineOfs in fillDisassemblyList will be too large
    myDisassembly.list.clear();
    myAddrToLineList.clear();

    myDisassembly.fieldwidth = 24;
    for(int seg = 0; seg < segCount; ++seg)
    {
      const int bank = cart.getSegmentBank(seg);
      Disassembly disassembly;
      AddrToLineList addrToLineList;
      BankInfo& info = myBankInfo[bank];

      info.offset = cart.bankOrigin(bank) | cart.bankSize() * seg;
      const uInt16 segAddress = bank == addrBank ? address : info.offset;
      // Disassemble segment
      changed |= disassemble(bank, segAddress, disassembly, addrToLineList, force);

       // Add extra empty line between segments
      if(seg < segCount - 1)
      {
        CartDebug::DisassemblyTag tag;
        tag.address = 0;
        tag.disasm = " ";
        disassembly.list.push_back(tag);
        addrToLineList.emplace(0, static_cast<uInt32>(disassembly.list.size() +
                               myDisassembly.list.size()) - 1);
      }
      // Aggregate segment disassemblies
      myDisassembly.list.insert(myDisassembly.list.end(),
                                disassembly.list.begin(), disassembly.list.end());
      myDisassembly.fieldwidth = std::max(myDisassembly.fieldwidth, disassembly.fieldwidth);
      myAddrToLineList.insert(addrToLineList.begin(), addrToLineList.end());
    }
    return changed;
  }
  else
    return disassemble(addrBank, address, myDisassembly, myAddrToLineList, force);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::disassemblePC(bool force)
{
  return disassembleAddr(myDebugger.cpuDebug().pc(), force);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::disassembleBank(int bank)
{
  // Provide no PC
  return disassemble(bank, 0xFFFF, myDisassembly, myAddrToLineList, true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::disassemble(int bank, uInt16 PC, Disassembly& disassembly,
                            AddrToLineList& addrToLineList, bool force)
{
  // Test current disassembly; don't re-disassemble if it hasn't changed
  // Also check if the current PC is in the current list
  const bool bankChanged = myConsole.cartridge().bankChanged();
  const int pcline = addressToLine(PC);
  const bool pcfound = (pcline != -1) && (static_cast<uInt32>(pcline) < disassembly.list.size()) &&
                       (disassembly.list[pcline].disasm[0] != '.');
  const bool pagedirty = (PC & 0x1000) ? mySystem.isPageDirty(0x1000, 0x1FFF) :
                                         mySystem.isPageDirty(0x80, 0xFF);
  const bool changed = !mySystem.autodetectMode() &&
                       (force || bankChanged || !pcfound || pagedirty);
  if(changed)
  {
    // Are we disassembling from ROM or ZP RAM?
    BankInfo& info = myBankInfo[bank];
      //(PC & 0x1000) ? myBankInfo[getBank(PC)] :
        //myBankInfo[myBankInfo.size()-1];

    // If the offset has changed, all old addresses must be 'converted'
    // For example, if the list contains any $fxxx and the address space is now
    // $bxxx, it must be changed
    const uInt16 offset = (PC & 0x1000) ? myConsole.cartridge().bankOrigin(bank, PC) : 0;
    AddressList& addresses = info.addressList;
    for(auto& i: addresses)
      i = (i & 0xFFF) + offset;

    // Only add addresses when absolutely necessary, to cut down on the
    // work that Distella has to do
    if(bankChanged || !pcfound)
    {
      AddressList::const_iterator i;
      for(i = addresses.cbegin(); i != addresses.cend(); ++i)
      {
        if(PC == *i)  // already present
          break;
      }
      // Otherwise, add the item at the end
      if(i == addresses.end())
      {
        addresses.push_back(PC);
        if(!DiStella::settings.resolveCode)
          addDirective(Device::AccessType::CODE, PC, PC, bank);
      }
    }
    // Always attempt to resolve code sections unless it's been
    // specifically disabled
    const bool found = fillDisassemblyList(info, disassembly, addrToLineList, PC);
    if(!found && DiStella::settings.resolveCode)
    {
      // Temporarily turn off code resolution
      DiStella::settings.resolveCode = false;
      fillDisassemblyList(info, disassembly, addrToLineList, PC);
      DiStella::settings.resolveCode = true;
    }
  }
  return changed;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::fillDisassemblyList(BankInfo& info, Disassembly& disassembly,
                                    AddrToLineList& addrToLineList, uInt16 search)
{
  disassembly.list.clear();
  addrToLineList.clear();
  // An empty address list means that DiStella can't do a disassembly
  if(info.addressList.empty())
    return false;

  disassembly.fieldwidth = 24 + myLabelLength;
  // line offset must be set before calling DiStella!
  auto lineOfs = static_cast<uInt32>(myDisassembly.list.size());
  const DiStella distella(*this, disassembly.list, info, DiStella::settings,
                          myDisLabels, myDisDirectives, myReserved);

  // Parts of the disassembly will be accessed later in different ways
  // We place those parts in separate maps, to speed up access
  bool found = false;

  myAddrToLineIsROM = info.offset & 0x1000;
  for(uInt32 i = 0; i < disassembly.list.size(); ++i)
  {
    const DisassemblyTag& tag = disassembly.list[i];
    const uInt16 address = tag.address & 0xFFF;

    // Exclude 'Device::ROW|NONE'; they don't have a valid address
    if(tag.type != Device::ROW && tag.type != Device::NONE)
    {
      // Create a mapping from addresses to line numbers
      addrToLineList.emplace(address, i + lineOfs);

      // Did we find the search value?
      if(address == (search & 0xFFF))
        found = true;
    }
  }
  return found;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::addressToLine(uInt16 address) const
{
  // Switching between ZP RAM address space and Cart/ROM address space
  // means the line isn't present
  if(!myAddrToLineIsROM != !(address & 0x1000))
    return -1;

  const auto& iter = myAddrToLineList.find(address & 0xFFF);
  return iter != myAddrToLineList.end() ? iter->second : -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::disassembleLines(uInt16 start, uInt16 lines) const
{
  // Fill the string with disassembled data
  start &= 0xFFF;
  ostringstream buffer;

  // First find the lines in the range, and determine the longest string
  const size_t list_size = myDisassembly.list.size();
  size_t begin = list_size, end = 0, length = 0;
  for(end = 0; end < list_size && lines > 0; ++end)
  {
    const CartDebug::DisassemblyTag& tag = myDisassembly.list[end];
    if((tag.address & 0xfff) >= start)
    {
      if(begin == list_size) begin = end;
      if(tag.type != Device::ROW)
        length = std::max(length, tag.disasm.length());

      --lines;
    }
  }

  // Now output the disassembly, using as little space as possible
  for(size_t i = begin; i < end; ++i)
  {
    const CartDebug::DisassemblyTag& tag = myDisassembly.list[i];
    if(tag.type == Device::NONE)
      continue;
    else if(tag.address)
      buffer << std::uppercase << std::hex << std::setw(4)
             << std::setfill('0') << tag.address << ":  ";
    else
      buffer << "       ";

    buffer << tag.disasm << std::setw(static_cast<int>(length - tag.disasm.length() + 2))
           << std::setfill(' ') << " "
           << std::setw(4) << std::left << tag.ccount << "   " << tag.bytes << '\n';
  }

  return buffer.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::addDirective(Device::AccessType type,
                             uInt16 start, uInt16 end, int bank)
{
  if(end < start || start == 0 || end == 0)
    return false;

  if(bank < 0)  // Do we want the current bank or ZP RAM?
    bank = (myDebugger.cpuDebug().pc() & 0x1000) ?
      getBank(myDebugger.cpuDebug().pc()) : static_cast<int>(myBankInfo.size())-1;

  bank = std::min(bank, romBankCount());
  BankInfo& info = myBankInfo[bank];
  DirectiveList& list = info.directiveList;

  DirectiveTag tag;
  tag.type = type;
  tag.start = start;
  tag.end = end;

  DirectiveList::iterator i;

  // If the same directive and range is added, consider it a removal instead
  for(i = list.begin(); i != list.end(); ++i)
  {
    if(i->type == tag.type && i->start == tag.start && i->end == tag.end)
    {
      list.erase(i);
      return false;
    }
  }

  // Otherwise, scan the list and make space for a 'smart' merge
  // Note that there are 4 possibilities:
  //  1: a range is completely inside the new range
  //  2: a range is completely outside the new range
  //  3: a range overlaps at the beginning of the new range
  //  4: a range overlaps at the end of the new range
  for(i = list.begin(); i != list.end(); ++i)
  {
    // Case 1: remove range that is completely inside new range
    if(tag.start <= i->start && tag.end >= i->end)
    {
      i = list.erase(i);
    }
    // Case 2: split the old range
    else if(tag.start >= i->start && tag.end <= i->end)
    {
      // Only split when necessary
      if(tag.type == i->type)
        return true;  // node is fine as-is

      // Create new endpoint
      DirectiveTag tag2;
      tag2.type = i->type;
      tag2.start = tag.end + 1;
      tag2.end = i->end;

      // Modify startpoint
      i->end = tag.start - 1;

      // Insert new endpoint
      ++i;
      list.insert(i, tag2);
      break;  // no need to go further; this is the insertion point
    }
    // Case 3: truncate end of old range
    else if(tag.start >= i->start && tag.start <= i->end)
    {
      i->end = tag.start - 1;
    }
    // Case 4: truncate start of old range
    else if(tag.end >= i->start && tag.end <= i->end)
    {
      i->start = tag.end + 1;
    }
  }

  // We now know that the new range can be inserted without overlap
  // Where possible, consecutive ranges should be merged rather than
  // new nodes created
  for(i = list.begin(); i != list.end(); ++i)
  {
    if(tag.end < i->start)  // node should be inserted *before* this one
    {
      bool createNode = true;

      // Is the new range ending consecutive with the old range beginning?
      // If so, a merge will suffice
      if(i->type == tag.type && tag.end + 1 == i->start)
      {
        i->start = tag.start;
        createNode = false;  // a merge was done, so a new node isn't needed
      }

      // Can we also merge with the previous range (if any)?
      if(i != list.begin())
      {
        auto p = i;
        --p;
        if(p->type == tag.type && p->end + 1 == tag.start)
        {
          if(createNode)  // a merge with right-hand range didn't previously occur
          {
            p->end = tag.end;
            createNode = false;  // a merge was done, so a new node isn't needed
          }
          else  // merge all three ranges
          {
            i->start = p->start;
            i = list.erase(p);
            createNode = false;  // a merge was done, so a new node isn't needed
          }
        }
      }

      // Create the node only when necessary
      if(createNode)
        i = list.insert(i, tag);

      break;
    }
  }
  // Otherwise, add the tag at the end
  if(i == list.end())
    list.push_back(tag);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::getBank(uInt16 address)
{
  return myConsole.cartridge().getBank(address);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::getPCBank()
{
  return myConsole.cartridge().getBank(myDebugger.cpuDebug().pc());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::romBankCount() const
{
  return myConsole.cartridge().romBankCount();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::addLabel(const string& label, uInt16 address)
{
  // Only user-defined labels can be added or redefined
  switch(addressType(address))
  {
    case AddrType::TIA:
    case AddrType::IO:
      return false;
    default:
      removeLabel(label);
      myUserAddresses.emplace(label, address);
      myUserLabels.emplace(address, label);
      myLabelLength = std::max(myLabelLength, static_cast<uInt16>(label.size()));
      mySystem.setDirtyPage(address);
      return true;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::removeLabel(const string& label)
{
  // Only user-defined labels can be removed
  const auto& iter = myUserAddresses.find(label);
  if(iter != myUserAddresses.end())
  {
    // Erase the address assigned to the label
    const auto& iter2 = myUserLabels.find(iter->second);
    if(iter2 != myUserLabels.end())
      myUserLabels.erase(iter2);

    // Erase the label itself
    mySystem.setDirtyPage(iter->second);
    myUserAddresses.erase(iter);

    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDebug::getLabel(ostream& buf, uInt16 addr, bool isRead,
                         int places, bool isRam) const
{
  switch(addressType(addr))
  {
    case AddrType::TIA:
    {
      if(isRead)
      {
        const uInt16 a = addr & 0x0F, offset = addr & 0xFFF0;
        buf << ourTIAMnemonicR[a];
        if(offset > 0)
          buf << "|$" << Base::HEX2 << offset;
      }
      else
      {
        const uInt16 a = addr & 0x3F, offset = addr & 0xFFC0;
        buf << ourTIAMnemonicW[a];
        if(offset > 0)
          buf << "|$" << Base::HEX2 << offset;
      }
      return true;
    }

    case AddrType::IO:
    {
      const uInt16 a = addr & 0xFF, offset = addr & 0xFD00;
      if(a <= 0x9F)
      {
        buf << ourIOMnemonic[a - 0x80];
        if(offset > 0)
          buf << "|$" << Base::HEX2 << offset;
      }
      else
        buf << "$" << Base::HEX2 << addr;

      return true;
    }

    case AddrType::ZPRAM:
    {
      // RAM can use user-defined labels; otherwise we default to
      // standard mnemonics
      AddrToLabel::const_iterator iter;
      const uInt16 a = addr & 0xFF, offset = addr & 0xFF00;
      bool found = false;

      // Search for nearest label
      for(uInt16 i = a; i >= 0x80; --i)
        if((iter = myUserLabels.find(i)) != myUserLabels.end())
        {
          buf << iter->second;
          if(a != i)
            buf << "+$" << Base::HEX1 << (a - i);
          found = true;
          break;
        }
      if(!found)
        buf << ourZPMnemonic[a - 0x80];
      if(offset > 0)
        buf << "|$" << Base::HEX2 << offset;

      return true;
    }

    case AddrType::ROM:
    {
      // These addresses can never be in the system labels list
      if(isRam) // cartridge RAM
      {
        AddrToLabel::const_iterator iter;

        // Search for nearest label
        for(uInt16 i = addr; i >= (addr & 0xf000); --i)
          if((iter = myUserLabels.find(i)) != myUserLabels.end())
          {
            buf << iter->second;
            if(addr != i)
              buf << "+$" << Base::HEX1 << (addr - i);
            return true;
          }
      }
      else
      {
        const auto& iter = myUserLabels.find(addr);
        if(iter != myUserLabels.end())
        {
          buf << iter->second;
          return true;
        }
      }
      break;
    }
  }

  switch(places)
  {
    case 2:
      buf << "$" << Base::HEX2 << addr;
      return true;
    case 4:
      buf << "$" << Base::HEX4 << addr;
      return true;
    case 8:
      buf << "$" << Base::HEX8 << addr;
      return true;
    default:
      break;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::getLabel(uInt16 addr, bool isRead, int places, bool isRam) const
{
  ostringstream buf;
  getLabel(buf, addr, isRead, places, isRam);
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebug::getAddress(const string& label) const
{
  LabelToAddr::const_iterator iter;

  if((iter = mySystemAddresses.find(label)) != mySystemAddresses.end())
    return iter->second;
  else if((iter = myUserAddresses.find(label)) != myUserAddresses.end())
    return iter->second;
  else
    return -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::loadListFile()
{
  // The default naming/location for list files is the ROM dir based on the
  // actual ROM filename

  const FSNode lst(myOSystem.romFile().getPathWithExt(".lst"));
  if(!lst.isReadable())
    return DebuggerParser::red("list file \'" + lst.getShortPath() + "\' not found");

  stringstream in;
  try
  {
    if(lst.read(in) == 0)
      return DebuggerParser::red("list file '" + lst.getShortPath() + "' not found");
  }
  catch(...)
  {
    return DebuggerParser::red("list file '" + lst.getShortPath() + "' not readable");
  }

  while(!in.eof())
  {
    string line, addr_s;

    getline(in, line);

    if(!in.good() || line.empty() || line[0] == '-')
      continue;
    else  // Search for constants
    {
      stringstream buf(line);

      // Swallow first value, then get actual numerical value for address
      // We need to read the address as a string, since it may contain 'U'
      int addr = -1;
      buf >> addr >> addr_s;
      if(addr_s.empty())
        continue;

      addr = BSPF::stoi<16>(addr_s[0] == 'U' ? addr_s.substr(1) : addr_s);

      // For now, completely ignore ROM addresses
      if(!(addr & 0x1000))
      {
        // Search for pattern 'xx yy  CONSTANT ='
        buf.seekg(20);  // skip potential '????'
        int xx = -1, yy = -1;
        char eq = '\0';
        buf >> hex >> xx >> hex >> yy >> line >> eq;
        if(xx >= 0 && yy >= 0 && eq == '=')
          //myUserCLabels.emplace(xx*256+yy, line);
          addLabel(line, xx * 256 + yy);
      }
    }
  }
  myDebugger.rom().invalidate();

  return "list file '" + lst.getShortPath() + "' loaded OK";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::loadSymbolFile()
{
  // The default naming/location for symbol files is the ROM dir based on the
  // actual ROM filename

  const FSNode sym(myOSystem.romFile().getPathWithExt(".sym"));
  if(!sym.isReadable())
    return DebuggerParser::red("symbol file \'" + sym.getShortPath() + "\' not found");

  myUserAddresses.clear();
  myUserLabels.clear();

  stringstream in;
  try
  {
    if(sym.read(in) == 0)
      return DebuggerParser::red("symbol file '" + sym.getShortPath() + "' not found");
  }
  catch(...)
  {
    return DebuggerParser::red("symbol file '" + sym.getShortPath() + "' not readable");
  }

  while(!in.eof())
  {
    string label;
    int value = -1;

    getline(in, label);
    if(!in.good())  continue;
    stringstream buf(label);
    buf >> label >> hex >> value;

    if(!label.empty() && label[0] != '-' && value >= 0)
    {
      // Make sure the value doesn't represent a constant
      // For now, we simply ignore constants completely
      //const auto& iter = myUserCLabels.find(value);
      //if(iter == myUserCLabels.end() || !BSPF::equalsIgnoreCase(label, iter->second))
      const auto& iter = myUserLabels.find(value);
      if (iter == myUserLabels.end() || !BSPF::equalsIgnoreCase(label, iter->second))
      {
        // Check for period, and strip leading number
        string::size_type pos = label.find_first_of('.', 0);
        if(pos != string::npos)
          addLabel(label.substr(pos), value);
        else
        {
          pos = label.find_last_of('$');
          if (pos == string::npos || pos != label.length() - 1)
            addLabel(label, value);
        }
      }
    }
  }
  myDebugger.rom().invalidate();

  return "symbol file '" + sym.getShortPath() + "' loaded OK";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::loadConfigFile()
{
  // The default naming/location for config files is the CFG dir and based
  // on the actual ROM filename

  const FSNode romNode(myOSystem.romFile().getPathWithExt(".cfg"));
  FSNode cfg = myOSystem.cfgDir();  cfg /= romNode.getName();
  if(!cfg.isReadable())
    return DebuggerParser::red("config file \'" + cfg.getShortPath() + "\' not found");

  stringstream in;
  try
  {
    cfg.read(in);
  }
  catch(...)
  {
    return "Unable to load directives from " + cfg.getPath();
  }

  // Erase all previous directives
  for(auto& bi: myBankInfo)
    bi.directiveList.clear();

  int currentbank = 0;
  while(!in.eof())
  {
    // Skip leading space
    int c = in.peek();
    while(c == ' ' || c == '\t')
    {
      in.get();
      c = in.peek();
    }

    string line;
    c = in.peek();
    if(c == '/')  // Comment, swallow line and continue
    {
      getline(in, line);
      continue;
    }
    else if(c == '[')
    {
      in.get();
      getline(in, line, ']');
      stringstream buf(line);
      buf >> currentbank;
    }
    else  // Should be commands from this point on
    {
      getline(in, line);
      stringstream buf;
      buf << line;

      string directive;
      uInt16 start = 0, end = 0;
      buf >> directive;
      if(BSPF::startsWithIgnoreCase(directive, "ORG"))
      {
        // TODO - figure out what to do with this
        buf >> hex >> start;
      }
      else if(BSPF::startsWithIgnoreCase(directive, "CODE"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::CODE, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "GFX"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::GFX, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "PGFX"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::PGFX, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "COL"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::COL, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "PCOL"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::PCOL, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "BCOL"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::BCOL, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "AUD"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::AUD, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "DATA"))
      {
        buf >> hex >> start >> hex >> end;
        addDirective(Device::DATA, start, end, currentbank);
      }
      else if(BSPF::startsWithIgnoreCase(directive, "ROW"))
      {
        buf >> hex >> start;
        buf >> hex >> end;
        addDirective(Device::ROW, start, end, currentbank);
      }
    }
  }
  myDebugger.rom().invalidate();

  stringstream retVal;
  if(myConsole.cartridge().romBankCount() > 1)
    retVal << DebuggerParser::red("config file for multi-bank ROM not fully supported\n");
  retVal << "config file '" << cfg.getShortPath() << "' loaded OK";
  return retVal.str();

}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::saveConfigFile()
{
  // The default naming/location for config files is the CFG dir and based
  // on the actual ROM filename

  const string& name = myConsole.properties().get(PropType::Cart_Name);
  const string& md5 = myConsole.properties().get(PropType::Cart_MD5);

  // Store all bank information
  stringstream out;
  out << "// Stella.pro: \"" << name << "\"\n"
      << "// MD5: " << md5 << "\n\n";
  for(uInt32 b = 0; b < myConsole.cartridge().romBankCount(); ++b)
  {
    out << "[" << b << "]\n";
    getBankDirectives(out, myBankInfo[b]);
  }

  stringstream retVal;
  try
  {
    const FSNode romNode(myOSystem.romFile().getPathWithExt(".cfg"));
    FSNode cfg = myOSystem.cfgDir();  cfg /= romNode.getName();
    if(!cfg.getParent().isWritable())
      return DebuggerParser::red("config file \'" + cfg.getShortPath() + "\' not writable");

    if(cfg.write(out) == 0)
      return "Unable to save directives to " + cfg.getShortPath();

    if(myConsole.cartridge().romBankCount() > 1)
      retVal << DebuggerParser::red("config file for multi-bank ROM not fully supported\n");
    retVal << "config file '" << cfg.getShortPath() << "' saved OK";
  }
  catch(const runtime_error& e)
  {
    retVal << "Unable to save directives: " << e.what();
  }
  return retVal.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::saveDisassembly(string path)
{
#define ALIGN(x) setfill(' ') << left << setw(x)

  // We can't print the header to the disassembly until it's actually
  // been processed; therefore buffer output to a string first
  ostringstream buf;

  // Use specific settings for disassembly output
  // This will most likely differ from what you see in the debugger
  DiStella::Settings settings;
  settings.gfxFormat = DiStella::settings.gfxFormat;
  settings.resolveCode = true;
  settings.showAddresses = false;
  settings.aFlag = false; // Otherwise DASM gets confused
  settings.fFlag = DiStella::settings.fFlag;
  settings.rFlag = DiStella::settings.rFlag;
  settings.bytesWidth = 8+1;  // same as Stella debugger
  settings.bFlag = DiStella::settings.bFlag; // process break routine (TODO)

  Disassembly disasm;
  disasm.list.reserve(2048);
  Cartridge& cart = myConsole.cartridge();
  const uInt16 romBankCount = cart.romBankCount();
  const uInt16 oldBank = cart.getBank();

  // prepare for switching banks
  uInt32 origin = 0;

  for(int bank = 0; bank < romBankCount; ++bank)
  {
    // TODO: not every CartDebugWidget does it like that, we need a method
    cart.unlockHotspots();
    cart.bank(bank);
    cart.lockHotspots();

    BankInfo& info = myBankInfo[bank];

    disassembleBank(bank);

    // An empty address list means that DiStella can't do a disassembly
    if(info.addressList.empty())
      continue;

    buf << "\n\n;***********************************************************\n"
      << ";      Bank " << bank;
    if (romBankCount > 1)
      buf << " / 0.." << romBankCount - 1;
    buf << "\n;***********************************************************\n\n";

    // Disassemble bank
    disasm.list.clear();
    const DiStella distella(*this, disasm.list, info, settings,
                            myDisLabels, myDisDirectives, myReserved);

    if (myReserved.breakFound)
      addLabel("Break", myDebugger.dpeek(0xfffe));

    buf << "    SEG     CODE\n";

    if(romBankCount == 1)
      buf << "    ORG     $" << Base::HEX4 << info.offset << "\n\n";
    else
      buf << "    ORG     $" << Base::HEX4 << origin << "\n"
          << "    RORG    $" << Base::HEX4 << info.offset << "\n\n";
    origin += static_cast<uInt32>(info.size);

    // Format in 'distella' style
    for(const auto& dt: disasm.list)
    {
      const DisassemblyTag& tag = dt;

      // Add label (if any)
      if(!tag.label.empty())
        buf << ALIGN(4) << (tag.label) << "\n";
      buf << "    ";

      switch(tag.type)
      {
        case Device::CODE:
          buf << ALIGN(32) << tag.disasm << tag.ccount.substr(0, 5) << tag.ctotal << tag.ccount.substr(5, 2);
          if (tag.disasm.find("WSYNC") != std::string::npos)
            buf << "\n;---------------------------------------";
          break;

        case Device::ROW:
          buf << ".byte   " << ALIGN(32) << tag.disasm.substr(6, 8*4-1) << "; $" << Base::HEX4 << tag.address << " (*)";
          break;

        case Device::GFX:
          buf << ".byte   " << (settings.gfxFormat == Base::Fmt::_2 ? "%" : "$")
              << tag.bytes << " ; |";
          for(int c = 12; c < 20; ++c)
            buf << ((tag.disasm[c] == '\x1e') ? "#" : " ");
          buf << ALIGN(13) << "|" << "$" << Base::HEX4 << tag.address << " (G)";
          break;

        case Device::PGFX:
          buf << ".byte   " << (settings.gfxFormat == Base::Fmt::_2 ? "%" : "$")
              << tag.bytes << " ; |";
          for(int c = 12; c < 20; ++c)
            buf << ((tag.disasm[c] == '\x1f') ? "*" : " ");
          buf << ALIGN(13) << "|" << "$" << Base::HEX4 << tag.address << " (P)";
          break;

        case Device::COL:
          buf << ".byte   " << ALIGN(32) << tag.disasm.substr(6, 15) << "; $" << Base::HEX4 << tag.address << " (C)";
          break;

        case Device::PCOL:
          buf << ".byte   " << ALIGN(32) << tag.disasm.substr(6, 15) << "; $" << Base::HEX4 << tag.address << " (CP)";
          break;

        case Device::BCOL:
          buf << ".byte   " << ALIGN(32) << tag.disasm.substr(6, 15) << "; $" << Base::HEX4 << tag.address << " (CB)";
          break;

        case Device::AUD:
          buf << ".byte   " << ALIGN(32) << tag.disasm.substr(6, 8 * 4 - 1) << "; $" << Base::HEX4 << tag.address << " (A)";
          break;

        case Device::DATA:
          buf << ".byte   " << ALIGN(32) << tag.disasm.substr(6, 8 * 4 - 1) << "; $" << Base::HEX4 << tag.address << " (D)";
          break;

        case Device::NONE:
        default:
          break;
      } // switch
      buf << "\n";
    }
  }
  cart.unlockHotspots();
  cart.bank(oldBank);
  cart.lockHotspots();

  // Some boilerplate, similar to what DiStella adds
  auto timeinfo = BSPF::localTime();
  stringstream out;
  out << "; Disassembly of " << myOSystem.romFile().getShortPath() << "\n"
      << "; Disassembled " << std::put_time(&timeinfo, "%c\n")
      << "; Using Stella " << STELLA_VERSION << "\n;\n"
      << "; ROM properties name : " << myConsole.properties().get(PropType::Cart_Name) << "\n"
      << "; ROM properties MD5  : " << myConsole.properties().get(PropType::Cart_MD5) << "\n"
      << "; Bankswitch type     : " << myConsole.cartridge().about() << "\n;\n"
      << "; Legend: *  = CODE not yet run (tentative code)\n"
      << ";         D  = DATA directive (referenced in some way)\n"
      << ";         G  = GFX directive, shown as '#' (stored in player, missile, ball)\n"
      << ";         P  = PGFX directive, shown as '*' (stored in playfield)\n"
      << ";         C  = COL directive, shown as color constants (stored in player color)\n"
      << ";         CP = PCOL directive, shown as color constants (stored in playfield color)\n"
      << ";         CB = BCOL directive, shown as color constants (stored in background color)\n"
      << ";         A  = AUD directive (stored in audio registers)\n"
      << ";         i  = indexed accessed only\n"
      << ";         c  = used by code executed in RAM\n"
      << ";         s  = used by stack\n"
      << ";         !  = page crossed, 1 cycle penalty\n"
      << "\n    processor 6502\n\n";

  out << "\n;-----------------------------------------------------------\n"
      << ";      Color constants\n"
      << ";-----------------------------------------------------------\n\n";

  if(myConsole.timing() == ConsoleTiming::ntsc)
  {
    const string NTSC_COLOR[16] = {
      "BLACK", "YELLOW", "BROWN", "ORANGE",
      "RED", "MAUVE", "VIOLET", "PURPLE",
      "BLUE", "BLUE_CYAN", "CYAN", "CYAN_GREEN",
      "GREEN", "GREEN_YELLOW", "GREEN_BEIGE", "BEIGE"
    };

    for(int i = 0; i < 16; ++i)
      out << ALIGN(16) << NTSC_COLOR[i] << " = $" << Base::HEX2 << (i << 4) << "\n";
  }
  else if(myConsole.timing() == ConsoleTiming::pal)
  {
    const string PAL_COLOR[16] = {
      "BLACK0", "BLACK1", "YELLOW", "GREEN_YELLOW",
      "ORANGE", "GREEN", "RED", "CYAN_GREEN",
      "MAUVE", "CYAN", "VIOLET", "BLUE_CYAN",
      "PURPLE", "BLUE", "BLACKE", "BLACKF"
    };

    for(int i = 0; i < 16; ++i)
      out << ALIGN(16) << PAL_COLOR[i] << " = $" << Base::HEX2 << (i << 4) << "\n";
  }
  else
  {
    const string SECAM_COLOR[8] = {
      "BLACK", "BLUE", "RED", "PURPLE",
      "GREEN", "CYAN", "YELLOW", "WHITE"
    };

    for(int i = 0; i < 8; ++i)
      out << ALIGN(16) << SECAM_COLOR[i] << " = $" << Base::HEX1 << (i << 1) << "\n";
  }
  out << "\n";

  bool addrUsed = false;
  for(uInt16 addr = 0x00; addr <= 0x0F; ++addr)
    addrUsed = addrUsed || myReserved.TIARead[addr] || (mySystem.getAccessFlags(addr) & Device::WRITE);
  for(uInt16 addr = 0x00; addr <= 0x3F; ++addr)
    addrUsed = addrUsed || myReserved.TIAWrite[addr] || (mySystem.getAccessFlags(addr) & Device::DATA);
  for(uInt16 addr = 0x00; addr <= 0x17; ++addr)
    addrUsed = addrUsed || myReserved.IOReadWrite[addr];

  if(addrUsed)
  {
    out << "\n;-----------------------------------------------------------\n"
        << ";      TIA and IO constants accessed\n"
        << ";-----------------------------------------------------------\n\n";

    // TIA read access
    for(uInt16 addr = 0x00; addr <= 0x0F; ++addr)
      if(myReserved.TIARead[addr])
        out << ALIGN(16) << ourTIAMnemonicR[addr] << "= $"
            << Base::HEX2 << right << addr << "  ; (R)\n";
      else if (mySystem.getAccessFlags(addr) & Device::DATA)
        out << ";" << ALIGN(16-1) << ourTIAMnemonicR[addr] << "= $"
        << Base::HEX2 << right << addr << "  ; (Ri)\n";
    out << "\n";

    // TIA write access
    for(uInt16 addr = 0x00; addr <= 0x3F; ++addr)
      if(myReserved.TIAWrite[addr])
        out << ALIGN(16) << ourTIAMnemonicW[addr] << "= $"
            << Base::HEX2 << right << addr << "  ; (W)\n";
      else if (mySystem.getAccessFlags(addr) & Device::WRITE)
        out << ";" << ALIGN(16-1) << ourTIAMnemonicW[addr] << "= $"
        << Base::HEX2 << right << addr << "  ; (Wi)\n";
    out << "\n";

    // RIOT IO access
    for(uInt16 addr = 0x00; addr <= 0x1F; ++addr)
      if(myReserved.IOReadWrite[addr])
        out << ALIGN(16) << ourIOMnemonic[addr] << "= $"
            << Base::HEX4 << right << (addr+0x280) << "\n";
  }

  addrUsed = false;
  for(uInt16 addr = 0x80; addr <= 0xFF; ++addr)
    addrUsed = addrUsed || myReserved.ZPRAM[addr-0x80]
      || (mySystem.getAccessFlags(addr) & (Device::DATA | Device::WRITE))
      || (mySystem.getAccessFlags(addr|0x100) & (Device::DATA | Device::WRITE));
  if(addrUsed)
  {
    bool addLine = false;
    out << "\n\n;-----------------------------------------------------------\n"
        << ";      RIOT RAM (zero-page) labels\n"
        << ";-----------------------------------------------------------\n\n";

    for (uInt16 addr = 0x80; addr <= 0xFF; ++addr) {
      const bool ramUsed = (mySystem.getAccessFlags(addr) & (Device::DATA | Device::WRITE));
      const bool codeUsed = (mySystem.getAccessFlags(addr) & Device::CODE);
      const bool stackUsed = (mySystem.getAccessFlags(addr|0x100) & (Device::DATA | Device::WRITE));

      if (myReserved.ZPRAM[addr - 0x80] &&
          myUserLabels.find(addr) == myUserLabels.end()) {
        if (addLine)
          out << "\n";
        out << ALIGN(16) << ourZPMnemonic[addr - 0x80] << "= $"
          << Base::HEX2 << right << (addr)
          << ((stackUsed || codeUsed) ? "; (" : "")
          << (codeUsed ? "c" : "")
          << (stackUsed ? "s" : "")
          << ((stackUsed || codeUsed) ? ")" : "")
          << "\n";
        addLine = false;
      } else if (ramUsed || codeUsed || stackUsed) {
        if (addLine)
          out << "\n";
        out << ALIGN(18) << ";" << "$"
          << Base::HEX2 << right << (addr)
          << "  ("
          << (ramUsed ? "i" : "")
          << (codeUsed ? "c" : "")
          << (stackUsed ? "s" : "")
          << ")\n";
        addLine = false;
      } else
        addLine = true;
    }
  }

  if(!myReserved.Label.empty())
  {
    out << "\n\n;-----------------------------------------------------------\n"
        << ";      Non Locatable Labels\n"
        << ";-----------------------------------------------------------\n\n";
    for(const auto& iter: myReserved.Label)
        out << ALIGN(16) << iter.second << "= $" << iter.first << "\n";
  }

  if(!myUserLabels.empty())
  {
    out << "\n\n;-----------------------------------------------------------\n"
        << ";      User Defined Labels\n"
        << ";-----------------------------------------------------------\n\n";
    int max_len = 16;
    for(const auto& iter: myUserLabels)
      max_len = std::max(max_len, static_cast<int>(iter.second.size()));
    for(const auto& iter: myUserLabels)
      out << ALIGN(max_len) << iter.second << "= $" << iter.first << "\n";
  }

  // And finally, output the disassembly
  out << buf.str();

  if(path.empty())
    path = myOSystem.userDir().getPath()
      + myConsole.properties().get(PropType::Cart_Name) + ".asm";
  else
    // Append default extension when missing
    if(path.find_last_of('.') == string::npos)
      path += ".asm";

  const FSNode node(path);
  stringstream retVal;
  try
  {
    node.write(out);

    if(myConsole.cartridge().romBankCount() > 1)
      retVal << DebuggerParser::red("disassembly for multi-bank ROM not fully supported\n");
    retVal << "saved " << node.getShortPath() << " OK";
  }
  catch(...)
  {
    retVal << "Unable to save disassembly to " << node.getShortPath();
  }
  return retVal.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::saveRom(string path)
{
  if(path.empty())
    path = myOSystem.userDir().getPath()
      + myConsole.properties().get(PropType::Cart_Name) + ".a26";
  else
    // Append default extension when missing
    if(path.find_last_of('.') == string::npos)
      path += ".a26";

  const FSNode node(path);

  if(myConsole.cartridge().saveROM(node))
    return "saved ROM as " + node.getShortPath();
  else
    return DebuggerParser::red("failed to save ROM");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::saveAccessFile(string path)
{
  stringstream out;
  out << myConsole.tia().getAccessCounters();
  out << myConsole.riot().getAccessCounters();
  out << myConsole.cartridge().getAccessCounters();

  try
  {
    if(path.empty())
      path = myOSystem.userDir().getPath()
        + myConsole.properties().get(PropType::Cart_Name) + ".csv";
    else
      // Append default extension when missing
      if(path.find_last_of('.') == string::npos)
        path += ".csv";

    const FSNode node(path);

    node.write(out);
    return "saved access counters as " + node.getShortPath();
  }
  catch(...)
  {
    return DebuggerParser::red("failed to save access counters file");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::listConfig(int bank)
{
  uInt32 startbank = 0, endbank = romBankCount();
  if(bank >= 0 && bank < romBankCount())
  {
    startbank = bank;
    endbank = startbank + 1;
  }

  ostringstream buf;
  buf << "(items marked '*' are user-defined)\n";
  for(uInt32 b = startbank; b < endbank; ++b)
  {
    const BankInfo& info = myBankInfo[b];
    buf << "Bank [" << b << "]\n";
    for(const auto& i: info.directiveList)
    {
      if(i.type != Device::NONE)
      {
        buf << "(*) ";
        AccessTypeAsString(buf, i.type);
        buf << " " << Base::HEX4 << i.start << " " << Base::HEX4 << i.end << '\n';
      }
    }
    getBankDirectives(buf, info);
  }

  if(myConsole.cartridge().romBankCount() > 1)
    buf << DebuggerParser::red("config file for multi-bank ROM not fully supported") << '\n';

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartDebug::clearConfig(int bank)
{
  uInt32 startbank = 0, endbank = romBankCount();
  if(bank >= 0 && bank < romBankCount())
  {
    startbank = bank;
    endbank = startbank + 1;
  }

  size_t count = 0;
  for(uInt32 b = startbank; b < endbank; ++b)
  {
    count += myBankInfo[b].directiveList.size();
    myBankInfo[b].directiveList.clear();
  }

  ostringstream buf;
  if(count > 0)
    buf << "removed " << dec << count << " directives from "
        << dec << (endbank - startbank) << " banks";
  else
    buf << "no directives present";
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebug::getCompletions(string_view in, StringList& completions) const
{
  // First scan system equates
  for(uInt16 addr = 0x00; addr <= 0x0F; ++addr)
    if(BSPF::matchesIgnoreCase(ourTIAMnemonicR[addr], in))
      completions.emplace_back(ourTIAMnemonicR[addr]);
  for(uInt16 addr = 0x00; addr <= 0x3F; ++addr)
    if(BSPF::matchesIgnoreCase(ourTIAMnemonicW[addr], in))
      completions.emplace_back(ourTIAMnemonicW[addr]);
  for(uInt16 addr = 0; addr <= 0x29F-0x280; ++addr)
    if(BSPF::matchesIgnoreCase(ourIOMnemonic[addr], in))
      completions.emplace_back(ourIOMnemonic[addr]);
  for(uInt16 addr = 0; addr <= 0x7F; ++addr)
    if(BSPF::matchesIgnoreCase(ourZPMnemonic[addr], in))
      completions.emplace_back(ourZPMnemonic[addr]);

  // Now scan user-defined labels
  for(const auto& iter: myUserAddresses)
  {
    const string_view l = iter.first;
    if(BSPF::matchesCamelCase(l, in))
      completions.emplace_back(l);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartDebug::AddrType CartDebug::addressType(uInt16 addr)
{
  // Determine the type of address to access the correct list
  // These addresses were based on (and checked against) Kroko's 2600 memory
  // map, found at http://www.qotile.net/minidig/docs/2600_mem_map.txt
  if(addr % 0x2000 < 0x1000)
  {
    if((addr & 0x00ff) < 0x80)
      return AddrType::TIA;
    else
    {
      switch(addr & 0x0f00)
      {
        case 0x000:  case 0x100:  case 0x400:  case 0x500:
        case 0x800:  case 0x900:  case 0xc00:  case 0xd00:
          return AddrType::ZPRAM;
        case 0x200:  case 0x300:  case 0x600:  case 0x700:
        case 0xa00:  case 0xb00:  case 0xe00:  case 0xf00:
          return AddrType::IO;
        default:
          break;
      }
    }
  }
  return AddrType::ROM;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebug::getBankDirectives(ostream& buf, const BankInfo& info) const
{
  // Start with the offset for this bank
  buf << "ORG " << Base::HEX4 << info.offset << '\n';

  // Now consider each byte
  uInt32 prev = info.offset, addr = prev + 1;
  Device::AccessType prevType = accessTypeAbsolute(mySystem.getAccessFlags(prev));
  for( ; addr < info.offset + info.size; ++addr)
  {
    const Device::AccessType currType = accessTypeAbsolute(mySystem.getAccessFlags(addr));

    // Have we changed to a new type?
    if(currType != prevType)
    {
      AccessTypeAsString(buf, prevType);
      buf << " " << Base::HEX4 << prev << " " << Base::HEX4 << (addr-1) << '\n';

      prev = addr;
      prevType = currType;
    }
  }

  // Grab the last directive, making sure it accounts for all remaining space
  if(prev != addr)
  {
    AccessTypeAsString(buf, prevType);
    buf << " " << Base::HEX4 << prev << " " << Base::HEX4 << (addr-1) << '\n';
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebug::accessTypeAsString(ostream& buf, uInt16 addr) const
{
  if(!(addr & 0x1000))
  {
    buf << DebuggerParser::red("type only defined for cart address space");
    return;
  }

  const uInt8 directive = myDisDirectives[addr & 0xFFF] & 0xFC,
              debugger  = myDebugger.getAccessFlags(addr) & 0xFC,
              label     = myDisLabels[addr & 0xFFF];

  buf << "\ndirective: " << Base::toString(directive, Base::Fmt::_2_8) << " ";
  AccessTypeAsString(buf, directive);
  buf << "\nemulation: " << Base::toString(debugger, Base::Fmt::_2_8) << " ";
  AccessTypeAsString(buf, debugger);
  buf << "\ntentative: " << Base::toString(label, Base::Fmt::_2_8) << " ";
  AccessTypeAsString(buf, label);
  buf << '\n';
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Device::AccessType CartDebug::accessTypeAbsolute(Device::AccessFlags flags)
{
  if(flags & Device::CODE)
    return Device::CODE;
  else if(flags & Device::TCODE)
    return Device::CODE;          // TODO - should this be separate??
  else if(flags & Device::GFX)
    return Device::GFX;
  else if(flags & Device::PGFX)
    return Device::PGFX;
  else if(flags & Device::COL)
    return Device::COL;
  else if(flags & Device::PCOL)
    return Device::PCOL;
  else if(flags & Device::BCOL)
    return Device::BCOL;
  else if(flags & Device::AUD)
    return Device::AUD;
  else if(flags & Device::DATA)
    return Device::DATA;
  else if(flags & Device::ROW)
    return Device::ROW;
  else
    return Device::NONE;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebug::AccessTypeAsString(ostream& buf, Device::AccessType type)
{
  switch(type)
  {
    case Device::CODE:   buf << "CODE";   break;
    case Device::TCODE:  buf << "TCODE";  break;
    case Device::GFX:    buf << "GFX";    break;
    case Device::PGFX:   buf << "PGFX";   break;
    case Device::COL:    buf << "COL";    break;
    case Device::PCOL:   buf << "PCOL";   break;
    case Device::BCOL:   buf << "BCOL";   break;
    case Device::AUD:    buf << "AUD";    break;
    case Device::DATA:   buf << "DATA";   break;
    case Device::ROW:    buf << "ROW";    break;
    default:                              break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebug::AccessTypeAsString(ostream& buf, Device::AccessFlags flags)
{
  if(flags)
  {
    if(flags & Device::CODE)
      buf << "CODE ";
    if(flags & Device::TCODE)
      buf << "TCODE ";
    if(flags & Device::GFX)
      buf << "GFX ";
    if(flags & Device::PGFX)
      buf << "PGFX ";
    if(flags & Device::COL)
      buf << "COL ";
    if(flags & Device::PCOL)
      buf << "PCOL ";
    if(flags & Device::BCOL)
      buf << "BCOL ";
    if(flags & Device::AUD)
      buf << "AUD ";
    if(flags & Device::DATA)
      buf << "DATA ";
    if(flags & Device::ROW)
      buf << "ROW ";
    if(flags & Device::REFERENCED)
      buf << "*REFERENCED ";
    if(flags & Device::VALID_ENTRY)
      buf << "*VALID_ENTRY ";
  }
  else
    buf << "no flags set";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::array<string_view, 16> CartDebug::ourTIAMnemonicR = {
  "CXM0P", "CXM1P", "CXP0FB", "CXP1FB", "CXM0FB", "CXM1FB", "CXBLPF", "CXPPMM",
  "INPT0", "INPT1", "INPT2", "INPT3", "INPT4", "INPT5", "$1e", "$1f"
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::array<string_view, 64> CartDebug::ourTIAMnemonicW = {
  "VSYNC", "VBLANK", "WSYNC", "RSYNC", "NUSIZ0", "NUSIZ1", "COLUP0", "COLUP1",
  "COLUPF", "COLUBK", "CTRLPF", "REFP0", "REFP1", "PF0", "PF1", "PF2",
  "RESP0", "RESP1", "RESM0", "RESM1", "RESBL", "AUDC0", "AUDC1", "AUDF0",
  "AUDF1", "AUDV0", "AUDV1", "GRP0", "GRP1", "ENAM0", "ENAM1", "ENABL",
  "HMP0", "HMP1", "HMM0", "HMM1", "HMBL", "VDELP0", "VDELP1", "VDELBL",
  "RESMP0", "RESMP1", "HMOVE", "HMCLR", "CXCLR", "$2d", "$2e", "$2f",
  "$30", "$31", "$32", "$33", "$34", "$35", "$36", "$37",
  "$38", "$39", "$3a", "$3b", "$3c", "$3d", "$3e", "$3f"
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::array<string_view, 32> CartDebug::ourIOMnemonic = {
  "SWCHA", "SWACNT", "SWCHB", "SWBCNT", "INTIM", "TIMINT",
  "$286", "$287", "$288", "$289", "$28a", "$28b", "$28c",
  "$28d", "$28e", "$28f", "$290", "$291", "$292", "$293",
  "TIM1T", "TIM8T", "TIM64T", "T1024T",
  "$298", "$299", "$29a", "$29b",
  "TIM1I", "TIM8I", "TIM64I", "T1024I"
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::array<string_view, 128> CartDebug::ourZPMnemonic = {
  "ram_80", "ram_81", "ram_82", "ram_83", "ram_84", "ram_85", "ram_86", "ram_87",
  "ram_88", "ram_89", "ram_8A", "ram_8B", "ram_8C", "ram_8D", "ram_8E", "ram_8F",
  "ram_90", "ram_91", "ram_92", "ram_93", "ram_94", "ram_95", "ram_96", "ram_97",
  "ram_98", "ram_99", "ram_9A", "ram_9B", "ram_9C", "ram_9D", "ram_9E", "ram_9F",
  "ram_A0", "ram_A1", "ram_A2", "ram_A3", "ram_A4", "ram_A5", "ram_A6", "ram_A7",
  "ram_A8", "ram_A9", "ram_AA", "ram_AB", "ram_AC", "ram_AD", "ram_AE", "ram_AF",
  "ram_B0", "ram_B1", "ram_B2", "ram_B3", "ram_B4", "ram_B5", "ram_B6", "ram_B7",
  "ram_B8", "ram_B9", "ram_BA", "ram_BB", "ram_BC", "ram_BD", "ram_BE", "ram_BF",
  "ram_C0", "ram_C1", "ram_C2", "ram_C3", "ram_C4", "ram_C5", "ram_C6", "ram_C7",
  "ram_C8", "ram_C9", "ram_CA", "ram_CB", "ram_CC", "ram_CD", "ram_CE", "ram_CF",
  "ram_D0", "ram_D1", "ram_D2", "ram_D3", "ram_D4", "ram_D5", "ram_D6", "ram_D7",
  "ram_D8", "ram_D9", "ram_DA", "ram_DB", "ram_DC", "ram_DD", "ram_DE", "ram_DF",
  "ram_E0", "ram_E1", "ram_E2", "ram_E3", "ram_E4", "ram_E5", "ram_E6", "ram_E7",
  "ram_E8", "ram_E9", "ram_EA", "ram_EB", "ram_EC", "ram_ED", "ram_EE", "ram_EF",
  "ram_F0", "ram_F1", "ram_F2", "ram_F3", "ram_F4", "ram_F5", "ram_F6", "ram_F7",
  "ram_F8", "ram_F9", "ram_FA", "ram_FB", "ram_FC", "ram_FD", "ram_FE", "ram_FF"
};
