//============================================================================
//
// MM     MM  6666  555555  0000   2222
// MMMM MMMM 66  66 55     00  00 22  22
// MM MMM MM 66     55     00  00     22
// MM  M  MM 66666  55555  00  00  22222  --  "A 6502 Microprocessor Emulator"
// MM     MM 66  66     55 00  00 22
// MM     MM 66  66 55  55 00  00 22
// MM     MM  6666   5555   0000  222222
//
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

/**
  Code and cases to emulate each of the 6502 instructions.

  Recompile with the following:
    'm4 M6502.m4 > M6502.ins'

  @author  Bradford W. Mott and Stephen Anthony
*/

#ifndef NOTSAMEPAGE
  #define NOTSAMEPAGE(_addr1, _addr2) (((_addr1) ^ (_addr2)) & 0xff00)
#endif

#ifndef SET_LAST_PEEK
  #ifdef DEBUGGER_SUPPORT
    #define SET_LAST_PEEK(_addr1, _addr2) _addr1 = _addr2;
  #else
    #define SET_LAST_PEEK(_addr1, _addr2)
  #endif
#endif

#ifndef CLEAR_LAST_PEEK
  #ifdef DEBUGGER_SUPPORT
    #define CLEAR_LAST_PEEK(_addr) _addr = -1;
  #else
    #define CLEAR_LAST_PEEK(_addr)
  #endif
#endif

#ifndef SET_LAST_POKE
  #ifdef DEBUGGER_SUPPORT
    #define SET_LAST_POKE(_addr) myDataAddressForPoke = _addr;
  #else
    #define SET_LAST_POKE(_addr)
  #endif
#endif


define(M6502_IMPLIED, `{
  peek(PC, DISASM_NONE);
}')

define(M6502_IMMEDIATE_READ, `{
  operand = peek(PC++, DISASM_CODE);
}')

define(M6502_IMMEDIATE_READ_DISCARD_OPERAND, `{
  peek(PC++, DISASM_CODE);
}')

define(M6502_ABSOLUTE_READ, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  intermediateAddress |= (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  operand = peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ABSOLUTE_READ_DISCARD_OPERAND, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  intermediateAddress |= (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ABSOLUTE_WRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  operandAddress |= (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
}')

define(M6502_ABSOLUTE_READMODIFYWRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  operandAddress |= (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_ABSOLUTEX_READ, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  intermediateAddress = high | static_cast<uInt8>(low + X);
  if((low + X) > 0xFF)
  {
    peek(intermediateAddress, DISASM_NONE);
    intermediateAddress = (high | low) + X;
    operand = peek(intermediateAddress, DISASM_DATA);
  }
  else
  {
    operand = peek(intermediateAddress, DISASM_DATA);
  }
}')

define(M6502_ABSOLUTEX_READ_DISCARD_OPERAND, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  intermediateAddress = high | static_cast<uInt8>(low + X);
  if((low + X) > 0xFF)
  {
    peek(intermediateAddress, DISASM_NONE);
    intermediateAddress = (high | low) + X;
    peek(intermediateAddress, DISASM_DATA);
  }
  else
  {
    peek(intermediateAddress, DISASM_DATA);
  }
}')

define(M6502_ABSOLUTEX_WRITE, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  peek(high | static_cast<uInt8>(low + X), DISASM_NONE);
  operandAddress = (high | low) + X;
}')

define(M6502_ABSOLUTEX_READMODIFYWRITE, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  peek(high | static_cast<uInt8>(low + X), DISASM_NONE);
  operandAddress = (high | low) + X;
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_ABSOLUTEY_READ, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  intermediateAddress = high | static_cast<uInt8>(low + Y);
  if((low + Y) > 0xFF)
  {
    peek(intermediateAddress, DISASM_NONE);
    intermediateAddress = (high | low) + Y;
    operand = peek(intermediateAddress, DISASM_DATA);
  }
  else
  {
    operand = peek(intermediateAddress, DISASM_DATA);
  }
}')

define(M6502_ABSOLUTEY_WRITE, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  peek(high | static_cast<uInt8>(low + Y), DISASM_NONE);
  operandAddress = (high | low) + Y;
}')

define(M6502_ABSOLUTEY_READMODIFYWRITE, `{
  const uInt16 low = peek(PC++, DISASM_CODE);
  const uInt16 high = (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);
  peek(high | static_cast<uInt8>(low + Y), DISASM_NONE);
  operandAddress = (high | low) + Y;
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_ZERO_READ, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  operand = peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ZERO_READ_DISCARD_OPERAND, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ZERO_WRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
}')

define(M6502_ZERO_READMODIFYWRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_ZEROX_READ, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  peek(intermediateAddress, DISASM_NONE);
  intermediateAddress += X;
  operand = peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ZEROX_READ_DISCARD_OPERAND, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  peek(intermediateAddress, DISASM_NONE);
  intermediateAddress += X;
  peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ZEROX_WRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  peek(operandAddress, DISASM_NONE);
  operandAddress = (operandAddress + X) & 0xFF;
}')

define(M6502_ZEROX_READMODIFYWRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  peek(operandAddress, DISASM_NONE);
  operandAddress = (operandAddress + X) & 0xFF;
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_ZEROY_READ, `{
  intermediateAddress = peek(PC++, DISASM_CODE);
  peek(intermediateAddress, DISASM_NONE);
  intermediateAddress += Y;
  operand = peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_ZEROY_WRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  peek(operandAddress, DISASM_NONE);
  operandAddress = (operandAddress + Y) & 0xFF;
}')

define(M6502_ZEROY_READMODIFYWRITE, `{
  operandAddress = peek(PC++, DISASM_CODE);
  peek(operandAddress, DISASM_NONE);
  operandAddress = (operandAddress + Y) & 0xFF;
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_INDIRECT, `{
  uInt16 addr = peek(PC++, DISASM_CODE);
  addr |= (static_cast<uInt16>(peek(PC++, DISASM_CODE)) << 8);

  // Simulate the error in the indirect addressing mode!
  const uInt16 high = NOTSAMEPAGE(addr, addr + 1) ? (addr & 0xff00) : (addr + 1);

  operandAddress = peek(addr, DISASM_DATA);
  operandAddress |= (static_cast<uInt16>(peek(high, DISASM_DATA)) << 8);
}')

define(M6502_INDIRECTX_READ, `{
  uInt8 pointer = peek(PC++, DISASM_CODE);
  peek(pointer, DISASM_NONE);
  pointer += X;
  intermediateAddress = peek(pointer++, DISASM_DATA);
  intermediateAddress |= (static_cast<uInt16>(peek(pointer, DISASM_DATA)) << 8);
  operand = peek(intermediateAddress, DISASM_DATA);
}')

define(M6502_INDIRECTX_WRITE, `{
  uInt8 pointer = peek(PC++, DISASM_CODE);
  peek(pointer, DISASM_NONE);
  pointer += X;
  operandAddress = peek(pointer++, DISASM_DATA);
  operandAddress |= (static_cast<uInt16>(peek(pointer, DISASM_DATA)) << 8);
}')

define(M6502_INDIRECTX_READMODIFYWRITE, `{
  uInt8 pointer = peek(PC++, DISASM_CODE);
  peek(pointer, DISASM_NONE);
  pointer += X;
  operandAddress = peek(pointer++, DISASM_DATA);
  operandAddress |= (static_cast<uInt16>(peek(pointer, DISASM_DATA)) << 8);
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_INDIRECTY_READ, `{
  uInt8 pointer = peek(PC++, DISASM_CODE);
  const uInt16 low = peek(pointer++, DISASM_DATA);
  const uInt16 high = (static_cast<uInt16>(peek(pointer, DISASM_DATA)) << 8);
  intermediateAddress = high | static_cast<uInt8>(low + Y);
  if((low + Y) > 0xFF)
  {
    peek(intermediateAddress, DISASM_NONE);
    intermediateAddress = (high | low) + Y;
    operand = peek(intermediateAddress, DISASM_DATA);
  }
  else
  {
    operand = peek(intermediateAddress, DISASM_DATA);
  }
}')

define(M6502_INDIRECTY_WRITE, `{
  uInt8 pointer = peek(PC++, DISASM_CODE);
  const uInt16 low = peek(pointer++, DISASM_DATA);
  const uInt16 high = (static_cast<uInt16>(peek(pointer, DISASM_DATA)) << 8);
  peek(high | static_cast<uInt8>(low + Y), DISASM_NONE);
  operandAddress = (high | low) + Y;
}')

define(M6502_INDIRECTY_READMODIFYWRITE, `{
  uInt8 pointer = peek(PC++, DISASM_CODE);
  const uInt16 low = peek(pointer++, DISASM_DATA);
  const uInt16 high = (static_cast<uInt16>(peek(pointer, DISASM_DATA)) << 8);
  peek(high | static_cast<uInt8>(low + Y), DISASM_NONE);
  operandAddress = (high | low) + Y;
  operand = peek(operandAddress, DISASM_DATA);
  poke(operandAddress, operand, DISASM_WRITE);
}')

define(M6502_BCC, `{
  if(!C)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BCS, `{
  if(C)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BEQ, `{
  if(!notZ)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BMI, `{
  if(N)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BNE, `{
  if(notZ)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BPL, `{
  if(!N)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BVC, `{
  if(!V)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_BVS, `{
  if(V)
  {
    peek(PC, DISASM_NONE);
    const uInt16 address = PC + static_cast<Int8>(operand);
    if(NOTSAMEPAGE(PC, address))
      peek((PC & 0xFF00) | (address & 0x00FF), DISASM_NONE);
    PC = address;
  }
}')

define(M6502_ADC, `{
  if(!D)
  {
    const Int32 sum = A + operand + (C ? 1 : 0);
    N = sum & 0x80;
    V = ~(A ^ operand) & (A ^ sum) & 0x80;
    notZ = sum & 0xff;
    C = sum & 0xff00;

    A = static_cast<uInt8>(sum);
  }
  else
  {
    Int32 lo = (A & 0x0f) + (operand & 0x0f) + (C ? 1 : 0);
    Int32 hi = (A & 0xf0) + (operand & 0xf0);
    notZ = (lo+hi) & 0xff;
    if(lo > 0x09)
    {
      hi += 0x10;
      lo += 0x06;
    }
    N = hi & 0x80;
    V = ~(A ^ operand) & (A ^ hi) & 0x80;
    if(hi > 0x90)
      hi += 0x60;
    C = hi & 0xff00;

    A = (lo & 0x0f) + (hi & 0xf0);
  }
}')

define(M6502_ANC, `{
  A &= operand;
  notZ = A;
  N = A & 0x80;
  C = N;
}')

define(M6502_AND, `{
  A &= operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_ANE, `{
  // NOTE: The implementation of this instruction is based on
  // information from the 64doc.txt file.  This instruction is
  // reported to be unstable!
  A = (A | 0xee) & X & operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_ARR, `{
  // NOTE: The implementation of this instruction is based on
  // information from the 64doc.txt file.  There are mixed
  // reports on its operation!
  if(!D)
  {
    A &= operand;
    A = ((A >> 1) & 0x7f) | (C ? 0x80 : 0x00);

    C = A & 0x40;
    V = (A & 0x40) ^ ((A & 0x20) << 1);

    notZ = A;
    N = A & 0x80;
  }
  else
  {
    const uInt8 value = A & operand;

    A = ((value >> 1) & 0x7f) | (C ? 0x80 : 0x00);
    N = C;
    notZ = A;
    V = (value ^ A) & 0x40;

    if(((value & 0x0f) + (value & 0x01)) > 0x05)
    {
      A = (A & 0xf0) | ((A + 0x06) & 0x0f);
    }

    if(((value & 0xf0) + (value & 0x10)) > 0x50)
    {
      A += 0x60;
      C = true;
    }
    else
    {
      C = false;
    }
  }
}')

define(M6502_ASL, `{
  // Set carry flag according to the left-most bit in value
  C = operand & 0x80;

  operand <<= 1;
  poke(operandAddress, operand, DISASM_WRITE);

  notZ = operand;
  N = operand & 0x80;
}')

define(M6502_ASLA, `{
  // Set carry flag according to the left-most bit in A
  C = A & 0x80;

  A <<= 1;

  notZ = A;
  N = A & 0x80;
}')

define(M6502_ASR, `{
  A &= operand;

  // Set carry flag according to the right-most bit
  C = A & 0x01;

  A >>= 1;

  notZ = A;
  N = false;
}')

define(M6502_BIT, `{
  notZ = (A & operand);
  N = operand & 0x80;
  V = operand & 0x40;
}')

define(M6502_BRK, `{
  peek(PC++, DISASM_NONE);

  B = true;

  poke(0x0100 + SP--, PC >> 8, DISASM_WRITE);
  poke(0x0100 + SP--, PC & 0x00ff, DISASM_WRITE);
  poke(0x0100 + SP--, PS(), DISASM_WRITE);

  I = true;

  PC = peek(0xfffe, DISASM_DATA);
  PC |= (static_cast<uInt16>(peek(0xffff, DISASM_DATA)) << 8);
}')

define(M6502_CLC, `{
  C = false;
}')

define(M6502_CLD, `{
  D = false;
}')

define(M6502_CLI, `{
  I = false;
}')

define(M6502_CLV, `{
  V = false;
}')

define(M6502_CMP, `{
  const uInt16 value = static_cast<uInt16>(A) - static_cast<uInt16>(operand);

  notZ = value;
  N = value & 0x0080;
  C = !(value & 0x0100);
}')

define(M6502_CPX, `{
  const uInt16 value = static_cast<uInt16>(X) - static_cast<uInt16>(operand);

  notZ = value;
  N = value & 0x0080;
  C = !(value & 0x0100);
}')

define(M6502_CPY, `{
  const uInt16 value = static_cast<uInt16>(Y) - static_cast<uInt16>(operand);

  notZ = value;
  N = value & 0x0080;
  C = !(value & 0x0100);
}')

define(M6502_DCP, `{
  const uInt8 value = operand - 1;
  poke(operandAddress, value, DISASM_WRITE);

  const uInt16 value2 = static_cast<uInt16>(A) - static_cast<uInt16>(value);
  notZ = value2;
  N = value2 & 0x0080;
  C = !(value2 & 0x0100);
}')

define(M6502_DEC, `{
  const uInt8 value = operand - 1;
  poke(operandAddress, value, DISASM_WRITE);

  notZ = value;
  N = value & 0x80;
}')

define(M6502_DEX, `{
  X--;

  notZ = X;
  N = X & 0x80;
}')


define(M6502_DEY, `{
  Y--;

  notZ = Y;
  N = Y & 0x80;
}')

define(M6502_EOR, `{
  A ^= operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_INC, `{
  const uInt8 value = operand + 1;
  poke(operandAddress, value, DISASM_WRITE);

  notZ = value;
  N = value & 0x80;
}')

define(M6502_INX, `{
  X++;
  notZ = X;
  N = X & 0x80;
}')

define(M6502_INY, `{
  Y++;
  notZ = Y;
  N = Y & 0x80;
}')

define(M6502_ISB, `{
  operand = operand + 1;
  poke(operandAddress, operand, DISASM_WRITE);

  // N, V, Z, C flags are the same in either mode (C calculated at the end)
  const Int32 sum = A - operand - (C ? 0 : 1);
  N = sum & 0x80;
  V = (A ^ operand) & (A ^ sum) & 0x80;
  notZ = sum & 0xff;

  if(!D)
  {
    A = static_cast<uInt8>(sum);
  }
  else
  {
    Int32 lo = (A & 0x0f) - (operand & 0x0f) - (C ? 0 : 1);
    Int32 hi = (A & 0xf0) - (operand & 0xf0);
    if(lo & 0x10)
    {
      lo -= 6;
      hi--;
    }
    if(hi & 0x0100)
      hi -= 0x60;

    A = (lo & 0x0f) | (hi & 0xf0);
  }
  C = (sum & 0xff00) == 0;
}')

define(M6502_JMP, `{
  PC = operandAddress;
}')

define(M6502_JSR, `{
  const uInt8 low = peek(PC++, DISASM_CODE);
  peek(0x0100 + SP, DISASM_NONE);

  // It seems that the 650x does not push the address of the next instruction
  // on the stack it actually pushes the address of the next instruction
  // minus one.  This is compensated for in the RTS instruction
  poke(0x0100 + SP--, PC >> 8, DISASM_WRITE);
  poke(0x0100 + SP--, PC & 0xff, DISASM_WRITE);

  PC = (low | (static_cast<uInt16>(peek(PC, DISASM_CODE)) << 8));
}')

define(M6502_LAS, `{
  A = X = SP = SP & operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_LAX, `{
  A = operand;
  X = operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_LDA, `{
  A = operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_LDX, `{
  X = operand;
  notZ = X;
  N = X & 0x80;
}')

define(M6502_LDY, `{
  Y = operand;
  notZ = Y;
  N = Y & 0x80;
}')

define(M6502_LSR, `{
  // Set carry flag according to the right-most bit in value
  C = operand & 0x01;

  operand >>= 1;
  poke(operandAddress, operand, DISASM_WRITE);

  notZ = operand;
  N = false;
}')

define(M6502_LSRA, `{
  // Set carry flag according to the right-most bit
  C = A & 0x01;

  A >>= 1;

  notZ = A;
  N = false;
}')

define(M6502_LXA, `{
  // NOTE: The implementation of this instruction is based on
  // information from the 64doc.txt file.  This instruction is
  // reported to be very unstable!
  A = X = (A | 0xee) & operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_NOP, `{
}')

define(M6502_ORA, `{
  A |= operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_PHA, `{
  poke(0x0100 + SP--, A, DISASM_WRITE);
}')

define(M6502_PHP, `{
  poke(0x0100 + SP--, PS(), DISASM_WRITE);
}')

define(M6502_PLA, `{
  peek(0x0100 + SP++, DISASM_NONE);
  A = peek(0x0100 + SP, DISASM_DATA);
  notZ = A;
  N = A & 0x80;
}')

define(M6502_PLP, `{
  peek(0x0100 + SP++, DISASM_NONE);
  PS(peek(0x0100 + SP, DISASM_DATA));
}')

define(M6502_RLA, `{
  const uInt8 value = (operand << 1) | (C ? 1 : 0);
  poke(operandAddress, value, DISASM_WRITE);

  A &= value;
  C = operand & 0x80;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_ROL, `{
  const bool oldC = C;

  // Set carry flag according to the left-most bit in operand
  C = operand & 0x80;

  operand = (operand << 1) | (oldC ? 1 : 0);
  poke(operandAddress, operand, DISASM_WRITE);

  notZ = operand;
  N = operand & 0x80;
}')

define(M6502_ROLA, `{
  const bool oldC = C;

  // Set carry flag according to the left-most bit
  C = A & 0x80;

  A = (A << 1) | (oldC ? 1 : 0);

  notZ = A;
  N = A & 0x80;
}')

define(M6502_ROR, `{
  const bool oldC = C;

  // Set carry flag according to the right-most bit
  C = operand & 0x01;

  operand = ((operand >> 1) & 0x7f) | (oldC ? 0x80 : 0x00);
  poke(operandAddress, operand, DISASM_WRITE);

  notZ = operand;
  N = operand & 0x80;
}')

define(M6502_RORA, `{
  const bool oldC = C;

  // Set carry flag according to the right-most bit
  C = A & 0x01;

  A = ((A >> 1) & 0x7f) | (oldC ? 0x80 : 0x00);

  notZ = A;
  N = A & 0x80;
}')

define(M6502_RRA, `{
  const bool oldC = C;

  // Set carry flag according to the right-most bit
  C = operand & 0x01;

  operand = ((operand >> 1) & 0x7f) | (oldC ? 0x80 : 0x00);
  poke(operandAddress, operand, DISASM_WRITE);

  if(!D)
  {
    const Int32 sum = A + operand + (C ? 1 : 0);
    N = sum & 0x80;
    V = ~(A ^ operand) & (A ^ sum) & 0x80;
    notZ = sum & 0xff;
    C = sum & 0xff00;

    A = static_cast<uInt8>(sum);
  }
  else
  {
    Int32 lo = (A & 0x0f) + (operand & 0x0f) + (C ? 1 : 0);
    Int32 hi = (A & 0xf0) + (operand & 0xf0);
    notZ = (lo+hi) & 0xff;
    if(lo > 0x09)
    {
      hi += 0x10;
      lo += 0x06;
    }
    N = hi & 0x80;
    V = ~(A ^ operand) & (A ^ hi) & 0x80;
    if(hi > 0x90)
      hi += 0x60;
    C = hi & 0xff00;

    A = (lo & 0x0f) + (hi & 0xf0);
  }
}')

define(M6502_RTI, `{
  peek(0x0100 + SP++, DISASM_NONE);
  PS(peek(0x0100 + SP++, DISASM_DATA));
  PC = peek(0x0100 + SP++, DISASM_DATA);
  PC |= (static_cast<uInt16>(peek(0x0100 + SP, DISASM_DATA)) << 8);
}')

define(M6502_RTS, `{
  peek(0x0100 + SP++, DISASM_NONE);
  PC = peek(0x0100 + SP++, DISASM_DATA);
  PC |= (static_cast<uInt16>(peek(0x0100 + SP, DISASM_DATA)) << 8);
  peek(PC++, DISASM_NONE);
}')

define(M6502_SAX, `{
  poke(operandAddress, A & X, DISASM_WRITE);
}')

define(M6502_SBC, `{
  // N, V, Z, C flags are the same in either mode (C calculated at the end)
  const Int32 sum = A - operand - (C ? 0 : 1);
  N = sum & 0x80;
  V = (A ^ operand) & (A ^ sum) & 0x80;
  notZ = sum & 0xff;

  if(!D)
  {
    A = static_cast<uInt8>(sum);
  }
  else
  {
    Int32 lo = (A & 0x0f) - (operand & 0x0f) - (C ? 0 : 1);
    Int32 hi = (A & 0xf0) - (operand & 0xf0);
    if(lo & 0x10)
    {
      lo -= 6;
      hi--;
    }
    if(hi & 0x0100)
      hi -= 0x60;

    A = (lo & 0x0f) | (hi & 0xf0);
  }
  C = (sum & 0xff00) == 0;
}')

define(M6502_SBX, `{
  const uInt16 value = static_cast<uInt16>(X & A) - static_cast<uInt16>(operand);
  X = (value & 0xff);

  notZ = X;
  N = X & 0x80;
  C = !(value & 0x0100);
}')

define(M6502_SEC, `{
  C = true;
}')

define(M6502_SED, `{
  D = true;
}')

define(M6502_SEI, `{
  I = true;
}')

define(M6502_SHA, `{
  // NOTE: There are mixed reports on the actual operation
  // of this instruction!
  poke(operandAddress, A & X & (((operandAddress >> 8) & 0xff) + 1), DISASM_WRITE);
}')

define(M6502_SHS, `{
  // NOTE: There are mixed reports on the actual operation
  // of this instruction!
  SP = A & X;
  poke(operandAddress, A & X & (((operandAddress >> 8) & 0xff) + 1), DISASM_WRITE);
}')

define(M6502_SHX, `{
  // NOTE: There are mixed reports on the actual operation
  // of this instruction!
  poke(operandAddress, X & (((operandAddress >> 8) & 0xff) + 1), DISASM_WRITE);
}')

define(M6502_SHY, `{
  // NOTE: There are mixed reports on the actual operation
  // of this instruction!
  poke(operandAddress, Y & (((operandAddress >> 8) & 0xff) + 1), DISASM_WRITE);
}')

define(M6502_SLO, `{
  // Set carry flag according to the left-most bit in value
  C = operand & 0x80;

  operand <<= 1;
  poke(operandAddress, operand, DISASM_WRITE);

  A |= operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_SRE, `{
  // Set carry flag according to the right-most bit in value
  C = operand & 0x01;

  operand = (operand >> 1) & 0x7f;
  poke(operandAddress, operand, DISASM_WRITE);

  A ^= operand;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_STA, `{
  poke(operandAddress, A, DISASM_WRITE);
}')

define(M6502_STX, `{
  poke(operandAddress, X, DISASM_WRITE);
}')

define(M6502_STY, `{
  poke(operandAddress, Y, DISASM_WRITE);
}')

define(M6502_TAX, `{
  X = A;
  notZ = X;
  N = X & 0x80;
}')

define(M6502_TAY, `{
  Y = A;
  notZ = Y;
  N = Y & 0x80;
}')

define(M6502_TSX, `{
  X = SP;
  notZ = X;
  N = X & 0x80;
}')

define(M6502_TXA, `{
  A = X;
  notZ = A;
  N = A & 0x80;
}')

define(M6502_TXS, `{
  SP = X;
}')

define(M6502_TYA, `{
  A = Y;
  notZ = A;
  N = A & 0x80;
}')

//////////////////////////////////////////////////
// ADC
case 0x69:
M6502_IMMEDIATE_READ
M6502_ADC
break;

case 0x65:
M6502_ZERO_READ
M6502_ADC
break;

case 0x75:
M6502_ZEROX_READ
M6502_ADC
break;

case 0x6d:
M6502_ABSOLUTE_READ
M6502_ADC
break;

case 0x7d:
M6502_ABSOLUTEX_READ
M6502_ADC
break;

case 0x79:
M6502_ABSOLUTEY_READ
M6502_ADC
break;

case 0x61:
M6502_INDIRECTX_READ
M6502_ADC
break;

case 0x71:
M6502_INDIRECTY_READ
M6502_ADC
break;

//////////////////////////////////////////////////
// ASR
case 0x4b:
M6502_IMMEDIATE_READ
M6502_ASR
break;

//////////////////////////////////////////////////
// ANC
case 0x0b:
case 0x2b:
M6502_IMMEDIATE_READ
M6502_ANC
break;

//////////////////////////////////////////////////
// AND
case 0x29:
M6502_IMMEDIATE_READ
M6502_AND
break;

case 0x25:
M6502_ZERO_READ
M6502_AND
break;

case 0x35:
M6502_ZEROX_READ
M6502_AND
break;

case 0x2d:
M6502_ABSOLUTE_READ
M6502_AND
break;

case 0x3d:
M6502_ABSOLUTEX_READ
M6502_AND
break;

case 0x39:
M6502_ABSOLUTEY_READ
M6502_AND
break;

case 0x21:
M6502_INDIRECTX_READ
M6502_AND
break;

case 0x31:
M6502_INDIRECTY_READ
M6502_AND
break;

//////////////////////////////////////////////////
// ANE
case 0x8b:
M6502_IMMEDIATE_READ
M6502_ANE
break;

//////////////////////////////////////////////////
// ARR
case 0x6b:
M6502_IMMEDIATE_READ
M6502_ARR
break;

//////////////////////////////////////////////////
// ASL
case 0x0a:
M6502_IMPLIED
M6502_ASLA
break;

case 0x06:
M6502_ZERO_READMODIFYWRITE
M6502_ASL
break;

case 0x16:
M6502_ZEROX_READMODIFYWRITE
M6502_ASL
break;

case 0x0e:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_ASL
break;

case 0x1e:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_ASL
break;

//////////////////////////////////////////////////
// BIT
case 0x24:
M6502_ZERO_READ
M6502_BIT
break;

case 0x2C:
M6502_ABSOLUTE_READ
M6502_BIT
break;

//////////////////////////////////////////////////
// Branches
case 0x90:
M6502_IMMEDIATE_READ
M6502_BCC
break;


case 0xb0:
M6502_IMMEDIATE_READ
M6502_BCS
break;


case 0xf0:
M6502_IMMEDIATE_READ
M6502_BEQ
break;


case 0x30:
M6502_IMMEDIATE_READ
M6502_BMI
break;


case 0xD0:
M6502_IMMEDIATE_READ
M6502_BNE
break;


case 0x10:
M6502_IMMEDIATE_READ
M6502_BPL
break;


case 0x50:
M6502_IMMEDIATE_READ
M6502_BVC
break;


case 0x70:
M6502_IMMEDIATE_READ
M6502_BVS
break;

//////////////////////////////////////////////////
// BRK
case 0x00:
M6502_BRK
break;

//////////////////////////////////////////////////
// CLC
case 0x18:
M6502_IMPLIED
M6502_CLC
break;

//////////////////////////////////////////////////
// CLD
case 0xd8:
M6502_IMPLIED
M6502_CLD
break;

//////////////////////////////////////////////////
// CLI
case 0x58:
M6502_IMPLIED
M6502_CLI
break;

//////////////////////////////////////////////////
// CLV
case 0xb8:
M6502_IMPLIED
M6502_CLV
break;

//////////////////////////////////////////////////
// CMP
case 0xc9:
M6502_IMMEDIATE_READ
M6502_CMP
break;

case 0xc5:
M6502_ZERO_READ
M6502_CMP
break;

case 0xd5:
M6502_ZEROX_READ
M6502_CMP
break;

case 0xcd:
M6502_ABSOLUTE_READ
M6502_CMP
break;

case 0xdd:
M6502_ABSOLUTEX_READ
M6502_CMP
break;

case 0xd9:
M6502_ABSOLUTEY_READ
M6502_CMP
break;

case 0xc1:
M6502_INDIRECTX_READ
M6502_CMP
break;

case 0xd1:
M6502_INDIRECTY_READ
M6502_CMP
break;

//////////////////////////////////////////////////
// CPX
case 0xe0:
M6502_IMMEDIATE_READ
M6502_CPX
break;

case 0xe4:
M6502_ZERO_READ
M6502_CPX
break;

case 0xec:
M6502_ABSOLUTE_READ
M6502_CPX
break;

//////////////////////////////////////////////////
// CPY
case 0xc0:
M6502_IMMEDIATE_READ
M6502_CPY
break;

case 0xc4:
M6502_ZERO_READ
M6502_CPY
break;

case 0xcc:
M6502_ABSOLUTE_READ
M6502_CPY
break;

//////////////////////////////////////////////////
// DCP
case 0xcf:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_DCP
break;

case 0xdf:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_DCP
break;

case 0xdb:
M6502_ABSOLUTEY_READMODIFYWRITE
M6502_DCP
break;

case 0xc7:
M6502_ZERO_READMODIFYWRITE
M6502_DCP
break;

case 0xd7:
M6502_ZEROX_READMODIFYWRITE
M6502_DCP
break;

case 0xc3:
M6502_INDIRECTX_READMODIFYWRITE
M6502_DCP
break;

case 0xd3:
M6502_INDIRECTY_READMODIFYWRITE
M6502_DCP
break;

//////////////////////////////////////////////////
// DEC
case 0xc6:
M6502_ZERO_READMODIFYWRITE
M6502_DEC
break;

case 0xd6:
M6502_ZEROX_READMODIFYWRITE
M6502_DEC
break;

case 0xce:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_DEC
break;

case 0xde:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_DEC
break;

//////////////////////////////////////////////////
// DEX
case 0xca:
M6502_IMPLIED
M6502_DEX
break;

//////////////////////////////////////////////////
// DEY
case 0x88:
M6502_IMPLIED
M6502_DEY
break;

//////////////////////////////////////////////////
// EOR
case 0x49:
M6502_IMMEDIATE_READ
M6502_EOR
break;

case 0x45:
M6502_ZERO_READ
M6502_EOR
break;

case 0x55:
M6502_ZEROX_READ
M6502_EOR
break;

case 0x4d:
M6502_ABSOLUTE_READ
M6502_EOR
break;

case 0x5d:
M6502_ABSOLUTEX_READ
M6502_EOR
break;

case 0x59:
M6502_ABSOLUTEY_READ
M6502_EOR
break;

case 0x41:
M6502_INDIRECTX_READ
M6502_EOR
break;

case 0x51:
M6502_INDIRECTY_READ
M6502_EOR
break;

//////////////////////////////////////////////////
// INC
case 0xe6:
M6502_ZERO_READMODIFYWRITE
M6502_INC
break;

case 0xf6:
M6502_ZEROX_READMODIFYWRITE
M6502_INC
break;

case 0xee:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_INC
break;

case 0xfe:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_INC
break;

//////////////////////////////////////////////////
// INX
case 0xe8:
M6502_IMPLIED
M6502_INX
break;

//////////////////////////////////////////////////
// INY
case 0xc8:
M6502_IMPLIED
M6502_INY
break;

//////////////////////////////////////////////////
// ISB
case 0xef:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_ISB
break;

case 0xff:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_ISB
break;

case 0xfb:
M6502_ABSOLUTEY_READMODIFYWRITE
M6502_ISB
break;

case 0xe7:
M6502_ZERO_READMODIFYWRITE
M6502_ISB
break;

case 0xf7:
M6502_ZEROX_READMODIFYWRITE
M6502_ISB
break;

case 0xe3:
M6502_INDIRECTX_READMODIFYWRITE
M6502_ISB
break;

case 0xf3:
M6502_INDIRECTY_READMODIFYWRITE
M6502_ISB
break;

//////////////////////////////////////////////////
// JMP
case 0x4c:
M6502_ABSOLUTE_WRITE
M6502_JMP
break;

case 0x6c:
M6502_INDIRECT
M6502_JMP
break;

//////////////////////////////////////////////////
// JSR
case 0x20:
M6502_JSR
break;

//////////////////////////////////////////////////
// LAS
case 0xbb:
M6502_ABSOLUTEY_READ
M6502_LAS
break;


//////////////////////////////////////////////////
// LAX
case 0xaf:
M6502_ABSOLUTE_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LAX
break;

case 0xbf:
M6502_ABSOLUTEY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LAX
break;

case 0xa7:
M6502_ZERO_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LAX
break;

case 0xb7:
M6502_ZEROY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)  // TODO - check this
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LAX
break;

case 0xa3:
M6502_INDIRECTX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)  // TODO - check this
M6502_LAX
break;

case 0xb3:
M6502_INDIRECTY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)  // TODO - check this
M6502_LAX
break;
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// LDA
case 0xa9:
M6502_IMMEDIATE_READ
CLEAR_LAST_PEEK(myLastSrcAddressA)
M6502_LDA
break;

case 0xa5:
M6502_ZERO_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;

case 0xb5:
M6502_ZEROX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;

case 0xad:
M6502_ABSOLUTE_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;

case 0xbd:
M6502_ABSOLUTEX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;

case 0xb9:
M6502_ABSOLUTEY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;

case 0xa1:
M6502_INDIRECTX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;

case 0xb1:
M6502_INDIRECTY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_LDA
break;
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// LDX
case 0xa2:
M6502_IMMEDIATE_READ
CLEAR_LAST_PEEK(myLastSrcAddressX)
M6502_LDX
break;

case 0xa6:
M6502_ZERO_READ
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LDX
break;

case 0xb6:
M6502_ZEROY_READ
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LDX
break;

case 0xae:
M6502_ABSOLUTE_READ
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LDX
break;

case 0xbe:
M6502_ABSOLUTEY_READ
SET_LAST_PEEK(myLastSrcAddressX, intermediateAddress)
M6502_LDX
break;
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// LDY
case 0xa0:
M6502_IMMEDIATE_READ
CLEAR_LAST_PEEK(myLastSrcAddressY)
M6502_LDY
break;

case 0xa4:
M6502_ZERO_READ
SET_LAST_PEEK(myLastSrcAddressY, intermediateAddress)
M6502_LDY
break;

case 0xb4:
M6502_ZEROX_READ
SET_LAST_PEEK(myLastSrcAddressY, intermediateAddress)
M6502_LDY
break;

case 0xac:
M6502_ABSOLUTE_READ
SET_LAST_PEEK(myLastSrcAddressY, intermediateAddress)
M6502_LDY
break;

case 0xbc:
M6502_ABSOLUTEX_READ
SET_LAST_PEEK(myLastSrcAddressY, intermediateAddress)
M6502_LDY
break;
//////////////////////////////////////////////////

//////////////////////////////////////////////////
// LSR
case 0x4a:
M6502_IMPLIED
M6502_LSRA
break;


case 0x46:
M6502_ZERO_READMODIFYWRITE
M6502_LSR
break;

case 0x56:
M6502_ZEROX_READMODIFYWRITE
M6502_LSR
break;

case 0x4e:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_LSR
break;

case 0x5e:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_LSR
break;

//////////////////////////////////////////////////
// LXA
case 0xab:
M6502_IMMEDIATE_READ
M6502_LXA
break;

//////////////////////////////////////////////////
// NOP
case 0x1a:
case 0x3a:
case 0x5a:
case 0x7a:
case 0xda:
case 0xea:
case 0xfa:
M6502_IMPLIED
M6502_NOP
break;

case 0x80:
case 0x82:
case 0x89:
case 0xc2:
case 0xe2:
M6502_IMMEDIATE_READ_DISCARD_OPERAND
M6502_NOP
break;

case 0x04:
case 0x44:
case 0x64:
M6502_ZERO_READ_DISCARD_OPERAND
M6502_NOP
break;

case 0x14:
case 0x34:
case 0x54:
case 0x74:
case 0xd4:
case 0xf4:
M6502_ZEROX_READ_DISCARD_OPERAND
M6502_NOP
break;

case 0x0c:
M6502_ABSOLUTE_READ_DISCARD_OPERAND
M6502_NOP
break;

case 0x1c:
case 0x3c:
case 0x5c:
case 0x7c:
case 0xdc:
case 0xfc:
M6502_ABSOLUTEX_READ_DISCARD_OPERAND
M6502_NOP
break;


//////////////////////////////////////////////////
// ORA
case 0x09:
M6502_IMMEDIATE_READ
CLEAR_LAST_PEEK(myLastSrcAddressA)
M6502_ORA
break;

case 0x05:
M6502_ZERO_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;

case 0x15:
M6502_ZEROX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;

case 0x0d:
M6502_ABSOLUTE_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;

case 0x1d:
M6502_ABSOLUTEX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;

case 0x19:
M6502_ABSOLUTEY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;

case 0x01:
M6502_INDIRECTX_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;

case 0x11:
M6502_INDIRECTY_READ
SET_LAST_PEEK(myLastSrcAddressA, intermediateAddress)
M6502_ORA
break;
//////////////////////////////////////////////////

//////////////////////////////////////////////////
// PHA
case 0x48:
M6502_IMPLIED
SET_LAST_POKE(myLastSrcAddressA)
M6502_PHA
break;

//////////////////////////////////////////////////
// PHP
case 0x08:
M6502_IMPLIED
// TODO - add tracking for this opcode
M6502_PHP
break;

//////////////////////////////////////////////////
// PLA
case 0x68:
M6502_IMPLIED
// TODO - add tracking for this opcode
M6502_PLA
break;

//////////////////////////////////////////////////
// PLP
case 0x28:
M6502_IMPLIED
// TODO - add tracking for this opcode
M6502_PLP
break;

//////////////////////////////////////////////////
// RLA
case 0x2f:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_RLA
break;

case 0x3f:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_RLA
break;

case 0x3b:
M6502_ABSOLUTEY_READMODIFYWRITE
M6502_RLA
break;

case 0x27:
M6502_ZERO_READMODIFYWRITE
M6502_RLA
break;

case 0x37:
M6502_ZEROX_READMODIFYWRITE
M6502_RLA
break;

case 0x23:
M6502_INDIRECTX_READMODIFYWRITE
M6502_RLA
break;

case 0x33:
M6502_INDIRECTY_READMODIFYWRITE
M6502_RLA
break;

//////////////////////////////////////////////////
// ROL
case 0x2a:
M6502_IMPLIED
M6502_ROLA
break;

case 0x26:
M6502_ZERO_READMODIFYWRITE
M6502_ROL
break;

case 0x36:
M6502_ZEROX_READMODIFYWRITE
M6502_ROL
break;

case 0x2e:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_ROL
break;

case 0x3e:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_ROL
break;

//////////////////////////////////////////////////
// ROR
case 0x6a:
M6502_IMPLIED
M6502_RORA
break;

case 0x66:
M6502_ZERO_READMODIFYWRITE
M6502_ROR
break;

case 0x76:
M6502_ZEROX_READMODIFYWRITE
M6502_ROR
break;

case 0x6e:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_ROR
break;

case 0x7e:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_ROR
break;

//////////////////////////////////////////////////
// RRA
case 0x6f:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_RRA
break;

case 0x7f:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_RRA
break;

case 0x7b:
M6502_ABSOLUTEY_READMODIFYWRITE
M6502_RRA
break;

case 0x67:
M6502_ZERO_READMODIFYWRITE
M6502_RRA
break;

case 0x77:
M6502_ZEROX_READMODIFYWRITE
M6502_RRA
break;

case 0x63:
M6502_INDIRECTX_READMODIFYWRITE
M6502_RRA
break;

case 0x73:
M6502_INDIRECTY_READMODIFYWRITE
M6502_RRA
break;

//////////////////////////////////////////////////
// RTI
case 0x40:
M6502_IMPLIED
M6502_RTI
break;

//////////////////////////////////////////////////
// RTS
case 0x60:
M6502_IMPLIED
M6502_RTS
break;

//////////////////////////////////////////////////
// SAX
case 0x8f:
M6502_ABSOLUTE_WRITE
M6502_SAX
break;

case 0x87:
M6502_ZERO_WRITE
M6502_SAX
break;

case 0x97:
M6502_ZEROY_WRITE
M6502_SAX
break;

case 0x83:
M6502_INDIRECTX_WRITE
M6502_SAX
break;

//////////////////////////////////////////////////
// SBC
case 0xe9:
case 0xeb:
M6502_IMMEDIATE_READ
M6502_SBC
break;

case 0xe5:
M6502_ZERO_READ
M6502_SBC
break;

case 0xf5:
M6502_ZEROX_READ
M6502_SBC
break;

case 0xed:
M6502_ABSOLUTE_READ
M6502_SBC
break;

case 0xfd:
M6502_ABSOLUTEX_READ
M6502_SBC
break;

case 0xf9:
M6502_ABSOLUTEY_READ
M6502_SBC
break;

case 0xe1:
M6502_INDIRECTX_READ
M6502_SBC
break;

case 0xf1:
M6502_INDIRECTY_READ
M6502_SBC
break;

//////////////////////////////////////////////////
// SBX
case 0xcb:
M6502_IMMEDIATE_READ
M6502_SBX
break;

//////////////////////////////////////////////////
// SEC
case 0x38:
M6502_IMPLIED
M6502_SEC
break;

//////////////////////////////////////////////////
// SED
case 0xf8:
M6502_IMPLIED
M6502_SED
break;

//////////////////////////////////////////////////
// SEI
case 0x78:
M6502_IMPLIED
M6502_SEI
break;

//////////////////////////////////////////////////
// SHA
case 0x9f:
M6502_ABSOLUTEY_WRITE
M6502_SHA
break;

case 0x93:
M6502_INDIRECTY_WRITE
M6502_SHA
break;

//////////////////////////////////////////////////
// SHS
case 0x9b:
M6502_ABSOLUTEY_WRITE
M6502_SHS
break;

//////////////////////////////////////////////////
// SHX
case 0x9e:
M6502_ABSOLUTEY_WRITE
M6502_SHX
break;

//////////////////////////////////////////////////
// SHY
case 0x9c:
M6502_ABSOLUTEX_WRITE
M6502_SHY
break;

//////////////////////////////////////////////////
// SLO
case 0x0f:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_SLO
break;

case 0x1f:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_SLO
break;

case 0x1b:
M6502_ABSOLUTEY_READMODIFYWRITE
M6502_SLO
break;

case 0x07:
M6502_ZERO_READMODIFYWRITE
M6502_SLO
break;

case 0x17:
M6502_ZEROX_READMODIFYWRITE
M6502_SLO
break;

case 0x03:
M6502_INDIRECTX_READMODIFYWRITE
M6502_SLO
break;

case 0x13:
M6502_INDIRECTY_READMODIFYWRITE
M6502_SLO
break;

//////////////////////////////////////////////////
// SRE
case 0x4f:
M6502_ABSOLUTE_READMODIFYWRITE
M6502_SRE
break;

case 0x5f:
M6502_ABSOLUTEX_READMODIFYWRITE
M6502_SRE
break;

case 0x5b:
M6502_ABSOLUTEY_READMODIFYWRITE
M6502_SRE
break;

case 0x47:
M6502_ZERO_READMODIFYWRITE
M6502_SRE
break;

case 0x57:
M6502_ZEROX_READMODIFYWRITE
M6502_SRE
break;

case 0x43:
M6502_INDIRECTX_READMODIFYWRITE
M6502_SRE
break;

case 0x53:
M6502_INDIRECTY_READMODIFYWRITE
M6502_SRE
break;


//////////////////////////////////////////////////
// STA
case 0x85:
M6502_ZERO_WRITE
SET_LAST_POKE(myLastSrcAddressA)
M6502_STA
break;

case 0x95:
M6502_ZEROX_WRITE
M6502_STA
break;

case 0x8d:
M6502_ABSOLUTE_WRITE
SET_LAST_POKE(myLastSrcAddressA)
M6502_STA
break;

case 0x9d:
M6502_ABSOLUTEX_WRITE
M6502_STA
break;

case 0x99:
M6502_ABSOLUTEY_WRITE
M6502_STA
break;

case 0x81:
M6502_INDIRECTX_WRITE
M6502_STA
break;

case 0x91:
M6502_INDIRECTY_WRITE
M6502_STA
break;
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// STX
case 0x86:
M6502_ZERO_WRITE
SET_LAST_POKE(myLastSrcAddressX)
M6502_STX
break;

case 0x96:
M6502_ZEROY_WRITE
M6502_STX
break;

case 0x8e:
M6502_ABSOLUTE_WRITE
SET_LAST_POKE(myLastSrcAddressX)
M6502_STX
break;
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// STY
case 0x84:
M6502_ZERO_WRITE
SET_LAST_POKE(myLastSrcAddressY)
M6502_STY
break;

case 0x94:
M6502_ZEROX_WRITE
M6502_STY
break;

case 0x8c:
M6502_ABSOLUTE_WRITE
SET_LAST_POKE(myLastSrcAddressY)
M6502_STY
break;
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// Remaining MOVE opcodes
case 0xaa:
M6502_IMPLIED
SET_LAST_PEEK(myLastSrcAddressX, myLastSrcAddressA)
M6502_TAX
break;


case 0xa8:
M6502_IMPLIED
SET_LAST_PEEK(myLastSrcAddressY, myLastSrcAddressA)
M6502_TAY
break;


case 0xba:
M6502_IMPLIED
SET_LAST_PEEK(myLastSrcAddressX, myLastSrcAddressS)
M6502_TSX
break;


case 0x8a:
M6502_IMPLIED
SET_LAST_PEEK(myLastSrcAddressA, myLastSrcAddressX)
M6502_TXA
break;


case 0x9a:
M6502_IMPLIED
SET_LAST_PEEK(myLastSrcAddressS, myLastSrcAddressX)
M6502_TXS
break;


case 0x98:
M6502_IMPLIED
SET_LAST_PEEK(myLastSrcAddressA, myLastSrcAddressY)
M6502_TYA
break;
//////////////////////////////////////////////////
