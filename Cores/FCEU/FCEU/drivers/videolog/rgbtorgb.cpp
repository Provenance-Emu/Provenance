#include <stdint.h>
#include <stdlib.h> // for size_t
#include <vector>
#include <cmath>

/* RGB to RGB and RGB from/to I420 conversions written by Bisqwit
 * Copyright (C) 1992,2008 Joel Yliluoma (http://iki.fi/bisqwit/)
 */

typedef uint_least64_t uint64_t;

#include "quantize.h"
#include "rgbtorgb.h"
#include "simd.h"

/* For BPP conversions */

static const uint64_t mask24l        __attribute__((aligned(8))) = 0x0000000000FFFFFFULL;
static const uint64_t mask24h        __attribute__((aligned(8))) = 0x0000FFFFFF000000ULL;
static const uint64_t mask24hh       __attribute__((aligned(8))) = 0xffff000000000000ULL;
static const uint64_t mask24hhh      __attribute__((aligned(8))) = 0xffffffff00000000ULL;
static const uint64_t mask24hhhh     __attribute__((aligned(8))) = 0xffffffffffff0000ULL;

static const uint64_t mask64h        __attribute__((aligned(8))) = 0xFF00FF00FF00FF00ULL;
static const uint64_t mask64l        __attribute__((aligned(8))) = 0x00FF00FF00FF00FFULL;
static const uint64_t mask64hw       __attribute__((aligned(8))) = 0xFFFF0000FFFF0000ULL;
static const uint64_t mask64lw       __attribute__((aligned(8))) = 0x0000FFFF0000FFFFULL;
static const uint64_t mask64hd       __attribute__((aligned(8))) = 0xFFFFFFFF00000000ULL;
static const uint64_t mask64ld       __attribute__((aligned(8))) = 0x00000000FFFFFFFFULL;

/* For RGB2YUV: */

static const int RGB2YUV_SHIFT = 15; /* highest value where [RGB][YUV] fit in signed short */

static const int RY = 8414;  //  ((int)(( 65.738/256.0)*(1<<RGB2YUV_SHIFT)+0.5));
static const int RV = 14392; //  ((int)((112.439/256.0)*(1<<RGB2YUV_SHIFT)+0.5));
static const int RU = -4856; //  ((int)((-37.945/256.0)*(1<<RGB2YUV_SHIFT)+0.5));

static const int GY = 16519; //  ((int)((129.057/256.0)*(1<<RGB2YUV_SHIFT)+0.5));
static const int GV = -12051;//  ((int)((-94.154/256.0)*(1<<RGB2YUV_SHIFT)+0.5));
static const int GU = -9534; //  ((int)((-74.494/256.0)*(1<<RGB2YUV_SHIFT)+0.5));

static const int BY = 3208;  //  ((int)(( 25.064/256.0)*(1<<RGB2YUV_SHIFT)+0.5));
static const int BV = -2339; //  ((int)((-18.285/256.0)*(1<<RGB2YUV_SHIFT)+0.5));
static const int BU = 14392; //  ((int)((112.439/256.0)*(1<<RGB2YUV_SHIFT)+0.5));

static const int Y_ADD = 16;
static const int U_ADD = 128;
static const int V_ADD = 128;

/* For YUV2RGB: */

static const int YUV2RGB_SHIFT = 13; /* highest value where UB still fits in signed short */

static const int Y_REV = 9539; // ((int)( (  255 / 219.0 )     * (1<<YUV2RGB_SHIFT)+0.5));
static const int VR = 14688;   // ((int)( ( 117504 / 65536.0 ) * (1<<YUV2RGB_SHIFT)+0.5));
static const int VG = -6659;   // ((int)( ( -53279 / 65536.0 ) * (1<<YUV2RGB_SHIFT)+0.5));
static const int UG = -3208;   // ((int)( ( -25675 / 65536.0 ) * (1<<YUV2RGB_SHIFT)+0.5));
static const int UB = 16525;   // ((int)( ( 132201 / 65536.0 ) * (1<<YUV2RGB_SHIFT)+0.5));

/****************/

template<typename c64>
static inline void Convert32To24_32bytes(c64 w0, c64 w1, c64 w2, c64 w3, unsigned char* dest)
{
    c64 r0 = (w0 & mask24l) | ((w0 >> 8) & mask24h); /* bbbaaa */
    c64 r1 = (w1 & mask24l) | ((w1 >> 8) & mask24h); /* dddccc */
    c64 r2 = (w2 & mask24l) | ((w2 >> 8) & mask24h); /* fffeee */
    c64 r3 = (w3 & mask24l) | ((w3 >> 8) & mask24h); /* hhhggg */
    
    /* ccbbbaaa */
    ((r0      )  | ((r1 << 48) & mask24hh)).Put(dest+0);
    /* feeedddc */
    ((r1 >> 16)  | ((r2 << 32) & mask24hhh)).Put(dest+8);
    /* hhhgggff */
    ((r2 >> 32)  | ((r3 << 16) & mask24hhhh)).Put(dest+16);
}

#if defined(__x86_64) || defined(USE_MMX)
static void Convert32To24_32bytes(const unsigned char* src,
                                  unsigned char* dest)
{
    c64 w0; w0.Get(src+0);
    c64 w1; w1.Get(src+8);
    c64 w2; w2.Get(src+16);
    c64 w3; w3.Get(src+24);
    Convert32To24_32bytes(w0,w1,w2,w3, dest);
}
#endif

void Convert32To24Frame(const void* data, unsigned char* dest, unsigned npixels)
{
    const unsigned char* src = (const unsigned char*)data;
    
    #if defined(__x86_64) || defined(USE_MMX)
    while(npixels >= 8)
    {
        Convert32To24_32bytes(src, dest);
        src  += 4*8;
        dest += 3*8;
        npixels -= 8;
    }
     #ifdef USE_MMX
     MMX_clear();
     #endif
    #endif
    
    for(unsigned pos=0; pos<npixels; ++pos)
    {
        dest[3*pos+0] = src[4*pos+0];
        dest[3*pos+1] = src[4*pos+1];
        dest[3*pos+2] = src[4*pos+2];
    }
}

static void Unbuild16(unsigned char* target, unsigned rgb16)
{
    unsigned B = (rgb16%32)*256/32;
    unsigned G = ((rgb16/32)%64)*256/64;
    unsigned R = ((rgb16/(32*64))%32)*256/32;
    target[0] = R;
    target[1] = G;
    target[2] = B;
}

static void Unbuild15(unsigned char* target, unsigned rgb16)
{
    unsigned B = (rgb16%32)*256/32;
    unsigned G = ((rgb16/32)%32)*256/32;
    unsigned R = ((rgb16/(32*32))%32)*256/32;
    target[0] = R;
    target[1] = G;
    target[2] = B;
}

template<int basevalue_lo, int basevalue_hi>
struct Bits16const
{
    static const uint64_t static_value =
       (( ((uint64_t)(unsigned short) basevalue_lo) << 0)
      | ( ((uint64_t)(unsigned short) basevalue_hi) << 16)
      | ( ((uint64_t)(unsigned short) basevalue_lo) << 32)
      | ( ((uint64_t)(unsigned short) basevalue_hi) << 48));
    static const uint64_t value;
};
template<int basevalue_lo, int basevalue_hi>
const uint64_t Bits16const<basevalue_lo, basevalue_hi>::value =
               Bits16const<basevalue_lo, basevalue_hi>::static_value;

template<int basevalue_lo, int basevalue_hi>
struct Bits32const
{
    static const uint64_t static_value = 
       (( ((uint64_t)(unsigned int) basevalue_lo) << 0)
      | ( ((uint64_t)(unsigned int) basevalue_hi) << 32));
    static const uint64_t value = static_value;
};/*
template<int basevalue_lo, int basevalue_hi>
const uint64_t Bits32const<basevalue_lo, basevalue_hi>::value =
               Bits32const<basevalue_lo, basevalue_hi>::static_value;*/

template<uint64_t basevalue_lo, uint64_t basevalue_hi>
struct Bits8const
{
    static const uint64_t static_value =
       ((basevalue_lo << 0)
      | (basevalue_hi << 8)
      | (basevalue_lo << 16)
      | (basevalue_hi << 24)
      | (basevalue_lo << 32)
      | (basevalue_hi << 40)
      | (basevalue_lo << 48)
      | (basevalue_hi << 56));
    static const uint64_t value = static_value;
};


template<int lowbitcount, int highbitcount, int leftshift>
struct MaskBconst
{
    static const uint64_t basevalue_lo = (1 <<  lowbitcount) - 1;
    static const uint64_t basevalue_hi = (1 << highbitcount) - 1;
    static const uint64_t value = Bits8const<basevalue_lo,basevalue_hi>::value << leftshift;
};

template<int bits>
struct Convert_2byte_consts
{
    static const uint64_t mask_lo;//   = MaskBconst<bits,0, 0>::value;
    static const uint64_t mask_hi;//   = MaskBconst<bits,0, 8>::value;
    static const uint64_t mask_frac;// = MaskBconst<8-bits,8-bits, 0>::value;
};
template<int bits>
const uint64_t Convert_2byte_consts<bits>::mask_lo   = MaskBconst<bits, 0, 0>::value;
template<int bits>
const uint64_t Convert_2byte_consts<bits>::mask_hi   = MaskBconst<bits, 0, 8>::value;
template<int bits>
const uint64_t Convert_2byte_consts<bits>::mask_frac = MaskBconst<8-bits, 8-bits, 0>::value;

template<int offs, int bits>
struct Convert_2byte_helper
{
    c64 lo, hi;
    
    Convert_2byte_helper(c64 p4a, c64 p4b)
    {
        const uint64_t& mask_lo   = Convert_2byte_consts<bits>::mask_lo;
        const uint64_t& mask_hi   = Convert_2byte_consts<bits>::mask_hi;
        const uint64_t& mask_frac = Convert_2byte_consts<bits>::mask_frac;
        
        /* STEP 1: SEPARATE THE PIXELS INTO RED, GREEN AND BLUE COMPONENTS */

        /* 000BBBBB 000bbbbb  000BBBBB 000bbbbb  000BBBBB 000bbbbb  000BBBBB 000bbbbb */
        c64 s5 = ((p4a >> offs) & mask_lo) | ((p4b << (8-offs)) & mask_hi);

        /* STEP 2: SCALE THE COLOR COMPONENTS TO 256 RANGE */
        
        /* BBBBB000 bbbbb000  BBBBB000 bbbbb000  BBBBB000 bbbbb000  BBBBB000 bbbbb000 */
        /* 00000BBB 00000bbb  00000BBB 00000bbb  00000BBB 00000bbb  00000BBB 00000bbb */
        c64 v8 = (s5 << (8-bits)) | ((s5 >> (bits-(8-bits))) & mask_frac);
        /* v8:
         *
         * BBBBBBBB bbbbbbbb  BBBBBBBB bbbbbbbb  BBBBBBBB bbbbbbbb  BBBBBBBB bbbbbbbb *
         */
        
        /* STEP 3: DEINTERLACE THE PIXELS */
        lo = (v8     ) & mask64l;
        hi = (v8 >> 8) & mask64l;
    }
};

/*
template<int roffs,int rbits, int goffs,int gbits, int boffs,int bbits>
static void Convert_2byte_to_24Common(const unsigned char* src, unsigned char* dest)
    __attribute((noinline));
*/
template<int roffs,int rbits, int goffs,int gbits, int boffs,int bbits, bool rgb24>
static void Convert_2byte_to_24or32Common(const unsigned char* src, unsigned char* dest)
{
    c64 p4a; p4a.Get(src+0); // four pixels
    c64 p4b; p4b.Get(src+8); // another four pixels
    
    /* in: In both registers: */
    
    Convert_2byte_helper<roffs,rbits> r(p4a,p4b);
    Convert_2byte_helper<boffs,bbits> b(p4a,p4b);
    Convert_2byte_helper<goffs,gbits> g(p4a,p4b);

    /* STEP 4: CONVERT PIXELS INTO RGB32 */
    
    /* Now we have:
     *               b.lo =  0j0g0d0a
     *               g.lo =  0k0h0e0b
     *               r.lo =  0l0i0f0c
     *               b.hi =  0J0G0D0A
     *               g.hi =  0K0H0E0B
     *               r.hi =  0L0I0F0C
     * We want:
     *                 w1 =  0fed0cba
     *                 w2 =  0lkj0ihg
     *                 w3 =  0FED0CBA
     *                 w4 =  0LKJ0IHG
     */
   
#if 0 && defined(__MMX__) /* FIXME why is this 0&&? */
    // punpcklbw  0k0h0e0b, 0j0g0d0a -> 00ed00ba
    // punpcklwd  0l0i0f0c, ________ -> 0f__0c__
    c64 w1 = r.lo.unpacklwd(0) | g.lo.unpacklbw(b.lo); // pix 0,1
    // punpckhbw  0k0h0e0b, 0j0g0d0a -> 00kj00hg
    // punpckhwd  0l0i0f0c, ________ -> 0l__0i__
    c64 w2 = r.lo.unpackhwd(0) | g.lo.unpackhbw(b.lo); // pix 2,3
    
    c64 w3 = r.hi.unpacklwd(0) | g.hi.unpacklbw(b.hi); // pix 4,5
    c64 w4 = r.hi.unpackhwd(0) | g.hi.unpackhbw(b.hi); // pix 6,7
    #ifndef USE_MMX
     MMX_clear();
    #endif
#else
    /* With 64-bit registers, this code is greatly simpler than
     * the emulation of unpack opcodes. However, when the
     * unpack opcodes is available, using them is shorter.
     * Which way is faster? FIXME: Find out
     */

    //        mask64lw:  00**00**
    //        mask64hw:  **00**00
    // b.lo & mask64lw:  000g000a
    // g.lo & mask64lw:  000h000b
    // r.lo & mask64lw:  000i000c
    // b.lo & mask64hw:  0j000d00
    // g.lo & mask64hw:  0k000e00
    // r.lo & mask64hw:  0l000f00
    
    c64 tlo1 = ((b.lo & mask64lw)     ) | ((g.lo & mask64lw) << 8) | ((r.lo & mask64lw) << 16);
    c64 tlo2 = ((b.lo & mask64hw) >>16) | ((g.lo & mask64hw) >> 8) | ((r.lo & mask64hw)      );

    c64 thi1 = ((b.hi & mask64lw)     ) | ((g.hi & mask64lw) << 8) | ((r.hi & mask64lw) << 16);
    c64 thi2 = ((b.hi & mask64hw) >>16) | ((g.hi & mask64hw) >> 8) | ((r.hi & mask64hw)      );
    /*
     *                tlo1 =  0ihg0cba
     *                tlo2 =  0lkj0fed
     *                thi1 =  0IHG0CBA
     *                thi2 =  0LKJ0FED
     *            mask64ld =  0000****
     *            mask64hd =  ****0000
     */
     
    c64 w1 = (tlo1 & mask64ld) | ((tlo2 & mask64ld) << 32); // 00000cba | 00000fed = 0fed0bca
    c64 w2 = (tlo2 & mask64hd) | ((tlo1 & mask64hd) >> 32); // 0lkj0000 | 0ihg0000 = 0lkj0ihg

    c64 w3 = (thi1 & mask64ld) | ((thi2 & mask64ld) << 32);
    c64 w4 = (thi2 & mask64hd) | ((thi1 & mask64hd) >> 32);
#endif
    
    if(rgb24)
    {
        /* STEP 5A: CONVERT PIXELS INTO RGB24 */
        Convert32To24_32bytes(w1,w2,w3,w4, dest);
    }
    else
    {
        /* STEP 5B: STORE RGB32 */
        w1.Put(dest+0);
        w2.Put(dest+8);
        w3.Put(dest+16);
        w4.Put(dest+24);
    }
     
    /*
     punpcklbw    ____ABCD, ____abcd = AaBbCcDd
     punpcklwd    ____ABCD, ____abcd = ABabCDcd
     punpckldq    ____ABCD, ____abcd = ABCDabcd
     
     punpckhbw    ABCD____, abcd____ = AaBbCcDd
     punpckhwd    ABCD____, abcd____ = ABabCDcd
     punpckhdq    ABCD____, abcd____ = ABCDabcd
    */
}

void Convert15To24Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue)
{
    const unsigned char* src = (const unsigned char*)data;
    
    if(swap_red_blue)
        for(; npixels >= 8; src += 8*2, dest += 8*3, npixels -= 8)
            Convert_2byte_to_24or32Common<0,5, 5,5, 10,5, true> (src, dest);
    else
        for(; npixels >= 8; src += 8*2, dest += 8*3, npixels -= 8)
            Convert_2byte_to_24or32Common<10,5, 5,5, 0,5, true> (src, dest);

    #ifdef USE_MMX
     MMX_clear();
    #endif
    for(unsigned a=0; a<npixels; ++a)
    {
        unsigned short v = ((const unsigned short*)src)[a];
        Unbuild15(&dest[a*3], v);
    }
}

void Convert16To24Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue)
{
    const unsigned char* src = (const unsigned char*)data;
    
    if(swap_red_blue)
        for(; npixels >= 8; src += 8*2, dest += 8*3, npixels -= 8)
            Convert_2byte_to_24or32Common<0,5, 5,6, 11,5, true> (src, dest);
    else
        for(; npixels >= 8; src += 8*2, dest += 8*3, npixels -= 8)
            Convert_2byte_to_24or32Common<11,5, 5,6, 0,5, true> (src, dest);

    #ifdef USE_MMX
     MMX_clear();
    #endif
    for(unsigned a=0; a<npixels; ++a)
    {
        unsigned short v = ((const unsigned short*)src)[a];
        Unbuild16(&dest[a*3], v);
    }
}

void Convert15To32Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue)
{
    const unsigned char* src = (const unsigned char*)data;
    
    if(swap_red_blue)
        for(; npixels >= 8; src += 8*2, dest += 8*4, npixels -= 8)
            Convert_2byte_to_24or32Common<0,5, 5,5, 10,5, false> (src, dest);
    else
        for(; npixels >= 8; src += 8*2, dest += 8*4, npixels -= 8)
            Convert_2byte_to_24or32Common<10,5, 5,5, 0,5, false> (src, dest);

    #ifdef USE_MMX
     MMX_clear();
    #endif
    for(unsigned a=0; a<npixels; ++a)
    {
        unsigned short v = ((const unsigned short*)src)[a];
        Unbuild15(&dest[a*4], v);
    }
}

void Convert16To32Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue)
{
    const unsigned char* src = (const unsigned char*)data;
    
    if(swap_red_blue)
        for(; npixels >= 8; src += 8*2, dest += 8*4, npixels -= 8)
            Convert_2byte_to_24or32Common<0,5, 5,6, 11,5, false> (src, dest);
    else
        for(; npixels >= 8; src += 8*2, dest += 8*4, npixels -= 8)
            Convert_2byte_to_24or32Common<11,5, 5,6, 0,5, false> (src, dest);

    #ifdef USE_MMX
     MMX_clear();
    #endif
    for(unsigned a=0; a<npixels; ++a)
    {
        unsigned short v = ((const unsigned short*)src)[a];
        Unbuild16(&dest[a*4], v);
    }
}

static inline unsigned Build16(unsigned x,unsigned y, const unsigned char* rgbdata)
{
    unsigned o16 = (x + 4*y) % 16;
    return (Quantize4x4<31>(o16, rgbdata[2]) << 0)
         | (Quantize4x4<63>(o16, rgbdata[1]) << 5)
         | (Quantize4x4<31>(o16, rgbdata[0]) << 11);
}
static inline unsigned Build15(unsigned x,unsigned y, const unsigned char* rgbdata)
{
    unsigned o16 = (x + 4*y) % 16;
    return (Quantize4x4<31>(o16, rgbdata[2]) << 0)
         | (Quantize4x4<31>(o16, rgbdata[1]) << 5)
         | (Quantize4x4<31>(o16, rgbdata[0]) << 10);
}

void Convert24To16Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    const unsigned char* logodata = (const unsigned char*) data;
    unsigned short* result = (unsigned short*) dest;
    unsigned x=0,y=0;
    for(unsigned pos=0; pos<npixels; ++pos)
    {
        result[pos] = Build16(x,y, &logodata[pos*3]);
        if(++x >= width) { x=0; ++y; }
    }
}

void Convert24To15Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    const unsigned char* logodata = (const unsigned char*) data;
    unsigned short* result = (unsigned short*) dest;
    unsigned x=0,y=0;
    for(unsigned pos=0; pos<npixels; ++pos)
    {
        result[pos] = Build15(x,y, &logodata[pos*3]);
        if(++x >= width) { x=0; ++y; }
    }
}

#ifdef __MMX__
static inline void Convert_I420_MMX_Common
    (c64_MMX p0_1, c64_MMX p2_3,
     unsigned char* dest_y0,
     unsigned char* dest_y1,
     unsigned char* dest_u,
     unsigned char* dest_v)
{
    c64_MMX p0 = c64_MMX(0).unpacklbw(p0_1); // expand to 64-bit (4*16)
    c64_MMX p1 = c64_MMX(0).unpackhbw(p0_1);
    c64_MMX p2 = c64_MMX(0).unpacklbw(p2_3);
    c64_MMX p3 = c64_MMX(0).unpackhbw(p2_3);
    
    c64_MMX ry_gy_by; ry_gy_by.Init16(RY,GY,BY, 0);
    c64_MMX rgb_u;    rgb_u.Init16(RU,GU,BU, 0);
    c64_MMX rgb_v;    rgb_v.Init16(RV,GV,BV, 0);

    c64_MMX ctotal = p0.add16(
                     p2.add16(
                     p1.add16(
                     p3)));
  
    p0 = _mm_madd_pi16(ry_gy_by.value, p0.value);
    p1 = _mm_madd_pi16(ry_gy_by.value, p1.value);
    p2 = _mm_madd_pi16(ry_gy_by.value, p2.value);
    p3 = _mm_madd_pi16(ry_gy_by.value, p3.value);
    
    c64_MMX yy;
    yy.Init16( ((p0.Extract32<0>() + p0.Extract32<1>()) >> (RGB2YUV_SHIFT)),
               ((p1.Extract32<0>() + p1.Extract32<1>()) >> (RGB2YUV_SHIFT)),
               ((p2.Extract32<0>() + p2.Extract32<1>()) >> (RGB2YUV_SHIFT)),
               ((p3.Extract32<0>() + p3.Extract32<1>()) >> (RGB2YUV_SHIFT)) );
    yy = yy.add16( Bits16const<Y_ADD,Y_ADD>::value );
    
    // Because we're writing to adjacent pixels, we optimize this by
    // writing two 8-bit values at once in both cases.
    *(short*)dest_y0 = yy.Extract88_from_1616lo();
    *(short*)dest_y1 = yy.Extract88_from_1616hi();
    
    c64_MMX u_total32 = _mm_madd_pi16(rgb_u.value, ctotal.value);
    c64_MMX v_total32 = _mm_madd_pi16(rgb_v.value, ctotal.value);
    
    *dest_u = U_ADD + ((u_total32.Extract32<0>() + u_total32.Extract32<1>()) >> (RGB2YUV_SHIFT+2));
    *dest_v = V_ADD + ((v_total32.Extract32<0>() + v_total32.Extract32<1>()) >> (RGB2YUV_SHIFT+2));
}

static inline void Convert_YUY2_MMX_Common
    (c64_MMX p0_1, c64_MMX p2_3,
     unsigned char* dest_yvyu)
{
    c64_MMX p0 = c64_MMX(0).unpacklbw(p0_1); // expand to 64-bit (4*16)
    c64_MMX p1 = c64_MMX(0).unpackhbw(p0_1);
    c64_MMX p2 = c64_MMX(0).unpacklbw(p2_3); // expand to 64-bit (4*16)
    c64_MMX p3 = c64_MMX(0).unpackhbw(p2_3);
    
    c64_MMX ry_gy_by; ry_gy_by.Init16(RY,GY,BY, 0);
    c64_MMX rgb_u;    rgb_u.Init16(RU,GU,BU, 0);
    c64_MMX rgb_v;    rgb_v.Init16(RV,GV,BV, 0);

    c64_MMX ctotal0 = p0.add16(p1);
    c64_MMX ctotal2 = p2.add16(p3);
  
    p0 = _mm_madd_pi16(ry_gy_by.value, p0.value);
    p1 = _mm_madd_pi16(ry_gy_by.value, p1.value);
    p2 = _mm_madd_pi16(ry_gy_by.value, p2.value);
    p3 = _mm_madd_pi16(ry_gy_by.value, p3.value);
    
    c64_MMX yy;
    yy.Init16( ((p0.Extract32<0>() + p0.Extract32<1>()) >> (RGB2YUV_SHIFT)),
               ((p1.Extract32<0>() + p1.Extract32<1>()) >> (RGB2YUV_SHIFT)),
               ((p2.Extract32<0>() + p2.Extract32<1>()) >> (RGB2YUV_SHIFT)),
               ((p3.Extract32<0>() + p3.Extract32<1>()) >> (RGB2YUV_SHIFT)) );

    yy = yy.add16( Bits16const<Y_ADD,Y_ADD>::value );
    
    c64_MMX u_total32_0 = _mm_madd_pi16(rgb_u.value, ctotal0.value);
    c64_MMX v_total32_0 = _mm_madd_pi16(rgb_v.value, ctotal0.value);
    c64_MMX u_total32_2 = _mm_madd_pi16(rgb_u.value, ctotal2.value);
    c64_MMX v_total32_2 = _mm_madd_pi16(rgb_v.value, ctotal2.value);
    
    c64_MMX quadword = yy; // four y values: at 0, 2, 4 and 6
    
    c64_MMX uv; uv.Init16(
        ((v_total32_0.Extract32<0>() + v_total32_0.Extract32<1>()) >> (RGB2YUV_SHIFT+1)),
        ((u_total32_0.Extract32<0>() + u_total32_0.Extract32<1>()) >> (RGB2YUV_SHIFT+1)),
        ((v_total32_2.Extract32<0>() + v_total32_2.Extract32<1>()) >> (RGB2YUV_SHIFT+1)),
        ((u_total32_2.Extract32<0>() + u_total32_2.Extract32<1>()) >> (RGB2YUV_SHIFT+1)) );
    c64_MMX uv_adds; uv_adds.Init16(V_ADD, U_ADD, V_ADD, U_ADD);
    uv = uv.add16(uv_adds);
    
    quadword |= uv << 8;     // two u and v values: at 1, 3, 5 and 7.
    quadword.Put(dest_yvyu); // write four y values: at 0, 2, 4 and 6
}
#endif

/*template<int PixStride>
void Convert_4byte_To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
    __attribute__((noinline));*/

template<int PixStride>
void Convert_4byte_To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    const unsigned char* src = (const unsigned char*) data;
    unsigned height = npixels / width;
    
    unsigned pos = 0;
    unsigned ypos = 0;
    unsigned vpos = npixels;
    unsigned upos = vpos + npixels / 4;
    unsigned stride = width*PixStride;

    /*fprintf(stderr, "npixels=%u, width=%u, height=%u, ypos=%u,upos=%u,vpos=%u",
        npixels,width,height, ypos,upos,vpos);*/

    /* This function is based on code from x264 svn version 711 */
    /* TODO: Apply MMX optimization for 24-bit pixels */
    
    for(unsigned y=0; y<height; y += 2)
    {
        for(unsigned x=0; x<width; x += 2)
        {
        #ifdef __MMX__
          if(PixStride == 4)
          {
            c64_MMX p0_1; p0_1.Get(&src[pos]);        // two 32-bit pixels (4*8)
            c64_MMX p2_3; p2_3.Get(&src[pos+stride]); // two 32-bit pixels

            pos += PixStride*2;
            
            Convert_I420_MMX_Common(p0_1, p2_3,
                dest+ypos,
                dest+ypos+width,
                dest+upos++,
                dest+vpos++);
          }
          else
        #endif
          {
            int c[3], rgb[3][4];
            
            /* luma */
            for(int n=0; n<3; ++n) c[n]  = rgb[n][0] = src[pos + n];
            for(int n=0; n<3; ++n) c[n] += rgb[n][1] = src[pos + n + stride];
            pos += PixStride;
            
            for(int n=0; n<3; ++n) c[n] += rgb[n][2] = src[pos + n];
            for(int n=0; n<3; ++n) c[n] += rgb[n][3] = src[pos + n + stride];
            pos += PixStride;

            unsigned destpos[4] = { ypos, ypos+width, ypos+1, ypos+width+1 };
            for(int n=0; n<4; ++n)
            {
                dest[destpos[n]]
                    = Y_ADD + ((RY * rgb[0][n]
                              + GY * rgb[1][n]
                              + BY * rgb[2][n]
                               ) >> RGB2YUV_SHIFT);  // y
            }
            
            dest[upos++] = (U_ADD + ((RU * c[0] + GU * c[1] + BU * c[2]) >> (RGB2YUV_SHIFT+2)) );
            dest[vpos++] = (V_ADD + ((RV * c[0] + GV * c[1] + BV * c[2]) >> (RGB2YUV_SHIFT+2)) ); 
          }
            
            ypos += 2;
        }
        pos += stride;
        ypos += width;
    }
    
    /*fprintf(stderr, ",yr=%u,ur=%u,vr=%u\n",
        ypos,upos,vpos);*/
    
    #ifdef __MMX__
     MMX_clear();
    #endif
}

template<int PixStride>
void Convert_4byte_To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    const unsigned char* src = (const unsigned char*) data;
    unsigned height = npixels / width;
    unsigned pos = 0;
    unsigned ypos = 0;
    unsigned stride = width*PixStride;

    /* This function is based on code from x264 svn version 711 */
    /* TODO: Apply MMX optimization for 24-bit pixels */
    
    for(unsigned y=0; y<height; ++y)
    {
        for(unsigned x=0; x<width; x += 2)
        {
        #ifdef __MMX__
          if(PixStride == 4)
          {
            c64_MMX p0_1; p0_1.Get(&src[pos]);        // two 32-bit pixels (4*8)
            pos += PixStride*2;
            
            c64_MMX p2_3; p2_3.Get(&src[pos]);        // two 32-bit pixels (4*8)
            pos += PixStride*2;
            x += 2;
            
            Convert_YUY2_MMX_Common(p0_1, p2_3,
                dest+ypos);
          
            ypos += 4;
          }
          else
        #endif
          {
            int c[3], rgb[3][2];
            
            /* luma */
            for(int n=0; n<3; ++n) c[n]  = rgb[n][0] = src[pos + n];
            pos += PixStride;
            
            for(int n=0; n<3; ++n) c[n] += rgb[n][1] = src[pos + n];
            pos += PixStride;

            for(int n=0; n<2; ++n)
            {
                dest[ypos + n*2]
                    = Y_ADD + ((RY * rgb[0][n]
                              + GY * rgb[1][n]
                              + BY * rgb[2][n]
                               ) >> RGB2YUV_SHIFT);  // y
            }
            
            dest[ypos+3] = (U_ADD + ((RU * c[0] + GU * c[1] + BU * c[2]) >> (RGB2YUV_SHIFT+1)) );
            dest[ypos+1] = (V_ADD + ((RV * c[0] + GV * c[1] + BV * c[2]) >> (RGB2YUV_SHIFT+1)) ); 
          }
            ypos += 4;
        }
    }
    #ifdef __MMX__
    MMX_clear();
    #endif
}

/*template<int roffs,int rbits, int goffs,int gbits, int boffs,int bbits>
void Convert_2byte_To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
    __attribute__((noinline));*/
    
template<int roffs,int rbits, int goffs,int gbits, int boffs,int bbits>
void Convert_2byte_To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    const unsigned PixStride = 2;
    const unsigned char* src = (const unsigned char*) data;
    unsigned height = npixels / width;
    unsigned pos = 0;
    unsigned ypos = 0;
    unsigned vpos = npixels;
    unsigned upos = vpos + npixels / 4;
    unsigned stride = width*PixStride;

    /* This function is based on code from x264 svn version 711 */
    
    for(unsigned y=0; y<height; y += 2)
    {
        for(unsigned x=0; x<width; x += 8)
        {
            unsigned char Rgb2byteBuf[2][8][4];
            
            /* Convert 8 pixels from two scanlines (16 in total)
             * from RGB15 / RGB16 to RGB32
             * (Not RGB32, because RGB32 conversion is faster)
             */
            Convert_2byte_to_24or32Common
                <roffs,rbits, goffs,gbits, boffs,bbits, false>
                (src+pos,        Rgb2byteBuf[0][0]);

            Convert_2byte_to_24or32Common
                <roffs,rbits, goffs,gbits, boffs,bbits, false>
                (src+pos+stride, Rgb2byteBuf[1][0]);

            pos += 16;
            
            for(int x8 = 0; x8 < 8; x8 += 2)
            {
              #ifdef _q_MMX__
                c64_MMX p0_1; p0_1.Get(&Rgb2byteBuf[0][x8][0]); // two 32-bit pixels (4*8)
                c64_MMX p2_3; p2_3.Get(&Rgb2byteBuf[1][x8][0]); // two 32-bit pixels

                Convert_I420_MMX_Common(p0_1, p2_3,
                    dest+ypos,
                    dest+ypos+width,
                    dest+upos++,
                    dest+vpos++);
              #else
                int c[3];
                /* TODO: Some faster means than using pointers */
                unsigned char* rgb[4] =
                {
                    Rgb2byteBuf[0][x8+0],
                    Rgb2byteBuf[0][x8+1],
                    Rgb2byteBuf[1][x8+0],
                    Rgb2byteBuf[1][x8+1]
                };
                
                for(int m=0; m<3; ++m) c[m] = 0;
                for(int n=0; n<4; ++n)
                    for(int m=0; m<3; ++m)
                        c[m] += rgb[n][m];
                
                unsigned destpos[4] = { ypos, ypos+1, ypos+width, ypos+width+1 };
                for(int n=0; n<4; ++n)
                {
                    dest[destpos[n]]
                        = Y_ADD + ((RY * rgb[n][0]
                                  + GY * rgb[n][1]
                                  + BY * rgb[n][2]
                                   ) >> RGB2YUV_SHIFT);  // y
                }
                
                /*c[0] /= 4; c[1] /= 4; c[2] /= 4;*/
                // Note: +2 is because c[] contains 4 values
                dest[upos++] = U_ADD + ((RU * c[0] + GU * c[1] + BU * c[2]) >> (RGB2YUV_SHIFT+2));
                dest[vpos++] = V_ADD + ((RV * c[0] + GV * c[1] + BV * c[2]) >> (RGB2YUV_SHIFT+2)); 
              #endif
                ypos += 2;
            }
        }
        pos += stride;
        ypos += width;
    }

    #ifdef __MMX__
    MMX_clear();
    #endif
}

template<int roffs,int rbits, int goffs,int gbits, int boffs,int bbits>
void Convert_2byte_To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    const unsigned PixStride = 2;
    const unsigned char* src = (const unsigned char*) data;
    unsigned height = npixels / width;
    unsigned pos = 0;
    unsigned ypos = 0;
    unsigned stride = width*PixStride;

    for(unsigned y=0; y<height; ++y)
    {
        for(unsigned x=0; x<width; x += 8)
        {
            unsigned char Rgb2byteBuf[8][4];
            
            /* Convert 8 pixels from a scanline
             * from RGB15 / RGB16 to RGB32
             * (Not RGB32, because RGB32 conversion is faster)
             */
            Convert_2byte_to_24or32Common
                <roffs,rbits, goffs,gbits, boffs,bbits, false>
                (src+pos, Rgb2byteBuf[0]);

            pos += 16;
            
            for(int x8 = 0; x8 < 8; )
            {
              #ifdef __MMX__
                c64_MMX p0_1; p0_1.Get(&Rgb2byteBuf[x8  ][0]); // two 32-bit pixels (4*8)
                c64_MMX p2_3; p2_3.Get(&Rgb2byteBuf[x8+2][0]); // two 32-bit pixels (4*8)
                Convert_YUY2_MMX_Common(p0_1, p2_3, dest+ypos);
                x8   += 4;
                ypos += 8;
              #else
                int c[3];
                /* TODO: Some faster means than using pointers */
                unsigned char* rgb[2] =
                {
                    Rgb2byteBuf[x8+0],
                    Rgb2byteBuf[x8+1],
                };
                
                for(int m=0; m<3; ++m) c[m] = 0;
                for(int n=0; n<2; ++n)
                    for(int m=0; m<3; ++m)
                        c[m] += rgb[n][m];
                
                for(int n=0; n<2; ++n)
                {
                    dest[ypos + n*2]
                        = Y_ADD + ((RY * rgb[n][0]
                                  + GY * rgb[n][1]
                                  + BY * rgb[n][2]
                                   ) >> RGB2YUV_SHIFT);  // y
                }
                
                /*c[0] /= 4; c[1] /= 4; c[2] /= 4;*/
                // Note: +2 is because c[] contains 4 values
                dest[ypos+3] = U_ADD + ((RU * c[0] + GU * c[1] + BU * c[2]) >> (RGB2YUV_SHIFT+1));
                dest[ypos+1] = V_ADD + ((RV * c[0] + GV * c[1] + BV * c[2]) >> (RGB2YUV_SHIFT+1)); 
                x8   += 2;
                ypos += 4;
              #endif
            }
        }
    }

    #ifdef __MMX__
    MMX_clear();
    #endif
}


/***/

void Convert_I420To24Frame(const void* data, unsigned char* dest,
                           unsigned npixels, unsigned width, bool swap_red_blue)
{
    const unsigned char* src = (const unsigned char*) data;
    unsigned height = npixels / width;
    unsigned pos = 0;
    unsigned ypos = 0;
    unsigned vpos = npixels;
    unsigned upos = vpos + npixels / 4;

    /*fprintf(stderr, "npixels=%u, width=%u, height=%u, ypos=%u,upos=%u,vpos=%u\n",
        npixels,width,height, ypos,upos,vpos);*/
    
    #ifdef __MMX__
    c64_MMX rgb[4], yy[4];
    static const c64_MMX vmul/*; vmul.Init16*/(VR, VG, 0, 0);  // R,G,B,0 * vmul = V
    static const c64_MMX umul/*; umul.Init16*/(0, UG, UB, 0);  // R,G,B,0 * umul = U
    #endif
    
    /*
        Y input: 16..235
        U input: 16..240
        V input: 16..240
        
    */
    
  #pragma omp parallel for
    for(unsigned y=0; y<height; y += 2)
    {
        for(unsigned x=0; x<width; )
        {
        #ifdef __MMX__
            rgb[0]=rgb[1]=rgb[2]=rgb[3]=yy[0]=yy[1]=yy[2]=yy[3]=c64_MMX(mask64hd)|mask64ld;
            /* Somehow, this line above fixes an error
             * where U&V seem to be off by 4 pixels.
             * Probably a GCC bug? */
            
            /* Load 4 U and V values and subtract U_ADD and V_ADD from them. */
            uint64_t tmp_u = *(uint32_t*)&src[upos];
            uint64_t tmp_v = *(uint32_t*)&src[vpos];
            c64_MMX uuq = c64_MMX(0)
                     .unpacklbw(tmp_u) // 8-bit to 16-bit
                     .sub16(Bits16const<U_ADD,U_ADD>::value)
                     .shl16(16 - YUV2RGB_SHIFT); // shift them so that *13bitconst results in upper 16 bits having the actual value
            c64_MMX vvq = c64_MMX(0)
                     .unpacklbw(tmp_v)
                     .sub16(Bits16const<V_ADD,V_ADD>::value)
                     .shl16(16 - YUV2RGB_SHIFT); // shift them so that *13bitconst results in upper 16 bits having the actual value
            
            const short* uu = (const short*)&uuq;
            const short* vv = (const short*)&vvq;
            
            /* c64_MMX rgb[4]; // four sets of 4*int16, each representing 1 rgb value */
            for(int n=0; n<4; ++n)
            {
                /* vv is shifted by 3 bits, vmul is shifted by 13 bits
                 * 16 bits in total, so mul16hi gets the 16-bit downscaled part */
                c64_MMX v; v.Init16(vv[n]);
                c64_MMX u; u.Init16(uu[n]);
                rgb[n] = v.mul16hi(vmul).add16(
                         u.mul16hi(umul)      );
            }
            
            /* rgb[0] : U,V increment of RGB32 for x0,y0 - x1,y1
             * rgb[1] : U,V increment of RGB32 for x2,y0 - x3,y1
             * rgb[2] : U,V increment of RGB32 for x4,y0 - x5,y1
             * rgb[3] : U,V increment of RGB32 for x6,y0 - x7,y1
             */
            
            unsigned yyoffs[4] = { ypos, ypos+1, ypos+width, ypos+width+1 };
            /* c64_MMX yy[4]; // four sets of 4*int16, each representing four Y values */
            for(int n=0; n<4; ++n)
            {
                c64_MMX luma; luma.Init16(
                    src[yyoffs[0]+n*2],  /* n(0..3): x0y0,x2y0,x4y0,x6y0 */
                    src[yyoffs[1]+n*2],  /* n(0..3): x1y0,x3y0,x5y0,x7y0 */
                    src[yyoffs[2]+n*2],  /* n(0..3): x0y1,x2y1,x4y1,x6y1 */
                    src[yyoffs[3]+n*2]   /* n(0..3): x1y1,x3y1,x5y1,x7y1 */
                );
                luma = luma.sub16(Bits16const<Y_ADD,Y_ADD>::value);
                luma = luma.shl16(16 - YUV2RGB_SHIFT);
                yy[n] = luma.mul16hi(Bits16const<Y_REV,Y_REV>::value);
            }
            const short* const yyval = (const short*) &yy[0].value;
            /*
                values in order:
                   x0y0 x1y0 x0y1 x1y1
                   x2y0 x3y0 x2y1 x3y1
                   x4y0 x5y0 x4y1 x5y1
                   x6y0 x7y0 x6y1 x7y1
            */
            int tmppos = pos;
            for(int ny = 0; ny < 4; ny += 2)
            {
                /* Note: We must use 16-bit pixels here instead of 8-bit,
                 * because the rgb+Y addition can overflow. conv_s16_u8()
                 * does the necessary clamping, which would not be done
                 * if the values were 8-bit.
                 */
                // 8 pixels for one scanline, repeated twice
                /* Note: C++ has no named constructors, so we
                 * use statement blocks here as substitutes.
                 */
                c64_MMX r0
                    = rgb[0].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+0]); tmp; }) )
                           .conv_s16_u8(
                      rgb[0].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+1]); tmp; }) ));
                c64_MMX r1
                    = rgb[1].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+4]); tmp; }) )
                           .conv_s16_u8(
                      rgb[1].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+5]); tmp; }) ));
                c64_MMX r2
                    = rgb[2].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+8]); tmp; }) )
                           .conv_s16_u8(
                      rgb[2].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+9]); tmp; }) ));
                c64_MMX r3
                    = rgb[3].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+12]); tmp; }) )
                           .conv_s16_u8(
                      rgb[3].add16( ({ c64_MMX tmp; tmp.Init16(yyval[ny+13]); tmp; }) ));

                Convert32To24_32bytes(r0,r1,r2,r3, &dest[tmppos]);
                tmppos += width*3; // next line
            }
            upos += 4;
            vpos += 4;
            ypos += 8;   // eight bytes for this line (and eight from next too)
            pos  += 8*3; // eight triplets generated on this line
            x    += 8;   // eight yy values used on this line
        #else /* non-MMX */
            int u = src[upos] - U_ADD;
            int v = src[vpos] - V_ADD;

            int rgb[3] =
                {
                   (VR * v         ) >> (YUV2RGB_SHIFT),
                   (VG * v + UG * u) >> (YUV2RGB_SHIFT),
                   (       + UB * u) >> (YUV2RGB_SHIFT)
                };
            
            unsigned incr[4] = {0,1,width,width+1};

            for(unsigned r=0; r<4; ++r)
                for(unsigned doffs=pos + incr[r]*3, yoffs=ypos + incr[r],
                        yy = (Y_REV * (src[yoffs] - Y_ADD)) >> YUV2RGB_SHIFT,
                        n=0; n<3; ++n)
                    dest[doffs+n] = c64::clamp_u8(rgb[n] + (int)yy);

            upos += 1;
            vpos += 1;
            ypos += 2; // two bytes for this line (two from next line)
            pos  += 2*3; // two triplets generated on this line
            x    += 2; // two yy values used on this line
        #endif
        }
        ypos += width;
        pos += 3*width;
    }
    #ifdef __MMX__
    MMX_clear();
    #endif
}

void Convert_YUY2To24Frame(const void* data, unsigned char* dest,
                           unsigned npixels, unsigned width, bool swap_red_blue)
{
    const unsigned char* src = (const unsigned char*) data;
    unsigned height = npixels / width;
    unsigned pos = 0;
    unsigned ypos = 0;
    
    /* TODO: MMX optimization */
    
    /*
        Y input: 16..235
        U input: 16..240
        V input: 16..240
        
    */
  #pragma omp parallel for
    for(unsigned y=0; y<height; ++y)
    {
        for(unsigned x=0; x<width; x += 2)
        {
            /* non-MMX */
            int u = src[ypos+1] - U_ADD;
            int v = src[ypos+3] - V_ADD;

            int rgb[3] =
                {
                   (VR * v         ) >> (YUV2RGB_SHIFT),
                   (VG * v + UG * u) >> (YUV2RGB_SHIFT),
                   (       + UB * u) >> (YUV2RGB_SHIFT)
                };
            
            for(unsigned r=0; r<2; ++r)
                for(unsigned doffs=pos + r*3, yoffs=ypos+r*2,
                        yy = (Y_REV * (src[yoffs] - Y_ADD)) >> YUV2RGB_SHIFT,
                        n=0; n<3; ++n)
                    dest[doffs+n] = c64::clamp_u8(rgb[n] + (int)yy);

            ypos += 4; // four bytes for this line (y,u,y,v)
            pos  += 2*3; // two triplets generated on this line
            x    += 2; // two yy values used on this line
        }
    }
}

/***/
void Convert24To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_4byte_To_I420Frame<3>(data,dest,npixels,width);
}
void Convert32To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_4byte_To_I420Frame<4>(data,dest,npixels,width);
}
void Convert15To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_2byte_To_I420Frame<10,5, 5,5, 0,5>(data,dest,npixels,width);
}
void Convert16To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_2byte_To_I420Frame<11,5, 5,6, 0,5>(data,dest,npixels,width);
}
/***/
void Convert24To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_4byte_To_YUY2Frame<3>(data,dest,npixels,width);
}
void Convert32To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_4byte_To_YUY2Frame<4>(data,dest,npixels,width);
}
void Convert15To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_2byte_To_YUY2Frame<10,5, 5,5, 0,5>(data,dest,npixels,width);
}
void Convert16To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width)
{
    Convert_2byte_To_YUY2Frame<11,5, 5,6, 0,5>(data,dest,npixels,width);
}
