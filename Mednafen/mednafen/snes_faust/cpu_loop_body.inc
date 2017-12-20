CPULBMX :

while(MDFN_LIKELY(CPUM.running_mask))
{
 if(CPUM.halted)
 {
  if(CPUM.halted == CPU_Misc::HALTED_DMA)
   CPUM.RunDMA();
  else
  {
   lc.SampleIRQ();

   if(CPUM.halted == CPU_Misc::HALTED_WAI && CPUM.CombinedNIState)
    CPUM.halted = CPU_Misc::HALTED_NOT;
   else if(CPUM.timestamp < CPUM.next_event_ts)
    CPUM.timestamp = CPUM.next_event_ts;
  }
 }

 while(MDFN_LIKELY(CPUM.timestamp < CPUM.next_event_ts))
 {
  uint8 opcode;

  if(MDFN_UNLIKELY(lc.PIN_Delay))
  {
   lc.OpRead(lc.PCPBR);
   lc.IO();

   if(MDFN_UNLIKELY(lc.PIN_Delay & 1))
   {
    lc.ISequence(Core65816::ISEQ_NMI);
    CPUM.CombinedNIState &= ~0x01;
   }
   else
    lc.ISequence(Core65816::ISEQ_IRQ);
  }
  lc.SampleIRQ();

//popread = false;
  opcode = lc.OpRead(lc.PCPBR);
//popread = true;
//  printf("Instr: %02x:%04x, %02x --- C=0x%04x, X=0x%04x, Y=0x%04x -- S=0x%04x, D=0x%04x --- P=0x%02x\n", lc.PBR, lc.PC, opcode, lc.C, lc.X, lc.Y, lc.S, lc.D, lc.P);
  lc.PC++;

  switch(opcode)
  {
   case 0x00: lc.RunInstruction<0x00, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x01: lc.RunInstruction<0x01, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x02: lc.RunInstruction<0x02, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x03: lc.RunInstruction<0x03, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x04: lc.RunInstruction<0x04, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x05: lc.RunInstruction<0x05, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x06: lc.RunInstruction<0x06, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x07: lc.RunInstruction<0x07, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x08: lc.RunInstruction<0x08, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x09: lc.RunInstruction<0x09, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x0A: lc.RunInstruction<0x0A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x0B: lc.RunInstruction<0x0B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x0C: lc.RunInstruction<0x0C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x0D: lc.RunInstruction<0x0D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x0E: lc.RunInstruction<0x0E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x0F: lc.RunInstruction<0x0F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x10: lc.RunInstruction<0x10, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x11: lc.RunInstruction<0x11, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x12: lc.RunInstruction<0x12, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x13: lc.RunInstruction<0x13, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x14: lc.RunInstruction<0x14, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x15: lc.RunInstruction<0x15, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x16: lc.RunInstruction<0x16, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x17: lc.RunInstruction<0x17, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x18: lc.RunInstruction<0x18, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x19: lc.RunInstruction<0x19, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x1A: lc.RunInstruction<0x1A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x1B: lc.RunInstruction<0x1B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x1C: lc.RunInstruction<0x1C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x1D: lc.RunInstruction<0x1D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x1E: lc.RunInstruction<0x1E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x1F: lc.RunInstruction<0x1F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x20: lc.RunInstruction<0x20, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x21: lc.RunInstruction<0x21, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x22: lc.RunInstruction<0x22, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x23: lc.RunInstruction<0x23, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x24: lc.RunInstruction<0x24, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x25: lc.RunInstruction<0x25, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x26: lc.RunInstruction<0x26, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x27: lc.RunInstruction<0x27, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x28: lc.RunInstruction<0x28, CPULBMTYPE, CPULBXTYPE>(); goto *LoopTable[(lc.P >> 4) & 0x3];
   case 0x29: lc.RunInstruction<0x29, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x2A: lc.RunInstruction<0x2A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x2B: lc.RunInstruction<0x2B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x2C: lc.RunInstruction<0x2C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x2D: lc.RunInstruction<0x2D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x2E: lc.RunInstruction<0x2E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x2F: lc.RunInstruction<0x2F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x30: lc.RunInstruction<0x30, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x31: lc.RunInstruction<0x31, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x32: lc.RunInstruction<0x32, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x33: lc.RunInstruction<0x33, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x34: lc.RunInstruction<0x34, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x35: lc.RunInstruction<0x35, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x36: lc.RunInstruction<0x36, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x37: lc.RunInstruction<0x37, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x38: lc.RunInstruction<0x38, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x39: lc.RunInstruction<0x39, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x3A: lc.RunInstruction<0x3A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x3B: lc.RunInstruction<0x3B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x3C: lc.RunInstruction<0x3C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x3D: lc.RunInstruction<0x3D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x3E: lc.RunInstruction<0x3E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x3F: lc.RunInstruction<0x3F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x40: lc.RunInstruction<0x40, CPULBMTYPE, CPULBXTYPE>(); goto *LoopTable[(lc.P >> 4) & 0x3];
   case 0x41: lc.RunInstruction<0x41, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x42: lc.RunInstruction<0x42, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x43: lc.RunInstruction<0x43, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x44: lc.RunInstruction<0x44, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x45: lc.RunInstruction<0x45, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x46: lc.RunInstruction<0x46, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x47: lc.RunInstruction<0x47, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x48: lc.RunInstruction<0x48, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x49: lc.RunInstruction<0x49, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x4A: lc.RunInstruction<0x4A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x4B: lc.RunInstruction<0x4B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x4C: lc.RunInstruction<0x4C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x4D: lc.RunInstruction<0x4D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x4E: lc.RunInstruction<0x4E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x4F: lc.RunInstruction<0x4F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x50: lc.RunInstruction<0x50, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x51: lc.RunInstruction<0x51, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x52: lc.RunInstruction<0x52, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x53: lc.RunInstruction<0x53, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x54: lc.RunInstruction<0x54, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x55: lc.RunInstruction<0x55, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x56: lc.RunInstruction<0x56, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x57: lc.RunInstruction<0x57, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x58: lc.RunInstruction<0x58, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x59: lc.RunInstruction<0x59, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x5A: lc.RunInstruction<0x5A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x5B: lc.RunInstruction<0x5B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x5C: lc.RunInstruction<0x5C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x5D: lc.RunInstruction<0x5D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x5E: lc.RunInstruction<0x5E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x5F: lc.RunInstruction<0x5F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x60: lc.RunInstruction<0x60, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x61: lc.RunInstruction<0x61, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x62: lc.RunInstruction<0x62, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x63: lc.RunInstruction<0x63, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x64: lc.RunInstruction<0x64, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x65: lc.RunInstruction<0x65, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x66: lc.RunInstruction<0x66, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x67: lc.RunInstruction<0x67, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x68: lc.RunInstruction<0x68, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x69: lc.RunInstruction<0x69, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x6A: lc.RunInstruction<0x6A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x6B: lc.RunInstruction<0x6B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x6C: lc.RunInstruction<0x6C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x6D: lc.RunInstruction<0x6D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x6E: lc.RunInstruction<0x6E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x6F: lc.RunInstruction<0x6F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x70: lc.RunInstruction<0x70, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x71: lc.RunInstruction<0x71, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x72: lc.RunInstruction<0x72, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x73: lc.RunInstruction<0x73, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x74: lc.RunInstruction<0x74, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x75: lc.RunInstruction<0x75, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x76: lc.RunInstruction<0x76, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x77: lc.RunInstruction<0x77, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x78: lc.RunInstruction<0x78, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x79: lc.RunInstruction<0x79, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x7A: lc.RunInstruction<0x7A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x7B: lc.RunInstruction<0x7B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x7C: lc.RunInstruction<0x7C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x7D: lc.RunInstruction<0x7D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x7E: lc.RunInstruction<0x7E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x7F: lc.RunInstruction<0x7F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x80: lc.RunInstruction<0x80, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x81: lc.RunInstruction<0x81, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x82: lc.RunInstruction<0x82, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x83: lc.RunInstruction<0x83, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x84: lc.RunInstruction<0x84, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x85: lc.RunInstruction<0x85, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x86: lc.RunInstruction<0x86, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x87: lc.RunInstruction<0x87, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x88: lc.RunInstruction<0x88, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x89: lc.RunInstruction<0x89, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x8A: lc.RunInstruction<0x8A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x8B: lc.RunInstruction<0x8B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x8C: lc.RunInstruction<0x8C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x8D: lc.RunInstruction<0x8D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x8E: lc.RunInstruction<0x8E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x8F: lc.RunInstruction<0x8F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x90: lc.RunInstruction<0x90, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x91: lc.RunInstruction<0x91, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x92: lc.RunInstruction<0x92, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x93: lc.RunInstruction<0x93, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x94: lc.RunInstruction<0x94, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x95: lc.RunInstruction<0x95, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x96: lc.RunInstruction<0x96, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x97: lc.RunInstruction<0x97, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x98: lc.RunInstruction<0x98, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x99: lc.RunInstruction<0x99, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x9A: lc.RunInstruction<0x9A, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x9B: lc.RunInstruction<0x9B, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x9C: lc.RunInstruction<0x9C, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x9D: lc.RunInstruction<0x9D, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x9E: lc.RunInstruction<0x9E, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0x9F: lc.RunInstruction<0x9F, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA0: lc.RunInstruction<0xA0, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA1: lc.RunInstruction<0xA1, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA2: lc.RunInstruction<0xA2, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA3: lc.RunInstruction<0xA3, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA4: lc.RunInstruction<0xA4, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA5: lc.RunInstruction<0xA5, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA6: lc.RunInstruction<0xA6, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA7: lc.RunInstruction<0xA7, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA8: lc.RunInstruction<0xA8, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xA9: lc.RunInstruction<0xA9, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xAA: lc.RunInstruction<0xAA, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xAB: lc.RunInstruction<0xAB, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xAC: lc.RunInstruction<0xAC, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xAD: lc.RunInstruction<0xAD, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xAE: lc.RunInstruction<0xAE, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xAF: lc.RunInstruction<0xAF, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB0: lc.RunInstruction<0xB0, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB1: lc.RunInstruction<0xB1, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB2: lc.RunInstruction<0xB2, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB3: lc.RunInstruction<0xB3, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB4: lc.RunInstruction<0xB4, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB5: lc.RunInstruction<0xB5, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB6: lc.RunInstruction<0xB6, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB7: lc.RunInstruction<0xB7, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB8: lc.RunInstruction<0xB8, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xB9: lc.RunInstruction<0xB9, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xBA: lc.RunInstruction<0xBA, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xBB: lc.RunInstruction<0xBB, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xBC: lc.RunInstruction<0xBC, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xBD: lc.RunInstruction<0xBD, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xBE: lc.RunInstruction<0xBE, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xBF: lc.RunInstruction<0xBF, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC0: lc.RunInstruction<0xC0, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC1: lc.RunInstruction<0xC1, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC2: lc.RunInstruction<0xC2, CPULBMTYPE, CPULBXTYPE>(); goto *LoopTable[(lc.P >> 4) & 0x3];
   case 0xC3: lc.RunInstruction<0xC3, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC4: lc.RunInstruction<0xC4, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC5: lc.RunInstruction<0xC5, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC6: lc.RunInstruction<0xC6, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC7: lc.RunInstruction<0xC7, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC8: lc.RunInstruction<0xC8, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xC9: lc.RunInstruction<0xC9, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xCA: lc.RunInstruction<0xCA, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xCB: lc.RunInstruction<0xCB, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xCC: lc.RunInstruction<0xCC, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xCD: lc.RunInstruction<0xCD, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xCE: lc.RunInstruction<0xCE, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xCF: lc.RunInstruction<0xCF, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD0: lc.RunInstruction<0xD0, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD1: lc.RunInstruction<0xD1, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD2: lc.RunInstruction<0xD2, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD3: lc.RunInstruction<0xD3, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD4: lc.RunInstruction<0xD4, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD5: lc.RunInstruction<0xD5, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD6: lc.RunInstruction<0xD6, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD7: lc.RunInstruction<0xD7, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD8: lc.RunInstruction<0xD8, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xD9: lc.RunInstruction<0xD9, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xDA: lc.RunInstruction<0xDA, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xDB: lc.RunInstruction<0xDB, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xDC: lc.RunInstruction<0xDC, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xDD: lc.RunInstruction<0xDD, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xDE: lc.RunInstruction<0xDE, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xDF: lc.RunInstruction<0xDF, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE0: lc.RunInstruction<0xE0, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE1: lc.RunInstruction<0xE1, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE2: lc.RunInstruction<0xE2, CPULBMTYPE, CPULBXTYPE>(); goto *LoopTable[(lc.P >> 4) & 0x3];
   case 0xE3: lc.RunInstruction<0xE3, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE4: lc.RunInstruction<0xE4, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE5: lc.RunInstruction<0xE5, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE6: lc.RunInstruction<0xE6, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE7: lc.RunInstruction<0xE7, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE8: lc.RunInstruction<0xE8, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xE9: lc.RunInstruction<0xE9, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xEA: lc.RunInstruction<0xEA, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xEB: lc.RunInstruction<0xEB, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xEC: lc.RunInstruction<0xEC, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xED: lc.RunInstruction<0xED, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xEE: lc.RunInstruction<0xEE, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xEF: lc.RunInstruction<0xEF, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF0: lc.RunInstruction<0xF0, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF1: lc.RunInstruction<0xF1, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF2: lc.RunInstruction<0xF2, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF3: lc.RunInstruction<0xF3, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF4: lc.RunInstruction<0xF4, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF5: lc.RunInstruction<0xF5, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF6: lc.RunInstruction<0xF6, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF7: lc.RunInstruction<0xF7, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF8: lc.RunInstruction<0xF8, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xF9: lc.RunInstruction<0xF9, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xFA: lc.RunInstruction<0xFA, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xFB: lc.RunInstruction<0xFB, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xFC: lc.RunInstruction<0xFC, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xFD: lc.RunInstruction<0xFD, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xFE: lc.RunInstruction<0xFE, CPULBMTYPE, CPULBXTYPE>(); continue;
   case 0xFF: lc.RunInstruction<0xFF, CPULBMTYPE, CPULBXTYPE>(); continue;
  }
 }

 CPUM.EventHandler();
}

goto ExitCat;
