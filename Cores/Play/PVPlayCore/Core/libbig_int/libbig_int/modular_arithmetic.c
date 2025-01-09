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
#include "basic_funcs.h" /* for basic big_int functions */
#include "number_theory.h" /* for GCD function */
#include "bitset_funcs.h"
#include "modular_arithmetic.h"

static int bin_op_mod(const big_int *a, const big_int *b,
                      const big_int *modulus, bin_op_type op, big_int *answer);

/**
    Private function.

    Calculates answer = a (op) b (mod modulus), where op - one
    of the operators: ADD, SUB, MUL, DIV

    Returns number of error:
        0 - no errors
        1 - division by zero (modulus cannot be zero)
        2 - GCD(b, modulus) != 1 (cannot find inv(b) for DIV operation)
*/
static int bin_op_mod(const big_int *a, const big_int *b,
                      const big_int *modulus, bin_op_type op, big_int *answer)
{
    big_int *answer_copy = NULL;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    if (modulus == answer || a == answer) {
        answer_copy = big_int_dup(answer);
        if (answer_copy == NULL) {
            result = 3;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    switch (op) {
        case ADD:
            result = big_int_add(a, b, answer_copy);
            break;

        case SUB:
            result = big_int_sub(a, b, answer_copy);
            break;

        case MUL:
            result = big_int_mul(a, b, answer_copy);
            break;

        case DIV:
            /*
                answer = a / b = a * inv(b) (mod modulus)
                if GCD(b, modulus) != 1, then cannot find answer.
            */
            result = big_int_invmod(b, modulus, answer_copy);
            switch (result) {
                case 0: break; /* inv(b) was found */
                case 1: /* division by zero. Modulus cannot be zero */
                    result = 1;
                    goto end;
                    break;
                case 2: /* GCD(b, modulus) != 1 */
                    result = 2;
                    goto end;
                    break;
                default: break;
            }
            if (result == 0) {
                result = big_int_mul(answer_copy, a, answer_copy);
            }
            break;

        default: /* unknown operator */
            result = 4;
            break;
    }
    if (result) {
        result = 5;
        goto end;
    }

    result = big_int_absmod(answer_copy, modulus, answer);
    if (result) {
        result = (result == 1) ? 1 : 5;
        goto end;
    }

    /*
        free allocated memory
    */
end:
    if (answer_copy != answer) {
        big_int_destroy(answer_copy);
    }

    return result;
}

/**
    Calculate:
        answer = pow(a, b) (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero. (modulus cannot be zero)
        2 - GCD(a, modulus) != 1, when [b] is negative
*/
int big_int_powmod(const big_int *a, const big_int *b, const big_int *modulus, big_int *answer)
{
    big_int_word *bb, *bb_start;
    size_t n_bits;
    big_int_word tmp;
    big_int *tmp1 = NULL, *tmp2 = NULL, *a_copy = NULL;
    big_int *tmp3; /* specialliy is not assigned to NULL :) */
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    /* division by zero check */
    if (modulus->len == 1 && modulus->num[0] == 0) {
        result = 1;
        goto end;
    }

    /* normalize [a] by mod [modulus] and store it to [a_copy] */
    a_copy = big_int_create(modulus->len);
    if (a_copy == NULL) {
        result = 3;
        goto end;
    }
    if (big_int_absmod(a, modulus, a_copy)) {
        result = 4;
        goto end;
    }

    /* check simple cases ([a] = 0 or [a] = 1) */
    if (a_copy->len == 1 && (a_copy->num[0] == 0 || a_copy->num[0] == 1)) {
        if (big_int_copy(a_copy, answer)) {
            result = 5;
            goto end;
        }
        goto end;
    }

    /* allocate memory for temporary buffers [tmp1] & [tmp2] */
    tmp1 = big_int_create(modulus->len);
    tmp2 = big_int_create(modulus->len);
    if (tmp1 == NULL || tmp2 == NULL) {
        result = 6;
        goto end;
    }

    /* main loop */
    if (big_int_from_int(1, tmp1)) {
        result = 7;
        goto end;
    }
    bb_start = b->num;
    bb = bb_start + b->len;
    tmp = *(--bb);
    n_bits = BIG_INT_WORD_BITS_CNT;
    while (n_bits && !(tmp >> (BIG_INT_WORD_BITS_CNT - 1))) {
        tmp <<= 1;
        n_bits--;
    }
    while (1) {
        while (n_bits--) {
            /* calculate tmp2 = tmp1 ^ 2 */
            if (big_int_sqrmod(tmp1, modulus, tmp2)) {
                result = 8;
                goto end;
            }
            if (tmp >> (BIG_INT_WORD_BITS_CNT - 1)) {
                /* calculate tmp1 = tmp2 * a_copy */
                if (big_int_mulmod(tmp2, a_copy, modulus, tmp1)) {
                    result = 9;
                    goto end;
                }
            } else {
                /* exchange [tmp1] <=> [tmp2] */
                tmp3 = tmp1;
                tmp1 = tmp2;
                tmp2 = tmp3;
            }
            tmp <<= 1;
        }
        if (bb <= bb_start) {
            /* stop calculation */
            break;
        }
        /* go to the next digit of [b] */
        n_bits = BIG_INT_WORD_BITS_CNT;
        tmp = *(--bb);
    }

    /*
        if [b] is negative, then try to find inverse number of
        [answer] by mod [modulus]
    */
    if (b->sign == MINUS) {
        result = big_int_invmod(tmp1, modulus, tmp2);
        switch (result) {
            case 0: /* there is no errors */
                break;
            case 1: /* division by zero error */
                break;
            case 2: /* GCD(answer_copy, modulus) != 1, so it is impossible to find inverse number */
                break;
            default: /* internal error */
                result = 10;
                break;
        }
        if (result) {
            goto end;
        }
    } else {
        /* exchange [tmp1] <=> [tmp2] */
        tmp3 = tmp1;
        tmp1 = tmp2;
        tmp2 = tmp3;
    }

    /* answer is in the [tmp2] */
    if (big_int_copy(tmp2, answer)) {
        result = 11;
        goto end;
    }

end:
    /* free allocated memory */
    big_int_destroy(tmp2);
    big_int_destroy(tmp1);
    big_int_destroy(a_copy);

    return result;
}

/**
    Tries to find [answer]:
        a * answer = 1 (mod modulus)

    It is possible only if GCD(a, modulus) = 1

    Returns error number:
        0 - no errors
        1 - division by zero. ([a] and [modulus] cannot be zero)
        2 - GCD(a, modulus) != 1
        other - internal error
*/
int big_int_invmod(const big_int *a, const big_int *modulus, big_int *answer)
{
    big_int *gcd = NULL, *answer_copy = NULL;
    int result = 0;

    assert(a != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    if (modulus->len == 1 && modulus->num[0] == 0) {
        /* division by zero */
        result = 1;
        goto end;
    }

    gcd = big_int_create(modulus->len);
    if (gcd == NULL) {
        result = 3;
        goto end;
    }

    if (answer == modulus) {
        answer_copy = big_int_create(modulus->len);
        if (answer_copy == NULL) {
            result = 4;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    /* normalize [a] by mod [modulus] */
    if (big_int_absmod(a, modulus, answer_copy)) {
        result = 5;
        goto end;
    }

    result = big_int_gcd_extended(answer_copy, modulus, gcd, answer_copy, NULL);
    if (result) {
        result = (result == 1) ? 1 : 6;
        goto end;
    }
    if (gcd->len > 1 || gcd->num[0] != 1) {
        /* GCD(a, modulus) != 1, so it is impossible to find inverse number */
        result = 2;
        goto end;
    }

    /* normalize [answer] by mod [modulus] */
    if (big_int_absmod(answer_copy, modulus, answer_copy)) {
        result = 7;
        goto end;
    }

    if (big_int_copy(answer_copy, answer)) {
        result = 8;
        goto end;
    }

end:
    /* free allocated memory */
    if (answer_copy != answer) {
        big_int_destroy(answer_copy);
    }
    big_int_destroy(gcd);

    return result;
}

/**
    Calculates:
        answer = a + b (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero. ([modulus] cannot be zero)
        other - internal error
*/
int big_int_addmod(const big_int *a, const big_int *b, const big_int *modulus, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    return bin_op_mod(a, b, modulus, ADD, answer);
}

/**
    Calculates:
        answer = a - b (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero. ([modulus] cannot be zero)
        other - internal error
*/
int big_int_submod(const big_int *a, const big_int *b, const big_int *modulus, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    return bin_op_mod(a, b, modulus, SUB, answer);
}

/**
    Calculates:
        answer = a * b (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero. ([modulus] cannot be zero)
        other - internal error
*/
int big_int_mulmod(const big_int *a, const big_int *b, const big_int *modulus, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    return bin_op_mod(a, b, modulus, MUL, answer);
}

/**
    Calculates:
        answer = a / b = a * inv(b) (mod modulus)

    Return error number:
        0 - no errors
        1 - division by zero (modulus cannot be zero)
        2 - GCD(b, modulus) != 1 (cannot find inv(b))
        other - internal error
*/
int big_int_divmod(const big_int *a, const big_int *b, const big_int *modulus, big_int *answer)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    return bin_op_mod(a, b, modulus, DIV, answer);
}

/**
    Calculates:
        answer = a * a (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero (modulus cannot be zero)
        other - internal error
*/
int big_int_sqrmod(const big_int *a, const big_int *modulus, big_int *answer)
{
    assert(a != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    return bin_op_mod(a, a, modulus, MUL, answer);
}

/**
    Compares [a] with [b] (mod modulus).
    
    Sets cmp_flag to:
        -1, if a < b (mod modulus)
        0, if a == b (mod modulus)
        1, if a > b (mod modulus)

    Example:
        if a=1, b=6 and modulus=5, then cmp_flag=0, because 6 mod 5 = 1
        if a=100, b=3 and modulus=5, then cmp_flag=-1, because 100 mod 5 = 0 < 3
        if a=3, b=5 and modulus=5, then cmp_flag=1, because 5 mod 5 = 0 < 3

    Returns error number:
        0 - no errors
        1 - division by zero (modulus cannot be zero)
        other - internal error
*/
int big_int_cmpmod(const big_int *a, const big_int *b, const big_int *modulus, int *cmp_flag)
{
    big_int *a_copy = NULL, *b_copy = NULL;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(modulus != NULL);
    assert(cmp_flag != NULL);

    a_copy = big_int_dup(a);
    if (a_copy == NULL) {
        result = 3;
        goto end;
    }
    b_copy = big_int_dup(b);
    if (b_copy == NULL) {
        result = 4;
        goto end;
    }

    result = big_int_absmod(a_copy, modulus, a_copy);
    if (result) {
        /*
            if result = 1, i.e. division by zero (modulus = 0),
            then don't touch [result]
        */
        result = (result == 1) ? 1 : 5;
        goto end;
    }
    result = big_int_absmod(b_copy, modulus, b_copy);
    if (result) {
        result = (result == 1) ? 1 : 6;
        goto end;
    }

    big_int_cmp_abs(a_copy, b_copy, cmp_flag);

end:
    big_int_destroy(b_copy);
    big_int_destroy(a_copy);

    return result;
}

/**
    Calculates:
        answer = a (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero (modulus cannot be zero)
        other - internal error
*/
int big_int_absmod(const big_int *a, const big_int *modulus, big_int *answer)
{
    big_int *answer_copy = NULL;
    int result = 0;

    assert(a != NULL);
    assert(modulus != NULL);
    assert(answer != NULL);

    if (modulus == answer) {
        answer_copy = big_int_dup(answer);
        if (answer_copy == NULL) {
            result = 3;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    result = big_int_mod(a, modulus, answer_copy);
    if (result) {
        result = (result == 1) ? 1 : 4;
        goto end;
    }

    /* if [answer_copy] is negative, then add abs(modulus) to it */
    if (answer_copy->sign == MINUS) {
        switch (modulus->sign) {
            case PLUS:
                result = big_int_add(answer_copy, modulus, answer_copy);
                break;
            case MINUS:
                result = big_int_sub(answer_copy, modulus, answer_copy);
                break;
        }
        if (result) {
            result = 5;
            goto end;
        }
    }

    if (big_int_copy(answer_copy, answer)) {
        result = 6;
        goto end;
    }

end:
    /* free allocated memory */
    if (answer_copy != answer) {
        big_int_destroy(answer_copy);
    }
    return result;
}

/**
    Calculates factorial of [a] (mod modulus):
        answer = a! (mod modulus)

    Returns error number:
        0 - no errors
        1 - division by zero (modulus cannot be zero)
        3 - [a] cannot be negative
        ohter - internal error
*/
int big_int_factmod(const big_int *a, const big_int *modulus, big_int *answer)
{
    big_int *a_copy = NULL, *answer_copy = NULL;
    int cmp_flag;
    int result = 0;

    assert(a != NULL);
    assert(answer != NULL);

    if (modulus->len == 1 && modulus->num[0] == 0) {
        /* division by zero */
        result = 1;
        goto end;
    }

    if (a->sign == MINUS) {
        /* [a] cannot be negative */
        result = 3;
        goto end;
    }

    /* check trivial case, when modulus =< a, so answer = 0 */
    big_int_cmp_abs(a, modulus, &cmp_flag);
    if (cmp_flag > 0) {
        /* [answer] = 0 */
        if (big_int_from_int(0, answer)) {
            result = 4;
            goto end;
        }
        goto end;
    }

    a_copy = big_int_dup(a);
    if (a_copy == NULL) {
        result = 5;
        goto end;
    }

    if (modulus == answer) {
        answer_copy = big_int_create(1);
        if (answer_copy == NULL) {
            result = 6;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    if (big_int_from_int(1, answer_copy)) {
        result = 7;
        goto end;
    }

    while (a_copy->len > 1 || a_copy->num[0] > 1) {
        if (big_int_mulmod(answer_copy, a_copy, modulus, answer_copy)) {
            result = 8;
            goto end;
        }
        if (answer->len == 1 && answer->num[0] == 0) {
            /* [answer] is 0 already, so break the loop */
            break;
        }
        if (big_int_dec(a_copy, a_copy)) {
            result = 9;
            goto end;
        }
    }
    if (big_int_copy(answer_copy, answer)) {
        result = 10;
        goto end;
    }

end:
    /* free allocated memory */
    if (answer_copy != answer) {
        big_int_destroy(answer_copy);
    }
    big_int_destroy(a_copy);

    return result;
}
