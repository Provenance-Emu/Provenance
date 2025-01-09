/*--------------------------------------------------
   TGB Dual - Gameboy Emulator -
   Copyright (C) 2001  Hii

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

//--------------------------------------------
// プリフィックスなしZ80オペコード

#define REG_A regs.AF.b.h
#define REG_F regs.AF.b.l
#define REG_B regs.BC.b.h
#define REG_C regs.BC.b.l
#define REG_D regs.DE.b.h
#define REG_E regs.DE.b.l
#define REG_H regs.HL.b.h
#define REG_L regs.HL.b.l
#define REG_AF regs.AF.w
#define REG_BC regs.BC.w
#define REG_DE regs.DE.w
#define REG_HL regs.HL.w
#define REG_SP regs.SP
#define REG_PC regs.PC

#define ADD(arg) \
	tmp.w=REG_A+arg; \
	REG_F=tmp.b.h|ZTable[tmp.b.l]|((REG_A^arg^tmp.b.l)&H_FLAG); \
	REG_A=tmp.b.l
#define ADC(arg) \
	tmp.w=REG_A+arg+(REG_F&C_FLAG); \
	REG_F=tmp.b.h|ZTable[tmp.b.l]|((REG_A^arg^tmp.b.l)&H_FLAG); \
	REG_A=tmp.b.l
#define SUB(arg) \
	tmp.w=REG_A-arg; \
	REG_F=N_FLAG|-tmp.b.h|ZTable[tmp.b.l]|((REG_A^arg^tmp.b.l)&H_FLAG); \
	REG_A=tmp.b.l
#define SBC(arg) \
	tmp.w=REG_A-arg-(REG_F&C_FLAG); \
	REG_F=N_FLAG|-tmp.b.h|ZTable[tmp.b.l]|((REG_A^arg^tmp.b.l)&H_FLAG); \
	REG_A=tmp.b.l
#define CP(arg) \
	tmp.w=REG_A-arg; \
	REG_F=N_FLAG|-tmp.b.h|ZTable[tmp.b.l]|((REG_A^arg^tmp.b.l)&H_FLAG)
#define AND(arg) REG_A&=arg;REG_F=H_FLAG|ZTable[REG_A]
#define OR(arg)  REG_A|=arg;REG_F=ZTable[REG_A]
#define XOR(arg) REG_A^=arg;REG_F=ZTable[REG_A]
#define INC(arg) arg++;REG_F=(REG_F&C_FLAG)|ZTable[arg]|((arg&0x0F)?0:H_FLAG)
#define DEC(arg) arg--;REG_F=N_FLAG|(REG_F&C_FLAG)|ZTable[arg]|(((arg&0x0F)==0x0F)?H_FLAG:0)
#define ADDW(arg) \
	tmp.w=REG_HL+arg; \
	REG_F=(REG_F&Z_FLAG)|(((REG_HL^arg^tmp.w)&0x1000)?H_FLAG:0)|((((unsigned long)REG_HL+(unsigned long)arg)&0x10000)?C_FLAG:0); \
	REG_HL=tmp.w

// GB orginal op_code

case 0x08: writew(op_readw(),REG_SP);break; //LD (mn),SP
case 0x10: if (speed_change) { speed_change=false;speed^=1;REG_PC++;/* 1バイト読み飛ばす */ } else { halt=true;REG_PC--; }break; //STOP(HALT?)

//0x2A LD A,(mn) -> LD A,(HLI) Load A from (HL) and decrement HL
case 0x2A: REG_A=read(REG_HL);REG_HL++;break; // LD A,(HLI) : 00 111 010 :state 13

//0x22 LD (mn),A -> LD (HLI),A Save A at (HL) and decrement HL
case 0x22: write(REG_HL,REG_A);REG_HL++;break; // LD (HLI),A : 00 110 010 :state 13

//0x3A LD A,(mn) -> LD A,(HLD) Load A from (HL) and decrement HL
case 0x3A: REG_A=read(REG_HL);REG_HL--;break; // LD A,(HLD) : 00 111 010 :state 13

//0x32 LD (mn),A -> LD (HLD),A Save A at (HL) and decrement HL
case 0x32: write(REG_HL,REG_A);REG_HL--;break; // LD (HLD),A : 00 110 010 :state 13

case 0xD9: /*Log("Return Interrupts.\n");*/regs.I=1;REG_PC=readw(REG_SP);REG_SP+=2;int_desable=true;/*;ref_gb->get_regs()->IF=0*/;/*res->system_reg.IF&=~Int_hist[(Int_depth>0)?--Int_depth:Int_depth]*//*Int_depth=((Int_depth>0)?--Int_depth:Int_depth);*//*res->system_reg.IF=0;*//*Log("RETI %d\n",Int_depth);*/break;//RETI state 16
case 0xE0: write(0xFF00+op_read(),REG_A);break;//LDH (n),A
case 0xE2: write(0xFF00+REG_C,REG_A);break;//LDH (C),A
case 0xE8: REG_SP+=(signed char)op_read();break;//ADD SP,n
case 0xEA: write(op_readw(),REG_A);break;//LD (mn),A

case 0xF0: REG_A=read(0xFF00+op_read());break;//LDH A,(n)
case 0xF2: REG_A=read(0xFF00+REG_C);break;//LDH A,(c)
case 0xF8: REG_HL=REG_SP+(signed char)op_read();break;//LD HL,SP+n 
case 0xFA: REG_A=read(op_readw());break;//LD A,(mn);

// 8bit load op_code

// regs B 000 C 001 D 010 E 011 H 100 L 101 A 111
//LD r,s  :01 r s :state 4(clocks)

case 0x40: break; // LD B,B
case 0x41: REG_B=REG_C;break; // LD B,C
case 0x42: REG_B=REG_D;break; // LD B,D
case 0x43: REG_B=REG_E;break; // LD B,E
case 0x44: REG_B=REG_H;break; // LD B,H
case 0x45: REG_B=REG_L;break; // LD B,L
case 0x47: REG_B=REG_A;break; // LD B,A

case 0x48: REG_C=REG_B;break; // LD C,B
case 0x49: break; // LD C,C
case 0x4A: REG_C=REG_D;break; // LD C,D
case 0x4B: REG_C=REG_E;break; // LD C,E
case 0x4C: REG_C=REG_H;break; // LD C,H
case 0x4D: REG_C=REG_L;break; // LD C,L
case 0x4F: REG_C=REG_A;break; // LD C,A

case 0x50: REG_D=REG_B;break; // LD D,B
case 0x51: REG_D=REG_C;break; // LD D,C
case 0x52: break; // LD D,D
case 0x53: REG_D=REG_E;break; // LD D,E
case 0x54: REG_D=REG_H;break; // LD D,H
case 0x55: REG_D=REG_L;break; // LD D,L
case 0x57: REG_D=REG_A;break; // LD D,A

case 0x58: REG_E=REG_B;break; // LD E,B
case 0x59: REG_E=REG_C;break; // LD E,C
case 0x5A: REG_E=REG_D;break; // LD E,D
case 0x5B: break; // LD E,E
case 0x5C: REG_E=REG_H;break; // LD E,H
case 0x5D: REG_E=REG_L;break; // LD E,L
case 0x5F: REG_E=REG_A;break; // LD E,A

case 0x60: REG_H=REG_B;break; // LD H,B
case 0x61: REG_H=REG_C;break; // LD H,C
case 0x62: REG_H=REG_D;break; // LD H,D
case 0x63: REG_H=REG_E;break; // LD H,E
case 0x64: break; // LD H,H
case 0x65: REG_H=REG_L;break; // LD H,L
case 0x67: REG_H=REG_A;break; // LD H,A

case 0x68: REG_L=REG_B;break; // LD L,B
case 0x69: REG_L=REG_C;break; // LD L,C
case 0x6A: REG_L=REG_D;break; // LD L,D
case 0x6B: REG_L=REG_E;break; // LD L,E
case 0x6C: REG_L=REG_H;break; // LD L,H
case 0x6D: break; // LD L,L
case 0x6F: REG_L=REG_A;break; // LD L,A

case 0x78: REG_A=REG_B;break; // LD A,B
case 0x79: REG_A=REG_C;break; // LD A,C
case 0x7A: REG_A=REG_D;break; // LD A,D
case 0x7B: REG_A=REG_E;break; // LD A,E
case 0x7C: REG_A=REG_H;break; // LD A,H
case 0x7D: REG_A=REG_L;break; // LD A,L
case 0x7F: break; // LD A,A

//LD r,n :00 r 110 n :state 7
case 0x06: REG_B=op_read();break; // LD B,n
case 0x0E: REG_C=op_read();break; // LD C,n
case 0x16: REG_D=op_read();break; // LD D,n
case 0x1E: REG_E=op_read();break; // LD E,n
case 0x26: REG_H=op_read();break; // LD H,n
case 0x2E: REG_L=op_read();break; // LD L,n
case 0x3E: REG_A=op_read();break; // LD A,n

//LD r,(HL) :01 r 110 :state 7
case 0x46: REG_B=read(REG_HL);break; // LD B,(HL)
case 0x4E: REG_C=read(REG_HL);break; // LD C,(HL)
case 0x56: REG_D=read(REG_HL);break; // LD D,(HL)
case 0x5E: REG_E=read(REG_HL);break; // LD E,(HL)
case 0x66: REG_H=read(REG_HL);break; // LD H,(HL)
case 0x6E: REG_L=read(REG_HL);break; // LD L,(HL)
case 0x7E: REG_A=read(REG_HL);break; // LD A,(HL)

//LD (HL),r :01 110 r :state 7
case 0x70: write(REG_HL,REG_B);break; // LD (HL),B
case 0x71: write(REG_HL,REG_C);break; // LD (HL),C
case 0x72: write(REG_HL,REG_D);break; // LD (HL),D
case 0x73: write(REG_HL,REG_E);break; // LD (HL),E
case 0x74: write(REG_HL,REG_H);break; // LD (HL),H
case 0x75: write(REG_HL,REG_L);break; // LD (HL),L
case 0x77: write(REG_HL,REG_A);break; // LD (HL),A

case 0x36: write(REG_HL,op_read());break; // LD (HL),n :00 110 110 :state 10
case 0x0A: REG_A=read(REG_BC);break; // LD A,(BC) :00 001 010 :state 7
case 0x1A: REG_A=read(REG_DE);break; // LD A,(DE) :00 011 010 : state 7
case 0x02: write(REG_BC,REG_A);break; // LD (BC),A : 00 000 010 :state 7
case 0x12: write(REG_DE,REG_A);break; // LD (DE),A : 00 010 010 :state 7

//16bit load opcode
//rp Pair Reg 00 BC 01 DE 10 HL 11 SP

//LD rp,mn : 00 rp0 001 n m :state 10
case 0x01: REG_BC=op_readw();break; //LD BC,(mn)
case 0x11: REG_DE=op_readw();break; //LD DE,(mn)
case 0x21: REG_HL=op_readw();break; //LD HL,(mn)
case 0x31: REG_SP=op_readw();break; //LD SP,(mn)

case 0xF9: REG_SP=REG_HL;break; //LD SP,HL : 11 111 001 :state 6

//stack opcode
//rq Pair Reg 00 BC 01 DE 10 HL 11 AF

//PUSH rq : 11 rq0 101 : state 11(16?)
case 0xC5: REG_SP-=2;writew(REG_SP,REG_BC);break; //PUSH BC
case 0xD5: REG_SP-=2;writew(REG_SP,REG_DE);break; //PUSH DE
case 0xE5: REG_SP-=2;writew(REG_SP,REG_HL);break; //PUSH HL
case 0xF5: write(REG_SP-2,z802gb[REG_F]|0xe);write(REG_SP-1,REG_A);REG_SP-=2;break; //PUSH AF // 未使用ビットは1になるみたい(メタルギアより)

//POP rq : 11 rq0 001 : state 10 (12?)
case 0xC1: REG_B=read(REG_SP+1);REG_C=read(REG_SP);REG_SP+=2;break; //POP BC
case 0xD1: REG_D=read(REG_SP+1);REG_E=read(REG_SP);REG_SP+=2;break; //POP DE
case 0xE1: REG_H=read(REG_SP+1);REG_L=read(REG_SP);REG_SP+=2;break; //POP HL
case 0xF1: REG_A=read(REG_SP+1);REG_F=gb2z80[read(REG_SP)&0xf0];REG_SP+=2;break; //POP AF

//8bit arithmetic/logical opcode
//regs B 000 C 001 D 010 E 011 H 100 L 101 A 111

//ADD A,r : 10 000 r : state 4
case 0x80: ADD(REG_B);break; //ADD A,B
case 0x81: ADD(REG_C);break; //ADD A,C
case 0x82: ADD(REG_D);break; //ADD A,D
case 0x83: ADD(REG_E);break; //ADD A,E
case 0x84: ADD(REG_H);break; //ADD A,H
case 0x85: ADD(REG_L);break; //ADD A,L
case 0x87: ADD(REG_A);break; //ADD A,A

case 0xC6: tmpb=op_read();ADD(tmpb);break; //ADD A,n : 11 000 110 :state 7
case 0x86: tmpb=read(REG_HL);ADD(tmpb);break; //ADD A,(HL) : 10 000 110 :state 7

//ADC A,r : 10 001 r : state 4
case 0x88: ADC(REG_B);break; //ADC A,B
case 0x89: ADC(REG_C);break; //ADC A,C
case 0x8A: ADC(REG_D);break; //ADC A,D
case 0x8B: ADC(REG_E);break; //ADC A,E
case 0x8C: ADC(REG_H);break; //ADC A,H
case 0x8D: ADC(REG_L);break; //ADC A,L
case 0x8F: ADC(REG_A);break; //ADC A,A

case 0xCE: tmpb=op_read();ADC(tmpb);break; //ADC A,n : 11 001 110 :state 7
case 0x8E: tmpb=read(REG_HL);ADC(tmpb);break; //ADC A,(HL) : 10 001 110 :state 7

//SUB A,r : 10 010 r : state 4
case 0x90: SUB(REG_B);break; //SUB A,B
case 0x91: SUB(REG_C);break; //SUB A,C
case 0x92: SUB(REG_D);break; //SUB A,D
case 0x93: SUB(REG_E);break; //SUB A,E
case 0x94: SUB(REG_H);break; //SUB A,H
case 0x95: SUB(REG_L);break; //SUB A,L
case 0x97: SUB(REG_A);break; //SUB A,A

case 0xD6: tmpb=op_read();SUB(tmpb);break; //SUB A,n : 11 010 110 :state 7
case 0x96: tmpb=read(REG_HL);SUB(tmpb);break; //SUB A,(HL) : 10 010 110 :state 7

//SBC A,r : 10 011 r : state 4
case 0x98: SBC(REG_B);break; //SBC A,B
case 0x99: SBC(REG_C);break; //SBC A,C
case 0x9A: SBC(REG_D);break; //SBC A,D
case 0x9B: SBC(REG_E);break; //SBC A,E
case 0x9C: SBC(REG_H);break; //SBC A,H
case 0x9D: SBC(REG_L);break; //SBC A,L
case 0x9F: SBC(REG_A);break; //SBC A,A

case 0xDE: tmpb=op_read();SBC(tmpb);break; //SBC A,n : 11 011 110 :state 7
case 0x9E: tmpb=read(REG_HL);SBC(tmpb);break; //SBC A,(HL) : 10 011 110 :state 7

//AND A,r : 10 100 r : state 4
case 0xA0: AND(REG_B);break; //AND A,B
case 0xA1: AND(REG_C);break; //AND A,C
case 0xA2: AND(REG_D);break; //AND A,D
case 0xA3: AND(REG_E);break; //AND A,E
case 0xA4: AND(REG_H);break; //AND A,H
case 0xA5: AND(REG_L);break; //AND A,L
case 0xA7: AND(REG_A);break; //AND A,A

case 0xE6: tmpb=op_read();AND(tmpb);break; //AND A,n : 11 100 110 :state 7
case 0xA6: tmpb=read(REG_HL);AND(tmpb);break; //AND A,(HL) : 10 100 110 :state 7

//XOR A,r : 10 101 r : state 4
case 0xA8: XOR(REG_B);break; //XOR A,B
case 0xA9: XOR(REG_C);break; //XOR A,C
case 0xAA: XOR(REG_D);break; //XOR A,D
case 0xAB: XOR(REG_E);break; //XOR A,E
case 0xAC: XOR(REG_H);break; //XOR A,H
case 0xAD: XOR(REG_L);break; //XOR A,L
case 0xAF: XOR(REG_A);break; //XOR A,A

case 0xEE: tmpb=op_read();XOR(tmpb);break; //XOR A,n : 11 101 110 :state 7
case 0xAE: tmpb=read(REG_HL);XOR(tmpb);break; //XOR A,(HL) : 10 101 110 :state 7

//OR A,r : 10 110 r : state 4
case 0xB0: OR(REG_B);break; //OR A,B
case 0xB1: OR(REG_C);break; //OR A,C
case 0xB2: OR(REG_D);break; //OR A,D
case 0xB3: OR(REG_E);break; //OR A,E
case 0xB4: OR(REG_H);break; //OR A,H
case 0xB5: OR(REG_L);break; //OR A,L
case 0xB7: OR(REG_A);break; //OR A,A

case 0xF6: tmpb=op_read();OR(tmpb);break; //OR A,n : 11 110 110 :state 7
case 0xB6: tmpb=read(REG_HL);OR(tmpb);break; //OR A,(HL) : 10 110 110 :state 7

//CP A,r : 10 111 r : state 4
case 0xB8: CP(REG_B);break; //CP A,B
case 0xB9: CP(REG_C);break; //CP A,C
case 0xBA: CP(REG_D);break; //CP A,D
case 0xBB: CP(REG_E);break; //CP A,E
case 0xBC: CP(REG_H);break; //CP A,H
case 0xBD: CP(REG_L);break; //CP A,L
case 0xBF: CP(REG_A);break; //CP A,A

case 0xFE: tmpb=op_read();CP(tmpb);break; //CP A,n : 11 111 110 :state 7
case 0xBE: tmpb=read(REG_HL);CP(tmpb);break; //CP A,(HL) : 10 111 110 :state 7

//INC r : 00 r 100 : state 4
case 0x04: INC(REG_B);break; //INC B
case 0x0C: INC(REG_C);break; //INC C
case 0x14: INC(REG_D);break; //INC D
case 0x1C: INC(REG_E);break; //INC E
case 0x24: INC(REG_H);break; //INC H
case 0x2C: INC(REG_L);break; //INC L
case 0x3C: INC(REG_A);break; //INC A
case 0x34: tmpb=read(REG_HL);INC(tmpb);write(REG_HL,tmpb);break; //INC (HL) : 00 110 100 : state 11

//DEC r : 00 r 101 : state 4
case 0x05: DEC(REG_B);break; //DEC B
case 0x0D: DEC(REG_C);break; //DEC C
case 0x15: DEC(REG_D);break; //DEC D
case 0x1D: DEC(REG_E);break; //DEC E
case 0x25: DEC(REG_H);break; //DEC H
case 0x2D: DEC(REG_L);break; //DEC L
case 0x3D: DEC(REG_A);break; //DEC A
case 0x35: tmpb=read(REG_HL);DEC(tmpb);write(REG_HL,tmpb);break; //DEC (HL) : 00 110 101 : state 11

//16bit arismetic opcode
//rp Pair Reg 00 BC 01 DE 10 HL 11 SP

//ADD HL,BC : 00 rp1 001 :state 11
case 0x09: ADDW(REG_BC);break; //ADD HL,BC
case 0x19: ADDW(REG_DE);break; //ADD HL,DE
case 0x29: ADDW(REG_HL);break; //ADD HL,HL
case 0x39: ADDW(REG_SP);break; //ADD HL,SP

//INC BC : 00 rp0 011 :state 11
case 0x03: REG_BC++;;break; //INC BC
case 0x13: REG_DE++;break; //INC DE
case 0x23: REG_HL++;break; //INC HL
case 0x33: REG_SP++;break; //INC SP

//DEC BC : 00 rp1 011 :state 11
case 0x0B: REG_BC--;break; //DEC BC
case 0x1B: REG_DE--;break; //DEC DE
case 0x2B: REG_HL--;break; //DEC HL
case 0x3B: REG_SP--;break; //DEC SP

//汎用：CPU制御 opcode

/*case 0x27://DAA :state 4
	tmp.b.h=REG_A&0x0F;
	tmp.w=(REG_F&N_FLAG)?
		((REG_F&C_FLAG)?(((REG_F&H_FLAG)?0x9A00:0xA000)+C_FLAG):((REG_F&H_FLAG)?0xFA00:0x0000)):
		((REG_F&C_FLAG)?(((REG_F&H_FLAG)?0x6600:((tmp.b.h<0x0A)?0x6000:0x6600))+C_FLAG):
		((REG_F&H_FLAG)?((REG_A<0xA0)?0x0600:(0x6600+C_FLAG)):((tmp.b.h<0x0A)?((REG_A<0xA0)?0x0000:(0x6000+C_FLAG)):
		((REG_F<0x90)?0x600:(0x6600+C_FLAG)))));
	REG_A+=tmp.b.h;
	REG_F=ZTable[REG_A]|(tmp.b.l|(REG_F&N_FLAG));
	break;
*/
case 0x27://DAA :state 4
  tmp.b.h=REG_A&0x0F;
  tmp.w=(REG_F&N_FLAG)?
  (
    (REG_F&C_FLAG)?
      (((REG_F&H_FLAG)? 0x9A00:0xA000)+C_FLAG):
      ((REG_F&H_FLAG)? 0xFA00:0x0000)
  )
  :
  (
    (REG_F&C_FLAG)?
      (((REG_F&H_FLAG)? 0x6600:((tmp.b.h<0x0A)? 0x6000:0x6600))+C_FLAG):
      (
        (REG_F&H_FLAG)?
          ((REG_A<0xA0)? 0x0600:(0x6600+C_FLAG)):
          (
            (tmp.b.h<0x0A)? 
              ((REG_A<0xA0)? 0x0000:(0x6000+C_FLAG)): 
	      ((REG_A<0x90)? 0x0600:(0x6600+C_FLAG))
          )
      )
  );
  REG_A+=tmp.b.h;
  REG_F=ZTable[REG_A]|(tmp.b.l|(REG_F&N_FLAG));
//  FLAGS(REG_A,tmp.b.l|(REG_F&N_FLAG));
  break;

case 0x2F: //CPL(1の補数) :state4
	REG_A=~REG_A;
	REG_F|=(N_FLAG|H_FLAG);
	break;

case 0x3F: //CCF(not carry) :state 4
	REG_F^=0x01;
	REG_F=REG_F&~(N_FLAG|H_FLAG);
//	REG_F|=(REG_F&C_FLAG)?0:H_FLAG;
	break;

case 0x37: //SCF(set carry) :state 4
	REG_F=(REG_F&~(N_FLAG|H_FLAG))|C_FLAG;
	break;

case 0x00: break; //NOP : state 4
case 0xF3: regs.I=0;break; //DI : state 4
case 0xFB: regs.I=1;int_desable=true;break; //EI : state 4

case 0x76:
#ifndef EXSACT_CORE
	if (ref_gb->get_regs()->TAC&0x04){//タイマ割りこみ
		word tmp;
		tmp=ref_gb->get_regs()->TIMA+(sys_clock+rest_clock)/timer_clocks[ref_gb->get_regs()->TAC&0x03];

		if (tmp&0xFF00){//HALT中に割りこみがかかる場合
			total_clock+=(256-ref_gb->get_regs()->TIMA)*timer_clocks[ref_gb->get_regs()->TAC&0x03]-sys_clock;
			rest_clock-=(256-ref_gb->get_regs()->TIMA)*timer_clocks[ref_gb->get_regs()->TAC&0x03]-sys_clock;
			ref_gb->get_regs()->TIMA=ref_gb->get_regs()->TMA;
			halt=true;
			REG_PC--;
			irq(INT_TIMER);
			sys_clock=(sys_clock+rest_clock)&(timer_clocks[ref_gb->get_regs()->TAC&0x03]-1);
		}
		else{
			ref_gb->get_regs()->TIMA=tmp&0xFF;
			sys_clock=(sys_clock+rest_clock)&(timer_clocks[ref_gb->get_regs()->TAC&0x03]-1);
			halt=true;
			total_clock+=rest_clock;
			rest_clock=0;
			REG_PC--;
		}
	}
	else{
		halt=true;
		total_clock+=rest_clock;
		div_clock+=rest_clock;
		rest_clock=0;
		REG_PC--;
	}
	tmp_clocks=0;
#else
	halt=true;
	REG_PC--;
#endif
	break; //HALT : state 4

//rotate/shift opcode
case 0x07: REG_F=(REG_A>>7);REG_A=(REG_A<<1)|(REG_A>>7);break; //RLCA :state 4
case 0x0F: REG_F=(REG_A&1);REG_A=(REG_A>>1)|(REG_A<<7);break; //RRCA :state 4
case 0x17: tmp.b.l=REG_A>>7;REG_A=(REG_A<<1)|(REG_F&C_FLAG);REG_F=tmp.b.l;break; //RLA :state 4
case 0x1F: tmp.b.l=REG_A&1;REG_A=(REG_A>>1)|(REG_F<<7);REG_F=tmp.b.l;break; //RRA :state 4

//jump opcode

//cc 条件 000 NZ non zero 001 Z zero 010 NC non carry 011 C carry
case 0xC3: REG_PC=op_readw();break;//JP mn : state 10 (16?)

//JP cc,mn : 11 cc 010 : state 16 or 12
case 0xC2: if (REG_F&Z_FLAG) REG_PC+=2; else { REG_PC=op_readw();tmp_clocks=16; };break; // JPNZ mn
case 0xCA: if (REG_F&Z_FLAG) { REG_PC=op_readw();tmp_clocks=16; } else REG_PC+=2;;break; // JPZ mn
case 0xD2: if (REG_F&C_FLAG) REG_PC+=2; else { REG_PC=op_readw();tmp_clocks=16; };break; // JPNC mn
case 0xDA: if (REG_F&C_FLAG) { REG_PC=op_readw();tmp_clocks=16; } else REG_PC+=2;;break; // JPC mn

case 0xE9: REG_PC=REG_HL;break; //JP HL : state 4 
case 0x18: REG_PC+=(signed char)op_read();break;//JR e : state 12

//JR cc,e : 00 1cc 000 : state 12(not jumped ->8)
case 0x20: if (REG_F&Z_FLAG) REG_PC+=1; else {REG_PC+=(signed char)op_read();tmp_clocks=12;} break;// JRNZ
case 0x28: if (REG_F&Z_FLAG) {REG_PC+=(signed char)op_read();tmp_clocks=12;} else REG_PC+=1; break;// JRZ
case 0x30: if (REG_F&C_FLAG) REG_PC+=1; else {REG_PC+=(signed char)op_read();tmp_clocks=12;} break;// JRNC
case 0x38: if (REG_F&C_FLAG) {REG_PC+=(signed char)op_read();tmp_clocks=12;} else REG_PC+=1; break;// JRC

//call/ret opcode

case 0xCD: REG_SP-=2;writew(REG_SP,REG_PC+2);REG_PC=op_readw();break; //CALL mn :state 24

//CALL cc,mn : 11 0cc 100 : state 24 or 12
case 0xC4: if (REG_F&Z_FLAG) REG_PC+=2; else {REG_SP-=2;writew(REG_SP,REG_PC+2);REG_PC=op_readw();tmp_clocks=24;} break; //CALLNZ mn
case 0xCC: if (REG_F&Z_FLAG) {REG_SP-=2;writew(REG_SP,REG_PC+2);REG_PC=op_readw();tmp_clocks=24;} else REG_PC+=2; break; //CALLZ mn
case 0xD4: if (REG_F&C_FLAG) REG_PC+=2; else {REG_SP-=2;writew(REG_SP,REG_PC+2);REG_PC=op_readw();tmp_clocks=24;} break; //CALLNC mn
case 0xDC: if (REG_F&C_FLAG) {REG_SP-=2;writew(REG_SP,REG_PC+2);REG_PC=op_readw();tmp_clocks=24;} else REG_PC+=2; break; //CALLC mn

//RST p : 11 t 111 (p=t<<3) : state 16
case 0xC7: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x00;break; //RST 0x00
case 0xCF: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x08;break; //RST 0x08
case 0xD7: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x10;break; //RST 0x10
case 0xDF: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x18;break; //RST 0x18
case 0xE7: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x20;break; //RST 0x20
case 0xEF: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x28;break; //RST 0x28
case 0xF7: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x30;break; //RST 0x30
case 0xFF: REG_SP-=2;writew(REG_SP,REG_PC);REG_PC=0x38;break; //RST 0x38

case 0xC9: REG_PC=readw(REG_SP);REG_SP+=2;break; //RET state 16

//RET cc : 11 0cc 000 : state 20 or 8
case 0xC0: if (!(REG_F&Z_FLAG)) {REG_PC=readw(REG_SP);REG_SP+=2;tmp_clocks=20;} break; //RETNZ
case 0xC8: if (REG_F&Z_FLAG) {REG_PC=readw(REG_SP);REG_SP+=2;tmp_clocks=20;} break; //RETZ
case 0xD0: if (!(REG_F&C_FLAG)) {REG_PC=readw(REG_SP);REG_SP+=2;tmp_clocks=20;} break; //RETNC
case 0xD8: if (REG_F&C_FLAG) {REG_PC=readw(REG_SP);REG_SP+=2;tmp_clocks=20;} break; //RETC
