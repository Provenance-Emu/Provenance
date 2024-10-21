/* Mednafen - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

case 0x00:  /* BRK */
            CPU_PC++;
            PUSH(CPU_PC>>8);
            PUSH(CPU_PC);
            PUSH(CPU_P|U_FLAG|B_FLAG);
	    CPU_P|=I_FLAG;
	    CPU_PI|=I_FLAG;
            CPU_PC=RdMem(0xFFFE);
            CPU_PC|=RdMem(0xFFFF)<<8;
	    ADDBT(CPU_PC);
            break;

case 0x40:  /* RTI */
            CPU_P=POP();
	    /* CPU_PI=CPU_P; This is probably incorrect, so it's commented out. */
	    CPU_PI = CPU_P;
            CPU_PC=POP();
            CPU_PC|=POP()<<8;
            ADDBT(CPU_PC);
            break;
            
case 0x60:  /* RTS */
            CPU_PC=POP();
            CPU_PC|=POP()<<8;
            CPU_PC++;
            ADDBT(CPU_PC);
            break;

case 0x48: /* PHA */
           PUSH(CPU_A);
           break;
case 0x08: /* PHP */
           PUSH(CPU_P|U_FLAG|B_FLAG);
           break;
case 0x68: /* PLA */
           CPU_A=POP();
           X_ZN(CPU_A);
           break;
case 0x28: /* PLP */
           CPU_P=POP();
           break;
case 0x4C:
	  {
	   uint16 ptmp=CPU_PC;
	   unsigned int npc;

	   npc=RdMem(ptmp);
	   ptmp++;
	   npc|=RdMem(ptmp)<<8;
	   CPU_PC=npc;
           ADDBT(CPU_PC);
	  }
	  break; /* JMP ABSOLUTE */
case 0x6C: 
	   {
	    uint32 tmp;
	    GetAB(tmp);
	    CPU_PC=RdMem(tmp);
	    CPU_PC|=RdMem( ((tmp+1)&0x00FF) | (tmp&0xFF00))<<8;
            ADDBT(CPU_PC);
	   }
	   break;
case 0x20: /* JSR */
	   {
	    uint8 npc;
	    npc=RdMem(CPU_PC);
	    CPU_PC++;
            PUSH(CPU_PC>>8);
            PUSH(CPU_PC);
            CPU_PC=RdMem(CPU_PC)<<8;
	    CPU_PC|=npc;
            ADDBT(CPU_PC);
	   }
           break;

case 0xAA: /* TAX */
           CPU_X=CPU_A;
           X_ZN(CPU_A);
           break;

case 0x8A: /* TXA */
           CPU_A=CPU_X;
           X_ZN(CPU_A);
           break;

case 0xA8: /* TAY */
           CPU_Y=CPU_A;
           X_ZN(CPU_A);
           break;
case 0x98: /* TYA */
           CPU_A=CPU_Y;
           X_ZN(CPU_A);
           break;

case 0xBA: /* TSX */
           CPU_X=CPU_S;
           X_ZN(CPU_X);
           break;
case 0x9A: /* TXS */
           CPU_S=CPU_X;
           break;

case 0xCA: /* DEX */
           CPU_X--;
           X_ZN(CPU_X);
           break;
case 0x88: /* DEY */
           CPU_Y--;
           X_ZN(CPU_Y);
           break;

case 0xE8: /* INX */
           CPU_X++;
           X_ZN(CPU_X);
           break;
case 0xC8: /* INY */
           CPU_Y++;
           X_ZN(CPU_Y);
           break;

case 0x18: /* CLC */
           CPU_P&=~C_FLAG;
           break;
case 0xD8: /* CLD */
           CPU_P&=~D_FLAG;
           break;
case 0x58: /* CLI */
           CPU_P&=~I_FLAG;
           break;
case 0xB8: /* CLV */
           CPU_P&=~V_FLAG;
           break;

case 0x38: /* SEC */
           CPU_P|=C_FLAG;
           break;
case 0xF8: /* SED */
           CPU_P|=D_FLAG;
           break;
case 0x78: /* SEI */
           CPU_P|=I_FLAG;
           break;

case 0xEA: /* NOP */
           break;

case 0x0A: RMW_A(ASL);
case 0x06: RMW_ZP(ASL);
case 0x16: RMW_ZPX(ASL);
case 0x0E: RMW_AB(ASL);
case 0x1E: RMW_ABX(ASL);

case 0xC6: RMW_ZP(DEC);
case 0xD6: RMW_ZPX(DEC);
case 0xCE: RMW_AB(DEC);
case 0xDE: RMW_ABX(DEC);

case 0xE6: RMW_ZP(INC);
case 0xF6: RMW_ZPX(INC);
case 0xEE: RMW_AB(INC);
case 0xFE: RMW_ABX(INC);

case 0x4A: RMW_A(LSR);
case 0x46: RMW_ZP(LSR);
case 0x56: RMW_ZPX(LSR);
case 0x4E: RMW_AB(LSR);
case 0x5E: RMW_ABX(LSR);

case 0x2A: RMW_A(ROL);
case 0x26: RMW_ZP(ROL);
case 0x36: RMW_ZPX(ROL);
case 0x2E: RMW_AB(ROL);
case 0x3E: RMW_ABX(ROL);

case 0x6A: RMW_A(ROR);
case 0x66: RMW_ZP(ROR);
case 0x76: RMW_ZPX(ROR);
case 0x6E: RMW_AB(ROR);
case 0x7E: RMW_ABX(ROR);

case 0x69: LD_IM(ADC);
case 0x65: LD_ZP(ADC);
case 0x75: LD_ZPX(ADC);
case 0x6D: LD_AB(ADC);
case 0x7D: LD_ABX(ADC);
case 0x79: LD_ABY(ADC);
case 0x61: LD_IX(ADC);
case 0x71: LD_IY(ADC);

case 0x29: LD_IM(AND);
case 0x25: LD_ZP(AND);
case 0x35: LD_ZPX(AND);
case 0x2D: LD_AB(AND);
case 0x3D: LD_ABX(AND);
case 0x39: LD_ABY(AND);
case 0x21: LD_IX(AND);
case 0x31: LD_IY(AND);

case 0x24: LD_ZP(BIT);
case 0x2C: LD_AB(BIT);

case 0xC9: LD_IM(CMP);
case 0xC5: LD_ZP(CMP);
case 0xD5: LD_ZPX(CMP);
case 0xCD: LD_AB(CMP);
case 0xDD: LD_ABX(CMP);
case 0xD9: LD_ABY(CMP);
case 0xC1: LD_IX(CMP);
case 0xD1: LD_IY(CMP);

case 0xE0: LD_IM(CPX);
case 0xE4: LD_ZP(CPX);
case 0xEC: LD_AB(CPX);

case 0xC0: LD_IM(CPY);
case 0xC4: LD_ZP(CPY);
case 0xCC: LD_AB(CPY);

case 0x49: LD_IM(EOR);
case 0x45: LD_ZP(EOR);
case 0x55: LD_ZPX(EOR);
case 0x4D: LD_AB(EOR);
case 0x5D: LD_ABX(EOR);
case 0x59: LD_ABY(EOR);
case 0x41: LD_IX(EOR);
case 0x51: LD_IY(EOR);

case 0xA9: LD_IM(LDA);
case 0xA5: LD_ZP(LDA);
case 0xB5: LD_ZPX(LDA);
case 0xAD: LD_AB(LDA);
case 0xBD: LD_ABX(LDA);
case 0xB9: LD_ABY(LDA);
case 0xA1: LD_IX(LDA);
case 0xB1: LD_IY(LDA);

case 0xA2: LD_IM(LDX);
case 0xA6: LD_ZP(LDX);
case 0xB6: LD_ZPY(LDX);
case 0xAE: LD_AB(LDX);
case 0xBE: LD_ABY(LDX);

case 0xA0: LD_IM(LDY);
case 0xA4: LD_ZP(LDY);
case 0xB4: LD_ZPX(LDY);
case 0xAC: LD_AB(LDY);
case 0xBC: LD_ABX(LDY);

case 0x09: LD_IM(ORA);
case 0x05: LD_ZP(ORA);
case 0x15: LD_ZPX(ORA);
case 0x0D: LD_AB(ORA);
case 0x1D: LD_ABX(ORA);
case 0x19: LD_ABY(ORA);
case 0x01: LD_IX(ORA);
case 0x11: LD_IY(ORA);

case 0xEB:	/* (undocumented) */
case 0xE9: LD_IM(SBC);
case 0xE5: LD_ZP(SBC);
case 0xF5: LD_ZPX(SBC);
case 0xED: LD_AB(SBC);
case 0xFD: LD_ABX(SBC);
case 0xF9: LD_ABY(SBC);
case 0xE1: LD_IX(SBC);
case 0xF1: LD_IY(SBC);

case 0x85: ST_ZP(CPU_A);
case 0x95: ST_ZPX(CPU_A);
case 0x8D: ST_AB(CPU_A);
case 0x9D: ST_ABX(CPU_A);
case 0x99: ST_ABY(CPU_A);
case 0x81: ST_IX(CPU_A);
case 0x91: ST_IY(CPU_A);

case 0x86: ST_ZP(CPU_X);
case 0x96: ST_ZPY(CPU_X);
case 0x8E: ST_AB(CPU_X);

case 0x84: ST_ZP(CPU_Y);
case 0x94: ST_ZPX(CPU_Y);
case 0x8C: ST_AB(CPU_Y);

/* BCC */
case 0x90: JR(!(CPU_P&C_FLAG)); break;

/* BCS */
case 0xB0: JR(CPU_P&C_FLAG); break;

/* BEQ */
case 0xF0: JR(CPU_P&Z_FLAG); break;

/* BNE */
case 0xD0: JR(!(CPU_P&Z_FLAG)); break;

/* BMI */
case 0x30: JR(CPU_P&N_FLAG); break;

/* BPL */
case 0x10: JR(!(CPU_P&N_FLAG)); break;

/* BVC */
case 0x50: JR(!(CPU_P&V_FLAG)); break;

/* BVS */
case 0x70: JR(CPU_P&V_FLAG); break;

//default: printf("Bad %02x at $%04x\n",b1,X.PC);break;
//ifdef moo
/* Here comes the undocumented instructions block.  Note that this implementation
   may be "wrong".  If so, please tell me.
*/

/* AAC */
case 0x2B:
case 0x0B: LD_IM(AND;CPU_P&=~C_FLAG;CPU_P|=CPU_A>>7);

/* AAX */
case 0x87: ST_ZP(CPU_A&CPU_X);
case 0x97: ST_ZPY(CPU_A&CPU_X);
case 0x8F: ST_AB(CPU_A&CPU_X);
case 0x83: ST_IX(CPU_A&CPU_X);

/* ARR - ARGH, MATEY! */
case 0x6B: { 
	     uint8 arrtmp; 
	     LD_IM(AND;CPU_P&=~V_FLAG;CPU_P|=(CPU_A^(CPU_A>>1))&0x40;arrtmp=CPU_A>>7;CPU_A>>=1;CPU_A|=(CPU_P&C_FLAG)<<7;CPU_P&=~C_FLAG;CPU_P|=arrtmp;X_ZN(CPU_A));
	   }
/* ASR */
case 0x4B: LD_IM(AND;LSRA);

/* ATX(OAL) Is this(OR with $EE) correct? */
case 0xAB: LD_IM(CPU_A|=0xEE;AND;CPU_X=CPU_A);

/* AXS */ 
case 0xCB: LD_IM(AXS);

/* DCP */
case 0xC7: RMW_ZP(DEC;CMP);
case 0xD7: RMW_ZPX(DEC;CMP);
case 0xCF: RMW_AB(DEC;CMP);
case 0xDF: RMW_ABX(DEC;CMP);
case 0xDB: RMW_ABY(DEC;CMP);
case 0xC3: RMW_IX(DEC;CMP);
case 0xD3: RMW_IY(DEC;CMP);

/* ISB */
case 0xE7: RMW_ZP(INC;SBC);
case 0xF7: RMW_ZPX(INC;SBC);
case 0xEF: RMW_AB(INC;SBC);
case 0xFF: RMW_ABX(INC;SBC);
case 0xFB: RMW_ABY(INC;SBC);
case 0xE3: RMW_IX(INC;SBC);
case 0xF3: RMW_IY(INC;SBC);

/* DOP */

case 0x04: CPU_PC++;break;
case 0x14: CPU_PC++;break;
case 0x34: CPU_PC++;break;
case 0x44: CPU_PC++;break;
case 0x54: CPU_PC++;break;
case 0x64: CPU_PC++;break;
case 0x74: CPU_PC++;break;

case 0x80: CPU_PC++;break;
case 0x82: CPU_PC++;break;
case 0x89: CPU_PC++;break;
case 0xC2: CPU_PC++;break;
case 0xD4: CPU_PC++;break;
case 0xE2: CPU_PC++;break;
case 0xF4: CPU_PC++;break;

/* KIL */

case 0x02:
case 0x12:
case 0x22:
case 0x32:
case 0x42:
case 0x52:
case 0x62:
case 0x72:
case 0x92:
case 0xB2:
case 0xD2:
case 0xF2:ADDCYC(0xFF);
          CPU_jammed=1;
	  CPU_PC--;
	  break;

/* LAR */
case 0xBB: RMW_ABY(CPU_S&=x;CPU_A=CPU_X=CPU_S;X_ZN(CPU_X));

/* LAX */
case 0xA7: LD_ZP(LDA;LDX);
case 0xB7: LD_ZPY(LDA;LDX);
case 0xAF: LD_AB(LDA;LDX);
case 0xBF: LD_ABY(LDA;LDX);
case 0xA3: LD_IX(LDA;LDX);
case 0xB3: LD_IY(LDA;LDX);

/* NOP */
case 0x1A:
case 0x3A:
case 0x5A:
case 0x7A:
case 0xDA:
case 0xFA: break;

/* RLA */
case 0x27: RMW_ZP(ROL;AND);
case 0x37: RMW_ZPX(ROL;AND);
case 0x2F: RMW_AB(ROL;AND);
case 0x3F: RMW_ABX(ROL;AND);
case 0x3B: RMW_ABY(ROL;AND);
case 0x23: RMW_IX(ROL;AND);
case 0x33: RMW_IY(ROL;AND);

/* RRA */
case 0x67: RMW_ZP(ROR;ADC);
case 0x77: RMW_ZPX(ROR;ADC);
case 0x6F: RMW_AB(ROR;ADC);
case 0x7F: RMW_ABX(ROR;ADC);
case 0x7B: RMW_ABY(ROR;ADC);
case 0x63: RMW_IX(ROR;ADC);
case 0x73: RMW_IY(ROR;ADC);

/* SLO */
case 0x07: RMW_ZP(ASL;ORA);
case 0x17: RMW_ZPX(ASL;ORA);
case 0x0F: RMW_AB(ASL;ORA);
case 0x1F: RMW_ABX(ASL;ORA);
case 0x1B: RMW_ABY(ASL;ORA);
case 0x03: RMW_IX(ASL;ORA);
case 0x13: RMW_IY(ASL;ORA);

/* SRE */
case 0x47: RMW_ZP(LSR;EOR);
case 0x57: RMW_ZPX(LSR;EOR);
case 0x4F: RMW_AB(LSR;EOR);
case 0x5F: RMW_ABX(LSR;EOR);
case 0x5B: RMW_ABY(LSR;EOR);
case 0x43: RMW_IX(LSR;EOR);
case 0x53: RMW_IY(LSR;EOR);

/* AXA - SHA */
case 0x93: ST_IY(CPU_A&CPU_X&(((A-CPU_Y)>>8)+1));
case 0x9F: ST_ABY(CPU_A&CPU_X&(((A-CPU_Y)>>8)+1));

/* SYA */
case 0x9C: ST_ABX(CPU_Y&(((A-CPU_X)>>8)+1));

/* SXA */
case 0x9E: ST_ABY(CPU_X&(((A-CPU_Y)>>8)+1));

/* XAS */
case 0x9B: CPU_S=CPU_A&CPU_X;ST_ABY(CPU_S& (((A-CPU_Y)>>8)+1) );

/* TOP */
case 0x0C: LD_AB(ARNOP);
case 0x1C: 
case 0x3C: 
case 0x5C: 
case 0x7C: 
case 0xDC: 
case 0xFC: LD_ABX(ARNOP);

/* XAA - BIG QUESTION MARK HERE */
case 0x8B: CPU_A|=0xEE; CPU_A&=CPU_X; LD_IM(AND);
//endif
