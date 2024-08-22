 if(MDFN_UNLIKELY(IFN))
 {
  OpRead(PC, true);
  CMX();

  ISequence(true);
  return;
 }

 v = OpRead(PC);
 //printf("%04x %02x\n", PC, v);
 PC++;
 CMX();

 /*
   printf(" ");
   for(unsigned i = 0; i < 256; i++)
   {
    printf(" case 0x%02X: goto Op_0x%02X;", i, i);

    if((i & 0x3) == 0x3)
     printf("\n ");
   }
 */

 if(cmos)
 {
  switch(v)
  {
   case 0x00: goto Op_0x00;      case 0x01: goto Op_0x01;      case 0x02: goto Op_CMOS_0x02; case 0x03: goto Op_CMOS_0x03;
   case 0x04: goto Op_CMOS_0x04; case 0x05: goto Op_0x05;      case 0x06: goto Op_0x06;      case 0x07: goto Op_CMOS_0x07;
   case 0x08: goto Op_0x08;      case 0x09: goto Op_0x09;      case 0x0A: goto Op_0x0A;      case 0x0B: goto Op_CMOS_0x0B;
   case 0x0C: goto Op_CMOS_0x0C; case 0x0D: goto Op_0x0D;      case 0x0E: goto Op_0x0E;      case 0x0F: goto Op_CMOS_0x0F;
   case 0x10: goto Op_0x10;      case 0x11: goto Op_0x11;      case 0x12: goto Op_CMOS_0x12; case 0x13: goto Op_CMOS_0x13;
   case 0x14: goto Op_CMOS_0x14; case 0x15: goto Op_0x15;      case 0x16: goto Op_0x16;      case 0x17: goto Op_CMOS_0x17;
   case 0x18: goto Op_0x18;      case 0x19: goto Op_0x19;      case 0x1A: goto Op_CMOS_0x1A; case 0x1B: goto Op_CMOS_0x1B;
   case 0x1C: goto Op_CMOS_0x1C; case 0x1D: goto Op_0x1D;      case 0x1E: goto Op_0x1E;      case 0x1F: goto Op_CMOS_0x1F;
   case 0x20: goto Op_0x20;      case 0x21: goto Op_0x21;      case 0x22: goto Op_CMOS_0x22; case 0x23: goto Op_CMOS_0x23;
   case 0x24: goto Op_0x24;      case 0x25: goto Op_0x25;      case 0x26: goto Op_0x26;      case 0x27: goto Op_CMOS_0x27;
   case 0x28: goto Op_0x28;      case 0x29: goto Op_0x29;      case 0x2A: goto Op_0x2A;      case 0x2B: goto Op_CMOS_0x2B;
   case 0x2C: goto Op_0x2C;      case 0x2D: goto Op_0x2D;      case 0x2E: goto Op_0x2E;      case 0x2F: goto Op_CMOS_0x2F;
   case 0x30: goto Op_0x30;      case 0x31: goto Op_0x31;      case 0x32: goto Op_CMOS_0x32; case 0x33: goto Op_CMOS_0x33;
   case 0x34: goto Op_CMOS_0x34; case 0x35: goto Op_0x35;      case 0x36: goto Op_0x36;      case 0x37: goto Op_CMOS_0x37;
   case 0x38: goto Op_0x38;      case 0x39: goto Op_0x39;      case 0x3A: goto Op_CMOS_0x3A; case 0x3B: goto Op_CMOS_0x3B;
   case 0x3C: goto Op_CMOS_0x3C; case 0x3D: goto Op_0x3D;      case 0x3E: goto Op_0x3E;      case 0x3F: goto Op_CMOS_0x3F;
   case 0x40: goto Op_0x40;      case 0x41: goto Op_0x41;      case 0x42: goto Op_CMOS_0x42; case 0x43: goto Op_CMOS_0x43;
   case 0x44: goto Op_CMOS_0x44; case 0x45: goto Op_0x45;      case 0x46: goto Op_0x46;      case 0x47: goto Op_CMOS_0x47;
   case 0x48: goto Op_0x48;      case 0x49: goto Op_0x49;      case 0x4A: goto Op_0x4A;      case 0x4B: goto Op_CMOS_0x4B;
   case 0x4C: goto Op_0x4C;      case 0x4D: goto Op_0x4D;      case 0x4E: goto Op_0x4E;      case 0x4F: goto Op_CMOS_0x4F;
   case 0x50: goto Op_0x50;      case 0x51: goto Op_0x51;      case 0x52: goto Op_CMOS_0x52; case 0x53: goto Op_CMOS_0x53;
   case 0x54: goto Op_CMOS_0x54; case 0x55: goto Op_0x55;      case 0x56: goto Op_0x56;      case 0x57: goto Op_CMOS_0x57;
   case 0x58: goto Op_0x58;      case 0x59: goto Op_0x59;      case 0x5A: goto Op_CMOS_0x5A; case 0x5B: goto Op_CMOS_0x5B;
   case 0x5C: goto Op_CMOS_0x5C; case 0x5D: goto Op_0x5D;      case 0x5E: goto Op_0x5E;      case 0x5F: goto Op_CMOS_0x5F;
   case 0x60: goto Op_0x60;      case 0x61: goto Op_0x61;      case 0x62: goto Op_CMOS_0x62; case 0x63: goto Op_CMOS_0x63;
   case 0x64: goto Op_CMOS_0x64; case 0x65: goto Op_0x65;      case 0x66: goto Op_0x66;      case 0x67: goto Op_CMOS_0x67;
   case 0x68: goto Op_0x68;      case 0x69: goto Op_0x69;      case 0x6A: goto Op_0x6A;      case 0x6B: goto Op_CMOS_0x6B;
   case 0x6C: goto Op_0x6C;      case 0x6D: goto Op_0x6D;      case 0x6E: goto Op_0x6E;      case 0x6F: goto Op_CMOS_0x6F;
   case 0x70: goto Op_0x70;      case 0x71: goto Op_0x71;      case 0x72: goto Op_CMOS_0x72; case 0x73: goto Op_CMOS_0x73;
   case 0x74: goto Op_CMOS_0x74; case 0x75: goto Op_0x75;      case 0x76: goto Op_0x76;      case 0x77: goto Op_CMOS_0x77;
   case 0x78: goto Op_0x78;      case 0x79: goto Op_0x79;      case 0x7A: goto Op_CMOS_0x7A; case 0x7B: goto Op_CMOS_0x7B;
   case 0x7C: goto Op_CMOS_0x7C; case 0x7D: goto Op_0x7D;      case 0x7E: goto Op_0x7E;      case 0x7F: goto Op_CMOS_0x7F;
   case 0x80: goto Op_CMOS_0x80; case 0x81: goto Op_0x81;      case 0x82: goto Op_CMOS_0x82; case 0x83: goto Op_CMOS_0x83;
   case 0x84: goto Op_0x84;      case 0x85: goto Op_0x85;      case 0x86: goto Op_0x86;      case 0x87: goto Op_CMOS_0x87;
   case 0x88: goto Op_0x88;      case 0x89: goto Op_CMOS_0x89; case 0x8A: goto Op_0x8A;      case 0x8B: goto Op_CMOS_0x8B;
   case 0x8C: goto Op_0x8C;      case 0x8D: goto Op_0x8D;      case 0x8E: goto Op_0x8E;      case 0x8F: goto Op_CMOS_0x8F;
   case 0x90: goto Op_0x90;      case 0x91: goto Op_0x91;      case 0x92: goto Op_CMOS_0x92; case 0x93: goto Op_CMOS_0x93;
   case 0x94: goto Op_0x94;      case 0x95: goto Op_0x95;      case 0x96: goto Op_0x96;      case 0x97: goto Op_CMOS_0x97;
   case 0x98: goto Op_0x98;      case 0x99: goto Op_0x99;      case 0x9A: goto Op_0x9A;      case 0x9B: goto Op_CMOS_0x9B;
   case 0x9C: goto Op_CMOS_0x9C; case 0x9D: goto Op_0x9D;      case 0x9E: goto Op_CMOS_0x9E; case 0x9F: goto Op_CMOS_0x9F;
   case 0xA0: goto Op_0xA0;      case 0xA1: goto Op_0xA1;      case 0xA2: goto Op_0xA2;      case 0xA3: goto Op_CMOS_0xA3;
   case 0xA4: goto Op_0xA4;      case 0xA5: goto Op_0xA5;      case 0xA6: goto Op_0xA6;      case 0xA7: goto Op_CMOS_0xA7;
   case 0xA8: goto Op_0xA8;      case 0xA9: goto Op_0xA9;      case 0xAA: goto Op_0xAA;      case 0xAB: goto Op_CMOS_0xAB;
   case 0xAC: goto Op_0xAC;      case 0xAD: goto Op_0xAD;      case 0xAE: goto Op_0xAE;      case 0xAF: goto Op_CMOS_0xAF;
   case 0xB0: goto Op_0xB0;      case 0xB1: goto Op_0xB1;      case 0xB2: goto Op_CMOS_0xB2; case 0xB3: goto Op_CMOS_0xB3;
   case 0xB4: goto Op_0xB4;      case 0xB5: goto Op_0xB5;      case 0xB6: goto Op_0xB6;      case 0xB7: goto Op_CMOS_0xB7;
   case 0xB8: goto Op_0xB8;      case 0xB9: goto Op_0xB9;      case 0xBA: goto Op_0xBA;      case 0xBB: goto Op_CMOS_0xBB;
   case 0xBC: goto Op_0xBC;      case 0xBD: goto Op_0xBD;      case 0xBE: goto Op_0xBE;      case 0xBF: goto Op_CMOS_0xBF;
   case 0xC0: goto Op_0xC0;      case 0xC1: goto Op_0xC1;      case 0xC2: goto Op_CMOS_0xC2; case 0xC3: goto Op_CMOS_0xC3;
   case 0xC4: goto Op_0xC4;      case 0xC5: goto Op_0xC5;      case 0xC6: goto Op_0xC6;      case 0xC7: goto Op_CMOS_0xC7;
   case 0xC8: goto Op_0xC8;      case 0xC9: goto Op_0xC9;      case 0xCA: goto Op_0xCA;      case 0xCB: goto Op_CMOS_0xCB;
   case 0xCC: goto Op_0xCC;      case 0xCD: goto Op_0xCD;      case 0xCE: goto Op_0xCE;      case 0xCF: goto Op_CMOS_0xCF;
   case 0xD0: goto Op_0xD0;      case 0xD1: goto Op_0xD1;      case 0xD2: goto Op_CMOS_0xD2; case 0xD3: goto Op_CMOS_0xD3;
   case 0xD4: goto Op_CMOS_0xD4; case 0xD5: goto Op_0xD5;      case 0xD6: goto Op_0xD6;      case 0xD7: goto Op_CMOS_0xD7;
   case 0xD8: goto Op_0xD8;      case 0xD9: goto Op_0xD9;      case 0xDA: goto Op_CMOS_0xDA; case 0xDB: goto Op_CMOS_0xDB;
   case 0xDC: goto Op_CMOS_0xDC; case 0xDD: goto Op_0xDD;      case 0xDE: goto Op_0xDE;      case 0xDF: goto Op_CMOS_0xDF;
   case 0xE0: goto Op_0xE0;      case 0xE1: goto Op_0xE1;      case 0xE2: goto Op_CMOS_0xE2; case 0xE3: goto Op_CMOS_0xE3;
   case 0xE4: goto Op_0xE4;      case 0xE5: goto Op_0xE5;      case 0xE6: goto Op_0xE6;      case 0xE7: goto Op_CMOS_0xE7;
   case 0xE8: goto Op_0xE8;      case 0xE9: goto Op_0xE9;      case 0xEA: goto Op_0xEA;      case 0xEB: goto Op_CMOS_0xEB;
   case 0xEC: goto Op_0xEC;      case 0xED: goto Op_0xED;      case 0xEE: goto Op_0xEE;      case 0xEF: goto Op_CMOS_0xEF;
   case 0xF0: goto Op_0xF0;      case 0xF1: goto Op_0xF1;      case 0xF2: goto Op_CMOS_0xF2; case 0xF3: goto Op_CMOS_0xF3;
   case 0xF4: goto Op_CMOS_0xF4; case 0xF5: goto Op_0xF5;      case 0xF6: goto Op_0xF6;      case 0xF7: goto Op_CMOS_0xF7;
   case 0xF8: goto Op_0xF8;      case 0xF9: goto Op_0xF9;      case 0xFA: goto Op_CMOS_0xFA; case 0xFB: goto Op_CMOS_0xFB;
   case 0xFC: goto Op_CMOS_0xFC; case 0xFD: goto Op_0xFD;      case 0xFE: goto Op_0xFE;      case 0xFF: goto Op_CMOS_0xFF;
  }
 }
 else
 {
  switch(v)
  {
   case 0x00: goto Op_0x00;      case 0x01: goto Op_0x01;      case 0x02: goto Op_NMOS_0x02; case 0x03: goto Op_NMOS_0x03;
   case 0x04: goto Op_NMOS_0x04; case 0x05: goto Op_0x05;      case 0x06: goto Op_0x06;      case 0x07: goto Op_NMOS_0x07;
   case 0x08: goto Op_0x08;      case 0x09: goto Op_0x09;      case 0x0A: goto Op_0x0A;      case 0x0B: goto Op_NMOS_0x0B;
   case 0x0C: goto Op_NMOS_0x0C; case 0x0D: goto Op_0x0D;      case 0x0E: goto Op_0x0E;      case 0x0F: goto Op_NMOS_0x0F;
   case 0x10: goto Op_0x10;      case 0x11: goto Op_0x11;      case 0x12: goto Op_NMOS_0x12; case 0x13: goto Op_NMOS_0x13;
   case 0x14: goto Op_NMOS_0x14; case 0x15: goto Op_0x15;      case 0x16: goto Op_0x16;      case 0x17: goto Op_NMOS_0x17;
   case 0x18: goto Op_0x18;      case 0x19: goto Op_0x19;      case 0x1A: goto Op_NMOS_0x1A; case 0x1B: goto Op_NMOS_0x1B;
   case 0x1C: goto Op_NMOS_0x1C; case 0x1D: goto Op_0x1D;      case 0x1E: goto Op_0x1E;      case 0x1F: goto Op_NMOS_0x1F;
   case 0x20: goto Op_0x20;      case 0x21: goto Op_0x21;      case 0x22: goto Op_NMOS_0x22; case 0x23: goto Op_NMOS_0x23;
   case 0x24: goto Op_0x24;      case 0x25: goto Op_0x25;      case 0x26: goto Op_0x26;      case 0x27: goto Op_NMOS_0x27;
   case 0x28: goto Op_0x28;      case 0x29: goto Op_0x29;      case 0x2A: goto Op_0x2A;      case 0x2B: goto Op_NMOS_0x2B;
   case 0x2C: goto Op_0x2C;      case 0x2D: goto Op_0x2D;      case 0x2E: goto Op_0x2E;      case 0x2F: goto Op_NMOS_0x2F;
   case 0x30: goto Op_0x30;      case 0x31: goto Op_0x31;      case 0x32: goto Op_NMOS_0x32; case 0x33: goto Op_NMOS_0x33;
   case 0x34: goto Op_NMOS_0x34; case 0x35: goto Op_0x35;      case 0x36: goto Op_0x36;      case 0x37: goto Op_NMOS_0x37;
   case 0x38: goto Op_0x38;      case 0x39: goto Op_0x39;      case 0x3A: goto Op_NMOS_0x3A; case 0x3B: goto Op_NMOS_0x3B;
   case 0x3C: goto Op_NMOS_0x3C; case 0x3D: goto Op_0x3D;      case 0x3E: goto Op_0x3E;      case 0x3F: goto Op_NMOS_0x3F;
   case 0x40: goto Op_0x40;      case 0x41: goto Op_0x41;      case 0x42: goto Op_NMOS_0x42; case 0x43: goto Op_NMOS_0x43;
   case 0x44: goto Op_NMOS_0x44; case 0x45: goto Op_0x45;      case 0x46: goto Op_0x46;      case 0x47: goto Op_NMOS_0x47;
   case 0x48: goto Op_0x48;      case 0x49: goto Op_0x49;      case 0x4A: goto Op_0x4A;      case 0x4B: goto Op_NMOS_0x4B;
   case 0x4C: goto Op_0x4C;      case 0x4D: goto Op_0x4D;      case 0x4E: goto Op_0x4E;      case 0x4F: goto Op_NMOS_0x4F;
   case 0x50: goto Op_0x50;      case 0x51: goto Op_0x51;      case 0x52: goto Op_NMOS_0x52; case 0x53: goto Op_NMOS_0x53;
   case 0x54: goto Op_NMOS_0x54; case 0x55: goto Op_0x55;      case 0x56: goto Op_0x56;      case 0x57: goto Op_NMOS_0x57;
   case 0x58: goto Op_0x58;      case 0x59: goto Op_0x59;      case 0x5A: goto Op_NMOS_0x5A; case 0x5B: goto Op_NMOS_0x5B;
   case 0x5C: goto Op_NMOS_0x5C; case 0x5D: goto Op_0x5D;      case 0x5E: goto Op_0x5E;      case 0x5F: goto Op_NMOS_0x5F;
   case 0x60: goto Op_0x60;      case 0x61: goto Op_0x61;      case 0x62: goto Op_NMOS_0x62; case 0x63: goto Op_NMOS_0x63;
   case 0x64: goto Op_NMOS_0x64; case 0x65: goto Op_0x65;      case 0x66: goto Op_0x66;      case 0x67: goto Op_NMOS_0x67;
   case 0x68: goto Op_0x68;      case 0x69: goto Op_0x69;      case 0x6A: goto Op_0x6A;      case 0x6B: goto Op_NMOS_0x6B;
   case 0x6C: goto Op_0x6C;      case 0x6D: goto Op_0x6D;      case 0x6E: goto Op_0x6E;      case 0x6F: goto Op_NMOS_0x6F;
   case 0x70: goto Op_0x70;      case 0x71: goto Op_0x71;      case 0x72: goto Op_NMOS_0x72; case 0x73: goto Op_NMOS_0x73;
   case 0x74: goto Op_NMOS_0x74; case 0x75: goto Op_0x75;      case 0x76: goto Op_0x76;      case 0x77: goto Op_NMOS_0x77;
   case 0x78: goto Op_0x78;      case 0x79: goto Op_0x79;      case 0x7A: goto Op_NMOS_0x7A; case 0x7B: goto Op_NMOS_0x7B;
   case 0x7C: goto Op_NMOS_0x7C; case 0x7D: goto Op_0x7D;      case 0x7E: goto Op_0x7E;      case 0x7F: goto Op_NMOS_0x7F;
   case 0x80: goto Op_NMOS_0x80; case 0x81: goto Op_0x81;      case 0x82: goto Op_NMOS_0x82; case 0x83: goto Op_NMOS_0x83;
   case 0x84: goto Op_0x84;      case 0x85: goto Op_0x85;      case 0x86: goto Op_0x86;      case 0x87: goto Op_NMOS_0x87;
   case 0x88: goto Op_0x88;      case 0x89: goto Op_NMOS_0x89; case 0x8A: goto Op_0x8A;      case 0x8B: goto Op_NMOS_0x8B;
   case 0x8C: goto Op_0x8C;      case 0x8D: goto Op_0x8D;      case 0x8E: goto Op_0x8E;      case 0x8F: goto Op_NMOS_0x8F;
   case 0x90: goto Op_0x90;      case 0x91: goto Op_0x91;      case 0x92: goto Op_NMOS_0x92; case 0x93: goto Op_NMOS_0x93;
   case 0x94: goto Op_0x94;      case 0x95: goto Op_0x95;      case 0x96: goto Op_0x96;      case 0x97: goto Op_NMOS_0x97;
   case 0x98: goto Op_0x98;      case 0x99: goto Op_0x99;      case 0x9A: goto Op_0x9A;      case 0x9B: goto Op_NMOS_0x9B;
   case 0x9C: goto Op_NMOS_0x9C; case 0x9D: goto Op_0x9D;      case 0x9E: goto Op_NMOS_0x9E; case 0x9F: goto Op_NMOS_0x9F;
   case 0xA0: goto Op_0xA0;      case 0xA1: goto Op_0xA1;      case 0xA2: goto Op_0xA2;      case 0xA3: goto Op_NMOS_0xA3;
   case 0xA4: goto Op_0xA4;      case 0xA5: goto Op_0xA5;      case 0xA6: goto Op_0xA6;      case 0xA7: goto Op_NMOS_0xA7;
   case 0xA8: goto Op_0xA8;      case 0xA9: goto Op_0xA9;      case 0xAA: goto Op_0xAA;      case 0xAB: goto Op_NMOS_0xAB;
   case 0xAC: goto Op_0xAC;      case 0xAD: goto Op_0xAD;      case 0xAE: goto Op_0xAE;      case 0xAF: goto Op_NMOS_0xAF;
   case 0xB0: goto Op_0xB0;      case 0xB1: goto Op_0xB1;      case 0xB2: goto Op_NMOS_0xB2; case 0xB3: goto Op_NMOS_0xB3;
   case 0xB4: goto Op_0xB4;      case 0xB5: goto Op_0xB5;      case 0xB6: goto Op_0xB6;      case 0xB7: goto Op_NMOS_0xB7;
   case 0xB8: goto Op_0xB8;      case 0xB9: goto Op_0xB9;      case 0xBA: goto Op_0xBA;      case 0xBB: goto Op_NMOS_0xBB;
   case 0xBC: goto Op_0xBC;      case 0xBD: goto Op_0xBD;      case 0xBE: goto Op_0xBE;      case 0xBF: goto Op_NMOS_0xBF;
   case 0xC0: goto Op_0xC0;      case 0xC1: goto Op_0xC1;      case 0xC2: goto Op_NMOS_0xC2; case 0xC3: goto Op_NMOS_0xC3;
   case 0xC4: goto Op_0xC4;      case 0xC5: goto Op_0xC5;      case 0xC6: goto Op_0xC6;      case 0xC7: goto Op_NMOS_0xC7;
   case 0xC8: goto Op_0xC8;      case 0xC9: goto Op_0xC9;      case 0xCA: goto Op_0xCA;      case 0xCB: goto Op_NMOS_0xCB;
   case 0xCC: goto Op_0xCC;      case 0xCD: goto Op_0xCD;      case 0xCE: goto Op_0xCE;      case 0xCF: goto Op_NMOS_0xCF;
   case 0xD0: goto Op_0xD0;      case 0xD1: goto Op_0xD1;      case 0xD2: goto Op_NMOS_0xD2; case 0xD3: goto Op_NMOS_0xD3;
   case 0xD4: goto Op_NMOS_0xD4; case 0xD5: goto Op_0xD5;      case 0xD6: goto Op_0xD6;      case 0xD7: goto Op_NMOS_0xD7;
   case 0xD8: goto Op_0xD8;      case 0xD9: goto Op_0xD9;      case 0xDA: goto Op_NMOS_0xDA; case 0xDB: goto Op_NMOS_0xDB;
   case 0xDC: goto Op_NMOS_0xDC; case 0xDD: goto Op_0xDD;      case 0xDE: goto Op_0xDE;      case 0xDF: goto Op_NMOS_0xDF;
   case 0xE0: goto Op_0xE0;      case 0xE1: goto Op_0xE1;      case 0xE2: goto Op_NMOS_0xE2; case 0xE3: goto Op_NMOS_0xE3;
   case 0xE4: goto Op_0xE4;      case 0xE5: goto Op_0xE5;      case 0xE6: goto Op_0xE6;      case 0xE7: goto Op_NMOS_0xE7;
   case 0xE8: goto Op_0xE8;      case 0xE9: goto Op_0xE9;      case 0xEA: goto Op_0xEA;      case 0xEB: goto Op_NMOS_0xEB;
   case 0xEC: goto Op_0xEC;      case 0xED: goto Op_0xED;      case 0xEE: goto Op_0xEE;      case 0xEF: goto Op_NMOS_0xEF;
   case 0xF0: goto Op_0xF0;      case 0xF1: goto Op_0xF1;      case 0xF2: goto Op_NMOS_0xF2; case 0xF3: goto Op_NMOS_0xF3;
   case 0xF4: goto Op_NMOS_0xF4; case 0xF5: goto Op_0xF5;      case 0xF6: goto Op_0xF6;      case 0xF7: goto Op_NMOS_0xF7;
   case 0xF8: goto Op_0xF8;      case 0xF9: goto Op_0xF9;      case 0xFA: goto Op_NMOS_0xFA; case 0xFB: goto Op_NMOS_0xFB;
   case 0xFC: goto Op_NMOS_0xFC; case 0xFD: goto Op_0xFD;      case 0xFE: goto Op_0xFE;      case 0xFF: goto Op_NMOS_0xFF;
  }
 }

 #define CASE(x) Op_ ## x
 #define NMOS_CASE(x) Op_NMOS_ ## x
 #define CMOS_CASE(x) Op_CMOS_ ## x

/*
 #define NMOS_CASE(x) case ((x) - (version == NMOS_6502) ? 0 : -1000)
 #define CMOS_CASE(x) case ((x) - (version == CMOS_6502) ? 0 : -2000)

 #define CMOS_WDC_CASE(x) case ((x) - (version == CMOS_6502_WDC) ? 0 : -3000)
 #define CMOS_WDCRW_CASE(x) case ((x) - (version == CMOS_6502_WDC || version == CMOS_6502_ROCKWELL) ? 0 : -4000)
*/
 //
 //
 {
  #define INSTR(memop, amode, subop) Instr_ ## memop ## _ ##amode(Op_ ## subop);

  //
  // Load
  //

  // ADC
  CASE(0x69): INSTR(LD, IMM,   ADC<cmos>); return;
  CASE(0x65): INSTR(LD, ZP,    ADC<cmos>); return;
  CASE(0x75): INSTR(LD, ZPX,   ADC<cmos>); return;
  CASE(0x6D): INSTR(LD, AB,    ADC<cmos>); return;
  CASE(0x7D): INSTR(LD, ABX,   ADC<cmos>); return;
  CASE(0x79): INSTR(LD, ABY,   ADC<cmos>); return;
  CASE(0x61): INSTR(LD, IDIRX, ADC<cmos>); return;
  CASE(0x71): INSTR(LD, IDIRY, ADC<cmos>); return;

  // AND
  CASE(0x29): INSTR(LD, IMM,   AND); return;
  CASE(0x25): INSTR(LD, ZP,    AND); return;
  CASE(0x35): INSTR(LD, ZPX,   AND); return;
  CASE(0x2D): INSTR(LD, AB,    AND); return;
  CASE(0x3D): INSTR(LD, ABX,   AND); return;
  CASE(0x39): INSTR(LD, ABY,   AND); return;
  CASE(0x21): INSTR(LD, IDIRX, AND); return;
  CASE(0x31): INSTR(LD, IDIRY, AND); return;

  // CMP
  CASE(0xC9): INSTR(LD, IMM,   CMP); return;
  CASE(0xC5): INSTR(LD, ZP,    CMP); return;
  CASE(0xD5): INSTR(LD, ZPX,   CMP); return;
  CASE(0xCD): INSTR(LD, AB,    CMP); return;
  CASE(0xDD): INSTR(LD, ABX,   CMP); return;
  CASE(0xD9): INSTR(LD, ABY,   CMP); return;
  CASE(0xC1): INSTR(LD, IDIRX, CMP); return;
  CASE(0xD1): INSTR(LD, IDIRY, CMP); return;

  // EOR
  CASE(0x49): INSTR(LD, IMM,   EOR); return;
  CASE(0x45): INSTR(LD, ZP,    EOR); return;
  CASE(0x55): INSTR(LD, ZPX,   EOR); return;
  CASE(0x4D): INSTR(LD, AB,    EOR); return;
  CASE(0x5D): INSTR(LD, ABX,   EOR); return;
  CASE(0x59): INSTR(LD, ABY,   EOR); return;
  CASE(0x41): INSTR(LD, IDIRX, EOR); return;
  CASE(0x51): INSTR(LD, IDIRY, EOR); return;

  // LDA
  CASE(0xA9): INSTR(LD, IMM,   LDA); return;
  CASE(0xA5): INSTR(LD, ZP,    LDA); return;
  CASE(0xB5): INSTR(LD, ZPX,   LDA); return;
  CASE(0xAD): INSTR(LD, AB,    LDA); return;
  CASE(0xBD): INSTR(LD, ABX,   LDA); return;
  CASE(0xB9): INSTR(LD, ABY,   LDA); return;
  CASE(0xA1): INSTR(LD, IDIRX, LDA); return;
  CASE(0xB1): INSTR(LD, IDIRY, LDA); return;

  // LDX
  CASE(0xA2): INSTR(LD, IMM,   LDX); return;
  CASE(0xA6): INSTR(LD, ZP,    LDX); return;
  CASE(0xB6): INSTR(LD, ZPY,   LDX); return;
  CASE(0xAE): INSTR(LD, AB,    LDX); return;
  CASE(0xBE): INSTR(LD, ABY,   LDX); return;

  // LDY
  CASE(0xA0): INSTR(LD, IMM,   LDY); return;
  CASE(0xA4): INSTR(LD, ZP,    LDY); return;
  CASE(0xB4): INSTR(LD, ZPX,   LDY); return;
  CASE(0xAC): INSTR(LD, AB,    LDY); return;
  CASE(0xBC): INSTR(LD, ABX,   LDY); return;

  // ORA
  CASE(0x09): INSTR(LD, IMM,   ORA); return;
  CASE(0x05): INSTR(LD, ZP,    ORA); return;
  CASE(0x15): INSTR(LD, ZPX,   ORA); return;
  CASE(0x0D): INSTR(LD, AB,    ORA); return;
  CASE(0x1D): INSTR(LD, ABX,   ORA); return;
  CASE(0x19): INSTR(LD, ABY,   ORA); return;
  CASE(0x01): INSTR(LD, IDIRX, ORA); return;
  CASE(0x11): INSTR(LD, IDIRY, ORA); return;

  // SBC
  NMOS_CASE(0xEB): //
  CASE(0xE9): INSTR(LD, IMM,   SBC<cmos>); return;
  CASE(0xE5): INSTR(LD, ZP,    SBC<cmos>); return;
  CASE(0xF5): INSTR(LD, ZPX,   SBC<cmos>); return;
  CASE(0xED): INSTR(LD, AB,    SBC<cmos>); return;
  CASE(0xFD): INSTR(LD, ABX,   SBC<cmos>); return;
  CASE(0xF9): INSTR(LD, ABY,   SBC<cmos>); return;
  CASE(0xE1): INSTR(LD, IDIRX, SBC<cmos>); return;
  CASE(0xF1): INSTR(LD, IDIRY, SBC<cmos>); return;

  // BIT
  CASE(0x24): INSTR(LD, ZP, BIT); return;
  CASE(0x2C): INSTR(LD, AB, BIT); return;

  // CPX
  CASE(0xE0): INSTR(LD, IMM, CPX); return;
  CASE(0xE4): INSTR(LD, ZP,  CPX); return;
  CASE(0xEC): INSTR(LD, AB,  CPX); return;

  // CPY
  CASE(0xC0): INSTR(LD, IMM, CPY); return;
  CASE(0xC4): INSTR(LD, ZP,  CPY); return;
  CASE(0xCC): INSTR(LD, AB,  CPY); return;


  //
  // Read-Modify-Write
  //

  // ASL
  CASE(0x0A): INSTR(RMW, A,   ASL); return;
  CASE(0x06): INSTR(RMW, ZP,  ASL); return;
  CASE(0x16): INSTR(RMW, ZPX, ASL); return;
  CASE(0x0E): INSTR(RMW, AB,  ASL); return;
  CASE(0x1E): INSTR(RMW, ABX, ASL); return;

  // DEC
  CASE(0xC6): INSTR(RMW, ZP,  DEC); return;
  CASE(0xD6): INSTR(RMW, ZPX, DEC); return;
  CASE(0xCE): INSTR(RMW, AB,  DEC); return;
  CASE(0xDE): INSTR(RMW, ABX_DIC, DEC); return;

  // INC
  CASE(0xE6): INSTR(RMW, ZP,  INC); return;
  CASE(0xF6): INSTR(RMW, ZPX, INC); return;
  CASE(0xEE): INSTR(RMW, AB,  INC); return;
  CASE(0xFE): INSTR(RMW, ABX_DIC, INC); return;

  // LSR
  CASE(0x4A): INSTR(RMW, A,   LSR); return;
  CASE(0x46): INSTR(RMW, ZP,  LSR); return;
  CASE(0x56): INSTR(RMW, ZPX, LSR); return;
  CASE(0x4E): INSTR(RMW, AB,  LSR); return;
  CASE(0x5E): INSTR(RMW, ABX, LSR); return;

  // ROL
  CASE(0x2A): INSTR(RMW, A,   ROL); return;
  CASE(0x26): INSTR(RMW, ZP,  ROL); return;
  CASE(0x36): INSTR(RMW, ZPX, ROL); return;
  CASE(0x2E): INSTR(RMW, AB,  ROL); return;
  CASE(0x3E): INSTR(RMW, ABX, ROL); return;

  // ROR
  CASE(0x6A): INSTR(RMW, A,   ROR); return;
  CASE(0x66): INSTR(RMW, ZP,  ROR); return;
  CASE(0x76): INSTR(RMW, ZPX, ROR); return;
  CASE(0x6E): INSTR(RMW, AB,  ROR); return;
  CASE(0x7E): INSTR(RMW, ABX, ROR); return;


  //
  // Store
  //

  // STA
  CASE(0x85): INSTR(ST, ZP,    STA); return;
  CASE(0x95): INSTR(ST, ZPX,   STA); return;
  CASE(0x8D): INSTR(ST, AB,    STA); return;
  CASE(0x9D): INSTR(ST, ABX,   STA); return;
  CASE(0x99): INSTR(ST, ABY,   STA); return;
  CASE(0x81): INSTR(ST, IDIRX, STA); return;
  CASE(0x91): INSTR(ST, IDIRY, STA); return;

  // STX
  CASE(0x86): INSTR(ST, ZP,    STX); return;
  CASE(0x96): INSTR(ST, ZPY,   STX); return;
  CASE(0x8E): INSTR(ST, AB,    STX); return;

  // STY
  CASE(0x84): INSTR(ST, ZP,    STY); return;
  CASE(0x94): INSTR(ST, ZPX,   STY); return;
  CASE(0x8C): INSTR(ST, AB,    STY); return;


  //
  // Branch
  //
  CASE(0x90): Instr_Bxx(!(P & FLAG_C)); return; // BCC
  CASE(0xB0): Instr_Bxx(P & FLAG_C); return; // BCS

  CASE(0xD0): Instr_Bxx(!(P & FLAG_Z)); return; // BNE
  CASE(0xF0): Instr_Bxx(P & FLAG_Z); return; // BEQ

  CASE(0x10): Instr_Bxx(!(P & FLAG_N)); return; // BPL
  CASE(0x30): Instr_Bxx(P & FLAG_N); return; // BMI

  CASE(0x50): Instr_Bxx(!(P & FLAG_V)); return; // BVC
  CASE(0x70): Instr_Bxx(P & FLAG_V); return; // BVS

  CASE(0x4C): Instr_JMP_ABS(); return;
  CASE(0x6C): Instr_JMP_IDIR(); return;

  CASE(0x20): Instr_JSR(); return;

  CASE(0x40): Instr_RTI(); return;
  CASE(0x60): Instr_RTS(); return;

  CASE(0x00): Instr_BRK(); return;

  //
  // Stack Manipulation
  //
  CASE(0x48): Instr_PHA(); return;
  CASE(0x08): Instr_PHP(); return;
  CASE(0x68): Instr_PLA(); return;
  CASE(0x28): Instr_PLP(); return;

#define INSTR_IMP(subop) Instr_IMP(Op_ ## subop);
  //
  // Implied
  //
  NMOS_CASE(0x1A): //
  NMOS_CASE(0x3A): //
  NMOS_CASE(0x5A): //
  NMOS_CASE(0x7A): //
  NMOS_CASE(0xDA): //
  NMOS_CASE(0xFA): //
  CASE(0xEA): INSTR_IMP(NOP); return;

  CASE(0xCA): INSTR_IMP(DEX); return;
  CASE(0x88): INSTR_IMP(DEY); return;
  CASE(0xE8): INSTR_IMP(INX); return;
  CASE(0xC8): INSTR_IMP(INY); return;

  CASE(0x18): INSTR_IMP(CLx<FLAG_C>); return; // CLC
  CASE(0xD8): INSTR_IMP(CLx<FLAG_D>); return; // CLD
  CASE(0x58): INSTR_IMP(CLx<FLAG_I>); return; // CLI
  CASE(0xB8): INSTR_IMP(CLx<FLAG_V>); return; // CLV

  CASE(0x38): INSTR_IMP(SEx<FLAG_C>); return; // SEC
  CASE(0xF8): INSTR_IMP(SEx<FLAG_D>); return; // SED
  CASE(0x78): INSTR_IMP(SEx<FLAG_I>); return; // SEI

  CASE(0xAA): INSTR_IMP(TAX); return;
  CASE(0xA8): INSTR_IMP(TAY); return;
  CASE(0x98): INSTR_IMP(TYA); return;
  CASE(0xBA): INSTR_IMP(TSX); return;
  CASE(0x8A): INSTR_IMP(TXA); return;
  CASE(0x9A): INSTR_IMP(TXS); return;

  //
  // Undocumented(TODO)
  //

  //
  // DCP
  //
  NMOS_CASE(0xC7): INSTR(RMW, ZP,    DCP); return;
  NMOS_CASE(0xD7): INSTR(RMW, ZPX,   DCP); return;
  NMOS_CASE(0xCF): INSTR(RMW, AB,    DCP); return;
  NMOS_CASE(0xDF): INSTR(RMW, ABX,   DCP); return;
  NMOS_CASE(0xDB): INSTR(RMW, ABY,   DCP); return;
  NMOS_CASE(0xC3): INSTR(RMW, IDIRX, DCP); return;
  NMOS_CASE(0xD3): INSTR(RMW, IDIRY, DCP); return;

  //
  // ISC
  //
  NMOS_CASE(0xE7): INSTR(RMW, ZP,    ISC); return;
  NMOS_CASE(0xF7): INSTR(RMW, ZPX,   ISC); return;
  NMOS_CASE(0xEF): INSTR(RMW, AB,    ISC); return;
  NMOS_CASE(0xFF): INSTR(RMW, ABX,   ISC); return;
  NMOS_CASE(0xFB): INSTR(RMW, ABY,   ISC); return;
  NMOS_CASE(0xE3): INSTR(RMW, IDIRX, ISC); return;
  NMOS_CASE(0xF3): INSTR(RMW, IDIRY, ISC); return;

  //
  // RLA
  //
  NMOS_CASE(0x27): INSTR(RMW, ZP,    RLA); return;
  NMOS_CASE(0x37): INSTR(RMW, ZPX,   RLA); return;
  NMOS_CASE(0x2F): INSTR(RMW, AB,    RLA); return;
  NMOS_CASE(0x3F): INSTR(RMW, ABX,   RLA); return;
  NMOS_CASE(0x3B): INSTR(RMW, ABY,   RLA); return;
  NMOS_CASE(0x23): INSTR(RMW, IDIRX, RLA); return;
  NMOS_CASE(0x33): INSTR(RMW, IDIRY, RLA); return;

  //
  // RRA
  //
  NMOS_CASE(0x67): INSTR(RMW, ZP,    RRA); return;
  NMOS_CASE(0x77): INSTR(RMW, ZPX,   RRA); return;
  NMOS_CASE(0x6F): INSTR(RMW, AB,    RRA); return;
  NMOS_CASE(0x7F): INSTR(RMW, ABX,   RRA); return;
  NMOS_CASE(0x7B): INSTR(RMW, ABY,   RRA); return;
  NMOS_CASE(0x63): INSTR(RMW, IDIRX, RRA); return;
  NMOS_CASE(0x73): INSTR(RMW, IDIRY, RRA); return;

  //
  // SLO / ASO
  //
  NMOS_CASE(0x07): INSTR(RMW, ZP,    SLO); return;
  NMOS_CASE(0x17): INSTR(RMW, ZPX,   SLO); return;
  NMOS_CASE(0x0F): INSTR(RMW, AB,    SLO); return;
  NMOS_CASE(0x1F): INSTR(RMW, ABX,   SLO); return;
  NMOS_CASE(0x1B): INSTR(RMW, ABY,   SLO); return;
  NMOS_CASE(0x03): INSTR(RMW, IDIRX, SLO); return;
  NMOS_CASE(0x13): INSTR(RMW, IDIRY, SLO); return;

  //
  // SRE
  //
  NMOS_CASE(0x47): INSTR(RMW, ZP,    SRE); return;
  NMOS_CASE(0x57): INSTR(RMW, ZPX,   SRE); return;
  NMOS_CASE(0x4F): INSTR(RMW, AB,    SRE); return;
  NMOS_CASE(0x5F): INSTR(RMW, ABX,   SRE); return;
  NMOS_CASE(0x5B): INSTR(RMW, ABY,   SRE); return;
  NMOS_CASE(0x43): INSTR(RMW, IDIRX, SRE); return;
  NMOS_CASE(0x53): INSTR(RMW, IDIRY, SRE); return;

  //
  // ARR
  //
  NMOS_CASE(0x6B): INSTR(LD, IMM, ARR); return;

  //
  // ASR
  //
  NMOS_CASE(0x4B): INSTR(LD, IMM, ASR); return;

  //
  // AAC
  //
  NMOS_CASE(0x0B):
  NMOS_CASE(0x2B): INSTR(LD, IMM, AAC); return;

  //
  // AXS
  //
  NMOS_CASE(0xCB): INSTR(LD, IMM, AXS); return;

  //
  // ATX ***
  //
  NMOS_CASE(0xAB): INSTR(LD, IMM, ATX); return;

  //
  // XAA ***
  //
  NMOS_CASE(0x8B): INSTR(LD, IMM, XAA); return;


  //
  // LAS ***?
  //
  NMOS_CASE(0xBB): INSTR(LD, ABY,   LAS); return;

  //
  // LAX ***?
  //
  NMOS_CASE(0xA7): INSTR(LD, ZP,    LAX); return;
  NMOS_CASE(0xB7): INSTR(LD, ZPY,   LAX); return;
  NMOS_CASE(0xAF): INSTR(LD, AB,    LAX); return;
  NMOS_CASE(0xBF): INSTR(LD, ABY,   LAX); return;
  NMOS_CASE(0xA3): INSTR(LD, IDIRX, LAX); return;
  NMOS_CASE(0xB3): INSTR(LD, IDIRY, LAX); return;

  //
  // DOP
  //
  NMOS_CASE(0x04): //
  NMOS_CASE(0x44): //
  NMOS_CASE(0x64): INSTR(LD, ZP, NOP); return;
  NMOS_CASE(0x14): //
  NMOS_CASE(0x34): //
  NMOS_CASE(0x54): //
  NMOS_CASE(0x74): //
  NMOS_CASE(0xD4): //
  NMOS_CASE(0xF4): INSTR(LD, ZPX, NOP); return;
  NMOS_CASE(0x80): //
  NMOS_CASE(0x82): //
  NMOS_CASE(0x89): //
  NMOS_CASE(0xC2): //
  NMOS_CASE(0xE2): INSTR(LD, IMM, NOP); return;

  //
  // TOP
  //
  NMOS_CASE(0x0C): INSTR(LD, AB,    NOP); return;
  NMOS_CASE(0x1C):
  NMOS_CASE(0x3C):
  NMOS_CASE(0x5C):
  NMOS_CASE(0x7C):
  NMOS_CASE(0xDC):
  NMOS_CASE(0xFC): INSTR(LD, ABX,   NOP); return;

  //
  // AAX
  //
  NMOS_CASE(0x87): INSTR(ST, ZP,    AAX); return;
  NMOS_CASE(0x97): INSTR(ST, ZPY,   AAX); return;
  NMOS_CASE(0x8F): INSTR(ST, AB,    AAX); return;
  NMOS_CASE(0x83): INSTR(ST, IDIRX, AAX); return;

  //
  // AXA ***
  //
  NMOS_CASE(0x9F): INSTR(ST_H_ILL, ABY,   AXA); return;
  NMOS_CASE(0x93): INSTR(ST_H_ILL, IDIRY, AXA); return;

  //
  // SXA ***
  //
  NMOS_CASE(0x9E): INSTR(ST_H_ILL, ABY,   SXA); return;

  //
  // SYA ***
  //
  NMOS_CASE(0x9C): INSTR(ST_H_ILL, ABX,   SYA); return;

  //
  // XAS ***
  //
  NMOS_CASE(0x9B): INSTR(ST_H_ILL, ABY,   XAS); return;

  //
  // KIL / JAM
  //
  NMOS_CASE(0x02):
  NMOS_CASE(0x12):
  NMOS_CASE(0x22):
  NMOS_CASE(0x32):
  NMOS_CASE(0x42):
  NMOS_CASE(0x52):
  NMOS_CASE(0x62):
  NMOS_CASE(0x72):
  NMOS_CASE(0x92):
  NMOS_CASE(0xB2):
  NMOS_CASE(0xD2):
  NMOS_CASE(0xF2): JamHandler(v); return;

  //
  //
  //
  //
  //
  //

  CMOS_CASE(0x72): INSTR(LD, IDIR, ADC<cmos>); return;
  CMOS_CASE(0x32): INSTR(LD, IDIR, AND); return;
  CMOS_CASE(0xD2): INSTR(LD, IDIR, CMP); return;
  CMOS_CASE(0x52): INSTR(LD, IDIR, EOR); return;
  CMOS_CASE(0xB2): INSTR(LD, IDIR, LDA); return;
  CMOS_CASE(0x12): INSTR(LD, IDIR, ORA); return;
  CMOS_CASE(0xF2): INSTR(LD, IDIR, SBC<cmos>); return;
  CMOS_CASE(0x92): INSTR(ST, IDIR, STA); return;

  CMOS_CASE(0x3C): INSTR(LD, ABX, BIT); return;
  CMOS_CASE(0x34): INSTR(LD, ZPX, BIT); return;
  CMOS_CASE(0x89): INSTR(LD, IMM, BIT_IMM); return;

  CMOS_CASE(0x3A): INSTR(RMW, A, DEC); return;
  CMOS_CASE(0x1A): INSTR(RMW, A, INC); return;

  CMOS_CASE(0x7C): Instr_JMP_IDIRX(); return;

  CMOS_CASE(0x80): Instr_Bxx(true); return; // BRA

  CMOS_CASE(0xDA): Instr_PHX(); return;
  CMOS_CASE(0xFA): Instr_PLX(); return;
  CMOS_CASE(0x5A): Instr_PHY(); return;
  CMOS_CASE(0x7A): Instr_PLY(); return;

  CMOS_CASE(0x64): INSTR(ST, ZP,    STZ); return;
  CMOS_CASE(0x74): INSTR(ST, ZPX,   STZ); return;
  CMOS_CASE(0x9C): INSTR(ST, AB,    STZ); return;
  CMOS_CASE(0x9E): INSTR(ST, ABX,   STZ); return;

  CMOS_CASE(0x1C): INSTR(RMW, AB, TRB); return;
  CMOS_CASE(0x14): INSTR(RMW, ZP, TRB); return;

  CMOS_CASE(0x0C): INSTR(RMW, AB, TSB); return;
  CMOS_CASE(0x04): INSTR(RMW, ZP, TSB); return;

  //
  // Pseudo-NOPs:
  //
  CMOS_CASE(0x03):
  CMOS_CASE(0x13):
  CMOS_CASE(0x23):
  CMOS_CASE(0x33):
  CMOS_CASE(0x43):
  CMOS_CASE(0x53):
  CMOS_CASE(0x63):
  CMOS_CASE(0x73):
  CMOS_CASE(0x83):
  CMOS_CASE(0x93):
  CMOS_CASE(0xA3):
  CMOS_CASE(0xB3):
  CMOS_CASE(0xC3):
  CMOS_CASE(0xD3):
  CMOS_CASE(0xE3):
  CMOS_CASE(0xF3):
  CMOS_CASE(0x0B):
  CMOS_CASE(0x1B):
  CMOS_CASE(0x2B):
  CMOS_CASE(0x3B):
  CMOS_CASE(0x4B):
  CMOS_CASE(0x5B):
  CMOS_CASE(0x6B):
  CMOS_CASE(0x7B):
  CMOS_CASE(0x8B):
  CMOS_CASE(0x9B):
  CMOS_CASE(0xAB):
  CMOS_CASE(0xBB):
  CMOS_CASE(0xCB):
  CMOS_CASE(0xDB):
  CMOS_CASE(0xEB):
  CMOS_CASE(0xFB):
  CMOS_CASE(0x07):
  CMOS_CASE(0x17):
  CMOS_CASE(0x27):
  CMOS_CASE(0x37):
  CMOS_CASE(0x47):
  CMOS_CASE(0x57):
  CMOS_CASE(0x67):
  CMOS_CASE(0x77):
  CMOS_CASE(0x87):
  CMOS_CASE(0x97):
  CMOS_CASE(0xA7):
  CMOS_CASE(0xB7):
  CMOS_CASE(0xC7):
  CMOS_CASE(0xD7):
  CMOS_CASE(0xE7):
  CMOS_CASE(0xF7):
  CMOS_CASE(0x0F):
  CMOS_CASE(0x1F):
  CMOS_CASE(0x2F):
  CMOS_CASE(0x3F):
  CMOS_CASE(0x4F):
  CMOS_CASE(0x5F):
  CMOS_CASE(0x6F):
  CMOS_CASE(0x7F):
  CMOS_CASE(0x8F):
  CMOS_CASE(0x9F):
  CMOS_CASE(0xAF):
  CMOS_CASE(0xBF):
  CMOS_CASE(0xCF):
  CMOS_CASE(0xDF):
  CMOS_CASE(0xEF):
  CMOS_CASE(0xFF): return; // 1-cycle, delay interrupts

  CMOS_CASE(0x02):
  CMOS_CASE(0x22):
  CMOS_CASE(0x42):
  CMOS_CASE(0x62):
  CMOS_CASE(0x82):
  CMOS_CASE(0xC2):
  CMOS_CASE(0xE2): INSTR(LD, IMM, NOP); return;

  CMOS_CASE(0x44): INSTR(LD, ZP, NOP); return;

  CMOS_CASE(0x54):
  CMOS_CASE(0xD4):
  CMOS_CASE(0xF4): INSTR(LD, ZPX, NOP); return;

  CMOS_CASE(0xDC):
  CMOS_CASE(0xFC): INSTR(LD, AB, NOP); return;

  CMOS_CASE(0x5C):
	GetEA_AB();

	ea |= 0xFF00;

	MemRead(ea);
	CMX();

	ea |= 0x00FF;

	MemRead(ea);
	CMX();
	MemRead(ea);
	CMX();
	MemRead(ea);
	CMX();

	UpdateIFN();
	MemRead(ea);
	return;

#if 0
  //
  // Rockwell/WDC:
  //

  CMOS_CASE(0x0F): Instr_BBR<0>(); return;
  CMOS_CASE(0x1F): Instr_BBR<1>(); return;
  CMOS_CASE(0x2F): Instr_BBR<2>(); return;
  CMOS_CASE(0x3F): Instr_BBR<3>(); return;
  CMOS_CASE(0x4F): Instr_BBR<4>(); return;
  CMOS_CASE(0x5F): Instr_BBR<5>(); return;
  CMOS_CASE(0x6F): Instr_BBR<6>(); return;
  CMOS_CASE(0x7F): Instr_BBR<7>(); return;

  CMOS_CASE(0x8F): Instr_BBS<0>(); return;
  CMOS_CASE(0x9F): Instr_BBS<1>(); return;
  CMOS_CASE(0xAF): Instr_BBS<2>(); return;
  CMOS_CASE(0xBF): Instr_BBS<3>(); return;
  CMOS_CASE(0xCF): Instr_BBS<4>(); return;
  CMOS_CASE(0xDF): Instr_BBS<5>(); return;
  CMOS_CASE(0xEF): Instr_BBS<6>(); return;
  CMOS_CASE(0xFF): Instr_BBS<7>(); return;

  // STP (WDC only?)
  CMOS_CASE(0xDB): return;

  // WAI (WDC only?)
  CMOS_CASE(0xCB): return;
#endif

  #undef INSTR_IMP
  #undef INSTR
 }

