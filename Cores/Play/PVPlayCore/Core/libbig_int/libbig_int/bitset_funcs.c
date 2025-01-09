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
#include "big_int.h"
#include "low_level_funcs.h" /* for low level or, and, xor functions */
#include "basic_funcs.h" /* for basic big_int functions */
#include "get_bit_length.h" /* for get_bit_length() function */
#include "bitset_funcs.h"

static int bin_op(const big_int *a, const big_int *b, size_t start_bit, bin_op_type op, big_int *answer);
static int lshift(const big_int *a, size_t n_bits, big_int *answer);
static int rshift(const big_int *a, size_t n_bits, big_int *answer);

/**
    Private function.
    Shifts [a] by [n_bits] bits to the left:
        answer = a << n_bits

    Returns error number:
        0 - no errors
        other - internal errors
*/
static int lshift(const big_int *a, size_t n_bits, big_int *answer)
{
    size_t i, n_digits;
    size_t len;
    big_int_word *num;

    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    if (!n_bits) {
        /* nothing to do */
        return 0;
    }

    n_digits = n_bits / BIG_INT_WORD_BITS_CNT;
    n_bits %= BIG_INT_WORD_BITS_CNT;

    /* allocate additional digits for the number */
    len = answer->len + n_digits + 1;
    if (big_int_realloc(answer, len)) {
        return 2;
    }
    num = answer->num;
    num[len - 1] = 0;
    answer->len = len;

    /* shift full digits to the left */
    if (n_digits > 0) {
        for (i = len - 2; i >= n_digits; i--) {
            num[i] = num[i - n_digits];
        }
        for (i = 0; i < n_digits; i++) {
            num[i] = 0;
        }
    }

    /* shift number by n_bits to the left */
    if (n_bits > 0) {
        for (i = len - 1; i > n_digits; i--) {
            num[i] <<= n_bits;
            num[i] |= num[i - 1] >> (BIG_INT_WORD_BITS_CNT - n_bits);
        }
        num[i] <<= n_bits;
    }

    big_int_clear_zeros(answer);

    return 0;
}

/**
    Private function.
    Shifts [a] by [n_bits] bits to the right:
        answer = a >> n_bits

    Returns error code:
        0 - no errors
        ohter - internal error
*/
static int rshift(const big_int *a, size_t n_bits, big_int *answer)
{
    size_t i, n_digits;
    big_int_word *num;

    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    if (!n_bits) {
        /* nothing to do */
        return 0;
    }

    num = answer->num;

    n_digits = n_bits / BIG_INT_WORD_BITS_CNT;
    n_bits %= BIG_INT_WORD_BITS_CNT;
    if (n_digits > 0) {
        for (i = n_digits; i < answer->len; i++) {
            num[i - n_digits] = num[i];
        }
        if (n_digits < answer->len) {
            answer->len -= n_digits;
        } else {
            num[0] = 0;
            answer->len = 1;
        }
    }

    if (n_bits > 0) {
        for (i = 0; i < answer->len - 1; i++) {
            num[i] >>= n_bits;
            num[i] |= num[i + 1] << (BIG_INT_WORD_BITS_CNT - n_bits);
        }
        num[i] >>= n_bits;
    }

    big_int_clear_zeros(answer);

    return 0;
}

/**
    Private function.
    Calculates
        answer = a op b, starting at position [start_bit], where op can be OR, AND, XOR, ANDNOT

    Returns error number:
        0 - no errors
        1 - unknown [op]
        other - internal errors
*/
static int bin_op(const big_int *a, const big_int *b, size_t start_bit, bin_op_type op, big_int *answer)
{
    int result = 0;
    big_int_word low_digit = 0;
    big_int_word *a_num;
    size_t bit_offset = start_bit % BIG_INT_WORD_BITS_CNT;
    size_t word_offset = start_bit / BIG_INT_WORD_BITS_CNT;
    size_t b_len;
    big_int *answer_copy = NULL;
    big_int *b_tmp = NULL;
    size_t answer_copy_len;

    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);

    /*
        a and b cannot points to the same address as answer,
        if start_bit != 0
    */
    if (start_bit && (a == answer || b == answer)) {
        answer_copy = big_int_create(1);
        if (answer_copy == NULL) {
            result = 2;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    // positive [start_bit]
    if (bit_offset) {
        /*
            store lower bits of [b] into [low_digit] and
            shift [b] to the right by (BIG_INT_WORD_BITS_CNT - [bit_offset]) bits
        */
        low_digit = b->num[0] << bit_offset;
        if (rshift(b, BIG_INT_WORD_BITS_CNT - bit_offset, (big_int *) b)) {
            result = 5;
            goto end;
        }
        ++word_offset;
    }
    a_num = a->num + word_offset;
    b_len = b->len + word_offset;

    /* allocate memory for [answer_copy] */
    answer_copy_len = a->len > b_len ? a->len : b_len;
    if (big_int_realloc(answer_copy, answer_copy_len)) {
        result = 6;
        goto end;
    }

    if (word_offset) {
        /* copy lower digits of [a] to [answer_copy] */
        if (a->num != answer_copy->num) {
            big_int_word *tmp = answer_copy->num;
            big_int_word *tmp_end = tmp + word_offset;
            big_int_word *tmp_a = a->num;
            big_int_word *tmp_a_end = tmp_a + a->len;
            do {
                *tmp++ = *tmp_a++;
            } while (tmp < tmp_end && tmp_a < tmp_a_end);
            /*
                digits of [a] are ends up, but we still need to fill
                first word_offset digits in [answer_copy] by zeros.
            */
            while (tmp < tmp_end) {
                *tmp++ = 0;
            }
        }
    }

    switch (op) {
        case OR:
            low_level_or(a_num, a_num + a->len - word_offset, b->num, b->num + b->len, answer_copy->num + word_offset);
            if (bit_offset) {
                *(answer_copy->num + word_offset - 1) |= low_digit;
            }
            break;

        case AND:
            low_level_and(a_num, a_num + a->len - word_offset, b->num, b->num + b->len, answer_copy->num + word_offset);
            if (bit_offset) {
                *(answer_copy->num + word_offset - 1) &= low_digit | ((1 << bit_offset) - 1);
            }
            break;

        case XOR:
            low_level_xor(a_num, a_num + a->len - word_offset, b->num, b->num + b->len, answer_copy->num + word_offset);
            if (bit_offset) {
                *(answer_copy->num + word_offset - 1) ^= low_digit;
            }
            break;

        case ANDNOT:
            low_level_andnot(a_num, a_num + a->len - word_offset, b->num, b->num + b->len, answer_copy->num + word_offset);
            if (bit_offset) {
                *(answer_copy->num + word_offset - 1) &= ~low_digit;
            }
            break;

        default:
            /* unknown operator */
            result = 1;
            goto end;
    }

    if (bit_offset) {
        /* restore [b] number */
        if (lshift(b, BIG_INT_WORD_BITS_CNT - bit_offset, (big_int *) b)) {
            result = 7;
            goto end;
        }
        *b->num |= low_digit >> bit_offset;
    }

    answer_copy->len = answer_copy_len;
    /* clear leading zeros in answer */
    big_int_clear_zeros(answer_copy);

    /* copy [answer_copy] into [answer] */
    if (big_int_copy(answer_copy, answer)) {
        result = 8;
        goto end;
    }

end:
    /* free allocated memory */
    if (answer_copy != answer) {
        big_int_destroy(answer_copy);
    }
    big_int_destroy(b_tmp);
    return result;
}

/**
    Calculates number of significant bits in the abs(a) and stores
    it to [len].
*/
void big_int_bit_length(const big_int *a, unsigned int *len)
{
    assert(a != NULL);
    assert(len != NULL);

    *len = BIG_INT_WORD_BITS_CNT * (a->len - 1) + get_bit_length(a->num[a->len - 1]);
}

/**
    Calculates number of 1-bits in the abs(a) and stores it to [len]
*/
void big_int_bit1_cnt(const big_int *a, unsigned int *cnt)
{
    big_int_word *num, *num_end;
    big_int_word tmp;
    unsigned int bits_cnt;

    assert(a != NULL);
    assert(cnt != NULL);

    num = a->num;
    num_end = num + a->len;
    bits_cnt = 0;
    while (num < num_end) {
        tmp = *num++;
        while (tmp) {
            if (tmp & 1) {
                bits_cnt++;
            }
            tmp >>= 1;
        }
    }

    *cnt = bits_cnt;
}

/**
    Calculates
        answer = a or b, starting at position [start_bit]

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_or(const big_int *a, const big_int *b, size_t start_bit, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);

    return bin_op(a, b, start_bit, OR, answer);
}

/**
    Calculates
        answer = a xor b, starting at position [start_bit]

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_xor(const big_int *a, const big_int *b, size_t start_bit, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);

    return bin_op(a, b, start_bit, XOR, answer);
}

/**
    Calculates
        answer = a and b, starting at position [start_bit]

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_and(const big_int *a, const big_int *b, size_t start_bit, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);

    return bin_op(a, b, start_bit, AND, answer);
}

/**
    Calculates
        answer = a andnot b, starting at position [start_bit]

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_andnot(const big_int *a, const big_int *b, size_t start_bit, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);

    return bin_op(a, b, start_bit, ANDNOT, answer);
}

/**
    Sets bit number n_bit in the [a].

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_set_bit(const big_int *a, size_t n_bit, big_int *answer)
{
    size_t n_word;
    size_t answer_len;

    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    n_word = n_bit / BIG_INT_WORD_BITS_CNT;
    n_word++;
    n_bit %= BIG_INT_WORD_BITS_CNT;

    if (big_int_realloc(answer, n_word)) {
        return 2;
    }

    answer_len = answer->len;
    while (answer_len < n_word) {
        answer->num[answer_len++] = 0;
    }

    answer->num[n_word - 1] |= (big_int_word) 1 << n_bit;
    answer->len = answer_len;

    return 0;
}

/**
    Clears bit number n_bit in the [a].

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_clr_bit(const big_int *a, size_t n_bit, big_int *answer)
{
    size_t n_word;

    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    n_word = n_bit / BIG_INT_WORD_BITS_CNT;
    n_bit %= BIG_INT_WORD_BITS_CNT;

    if (n_word < answer->len) {
        answer->num[n_word] &= ~((big_int_word) 1 << n_bit);
        big_int_clear_zeros(answer);
    }

    return 0;
}

/**
    Sets [bit_value] to:
        0, if bit [n_bit] in the [a] is 0
        1, if bit [n_bit] in the [a] is 1

    Returns error number:
        0 - no errors
*/
int big_int_test_bit(const big_int *a, size_t n_bit, int *bit_value)
{
    size_t n_word;

    assert(a != NULL);
    assert(bit_value != NULL);

    n_word = n_bit / BIG_INT_WORD_BITS_CNT;
    n_bit %= BIG_INT_WORD_BITS_CNT;

    if (n_word >= a->len) {
        /* bit [n_bit] is 0 */
        *bit_value = 0;
        return 0;
    }

    *bit_value = (a->num[n_word] >> n_bit) & 1;

    return 0;
}

/**
    Inverses bit number n_bit in the [a].

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_inv_bit(const big_int *a, size_t n_bit, big_int *answer)
{
    size_t n_word;
    size_t answer_len;

    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    n_word = n_bit / BIG_INT_WORD_BITS_CNT;
    n_bit %= BIG_INT_WORD_BITS_CNT;

    if (big_int_realloc(answer, n_word + 1)) {
        return 2;
    }

    answer_len = answer->len;
    while (answer_len <= n_word) {
        answer->num[answer_len++] = 0;
    }

    answer->num[n_word] ^= (big_int_word) 1 << n_bit;
    answer->len = answer_len;
    big_int_clear_zeros(answer);

    return 0;
}

/**
    Scans [a] for first 1-bit starting from [pos_start] bit.
    Sets [pos_found] to position of first 1-bit, starting from
    [pos_start].

    Returns error number:
        0 - no errors
        1 - can't find 1-bit
*/
int big_int_scan1_bit(const big_int *a, size_t pos_start, size_t *pos_found)
{
    big_int_word *num, *num_end;
    big_int_word tmp;

    assert(a != NULL);
    assert(pos_found != NULL);

    num = a->num + pos_start / BIG_INT_WORD_BITS_CNT;
    num_end = a->num + a->len;
    if (num >= num_end) {
        /* can't find 1-bit */
        return 1;
    }

    tmp = *num++;
    tmp >>= pos_start % BIG_INT_WORD_BITS_CNT;
    if (!tmp) {
        pos_start = (num - a->num) * BIG_INT_WORD_BITS_CNT;
        while (num < num_end && !*num) {
            num++;
            pos_start += BIG_INT_WORD_BITS_CNT;
        }
        if (num == num_end) {
            /* can't find 1-bit */
            return 1;
        }
        tmp = *num;
    }
    while (!(tmp & 1)) {
        pos_start++;
        tmp >>= 1;
    }
    /* position of 1-bit was found */
    *pos_found = pos_start;

    return 0;
}

/**
    Scans [a] for first 0-bit starting from [pos_start] bit.
    Sets [pos_found] to position of first 1-bit, starting from
    [pos_start].

    Returns error number:
        0 - no errors
*/
int big_int_scan0_bit(const big_int *a, size_t pos_start, size_t *pos_found)
{
    big_int_word *num, *num_end;
    big_int_word tmp;
    size_t i;

    assert(a != NULL);
    assert(pos_found != NULL);

    num = a->num + pos_start / BIG_INT_WORD_BITS_CNT;
    num_end = a->num + a->len;
    if (num >= num_end) {
        /* current bit [pos_start] is 0 */
        *pos_found = pos_start;
        return 0;
    }

    i = pos_start % BIG_INT_WORD_BITS_CNT;
    while (num < num_end) {
        tmp = *num++;
        tmp >>= i;
        i = BIG_INT_WORD_BITS_CNT - i;
        while (i && (tmp & 1)) {
            i--;
            pos_start++;
            tmp >>= 1;
        }
        if (i) {
            /* 0-bit found */
            break;
        }
        i = 0;
    }

    /* position of 0-bit was found */
    *pos_found = pos_start;

    return 0;
}

/**
    Calculates Hamming distance between [a] and [b].
        distance = big_int_bit1_cnt(big_int_xor(a, b, 0));

    Retruns error number:
        0 - no errors
        other - internal error
*/
int big_int_hamming_distance(const big_int *a, const big_int *b, unsigned int *distance)
{
    big_int *tmp = NULL;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(distance != NULL);

    tmp = big_int_create(1);
    if (tmp == NULL) {
        result = 1;
        goto end;
    }

    if (big_int_xor(a, b, 0, tmp)) {
        result = 2;
        goto end;
    }
    big_int_bit1_cnt(tmp, distance);

end:
    /* free allocated memory */
    big_int_destroy(tmp);

    return 0;
}

/**
    Subtract part or number [a], starting from [start_bit], with length [bit_len].
        If [is_invert] != 0, then [answer] will be inverted,
        i.e. 1-bits become 0-bits and 0-bits become 1-bits

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_subint(const big_int *a, size_t start_bit, size_t bit_len,
                   int is_invert, big_int *answer)
{
    big_int_word *num, *num_end, *answer_num;
    size_t answer_len;

    assert(a != NULL);
    assert(answer != NULL);

    num = a->num + start_bit / BIG_INT_WORD_BITS_CNT;
    if (num >= a->num + a->len) {
        if (!is_invert) {
            /* [answer] is 0 */
            if (big_int_from_int(0, answer)) {
                return 1;
            }
        } else {
            /* answer is -11...11 with length of big_len bits */
            answer_len = bit_len / BIG_INT_WORD_BITS_CNT;
            if (bit_len % BIG_INT_WORD_BITS_CNT) answer_len++;
            if (big_int_realloc(answer, answer_len)) {
                return 2;
            }
            num = answer->num;
            num_end = num + answer_len;
            while (num < num_end) {
                *num++ = BIG_INT_MAX_WORD_NUM;
            }
            bit_len %= BIG_INT_WORD_BITS_CNT;
            if (bit_len) {
                *(--num) >>= BIG_INT_WORD_BITS_CNT - bit_len;
            }
            answer->len = answer_len;
            answer->sign = MINUS;
        }
        return 0;
    }
    start_bit %= BIG_INT_WORD_BITS_CNT;
    num_end = num + (bit_len + start_bit) / BIG_INT_WORD_BITS_CNT;
    num_end++;

    /* copy digits from [a] to [answer] */
    if (!is_invert) {
        if (num_end > a->num + a->len) {
            num_end = a->num + a->len;
        }
        /* allocate memory for answer */
        answer_len = num_end - num;
        if (big_int_realloc(answer, answer_len)) {
            return 3;
        }
        /* copy words from [a] to [answer] */
        answer_num = answer->num;
        while (num < num_end) {
            *answer_num++ = *num++;
        }
        answer->sign = a->sign;
    } else {
        /* invert digits */
        /* allocate memory for answer */
        answer_len = num_end - num;
        if (big_int_realloc(answer, answer_len)) {
            return 4;
        }
        answer_num = answer->num;
        /* copy words from [a] to [answer] */
        if (num_end > a->num + a->len) {
            num_end = a->num + a->len;
        }
        while (num < num_end) {
            *answer_num++ = ~(*num++);
        }
        /* assign ~0 to higher digits of [answer] */
        num_end = answer_num + (answer_len - a->len);
        while (answer_num < num_end) {
            *answer_num++ = BIG_INT_MAX_WORD_NUM;
        }
        answer->sign = (a->sign == PLUS) ? MINUS : PLUS;
    }
    answer->len = answer_len;

    if (rshift(answer, start_bit, answer)) {
        return 5;
    }
    if (answer->len > bit_len / BIG_INT_WORD_BITS_CNT) {
        answer->len = (bit_len / BIG_INT_WORD_BITS_CNT) + 1;
        answer->num[answer->len - 1] &= (1 << (bit_len % BIG_INT_WORD_BITS_CNT)) - 1;
        big_int_clear_zeros(answer);
    }

    return 0;
}

/**
    Shifts [a] by [n_bits] bits to the right:
        answer = a >> n_bits

    Returns error code:
        0 - no errors
        ohter - internal error
*/
int big_int_rshift(const big_int *a, int n_bits, big_int *answer)
{
    return (n_bits < 0) ? lshift(a, -n_bits, answer) : rshift(a, n_bits, answer);
}

/**
    Shifts [a] by [n_bits] bits to the left:
        answer = a << n_bits

    Returns error number:
        0 - no errors
        other - internal errors
*/
int big_int_lshift(const big_int *a, int n_bits, big_int *answer)
{
    return (n_bits < 0) ? rshift(a, -n_bits, answer) : lshift(a, n_bits, answer);
}

/**
    answer = random number with [n_bits] bits length

    [rand_func] - pointer to function, which must
    generate unsigned integers. For example, it can be
    rand() from stdlib.h

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_rand(big_int_rnd_fp rand_func, size_t n_bits, big_int *answer)
{
    size_t n_words, i;
    big_int_word tmp;
    big_int_word *num, *num_end;

    assert(rand_func != NULL);
    assert(answer != NULL); 

    n_words = (n_bits / BIG_INT_WORD_BITS_CNT) + 1;
    n_bits %= BIG_INT_WORD_BITS_CNT;

    /* allocate memory for [answer] */
    if (big_int_realloc(answer, n_words)) {
        return 1;
    }
    answer->len = n_words;

    /* generate random bitset with [n_words] words length */
    num = answer->num;
    num_end = num + n_words;
    while (num < num_end) {
        tmp = 0;
        i = BIG_INT_WORD_BYTES_CNT;
        while (i--) {
            tmp <<= 8;
            tmp |= (unsigned char) rand_func();
        }
        *num++ = tmp;
    }

    /* clear higer bits in the higer digit */
    *(--num) &= (1 << n_bits) - 1;

    big_int_clear_zeros(answer);
    answer->sign = PLUS; // change answer sign

    return 0;
}
