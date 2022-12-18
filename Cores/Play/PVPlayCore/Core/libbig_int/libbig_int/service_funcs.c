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
#include <assert.h> /* for assert() */
#include <string.h> /* for memcpy */
#include "big_int.h"
#include "low_level_funcs.h" /* for low level add, sub, etc. funcs */
#include "service_funcs.h"

/*
    Digits chartable, which used to convert numbers,
    represented from strings to internal format and back.

    Fromat of each element in this table:
        first byte: ASCII representation of the digit
        second byte: number value of the digit
        third byte: NULL

    There are 36 avaible digits:
        - [0-9] - usual decimal digits
        - [a-z] and [A-Z] - digits with number value [10 - 36]
*/
static const char *digits[] = {
    "0\x00", "1\x01", "2\x02", "3\x03", "4\x04", "5\x05",
    "6\x06", "7\x07", "8\x08", "9\x09", "a\x0a", "b\x0b",
    "c\x0c", "d\x0d", "e\x0e", "f\x0f", "g\x10", "h\x11",
    "i\x12", "j\x13", "k\x14", "l\x15", "m\x16", "n\x17",
    "o\x18", "p\x19", "q\x1a", "r\x1b", "s\x1c", "t\x1d",
    "u\x1e", "v\x1f", "w\x20", "x\x21", "y\x22", "z\x23",
    "A\x0a", "B\x0b", "C\x0c", "D\x0d", "E\x0e", "F\x0f",
    "G\x10", "H\x11", "I\x12", "J\x13", "K\x14", "L\x15",
    "M\x16", "N\x17", "O\x18", "P\x19", "Q\x1a", "R\x1b",
    "S\x1c", "T\x1d", "U\x1e", "V\x1f", "W\x20", "X\x21",
    "Y\x22", "Z\x23",
};

/*
    Table y = log2(x) / 8 for x = [0..36];
    Values rounded to greater value.

    This table is used in big_int_from_str() function to calculate
    the length of number in internal format.
*/
static const double log2_table[] = {
    0.000, 0.000, 0.126, 0.199, 0.251, 0.291, 0.324, 0.352,
    0.376, 0.397, 0.416, 0.433, 0.449, 0.464, 0.477, 0.489,
    0.501, 0.512, 0.522, 0.532, 0.541, 0.550, 0.558, 0.566,
    0.574, 0.581, 0.589, 0.595, 0.602, 0.608, 0.614, 0.620,
    0.626, 0.632, 0.637, 0.642, 0.647,
};

/*
    Table y = 8 / log2(x) for x = [0..36];
    Values rounded to greater value.

    This table is used in big_int_to_str() function to calculate
    the length of result string.
*/
static const double log2_inv_table[] = {
    0.000, 0.000, 8.001, 5.048, 4.001, 3.446, 3.096, 2.851,
    2.668, 2.525, 2.409, 2.314, 2.233, 2.163, 2.102, 2.049,
    2.001, 1.958, 1.919, 1.884, 1.852, 1.822, 1.795, 1.770,
    1.746, 1.724, 1.703, 1.683, 1.665, 1.648, 1.631, 1.616,
    1.601, 1.587, 1.573, 1.561, 1.548,
};

/* macros, which adjusts [len] in big_int_create() & big_int_realloc() functions */
#define LEN_ADJUST do { int i = 0; --len; while (++i && (len >>= 1)); len = (i < sizeof(size_t) * 8) ? (1 << i) : ~(size_t)0; } while(0)

/* macros, which tests possible integer overflow for [len] */
#define LEN_OVERFLOW_CHECK(ret_arg) if ((~(size_t)0) / BIG_INT_WORD_BYTES_CNT < len) { return (ret_arg); }

/* returns version of big_int library */
const char * big_int_version() { return BIG_INT_VERSION; }

/* returns build date of big_int library */
const char * big_int_build_date() { return BIG_INT_BUILD_DATE; }

/*
    Creates a new big_int number with [len] preallocated digits.

    Returns pointer to created number. Initial value of number is 0.
    On error returns NULL pointer.
*/
big_int * big_int_create(size_t len)
{
    big_int *a;
    big_int_word *num;

    if (!len) {
        len = 1;
    }
    LEN_ADJUST;
    LEN_OVERFLOW_CHECK(NULL);
    num = (big_int_word *) bi_malloc(BIG_INT_WORD_BYTES_CNT * len);

    if (num == NULL) {
        return NULL;
    }

    /* set created number to zero */
    num[0] = 0;

    /* allocate memory for big_int structure, then fill it */
    a = (big_int *) bi_malloc(sizeof(big_int));
    if (a == NULL) {
        bi_free(num);
        return NULL;
    }
    a->num = num; /* pointer to internal representation of number */
    a->len = 1; /* number of [big_int_word] digits */
    a->len_allocated = len; /* number of preallocated digits */
    a->sign = PLUS; /* sign of the number */

    return a;
}

/**
    frees allocated memory for number [a]. Pointer to [a] can be NULL
*/
void big_int_destroy(big_int *a)
{
    if (a == NULL) {
        return;
    }

    bi_free(a->num);
    bi_free(a);
}

/**
    Reallocates memory for number [a] to [len] digits.

    Returns error number:
        0 - no errors
        1 - memory reallocation error
*/
int big_int_realloc(big_int *a, size_t len)
{
    assert(a != NULL);

    if (a->len_allocated < len) {
        LEN_ADJUST;
        LEN_OVERFLOW_CHECK(1);
        a->num = (big_int_word *) bi_realloc(a->num, BIG_INT_WORD_BYTES_CNT * len);
        if (a->num == NULL) {
            /* memory reallocation error */
            return 1;
        }
        a->len_allocated = len;
    }
    return 0;
}

/**
    Copy [src] number into [dst].

    Returns error number:
        0 - no errors
        1 - memory reallocation error
*/
int big_int_copy(const big_int *src, big_int *dst)
{
    assert(src != NULL);
    assert(dst != NULL);

    if (dst == src) {
        /* nothing to do */
        return 0;
    }
    /* allocate memory for [src] number in [dst] */
    if (big_int_realloc(dst, src->len)) {
        /* error when reallocating memory */
        return 1;
    }

    /* copy [src] number and all its contents (length and sign) */
    memcpy(dst->num, src->num, BIG_INT_WORD_BYTES_CNT * src->len);
    dst->len = src->len;
    dst->sign = src->sign;

    return 0;
}

/**
    Returns duplicate of number [a].
    It is need to call dig_int_destroy() for this duplicate
    On error returns NULL
*/
big_int * big_int_dup(const big_int *a)
{
    big_int *new_num;

    assert(a != NULL);

    new_num = big_int_create(a->len);
    if (new_num == NULL) {
        return NULL;
    }
    memcpy(new_num->num, a->num, BIG_INT_WORD_BYTES_CNT * a->len);
    new_num->len = a->len;
    new_num->sign = a->sign;

    return new_num;
}

/**
    Removes higher zero digits form [a]
*/
void big_int_clear_zeros(big_int *a)
{
    big_int_word *num, *num_end;

    assert(a != NULL);

    num = a->num;
    num_end = a->num + a->len - 1;

    /* try to find highest non-zero digit in the number */
    while (num_end > num && !*num_end) {
        num_end--;
    }
    num_end++;

    a->len = num_end - num; /* set the real length of number */
    if (a->len == 1 && !*num) {
        /* if number is zero, then its sign is always PLUS */
        a->sign = PLUS;
    }
}

/**
    Converts number from string representation in [base] base
    to [big_int] format.
    Saves result to [answer].

    Returns error number:
        0 - no errors
        1 - wrong [base] base. It can be from 2 to 36 inclusive
        2 - string [s] contains wrong character for chosen base
        3 - length of the string must be greater than 0
        other - internal error
*/
int big_int_from_str(const big_int_str *s, unsigned int base, big_int *answer)
{
    size_t str_length, len;
    big_int_word *a, *a_end, *aa;
    char *str, *str_end;
    big_int_word digit, digit_norm;
    big_int_dword tmp1, base_norm;
    unsigned int i, base_pow;
    static big_int_word digit_table[256];
    static int is_not_digit_table = 1;
    const char **tmp, **tmp_end;

    assert(s != NULL);
    assert(answer != NULL);

    /* [digit_table] initialization */
    if (is_not_digit_table) {
        memset(digit_table, 0xff, BIG_INT_WORD_BYTES_CNT * 256);

        tmp = digits;
        tmp_end = tmp + 62;
        do {
            digit_table[(unsigned char) (*tmp)[0]] = (*tmp)[1];
        } while (++tmp < tmp_end);

        /* set flag that [digit_table] initialization is done */
        is_not_digit_table = 0;
    }

    if (base < 2 || base > 36) {
        /* wrong [base] base */
        return 1;
    }

    str = s->str;
    str_length = s->len;
    /* find the sign of the number */
    answer->sign = PLUS;
    switch (*str) {
    case '-' :
        answer->sign = MINUS;
        /* I know: break skipped  :) */
    case '+' :
        /* skip the sign character */
        if (str_length) {
            str_length--;
        }
        str++;
        break;
    }

    if (!str_length) {
        /* length of the string must be greater than 0 */
        return 3;
    }

    /*
        calculate [base_norm] and [base_pow], such as:
            - base^base_pow < BIG_INT_MAX_WORD_NUM
    */
    base_norm = base;
    base_pow = 0;
    do {
        base_norm *= base;
        ++base_pow;
    } while (!(base_norm >> BIG_INT_WORD_BITS_CNT));
    base_norm /= base;

    /* calculate memory volume needed to save converted number */
    len = (size_t) (log2_table[base] * str_length) + 1; /* memory volume in bytes */
    len = (len + BIG_INT_WORD_BYTES_CNT - 1) / BIG_INT_WORD_BYTES_CNT; /* number of [big_int_word] digits */
    len++; /* additional digit for calculations */

    if (big_int_realloc(answer, len)) {
        return 4;
    }
    memset(answer->num, 0, BIG_INT_WORD_BYTES_CNT * len);

    /* try to convert number into [big_int] format */
    a = answer->num;
    a_end = a + len - 1;
    str_end = str + str_length;
    do {
        /*
            calculate [digit_norm] - signle digit of the number [a]
        */
        i = base_pow;
        digit_norm = 0;
        do {
            digit = digit_table[(unsigned char) *str++];
            if (digit >= base) {
                /* there is wrong character for the chosen base in the string */
                return 2;
            }
            digit_norm *= base;
            digit_norm += digit;
        } while (--i && str < str_end);
        /*
            [i] can be non-zero at the end of [str].
            So, we need to adjust [base_norm] by [i] times dividing it by [base]
        */
        while (i--) {
            base_norm /= base;
        }
        tmp1 = 0;
        aa = a;
        do {
            tmp1 += base_norm * (*aa);
            *aa++ = BIG_INT_LO_WORD(tmp1);
            tmp1 >>= BIG_INT_WORD_BITS_CNT;
        } while (aa < a_end);
        low_level_add(a, a_end, &digit_norm, (&digit_norm) + 1, a);
    } while (str < str_end);

    answer->len = len;
    big_int_clear_zeros(answer);

    return 0;
}

/**
    Converts number [a] into string representation by base [base].

    Returns error number:
        0 - no errors
        1 - wrong [base]. It can be from 2 to 36 inclusive
        other - internal error
*/
int big_int_to_str(const big_int *a, unsigned int base, big_int_str *s)
{
    size_t len;
    char *str, *str_end, *ss;
    big_int_word *num, *num_end, *num1;
    big_int_dword tmp;
    big_int_dword base_norm;
    unsigned int i, base_pow;
    big_int *a_copy = NULL;

    assert(a != NULL);
    assert(s != NULL);

    if (base < 2 || base > 36) {
        return 1;
    }

    /*
        calculate [base_norm] and [base_pow], such as:
            1) base_norm < BIG_INT_MAX_WORD_NUM
            2) base_norm = base^base_pow, where base_pow - most biggest number
    */
    base_norm = base;
    base_pow = 0;
    do {
        base_norm *= base;
        ++base_pow;
    } while (!(base_norm >> BIG_INT_WORD_BITS_CNT));
    base_norm /= base;

    /*
        calculate string length and allocate memory for it
        additional 3 bytes needed for:
            1) round [len] to the upper integer
            2) possible '-' sign at the beginning
            3) end-of-string '\0' at the end
    */
    len = (size_t) (log2_inv_table[base] * a->len * BIG_INT_WORD_BYTES_CNT) + 3;
    if (big_int_str_realloc(s, len)) {
        return 2;
    }
    str = s->str;
    str_end = str + len;

    if (a->sign == MINUS) {
        *str++ = '-';
    }

    a_copy = big_int_dup(a);
    if (a_copy == NULL) {
        return 3;
    }

    num = a_copy->num;
    num_end = num + a_copy->len;
    do {
        tmp = 0;
        /* skip leading zeros in number */
        while (!*(--num_end) && num_end > num);
        /* divide number [a] by base_norm and calculate remainder in [tmp] */
        num1 = ++num_end;
        do {
            tmp <<= BIG_INT_WORD_BITS_CNT;
            tmp |= *(--num1);
            *num1 = (big_int_word) (tmp / base_norm);
            tmp %= base_norm;
        } while (num1 > num);
        /* convert ramainder [tmp] into char digits */
        i = base_pow;
        do {
            *(--str_end) = *digits[BIG_INT_LO_WORD(tmp) % base];
            tmp /= base;
        } while (--i && str_end > str);
    } while (str_end > str);

    big_int_destroy(a_copy);

    /* delete zeros at the begining of string */
    ss = str;
    str_end = s->str + len;
    while (ss < str_end && *ss == '0') {
        ss++;
    }
    if (ss < str_end) {
        len = str_end - ss;
        memmove(str, ss, len);
    } else {
        /* string contains only zeros. Leave one */
        len = 1;
    }

    str[len] = '\0';
    if (a->sign == MINUS) {
        len++;
    }

    s->len = len;
    return 0;
}

/**
    Converts string representation of the number from base [base_from]
    into base [base_to]

    Returns error number:
        0 - no errors
        1 - wrong [base_from]. It can be from 2 to 36 inclusive
        2 - wrong [base_to]. It can be from 2 to 36 inclusive
        3 - unexpected character in [src] for base [base_from]
        4 - length of the string must be greater than 0
        other - internal error
*/
int big_int_base_convert(const big_int_str *src, big_int_str *dst,
                         unsigned int base_from, unsigned int base_to)
{
    big_int *tmp = NULL;
    int result = 0;

    assert(src != NULL);
    assert(dst != NULL);

    if (base_from < 2 || base_from > 36) {
        result = 1;
        goto end;
    }
    if (base_to < 2 || base_to > 36) {
        result = 2;
        goto end;
    }

    tmp = big_int_create(1);
    if (tmp == NULL) {
        result = 5;
        goto end;
    }

    switch (big_int_from_str(src, base_from, tmp)) {
        case 0: break;
        case 2: /* unexpected character in the [src] string */
            result = 3;
            goto end;
        case 3: /* length of the string must be greater than 0 */
            result = 4;
            goto end;
        default:
            result = 6;
            goto end;
    }

    if (big_int_to_str(tmp, base_to, dst)) {
        result = 5;
        goto end;
    }

end:
    /* free allocated memory */
    big_int_destroy(tmp);

    return result;
}

/**
    Assigns number [a] to [value]

    Returns error number:
        0 - no errors
        1 - [a] overflows [value]
*/
int big_int_to_int(const big_int *a, int *value)
{
    unsigned int num;
    size_t i, len;
    int result = 0;

    assert(a != NULL);
    assert(value != NULL);

    if (sizeof(num) < a->len * BIG_INT_WORD_BYTES_CNT) {
        /* integer overflow */
        result = 1;
    }

    len = sizeof(num) / BIG_INT_WORD_BYTES_CNT;
    if (len > 1) {
        num = 0;
        len = (len < a->len) ? len : a->len;
        for (i = 0; i < len; i++) {
            num |= a->num[i] << (i * BIG_INT_WORD_BITS_CNT);
        }
    } else {
        num = a->num[0];
    }
    if (num >> (sizeof(num) * 8 - 1)) {
        /* integer overflow */
        result = 1;
    }
    *value = (a->sign == MINUS) ? -((int) num) : num;

    return result;
}

/**
    Assigns [value] to number [a].

    Returns error number:
        0 - no errors
        1 - memory reallocating error
*/
int big_int_from_int(int value, big_int *a)
{
    size_t len;
    size_t n_bits = BIG_INT_WORD_BITS_CNT;

    assert(a != NULL);

    /* determine the sign of [value] */
    if (value < 0) {
        a->sign = MINUS;
        value = -value;
    } else {
        a->sign = PLUS;
    }

    /* calculate number of digits, needed to store [value] in [a] */
    len = sizeof(value) / BIG_INT_WORD_BYTES_CNT;
    if (len > 1) {
        /* more than one digit. Allocate (len+1) digits for number */
        if (big_int_realloc(a, len + 1)) {
            return 1;
        }
        len = 0;
        while (value) {
            a->num[len++] = (big_int_word) value;
            value >>= n_bits;
        }
        if (len == 0) {
            len = 1;
            a->num[0] = 0;
        }
        a->len = len;
    } else {
        /* one digit */
        a->num[0] = (big_int_word) value;
        a->len = 1;
    }

    return 0;
}

/**
    Serializes number [a] into string [s] as bytestream.
    It is useful for storing or transferring numbers for
    future use.
    If is_sign != 0, then put the sign of number into the last
    char of [s], else do not save sign into [s].

    Returns error number:
        0 - no errors
        1 - reallocating memory error
*/
int big_int_serialize(const big_int *a, int is_sign, big_int_str *s)
{
    big_int_word *num, *num_end;
    big_int_word tmp;
    unsigned char *str;
    size_t str_len, i;

    assert(a != NULL);
    assert(s != NULL);
    assert(sizeof(char) == 1);

    /* allocate memory for string needed to serialize number with sign */
    str_len = a->len * BIG_INT_WORD_BYTES_CNT + 1;
    if (big_int_str_realloc(s, str_len)) {
        return 1;
    }

    num = a->num;
    num_end = num + a->len;
    str = (unsigned char *) s->str;
    while (num < num_end) {
        tmp = *num++;
        i = BIG_INT_WORD_BYTES_CNT;
        while (i--) {
            *str++ = (unsigned char) tmp;
            tmp >>= 8;
        }
    }
    /* delete trailing zeros */
    str--;
    while (str > (unsigned char *) s->str && !*str) {
        str--;
    }
    /* save the sign of number [a] */
    if (is_sign) {
        *(++str) = a->sign == PLUS ? 0x01 : 0xff;
    }
    /* end of bytestream */
    *(++str) = '\0';
    /* calculate length of serialized string */
    s->len = (char *) str - s->str;

    return 0;
}

/**
    Unserializes bytestream from string [s], serialized by
    big_int_serialize(), to number [a].
    If is_sign != 0, then interpret last char of [s] as sign (0x01 - plus, 0xff - minus).
    Else sign = PLUS

    Returns error number:
        0 - no errors
        1 - bytestream is too short.
        2 - wrong first byte (sign). It must be 0x01 (plus) or 0xff (minus)
        3 - reallocating memory error
*/
int big_int_unserialize(const big_int_str *s, int is_sign, big_int *a)
{
    unsigned char *str;
    big_int_word *num, *num_end;
    big_int_word tmp;
    size_t a_len, i, s_len;

    assert(s != NULL);
    assert(a != NULL);
    assert(sizeof(char) == 1);

    s_len = is_sign ? s->len - 1 : s->len;
    if (s_len < 1) {
        /* bytestream is too short */
        return 1;
    }

    str = (unsigned char *) s->str;

    /* restore the number */
    a_len = (s_len + BIG_INT_WORD_BYTES_CNT - 1) / BIG_INT_WORD_BYTES_CNT;
    if (big_int_realloc(a, a_len)) {
        return 3;
    }
    a->len = a_len;
    num = a->num;
    num_end = num + a->len;
    num_end--;
    while (num < num_end) {
        tmp = 0;
        i = BIG_INT_WORD_BYTES_CNT;
        str += i;
        while (i--) {
            tmp <<= 8;
            tmp |= *(--str);
        }
        str += BIG_INT_WORD_BYTES_CNT;
        *num++ = tmp;
    }

    tmp = 0;
    i = s_len - (a_len - 1) * BIG_INT_WORD_BYTES_CNT;
    str += i;

    /* restore the sign */
    if (is_sign) {
        /* determine the sign of number */
        switch (*str) {
            case 0x01: a->sign = PLUS; break;
            case 0xff: a->sign = MINUS; break;
            default: return 2; /* cannot recognize sign byte */
        }
    } else {
        a->sign = PLUS;
    }

    /* init last word */
    while (i--) {
        tmp <<= 8;
        tmp |= *(--str);
    }
    *num++ = tmp;

    big_int_clear_zeros(a); /* strip leading zeros in [a] */

    return 0;
}
