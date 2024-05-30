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

//bit test/set/reset opcode

//B 000 C 001 D 010 E 011 H 100 L 101 A 111
//BIT b,r :01 b r :state 8
case 0x40: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B<<6)&0x40)^0x40);break; //BIT 0,B
case 0x41: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C<<6)&0x40)^0x40);break; //BIT 0,C
case 0x42: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D<<6)&0x40)^0x40);break; //BIT 0,D
case 0x43: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E<<6)&0x40)^0x40);break; //BIT 0,E
case 0x44: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H<<6)&0x40)^0x40);break; //BIT 0,H
case 0x45: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L<<6)&0x40)^0x40);break; //BIT 0,L
case 0x47: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A<<6)&0x40)^0x40);break; //BIT 0,A

case 0x48: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B<<5)&0x40)^0x40);break; //BIT 1,B
case 0x49: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C<<5)&0x40)^0x40);break; //BIT 1,C
case 0x4A: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D<<5)&0x40)^0x40);break; //BIT 1,D
case 0x4B: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E<<5)&0x40)^0x40);break; //BIT 1,E
case 0x4C: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H<<5)&0x40)^0x40);break; //BIT 1,H
case 0x4D: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L<<5)&0x40)^0x40);break; //BIT 1,L
case 0x4F: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A<<5)&0x40)^0x40);break; //BIT 1,A

case 0x50: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B<<4)&0x40)^0x40);break; //BIT 2,B
case 0x51: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C<<4)&0x40)^0x40);break; //BIT 2,C
case 0x52: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D<<4)&0x40)^0x40);break; //BIT 2,D
case 0x53: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E<<4)&0x40)^0x40);break; //BIT 2,E
case 0x54: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H<<4)&0x40)^0x40);break; //BIT 2,H
case 0x55: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L<<4)&0x40)^0x40);break; //BIT 2,L
case 0x57: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A<<4)&0x40)^0x40);break; //BIT 2,A

case 0x58: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B<<3)&0x40)^0x40);break; //BIT 3,B
case 0x59: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C<<3)&0x40)^0x40);break; //BIT 3,C
case 0x5A: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D<<3)&0x40)^0x40);break; //BIT 3,D
case 0x5B: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E<<3)&0x40)^0x40);break; //BIT 3,E
case 0x5C: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H<<3)&0x40)^0x40);break; //BIT 3,H
case 0x5D: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L<<3)&0x40)^0x40);break; //BIT 3,L
case 0x5F: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A<<3)&0x40)^0x40);break; //BIT 3,A

case 0x60: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B<<2)&0x40)^0x40);break; //BIT 4,B
case 0x61: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C<<2)&0x40)^0x40);break; //BIT 4,C
case 0x62: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D<<2)&0x40)^0x40);break; //BIT 4,D
case 0x63: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E<<2)&0x40)^0x40);break; //BIT 4,E
case 0x64: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H<<2)&0x40)^0x40);break; //BIT 4,H
case 0x65: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L<<2)&0x40)^0x40);break; //BIT 4,L
case 0x67: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A<<2)&0x40)^0x40);break; //BIT 4,A

case 0x68: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B<<1)&0x40)^0x40);break; //BIT 5,B
case 0x69: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C<<1)&0x40)^0x40);break; //BIT 5,C
case 0x6A: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D<<1)&0x40)^0x40);break; //BIT 5,D
case 0x6B: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E<<1)&0x40)^0x40);break; //BIT 5,E
case 0x6C: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H<<1)&0x40)^0x40);break; //BIT 5,H
case 0x6D: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L<<1)&0x40)^0x40);break; //BIT 5,L
case 0x6F: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A<<1)&0x40)^0x40);break; //BIT 5,A

case 0x70: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B)&0x40)^0x40);break; //BIT 6,B
case 0x71: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C)&0x40)^0x40);break; //BIT 6,C
case 0x72: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D)&0x40)^0x40);break; //BIT 6,D
case 0x73: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E)&0x40)^0x40);break; //BIT 6,E
case 0x74: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H)&0x40)^0x40);break; //BIT 6,H
case 0x75: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L)&0x40)^0x40);break; //BIT 6,L
case 0x77: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A)&0x40)^0x40);break; //BIT 6,A

case 0x78: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_B>>1)&0x40)^0x40);break; //BIT 7,B
case 0x79: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_C>>1)&0x40)^0x40);break; //BIT 7,C
case 0x7A: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_D>>1)&0x40)^0x40);break; //BIT 7,D
case 0x7B: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_E>>1)&0x40)^0x40);break; //BIT 7,E
case 0x7C: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_H>>1)&0x40)^0x40);break; //BIT 7,H
case 0x7D: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_L>>1)&0x40)^0x40);break; //BIT 7,L
case 0x7F: REG_F=((REG_F&C_FLAG)|H_FLAG)|(((REG_A>>1)&0x40)^0x40);break; //BIT 7,A

//state 12
case 0x46: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l<<6)&0x40)^0x40);break; //BIT 0,(HL)
case 0x4E: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l<<5)&0x40)^0x40);break; //BIT 1,(HL)
case 0x56: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l<<4)&0x40)^0x40);break; //BIT 2,(HL)
case 0x5E: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l<<3)&0x40)^0x40);break; //BIT 3,(HL)
case 0x66: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l<<2)&0x40)^0x40);break; //BIT 4,(HL)
case 0x6E: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l<<1)&0x40)^0x40);break; //BIT 5,(HL)
case 0x76: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l)&0x40)^0x40);break; //BIT 6,(HL)
case 0x7E: tmp.b.l=read(REG_HL);REG_F=((REG_F&C_FLAG)|H_FLAG)|(((tmp.b.l>>1)&0x40)^0x40);break; //BIT 7,(HL)

//bit set opcode
//SET b,r :11 b r : state 8

case 0xC0: REG_B|=0x01;break; //SET 0,B
case 0xC1: REG_C|=0x01;break; //SET 0,C
case 0xC2: REG_D|=0x01;break; //SET 0,D
case 0xC3: REG_E|=0x01;break; //SET 0,E
case 0xC4: REG_H|=0x01;break; //SET 0,H
case 0xC5: REG_L|=0x01;break; //SET 0,L
case 0xC7: REG_A|=0x01;break; //SET 0,A

case 0xC8: REG_B|=0x02;break; //SET 1,B
case 0xC9: REG_C|=0x02;break; //SET 1,C
case 0xCA: REG_D|=0x02;break; //SET 1,D
case 0xCB: REG_E|=0x02;break; //SET 1,E
case 0xCC: REG_H|=0x02;break; //SET 1,H
case 0xCD: REG_L|=0x02;break; //SET 1,L
case 0xCF: REG_A|=0x02;break; //SET 1,A

case 0xD0: REG_B|=0x04;break; //SET 2,B
case 0xD1: REG_C|=0x04;break; //SET 2,C
case 0xD2: REG_D|=0x04;break; //SET 2,D
case 0xD3: REG_E|=0x04;break; //SET 2,E
case 0xD4: REG_H|=0x04;break; //SET 2,H
case 0xD5: REG_L|=0x04;break; //SET 2,L
case 0xD7: REG_A|=0x04;break; //SET 2,A

case 0xD8: REG_B|=0x08;break; //SET 3,B
case 0xD9: REG_C|=0x08;break; //SET 3,C
case 0xDA: REG_D|=0x08;break; //SET 3,D
case 0xDB: REG_E|=0x08;break; //SET 3,E
case 0xDC: REG_H|=0x08;break; //SET 3,H
case 0xDD: REG_L|=0x08;break; //SET 3,L
case 0xDF: REG_A|=0x08;break; //SET 3,A

case 0xE0: REG_B|=0x10;break; //SET 4,B
case 0xE1: REG_C|=0x10;break; //SET 4,C
case 0xE2: REG_D|=0x10;break; //SET 4,D
case 0xE3: REG_E|=0x10;break; //SET 4,E
case 0xE4: REG_H|=0x10;break; //SET 4,H
case 0xE5: REG_L|=0x10;break; //SET 4,L
case 0xE7: REG_A|=0x10;break; //SET 4,A

case 0xE8: REG_B|=0x20;break; //SET 5,B
case 0xE9: REG_C|=0x20;break; //SET 5,C
case 0xEA: REG_D|=0x20;break; //SET 5,D
case 0xEB: REG_E|=0x20;break; //SET 5,E
case 0xEC: REG_H|=0x20;break; //SET 5,H
case 0xED: REG_L|=0x20;break; //SET 5,L
case 0xEF: REG_A|=0x20;break; //SET 5,A

case 0xF0: REG_B|=0x40;break; //SET 6,B
case 0xF1: REG_C|=0x40;break; //SET 6,C
case 0xF2: REG_D|=0x40;break; //SET 6,D
case 0xF3: REG_E|=0x40;break; //SET 6,E
case 0xF4: REG_H|=0x40;break; //SET 6,H
case 0xF5: REG_L|=0x40;break; //SET 6,L
case 0xF7: REG_A|=0x40;break; //SET 6,A

case 0xF8: REG_B|=0x80;break; //SET 7,B
case 0xF9: REG_C|=0x80;break; //SET 7,C
case 0xFA: REG_D|=0x80;break; //SET 7,D
case 0xFB: REG_E|=0x80;break; //SET 7,E
case 0xFC: REG_H|=0x80;break; //SET 7,H
case 0xFD: REG_L|=0x80;break; //SET 7,L
case 0xFF: REG_A|=0x80;break; //SET 7,A

//state 16
case 0xC6: tmp.b.l=read(REG_HL);tmp.b.l|=0x01;write(REG_HL,tmp.b.l);break; //SET 0,(HL)
case 0xCE: tmp.b.l=read(REG_HL);tmp.b.l|=0x02;write(REG_HL,tmp.b.l);break; //SET 1,(HL)
case 0xD6: tmp.b.l=read(REG_HL);tmp.b.l|=0x04;write(REG_HL,tmp.b.l);break; //SET 2,(HL)
case 0xDE: tmp.b.l=read(REG_HL);tmp.b.l|=0x08;write(REG_HL,tmp.b.l);break; //SET 3,(HL)
case 0xE6: tmp.b.l=read(REG_HL);tmp.b.l|=0x10;write(REG_HL,tmp.b.l);break; //SET 4,(HL)
case 0xEE: tmp.b.l=read(REG_HL);tmp.b.l|=0x20;write(REG_HL,tmp.b.l);break; //SET 5,(HL)
case 0xF6: tmp.b.l=read(REG_HL);tmp.b.l|=0x40;write(REG_HL,tmp.b.l);break; //SET 6,(HL)
case 0xFE: tmp.b.l=read(REG_HL);tmp.b.l|=0x80;write(REG_HL,tmp.b.l);break; //SET 7,(HL)

//bit reset opcode
//RES b,r : 10 b r : state 8
case 0x80: REG_B&=0xFE;break; //RES 0,B
case 0x81: REG_C&=0xFE;break; //RES 0,C
case 0x82: REG_D&=0xFE;break; //RES 0,D
case 0x83: REG_E&=0xFE;break; //RES 0,E
case 0x84: REG_H&=0xFE;break; //RES 0,H
case 0x85: REG_L&=0xFE;break; //RES 0,L
case 0x87: REG_A&=0xFE;break; //RES 0,A

case 0x88: REG_B&=0xFD;break; //RES 1,B
case 0x89: REG_C&=0xFD;break; //RES 1,C
case 0x8A: REG_D&=0xFD;break; //RES 1,D
case 0x8B: REG_E&=0xFD;break; //RES 1,E
case 0x8C: REG_H&=0xFD;break; //RES 1,H
case 0x8D: REG_L&=0xFD;break; //RES 1,L
case 0x8F: REG_A&=0xFD;break; //RES 1,A

case 0x90: REG_B&=0xFB;break; //RES 2,B
case 0x91: REG_C&=0xFB;break; //RES 2,C
case 0x92: REG_D&=0xFB;break; //RES 2,D
case 0x93: REG_E&=0xFB;break; //RES 2,E
case 0x94: REG_H&=0xFB;break; //RES 2,H
case 0x95: REG_L&=0xFB;break; //RES 2,L
case 0x97: REG_A&=0xFB;break; //RES 2,A

case 0x98: REG_B&=0xF7;break; //RES 3,B
case 0x99: REG_C&=0xF7;break; //RES 3,C
case 0x9A: REG_D&=0xF7;break; //RES 3,D
case 0x9B: REG_E&=0xF7;break; //RES 3,E
case 0x9C: REG_H&=0xF7;break; //RES 3,H
case 0x9D: REG_L&=0xF7;break; //RES 3,L
case 0x9F: REG_A&=0xF7;break; //RES 3,A

case 0xA0: REG_B&=0xEF;break; //RES 4,B
case 0xA1: REG_C&=0xEF;break; //RES 4,C
case 0xA2: REG_D&=0xEF;break; //RES 4,D
case 0xA3: REG_E&=0xEF;break; //RES 4,E
case 0xA4: REG_H&=0xEF;break; //RES 4,H
case 0xA5: REG_L&=0xEF;break; //RES 4,L
case 0xA7: REG_A&=0xEF;break; //RES 4,A

case 0xA8: REG_B&=0xDF;break; //RES 5,B
case 0xA9: REG_C&=0xDF;break; //RES 5,C
case 0xAA: REG_D&=0xDF;break; //RES 5,D
case 0xAB: REG_E&=0xDF;break; //RES 5,E
case 0xAC: REG_H&=0xDF;break; //RES 5,H
case 0xAD: REG_L&=0xDF;break; //RES 5,L
case 0xAF: REG_A&=0xDF;break; //RES 5,A

case 0xB0: REG_B&=0xBF;break; //RES 6,B
case 0xB1: REG_C&=0xBF;break; //RES 6,C
case 0xB2: REG_D&=0xBF;break; //RES 6,D
case 0xB3: REG_E&=0xBF;break; //RES 6,E
case 0xB4: REG_H&=0xBF;break; //RES 6,H
case 0xB5: REG_L&=0xBF;break; //RES 6,L
case 0xB7: REG_A&=0xBF;break; //RES 6,A

case 0xB8: REG_B&=0x7F;break; //RES 7,B
case 0xB9: REG_C&=0x7F;break; //RES 7,C
case 0xBA: REG_D&=0x7F;break; //RES 7,D
case 0xBB: REG_E&=0x7F;break; //RES 7,E
case 0xBC: REG_H&=0x7F;break; //RES 7,H
case 0xBD: REG_L&=0x7F;break; //RES 7,L
case 0xBF: REG_A&=0x7F;break; //RES 7,A

//state 16
case 0x86: tmp.b.l=read(REG_HL);tmp.b.l&=0xFE;write(REG_HL,tmp.b.l);break; //RES 0,(HL)
case 0x8E: tmp.b.l=read(REG_HL);tmp.b.l&=0xFD;write(REG_HL,tmp.b.l);break; //RES 1,(HL)
case 0x96: tmp.b.l=read(REG_HL);tmp.b.l&=0xFB;write(REG_HL,tmp.b.l);break; //RES 2,(HL)
case 0x9E: tmp.b.l=read(REG_HL);tmp.b.l&=0xF7;write(REG_HL,tmp.b.l);break; //RES 3,(HL)
case 0xA6: tmp.b.l=read(REG_HL);tmp.b.l&=0xEF;write(REG_HL,tmp.b.l);break; //RES 4,(HL)
case 0xAE: tmp.b.l=read(REG_HL);tmp.b.l&=0xDF;write(REG_HL,tmp.b.l);break; //RES 5,(HL)
case 0xB6: tmp.b.l=read(REG_HL);tmp.b.l&=0xBF;write(REG_HL,tmp.b.l);break; //RES 6,(HL)
case 0xBE: tmp.b.l=read(REG_HL);tmp.b.l&=0x7F;write(REG_HL,tmp.b.l);break; //RES 7,(HL)

//shift rotate opcode
//RLC s : 00 000 r : state 8
case 0x00: REG_F=(REG_B>>7);REG_B=(REG_B<<1)|(REG_F);REG_F|=ZTable[REG_B];break;//RLC B
case 0x01: REG_F=(REG_C>>7);REG_C=(REG_C<<1)|(REG_F);REG_F|=ZTable[REG_C];break;//RLC C
case 0x02: REG_F=(REG_D>>7);REG_D=(REG_D<<1)|(REG_F);REG_F|=ZTable[REG_D];break;//RLC D
case 0x03: REG_F=(REG_E>>7);REG_E=(REG_E<<1)|(REG_F);REG_F|=ZTable[REG_E];break;//RLC E
case 0x04: REG_F=(REG_H>>7);REG_H=(REG_H<<1)|(REG_F);REG_F|=ZTable[REG_H];break;//RLC H
case 0x05: REG_F=(REG_L>>7);REG_L=(REG_L<<1)|(REG_F);REG_F|=ZTable[REG_L];break;//RLC L
case 0x07: REG_F=(REG_A>>7);REG_A=(REG_A<<1)|(REG_F);REG_F|=ZTable[REG_A];break;//RLC A

case 0x06: tmp.b.l=read(REG_HL);REG_F=(tmp.b.l>>7);tmp.b.l=(tmp.b.l<<1)|(REG_F);REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//RLC (HL) : state 16

//RRC s : 00 001 r : state 8
case 0x08: REG_F=(REG_B&0x01);REG_B=(REG_B>>1)|(REG_F<<7);REG_F|=ZTable[REG_B];break;//RRC B
case 0x09: REG_F=(REG_C&0x01);REG_C=(REG_C>>1)|(REG_F<<7);REG_F|=ZTable[REG_C];break;//RRC C
case 0x0A: REG_F=(REG_D&0x01);REG_D=(REG_D>>1)|(REG_F<<7);REG_F|=ZTable[REG_D];break;//RRC D
case 0x0B: REG_F=(REG_E&0x01);REG_E=(REG_E>>1)|(REG_F<<7);REG_F|=ZTable[REG_E];break;//RRC E
case 0x0C: REG_F=(REG_H&0x01);REG_H=(REG_H>>1)|(REG_F<<7);REG_F|=ZTable[REG_H];break;//RRC H
case 0x0D: REG_F=(REG_L&0x01);REG_L=(REG_L>>1)|(REG_F<<7);REG_F|=ZTable[REG_L];break;//RRC L
case 0x0F: REG_F=(REG_A&0x01);REG_A=(REG_A>>1)|(REG_F<<7);REG_F|=ZTable[REG_A];break;//RRC A

case 0x0E: tmp.b.l=read(REG_HL);REG_F=(tmp.b.l&0x01);tmp.b.l=(tmp.b.l>>1)|(REG_F<<7);REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//RRC (HL) :state 16

//RL s : 00 010 r : state 8
case 0x10: tmp.b.l=REG_F&0x01;REG_F=(REG_B>>7);REG_B=(REG_B<<1)|tmp.b.l;REG_F|=ZTable[REG_B];break;//RL B
case 0x11: tmp.b.l=REG_F&0x01;REG_F=(REG_C>>7);REG_C=(REG_C<<1)|tmp.b.l;REG_F|=ZTable[REG_C];break;//RL C
case 0x12: tmp.b.l=REG_F&0x01;REG_F=(REG_D>>7);REG_D=(REG_D<<1)|tmp.b.l;REG_F|=ZTable[REG_D];break;//RL D
case 0x13: tmp.b.l=REG_F&0x01;REG_F=(REG_E>>7);REG_E=(REG_E<<1)|tmp.b.l;REG_F|=ZTable[REG_E];break;//RL E
case 0x14: tmp.b.l=REG_F&0x01;REG_F=(REG_H>>7);REG_H=(REG_H<<1)|tmp.b.l;REG_F|=ZTable[REG_H];break;//RL H
case 0x15: tmp.b.l=REG_F&0x01;REG_F=(REG_L>>7);REG_L=(REG_L<<1)|tmp.b.l;REG_F|=ZTable[REG_L];break;//RL L
case 0x17: tmp.b.l=REG_F&0x01;REG_F=(REG_A>>7);REG_A=(REG_A<<1)|tmp.b.l;REG_F|=ZTable[REG_A];break;//RL A

case 0x16: tmp.b.l=read(REG_HL);tmp.b.h=REG_F&0x01;REG_F=(tmp.b.l>>7);tmp.b.l=(tmp.b.l<<1)|tmp.b.h;REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//RL (HL) :state 16

//RR s : 00 011 r : state 8
case 0x18: tmp.b.l=REG_F&0x01;REG_F=(REG_B&0x01);REG_B=(REG_B>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_B];break;//RR B
case 0x19: tmp.b.l=REG_F&0x01;REG_F=(REG_C&0x01);REG_C=(REG_C>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_C];break;//RR C
case 0x1A: tmp.b.l=REG_F&0x01;REG_F=(REG_D&0x01);REG_D=(REG_D>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_D];break;//RR D
case 0x1B: tmp.b.l=REG_F&0x01;REG_F=(REG_E&0x01);REG_E=(REG_E>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_E];break;//RR E
case 0x1C: tmp.b.l=REG_F&0x01;REG_F=(REG_H&0x01);REG_H=(REG_H>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_H];break;//RR H
case 0x1D: tmp.b.l=REG_F&0x01;REG_F=(REG_L&0x01);REG_L=(REG_L>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_L];break;//RR L
case 0x1F: tmp.b.l=REG_F&0x01;REG_F=(REG_A&0x01);REG_A=(REG_A>>1)|(tmp.b.l<<7);REG_F|=ZTable[REG_A];break;//RR A

case 0x1E: tmp.b.l=read(REG_HL);tmp.b.h=REG_F&0x01;REG_F=(tmp.b.l&0x01);tmp.b.l=(tmp.b.l>>1)|(tmp.b.h<<7);REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//RR (HL) :state 16

//SLA s : 00 100 r : state 8
case 0x20: REG_F=REG_B>>7;REG_B<<=1;REG_F|=ZTable[REG_B];break;//SLA B
case 0x21: REG_F=REG_C>>7;REG_C<<=1;REG_F|=ZTable[REG_C];break;//SLA C
case 0x22: REG_F=REG_D>>7;REG_D<<=1;REG_F|=ZTable[REG_D];break;//SLA D
case 0x23: REG_F=REG_E>>7;REG_E<<=1;REG_F|=ZTable[REG_E];break;//SLA E
case 0x24: REG_F=REG_H>>7;REG_H<<=1;REG_F|=ZTable[REG_H];break;//SLA H
case 0x25: REG_F=REG_L>>7;REG_L<<=1;REG_F|=ZTable[REG_L];break;//SLA L
case 0x27: REG_F=REG_A>>7;REG_A<<=1;REG_F|=ZTable[REG_A];break;//SLA A

case 0x26: tmp.b.l=read(REG_HL);REG_F=tmp.b.l>>7;tmp.b.l<<=1;REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//SLA (HL) :state 16

//SRA s : 00 101 r : state 8
case 0x28: REG_F=REG_B&0x01;REG_B=(REG_B>>1)|(REG_B&0x80);REG_F|=ZTable[REG_B];break;//SRA B
case 0x29: REG_F=REG_C&0x01;REG_C=(REG_C>>1)|(REG_C&0x80);REG_F|=ZTable[REG_C];break;//SRA C
case 0x2A: REG_F=REG_D&0x01;REG_D=(REG_D>>1)|(REG_D&0x80);REG_F|=ZTable[REG_D];break;//SRA D
case 0x2B: REG_F=REG_E&0x01;REG_E=(REG_E>>1)|(REG_E&0x80);REG_F|=ZTable[REG_E];break;//SRA E
case 0x2C: REG_F=REG_H&0x01;REG_H=(REG_H>>1)|(REG_H&0x80);REG_F|=ZTable[REG_H];break;//SRA H
case 0x2D: REG_F=REG_L&0x01;REG_L=(REG_L>>1)|(REG_L&0x80);REG_F|=ZTable[REG_L];break;//SRA L
case 0x2F: REG_F=REG_A&0x01;REG_A=(REG_A>>1)|(REG_A&0x80);REG_F|=ZTable[REG_A];break;//SRA A

case 0x2E: tmp.b.l=read(REG_HL);REG_F=tmp.b.l&0x01;tmp.b.l>>=1;tmp.b.l|=(tmp.b.l<<1)&0x80;REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//SRA (HL) :state 16

//SRL s : 00 111 r : state 8
case 0x38: REG_F=REG_B&0x01;REG_B>>=1;REG_F|=ZTable[REG_B];break;//SRL B
case 0x39: REG_F=REG_C&0x01;REG_C>>=1;REG_F|=ZTable[REG_C];break;//SRL C
case 0x3A: REG_F=REG_D&0x01;REG_D>>=1;REG_F|=ZTable[REG_D];break;//SRL D
case 0x3B: REG_F=REG_E&0x01;REG_E>>=1;REG_F|=ZTable[REG_E];break;//SRL E
case 0x3C: REG_F=REG_H&0x01;REG_H>>=1;REG_F|=ZTable[REG_H];break;//SRL H
case 0x3D: REG_F=REG_L&0x01;REG_L>>=1;REG_F|=ZTable[REG_L];break;//SRL L
case 0x3F: REG_F=REG_A&0x01;REG_A>>=1;REG_F|=ZTable[REG_A];break;//SRL A

case 0x3E: tmp.b.l=read(REG_HL);REG_F=tmp.b.l&0x01;tmp.b.l>>=1;REG_F|=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//SRL (HL) :state 16

//swap opcode
//SWAP n : 00 110 r :state 8
case 0x30: REG_B=(REG_B>>4)|(REG_B<<4);REG_F=ZTable[REG_B];break;//SWAP B
case 0x31: REG_C=(REG_C>>4)|(REG_C<<4);REG_F=ZTable[REG_C];break;//SWAP C
case 0x32: REG_D=(REG_D>>4)|(REG_D<<4);REG_F=ZTable[REG_D];break;//SWAP D
case 0x33: REG_E=(REG_E>>4)|(REG_E<<4);REG_F=ZTable[REG_E];break;//SWAP E
case 0x34: REG_H=(REG_H>>4)|(REG_H<<4);REG_F=ZTable[REG_H];break;//SWAP H
case 0x35: REG_L=(REG_L>>4)|(REG_L<<4);REG_F=ZTable[REG_L];break;//SWAP L
case 0x37: REG_A=(REG_A>>4)|(REG_A<<4);REG_F=ZTable[REG_A];break;//SWAP A

case 0x36: tmp.b.l=read(REG_HL);tmp.b.l=(tmp.b.l>>4)|(tmp.b.l<<4);REG_F=ZTable[tmp.b.l];write(REG_HL,tmp.b.l);break;//SWAP (HL) : state 16
