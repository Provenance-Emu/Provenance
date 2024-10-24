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
#include "Debugger.hxx"
#include "Device.hxx"
#include "DiStella.hxx"
using Common::Base;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DiStella::DiStella(const CartDebug& dbg, CartDebug::DisassemblyList& list,
                   CartDebug::BankInfo& info, const DiStella::Settings& s,
                   CartDebug::AddrTypeArray& labels,
                   CartDebug::AddrTypeArray& directives,
                   CartDebug::ReservedEquates& reserved)
  : myDbg{dbg},
    myList{list},
    mySettings{s},
    myReserved{reserved},
    myLabels{labels},
    myDirectives{directives}
{
  bool resolve_code = mySettings.resolveCode;
  const CartDebug::AddressList& debuggerAddresses = info.addressList;
  const uInt16 start = *debuggerAddresses.cbegin();

  myOffset = info.offset;
  if (start & 0x1000) {
    info.start = myAppData.start = 0x0000;
    info.end = myAppData.end = static_cast<uInt16>(info.size - 1);
    // Keep previous offset; it may be different between banks
    if (info.offset == 0)
      info.offset = myOffset = (start - (start % info.size));
  } else { // ZP RAM
    // For now, we assume all accesses below $1000 are zero-page
    info.start = myAppData.start = 0x0080;
    info.end = myAppData.end = 0x00FF;
    info.offset = myOffset = 0;

    // Resolve code is never used in ZP RAM mode
    resolve_code = false;
  }
  myAppData.length = static_cast<uInt16>(info.size);

  myLabels.fill(0);
  myDirectives.fill(0);

  // Process any directives first, as they override automatic code determination
  processDirectives(info.directiveList);

  myReserved.breakFound = false;

  if (resolve_code)
    // First pass
    disasmPass1(info.addressList);

  // Second pass
  disasm(myOffset, 2);

  // Add reserved line equates
  ostringstream reservedLabel;
  for (int k = 0; k <= myAppData.end; k++) {
    if ((myLabels[k] & (Device::REFERENCED | Device::VALID_ENTRY)) == Device::REFERENCED) {
      // If we have a piece of code referenced somewhere else, but cannot
      // locate the label in code (i.e because the address is inside of a
      // multi-byte instruction, then we make note of that address for reference
      //
      // However, we only do this for labels pointing to ROM (above $1000)
      if (CartDebug::addressType(k + myOffset) == CartDebug::AddrType::ROM) {
        reservedLabel.str("");
        reservedLabel << "L" << Base::HEX4 << (k + myOffset);
        myReserved.Label.emplace(k + myOffset, reservedLabel.str());
      }
    }
  }

  // Third pass
  disasm(myOffset, 3);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::disasm(uInt32 distart, int pass)
/*
// Here we have 3 passes:
   - pass 1 tries to detect code and data ranges and labels
   - pass 2 marks valid code
   - pass 3 generates output
*/
{
#define LABEL_A12_HIGH(address) labelA12High(nextLine, opcode, address, labelFound)
#define LABEL_A12_LOW(address)  labelA12Low(nextLine, opcode, address, labelFound)

  uInt8 opcode = 0, d1 = 0;
  uInt16 ad = 0;
  Int32 cycles = 0;
  AddressingMode addrMode{};
  AddressType labelFound = AddressType::INVALID;
  stringstream nextLine, nextLineBytes;

  mySegType = Device::NONE; // create extra lines between code and data

  myDisasmBuf.str("");

  /* pc=myAppData.start; */
  myPC = distart - myOffset;
  while(myPC <= myAppData.end)
  {
    // since -1 is used in m6502.m4 for clearing the last peek
    // and this results into an access at e.g. 0xffff,
    // we have to fix the consequences here (ugly!).
    if(myPC == myAppData.end)
      goto FIX_LAST;  // NOLINT

    if(checkBits(myPC, Device::GFX | Device::PGFX,
       Device::CODE))
    {
      if(pass == 2)
        mark(myPC + myOffset, Device::VALID_ENTRY);
      if(pass == 3)
        outputGraphics();
      ++myPC;
    }
    else if(checkBits(myPC, Device::COL | Device::PCOL | Device::BCOL,
            Device::CODE | Device::GFX | Device::PGFX))
    {
      if(pass == 2)
        mark(myPC + myOffset, Device::VALID_ENTRY);
      if(pass == 3)
        outputColors();
      ++myPC;
    }
    else if(checkBits(myPC, Device::AUD,
            Device::CODE | Device::GFX | Device::PGFX |
            Device::COL | Device::PCOL | Device::BCOL))
    {
      if(pass == 2)
        mark(myPC + myOffset, Device::VALID_ENTRY);
      if(pass == 3)
        outputBytes(Device::AUD);
      else
        ++myPC;
    }
    else if(checkBits(myPC, Device::DATA,
            Device::CODE | Device::GFX | Device::PGFX |
            Device::COL | Device::PCOL | Device::BCOL |
            Device::AUD))
    {
      if(pass == 2)
        mark(myPC + myOffset, Device::VALID_ENTRY);
      if(pass == 3)
        outputBytes(Device::DATA);
      else
        ++myPC;
    }
    else if(checkBits(myPC, Device::ROW,
            Device::CODE | Device::GFX | Device::PGFX |
            Device::COL | Device::PCOL | Device::BCOL |
            Device::AUD | Device::DATA)) {
    FIX_LAST:
      if(pass == 2)
        mark(myPC + myOffset, Device::VALID_ENTRY);

      if(pass == 3)
        outputBytes(Device::ROW);
      else
        ++myPC;
    }
    else {
   // The following sections must be CODE

   // add extra spacing line when switching from non-code to code
      if(pass == 3 && mySegType != Device::CODE && mySegType != Device::NONE) {
        myDisasmBuf << "    '     ' ";
        addEntry(Device::NONE);
        mark(myPC + myOffset, Device::REFERENCED); // add label when switching
      }
      mySegType = Device::CODE;

      /* version 2.1 bug fix */
      if(pass == 2)
        mark(myPC + myOffset, Device::VALID_ENTRY);

      // get opcode
      opcode = Debugger::debugger().peek(myPC + myOffset);
      // get address mode for opcode
      addrMode = ourLookup[opcode].addr_mode;

      if(pass == 3) {
        if(checkBit(myPC, Device::REFERENCED))
          myDisasmBuf << Base::HEX4 << myPC + myOffset << "'L" << Base::HEX4 << myPC + myOffset << "'";
        else
          myDisasmBuf << Base::HEX4 << myPC + myOffset << "'     '";
      }
      ++myPC;

      // detect labels inside instructions (e.g. BIT masks)
      labelFound = AddressType::INVALID;
      for(uInt8 i = 0; i < ourLookup[opcode].bytes - 1; i++) {
        if(checkBit(myPC + i, Device::REFERENCED)) {
          labelFound = AddressType::ROM;
          break;
        }
      }
      if(labelFound != AddressType::INVALID) {
        if(myOffset >= 0x1000) {
          // the opcode's operand address matches a label address
          if(pass == 3) {
            // output the byte of the opcode incl. cycles
            const uInt8 nextOpcode = Debugger::debugger().peek(myPC + myOffset);

            cycles += static_cast<int>(ourLookup[opcode].cycles) -
                      static_cast<int>(ourLookup[nextOpcode].cycles);
            nextLine << ".byte   $" << Base::HEX2 << static_cast<int>(opcode) << " ;";
            nextLine << ourLookup[opcode].mnemonic;

            myDisasmBuf << nextLine.str() << "'" << ";"
              << std::dec << static_cast<int>(ourLookup[opcode].cycles) << "-"
              << std::dec << static_cast<int>(ourLookup[nextOpcode].cycles) << " "
              << "'= " << std::setw(3) << std::setfill(' ') << std::dec << cycles;

            nextLine.str("");
            cycles = 0;
            addEntry(Device::CODE); // add the new found CODE entry
          }
          // continue with the label's opcode
          continue;
        }
        else {
          if(pass == 3) {
            // TODO
          }
        }
      }

      // Undefined opcodes start with a '.'
      // These are undefined wrt DASM
      if(ourLookup[opcode].mnemonic[0] == '.' && pass == 3) {
        nextLine << ".byte   $" << Base::HEX2 << static_cast<int>(opcode) << " ;";
      }

      if(pass == 3) {
        nextLine << ourLookup[opcode].mnemonic;
        nextLineBytes << Base::HEX2 << static_cast<int>(opcode) << " ";
      }

      // Add operand(s) for PC values outside the app data range
      if(myPC >= myAppData.end) {
        switch(addrMode) {
          case AddressingMode::ABSOLUTE:
          case AddressingMode::ABSOLUTE_X:
          case AddressingMode::ABSOLUTE_Y:
          case AddressingMode::INDIRECT_X:
          case AddressingMode::INDIRECT_Y:
          case AddressingMode::ABS_INDIRECT:
          {
            if(pass == 3) {
              /* Line information is already printed; append .byte since last
                 instruction will put recompilable object larger that original
                 binary file */
              myDisasmBuf << ".byte $" << Base::HEX2 << static_cast<int>(opcode)
                << " ;" << ourLookup[opcode].mnemonic;
              addEntry(Device::DATA);

              if(myPC == myAppData.end) {
                if(checkBit(myPC, Device::REFERENCED))
                  myDisasmBuf << Base::HEX4 << myPC + myOffset << "'L" << Base::HEX4 << myPC + myOffset << "'";
                else
                  myDisasmBuf << Base::HEX4 << myPC + myOffset << "'     '";

                opcode = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
                myDisasmBuf << ".byte $" << Base::HEX2 << static_cast<int>(opcode);
                addEntry(Device::DATA);
              }
            }
            myPCEnd = myAppData.end + myOffset;
            return;
          }

          case AddressingMode::ZERO_PAGE:
          case AddressingMode::IMMEDIATE:
          case AddressingMode::ZERO_PAGE_X:
          case AddressingMode::ZERO_PAGE_Y:
          case AddressingMode::RELATIVE:
          {
            if(pass == 3) {
              /* Line information is already printed, but we can remove the
                  Instruction (i.e. BMI) by simply clearing the buffer to print */
              myDisasmBuf << ".byte $" << Base::HEX2 << static_cast<int>(opcode);
              addEntry(Device::ROW);
              nextLine.str("");
              nextLineBytes.str("");
            }
            ++myPC;
            myPCEnd = myAppData.end + myOffset;
            return;
          }

          default:
            break;
        }  // end switch(addr_mode)
      }

      // Add operand(s)
      ad = d1 = 0; // not WSYNC by default!
      /* Version 2.1 added the extensions to mnemonics */
      switch(addrMode) {
        case AddressingMode::ACCUMULATOR:
        {
          if(pass == 3 && mySettings.aFlag)
            nextLine << "     A";
          break;
        }

        case AddressingMode::ABSOLUTE:
        {
          ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
          labelFound = mark(ad, Device::REFERENCED);
          if(pass == 3) {
            if(ad < 0x100 && mySettings.fFlag)
              nextLine << ".w   ";
            else
              nextLine << "     ";

            if(labelFound == AddressType::ROM) {
              LABEL_A12_HIGH(ad);
              nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                            << Base::HEX2 << static_cast<int>(ad >> 8);
            }
            else if(labelFound == AddressType::ROM_MIRROR) {
              if(mySettings.rFlag) {
                const int tmp = (ad & myAppData.end) + myOffset;
                LABEL_A12_HIGH(tmp);
                nextLineBytes << Base::HEX2 << static_cast<int>(tmp & 0xff) << " "
                              << Base::HEX2 << static_cast<int>(tmp >> 8);
              }
              else {
                nextLine << "$" << Base::HEX4 << ad;
                nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                              << Base::HEX2 << static_cast<int>(ad >> 8);
              }
            }
            else {
              LABEL_A12_LOW(ad);
              nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                            << Base::HEX2 << static_cast<int>(ad >> 8);
            }
          }
          break;
        }

        case AddressingMode::ZERO_PAGE:
        {
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          labelFound = mark(d1, Device::REFERENCED);
          if(pass == 3) {
            nextLine << "     ";
            LABEL_A12_LOW(int(d1));
            nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          }
          break;
        }

        case AddressingMode::IMMEDIATE:
        {
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          if(pass == 3) {
            nextLine << "     #$" << Base::HEX2 << static_cast<int>(d1) << " ";
            nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          }
          break;
        }

        case AddressingMode::ABSOLUTE_X:
        {
          ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
          labelFound = mark(ad, Device::REFERENCED);
          if(pass == 2 && !checkBit(ad & myAppData.end, Device::CODE)) {
            // Since we can't know what address is being accessed unless we also
            // know the current X value, this is marked as ROW instead of DATA
            // The processing is left here, however, in case future versions of
            // the code can somehow track access to CPU registers
            mark(ad, Device::ROW);
          }
          else if(pass == 3) {
            if(ad < 0x100 && mySettings.fFlag)
              nextLine << ".wx  ";
            else
              nextLine << "     ";

            if(labelFound == AddressType::ROM) {
              LABEL_A12_HIGH(ad);
              nextLine << ",x";
              nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                            << Base::HEX2 << static_cast<int>(ad >> 8);
            }
            else if(labelFound == AddressType::ROM_MIRROR) {
              if(mySettings.rFlag) {
                const int tmp = (ad & myAppData.end) + myOffset;
                LABEL_A12_HIGH(tmp);
                nextLine << ",x";
                nextLineBytes << Base::HEX2 << static_cast<int>(tmp & 0xff) << " "
                              << Base::HEX2 << static_cast<int>(tmp >> 8);
              }
              else {
                nextLine << "$" << Base::HEX4 << ad << ",x";
                nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                              << Base::HEX2 << static_cast<int>(ad >> 8);
              }
            }
            else {
              LABEL_A12_LOW(ad);
              nextLine << ",x";
              nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                            << Base::HEX2 << static_cast<int>(ad >> 8);
            }
          }
          break;
        }

        case AddressingMode::ABSOLUTE_Y:
        {
          ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
          labelFound = mark(ad, Device::REFERENCED);
          if(pass == 2 && !checkBit(ad & myAppData.end, Device::CODE)) {
            // Since we can't know what address is being accessed unless we also
            // know the current Y value, this is marked as ROW instead of DATA
            // The processing is left here, however, in case future versions of
            // the code can somehow track access to CPU registers
            mark(ad, Device::ROW);
          }
          else if(pass == 3) {
            if(ad < 0x100 && mySettings.fFlag)
              nextLine << ".wy  ";
            else
              nextLine << "     ";

            if(labelFound == AddressType::ROM) {
              LABEL_A12_HIGH(ad);
              nextLine << ",y";
              nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                            << Base::HEX2 << static_cast<int>(ad >> 8);
            }
            else if(labelFound == AddressType::ROM_MIRROR) {
              if(mySettings.rFlag) {
                const int tmp = (ad & myAppData.end) + myOffset;
                LABEL_A12_HIGH(tmp);
                nextLine << ",y";
                nextLineBytes << Base::HEX2 << static_cast<int>(tmp & 0xff) << " "
                              << Base::HEX2 << static_cast<int>(tmp >> 8);
              }
              else {
                nextLine << "$" << Base::HEX4 << ad << ",y";
                nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                              << Base::HEX2 << static_cast<int>(ad >> 8);
              }
            }
            else {
              LABEL_A12_LOW(ad);
              nextLine << ",y";
              nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                            << Base::HEX2 << static_cast<int>(ad >> 8);
            }
          }
          break;
        }

        case AddressingMode::INDIRECT_X:
        {
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          if(pass == 3) {
            labelFound = mark(d1, 0);  // dummy call to get address type
            nextLine << "     (";
            LABEL_A12_LOW(d1);
            nextLine << ",x)";
            nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          }
          break;
        }

        case AddressingMode::INDIRECT_Y:
        {
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          if(pass == 3) {
            labelFound = mark(d1, 0);  // dummy call to get address type
            nextLine << "     (";
            LABEL_A12_LOW(d1);
            nextLine << "),y";
            nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          }
          break;
        }

        case AddressingMode::ZERO_PAGE_X:
        {
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          labelFound = mark(d1, Device::REFERENCED);
          if(pass == 3) {
            nextLine << "     ";
            LABEL_A12_LOW(d1);
            nextLine << ",x";
          }
          nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          break;
        }

        case AddressingMode::ZERO_PAGE_Y:
        {
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          labelFound = mark(d1, Device::REFERENCED);
          if(pass == 3) {
            nextLine << "     ";
            LABEL_A12_LOW(d1);
            nextLine << ",y";
          }
          nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          break;
        }

        case AddressingMode::RELATIVE:
        {
          // SA - 04-06-2010: there seemed to be a bug in distella,
          // where wraparound occurred on a 32-bit int, and subsequent
          // indexing into the labels array caused a crash
          d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
          ad = ((myPC + static_cast<Int8>(d1)) & 0xfff) + myOffset;

          labelFound = mark(ad, Device::REFERENCED);
          if(pass == 3) {
            if(labelFound == AddressType::ROM) {
              nextLine << "     ";
              LABEL_A12_HIGH(ad);
            }
            else
              nextLine << "     $" << Base::HEX4 << ad;

            nextLineBytes << Base::HEX2 << static_cast<int>(d1);
          }
          break;
        }

        case AddressingMode::ABS_INDIRECT:
        {
          ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
          labelFound = mark(ad, Device::REFERENCED);
          if(pass == 2 && !checkBit(ad & myAppData.end, Device::CODE)) {
            // Since we can't know what address is being accessed unless we also
            // know the current X value, this is marked as ROW instead of DATA
            // The processing is left here, however, in case future versions of
            // the code can somehow track access to CPU registers
            mark(ad, Device::ROW);
          }
          else if(pass == 3) {
            if(ad < 0x100 && mySettings.fFlag)
              nextLine << ".ind ";
            else
              nextLine << "     ";
          }
          if(labelFound == AddressType::ROM) {
            nextLine << "(";
            LABEL_A12_HIGH(ad);
            nextLine << ")";
          }
          else if(labelFound == AddressType::ROM_MIRROR) {
            nextLine << "(";
            if(mySettings.rFlag) {
              const int tmp = (ad & myAppData.end) + myOffset;
              LABEL_A12_HIGH(tmp);
            }
            else {
              LABEL_A12_LOW(ad);
            }
            nextLine << ")";
          }
          else {
            nextLine << "(";
            LABEL_A12_LOW(ad);
            nextLine << ")";
          }

          nextLineBytes << Base::HEX2 << static_cast<int>(ad & 0xff) << " "
                        << Base::HEX2 << static_cast<int>(ad >> 8);
          break;
        }

        default:
          break;
      } // end switch

      if(pass == 3) {
        cycles += static_cast<int>(ourLookup[opcode].cycles);
        // A complete line of disassembly (text, cycle count, and bytes)
        myDisasmBuf << nextLine.str() << "'"
          << ";" << std::dec << static_cast<int>(ourLookup[opcode].cycles)
          << (addrMode == AddressingMode::RELATIVE ? (ad & 0xf00) != ((myPC + myOffset) & 0xf00) ? "/3!" : "/3 " : "   ");
        if((opcode == 0x40 || opcode == 0x60 || opcode == 0x4c || opcode == 0x00 // code block end
           || checkBit(myPC, Device::REFERENCED)                              // referenced address
           || (ourLookup[opcode].rw_mode == RWMode::WRITE && d1 == WSYNC))       // strobe WSYNC
           && cycles > 0) {
         // output cycles for previous code block
          myDisasmBuf << "'= " << std::setw(3) << std::setfill(' ') << std::dec << cycles;
          cycles = 0;
        }
        else {
          myDisasmBuf << "'     ";
        }
        myDisasmBuf << "'" << nextLineBytes.str();

        addEntry(Device::CODE);
        if(opcode == 0x40 || opcode == 0x60 || opcode == 0x4c || opcode == 0x00) {
          myDisasmBuf << "    '     ' ";
          addEntry(Device::NONE);
          mySegType = Device::NONE; // prevent extra lines if data follows
        }

        nextLine.str("");
        nextLineBytes.str("");
      }
    } // CODE
  } /* while loop */

  /* Just in case we are disassembling outside of the address range, force the myPCEnd to EOF */
  myPCEnd = myAppData.end + myOffset;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::disasmPass1(CartDebug::AddressList& debuggerAddresses)
{
  auto it = debuggerAddresses.cbegin();
  const uInt16 start = *it++;

  // After we've disassembled from all addresses in the address list,
  // use all access points determined by Stella during emulation
  int codeAccessPoint = 0;

  // Sometimes we get a circular reference, in that processing a certain
  // PC address leads us to a sequence of addresses that end up trying
  // to process the same address again.  We detect such consecutive PC
  // addresses and only process the first one
  uInt16 lastPC = 0;
  bool duplicateFound = false;

  while (!myAddressQueue.empty())
    myAddressQueue.pop();
  myAddressQueue.push(start);

  while (!(myAddressQueue.empty() || duplicateFound)) {
    const uInt16 pcBeg = myPC = lastPC = myAddressQueue.front();
    myAddressQueue.pop();

    disasmFromAddress(myPC);

    if (pcBeg <= myPCEnd) {
      // Tentatively mark all addresses in the range as CODE
      // Note that this is a 'best-effort' approach, since
      // Distella will normally keep going until the end of the
      // range or branch is encountered
      // However, addresses *specifically* marked as DATA/GFX/PGFX/COL/PCOL/BCOL/AUD
      // in the emulation core indicate that the CODE range has finished
      // Therefore, we stop at the first such address encountered
      for (uInt32 k = pcBeg; k <= myPCEnd; ++k) {
        if (checkBits(k, Device::Device::DATA | Device::GFX | Device::PGFX |
            Device::COL | Device::PCOL | Device::BCOL | Device::AUD,
            Device::CODE)) {
          //if (Debugger::debugger().getAccessFlags(k) &
          //    (Device::DATA | Device::GFX | Device::PGFX)) {
          // TODO: this should never happen, remove when we are sure
          // TODO: NOT USED: uInt16 flags = Debugger::debugger().getAccessFlags(k);
          myPCEnd = k - 1;
          break;
        }
        mark(k, Device::CODE);
      }
    }

    // When we get to this point, all addresses have been processed
    // starting from the initial one in the address list
    // If so, process the next one in the list that hasn't already
    // been marked as CODE
    // If it *has* been marked, it can be removed from consideration
    // in all subsequent passes
    //
    // Once the address list has been exhausted, we process all addresses
    // determined during emulation to represent code, which *haven't* already
    // been considered
    //
    // Note that we can't simply add all addresses right away, since
    // the processing of a single address can cause others to be added in
    // the ::disasm method
    // All of these have to be exhausted before considering a new address
    while (myAddressQueue.empty() && it != debuggerAddresses.end()) {
      const uInt16 addr = *it;

      if (!checkBit(addr - myOffset, Device::CODE)) {
        myAddressQueue.push(addr);
        ++it;
      } else // remove this address, it is redundant
        it = debuggerAddresses.erase(it);
    }

    // Stella itself can provide hints on whether an address has ever
    // been referenced as CODE
    while (myAddressQueue.empty() && codeAccessPoint <= myAppData.end) {
      if ((Debugger::debugger().getAccessFlags(codeAccessPoint + myOffset) & Device::CODE)
          && !(myLabels[codeAccessPoint & myAppData.end] & Device::CODE)) {
        myAddressQueue.push(codeAccessPoint + myOffset);
        ++codeAccessPoint;
        break;
      }
      ++codeAccessPoint;
    }
    duplicateFound = !myAddressQueue.empty() && (myAddressQueue.front() == lastPC); // TODO: check!
  } // while

  for (int k = 0; k <= myAppData.end; k++) {
    // Let the emulation core know about tentative code
    if (checkBit(k, Device::CODE) &&
      !(Debugger::debugger().getAccessFlags(k + myOffset) & Device::CODE)
      && myOffset != 0) {
      Debugger::debugger().setAccessFlags(k + myOffset, Device::TCODE);
    }

    // Must be ROW / unused bytes
    if (!checkBit(k, Device::CODE | Device::GFX | Device::PGFX |
        Device::COL | Device::PCOL | Device::BCOL | Device::AUD |
        Device::DATA))
      mark(k + myOffset, Device::ROW);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::disasmFromAddress(uInt32 distart)
{
  uInt8 opcode = 0, d1 = 0;
  uInt16 ad = 0;
  AddressingMode addrMode{};

  myPC = distart - myOffset;

  while (myPC <= myAppData.end) {

    // abort when we reach non-code areas
    if (checkBits(myPC, Device::Device::DATA | Device::GFX | Device::PGFX |
                        Device::COL | Device::PCOL | Device::BCOL |
                        Device::AUD,
                  Device::CODE)) {
      myPCEnd = (myPC - 1) + myOffset;
      return;
    }

    // so this should be code now...
    // get opcode
    opcode = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
    // get address mode for opcode
    addrMode = ourLookup[opcode].addr_mode;

    // Add operand(s) for PC values outside the app data range
    if (myPC >= myAppData.end) {
      switch (addrMode) {
        case AddressingMode::ABSOLUTE:
        case AddressingMode::ABSOLUTE_X:
        case AddressingMode::ABSOLUTE_Y:
        case AddressingMode::INDIRECT_X:
        case AddressingMode::INDIRECT_Y:
        case AddressingMode::ABS_INDIRECT:
          myPCEnd = myAppData.end + myOffset;
          return;

        case AddressingMode::ZERO_PAGE:
        case AddressingMode::IMMEDIATE:
        case AddressingMode::ZERO_PAGE_X:
        case AddressingMode::ZERO_PAGE_Y:
        case AddressingMode::RELATIVE:
          if (myPC > myAppData.end) {
            ++myPC;
            myPCEnd = myAppData.end + myOffset;
            return;
          }
          break;  // TODO - is this the intent?

        default:
          break;
      }  // end switch(addr_mode)
    } // end if (myPC >= myAppData.end)

    // Add operand(s)
    switch (addrMode) {
      case AddressingMode::ABSOLUTE:
        ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
        mark(ad, Device::REFERENCED);
        // handle JMP/JSR
        if (ourLookup[opcode].source == AccessMode::ADDR) {
          // do NOT use flags set by debugger, else known CODE will not analyzed statically.
          if (!checkBit(ad & myAppData.end, Device::CODE | Device::ROW, false)) {
            if (ad > 0xfff)
              myAddressQueue.push((ad & myAppData.end) + myOffset);
            mark(ad, Device::CODE);
          }
        } else
          mark(ad, Device::DATA);
        break;

      case AddressingMode::ZERO_PAGE:
        d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
        mark(d1, Device::REFERENCED);
        break;

      case AddressingMode::IMMEDIATE:
        ++myPC;
        break;

      case AddressingMode::ABSOLUTE_X:
        ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
        mark(ad, Device::REFERENCED);
        break;

      case AddressingMode::ABSOLUTE_Y:
        ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
        mark(ad, Device::REFERENCED);
        break;

      case AddressingMode::INDIRECT_X:
        ++myPC;
        break;

      case AddressingMode::INDIRECT_Y:
        ++myPC;
        break;

      case AddressingMode::ZERO_PAGE_X:
        d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
        mark(d1, Device::REFERENCED);
        break;

      case AddressingMode::ZERO_PAGE_Y:
        d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
        mark(d1, Device::REFERENCED);
        break;

      case AddressingMode::RELATIVE:
        // SA - 04-06-2010: there seemed to be a bug in distella,
        // where wraparound occurred on a 32-bit int, and subsequent
        // indexing into the labels array caused a crash
        d1 = Debugger::debugger().peek(myPC + myOffset);  ++myPC;
        ad = ((myPC + static_cast<Int8>(d1)) & 0xfff) + myOffset;
        mark(ad, Device::REFERENCED);
        // do NOT use flags set by debugger, else known CODE will not analyzed statically.
        if (!checkBit(ad - myOffset, Device::CODE | Device::ROW, false)) {
          myAddressQueue.push(ad);
          mark(ad, Device::CODE);
        }
        break;

      case AddressingMode::ABS_INDIRECT:
        ad = Debugger::debugger().dpeek(myPC + myOffset);  myPC += 2;
        mark(ad, Device::REFERENCED);
        break;

      default:
        break;
    } // end switch

    // mark BRK vector
    if (opcode == 0x00) {
      ad = Debugger::debugger().dpeek(0xfffe, Device::DATA);
      if (!myReserved.breakFound) {
        myAddressQueue.push(ad);
        mark(ad, Device::CODE);
        myReserved.breakFound = true;
      }
    }

    // JMP/RTS/RTI always indicate the end of a block of CODE
    if (opcode == 0x4c || opcode == 0x60 || opcode == 0x40) {
      // code block end
      myPCEnd = (myPC - 1) + myOffset;
      return;
    }
  } // while
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DiStella::AddressType DiStella::mark(uInt32 address, uInt16 mask, bool directive)
{
  /*-----------------------------------------------------------------------
    For any given offset and code range...

    If we're between the offset and the end of the code range, we mark
    the bit in the labels array for that data.  The labels array is an
    array of label info for each code address.  If this is the case,
    return "ROM", else...

    We sweep for hardware/system equates, which are valid addresses,
    outside the scope of the code/data range.  For these, we mark its
    corresponding hardware/system array element, and return "TIA" or "RIOT"
    (depending on which system/hardware element was accessed).
    If this was not the case...

    Next we check if it is a code "mirror".  For the 2600, address ranges
    are limited with 13 bits, so other addresses can exist outside of the
    standard code/data range.  For these, we mark the element in the "labels"
    array that corresponds to the mirrored address, and return "ROM_MIRROR"

    If all else fails, it's not a valid address, so return INVALID.

    A quick example breakdown for a 2600 4K cart:
    ===========================================================
      $00-$3d     = system equates (WSYNC, etc...); return TIA.
      $80-$ff     = zero-page RAM (ram_80, etc...); return ZP_RAM.
      $0280-$0297 = system equates (INPT0, etc...); mark the array's element
                    with the appropriate bit; return RIOT.
      $1000-$1FFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $3000-$3FFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $5000-$5FFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $7000-$7FFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $9000-$9FFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $B000-$BFFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $D000-$DFFF = mark the code/data array for the mirrored address
                    with the appropriate bit; return ROM_MIRROR.
      $F000-$FFFF = mark the code/data array for the address
                    with the appropriate bit; return ROM.
      Anything else = invalid, return INVALID.
    ===========================================================
  -----------------------------------------------------------------------*/

  // Check for equates before ROM/ZP-RAM accesses, because the original logic
  // of Distella assumed either equates or ROM; it didn't take ZP-RAM into account
  const CartDebug::AddrType type = CartDebug::addressType(address);
  if(type == CartDebug::AddrType::TIA) {
    return AddressType::TIA;
  }
  else if(type == CartDebug::AddrType::IO) {
    return AddressType::RIOT;
  }
  else if(type == CartDebug::AddrType::ZPRAM && myOffset != 0) {
    return AddressType::ZP_RAM;
  }
  else if(address >= static_cast<uInt32>(myOffset) &&
          address <= static_cast<uInt32>(myAppData.end + myOffset)) {
    myLabels[address - myOffset] = myLabels[address - myOffset] | mask;
    if(directive)
      myDirectives[address - myOffset] = mask;
    return AddressType::ROM;
  }
  else if(address > 0x1000 && myOffset != 0)  // Exclude zero-page accesses
  {
    /* 2K & 4K case */
    myLabels[address & myAppData.end] = myLabels[address & myAppData.end] | mask;
    if(directive)
      myDirectives[address & myAppData.end] = mask;
    return AddressType::ROM_MIRROR;
  }
  else
    return AddressType::INVALID;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DiStella::checkBit(uInt16 address, uInt16 mask, bool useDebugger) const
{
  // The REFERENCED and VALID_ENTRY flags are needed for any inspection of
  // an address
  // Since they're set only in the labels array (as the lower two bits),
  // they must be included in the other bitfields
  const uInt16 label = myLabels[address & myAppData.end],
    lastbits = label & (Device::REFERENCED | Device::VALID_ENTRY),
    directive = myDirectives[address & myAppData.end] & ~(Device::REFERENCED | Device::VALID_ENTRY),
    debugger = Debugger::debugger().getAccessFlags(address | myOffset) & ~(Device::REFERENCED | Device::VALID_ENTRY);

  // Any address marked by a manual directive always takes priority
  if (directive)
    return (directive | lastbits) & mask;
  // Next, the results from a dynamic/runtime analysis are used (except for pass 1)
  else if (useDebugger && ((debugger | lastbits) & mask))
    return true;
  // Otherwise, default to static analysis from Distella
  else
    return label & mask;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DiStella::checkBits(uInt16 address, uInt16 mask, uInt16 notMask, bool useDebugger) const
{
  return checkBit(address, mask, useDebugger) && !checkBit(address, notMask, useDebugger);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DiStella::check_range(uInt16 start, uInt16 end) const
{
  if (start > end) {
    cerr << "Beginning of range greater than end: start = " << std::hex << start
      << ", end = " << std::hex << end << '\n';
    return false;
  } else if (start > myAppData.end + myOffset) {
    cerr << "Beginning of range out of range: start = " << std::hex << start
      << ", range = " << std::hex << (myAppData.end + myOffset) << '\n';
    return false;
  } else if (start < myOffset) {
    cerr << "Beginning of range out of range: start = " << std::hex << start
      << ", offset = " << std::hex << myOffset << '\n';
    return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::addEntry(Device::AccessType type)
{
  CartDebug::DisassemblyTag tag;

  // Type
  tag.type = type;

  // Address
  myDisasmBuf.seekg(0, std::ios::beg);
  if (myDisasmBuf.peek() == ' ')
    tag.address = 0;
  else
    myDisasmBuf >> std::setw(4) >> std::hex >> tag.address;

  // Only include addresses within the requested range
  if (tag.address < myAppData.start)
    goto DONE_WITH_ADD;  // NOLINT

  // Label (a user-defined label always overrides any auto-generated one)
  myDisasmBuf.seekg(5, std::ios::beg);
  if (tag.address) {
    tag.label = myDbg.getLabel(tag.address, true);
    tag.hllabel = true;
    if (tag.label == EmptyString) {
      if (myDisasmBuf.peek() != ' ')
        getline(myDisasmBuf, tag.label, '\'');
      else if (mySettings.showAddresses && tag.type == Device::CODE) {
        // Have addresses indented, to differentiate from actual labels
        tag.label = " " + Base::toString(tag.address, Base::Fmt::_16_4);
        tag.hllabel = false;
      }
    }
  }

  // Disassembly
  // Up to this point the field sizes are fixed, until we get to
  // variable length labels, cycle counts, etc
  myDisasmBuf.seekg(11, std::ios::beg);
  switch (tag.type) {
    case Device::CODE:
      getline(myDisasmBuf, tag.disasm, '\'');
      getline(myDisasmBuf, tag.ccount, '\'');
      getline(myDisasmBuf, tag.ctotal, '\'');
      getline(myDisasmBuf, tag.bytes);

      // Make note of when we override CODE sections from the debugger
      // It could mean that the code hasn't been accessed up to this point,
      // but it could also indicate that code will *never* be accessed
      // Since it is impossible to tell the difference, marking the address
      // in the disassembly at least tells the user about it
      if (!(Debugger::debugger().getAccessFlags(tag.address) & Device::CODE)
          && myOffset != 0) {
        tag.ccount += " *";
        Debugger::debugger().setAccessFlags(tag.address, Device::TCODE);
      }
      break;

    case Device::GFX:
    case Device::PGFX:
    case Device::COL:
    case Device::PCOL:
    case Device::BCOL:
    case Device::DATA:
    case Device::AUD:
      getline(myDisasmBuf, tag.disasm, '\'');
      getline(myDisasmBuf, tag.bytes);
      break;

    case Device::ROW:
      getline(myDisasmBuf, tag.disasm);
      break;

    case Device::NONE:
    default:  // should never happen
      tag.disasm = " ";
      break;
  }
  myList.push_back(tag);

DONE_WITH_ADD:
  myDisasmBuf.clear();
  myDisasmBuf.str("");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::outputGraphics()
{
  const bool isPGfx = checkBit(myPC, Device::PGFX);
  const string& bitString = isPGfx ? "\x1f" : "\x1e";
  const uInt8 byte = Debugger::debugger().peek(myPC + myOffset);

  // add extra spacing line when switching from non-graphics to graphics
  if (mySegType != Device::GFX && mySegType != Device::NONE) {
    myDisasmBuf << "    '     ' ";
    addEntry(Device::NONE);
  }
  mySegType = Device::GFX;

  if (checkBit(myPC, Device::REFERENCED))
    myDisasmBuf << Base::HEX4 << myPC + myOffset << "'L" << Base::HEX4 << myPC + myOffset << "'";
  else
    myDisasmBuf << Base::HEX4 << myPC + myOffset << "'     '";
  myDisasmBuf << ".byte $" << Base::HEX2 << static_cast<int>(byte) << "  |";
  for (uInt8 i = 0, c = byte; i < 8; ++i, c <<= 1)
    myDisasmBuf << ((c > 127) ? bitString : " ");
  myDisasmBuf << "|   $" << Base::HEX4 << myPC + myOffset << "'";
  if (mySettings.gfxFormat == Base::Fmt::_2)
    myDisasmBuf << Base::toString(byte, Base::Fmt::_2_8);
  else
    myDisasmBuf << Base::HEX2 << static_cast<int>(byte);

  addEntry(isPGfx ? Device::PGFX : Device::GFX);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::outputColors()
{
  const string NTSC_COLOR[16] = {
    "BLACK", "YELLOW", "BROWN", "ORANGE",
    "RED", "MAUVE", "VIOLET", "PURPLE",
    "BLUE", "BLUE_CYAN", "CYAN", "CYAN_GREEN",
    "GREEN", "GREEN_YELLOW", "GREEN_BEIGE", "BEIGE"
  };
  const string PAL_COLOR[16] = {
    "BLACK0", "BLACK1", "YELLOW", "GREEN_YELLOW",
    "ORANGE", "GREEN", "RED", "CYAN_GREEN",
    "MAUVE", "CYAN", "VIOLET", "BLUE_CYAN",
    "PURPLE", "BLUE", "BLACKE", "BLACKF"
  };
  const string SECAM_COLOR[8] = {
    "BLACK", "BLUE", "RED", "PURPLE",
    "GREEN", "CYAN", "YELLOW", "WHITE"
  };

  const uInt8 byte = Debugger::debugger().peek(myPC + myOffset);

  // add extra spacing line when switching from non-colors to colors
  if(mySegType != Device::COL && mySegType != Device::NONE)
  {
    myDisasmBuf << "    '     ' ";
    addEntry(Device::NONE);
  }
  mySegType = Device::COL;

  // output label/address
  if(checkBit(myPC, Device::REFERENCED))
    myDisasmBuf << Base::HEX4 << myPC + myOffset << "'L" << Base::HEX4 << myPC + myOffset << "'";
  else
    myDisasmBuf << Base::HEX4 << myPC + myOffset << "'     '";

  // output color
  string color;

  myDisasmBuf << ".byte ";
  if(myDbg.myConsole.timing() == ConsoleTiming::ntsc)
  {
    color = NTSC_COLOR[byte >> 4];
    myDisasmBuf << color << "|$" << Base::HEX1 << (byte & 0xf);
  }
  else if(myDbg.myConsole.timing() == ConsoleTiming::pal)
  {
    color = PAL_COLOR[byte >> 4];
    myDisasmBuf << color << "|$" << Base::HEX1 << (byte & 0xf);
  }
  else
  {
    color = SECAM_COLOR[(byte >> 1) & 0x7];
    myDisasmBuf << "$" << Base::HEX1 << (byte >> 4) << "|" << color;
  }
  myDisasmBuf << std::setw(static_cast<int>(16 - color.length())) << std::setfill(' ');

  // output address
  myDisasmBuf << "; $" << Base::HEX4 << myPC + myOffset << " "
    << (checkBit(myPC, Device::COL) ? "(Px)" : checkBit(myPC, Device::PCOL) ? "(PF)" : "(BK)");

  // output color value
  myDisasmBuf << "'" << Base::HEX2 << static_cast<int>(byte);

  addEntry(checkBit(myPC, Device::COL) ? Device::COL :
           checkBit(myPC, Device::PCOL) ? Device::PCOL : Device::BCOL);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::outputBytes(Device::AccessType type)
{
  bool isType = true;
  bool referenced = checkBit(myPC, Device::REFERENCED);
  bool lineEmpty = true;
  int numBytes = 0;

  // add extra spacing line when switching from non-data to data
  if (mySegType != Device::DATA && mySegType != Device::NONE) {
    myDisasmBuf << "    '     ' ";
    addEntry(Device::NONE);
  }
  mySegType = Device::DATA;

  while (isType && myPC <= myAppData.end) {
    if (referenced) {
      // start a new line with a label
      if (!lineEmpty)
        addEntry(type);

      myDisasmBuf << Base::HEX4 << myPC + myOffset << "'L" << Base::HEX4
        << myPC + myOffset << "'.byte " << "$" << Base::HEX2
        << static_cast<int>(Debugger::debugger().peek(myPC + myOffset));
      ++myPC;
      numBytes = 1;
      lineEmpty = false;
    } else if (lineEmpty) {
      // start a new line without a label
      myDisasmBuf << Base::HEX4 << myPC + myOffset << "'     '"
        << ".byte $" << Base::HEX2 << static_cast<int>(Debugger::debugger().peek(myPC + myOffset));
      ++myPC;
      numBytes = 1;
      lineEmpty = false;
    }
    // Otherwise, append bytes to the current line, up until the maximum
    else if (++numBytes == mySettings.bytesWidth) {
      addEntry(type);
      lineEmpty = true;
    } else {
      myDisasmBuf << ",$" << Base::HEX2 << static_cast<int>(Debugger::debugger().peek(myPC + myOffset));
      ++myPC;
    }
    isType = checkBits(myPC, type,
                       Device::CODE | (type != Device::DATA ? Device::DATA : 0) |
                       Device::GFX | Device::PGFX |
                       Device::COL | Device::PCOL | Device::BCOL | Device::AUD);
    referenced = checkBit(myPC, Device::REFERENCED);
  }
  if (!lineEmpty)
    addEntry(type);
  /*myDisasmBuf << "    '     ' ";
  addEntry(Device::NONE);*/
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DiStella::processDirectives(const CartDebug::DirectiveList& directives)
{
  for (const auto& tag : directives) {
    if (check_range(tag.start, tag.end))
      for (uInt32 k = tag.start; k <= tag.end; ++k)
        mark(k, tag.type, true);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DiStella::Settings DiStella::settings;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<DiStella::Instruction_tag, 256> DiStella::ourLookup = { {
  /****  Positive  ****/

  /* 00 */{"brk", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  7, 1}, /* Pseudo Absolute */
  /* 01 */{"ora", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (Indirect,X) */
  /* 02 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 03 */{"SLO", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::WRITE, 8, 2},

  /* 04 */{"NOP", AddressingMode::ZERO_PAGE,   AccessMode::NONE, RWMode::NONE,  3, 2},
  /* 05 */{"ora", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* 06 */{"asl", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2}, /* Zeropage */
  /* 07 */{"SLO", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2},

  /* 08 */{"php", AddressingMode::IMPLIED,     AccessMode::SR,   RWMode::NONE,  3, 1},
  /* 09 */{"ora", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* 0a */{"asl", AddressingMode::ACCUMULATOR, AccessMode::AC,   RWMode::WRITE, 2, 1}, /* Accumulator */
  /* 0b */{"ANC", AddressingMode::IMMEDIATE,   AccessMode::ACIM, RWMode::READ,  2, 2},

  /* 0c */{"NOP", AddressingMode::ABSOLUTE,    AccessMode::NONE, RWMode::NONE,  4, 3},
  /* 0d */{"ora", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* 0e */{"asl", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3}, /* Absolute */
  /* 0f */{"SLO", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3},

  /* 10 */{"bpl", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* 11 */{"ora", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (Indirect),Y */
  /* 12 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 13 */{"SLO", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::WRITE, 8, 2},

  /* 14 */{"NOP", AddressingMode::ZERO_PAGE_X, AccessMode::NONE, RWMode::NONE,  4, 2},
  /* 15 */{"ora", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* 16 */{"asl", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2}, /* Zeropage,X */
  /* 17 */{"SLO", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2},

  /* 18 */{"clc", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 19 */{"ora", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* 1a */{"NOP", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 1b */{"SLO", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::WRITE, 7, 3},

  /* 1c */{"NOP", AddressingMode::ABSOLUTE_X,  AccessMode::NONE, RWMode::NONE,  4, 3},
  /* 1d */{"ora", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* 1e */{"asl", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3}, /* Absolute,X */
  /* 1f */{"SLO", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3},

  /* 20 */{"jsr", AddressingMode::ABSOLUTE,    AccessMode::ADDR, RWMode::READ,  6, 3},
  /* 21 */{"and", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (Indirect ,X) */
  /* 22 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 23 */{"RLA", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::WRITE, 8, 2},

  /* 24 */{"bit", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* 25 */{"and", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* 26 */{"rol", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2}, /* Zeropage */
  /* 27 */{"RLA", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2},

  /* 28 */{"plp", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  4, 1},
  /* 29 */{"and", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* 2a */{"rol", AddressingMode::ACCUMULATOR, AccessMode::AC,   RWMode::WRITE, 2, 1}, /* Accumulator */
  /* 2b */{"ANC", AddressingMode::IMMEDIATE,   AccessMode::ACIM, RWMode::READ,  2, 2},

  /* 2c */{"bit", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* 2d */{"and", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* 2e */{"rol", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3}, /* Absolute */
  /* 2f */{"RLA", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3},

  /* 30 */{"bmi", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* 31 */{"and", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (Indirect),Y */
  /* 32 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 33 */{"RLA", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::WRITE, 8, 2},

  /* 34 */{"NOP", AddressingMode::ZERO_PAGE_X, AccessMode::NONE, RWMode::NONE,  4, 2},
  /* 35 */{"and", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* 36 */{"rol", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2}, /* Zeropage,X */
  /* 37 */{"RLA", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2},

  /* 38 */{"sec", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 39 */{"and", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* 3a */{"NOP", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 3b */{"RLA", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::WRITE, 7, 3},

  /* 3c */{"NOP", AddressingMode::ABSOLUTE_X,  AccessMode::NONE, RWMode::NONE,  4, 3},
  /* 3d */{"and", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* 3e */{"rol", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3}, /* Absolute,X */
  /* 3f */{"RLA", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3},

  /* 40 */{"rti", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  6, 1},
  /* 41 */{"eor", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (Indirect,X) */
  /* 42 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 43 */{"SRE", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::WRITE, 8, 2},

  /* 44 */{"NOP", AddressingMode::ZERO_PAGE,   AccessMode::NONE, RWMode::NONE,  3, 2},
  /* 45 */{"eor", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* 46 */{"lsr", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2}, /* Zeropage */
  /* 47 */{"SRE", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2},

  /* 48 */{"pha", AddressingMode::IMPLIED,     AccessMode::AC,   RWMode::NONE,  3, 1},
  /* 49 */{"eor", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* 4a */{"lsr", AddressingMode::ACCUMULATOR, AccessMode::AC,   RWMode::WRITE, 2, 1}, /* Accumulator */
  /* 4b */{"ASR", AddressingMode::IMMEDIATE,   AccessMode::ACIM, RWMode::READ,  2, 2}, /* (AC & IMM) >>1 */

  /* 4c */{"jmp", AddressingMode::ABSOLUTE,    AccessMode::ADDR, RWMode::READ,  3, 3}, /* Absolute */
  /* 4d */{"eor", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* 4e */{"lsr", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3}, /* Absolute */
  /* 4f */{"SRE", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3},

  /* 50 */{"bvc", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* 51 */{"eor", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (Indirect),Y */
  /* 52 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 53 */{"SRE", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::WRITE, 8, 2},

  /* 54 */{"NOP", AddressingMode::ZERO_PAGE_X, AccessMode::NONE, RWMode::NONE,  4, 2},
  /* 55 */{"eor", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* 56 */{"lsr", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2}, /* Zeropage,X */
  /* 57 */{"SRE", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2},

  /* 58 */{"cli", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 59 */{"eor", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* 5a */{"NOP", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 5b */{"SRE", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::WRITE, 7, 3},

  /* 5c */{"NOP", AddressingMode::ABSOLUTE_X,  AccessMode::NONE, RWMode::NONE,  4, 3},
  /* 5d */{"eor", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* 5e */{"lsr", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3}, /* Absolute,X */
  /* 5f */{"SRE", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3},

  /* 60 */{"rts", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  6, 1},
  /* 61 */{"adc", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (Indirect,X) */
  /* 62 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* 63 */{"RRA", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::WRITE, 8, 2},

  /* 64 */{"NOP", AddressingMode::ZERO_PAGE,   AccessMode::NONE, RWMode::NONE,  3, 2},
  /* 65 */{"adc", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* 66 */{"ror", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2}, /* Zeropage */
  /* 67 */{"RRA", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2},

  /* 68 */{"pla", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  4, 1},
  /* 69 */{"adc", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* 6a */{"ror", AddressingMode::ACCUMULATOR, AccessMode::AC,   RWMode::WRITE, 2, 1}, /* Accumulator */
  /* 6b */{"ARR", AddressingMode::IMMEDIATE,   AccessMode::ACIM, RWMode::READ,  2, 2}, /* ARR isn't typo */

  /* 6c */{"jmp", AddressingMode::ABS_INDIRECT,AccessMode::AIND, RWMode::READ,  5, 3}, /* Indirect */
  /* 6d */{"adc", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* 6e */{"ror", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3}, /* Absolute */
  /* 6f */{"RRA", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3},

  /* 70 */{"bvs", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* 71 */{"adc", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (Indirect),Y */
  /* 72 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT relative? */
  /* 73 */{"RRA", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::WRITE, 8, 2},

  /* 74 */{"NOP", AddressingMode::ZERO_PAGE_X, AccessMode::NONE, RWMode::NONE,  4, 2},
  /* 75 */{"adc", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* 76 */{"ror", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2}, /* Zeropage,X */
  /* 77 */{"RRA", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2},

  /* 78 */{"sei", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 79 */{"adc", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* 7a */{"NOP", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* 7b */{"RRA", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::WRITE, 7, 3},

  /* 7c */{"NOP", AddressingMode::ABSOLUTE_X,  AccessMode::NONE, RWMode::NONE,  4, 3},
  /* 7d */{"adc", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3},  /* Absolute,X */
  /* 7e */{"ror", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3},  /* Absolute,X */
  /* 7f */{"RRA", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3},

  /****  Negative  ****/

  /* 80 */{"NOP", AddressingMode::IMMEDIATE,   AccessMode::NONE, RWMode::NONE,  2, 2},
  /* 81 */{"sta", AddressingMode::INDIRECT_X,  AccessMode::AC,   RWMode::WRITE, 6, 2}, /* (Indirect,X) */
  /* 82 */{"NOP", AddressingMode::IMMEDIATE,   AccessMode::NONE, RWMode::NONE,  2, 2},
  /* 83 */{"SAX", AddressingMode::INDIRECT_X,  AccessMode::ANXR, RWMode::WRITE, 6, 2},

  /* 84 */{"sty", AddressingMode::ZERO_PAGE,   AccessMode::YR,   RWMode::WRITE, 3, 2}, /* Zeropage */
  /* 85 */{"sta", AddressingMode::ZERO_PAGE,   AccessMode::AC,   RWMode::WRITE, 3, 2}, /* Zeropage */
  /* 86 */{"stx", AddressingMode::ZERO_PAGE,   AccessMode::XR,   RWMode::WRITE, 3, 2}, /* Zeropage */
  /* 87 */{"SAX", AddressingMode::ZERO_PAGE,   AccessMode::ANXR, RWMode::WRITE, 3, 2},

  /* 88 */{"dey", AddressingMode::IMPLIED,     AccessMode::YR,   RWMode::NONE,  2, 1},
  /* 89 */{"NOP", AddressingMode::IMMEDIATE,   AccessMode::NONE, RWMode::NONE,  2, 2},
  /* 8a */{"txa", AddressingMode::IMPLIED,     AccessMode::XR,   RWMode::NONE,  2, 1},
  /****  very abnormal: usually AC = AC | #$EE & XR & #$oper  ****/
  /* 8b */{"ANE", AddressingMode::IMMEDIATE,   AccessMode::AXIM, RWMode::READ,  2, 2},

  /* 8c */{"sty", AddressingMode::ABSOLUTE,    AccessMode::YR,   RWMode::WRITE, 4, 3}, /* Absolute */
  /* 8d */{"sta", AddressingMode::ABSOLUTE,    AccessMode::AC,   RWMode::WRITE, 4, 3}, /* Absolute */
  /* 8e */{"stx", AddressingMode::ABSOLUTE,    AccessMode::XR,   RWMode::WRITE, 4, 3}, /* Absolute */
  /* 8f */{"SAX", AddressingMode::ABSOLUTE,    AccessMode::ANXR, RWMode::WRITE, 4, 3},

  /* 90 */{"bcc", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* 91 */{"sta", AddressingMode::INDIRECT_Y,  AccessMode::AC,   RWMode::WRITE, 6, 2}, /* (Indirect),Y */
  /* 92 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT relative? */
  /* 93 */{"SHA", AddressingMode::INDIRECT_Y,  AccessMode::ANXR, RWMode::WRITE, 6, 2},

  /* 94 */{"sty", AddressingMode::ZERO_PAGE_X, AccessMode::YR,   RWMode::WRITE, 4, 2}, /* Zeropage,X */
  /* 95 */{"sta", AddressingMode::ZERO_PAGE_X, AccessMode::AC,   RWMode::WRITE, 4, 2}, /* Zeropage,X */
  /* 96 */{"stx", AddressingMode::ZERO_PAGE_Y, AccessMode::XR,   RWMode::WRITE, 4, 2}, /* Zeropage,Y */
  /* 97 */{"SAX", AddressingMode::ZERO_PAGE_Y, AccessMode::ANXR, RWMode::WRITE, 4, 2},

  /* 98 */{"tya", AddressingMode::IMPLIED,     AccessMode::YR,   RWMode::NONE,  2, 1},
  /* 99 */{"sta", AddressingMode::ABSOLUTE_Y,  AccessMode::AC,   RWMode::WRITE, 5, 3}, /* Absolute,Y */
  /* 9a */{"txs", AddressingMode::IMPLIED,     AccessMode::XR,   RWMode::NONE,  2, 1},
  /*** This is very mysterious command ... */
  /* 9b */{"SHS", AddressingMode::ABSOLUTE_Y,  AccessMode::ANXR, RWMode::WRITE, 5, 3},

  /* 9c */{"SHY", AddressingMode::ABSOLUTE_X,  AccessMode::YR,   RWMode::WRITE, 5, 3},
  /* 9d */{"sta", AddressingMode::ABSOLUTE_X,  AccessMode::AC,   RWMode::WRITE, 5, 3}, /* Absolute,X */
  /* 9e */{"SHX", AddressingMode::ABSOLUTE_Y,  AccessMode::XR  , RWMode::WRITE, 5, 3},
  /* 9f */{"SHA", AddressingMode::ABSOLUTE_Y,  AccessMode::ANXR, RWMode::WRITE, 5, 3},

  /* a0 */{"ldy", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* a1 */{"lda", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (indirect,X) */
  /* a2 */{"ldx", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* a3 */{"LAX", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (indirect,X) */

  /* a4 */{"ldy", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* a5 */{"lda", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* a6 */{"ldx", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* a7 */{"LAX", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2},

  /* a8 */{"tay", AddressingMode::IMPLIED,     AccessMode::AC,   RWMode::NONE,  2, 1},
  /* a9 */{"lda", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* aa */{"tax", AddressingMode::IMPLIED,     AccessMode::AC,   RWMode::NONE,  2, 1},
  /* ab */{"LXA", AddressingMode::IMMEDIATE,   AccessMode::ACIM, RWMode::READ,  2, 2}, /* LXA isn't a typo */

  /* ac */{"ldy", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* ad */{"lda", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* ae */{"ldx", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* af */{"LAX", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3},

  /* b0 */{"bcs", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* b1 */{"lda", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (indirect),Y */
  /* b2 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* b3 */{"LAX", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2},

  /* b4 */{"ldy", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* b5 */{"lda", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* b6 */{"ldx", AddressingMode::ZERO_PAGE_Y, AccessMode::ZERY, RWMode::READ,  4, 2}, /* Zeropage,Y */
  /* b7 */{"LAX", AddressingMode::ZERO_PAGE_Y, AccessMode::ZERY, RWMode::READ,  4, 2},

  /* b8 */{"clv", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* b9 */{"lda", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* ba */{"tsx", AddressingMode::IMPLIED,     AccessMode::SP,   RWMode::NONE,  2, 1},
  /* bb */{"LAS", AddressingMode::ABSOLUTE_Y,  AccessMode::SABY, RWMode::READ,  4, 3},

  /* bc */{"ldy", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* bd */{"lda", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* be */{"ldx", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* bf */{"LAX", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3},

  /* c0 */{"cpy", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* c1 */{"cmp", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (Indirect,X) */
  /* c2 */{"NOP", AddressingMode::IMMEDIATE,   AccessMode::NONE, RWMode::NONE,  2, 2}, /* occasional TILT */
  /* c3 */{"DCP", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::WRITE, 8, 2},

  /* c4 */{"cpy", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* c5 */{"cmp", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* c6 */{"dec", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2}, /* Zeropage */
  /* c7 */{"DCP", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2},

  /* c8 */{"iny", AddressingMode::IMPLIED,     AccessMode::YR,   RWMode::NONE,  2, 1},
  /* c9 */{"cmp", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* ca */{"dex", AddressingMode::IMPLIED,     AccessMode::XR,   RWMode::NONE,  2, 1},
  /* cb */{"SBX", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2},

  /* cc */{"cpy", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* cd */{"cmp", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* ce */{"dec", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3}, /* Absolute */
  /* cf */{"DCP", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3},

  /* d0 */{"bne", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* d1 */{"cmp", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (Indirect),Y */
  /* d2 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* d3 */{"DCP", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::WRITE, 8, 2},

  /* d4 */{"NOP", AddressingMode::ZERO_PAGE_X, AccessMode::NONE, RWMode::NONE,  4, 2},
  /* d5 */{"cmp", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* d6 */{"dec", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2}, /* Zeropage,X */
  /* d7 */{"DCP", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2},

  /* d8 */{"cld", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* d9 */{"cmp", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* da */{"NOP", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* db */{"DCP", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::WRITE, 7, 3},

  /* dc */{"NOP", AddressingMode::ABSOLUTE_X,  AccessMode::NONE, RWMode::NONE,  4, 3},
  /* dd */{"cmp", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* de */{"dec", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3}, /* Absolute,X */
  /* df */{"DCP", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3},

  /* e0 */{"cpx", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* e1 */{"sbc", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::READ,  6, 2}, /* (Indirect,X) */
  /* e2 */{"NOP", AddressingMode::IMMEDIATE,   AccessMode::NONE, RWMode::NONE,  2, 2},
  /* e3 */{"ISB", AddressingMode::INDIRECT_X,  AccessMode::INDX, RWMode::WRITE, 8, 2},

  /* e4 */{"cpx", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* e5 */{"sbc", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::READ,  3, 2}, /* Zeropage */
  /* e6 */{"inc", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2}, /* Zeropage */
  /* e7 */{"ISB", AddressingMode::ZERO_PAGE,   AccessMode::ZERO, RWMode::WRITE, 5, 2},

  /* e8 */{"inx", AddressingMode::IMPLIED,     AccessMode::XR,   RWMode::NONE,  2, 1},
  /* e9 */{"sbc", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* Immediate */
  /* ea */{"nop", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* eb */{"SBC", AddressingMode::IMMEDIATE,   AccessMode::IMM,  RWMode::READ,  2, 2}, /* same as e9 */

  /* ec */{"cpx", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* ed */{"sbc", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::READ,  4, 3}, /* Absolute */
  /* ee */{"inc", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3}, /* Absolute */
  /* ef */{"ISB", AddressingMode::ABSOLUTE,    AccessMode::ABS,  RWMode::WRITE, 6, 3},

  /* f0 */{"beq", AddressingMode::RELATIVE,    AccessMode::REL,  RWMode::READ,  2, 2},
  /* f1 */{"sbc", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::READ,  5, 2}, /* (Indirect),Y */
  /* f2 */{".JAM",AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  0, 1}, /* TILT */
  /* f3 */{"ISB", AddressingMode::INDIRECT_Y,  AccessMode::INDY, RWMode::WRITE, 8, 2},

  /* f4 */{"NOP", AddressingMode::ZERO_PAGE_X, AccessMode::NONE, RWMode::NONE,  4, 2},
  /* f5 */{"sbc", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::READ,  4, 2}, /* Zeropage,X */
  /* f6 */{"inc", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2}, /* Zeropage,X */
  /* f7 */{"ISB", AddressingMode::ZERO_PAGE_X, AccessMode::ZERX, RWMode::WRITE, 6, 2},

  /* f8 */{"sed", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* f9 */{"sbc", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::READ,  4, 3}, /* Absolute,Y */
  /* fa */{"NOP", AddressingMode::IMPLIED,     AccessMode::NONE, RWMode::NONE,  2, 1},
  /* fb */{"ISB", AddressingMode::ABSOLUTE_Y,  AccessMode::ABSY, RWMode::WRITE, 7, 3},

  /* fc */{"NOP" ,AddressingMode::ABSOLUTE_X,  AccessMode::NONE, RWMode::NONE,  4, 3},
  /* fd */{"sbc", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::READ,  4, 3}, /* Absolute,X */
  /* fe */{"inc", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3}, /* Absolute,X */
  /* ff */{"ISB", AddressingMode::ABSOLUTE_X,  AccessMode::ABSX, RWMode::WRITE, 7, 3}
} };
