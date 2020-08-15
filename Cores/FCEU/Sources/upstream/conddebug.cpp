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

/*
* The parser was heavily inspired by the following two websites:

* http://www.cs.utsa.edu/~wagner/CS5363/rdparse.html
* http://www.engr.mun.ca/~theo/Misc/exp_parsing.htm
*
* Grammar of the parser:
*
* P         -> Connect
* Connect   -> Compare {('||' | '&&') Compare}
* Compare   -> Sum {('==' | '!=' | '<=' | '>=' | '<' | '>') Sum}
* Sum       -> Product {('+' | '-') Product}
* Product   -> Primitive {('*' | '/') Primitive}
* Primitive -> Number | Address | Register | Flag | PC Bank | '(' Connect ')'
* Number    -> '#' [1-9A-F]*
* Address   -> '$' [1-9A-F]* | '$' '[' Connect ']'
* Register  -> 'A' | 'X' | 'Y' | 'P'
* Flag      -> 'N' | 'C' | 'Z' | 'I' | 'B' | 'V'
* PC Bank   -> 'K'
* Data Bank   -> 'T'
*/

#include "types.h"
#include "conddebug.h"
#include "utils/memory.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <cctype>

// hack: this address is used by 'T' condition
uint16 addressOfTheLastAccessedData = 0;
// Next non-whitespace character in string
char next;

int ishex(char c)
{
	return isdigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

void scan(const char** str)
{
	do
	{
		next = **str;
		(*str)++;
	} while (isspace(next));
}

// Frees a condition and all of it's sub conditions
void freeTree(Condition* c)
{
	if (c->lhs) freeTree(c->lhs);
	if (c->rhs) freeTree(c->rhs);

	free(c);
}

// Generic function to handle all infix operators but the last one in the precedence hierarchy. : '(' E ')'
Condition* InfixOperator(const char** str, Condition(*nextPart(const char**)), int(*operators)(const char**))
{
	Condition* t = nextPart(str);
	Condition* t1;
	Condition* mid;
	int op;

	while ((op = operators(str)))
	{
		scan(str);

		t1 = nextPart(str);

		if (t1 == 0)
		{
			if(t)
				freeTree(t);
			return 0;
		}

		mid = (Condition*)FCEU_dmalloc(sizeof(Condition));
		if (!mid)
			return NULL;
		memset(mid, 0, sizeof(Condition));

		mid->lhs = t;
		mid->rhs = t1;
		mid->op = op;

		t = mid;
	}

	return t;
}

// Generic handler for two-character operators
int TwoCharOperator(const char** str, char c1, char c2, int op)
{
	if (next == c1 && **str == c2)
	{
		scan(str);
		return op;
	}
	else
	{
		return 0;
	}
}

// Determines if a character is a flag
int isFlag(char c)
{
	return c == 'N' || c == 'I' || c == 'C' || c == 'V' || c == 'Z' || c == 'B' || c == 'U' || c == 'D';
}

// Determines if a character is a register
int isRegister(char c)
{
	return c == 'A' || c == 'X' || c == 'Y' || c == 'P';
}

// Determines if a character is for PC bank
int isPCBank(char c)
{
	return c == 'K';
}

// Determines if a character is for Data bank
int isDataBank(char c)
{
	return c == 'T';
}

// Reads a hexadecimal number from str
int getNumber(unsigned int* number, const char** str)
{
//	char buffer[5];

	if (sscanf(*str, "%X", number) == EOF || *number > 0xFFFF)
	{
		return 0;
	}

// Older, inferior version which doesn't work with leading zeros
//	sprintf(buffer, "%X", *number);
//	*str += strlen(buffer);
	while (ishex(**str)) (*str)++;
	scan(str);

	return 1;
}

Condition* Connect(const char** str);

// Handles the following part of the grammar: '(' E ')'
Condition* Parentheses(const char** str, Condition* c, char openPar, char closePar)
{
	if (next == openPar)
	{
		scan(str);

		c->lhs = Connect(str);

		if (!c) return 0;

		if (next == closePar)
		{
			scan(str);
			return c;
		}
		else
		{
			return 0;
		}
	}

	return 0;
}

/*
* Check for primitives
* Flags, Registers, Numbers, Addresses and parentheses
*/
Condition* Primitive(const char** str, Condition* c)
{
	if (isFlag(next)) /* Flags */
	{
		if (c->type1 == TYPE_NO)
		{
			c->type1 = TYPE_FLAG;
			c->value1 = next;
		}
		else
		{
			c->type2 = TYPE_FLAG;
			c->value2 = next;
		}

		scan(str);

		return c;
	}
	else if (isRegister(next)) /* Registers */
	{
		if (c->type1 == TYPE_NO)
		{
			c->type1 = TYPE_REG;
			c->value1 = next;
		}
		else
		{
			c->type2 = TYPE_REG;
			c->value2 = next;
		}

		scan(str);

		return c;
	}
	else if (isPCBank(next)) /* PC Bank */
	{
		if (c->type1 == TYPE_NO)
		{
			c->type1 = TYPE_PC_BANK;
			c->value1 = next;
		}
		else
		{
			c->type2 = TYPE_PC_BANK;
			c->value2 = next;
		}

		scan(str);

		return c;
	}
	else if (isDataBank(next)) /* Data Bank */
	{
		if (c->type1 == TYPE_NO)
		{
			c->type1 = TYPE_DATA_BANK;
			c->value1 = next;
		}
		else
		{
			c->type2 = TYPE_DATA_BANK;
			c->value2 = next;
		}

		scan(str);

		return c;
	}
	else if (next == '#') /* Numbers */
	{
		unsigned int number = 0;
		if (!getNumber(&number, str))
		{
			return 0;
		}

		if (c->type1 == TYPE_NO)
		{
			c->type1 = TYPE_NUM;
			c->value1 = number;
		}
		else
		{
			c->type2 = TYPE_NUM;
			c->value2 = number;
		}

		return c;
	}
	else if (next == '$') /* Addresses */
	{
		if ((**str >= '0' && **str <= '9') || (**str >= 'A' && **str <= 'F')) /* Constant addresses */
		{
			unsigned int number = 0;
			if (!getNumber(&number, str))
			{
				return 0;
			}

			if (c->type1 == TYPE_NO)
			{
				c->type1 = TYPE_ADDR;
				c->value1 = number;
			}
			else
			{
				c->type2 = TYPE_ADDR;
				c->value2 = number;
			}

			return c;
		}
		else if (**str == '[') /* Dynamic addresses */
		{
			scan(str);
			Parentheses(str, c, '[', ']');

			if (c->type1 == TYPE_NO)
			{
				c->type1 = TYPE_ADDR;
			}
			else
			{
				c->type2 = TYPE_ADDR;
			}

			return c;
		}
		else
		{
			return 0;
		}
	}
	else if (next == '(')
	{
		return Parentheses(str, c, '(', ')');
	}

	return 0;
}

/* Handle * and / operators */
Condition* Term(const char** str)
{
	Condition* t;
	Condition* t1;
	Condition* mid;

    t = (Condition*)FCEU_dmalloc(sizeof(Condition));
    if (!t)
        return NULL;

	memset(t, 0, sizeof(Condition));

	if (!Primitive(str, t))
	{
		freeTree(t);
		return 0;
	}

	while (next == '*' || next == '/')
	{
		int op = next == '*' ? OP_MULT : OP_DIV;

		scan(str);

		if (!(t1 = (Condition*)FCEU_dmalloc(sizeof(Condition))))
            return NULL;

		memset(t1, 0, sizeof(Condition));

		if (!Primitive(str, t1))
		{
			freeTree(t);
			freeTree(t1);
			return 0;
		}

		if (!(mid = (Condition*)FCEU_dmalloc(sizeof(Condition))))
            return NULL;

		memset(mid, 0, sizeof(Condition));

		mid->lhs = t;
		mid->rhs = t1;
		mid->op = op;

		t = mid;
	}

	return t;
}

/* Check for + and - operators */
int SumOperators(const char** str)
{
	switch (next)
	{
		case '+': return OP_PLUS;
		case '-': return OP_MINUS;
		default: return OP_NO;
	}
}

/* Handle + and - operators */
Condition* Sum(const char** str)
{
	return InfixOperator(str, Term, SumOperators);
}

/* Check for <=, =>, ==, !=, > and < operators */
int CompareOperators(const char** str)
{
	int val = TwoCharOperator(str, '=', '=', OP_EQ);
	if (val) return val;

	val = TwoCharOperator(str, '!', '=', OP_NE);
	if (val) return val;

	val = TwoCharOperator(str, '>', '=', OP_GE);
	if (val) return val;

	val = TwoCharOperator(str, '<', '=', OP_LE);
	if (val) return val;

	val = next == '>' ? OP_G : 0;
	if (val) return val;

	val = next == '<' ? OP_L : 0;
	if (val) return val;

	return OP_NO;
}

/* Handle <=, =>, ==, !=, > and < operators */
Condition* Compare(const char** str)
{
	return InfixOperator(str, Sum, CompareOperators);
}

/* Check for || or && operators */
int ConnectOperators(const char** str)
{
	int val = TwoCharOperator(str, '|', '|', OP_OR);
	if(val) return val;

	val = TwoCharOperator(str, '&', '&', OP_AND);
	if(val) return val;

	return OP_NO;
}

/* Handle || and && operators */
Condition* Connect(const char** str)
{
	return InfixOperator(str, Compare, ConnectOperators);
}

/* Root of the parser generator */
Condition* generateCondition(const char* str)
{
	Condition* c;

	scan(&str);
	c = Connect(&str);

	if (!c || next != 0) return 0;
	else return c;
}
