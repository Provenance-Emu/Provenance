#if defined(__MMX__) && !defined(__x86_64)
#define USE_MMX
#endif
#if defined(__SSE__)
#define USE_SSE
#endif

/* SIMD interface (MMX) written by Bisqwit
 * Copyright (C) 1992,2008 Joel Yliluoma (http://iki.fi/bisqwit/)
 */

#ifdef __3dNOW__
# include <mm3dnow.h> /* Note: not available on ICC */ 
#elif defined(__MMX__)
# include <mmintrin.h>
#endif
#ifdef __SSE__
#include <xmmintrin.h>
 #ifdef __ICC
 typedef __m128 __v4sf;
 #endif
#endif

struct c64_common
{
    static signed char clamp_s8(int_fast64_t v)
        { return v<-128 ? -128 : (v > 127 ? 127 : v); }
    static unsigned char clamp_u8(int_fast64_t v)
        { return v<0 ? 0 : (v > 255 ? 255 : v); }
    static short clamp_s16(int_fast64_t v)
        { return v<-32768 ? -32768 : (v > 32767 ? 32767 : v); }

    static inline uint_fast64_t expand32_8(uint_fast32_t a)
    {
        // 0000abcd -> 0a0b0c0d
        typedef uint_fast64_t v;
        return (a&0xFFU)
            | ((a&0xFF00U)<<8)    // base: 8+8 = 16
            | ((v)(a&0xFF0000U)<<16) // base: 16+16 = 32
            | ((v)(a&0xFF000000UL)<<24); // base: 24+24 = 48
    }
    static inline uint_fast64_t expand32_16(uint_fast32_t a)
    {
        // 0000abcd -> 00ab00cd
        typedef uint_fast64_t v;
        return (a&0xFFFFU)
         | ((v)(a&0xFFFF0000UL)<<16);   // base: 16+16 = 32
    }
};

#ifdef __MMX__
/* 64-bit integers that use MMX / 3Dnow operations where relevant */
struct c64_MMX: public c64_common
{
    typedef c64_MMX c64;

    __m64 value;
    
    inline c64_MMX() { }
    inline c64_MMX(__m64 v) : value(v) { }
    inline c64_MMX(const uint64_t& v) : value( *(const __m64*)& v) { }
    inline c64_MMX(int v) : value(_m_from_int(v)) { }
    inline c64_MMX(short a,short b,short c, short d)
        : value(_mm_setr_pi16(a,b,c,d)) { }

    inline c64 operator<< (int b) const { if(b < 0) return *this >> -b; return shl64(b); }
    inline c64 operator>> (int b) const { if(b < 0) return *this << -b; return shr64(b); }
    c64& operator<<= (int n) { return *this = shl64(n); }
    c64& operator>>= (int n) { return *this = shr64(n); }

    c64 conv_s16_u8() const { return conv_s16_u8(*this); }
    c64 conv_s16_s8() const { return conv_s16_s8(*this); }

    void Get(const unsigned char* p)      { value = *(const __m64*)p; }
    void Put(      unsigned char* p)const { *(__m64*)p =  value; }
    
    void Init16(short a,short b,short c, short d)
        { value = _mm_setr_pi16(a,b,c,d); }
    void Init16(short a)
        { value = _mm_set1_pi16(a); }

    void GetD(const unsigned char* p)      { value = *(const __m64*)p; }
    
    template<int n>
    short Extract16() const { return ((const short*)&value)[n]; }
    template<int n>
    int Extract32() const { return ((const int*)&value)[n]; }
    
    short Extract88_from_1616lo() const
    {
        const unsigned char* data = (const unsigned char*)&value;
        // bytes:  76543210
        // shorts: 33221100
        // take:        H L
        return data[0] | *(short*)(data+1);
        //return data[0] | ((*(const unsigned int*)data) >> 8);
    }
    short Extract88_from_1616hi() const
    {
        const unsigned char* data = 4+(const unsigned char*)&value;
        // bytes:  76543210
        // shorts: 33221100
        // take:    H L
        return data[0] | *(short*)(data+1);
        //return data[0] | ((*(const unsigned int*)data) >> 8);
    }
    

    c64& operator&= (const c64& b) { value=_mm_and_si64(value,b.value); return *this; }
    c64& operator|= (const c64& b) { value=_mm_or_si64(value,b.value); return *this; }
    c64& operator^= (const c64& b) { value=_mm_xor_si64(value,b.value); return *this; }
    c64& operator+= (const c64& b) { return *this = *this + b; }
    c64& operator-= (const c64& b) { return *this = *this - b; }
    
    c64 operator~ () const {
        static const uint_least64_t negpat = ~(uint_least64_t)0;
        return c64(_mm_xor_si64(value, *(const __m64*)&negpat));
    }
    
            /* psllqi: p = packed
                       s = shift
                       r = right, l = left
                       l = shift in zero, a = shift in sign bit
                       q = 64-bit, d = 32-bit, w = 16-bit
                      [i = immed amount]
             */
    c64 operator& (const c64& b) const { return c64(_mm_and_si64(value,b.value)); }
    c64 operator| (const c64& b) const { return c64(_mm_or_si64(value,b.value)); }
    c64 operator^ (const c64& b) const { return c64(_mm_xor_si64(value,b.value)); }
    
    c64 operator- (const c64& b) const
    {
        #ifdef __SSE2__
        return _mm_sub_si64(value, b.value);
        #else
        return (const uint64_t&)value - (const uint64_t&)b.value;
        #endif
    }
    c64 operator+ (const c64& b) const
    {
        #ifdef __SSE2__
        return _mm_add_si64(value, b.value);
        #else
        return (const uint64_t&)value + (const uint64_t&)b.value;
        #endif
    }
    

    c64 shl64(int b) const { return _mm_slli_si64(value, b); }
    c64 shr64(int b) const { return _mm_srli_si64(value, b); }
    c64 shl16(int b) const { return _mm_slli_pi16(value, b); }
    c64 shr16(int b) const { return _mm_srli_pi16(value, b); }
    c64 sar32(int b) const { return _mm_srai_pi32(value, b); }
    c64 sar16(int b) const { return _mm_srai_pi16(value, b); }
    c64 add32(const c64& b) const { return _mm_add_pi32(value, b.value); }
    c64 add16(const c64& b) const { return _mm_add_pi16(value, b.value); }
    c64 sub32(const c64& b) const { return _mm_sub_pi32(value, b.value); }
    c64 sub16(const c64& b) const { return _mm_sub_pi16(value, b.value); }
    c64 mul16(const c64& b) const   { return _mm_mullo_pi16(value, b.value); }
    c64 mul16hi(const c64& b) const { return _mm_mulhi_pi16(value, b.value); }
    //c64 mul32(const c64& b) const { return _mm_mullo_pi32(value, b.value); }
    c64 add8(const c64& b) const { return _mm_add_pi8(value, b.value); }
    c64 sub8(const c64& b) const { return _mm_sub_pi8(value, b.value); }
    
    c64 unpacklbw(const c64& b) const { return _mm_unpacklo_pi8(b.value,value); }
    c64 unpacklwd(const c64& b) const { return _mm_unpacklo_pi16(b.value,value); }
    c64 unpackhbw(const c64& b) const { return _mm_unpackhi_pi8(b.value,value); }
    c64 unpackhwd(const c64& b) const { return _mm_unpackhi_pi16(b.value,value); }
    c64 unpackldq(const c64& b) const { return _mm_unpacklo_pi32(b.value,value); }
    c64 unpackldq() const { return _mm_unpacklo_pi32(value,value); }

    c64 operator& (const uint64_t& v) { return c64(_mm_and_si64(value, *(const __m64*)& v)); }
    
    c64 conv_s32_s16(const c64& b) const { return _mm_packs_pi32(value, b.value); }
    c64 conv_s16_u8(const c64& b) const { return _mm_packs_pu16(value, b.value); }
    c64 conv_s16_s8(const c64& b) const { return _mm_packs_pi16(value, b.value); }
};
#endif

struct c64_nonMMX: public c64_common
{
    typedef c64_nonMMX c64;
    
    uint_least64_t value;
    
    inline c64_nonMMX() { }
    inline c64_nonMMX(uint64_t v) : value(v) { }
    inline c64_nonMMX(int v) : value(v) { }
    inline c64_nonMMX(short a,short b,short c, short d)
        { Init16(a,b,c,d); }

    c64 operator<< (int b) const { if(b < 0) return *this >> -b; return shl64(b); }
    c64 operator>> (int b) const { if(b < 0) return *this << -b; return shr64(b); }
    c64& operator<<= (int n) { return *this = shl64(n); }
    c64& operator>>= (int n) { return *this = shr64(n); }

    c64 conv_s16_u8() const { return conv_s16_u8(*this); }
    c64 conv_s16_s8() const { return conv_s16_s8(*this); }

    void Init16(short a,short b,short c, short d)
        { uint_fast64_t aa = (unsigned short)a,
                        bb = (unsigned short)b,
                        cc = (unsigned short)c,
                        dd = (unsigned short)d;
          value = aa | (bb << 16) | (cc << 32) | (dd << 48); }
    void Init16(short a)
        { Init16(a,a,a,a); }
    void Init8(unsigned char a,unsigned char b,unsigned char c,unsigned char d,
               unsigned char e,unsigned char f,unsigned char g,unsigned char h)
    {
        value = ((uint_fast64_t)(a | (b << 8) | (c << 16) | (d << 24)))
              | (((uint_fast64_t)e) << 32)
              | (((uint_fast64_t)f) << 40)
              | (((uint_fast64_t)g) << 48)
              | (((uint_fast64_t)h) << 56);
    }

    void Get(const unsigned char* p)      { value = *(const uint_least64_t*)p; }
    void Put(      unsigned char* p)const { *(uint_least64_t*)p =  value; }
    
    c64& operator&= (const c64& b) { value&=b.value; return *this; }
    c64& operator|= (const c64& b) { value|=b.value; return *this; }
    c64& operator^= (const c64& b) { value^=b.value; return *this; }
    c64& operator+= (const c64& b) { value+=b.value; return *this; }
    c64& operator-= (const c64& b) { value-=b.value; return *this; }
    c64 operator& (const c64& b) const { return value & b.value; }
    c64 operator| (const c64& b) const { return value | b.value; }
    c64 operator^ (const c64& b) const { return value ^ b.value; }
    c64 operator- (const c64& b) const { return value - b.value; }
    c64 operator+ (const c64& b) const { return value + b.value; }

    c64 operator& (uint_fast64_t b) const { return value & b; }

    c64 operator~ () const { return ~value; }
    
    #define usimdsim(type, count, op) \
        type* p = (type*)&res.value; \
        for(int n=0; n<count; ++n) p[n] = (p[n] op b)

    #define simdsim(type, count, op) \
        type* p = (type*)&res.value; \
        const type* o = (const type*)&b.value; \
        for(int n=0; n<count; ++n) p[n] = (p[n] op o[n])
    
    c64 shl64(int b) const { return value << b; }
    c64 shr64(int b) const { return value >> b; }
    c64 shl16(int b) const { c64 res = *this; usimdsim(short, 2, <<); return res; }
    c64 shr16(int b) const { c64 res = *this; usimdsim(unsigned short, 2, >>); return res; }
    c64 sar32(int b) const { c64 res = *this; usimdsim(int, 2, >>); return res; }
    c64 sar16(int b) const { c64 res = *this; usimdsim(short, 2, >>); return res; }

    c64 add16(const c64& b) const { c64 res = *this; simdsim(short, 4, +); return res; }
    c64 sub16(const c64& b) const { c64 res = *this; simdsim(short, 4, -); return res; }
    c64 add32(const c64& b) const { c64 res = *this; simdsim(int,   2, +); return res; }
    c64 sub32(const c64& b) const { c64 res = *this; simdsim(int,   2, -); return res; }
    c64 mul16(const c64& b) const { c64 res = *this; simdsim(short, 4, *); return res; }
    c64 mul16hi(const c64& b) const { c64 res = *this; simdsim(short, 4, *) >> 16; return res; }
    c64 add8(const c64& b) const { c64 res = *this; simdsim(unsigned char, 8, +); return res; }
    c64 sub8(const c64& b) const { c64 res = *this; simdsim(unsigned char, 8, -); return res; }
    
    #undef simdsim
    #undef usimdsim
    
    c64 conv_s32_s16(const c64& b) const
    {
        c64 res; res.
        Init16(clamp_s16(value & 0xFFFFFFFFU),
               clamp_s16(value >> 32),
               clamp_s16(b.value & 0xFFFFFFFFU),
               clamp_s16(b.value >> 32));
        return res;
    }
    c64 conv_s16_u8(const c64& b) const
    {
        c64 res; res.
        Init8(clamp_u8(value & 0xFFFF),
              clamp_u8((value >> 16) & 0xFFFF),
              clamp_u8((value >> 32) & 0xFFFF),
              clamp_u8((value >> 48) & 0xFFFF),
              clamp_u8(b.value & 0xFFFF),
              clamp_u8((b.value >> 16) & 0xFFFF),
              clamp_u8((b.value >> 32) & 0xFFFF),
              clamp_u8((b.value >> 48) & 0xFFFF));
        return res;
    }
    c64 conv_s16_s8(const c64& b) const
    {
        c64 res; res.
        Init8(clamp_s8(value & 0xFFFF),
              clamp_s8((value >> 16) & 0xFFFF),
              clamp_s8((value >> 32) & 0xFFFF),
              clamp_s8((value >> 48) & 0xFFFF),
              clamp_s8(b.value & 0xFFFF),
              clamp_s8((b.value >> 16) & 0xFFFF),
              clamp_s8((b.value >> 32) & 0xFFFF),
              clamp_s8((b.value >> 48) & 0xFFFF));
        return res;
    }

    /* TODO: Verify that these are correct (though they should never be used anyway) */
    c64 unpacklbw(const c64& p) const
    {
    #if defined(__MMX__) && !defined(__ICC)
        /* ICC says [error: type of cast must be integral or enum]
         * on the return value cast,
         * so we cannot use this code on ICC. Fine for GCC. */
        return (uint_least64_t)_m_punpcklbw(*(__m64*)&p.value, *(__m64*)&value);
    #else
        uint_fast64_t a=value, b=p.value;
        return expand32_8(a) | (expand32_8(b) << 8);
    #endif
    }
    c64 unpackhbw(const c64& p) const
    {
    #if defined(__MMX__) && !defined(__ICC)
        return (uint_least64_t)_m_punpckhbw(*(__m64*)&p.value, *(__m64*)&value);
    #else
        uint_fast64_t a=value, b=p.value;
        return expand32_8(a>>32) | (expand32_8(b>>32) << 8);
    #endif
    }
    c64 unpacklwd(const c64& p) const
    {
    #if defined(__MMX__) && !defined(__ICC)
        return (uint_least64_t)_m_punpcklwd(*(__m64*)&p.value, *(__m64*)&value);
    #else
        uint_fast64_t a=value, b=p.value;
        return expand32_16(a) | (expand32_16(b) << 16);
    #endif
    }
    c64 unpackhwd(const c64& p) const
    {
    #if defined(__MMX__) && !defined(__ICC)
        return (uint_least64_t)_m_punpckhwd(*(__m64*)&p.value, *(__m64*)&value);
    #else
        uint_fast64_t a=value, b=p.value;
        return expand32_16(a>>32) | (expand32_16(b>>32) << 16);
    #endif
    }
    c64 unpackldq() const { return unpackldq(*this); }
    c64 unpackldq(const c64& p) const
    {
    #if defined(__MMX__) && !defined(__ICC)
        return (uint_least64_t)_m_punpckldq(*(__m64*)&p.value, *(__m64*)&value);
    #else
        return value | (p.value << 32);
    #endif
    }
};

#ifdef USE_MMX
typedef c64_MMX c64;
#else
typedef c64_nonMMX c64;
#endif

static inline void MMX_clear()
{
    #ifdef __3dNOW__
    _m_femms(); /* Note: not available on ICC or Valgrind */
    //_mm_empty();
    #elif defined(__MMX__)
    _mm_empty();
    #endif
}
