/* A Bison parser, made by GNU Bison 3.5.1.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2020 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* Undocumented macros, especially those whose name start with YY_,
   are private implementation details.  Do not rely on them.  */

#ifndef YY_YY_Y_TAB_H_INCLUDED
# define YY_YY_Y_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token type.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    NUMBER = 258,
    ERR = 259,
    EQUATE = 260,
    CART_METHOD = 261,
    CPU_METHOD = 262,
    RIOT_METHOD = 263,
    TIA_METHOD = 264,
    FUNCTION = 265,
    LOG_OR = 266,
    LOG_AND = 267,
    LOG_NOT = 268,
    SHR = 269,
    SHL = 270,
    GTE = 271,
    LTE = 272,
    NE = 273,
    EQ = 274,
    DEREF = 275,
    UMINUS = 276
  };
#endif
/* Tokens.  */
#define NUMBER 258
#define ERR 259
#define EQUATE 260
#define CART_METHOD 261
#define CPU_METHOD 262
#define RIOT_METHOD 263
#define TIA_METHOD 264
#define FUNCTION 265
#define LOG_OR 266
#define LOG_AND 267
#define LOG_NOT 268
#define SHR 269
#define SHL 270
#define GTE 271
#define LTE 272
#define NE 273
#define EQ 274
#define DEREF 275
#define UMINUS 276

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 28 "stella.y"

	int val;
	char* Equate;
	CartMethod cartMethod;
	CpuMethod cpuMethod;
	RiotMethod riotMethod;
	TiaMethod tiaMethod;
	Expression* exp;
	char* DefinedFunction;

#line 110 "y.tab.h"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_Y_TAB_H_INCLUDED  */
