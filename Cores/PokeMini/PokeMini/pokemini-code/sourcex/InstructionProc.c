/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "InstructionProc.h"
#include "InstructionInfo.h"
#include "PMCommon.h"

// Get instruction data and size, return InstructionInfo
InstructionInfo *GetInstructionInfo(InstructionProcReadCB readcb, int cpu, uint32_t addr, uint8_t *data, int *size)
{
	InstructionInfo *II;
	uint8_t IR, IR2;
	if (!readcb) return 0;
	IR = readcb(cpu, addr);
	if (IR == 0xCE) {
		// Expand 1
		IR2 = readcb(cpu, addr+1);
		II = &DebugCPUInstructions_CE[IR2];
		if (data) {
			data[0] = IR;
			data[1] = IR2;
			if (II->size >= 3) data[2] = readcb(cpu, addr+2);
			if (II->size >= 4) data[3] = readcb(cpu, addr+3);
		}
		if (size) *size = II->size;
		return II;
	} else if (IR == 0xCF) {
		// Expand 2
		IR2 = readcb(cpu, addr+1);
		II = &DebugCPUInstructions_CF[IR2];
		if (data) {
			data[0] = IR;
			data[1] = IR2;
			if (II->size >= 3) data[2] = readcb(cpu, addr+2);
			if (II->size >= 4) data[3] = readcb(cpu, addr+3);
		}
		if (size) *size = II->size;
		return II;
	} else {
		// No expand
		II = &DebugCPUInstructions_XX[IR];
		if (data) {
			data[0] = IR;
			if (II->size >= 2) data[1] = readcb(cpu, addr+1);
			if (II->size >= 3) data[2] = readcb(cpu, addr+2);
			if (II->size >= 4) data[3] = readcb(cpu, addr+3);
		}
		if (size) *size = II->size;
		return II;
	}
}

// %u = Unsigned 8-Bits
// %U = Unsigned 16-Bits
// %s = Signed 8-Bits
// %S = Signed 16-Bits
// %j = Relative jump (8-Bits)
// %J = Relative jump (16-Bits)
// %h = Relative expanded jump (8-Bits)
// %i = Interrupt

// Default operand number decode
int DefaultOperandNumberDec(char *sout, char type, uint32_t addr, int value)
{
	switch (type) {
		case 'u':	// %u = Unsigned 8-Bits
		case 'i':	// %i = Interrupt
			sprintf(sout, "$%02X", value);
			break;
		case 'U':	// %U = Unsigned 16-Bits
			sprintf(sout, "$%04X", value);
			break;
		case 's':	// %s = Unsigned 8-Bits
			if (value < 0) {
				sprintf(sout, "-$%02X", -value);
			} else {
				sprintf(sout, "$%02X", value);
			}
			break;
		case 'S':	// %S = Unsigned 16-Bits
			if (value < 0) {
				sprintf(sout, "-$%04X", -value);
			} else {
				sprintf(sout, "$%04X", value);
			}
			break;
		case 'j':	// %j = Relative jump (8-Bits)
		case 'J':	// %J = Relative jump (16-Bits)
		case 'h':	// %h = Relative expanded jump (8-Bits)
			if (value >= 0x8000) value = 0x8000 | (value & 0x7FFF);
			else value &= 0xFFFF;
			sprintf(sout, "@%04X", value);
			break;
		default:
			return 0;
	}
	return 1;
}

// Default operand number encode
int DefaultOperandNumberEnc(char *sin, char type, uint32_t addr, InstructionInfo *opcode, uint8_t *data, char *err)
{
	char ch, lastch = 0, negnum = 0;
	int val = 0, base = 10, absjmp = 0;
	while ((ch = *sin++) != 0) {
		switch (ch) {
		case '#': case '+':	// Ignored
			break;
		case '@':		// Absolute jump
			absjmp = 1;
			base = 16;
			break;
		case '-':		// Negative
			negnum = !negnum;
			break;
		case '$':		// Hexadecimal
			base = 16;
			break;
		case 'x': case 'X':
			if (lastch != '0') return 0;
			base = 16;
			break;
		case '0': case '1': case '2': case '3':	// Number
		case '4': case '5': case '6': case '7':
		case '8': case '9':
			val = (val * base) + (ch - '0');
			break;
		case 'a': case 'b': case 'c': case 'd':	// Hex number
		case 'e': case 'f':
			if (base != 16) {
				sprintf(err, "Error: Invalid character: '%c'\n", ch);
				return 0;
			}
			val = (val * base) + (ch - 'a') + 10;
			break;
		case 'A': case 'B': case 'C': case 'D': // Hex number
		case 'E': case 'F':
			if (base != 16) {
				sprintf(err, "Error: Invalid character: '%c'\n", ch);
				return 0;
			}
			val = (val * base) + (ch - 'A') + 10;
			break;
		default:				// Invalid
			sprintf(err, "Error: Invalid character: '%c'\n", ch);
			return 0;
		}
		lastch = ch;
	}
	if (negnum) val = -val;
	switch (type) {
		case 'u':	// %u = Unsigned 8-Bits
			if (val >= 256) {
				sprintf(err, "Error: Value out of range %i\nMust be between 0 and 255\n", val);
				return 0;
			}
			data[0] = val;
			break;
		case 'U':	// %U = Unsigned 16-Bits
			if (val >= 65536) {
				sprintf(err, "Error: Value out of range: %i\nMust be between 0 and 65535\n", val);
				return 0;
			}
			data[0] = val;
			data[1] = val >> 8;
			break;
		case 's':	// %s = Signed 8-Bits
			if ((val < -128) || (val >= 256)) {
				sprintf(err, "Error: Value out of range: %i\nMust be between -128 and 127\n", val);
				return 0;
			}
			data[0] = val;
			break;
		case 'S':	// %S = Signed 16-Bits
			if ((val < -32768) || (val >= 65536)) {
				sprintf(err, "Error: Value out of range: %i\nMust be between -32768 and 32767\n", val);
				return 0;
			}
			data[0] = val;
			data[1] = val >> 8;
			break;
		case 'j':	// %j = Relative jump (8-Bits)
			if (absjmp) {
				val = val - addr - 1;
			}
			if ((val < -128) || (val >= 128)) {
				sprintf(err, "Error: Value out of range: %i\nJump out of reach\n", val);
				return 0;
			}	
			data[0] = val;
			break;
		case 'J':	// %J = Relative jump (16-Bits)
			if (absjmp) {
				val = val - addr - 2;
			}
			data[0] = val;
			data[1] = val >> 8;
			break;
		case 'h':	// %h = Relative expanded jump (8-Bits)
			if (absjmp) {
				val = val - addr - 2;
			}
			if ((val < -128) || (val >= 128)) {
				sprintf(err, "Error: Value out of range: %i\nJump out of reach\n", val);
				return 0;
			}	
			data[0] = val;
			break;
		case 'i':	// %i = Interrupt
			if (val >= 128) {
				sprintf(err, "Error: Value out of range: %i\nMust be between 0 and 127\n", val);
				return 0;
			}
			data[0] = val << 1;
			break;
		default:
			return 0;
	}
	return 1;
}

// Default single opcode decoder
TSOpcDec DefaultSOpcDec = {
	DefaultOperandNumberDec,	// Operand number decode
	DefaultOperandNumberEnc,	// Operand number encode
	DebugCPUInstructions_Opcode,	// Opcode dictionary
	DebugCPUInstructions_Operand,	// Operand dictionary
	"",				// Opcode pre-text
	" ",				// Opcode post-text
	", "				// Operand separator
};

// Parse operand string (decoder)
// operand - full operand string
// addr    - address
// data    - input data
// pout    - output string
// spcdec  - decoder
static int ParseOperandStringDec(char *operand, uint32_t addr, uint8_t *data, char *pout, TSOpcDec *sopcdec)
{
	char ch, cod;
	char tmp[256];
	int val;

	*pout = 0;
	while ((ch = *operand) != 0) {
		if (ch == '%') {
			cod = operand[1];
			tmp[0] = 0;
			switch (cod) {
			case 'u':	// %u = Unsigned 8-Bits
				val = data[0];
				break;
			case 'U':	// %U = Unsigned 16-Bits
				val = data[1] * 256 + data[0];
				break;
			case 's':	// %s = Signed 8-Bits
				val = data[0];
				val = (val >= 0x80) ? val - 256 : val;
				break;
			case 'S':	// %S = Signed 16-Bits
				val = data[1] * 256 + data[0];
				val = (val >= 0x8000) ? val - 65536 : val;
				break;
			case 'j':	// %j = Relative jump (8-Bits)
				val = data[0];
				val = (val >= 0x80) ? val - 256 : val;
				val = addr + 1 + val;
				break;
			case 'J':	// %J = Relative jump (16-Bits)
				val = data[1] * 256 + data[0];
				val = (val >= 0x8000) ? val - 65536 : val;
				val = addr + 2 + val;
				break;
			case 'h':	// %h = Relative expanded jump (8-Bits)
				val = data[0];
				val = (val >= 0x80) ? val - 256 : val;
				val = addr + 2 + val;
				break;
			case 'i':	// %i = Interrupt
				val = data[0] >> 1;
				break;
			default:	// Invalid
				val = 0;
				break;
			}
			if (!sopcdec->on_opndec(tmp, cod, addr, val)) return 0;
			strcat(pout, tmp);
			pout += strlen(tmp);
			operand += 2;
			continue;
		}
		*pout++ = ch;
		*pout = 0;
		operand++;
	}
	return 1;
}

// Disassemble single opcode
int DisasmSingleOpcode(InstructionInfo *opcode, uint32_t addr, uint8_t *data, char *sout, TSOpcDec *sopcdec)
{
	char tmp[256];
	if ((!sout) || (!opcode)) return 0;
	if (!opcode->opc) {
		// Raw data
		strcpy(sout, ".DB ");
		if (opcode->size >= 1) { sprintf(tmp,  "$%02X", data[0]); strcat(sout, tmp); }
		if (opcode->size >= 2) { sprintf(tmp, ",$%02X", data[1]); strcat(sout, tmp); }
		if (opcode->size >= 3) { sprintf(tmp, ",$%02X", data[2]); strcat(sout, tmp); }
		if (opcode->size >= 4) { sprintf(tmp, ",$%02X", data[3]); strcat(sout, tmp); }
		return 1;
	} else {
		// Instruction
		strcpy(sout, sopcdec->opcode_pre);
		strcpy(sout, sopcdec->opcode_dict[opcode->opc]);
		if (opcode->opclen == 1) strcat(sout, "b");
		if (opcode->opclen == 2) strcat(sout, "w");
		if (opcode->p1) {
			strcat(sout, sopcdec->opcode_post);
			if (!ParseOperandStringDec(sopcdec->operand_dict[opcode->p1], addr, (uint8_t *)data + opcode->p1off, tmp, sopcdec)) return 0;
			strcat(sout, tmp);
		}
		if (opcode->p2) {
			strcat(sout, sopcdec->operand_sep);
			if (!ParseOperandStringDec(sopcdec->operand_dict[opcode->p2], addr, (uint8_t *)data + opcode->p2off, tmp, sopcdec)) return 0;
			strcat(sout, tmp);
		}
		return 1;
	}
}

// Parse operand string (encoder)
// operand - expected operand string
// addr    - address
// data    - output data
// pin     - operand input from assembly
// opcode  - expected opcode
// spcdec  - decoder
static int ParseOperandStringEnc(char *operand, uint32_t addr, uint8_t *data, char *pin, InstructionInfo *opcode, TSOpcDec *sopcdec, char *err)
{
	char ch, cod;
	char tok[2] = {0, 0}, tokfound;
	char tmp[256];

	while ((ch = *operand) != 0) {
		if (ch == '%') {
			cod = operand[1];	// code
			tok[0] = operand[2];	// next character
			pin = (char *)UpToToken(tmp, pin, tok, &tokfound) - 1;
			if (!sopcdec->on_opnenc(tmp, cod, addr, opcode, data, err)) return 0;
			operand += 2;
			continue;
		}

		// Check for differences
		if (toupper(ch) != toupper(*pin)) return 0;
		pin++;
		operand++;
	}
	if ((ch == 0) && (*pin == 0)) return 1;
	return 0;
}

// Assemble single opcode
InstructionInfo *AsmSingleOpcode(char *sin, uint32_t addr, uint8_t *data, TSOpcDec *sopcdec, char *err)
{
	char tmp[256], *ctmp = tmp;
	char opcname[256];
	char operand1[256], operand2[256];
	char operand3[256], operand4[256];
	InstructionInfo *opcode;
	int i;

	// Empty strings
	opcname[0] = 0;
	operand1[0] = 0;
	operand2[0] = 0;
	operand3[0] = 0;
	operand4[0] = 0;
	sprintf(err, "Error: Syntax error");

	// Remove comments and trim
	strcpy(ctmp, sin);
	RemoveComments(ctmp);
	ctmp = TrimStr(tmp);
	ctmp = UpToToken(opcname, ctmp, " \t", NULL);
	ctmp = UpToToken(operand1, ctmp, ",", NULL);
	RemoveChars(operand1, operand1, " \t");
	ctmp = UpToToken(operand2, ctmp, ",\n", NULL);
	RemoveChars(operand2, operand2, " \t");
	ctmp = UpToToken(operand3, ctmp, ",\n", NULL);
	RemoveChars(operand3, operand3, " \t");
	ctmp = UpToToken(operand4, ctmp, "\n", NULL);
	RemoveChars(operand4, operand4, " \t");

	// Data (Byte)
	if (!strcasecmp(opcname, ".DB")) {
		i = 0;
		if (!ParseOperandStringEnc("%u", 0, (uint8_t *)data+0, operand1, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		if (strlen(operand2)) {
			i = 1;
			if (!ParseOperandStringEnc("%u", 0, (uint8_t *)data+1, operand2, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		}
		if (strlen(operand3)) {
			i = 2;
			if (!ParseOperandStringEnc("%u", 0, (uint8_t *)data+2, operand3, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		}
		if (strlen(operand4)) {
			i = 3;
			if (!ParseOperandStringEnc("%u", 0, (uint8_t *)data+3, operand4, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		}
		return &DebugCPUInstructions_DX[i];
	}

	// Data (Word)
	if (!strcasecmp(opcname, ".DW")) {
		i = 4;
		if (!ParseOperandStringEnc("%U", 0, (uint8_t *)data+0, operand1, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		if (strlen(operand2)) {
			i = 5;
			if (!ParseOperandStringEnc("%U", 0, (uint8_t *)data+2, operand2, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		}
		if (strlen(operand3)) {
			i = 6;
			if (!ParseOperandStringEnc("%U", 0, (uint8_t *)data+4, operand3, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		}
		if (strlen(operand4)) {
			i = 7;
			if (!ParseOperandStringEnc("%U", 0, (uint8_t *)data+6, operand4, DebugCPUInstructions_DX, sopcdec, err)) return NULL;
		}
		return &DebugCPUInstructions_DX[i];
	}

	// Find opcode from the list
	for (i=0; i<256; i++) {
		// XX Opcode
		opcode = (InstructionInfo *)&DebugCPUInstructions_XX[i];
		strcpy(tmp, sopcdec->opcode_dict[opcode->opc]);
		if (opcode->opclen == 1) strcat(tmp, "b");
		if (opcode->opclen == 2) strcat(tmp, "w");
		if ((!strcasecmp(opcname, tmp)) || (!strcasecmp(opcname, sopcdec->opcode_dict[opcode->opc]))) {
			data[0] = i;
			if (opcode->p1 == 0) return opcode;
			if (ParseOperandStringEnc(sopcdec->operand_dict[opcode->p1], addr, (uint8_t *)data + opcode->p1off, operand1, opcode, sopcdec, err)) {
				if (opcode->p2 == 0) return opcode;
				if (ParseOperandStringEnc(sopcdec->operand_dict[opcode->p2], addr, (uint8_t *)data + opcode->p2off, operand2, opcode, sopcdec, err)) {
					return opcode;
				}
			}
		}

		// CE Opcode
		opcode = (InstructionInfo *)&DebugCPUInstructions_CE[i];
		strcpy(tmp, sopcdec->opcode_dict[opcode->opc]);
		if (opcode->opclen == 1) strcat(tmp, "b");
		if (opcode->opclen == 2) strcat(tmp, "w");
		if ((!strcasecmp(opcname, tmp)) || (!strcasecmp(opcname, sopcdec->opcode_dict[opcode->opc]))) {
			data[0] = 0xCE;
			data[1] = i;
			if (opcode->p1 == 0) return opcode;
			if (ParseOperandStringEnc(sopcdec->operand_dict[opcode->p1], addr, (uint8_t *)data + opcode->p1off, operand1, opcode, sopcdec, err)) {
				if (opcode->p2 == 0) return opcode;
				if (ParseOperandStringEnc(sopcdec->operand_dict[opcode->p2], addr, (uint8_t *)data + opcode->p2off, operand2, opcode, sopcdec, err)) {
					return opcode;
				}
			}
		}

		// CF Opcode
		opcode = (InstructionInfo *)&DebugCPUInstructions_CF[i];
		strcpy(tmp, sopcdec->opcode_dict[opcode->opc]);
		if (opcode->opclen == 1) strcat(tmp, "b");
		if (opcode->opclen == 2) strcat(tmp, "w");
		if ((!strcasecmp(opcname, tmp)) || (!strcasecmp(opcname, sopcdec->opcode_dict[opcode->opc]))) {
			data[0] = 0xCF;
			data[1] = i;
			if (opcode->p1 == 0) return opcode;
			if (ParseOperandStringEnc(sopcdec->operand_dict[opcode->p1], addr, (uint8_t *)data + opcode->p1off, operand1, opcode, sopcdec, err)) {
				if (opcode->p2 == 0) return opcode;
				if (ParseOperandStringEnc(sopcdec->operand_dict[opcode->p2], addr, (uint8_t *)data + opcode->p2off, operand2, opcode, sopcdec, err)) {
					return opcode;
				}
			}
		}
	}

	return NULL;
}
