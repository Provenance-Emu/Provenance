/***********************************************************************
    Copyright 2004, 2005 Alexander Valyalkin

    These sources is free software. You can redistribute it and/or
    modify it freely. You can use it with any free or commercial
    software.

    These sources is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY. Without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    You may contact the author by:
       e-mail:  valyala@gmail.com
*************************************************************************/
#ifndef BIG_INT_H
#define BIG_INT_H

#define BIG_INT_BUILD_DATE __DATE__ " " __TIME__
/* version of BIG_INT library */
#define BIG_INT_VERSION "0.0.50"

#include "memory_manager.h" /* custom malloc, realloc & free functions */

/*
    BIG_INT_API definition.
    
    If you want to build big_int dll under Windows,
    then define BIG_INT_BUILD_DLL (-DBIG_INT_BUILD_DLL)

    If you want to use existing big_int dll,
    then define BIG_INT_USE_DLL (-DBIG_INT_USE_DLL)
*/
#if defined(BIG_INT_BUILD_DLL)
#define BIG_INT_API __declspec(dllexport)
#elif defined(BIG_INT_USE_DLL)
#define BIG_INT_API __declspec(dllimport)
#else
#define BIG_INT_API extern
#endif

#include <stddef.h> /* for size_t & NULL declarations */

/*
    BIG_INT_DIGIT_SIZE could be defined in preprocessor definitions
    to 32, 16 or 8 bits.
    The default value for 32-bit processors is 32 bit (if not defined
    during compilation)
*/
#if !defined(BIG_INT_DIGIT_SIZE)
#define BIG_INT_DIGIT_SIZE 32
#endif

/*
    main types of big_int library
    big_int_word - base digit of big_int numbers
    big_int_dwrod - double digit.

    big_int_dwrod must be EXACTLY double length of big_int_word.
    Both types MUST BE unsigned.
*/
#if defined(_MSC_VER)
/*
    MSVC compilers are not ANSI C99 compliant.
    They have [__int64] instead of [uint64_t] type
*/
#if (BIG_INT_DIGIT_SIZE == 32)
typedef unsigned __int32 big_int_word;
typedef unsigned __int64 big_int_dword;
#elif (BIG_INT_DIGIT_SIZE == 16)
typedef unsigned __int16 big_int_word;
typedef unsigned __int32 big_int_dword;
#elif (BIG_INT_DIGIT_SIZE == 8)
typedef unsigned __int8 big_int_word;
typedef unsigned __int16 big_int_dword;
#else
#error wrong BIG_INT_DIGIT_SIZE. Expected 8, 16 or 32
#endif /* end of if (BIG_INT_DIGIT_SIZE == 32) */
#else
/*
    for ANSI C99 compliant comilers, which implement
    uint{N}_t types, where {N} can be 8, 16, 32, and 64
*/
#if defined(__FreeBSD__) && __FreeBSD__ < 5
/* FreeBSD 4 doesn't have stdint.h file */
#include <inttypes.h>
#else
#include <stdint.h>
#endif

#if (BIG_INT_DIGIT_SIZE == 32)
typedef uint32_t big_int_word;
typedef uint64_t big_int_dword;
#elif (BIG_INT_DIGIT_SIZE == 16)
typedef uint16_t big_int_word;
typedef uint32_t big_int_dword;
#elif (BIG_INT_DIGIT_SIZE == 8)
typedef uint8_t big_int_word;
typedef uint16_t big_int_dword;
#else
#error wrong BIG_INT_DIGIT_SIZE. Expected 8, 16 or 32
#endif /* end of BIG_INT_DIGIT_SIZE */
#endif /* end of if defined(_MSC_VER) */

#define BIG_INT_WORD_BYTES_CNT (sizeof(big_int_word))
#define BIG_INT_WORD_BITS_CNT (sizeof(big_int_word) * 8)
#define BIG_INT_LO_WORD(n) ((big_int_word) (n))
#define BIG_INT_HI_WORD(n) ((big_int_word) ((big_int_dword) (n) >> BIG_INT_WORD_BITS_CNT))
#define BIG_INT_MAX_WORD_NUM (BIG_INT_LO_WORD(~((big_int_word) 0)))

typedef enum {PLUS, MINUS} sign_type;

/* binary operators */
typedef enum {
    ADD, SUB, MUL, DIV, MOD, CMP,
    POW, GCD, OR,  XOR, AND, ANDNOT,
} bin_op_type;

typedef struct {
    big_int_word *num; /* pointer to the array, which contains number */
    sign_type sign; /* sign of the number */
    size_t len; /* length of the array num */
    size_t len_allocated; /* allocated memory for array num (len_allocated >= len) */
} big_int;

#endif
