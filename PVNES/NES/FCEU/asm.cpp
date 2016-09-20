/// \file
/// \brief 6502 assembler and disassembler

#include "types.h"
#include "utils/xstring.h"
#include "debug.h"
#include "asm.h"
#include "x6502.h"

#include <cstring>
#include <cstdlib>
#include <cstdio>
///assembles the string to an instruction located at addr, storing opcodes in output buffer
int Assemble(unsigned char *output, int addr, char *str) {
	//unsigned char opcode[3] = { 0,0,0 };
	output[0] = output[1] = output[2] = 0;
	char astr[128],ins[4];
	int len = strlen(str);
	if ((!len) || (len > 0x127)) return 1;

	strcpy(astr,str);
	str_ucase(astr);
	sscanf(astr,"%3s",ins); //get instruction
	if (strlen(ins) != 3) return 1;
	strcpy(astr,strstr(astr,ins)+3); //heheh, this is probably a bad idea, but let's do it anyway!
	if ((astr[0] != ' ') && (astr[0] != 0)) return 1;

	//remove all whitespace
	str_strip(astr,STRIP_SP|STRIP_TAB|STRIP_CR|STRIP_LF);

	//repair syntax
	chr_replace(astr,'[','(');	//brackets
	chr_replace(astr,']',')');
	chr_replace(astr,'{','(');
	chr_replace(astr,'}',')');
	chr_replace(astr,';',0);	//comments
	str_replace(astr,"0X","$");	//miscellaneous

	//This does the following:
	// 1) Sets opcode[0] on success, else returns 1.
	// 2) Parses text in *astr to build the rest of the assembled
	//    data in 'opcode', else returns 1 on error.

	if (!strlen(astr)) {
		//Implied instructions
			 if (!strcmp(ins,"BRK")) output[0] = 0x00;
		else if (!strcmp(ins,"PHP")) output[0] = 0x08;
		else if (!strcmp(ins,"ASL")) output[0] = 0x0A;
		else if (!strcmp(ins,"CLC")) output[0] = 0x18;
		else if (!strcmp(ins,"PLP")) output[0] = 0x28;
		else if (!strcmp(ins,"ROL")) output[0] = 0x2A;
		else if (!strcmp(ins,"SEC")) output[0] = 0x38;
		else if (!strcmp(ins,"RTI")) output[0] = 0x40;
		else if (!strcmp(ins,"PHA")) output[0] = 0x48;
		else if (!strcmp(ins,"LSR")) output[0] = 0x4A;
		else if (!strcmp(ins,"CLI")) output[0] = 0x58;
		else if (!strcmp(ins,"RTS")) output[0] = 0x60;
		else if (!strcmp(ins,"PLA")) output[0] = 0x68;
		else if (!strcmp(ins,"ROR")) output[0] = 0x6A;
		else if (!strcmp(ins,"SEI")) output[0] = 0x78;
		else if (!strcmp(ins,"DEY")) output[0] = 0x88;
		else if (!strcmp(ins,"TXA")) output[0] = 0x8A;
		else if (!strcmp(ins,"TYA")) output[0] = 0x98;
		else if (!strcmp(ins,"TXS")) output[0] = 0x9A;
		else if (!strcmp(ins,"TAY")) output[0] = 0xA8;
		else if (!strcmp(ins,"TAX")) output[0] = 0xAA;
		else if (!strcmp(ins,"CLV")) output[0] = 0xB8;
		else if (!strcmp(ins,"TSX")) output[0] = 0xBA;
		else if (!strcmp(ins,"INY")) output[0] = 0xC8;
		else if (!strcmp(ins,"DEX")) output[0] = 0xCA;
		else if (!strcmp(ins,"CLD")) output[0] = 0xD8;
		else if (!strcmp(ins,"INX")) output[0] = 0xE8;
		else if (!strcmp(ins,"NOP")) output[0] = 0xEA;
		else if (!strcmp(ins,"SED")) output[0] = 0xF8;
		else return 1;
	}
	else {
		//Instructions with Operands
			 if (!strcmp(ins,"ORA")) output[0] = 0x01;
		else if (!strcmp(ins,"ASL")) output[0] = 0x06;
		else if (!strcmp(ins,"BPL")) output[0] = 0x10;
		else if (!strcmp(ins,"JSR")) output[0] = 0x20;
		else if (!strcmp(ins,"AND")) output[0] = 0x21;
		else if (!strcmp(ins,"BIT")) output[0] = 0x24;
		else if (!strcmp(ins,"ROL")) output[0] = 0x26;
		else if (!strcmp(ins,"BMI")) output[0] = 0x30;
		else if (!strcmp(ins,"EOR")) output[0] = 0x41;
		else if (!strcmp(ins,"LSR")) output[0] = 0x46;
		else if (!strcmp(ins,"JMP")) output[0] = 0x4C;
		else if (!strcmp(ins,"BVC")) output[0] = 0x50;
		else if (!strcmp(ins,"ADC")) output[0] = 0x61;
		else if (!strcmp(ins,"ROR")) output[0] = 0x66;
		else if (!strcmp(ins,"BVS")) output[0] = 0x70;
		else if (!strcmp(ins,"STA")) output[0] = 0x81;
		else if (!strcmp(ins,"STY")) output[0] = 0x84;
		else if (!strcmp(ins,"STX")) output[0] = 0x86;
		else if (!strcmp(ins,"BCC")) output[0] = 0x90;
		else if (!strcmp(ins,"LDY")) output[0] = 0xA0;
		else if (!strcmp(ins,"LDA")) output[0] = 0xA1;
		else if (!strcmp(ins,"LDX")) output[0] = 0xA2;
		else if (!strcmp(ins,"BCS")) output[0] = 0xB0;
		else if (!strcmp(ins,"CPY")) output[0] = 0xC0;
		else if (!strcmp(ins,"CMP")) output[0] = 0xC1;
		else if (!strcmp(ins,"DEC")) output[0] = 0xC6;
		else if (!strcmp(ins,"BNE")) output[0] = 0xD0;
		else if (!strcmp(ins,"CPX")) output[0] = 0xE0;
		else if (!strcmp(ins,"SBC")) output[0] = 0xE1;
		else if (!strcmp(ins,"INC")) output[0] = 0xE6;
		else if (!strcmp(ins,"BEQ")) output[0] = 0xF0;
		else return 1;

		{
			//Parse Operands
			// It's not the sexiest thing ever, but it works well enough!

			//TODO:
			// Add branches.
			// Fix certain instructions. (Setting bits is not 100% perfect.)
			// Fix instruction/operand matching. (Instructions like "jmp ($94),Y" are no good!)
			// Optimizations?
			int tmpint;
			char tmpchr,tmpstr[20];

			if (sscanf(astr,"#$%2X%c",&tmpint,&tmpchr) == 1) { //#Immediate
				switch (output[0]) {
					case 0x20: case 0x4C: //Jumps
					case 0x10: case 0x30: case 0x50: case 0x70: //Branches
					case 0x90: case 0xB0: case 0xD0: case 0xF0:
					case 0x06: case 0x24: case 0x26: case 0x46: //Other instructions incapable of #Immediate
					case 0x66: case 0x81: case 0x84: case 0x86:
					case 0xC6: case 0xE6:
						return 1;
					default:
						//cheap hack for certain instructions
						switch (output[0]) {
							case 0xA0: case 0xA2: case 0xC0: case 0xE0:
								break;
							default:
								output[0] |= 0x08;
								break;
						}
						output[1] = tmpint;
						break;
				}
			}
			else if (sscanf(astr,"$%4X%c",&tmpint,&tmpchr) == 1) { //Absolute, Zero Page, Branch, or Jump
				switch (output[0]) {
					case 0x20: case 0x4C: //Jumps
						output[1] = (tmpint & 0xFF);
						output[2] = (tmpint >> 8);
						break;
					case 0x10: case 0x30: case 0x50: case 0x70: //Branches
					case 0x90: case 0xB0: case 0xD0: case 0xF0:
						tmpint -= (addr+2);
						if ((tmpint < -128) || (tmpint > 127)) return 1;
						output[1] = (tmpint & 0xFF);
						break;
						//return 1; //FIX ME
					default:
						if (tmpint > 0xFF) { //Absolute
							output[0] |= 0x0C;
							output[1] = (tmpint & 0xFF);
							output[2] = (tmpint >> 8);
						}
						else { //Zero Page
							output[0] |= 0x04;
							output[1] = (tmpint & 0xFF);
						}
						break;
				}
			}
			else if (sscanf(astr,"$%4X%s",&tmpint,tmpstr) == 2) { //Absolute,X, Zero Page,X, Absolute,Y or Zero Page,Y
				if (!strcmp(tmpstr,",X")) { //Absolute,X or Zero Page,X
					switch (output[0]) {
						case 0x20: case 0x4C: //Jumps
						case 0x10: case 0x30: case 0x50: case 0x70: //Branches
						case 0x90: case 0xB0: case 0xD0: case 0xF0:
						case 0x24: case 0x86: case 0xA2: case 0xC0: //Other instructions incapable of Absolute,X or Zero Page,X
						case 0xE0:
							return 1;
						default:
							if (tmpint > 0xFF) { //Absolute
								if (output[0] == 0x84) return 1; //No STY Absolute,X!
								output[0] |= 0x1C;
								output[1] = (tmpint & 0xFF);
								output[2] = (tmpint >> 8);
							}
							else { //Zero Page
								output[0] |= 0x14;
								output[1] = (tmpint & 0xFF);
							}
							break;
					}
				}
				else if (!strcmp(tmpstr,",Y")) { //Absolute,Y or Zero Page,Y
					switch (output[0]) {
						case 0x20: case 0x4C: //Jumps
						case 0x10: case 0x30: case 0x50: case 0x70: //Branches
						case 0x90: case 0xB0: case 0xD0: case 0xF0:
						case 0x06: case 0x24: case 0x26: case 0x46: //Other instructions incapable of Absolute,Y or Zero Page,Y
						case 0x66: case 0x84: case 0x86: case 0xA0:
						case 0xC0: case 0xC6: case 0xE0: case 0xE6:
							return 1;
						case 0xA2: //cheap hack for LDX
							output[0] |= 0x04;
						default:
							if (tmpint > 0xFF) { //Absolute
								if (output[0] == 0x86) return 1; //No STX Absolute,Y!
								output[0] |= 0x18;
								output[1] = (tmpint & 0xFF);
								output[2] = (tmpint >> 8);
							}
							else { //Zero Page
								if ((output[0] != 0x86) && (output[0] != 0xA2)) return 1; //only STX and LDX Absolute,Y!
								output[0] |= 0x10;
								output[1] = (tmpint & 0xFF);
							}
							break;
					}
				}
				else return 1;
			}
			else if (sscanf(astr,"($%4X%s",&tmpint,tmpstr) == 2) { //Jump (Indirect), (Indirect,X) or (Indirect),Y
				switch (output[0]) {
					case 0x20: //Jumps
					case 0x10: case 0x30: case 0x50: case 0x70: //Branches
					case 0x90: case 0xB0: case 0xD0: case 0xF0:
					case 0x06: case 0x24: case 0x26: case 0x46: //Other instructions incapable of Jump (Indirect), (Indirect,X) or (Indirect),Y
					case 0x66: case 0x84: case 0x86: case 0xA0:
					case 0xA2: case 0xC0: case 0xC6: case 0xE0:
					case 0xE6:
						return 1;
					default:
						if ((!strcmp(tmpstr,")")) && (output[0] == 0x4C)) { //Jump (Indirect)
							output[0] = 0x6C;
							output[1] = (tmpint & 0xFF);
							output[2] = (tmpint >> 8);
						}
						else if ((!strcmp(tmpstr,",X)")) && (tmpint <= 0xFF) && (output[0] != 0x4C)) { //(Indirect,X)
							output[1] = (tmpint & 0xFF);
						}
						else if ((!strcmp(tmpstr,"),Y")) && (tmpint <= 0xFF) && (output[0] != 0x4C)) { //(Indirect),Y
							output[0] |= 0x10;
							output[1] = (tmpint & 0xFF);
						}
						else return 1;
						break;
				}
			}
			else return 1;
		}
	}

	return 0;
}

///disassembles the opcodes in the buffer assuming the provided address. Uses GetMem() and 6502 current registers to query referenced values. returns a static string buffer.
char *Disassemble(int addr, uint8 *opcode) {
	static char str[64]={0},chr[5]={0};
	uint16 tmp,tmp2;

	//these may be replaced later with passed-in values to make a lighter-weight disassembly mode that may not query the referenced values
	#define RX (X.X)
	#define RY (X.Y)

	switch (opcode[0]) {
		#define relative(a) { \
			if (((a)=opcode[1])&0x80) (a) = addr-(((a)-1)^0xFF); \
			else (a)+=addr; \
		}
		#define absolute(a) { \
			(a) = opcode[1] | opcode[2]<<8; \
		}
		#define zpIndex(a,i) { \
			(a) = opcode[1]+(i); \
		}
		#define indirectX(a) { \
			(a) = (opcode[1]+RX)&0xFF; \
			(a) = GetMem((a)) | (GetMem(((a)+1)&0xff))<<8; \
		}
		#define indirectY(a) { \
			(a) = GetMem(opcode[1]) | (GetMem((opcode[1]+1)&0xff))<<8; \
			(a) += RY; \
		}


		#ifdef BRK_3BYTE_HACK
			case 0x00:
			sprintf(str,"BRK %02X %02X", opcode[1], opcode[2]);
			break;
		#else
			case 0x00: strcpy(str,"BRK"); break;
		#endif

		//odd, 1-byte opcodes
		case 0x08: strcpy(str,"PHP"); break;
		case 0x0A: strcpy(str,"ASL"); break;
		case 0x18: strcpy(str,"CLC"); break;
		case 0x28: strcpy(str,"PLP"); break;
		case 0x2A: strcpy(str,"ROL"); break;
		case 0x38: strcpy(str,"SEC"); break;
		case 0x40: strcpy(str,"RTI"); break;
		case 0x48: strcpy(str,"PHA"); break;
		case 0x4A: strcpy(str,"LSR"); break;
		case 0x58: strcpy(str,"CLI"); break;
		case 0x60: strcpy(str,"RTS"); break;
		case 0x68: strcpy(str,"PLA"); break;
		case 0x6A: strcpy(str,"ROR"); break;
		case 0x78: strcpy(str,"SEI"); break;
		case 0x88: strcpy(str,"DEY"); break;
		case 0x8A: strcpy(str,"TXA"); break;
		case 0x98: strcpy(str,"TYA"); break;
		case 0x9A: strcpy(str,"TXS"); break;
		case 0xA8: strcpy(str,"TAY"); break;
		case 0xAA: strcpy(str,"TAX"); break;
		case 0xB8: strcpy(str,"CLV"); break;
		case 0xBA: strcpy(str,"TSX"); break;
		case 0xC8: strcpy(str,"INY"); break;
		case 0xCA: strcpy(str,"DEX"); break;
		case 0xD8: strcpy(str,"CLD"); break;
		case 0xE8: strcpy(str,"INX"); break;
		case 0xEA: strcpy(str,"NOP"); break;
		case 0xF8: strcpy(str,"SED"); break;

		//(Indirect,X)
		case 0x01: strcpy(chr,"ORA"); goto _indirectx;
		case 0x21: strcpy(chr,"AND"); goto _indirectx;
		case 0x41: strcpy(chr,"EOR"); goto _indirectx;
		case 0x61: strcpy(chr,"ADC"); goto _indirectx;
		case 0x81: strcpy(chr,"STA"); goto _indirectx;
		case 0xA1: strcpy(chr,"LDA"); goto _indirectx;
		case 0xC1: strcpy(chr,"CMP"); goto _indirectx;
		case 0xE1: strcpy(chr,"SBC"); goto _indirectx;
		_indirectx:
			indirectX(tmp);
			sprintf(str,"%s ($%02X,X) @ $%04X = #$%02X", chr,opcode[1],tmp,GetMem(tmp));
			break;

		//Zero Page
		case 0x05: strcpy(chr,"ORA"); goto _zeropage;
		case 0x06: strcpy(chr,"ASL"); goto _zeropage;
		case 0x24: strcpy(chr,"BIT"); goto _zeropage;
		case 0x25: strcpy(chr,"AND"); goto _zeropage;
		case 0x26: strcpy(chr,"ROL"); goto _zeropage;
		case 0x45: strcpy(chr,"EOR"); goto _zeropage;
		case 0x46: strcpy(chr,"LSR"); goto _zeropage;
		case 0x65: strcpy(chr,"ADC"); goto _zeropage;
		case 0x66: strcpy(chr,"ROR"); goto _zeropage;
		case 0x84: strcpy(chr,"STY"); goto _zeropage;
		case 0x85: strcpy(chr,"STA"); goto _zeropage;
		case 0x86: strcpy(chr,"STX"); goto _zeropage;
		case 0xA4: strcpy(chr,"LDY"); goto _zeropage;
		case 0xA5: strcpy(chr,"LDA"); goto _zeropage;
		case 0xA6: strcpy(chr,"LDX"); goto _zeropage;
		case 0xC4: strcpy(chr,"CPY"); goto _zeropage;
		case 0xC5: strcpy(chr,"CMP"); goto _zeropage;
		case 0xC6: strcpy(chr,"DEC"); goto _zeropage;
		case 0xE4: strcpy(chr,"CPX"); goto _zeropage;
		case 0xE5: strcpy(chr,"SBC"); goto _zeropage;
		case 0xE6: strcpy(chr,"INC"); goto _zeropage;
		_zeropage:
		// ################################## Start of SP CODE ###########################
		// Change width to %04X
			sprintf(str,"%s $%04X = #$%02X", chr,opcode[1],GetMem(opcode[1]));
		// ################################## End of SP CODE ###########################
			break;

		//#Immediate
		case 0x09: strcpy(chr,"ORA"); goto _immediate;
		case 0x29: strcpy(chr,"AND"); goto _immediate;
		case 0x49: strcpy(chr,"EOR"); goto _immediate;
		case 0x69: strcpy(chr,"ADC"); goto _immediate;
		//case 0x89: strcpy(chr,"STA"); goto _immediate;  //baka, no STA #imm!!
		case 0xA0: strcpy(chr,"LDY"); goto _immediate;
		case 0xA2: strcpy(chr,"LDX"); goto _immediate;
		case 0xA9: strcpy(chr,"LDA"); goto _immediate;
		case 0xC0: strcpy(chr,"CPY"); goto _immediate;
		case 0xC9: strcpy(chr,"CMP"); goto _immediate;
		case 0xE0: strcpy(chr,"CPX"); goto _immediate;
		case 0xE9: strcpy(chr,"SBC"); goto _immediate;
		_immediate:
			sprintf(str,"%s #$%02X", chr,opcode[1]);
			break;

		//Absolute
		case 0x0D: strcpy(chr,"ORA"); goto _absolute;
		case 0x0E: strcpy(chr,"ASL"); goto _absolute;
		case 0x2C: strcpy(chr,"BIT"); goto _absolute;
		case 0x2D: strcpy(chr,"AND"); goto _absolute;
		case 0x2E: strcpy(chr,"ROL"); goto _absolute;
		case 0x4D: strcpy(chr,"EOR"); goto _absolute;
		case 0x4E: strcpy(chr,"LSR"); goto _absolute;
		case 0x6D: strcpy(chr,"ADC"); goto _absolute;
		case 0x6E: strcpy(chr,"ROR"); goto _absolute;
		case 0x8C: strcpy(chr,"STY"); goto _absolute;
		case 0x8D: strcpy(chr,"STA"); goto _absolute;
		case 0x8E: strcpy(chr,"STX"); goto _absolute;
		case 0xAC: strcpy(chr,"LDY"); goto _absolute;
		case 0xAD: strcpy(chr,"LDA"); goto _absolute;
		case 0xAE: strcpy(chr,"LDX"); goto _absolute;
		case 0xCC: strcpy(chr,"CPY"); goto _absolute;
		case 0xCD: strcpy(chr,"CMP"); goto _absolute;
		case 0xCE: strcpy(chr,"DEC"); goto _absolute;
		case 0xEC: strcpy(chr,"CPX"); goto _absolute;
		case 0xED: strcpy(chr,"SBC"); goto _absolute;
		case 0xEE: strcpy(chr,"INC"); goto _absolute;
		_absolute:
			absolute(tmp);
			sprintf(str,"%s $%04X = #$%02X", chr,tmp,GetMem(tmp));
			break;

		//branches
		case 0x10: strcpy(chr,"BPL"); goto _branch;
		case 0x30: strcpy(chr,"BMI"); goto _branch;
		case 0x50: strcpy(chr,"BVC"); goto _branch;
		case 0x70: strcpy(chr,"BVS"); goto _branch;
		case 0x90: strcpy(chr,"BCC"); goto _branch;
		case 0xB0: strcpy(chr,"BCS"); goto _branch;
		case 0xD0: strcpy(chr,"BNE"); goto _branch;
		case 0xF0: strcpy(chr,"BEQ"); goto _branch;
		_branch:
			relative(tmp);
			sprintf(str,"%s $%04X", chr,tmp);
			break;

		//(Indirect),Y
		case 0x11: strcpy(chr,"ORA"); goto _indirecty;
		case 0x31: strcpy(chr,"AND"); goto _indirecty;
		case 0x51: strcpy(chr,"EOR"); goto _indirecty;
		case 0x71: strcpy(chr,"ADC"); goto _indirecty;
		case 0x91: strcpy(chr,"STA"); goto _indirecty;
		case 0xB1: strcpy(chr,"LDA"); goto _indirecty;
		case 0xD1: strcpy(chr,"CMP"); goto _indirecty;
		case 0xF1: strcpy(chr,"SBC"); goto _indirecty;
		_indirecty:
			indirectY(tmp);
			sprintf(str,"%s ($%02X),Y @ $%04X = #$%02X", chr,opcode[1],tmp,GetMem(tmp));
			break;

		//Zero Page,X
		case 0x15: strcpy(chr,"ORA"); goto _zeropagex;
		case 0x16: strcpy(chr,"ASL"); goto _zeropagex;
		case 0x35: strcpy(chr,"AND"); goto _zeropagex;
		case 0x36: strcpy(chr,"ROL"); goto _zeropagex;
		case 0x55: strcpy(chr,"EOR"); goto _zeropagex;
		case 0x56: strcpy(chr,"LSR"); goto _zeropagex;
		case 0x75: strcpy(chr,"ADC"); goto _zeropagex;
		case 0x76: strcpy(chr,"ROR"); goto _zeropagex;
		case 0x94: strcpy(chr,"STY"); goto _zeropagex;
		case 0x95: strcpy(chr,"STA"); goto _zeropagex;
		case 0xB4: strcpy(chr,"LDY"); goto _zeropagex;
		case 0xB5: strcpy(chr,"LDA"); goto _zeropagex;
		case 0xD5: strcpy(chr,"CMP"); goto _zeropagex;
		case 0xD6: strcpy(chr,"DEC"); goto _zeropagex;
		case 0xF5: strcpy(chr,"SBC"); goto _zeropagex;
		case 0xF6: strcpy(chr,"INC"); goto _zeropagex;
		_zeropagex:
			zpIndex(tmp,RX);
		// ################################## Start of SP CODE ###########################
		// Change width to %04X
			sprintf(str,"%s $%02X,X @ $%04X = #$%02X", chr,opcode[1],tmp,GetMem(tmp));
		// ################################## End of SP CODE ###########################
			break;

		//Absolute,Y
		case 0x19: strcpy(chr,"ORA"); goto _absolutey;
		case 0x39: strcpy(chr,"AND"); goto _absolutey;
		case 0x59: strcpy(chr,"EOR"); goto _absolutey;
		case 0x79: strcpy(chr,"ADC"); goto _absolutey;
		case 0x99: strcpy(chr,"STA"); goto _absolutey;
		case 0xB9: strcpy(chr,"LDA"); goto _absolutey;
		case 0xBE: strcpy(chr,"LDX"); goto _absolutey;
		case 0xD9: strcpy(chr,"CMP"); goto _absolutey;
		case 0xF9: strcpy(chr,"SBC"); goto _absolutey;
		_absolutey:
			absolute(tmp);
			tmp2=(tmp+RY);
			sprintf(str,"%s $%04X,Y @ $%04X = #$%02X", chr,tmp,tmp2,GetMem(tmp2));
			break;

		//Absolute,X
		case 0x1D: strcpy(chr,"ORA"); goto _absolutex;
		case 0x1E: strcpy(chr,"ASL"); goto _absolutex;
		case 0x3D: strcpy(chr,"AND"); goto _absolutex;
		case 0x3E: strcpy(chr,"ROL"); goto _absolutex;
		case 0x5D: strcpy(chr,"EOR"); goto _absolutex;
		case 0x5E: strcpy(chr,"LSR"); goto _absolutex;
		case 0x7D: strcpy(chr,"ADC"); goto _absolutex;
		case 0x7E: strcpy(chr,"ROR"); goto _absolutex;
		case 0x9D: strcpy(chr,"STA"); goto _absolutex;
		case 0xBC: strcpy(chr,"LDY"); goto _absolutex;
		case 0xBD: strcpy(chr,"LDA"); goto _absolutex;
		case 0xDD: strcpy(chr,"CMP"); goto _absolutex;
		case 0xDE: strcpy(chr,"DEC"); goto _absolutex;
		case 0xFD: strcpy(chr,"SBC"); goto _absolutex;
		case 0xFE: strcpy(chr,"INC"); goto _absolutex;
		_absolutex:
			absolute(tmp);
			tmp2=(tmp+RX);
			sprintf(str,"%s $%04X,X @ $%04X = #$%02X", chr,tmp,tmp2,GetMem(tmp2));
			break;

		//jumps
		case 0x20: strcpy(chr,"JSR"); goto _jump;
		case 0x4C: strcpy(chr,"JMP"); goto _jump;
		case 0x6C: absolute(tmp); sprintf(str,"JMP ($%04X) = $%04X", tmp,GetMem(tmp)|GetMem(tmp+1)<<8); break;
		_jump:
			absolute(tmp);
			sprintf(str,"%s $%04X", chr,tmp);
			break;

		//Zero Page,Y
		case 0x96: strcpy(chr,"STX"); goto _zeropagey;
		case 0xB6: strcpy(chr,"LDX"); goto _zeropagey;
		_zeropagey:
			zpIndex(tmp,RY);
		// ################################## Start of SP CODE ###########################
		// Change width to %04X
			sprintf(str,"%s $%04X,Y @ $%04X = #$%02X", chr,opcode[1],tmp,GetMem(tmp));
		// ################################## End of SP CODE ###########################
			break;

		//UNDEFINED
		default: strcpy(str,"ERROR"); break;

	}

	return str;
}
