/* FCEUXD SP - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 Sebastian Porst
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef CONDDEBUG_H
#define CONDDEBUG_H

#define TYPE_NO 0
#define TYPE_REG 1
#define TYPE_FLAG 2
#define TYPE_NUM 3
#define TYPE_ADDR 4
#define TYPE_PC_BANK 5
#define TYPE_DATA_BANK 6

#define OP_NO 0
#define OP_EQ 1
#define OP_NE 2
#define OP_GE 3
#define OP_LE 4
#define OP_G 5
#define OP_L 6
#define OP_PLUS 7
#define OP_MINUS 8
#define OP_MULT 9
#define OP_DIV 10
#define OP_OR 11
#define OP_AND 12

extern uint16 addressOfTheLastAccessedData;
//mbg merge 7/18/06 turned into sane c++
struct Condition
{
	Condition* lhs;
	Condition* rhs;

	unsigned int type1;
	unsigned int value1;

	unsigned int op;

	unsigned int type2;
	unsigned int value2;
};

void freeTree(Condition* c);
Condition* generateCondition(const char* str);

#endif
