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
#include "get_bit_length.h" /* for get_bit_length() function */
#include "low_level_funcs.h" /* for low level add, sub, etc. functions */
#include "bitset_funcs.h" /* for rshift, lshift, etc. */
#include "basic_funcs.h"

/*
    private functions
*/
static int incdec(const big_int *a, bin_op_type op, big_int *answer);
static int addsub(const big_int *a, const big_int *b, bin_op_type op, big_int *answer);

/**
    Private function.

    Increments / decrements number [a].
    If [op] == ADD, then increments number [a]
    if [op] == SUB, then decrements number [a]

    Returns error number:
        0 - no errors
        other - internal error
*/
static int incdec(const big_int *a, bin_op_type op, big_int *answer)
{
    big_int_word one = 1;

    assert(a != NULL);
    assert(answer != NULL);
    assert(op == ADD || op == SUB);

    /* copy [a] to [answer] */
    if (big_int_copy(a, answer)) {
        return 1;
    }

    if (answer->sign == PLUS && op == ADD ||
        answer->sign == MINUS && op == SUB) {
        /*
            Add 1 to [answer]. For this allocate one digit and
            set it to zero before calling low_level_add() function.
        */
        if (big_int_realloc(answer, answer->len + 1)) {
            return 2;
        }
        answer->num[answer->len] = 0;
        low_level_add(answer->num, answer->num + answer->len, &one, (&one) + 1, answer->num);
        answer->len++;
    } else {
        /*
            Subtract 1 from [answer]. If [answer] == 0, then
            set it to -1, else call low_level_sub() function.
        */
        if (answer->len == 1 && answer->num[0] == 0) {
            answer->num[0] = 1;
            answer->sign = MINUS;
        } else {
            low_level_sub(answer->num, answer->num + answer->len, &one, (&one) + 1, answer->num);
        }
    }
    big_int_clear_zeros(answer);

    return 0;
}

/**
    Private function.

    If [op] == ADD, then answer = a + b
    if [op] == SUB, then answer = a - b

    Returns error number:
        0 - no errors
        other - internal error
*/
static int addsub(const big_int *a, const big_int *b, bin_op_type op, big_int *answer)
{
    size_t answer_len;
    sign_type a_sign, b_sign, tmp_sign;
    int cmp_flag;
    big_int *answer_copy = NULL;
    const big_int *tmp;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);
    assert(op == ADD || op == SUB);

    /* copy signs of [a] and [b] to [a_sign] and [b_sign] */
    a_sign = a->sign;
    b_sign = b->sign;
    if (op == SUB) {
        /* invert [b] sign */
        switch (b_sign) {
            case PLUS: b_sign = MINUS; break;
            case MINUS: b_sign = PLUS; break;
        }
    }

    /* exchange [a] with [b] if abs(b) > abs(a) */
    big_int_cmp_abs(a, b, &cmp_flag);
    if (cmp_flag < 0) {
        tmp = a;
        a = b;
        b = tmp;
        /* exchange of signs */
        tmp_sign = a_sign;
        a_sign = b_sign;
        b_sign = tmp_sign;
    }

    /*
        If [b] and [answer] points to the same address,
        then do copy of [answer] (restriction of low_level_add()
        and low_level_sub() functions).
    */
    if (b == answer) {
        answer_copy = big_int_create(1);
        if (answer_copy == NULL) {
            result = 1;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    answer_len = a->len;
    if (a_sign == b_sign) {
        /*
            allocate additional block for [answer]
            (restriction of low_level_add() function)
        */
        answer_len++;
    }
    if (big_int_realloc(answer_copy, answer_len)) {
        result = 2;
        goto end;
    }

    if (a_sign == b_sign) {
        low_level_add(a->num, a->num + a->len, b->num, b->num + b->len, answer_copy->num);
    } else {
        low_level_sub(a->num, a->num + a->len, b->num, b->num + b->len, answer_copy->num);
    }

    answer_copy->len = answer_len;
    answer_copy->sign = a_sign;
    big_int_clear_zeros(answer_copy); /* clear zeros from the higher digits */

    if (big_int_copy(answer_copy, answer)) {
        result = 3;
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
    Calculates
        answer = c + a * b

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_muladd(const big_int *a, const big_int *b, const big_int *c, big_int *answer)
{
    big_int *answer_copy = NULL;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(c != NULL);
    assert(answer != NULL);

    if (c == answer) {
        answer_copy = big_int_create(1);
        if (answer_copy == NULL) {
            result = 1;
            goto end;
        }
    } else {
        answer_copy = answer;
    }

    if (big_int_mul(a, b, answer_copy)) {
        result = 2;
        goto end;
    }
    if (big_int_add(answer_copy, c, answer_copy)) {
        result = 3;
        goto end;
    }
    if (big_int_copy(answer_copy, answer)) {
        result = 4;
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
    Multiplies [a] by [b]:
        answer = a * b

    Returns error number:
        0 - no errors
        ohter - internal error
*/
int big_int_mul(const big_int *a, const big_int *b, big_int *answer)
{
    size_t answer_len;
    big_int *answer_copy = NULL;
    const big_int *tmp;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(answer != NULL);

    /* if (a < b) then exchange them for faster multiplying */
    if (a->len < b->len || a->len == 1) {
        tmp = a;
        a = b;
        b = tmp;
    }

    /* check special cases, when [b] is equal to 0 or 1 */
    if (b->len == 1) {
        if (b->num[0] == 0) {
            if (big_int_from_int(0, answer)) {
                result = 1;
                goto end;
            }
            goto end;
        }
        if (b->num[0] == 1) {
            /* [b] = 1, so answer equals to [a] */
            if (big_int_copy(a, answer)) {
                result = 2;
                goto end;
            }
            answer->sign = (a->sign == b->sign) ? PLUS : MINUS;
            goto end;
        }
    }

    /*
        If [a] or [b] points to the address [answer], then do copy of
        [answer] (restriction of low_level_mul() function)
    */
    if (a == answer || b == answer) {
        answer_copy = big_int_create(1);
        if (answer_copy == NULL) {
            result = 3;
            goto end;
        }
    } else {
        answer_copy = answer;
    }
    /* determine the sign of [answer] */
    answer_copy->sign = (a->sign == b->sign) ? PLUS : MINUS;

    /* allocate memory for [answer_copy] */
    answer_len = a->len + b->len;
    if (big_int_realloc(answer_copy, answer_len)) {
        result = 4;
        goto end;
    }
    answer_copy->len = answer_len;

    if (a == b) {
        /*
            If a == b, i.e. answer += a*a, then
            call low_level_sqr(), which is faster then low_level_mul()
        */
        low_level_sqr(a->num, a->num + a->len, answer_copy->num);
    } else {
        low_level_mul(a->num, a->num + a->len, b->num, b->num + b->len, answer_copy->num);
    }

    big_int_clear_zeros(answer_copy);

    if (big_int_copy(answer_copy, answer)) {
        result = 5;
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
    Adds [a] and [b]:
        answer = a + b

    Returns error number:
        0 - no errors
        ohter - internal error
*/
int big_int_add(const big_int *a, const big_int *b, big_int *answer)
{
    assert(a != NULL);
    assert(a != NULL);
    assert(answer != NULL);

    return addsub(a, b, ADD, answer);
}

/**
    Subtracts [a] by [b]:
        answer = a - b

    Returns error number:
        0 - no errors
        ohter - internal error
*/
int big_int_sub(const big_int *a, const big_int *b, big_int *answer)
{
    assert(a != NULL);
    assert(a != NULL);
    assert(answer != NULL);

    return addsub(a, b, SUB, answer);
}

/**
    Compares modules of [a] and [b].

    Sets [cmp_flag]:
        - if abs(a) > abs(b), then [cmp_flag] = 1
        - if abs(a) = abs(b), then [cmp_flag] = 0
        - if abs(a) < abs(b), then [cmp_flag] = -1
*/
void big_int_cmp_abs(const big_int *a, const big_int *b, int *cmp_flag)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(cmp_flag != NULL);

    /* clear zeros from the higher digits */
    big_int_clear_zeros((big_int *) a);
    big_int_clear_zeros((big_int *) b);

    if (a->len > b->len) {
        *cmp_flag = 1;
    } else if (a->len < b->len) {
        *cmp_flag = -1;
    } else {
        /*
            length of [a] equals to length [b].
            Call low_level_cmp() function to compare numbers
        */
        *cmp_flag = low_level_cmp(a->num, b->num, a->len);
    }
}

/**
    Compares [a] and [b].

    Sets [cmp_flag]:
        - if a > b, then [cmp_flag] = 1
        - if a = b, then [cmp_flag] = 0
        - if a < b, then [cmp_flag] = -1
*/
void big_int_cmp(const big_int *a, const big_int *b, int *cmp_flag)
{
    assert(a != NULL);
    assert(b != NULL);
    assert(cmp_flag != NULL);

    if (a->sign == MINUS && b->sign == PLUS) {
        *cmp_flag = -1;
    } else if (a->sign == PLUS && b->sign == MINUS) {
        *cmp_flag = 1;
    } else {
        /*
            sign of [a] equals to sign of [b]. So,
            compare its modules
        */
        big_int_cmp_abs(a, b, cmp_flag);
        if (a->sign == MINUS) {
            *cmp_flag = -(*cmp_flag);
        }
    }
}

/**
    Divides [a] by [b]:
        q = a / b
    
    Founds quotient [q] and reminder [r], if its pointers is not set to NULL.
    So, a = q * b + r

    Examples of function calls:
        big_int_div_extended(a, b, q, NULL) - if we need only quotient
        big_int_div_extended(a, b, NULL, r) - if we need only reminder

    Returns error code:
        0 - no errors
        1 - division by zero ([b] cannot be zero)
        other - internal errors
*/
int big_int_div_extended(const big_int *a, const big_int *b, big_int *q, big_int *r)
{
    size_t a_len, b_len, c_len;
    big_int *c = NULL, *a_copy = NULL;
    size_t n_bits;
    int cmp_flag;
    int result = 0;

    assert(a != NULL);
    assert(b != NULL);
    assert(q != r);

    /* check special cases, when [b] = 0 or 1 */
    if (b->len == 1) {
        if (b->num[0] == 0) {
            /* division by zero */
            result = 1;
            goto end;
        }
        if (b->num[0] == 1) {
            /* if [b] = 1, then [q] = [a], [r] = 0 */
            if (q != NULL) {
                if (big_int_copy(a, q)) {
                    result = 2;
                    goto end;
                }
                /* set the sign of quotient */
                q->sign = (a->sign == b->sign) ? PLUS : MINUS;
            }
            if (r != NULL) {
                r->num[0] = 0;
                r->len = 1;
                r->sign = PLUS;
            }
            goto end;
        }
    }

    /*
        If abs(b) less than abs(a), then q = 0 and r = a
    */
    cmp_flag = 0;
    big_int_cmp_abs(a, b, &cmp_flag);
    if (cmp_flag < 0) {
        if (q != NULL) {
            if (big_int_from_int(0, q)) {
                result = 3;
                goto end;
            }
        }
        if (r != NULL) {
            if (big_int_copy(a, r)) {
                result = 4;
                goto end;
            }
        }
        goto end;
    }

    a_copy = big_int_dup(a);
    if (a_copy == NULL) {
        result = 5;
        goto end;
    }
    /* allocate additional word for [a_copy] (need for low_level_div() ) */
    a_len = a_copy->len + 1;
    if (big_int_realloc(a_copy, a_len)) {
        result = 6;
        goto end;
    }

    /* calculates size of quotient */
    b_len = b->len;
    c_len = a_len - b_len;
    /* allocate memory for quotient */
    c = big_int_create(c_len);
    if (c == NULL) {
        result = 7;
        goto end;
    }
    c->len = c_len;

    n_bits = BIG_INT_WORD_BITS_CNT - get_bit_length(b->num[b->len - 1]);
    if (big_int_lshift(a_copy, (int) n_bits, a_copy)) {
        result = 8;
        goto end;
    }
    if (big_int_lshift(b, (int) n_bits, (big_int *) b)) {
        result = 9;
        goto end;
    }
    if (a_copy->len < a_len) {
        a_copy->num[a_len - 1] = 0;
    }

    low_level_div(a_copy->num, a_copy->num + a_len,
                  b->num, b->num + b_len,
                  c->num, c->num + c_len);
    /*
        Set signs of quotient and reminder.
        Sign of reminder (a_copy) is the same as sign of [a]
        Sign of quotient (c) is a->sign ^ b->sign
    */
    a_copy->sign = a->sign;
    c->sign = (a->sign == b->sign) ? PLUS : MINUS;

    if (big_int_rshift(b, (int) n_bits, (big_int *) b)) {
        result = 10;
        goto end;
    }

    if (q != NULL) {
        big_int_clear_zeros(c);
        if (big_int_copy(c, q)) {
            result = 11;
            goto end;
        }
    }
    if (r != NULL) {
        big_int_clear_zeros(a_copy);
        if (big_int_rshift(a_copy, (int) n_bits, a_copy)) {
            result = 12;
            goto end;
        }
        if (big_int_copy(a_copy, r)) {
            result = 13;
            goto end;
        }
    }

end:
    /* free allocated memory */
    big_int_destroy(c);
    big_int_destroy(a_copy);

    return result;
}

/**
    Divides [a] by [b]:
        answer = a / b

    Returns error number:
        0 - no errors
        1 - division by zero
        other - internal errors
*/
int big_int_div(const big_int *a, const big_int *b, big_int *answer)
{
    assert(a != NULL);
    assert(a != NULL);
    assert(answer != NULL);

    return big_int_div_extended(a, b, answer, NULL);
}

/**
    Finds reminder of the division [a] by [b]:
        answer = a mod b

    Returns error number:
        0 - no errors
        1 - division by zero
        other - internal errors
*/
int big_int_mod(const big_int *a, const big_int *b, big_int *answer)
{
    assert(a != NULL);
    assert(a != NULL);
    assert(answer != NULL);

    return big_int_div_extended(a, b, NULL, answer);
}

/**
    Increments [a] by 1:
        a = a + 1;

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_inc(const big_int *a, big_int *answer)
{
    assert(a != NULL);
    assert(answer != NULL);

    return incdec(a, ADD, answer);
}

/**
    Decrements [a] by 1:
        a = a - 1;

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_dec(const big_int *a, big_int *answer)
{
    assert(a != NULL);
    assert(answer != NULL);

    return incdec(a, SUB, answer);
}

/**
    Copy the sign of number [a] to [sign]
*/
void big_int_sign(const big_int *a, sign_type *sign)
{
    assert(a != NULL);
    assert(sign != NULL);

    *sign = a->sign;
}

/**
    answer = abs(a)

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_abs(const big_int *a, big_int *answer)
{
    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    answer->sign = PLUS;

    return 0;
}

/**
    answer = -a

    Returns error number:
        0 - no errors
        other - internal error
*/
int big_int_neg(const big_int *a, big_int *answer)
{
    assert(a != NULL);
    assert(answer != NULL);

    if (big_int_copy(a, answer)) {
        return 1;
    }

    if (answer->len == 1 && answer->num[0] == 0) {
        /* zero always has PLUS sign */
        answer->sign = PLUS;
        return 0;
    }

    switch (answer->sign) {
        case PLUS:
            answer->sign = MINUS;
            break;
        case MINUS:
            answer->sign = PLUS;
            break;
    }

    return 0;
}

/**
    answer = a * a

    Return error number:
        0 - no errors
        other - internal error
*/
int big_int_sqr(const big_int *a, big_int *answer)
{
    assert(a != NULL);
    assert(answer != NULL);

    return big_int_mul(a, a, answer);
}

/**
    sets [is_zero] to 1, if [a] is zero.
    Else sets it to 0
*/
void big_int_is_zero(const big_int *a, int *is_zero)
{
    *is_zero = (a->len == 1 && a->num[0] == 0);
}

/**
    sets [is_one] to 1, if [a] = 1.
    Else sets it to 0
*/
void big_int_is_one(const big_int *a, int *is_one)
{
    *is_one = (a->len == 1 && a->num[0] == 1);
}
