/* Mednafen - Multi-system Emulator
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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

//
// DO NOT REMOVE/DISABLE THE SANITY TESTS.  THEY EXIST TO DIAGNOSE COMPILER BUGS AND INCORRECT
// COMPILER FLAGS WHICH CAN CAUSE EMULATION GLITCHES AMONG OTHER PROBLEMS, AND TO ENSURE CORRECT
// SEMANTICS IN MEDNAFEN UTILITY FUNCTIONS AS DEVELOPMENT PROGRESSES.
//

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#undef NDEBUG

#include "mednafen.h"
#include "lepacker.h"
#include "tests.h"
#include "testsexp.h"

#include <mednafen/hash/md5.h>
#include <mednafen/hash/sha1.h>
#include <mednafen/hash/sha256.h>
#include <mednafen/hash/crc.h>

#include <mednafen/SimpleBitset.h>

#include <mednafen/cdrom/CDUtility.h>

#include <mednafen/Time.h>

#include <mednafen/jump.h>

#include <time.h>

#include <zlib.h>

// We really don't want NDEBUG defined ;)
#undef NDEBUG
#include <assert.h>
#include <math.h>

#include "psx/masmem.h"
#include "general.h"

#if defined(HAVE_FENV_H)
#include <fenv.h>
#endif

#include <atomic>

#if defined(HAVE_ALTIVEC_INTRINSICS) && defined(HAVE_ALTIVEC_H)
 #include <altivec.h>
#endif

#ifdef HAVE_NEON_INTRINSICS
 #include <arm_neon.h>
#endif

#if defined(HAVE_MMX_INTRINSICS)
 #include <mmintrin.h>
#endif

#ifdef HAVE_SSE_INTRINSICS
 #include <xmmintrin.h>
#endif

namespace Mednafen
{

namespace MDFN_TESTS_CPP
{

static_assert(sizeof(uint8) == 1, "unexpected size");
static_assert(sizeof(int8) == 1, "unexpected size");

static_assert(sizeof(uint16) == 2, "unexpected size");
static_assert(sizeof(int16) == 2, "unexpected size");

static_assert(sizeof(uint32) == 4, "unexpected size");
static_assert(sizeof(int32) == 4, "unexpected size");

static_assert(sizeof(uint64) == 8, "unexpected size");
static_assert(sizeof(int64) == 8, "unexpected size");

static_assert(sizeof(char) == 1, "unexpected size");
static_assert(sizeof(int) == 4, "unexpected size");

static_assert(sizeof(short) >= 2, "unexpected size");
static_assert(sizeof(long) >= 4, "unexpected size");
static_assert(sizeof(long long) >= 8, "unexpected size");
static_assert(sizeof(size_t) >= 4, "unexpected size");

static_assert(sizeof(float) >= 4, "unexpected size");
static_assert(sizeof(double) >= 8, "unexpected size");
static_assert(sizeof(long double) >= 8, "unexpected size");

static_assert(sizeof(void*) >= 4, "unexpected size");
//static_assert(sizeof(void*) >= sizeof(void (*)(void)), "unexpected size");
static_assert(sizeof(uintptr_t) >= sizeof(void*), "unexpected size");

static_assert(sizeof(char) == SIZEOF_CHAR, "unexpected size");
static_assert(sizeof(short) == SIZEOF_SHORT, "unexpected size");
static_assert(sizeof(int) == SIZEOF_INT, "unexpected size");
static_assert(sizeof(long) == SIZEOF_LONG, "unexpected size");
static_assert(sizeof(long long) == SIZEOF_LONG_LONG, "unexpected size");

static_assert(sizeof(off_t) == SIZEOF_OFF_T, "unexpected size");
static_assert(sizeof(ptrdiff_t) == SIZEOF_PTRDIFF_T, "unexpected size");
static_assert(sizeof(size_t) == SIZEOF_SIZE_T, "unexpected size");
static_assert(sizeof(void*) == SIZEOF_VOID_P, "unexpected size");

static_assert((uint8)~0U == 0xFF, "bad uint8 type");
static_assert((int8)0xFF == -1 && (int8)0x7F == 0x7F, "bad int8 type");
static_assert((unsigned char)~0U == 0xFF, "unsigned char type is not 8-bit");

// Make sure the "char" type is signed(pass -fsigned-char to gcc).  New code in Mednafen shouldn't be written with the
// assumption that "char" is signed, but there likely is at least some code that does.
static_assert((char)255 == -1, "char type is not signed 8-bit");


//
//
//
//
//
//
//

// Don't define this static, and don't define it const.  We want these tests to be done at run time, not compile time(although maybe we should do both...).
typedef struct
{
 int bits;
 uint32 negative_one;
 uint32 mostneg;
 int32 mostnegresult;
} MathTestEntry;

#define ADD_MTE(_bits) { _bits, ((uint32)1 << _bits) - 1, (uint32)1 << (_bits - 1), (int32)(0 - ((uint32)1 << (_bits - 1))) }

MathTestEntry math_test_vals[] =
{
 {  9, 0x01FF, 0x0100, -256 },
 { 10, 0x03FF, 0x0200, -512 },
 { 11, 0x07FF, 0x0400, -1024 },
 { 12, 0x0FFF, 0x0800, -2048 },
 { 13, 0x1FFF, 0x1000, -4096 },
 { 14, 0x3FFF, 0x2000, -8192 },
 { 15, 0x7FFF, 0x4000, -16384 },

 ADD_MTE(17),
 ADD_MTE(18),
 ADD_MTE(19),
 ADD_MTE(20),
 ADD_MTE(21),
 ADD_MTE(22),
 ADD_MTE(23),
 ADD_MTE(24),
 ADD_MTE(25),
 ADD_MTE(26),
 ADD_MTE(27),
 ADD_MTE(28),
 ADD_MTE(29),
 ADD_MTE(30),
 ADD_MTE(31),

 { 0, 0, 0, 0 },
};

static void TestSignExtend(void)
{
 MathTestEntry *itoo = math_test_vals;

 assert(sign_9_to_s16(itoo->negative_one) == -1 && sign_9_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_10_to_s16(itoo->negative_one) == -1 && sign_10_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_11_to_s16(itoo->negative_one) == -1 && sign_11_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_12_to_s16(itoo->negative_one) == -1 && sign_12_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_13_to_s16(itoo->negative_one) == -1 && sign_13_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_14_to_s16(itoo->negative_one) == -1 && sign_14_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_15_to_s16(itoo->negative_one) == -1 && sign_15_to_s16(itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(17, itoo->negative_one) == -1 && sign_x_to_s32(17, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(18, itoo->negative_one) == -1 && sign_x_to_s32(18, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(19, itoo->negative_one) == -1 && sign_x_to_s32(19, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(20, itoo->negative_one) == -1 && sign_x_to_s32(20, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(21, itoo->negative_one) == -1 && sign_x_to_s32(21, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(22, itoo->negative_one) == -1 && sign_x_to_s32(22, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(23, itoo->negative_one) == -1 && sign_x_to_s32(23, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(24, itoo->negative_one) == -1 && sign_x_to_s32(24, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(25, itoo->negative_one) == -1 && sign_x_to_s32(25, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(26, itoo->negative_one) == -1 && sign_x_to_s32(26, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(27, itoo->negative_one) == -1 && sign_x_to_s32(27, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(28, itoo->negative_one) == -1 && sign_x_to_s32(28, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(29, itoo->negative_one) == -1 && sign_x_to_s32(29, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(30, itoo->negative_one) == -1 && sign_x_to_s32(30, itoo->mostneg) == itoo->mostnegresult);
 itoo++;

 assert(sign_x_to_s32(31, itoo->negative_one) == -1 && sign_x_to_s32(31, itoo->mostneg) == itoo->mostnegresult);
 itoo++;
}

static NO_INLINE void AntiNSOBugTest_Sub1_a(int *array)
{
 for(int value = 0; value < 127; value++)
  array[value] += (int8)value * 15;
}

static NO_INLINE void AntiNSOBugTest_Sub1_b(int *array)
{
 for(int value = 127; value < 256; value++)
  array[value] += (int8)value * 15;
}

static NO_INLINE void AntiNSOBugTest_Sub2(int *array)
{
 for(int value = 0; value < 256; value++)
  array[value] += (int8)value * 15;
}

static NO_INLINE void AntiNSOBugTest_Sub3(int *array)
{
 for(int value = 0; value < 256; value++)
 {
  if(value >= 128)
   array[value] = (value - 256) * 15;
  else
   array[value] = value * 15;
 }
}

static void DoAntiNSOBugTest(void)
{
 int array1[256], array2[256], array3[256];
 
 memset(array1, 0, sizeof(array1));
 memset(array2, 0, sizeof(array2));
 memset(array3, 0, sizeof(array3));

 AntiNSOBugTest_Sub1_a(array1);
 AntiNSOBugTest_Sub1_b(array1);
 AntiNSOBugTest_Sub2(array2);
 AntiNSOBugTest_Sub3(array3);

 for(int i = 0; i < 256; i++)
 {
  assert((array1[i] == array2[i]) && (array2[i] == array3[i]));
 }
 //for(int value = 0; value < 256; value++)
 // printf("%d, %d\n", (int8)value, ((int8)value) * 15);
}

//
// Related: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=61741
//
// Not found to be causing problems in Mednafen(unlike the earlier no-strict-overflow problem and associated test),
// but better safe than sorry.
//
static NO_INLINE NO_CLONE void DoAntiNSOBugTest2014_SubA(int a)
{
 signed char c = 0;

 for(; a; a--)
 {
  for(; c >= 0; c++)
  {

  }
 }

 assert(c == -128);
}

static int ANSOBT_CallCount;
static NO_INLINE NO_CLONE void DoAntiNSOBugTest2014_SubMx_F(void)
{
 ANSOBT_CallCount++;

 assert(ANSOBT_CallCount < 1000);
}

static NO_INLINE NO_CLONE void DoAntiNSOBugTest2014_SubM1(void)
{
 signed char a;

 for(a = 127 - 1; a >= 0; a++)
  DoAntiNSOBugTest2014_SubMx_F();
}

static NO_INLINE NO_CLONE void DoAntiNSOBugTest2014_SubM3(void)
{
 signed char a;

 for(a = 127 - 3; a >= 0; a++)
  DoAntiNSOBugTest2014_SubMx_F();
}


static void DoAntiNSOBugTest2014(void)
{
 DoAntiNSOBugTest2014_SubA(1);

 ANSOBT_CallCount = 0;
 DoAntiNSOBugTest2014_SubM1();
 assert(ANSOBT_CallCount == 2);

 ANSOBT_CallCount = 0;
 DoAntiNSOBugTest2014_SubM3();
 assert(ANSOBT_CallCount == 4);
}


void DoLEPackerTest(void)
{
 LEPacker mizer;
 static const uint8 correct_result[24] = { 0xed, 0xfe, 0xed, 0xde, 0xaa, 0xca, 0xef, 0xbe, 0xbe, 0xba, 0xfe, 0xca, 0xad, 0xde, 0x01, 0x9a, 0x0c, 0xa7, 0xff, 0x00, 0xff, 0xff, 0x55, 0x7f };

 uint64 u64_test = 0xDEADCAFEBABEBEEFULL;
 uint32 u32_test = 0xDEEDFEED;
 uint16 u16_test = 0xCAAA;
 uint8 u8_test = 0x55;
 int32 s32_test = -5829478;
 int16 s16_test = -1;
 int8 s8_test = 127;

 bool bool_test0 = 0;
 bool bool_test1 = 1;

 mizer ^ u32_test;
 mizer ^ u16_test;
 mizer ^ u64_test;
 mizer ^ bool_test1;
 mizer ^ s32_test;
 mizer ^ bool_test0;
 mizer ^ s16_test;
 mizer ^ u8_test;
 mizer ^ s8_test;

 assert(mizer.size() == 24);

 for(unsigned int i = 0; i < mizer.size(); i++)
 {
  assert(mizer[i] == correct_result[i]);
 }

 u64_test = 0;
 u32_test = 0;
 u16_test = 0;
 u8_test = 0;
 s32_test = 0;
 s16_test = 0;
 s8_test = 0;

 bool_test0 = 1;
 bool_test1 = 0;

 mizer.set_read_mode(true);

 mizer ^ u32_test;
 mizer ^ u16_test;
 mizer ^ u64_test;
 mizer ^ bool_test1;
 mizer ^ s32_test;
 mizer ^ bool_test0;
 mizer ^ s16_test;
 mizer ^ u8_test;
 mizer ^ s8_test;


 assert(u32_test == 0xDEEDFEED);
 assert(u16_test == 0xCAAA);
 assert(u64_test == 0xDEADCAFEBABEBEEFULL);
 assert(u8_test == 0x55);
 assert(s32_test == -5829478);
 assert(s16_test == -1);
 assert(s8_test == 127);
 assert(bool_test0 == 0);
 assert(bool_test1 == 1);
}

struct MathTestTSOEntry
{
 int32 a;
 int32 b;
};

// Don't declare as static(though whopr might mess it up anyway)
MathTestTSOEntry MathTestTSOTests[] =
{
 { 0x7FFFFFFF, 2 },
 { 0x7FFFFFFE, 0x7FFFFFFF },
 { 0x7FFFFFFF, 0x7FFFFFFF },
 { 0x7FFFFFFE, 0x7FFFFFFE },
};

volatile int32 MDFNTestsCPP_SLS_InitVar = (int32)0xDEADBEEF;
volatile int8 MDFNTestsCPP_SLS_InitVar8 = (int8)0xEF;
volatile int16 MDFNTestsCPP_SLS_InitVar16 = (int16)0xBEEF;
volatile int32 MDFNTestsCPP_SLS_Var;
volatile int8 MDFNTestsCPP_SLS_Var8;
volatile int16 MDFNTestsCPP_SLS_Var16;
int32 MDFNTestsCPP_SLS_Var_NT = (int32)0xDEADBEEF;
int32 MDFNTestsCPP_SLS_Var_NT2 = (int32)0x7EADBEEF;

static uint64 NO_INLINE NO_CLONE Mul_U16U16U32U64_Proper(uint16 a, uint16 b)	// For reference
{
 return (uint32)a * (uint32)b;
}

static uint64 NO_INLINE NO_CLONE Mul_U16U16U32U64(uint16 a, uint16 b)
{
 return (uint32)(a * b);
}

void NO_INLINE NO_CLONE TestSignedOverflowSub(void)
{
 assert(Mul_U16U16U32U64_Proper(65535, 65535) == 0xfffe0001ULL);
 assert(Mul_U16U16U32U64(65535, 65535) == 0xfffe0001ULL);

 for(unsigned int i = 0; i < sizeof(MathTestTSOTests) / sizeof(MathTestTSOEntry); i++)
 {
  int32 a = MathTestTSOTests[i].a;
  int32 b = MathTestTSOTests[i].b;

  assert((a + b) < a && (a + b) < b);

  assert((a + 0x7FFFFFFE) < a);
  assert((b + 0x7FFFFFFE) < b);

  assert((a + 0x7FFFFFFF) < a);
  assert((b + 0x7FFFFFFF) < b);

  assert((int32)(a + 0x80000000) < a);
  assert((int32)(b + 0x80000000) < b);

  assert((int32)(a ^ 0x80000000) < a);
  assert((int32)(b ^ 0x80000000) < b);
 }

 for(unsigned i = 0; i < 64; i++)
 {
  MDFNTestsCPP_SLS_Var = (MDFNTestsCPP_SLS_Var << 1) ^ ((MDFNTestsCPP_SLS_Var << 2) + 0x7FFFFFFF) ^ ((MDFNTestsCPP_SLS_Var >> 31) & 0x3);
  MDFNTestsCPP_SLS_Var8 = (MDFNTestsCPP_SLS_Var8 << 1) ^ ((MDFNTestsCPP_SLS_Var8 << 2) + 0x7F) ^ ((MDFNTestsCPP_SLS_Var8 >> 7) & 0x3);
  MDFNTestsCPP_SLS_Var16 = (MDFNTestsCPP_SLS_Var16 << 1) ^ ((MDFNTestsCPP_SLS_Var16 << 2) + 0x7FFF) ^ ((MDFNTestsCPP_SLS_Var16 >> 15) & 0x3);
 }

 {
  int8 a = MDFNTestsCPP_SLS_Var8;
  int16 b = MDFNTestsCPP_SLS_Var16;
  int32 c = MDFNTestsCPP_SLS_Var;
  int64 d = (int64)MDFNTestsCPP_SLS_Var * (int64)MDFNTestsCPP_SLS_Var;
  int32 e = c;
  int64 f = c;

  for(int i = 0; i < 64; i++)
  {
   a += a * i + b;
   b += b * i + c;
   c += c * i + d;
   d += d * i + a;

   e += e * i + c;
   f += f * i + c;
  }
  //printf("%08x %16llx - %02x %04x %08x %16llx\n", (uint32)e, (uint64)f, (uint8)a, (uint16)b, (uint32)c, (uint64)d);
  assert((uint32)e == (uint32)f && (uint32)e == 0x00c37de2 && (uint64)f == 0x5d17261900c37de2);
  assert((uint8)a == 0xbf);
  assert((uint16)b == 0xb77c);
  assert((uint32)c == 0xb4244622U);
  assert((uint64)d == 0xa966e02ed95c83fULL);
 }


 //printf("%02x %04x %08x\n", (uint8)MDFNTestsCPP_SLS_Var8, (uint16)MDFNTestsCPP_SLS_Var16, (uint32)MDFNTestsCPP_SLS_Var);
 assert((uint8)MDFNTestsCPP_SLS_Var8 == 0x04);
 assert((uint16)MDFNTestsCPP_SLS_Var16 == 0xa7d8);
 assert((uint32)MDFNTestsCPP_SLS_Var == 0x4ef11a23);

 for(signed i = 1; i != 0; i =~-i);	// Not really signed overflow, but meh!
 for(signed i = -1; i != 0; i <<= 1);
 for(signed i = 1; i >= 0; i *= 3);

 if(MDFNTestsCPP_SLS_Var_NT < 0)
  assert((MDFNTestsCPP_SLS_Var_NT << 2) > 0);

 if(MDFNTestsCPP_SLS_Var_NT2 > 0)
  assert((MDFNTestsCPP_SLS_Var_NT2 << 2) < 0);
}

static void TestSignedOverflow(void)
{
 MDFNTestsCPP_SLS_Var = MDFNTestsCPP_SLS_InitVar;
 MDFNTestsCPP_SLS_Var8 = MDFNTestsCPP_SLS_InitVar8;
 MDFNTestsCPP_SLS_Var16 = MDFNTestsCPP_SLS_InitVar16;

 TestSignedOverflowSub();
}

unsigned MDFNTests_OverShiftAmounts[3] = { 8, 16, 32};
uint32 MDFNTests_OverShiftTV = 0xBEEFD00D;
static void TestDefinedOverShift(void)
{
 //for(unsigned sa = 0; sa < 4; sa++)
 {
  for(unsigned i = 0; i < 2; i++)
  {
   uint8 v8 = MDFNTests_OverShiftTV;
   uint16 v16 = MDFNTests_OverShiftTV;
   uint32 v32 = MDFNTests_OverShiftTV;

   int8 iv8 = MDFNTests_OverShiftTV;
   int16 iv16 = MDFNTests_OverShiftTV;
   int32 iv32 = MDFNTests_OverShiftTV;

   if(i == 1)
   {
    v8 >>= MDFNTests_OverShiftAmounts[0];
    v16 >>= MDFNTests_OverShiftAmounts[1];
    v32 = (uint64)v32 >> MDFNTests_OverShiftAmounts[2];

    iv8 >>= MDFNTests_OverShiftAmounts[0];
    iv16 >>= MDFNTests_OverShiftAmounts[1];
    iv32 = (int64)iv32 >> MDFNTests_OverShiftAmounts[2];
   }
   else
   {
    v8 <<= MDFNTests_OverShiftAmounts[0];
    v16 <<= MDFNTests_OverShiftAmounts[1];
    v32 = (uint64)v32 << MDFNTests_OverShiftAmounts[2];

    iv8 <<= MDFNTests_OverShiftAmounts[0];
    iv16 <<= MDFNTests_OverShiftAmounts[1];
    iv32 = (int64)iv32 << MDFNTests_OverShiftAmounts[2];
   }

   assert(v8 == 0);
   assert(v16 == 0);
   assert(v32 == 0);

   assert(iv8 == 0);
   assert(iv16 == -(int)i);
   assert(iv32 == -(int)i);
  }
 }
}

static MDFN_COLD NO_INLINE uint8 BoolConvSupportFunc(void)
{
 return 0xFF;
}

static MDFN_COLD NO_INLINE bool BoolConv0(void)
{
 return BoolConvSupportFunc() & 1;
}

static MDFN_COLD NO_INLINE void BoolTestThing(unsigned val)
{
 if(val != 1)
  printf("%u\n", val);

 assert(val == 1);
}

static void TestBoolConv(void)
{
 BoolTestThing(BoolConv0());
}

static NO_INLINE MDFN_COLD void TestNarrowConstFold(void)
{
 unsigned sa = 8;
 uint8 za[1] = { 0 };
 int a;

 a = za[0] < (uint8)(1 << sa);

 assert(a == 0);
}


unsigned MDFNTests_ModTern_a = 2;
unsigned MDFNTests_ModTern_b = 0;
static NO_INLINE MDFN_COLD void ModTernTestEval(unsigned v)
{
 assert(v == 0);
}

static NO_INLINE MDFN_COLD void TestModTern(void)
{
 if(!MDFNTests_ModTern_b)
 {
  MDFNTests_ModTern_b = MDFNTests_ModTern_a;

  if(1 % (MDFNTests_ModTern_a ? MDFNTests_ModTern_a : 2))
   MDFNTests_ModTern_b = 0;
 }
 ModTernTestEval(MDFNTests_ModTern_b);
}

static NO_INLINE NO_CLONE int TestBWNotMask31GTZ_Sub(int a)
{
 a = (((~a) & 0x80000000LL) > 0) + 1;
 return a;
}

static void TestBWNotMask31GTZ(void)
{
 assert(TestBWNotMask31GTZ_Sub(0) == 2);
}

int MDFN_tests_TestTernary_val = 0;
void NO_INLINE NO_CLONE TestTernary_Sub2(void)
{
 MDFN_tests_TestTernary_val++;
}

void NO_INLINE NO_CLONE TestTernary_Sub1(void)
{
 int a = ((MDFN_tests_TestTernary_val++) ? (MDFN_tests_TestTernary_val = 20) : (TestTernary_Sub2(), MDFN_tests_TestTernary_val));

 assert(a == 2);
}

static void TestTernary(void)
{
 MDFN_tests_TestTernary_val = 0;
 TestTernary_Sub1();
}

size_t TestLLVM15470_Counter;
void NO_INLINE NO_CLONE TestLLVM15470_Sub2(size_t x)
{
 assert(x == TestLLVM15470_Counter);
 TestLLVM15470_Counter++;
}

void NO_INLINE NO_CLONE TestLLVM15470_Sub(size_t m)
{
 size_t m2 = ~(size_t)0;

 for(size_t i = 1; i <= 4; i *= m)
  m2++;

 for(size_t a = 0; a < 2; a++)
 {
  for(size_t b = 1; b <= 2; b++)
  {
   TestLLVM15470_Sub2(a * m2 + b);
  }
 }
}

void NO_INLINE NO_CLONE TestLLVM15470(void)
{
 TestLLVM15470_Counter = 1;
 TestLLVM15470_Sub(2);
}

int NO_INLINE NO_CLONE TestGCC60196_Sub(const int16* data, int count)
{
 int ret = 0;

 for(int i = 0; i < count; i++)
  ret += i * data[i];

 return ret;
}

void NO_INLINE NO_CLONE TestGCC60196(void)
{
 int16 ta[16];

 for(unsigned i = 0; i < 16; i++)
  ta[i] = 1;

 assert(TestGCC60196_Sub(ta, sizeof(ta) / sizeof(ta[0])) == 120);
}


uint16 gcc69606_var = 0;
int32 NO_INLINE NO_CLONE TestGCC69606_Sub(int8 a, uint8 e)
{
 int32 f = 1;
 int32 mod = ~(int32)a;
 int32 d = 0;

 if(gcc69606_var > f)
 {
  e = gcc69606_var;
  d = gcc69606_var | e;
  mod = 8;
 }

 return (7 + d) % mod;
}

void NO_INLINE NO_CLONE TestGCC69606(void)
{
 assert(TestGCC69606_Sub(0, 0) == 0);
}

int8 gcc70941_array[2] = { 0, 0 };
void NO_INLINE NO_CLONE TestGCC70941(void)
{
 int8 tmp = (0x7F - gcc70941_array[0] - ((gcc70941_array[0] && gcc70941_array[1]) ^ 0x8080));

 assert(tmp == -1);
}

void NO_INLINE NO_CLONE TestGCC71488_Sub(long long* p, int v)
{
 for(unsigned i = 0; i < 4; i++)
  p[i] = ((!p[4]) > (unsigned)!v) + !p[4];
}

void NO_INLINE NO_CLONE TestGCC71488(void)
{
 long long p[5] = { 0, 0, 0, 0, 0 };

 TestGCC71488_Sub(p, 1);

 assert(p[0] == 2 && p[1] == 2 && p[2] == 2 && p[3] == 2 && p[4] == 0);
}

int NO_INLINE NO_CLONE TestGCC80631_Sub(int* p)
{
 int ret = -1;

 for(int i = 0; i < 8; i++)
  if(p[i])
   ret = i;

 return ret;
}

void NO_INLINE NO_CLONE TestGCC80631(void)
{
 int p[32];

 for(int i = 0; i < 32; i++)
  p[i] = (i == 0 || i >= 8);

 assert(TestGCC80631_Sub(p) == 0);
}

NO_INLINE NO_CLONE void TestGCC81740_Sub(int* p, unsigned count)
{
 static const int good[20] = { 0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 10, 5, 6, 7, 8, 15, 10, 11, 12, 13 };

 assert(count == 20);

 for(unsigned i = 0; i < count; i++)
  assert(good[i] == p[i]);
}

int TestGCC81740_b;

NO_INLINE NO_CLONE void TestGCC81740(void)
{
 int v[4][5] = { { 0 } };

 for(unsigned i = 0; i < sizeof(v) / sizeof(int); i++)
  MDAP(v)[i] = i;

 for(int a = 3; a >= 0; a--)
  for(TestGCC81740_b = 0; TestGCC81740_b < 3; TestGCC81740_b++)
   v[TestGCC81740_b + 1][a + 1] = v[TestGCC81740_b][a];

 TestGCC81740_Sub(MDAP(v), sizeof(v) / sizeof(int));
}

NO_INLINE NO_CLONE int TestGCC86927_Sub(void)
{
 int data[4] = { 0, 0, 0, -1 };
 int ret = true;

 for(size_t i = 0; i < 4; i++)
  if(data[3 - i] < 0)
   ret = false;

 return ret;
}

NO_INLINE NO_CLONE void TestGCC86927(void)
{
 assert(!TestGCC86927_Sub());
}

NO_INLINE NO_CLONE int TestGCC97760_Sub(void)
{
 int v = 0;

 for(int i = 0, j = 0; i < 8; i++, j += i >> 1)
  v = ++j;

 return v;
}

NO_INLINE NO_CLONE void TestGCC97760(void)
{
 assert(TestGCC97760_Sub() == 20);
}


NO_INLINE NO_CLONE uint16 TestGCC98640_Sub0(uint16 v, int16* g)
{
 *g = v + 1;
 return (int8)v + 1;
}

NO_INLINE NO_CLONE uint32 TestGCC98640_Sub1(uint32 v, int32* g)
{
 *g = v + 1;
 return (int16)v + 1;
}

NO_INLINE NO_CLONE uint64 TestGCC98640_Sub2(uint64 v, int64* g)
{
 *g = v + 1;
 return (int32)v + 1;
}

NO_INLINE NO_CLONE void TestGCC98640(void)
{
 int16 dummy16;
 int32 dummy32;
 int64 dummy64;

 assert(TestGCC98640_Sub0((uint16)1 <<  8, &dummy16) == 1);
 assert(TestGCC98640_Sub1((uint32)1 << 16, &dummy32) == 1);
 assert(TestGCC98640_Sub2((uint64)1 << 32, &dummy64) == 1);
}

template<typename A, typename B>
void NO_INLINE NO_CLONE TestSUCompare_Sub(A a, B b)
{
 assert(a < b);
}

int16 TestSUCompare_x0 = 256;

void NO_INLINE NO_CLONE TestSUCompare(void)
{
 int8 a = 1;
 uint8 b = 255;
 int16 c = 1;
 uint16 d = 65535;
 int32 e = 1;
 uint32 f = ~0U;
 int64 g = (uint32)-1;
 uint64 h = (uint64)-1;

 assert(a < b);
 assert(c < d);
 assert((uint32)e < f);
 assert((uint64)g < h);

 TestSUCompare_Sub<int8, uint8>(1, 255);
 TestSUCompare_Sub<int16, uint16>(1, 65535);

 TestSUCompare_Sub<int8, uint8>(TestSUCompare_x0, 255);
}

template<typename T>
NO_INLINE NO_CLONE void CheckAlignasType_Sub(void* p)
{
 assert(((uintptr_t)p % alignof(T)) == 0);
}

template<size_t I>
NO_INLINE NO_CLONE void CheckAlignasI_Sub(void* p)
{
 assert(((uintptr_t)p % I) == 0);
}

template<typename T>
NO_INLINE NO_CLONE void CheckAlignasType(void)
{
 alignas(alignof(T)) uint8 lv0[sizeof(T) + 1];
 alignas(alignof(T)) uint8 lv1[sizeof(T) + 1];
 alignas(alignof(T)) static uint8 gv0[sizeof(T) + 1];
 alignas(alignof(T)) static uint8 gv1[sizeof(T) + 1];

 CheckAlignasType_Sub<T>((void*)lv0);
 CheckAlignasType_Sub<T>((void*)lv1);
 CheckAlignasType_Sub<T>((void*)gv0);
 CheckAlignasType_Sub<T>((void*)gv1);
}

template<size_t I>
NO_INLINE NO_CLONE void CheckAlignasI(void)
{
 alignas(I) uint8 lv0[I + 1];
 alignas(I) uint8 lv1[I + 1];
 alignas(I) static uint8 gv0[I + 1];
 alignas(I) static uint8 gv1[I + 1];

 CheckAlignasI_Sub<I>((void*)lv0);
 CheckAlignasI_Sub<I>((void*)lv1);
 CheckAlignasI_Sub<I>((void*)gv0);
 CheckAlignasI_Sub<I>((void*)gv1);
}

static void DoAlignmentChecks(void)
{
 static_assert(alignof(uint8) <= sizeof(uint8), "Alignment of type is greater than size of type.");
 static_assert(alignof(uint16) <= sizeof(uint16), "Alignment of type is greater than size of type.");
 static_assert(alignof(uint32) <= sizeof(uint32), "Alignment of type is greater than size of type.");
 static_assert(alignof(uint64) <= sizeof(uint64), "Alignment of type is greater than size of type.");

 CheckAlignasType<uint16>();
 CheckAlignasType<uint32>();
 CheckAlignasType<uint64>();
 CheckAlignasType<float>();
 CheckAlignasType<double>();

#if defined(ARCH_X86)
 CheckAlignasI<16>();
#endif

#if defined(HAVE_MMX_INTRINSICS)
 CheckAlignasType<__m64>();
#endif

#if defined(HAVE_SSE_INTRINSICS)
 CheckAlignasType<__m128>();
#endif

#if defined(HAVE_ALTIVEC_INTRINSICS)
 CheckAlignasType<vector unsigned int>();
 CheckAlignasType<vector unsigned short>();
#endif

#ifdef HAVE_NEON_INTRINSICS
 CheckAlignasType<int16x4_t>();
 CheckAlignasType<int32x4_t>();
 CheckAlignasType<float32x4_t>();
#endif
}

static uint32 NO_INLINE NO_CLONE RunMASMemTests_DoomAndGloom(uint32 offset)
{
 MultiAccessSizeMem<4, false> mt0;

 mt0.WriteU32(offset, 4);
 mt0.WriteU16(offset, 0);
 mt0.WriteU32(offset, mt0.ReadU32(offset) + 1);

 return mt0.ReadU32(offset);
}

static void RunMASMemTests(void)
{
 // Little endian:
 {
  MultiAccessSizeMem<4, false> mt0;

  mt0.WriteU16(0, 0xDEAD);
  mt0.WriteU32(0, 0xCAFEBEEF);
  mt0.WriteU16(2, mt0.ReadU16(0));
  mt0.WriteU8(1, mt0.ReadU8(0));
  mt0.WriteU16(2, mt0.ReadU16(0));
  mt0.WriteU32(0, mt0.ReadU32(0) + 0x13121111);

  assert(mt0.ReadU16(0) == 0x0100 && mt0.ReadU16(2) == 0x0302);
  assert(mt0.ReadU32(0) == 0x03020100);
 
  mt0.WriteU32(0, 0xB0B0AA55);
  mt0.WriteU24(0, 0xDEADBEEF);
  assert(mt0.ReadU32(0) == 0xB0ADBEEF);
  assert(mt0.ReadU24(1) == 0x00B0ADBE);
 }

 // Big endian:
 {
  MultiAccessSizeMem<4, true> mt0;

  mt0.WriteU16(2, 0xDEAD);
  mt0.WriteU32(0, 0xCAFEBEEF);
  mt0.WriteU16(0, mt0.ReadU16(2));
  mt0.WriteU8(2, mt0.ReadU8(3));
  mt0.WriteU16(0, mt0.ReadU16(2));
  mt0.WriteU32(0, mt0.ReadU32(0) + 0x13121111);

  assert(mt0.ReadU16(2) == 0x0100 && mt0.ReadU16(0) == 0x0302);
  assert(mt0.ReadU32(0) == 0x03020100);
 
  mt0.WriteU32(0, 0xB0B0AA55);
  mt0.WriteU24(1, 0xDEADBEEF);
  assert(mt0.ReadU32(0) == 0xB0ADBEEF);
  assert(mt0.ReadU24(0) == 0x00B0ADBE);
 }

 assert(RunMASMemTests_DoomAndGloom(0) == 1);
}


void NO_INLINE NO_CLONE RunMiscEndianTests_Sub(uint32 v, volatile uint16* a)
{
 *a = (v << 24) | (v >> 24) | ((v << 8) & 0xFF0000) | ((v >> 8) & 0xFF00);
}

static void NO_INLINE NO_CLONE RunMiscEndianTests(uint32 arg0, uint32 arg1)
{
 uint8 mem[8];

 memset(mem, 0xFF, sizeof(mem));

 MDFN_en24msb(&mem[0], arg0);
 MDFN_en24lsb(&mem[4], arg1);

 assert(MDFN_de32lsb(&mem[0]) == 0xFF030201);
 assert(MDFN_de32lsb(&mem[4]) == 0xFF030201);

 assert(MDFN_de32msb(&mem[0]) == 0x010203FF);
 assert(MDFN_de32msb(&mem[4]) == 0x010203FF);

 assert(MDFN_de32lsb(&mem[0]) == 0xFF030201);
 assert(MDFN_de32msb(&mem[4]) == 0x010203FF);

 assert(MDFN_de24lsb(&mem[0]) == 0x030201);
 assert(MDFN_de24lsb(&mem[4]) == 0x030201);

 assert(MDFN_de24msb(&mem[0]) == 0x010203);
 assert(MDFN_de24msb(&mem[4]) == 0x010203);

 assert(MDFN_de24lsb(&mem[1]) == 0xFF0302);
 assert(MDFN_de24lsb(&mem[5]) == 0xFF0302);

 assert(MDFN_de24msb(&mem[1]) == 0x0203FF);
 assert(MDFN_de24msb(&mem[5]) == 0x0203FF);

 assert(MDFN_de64lsb(&mem[0]) == 0xFF030201FF030201ULL);
 assert(MDFN_de64msb(&mem[0]) == 0x010203FF010203FFULL);
 //
 //
 //
 uint16 mem16[8] = { 0x1122, 0x3344, 0x5566, 0x7788, 0x99AA, 0xBBCC, 0xDDEE, 0xFF00 };

 for(unsigned i = 0; i < 8; i++)
 {
  assert(ne16_rbo_le<uint16>(mem16, i << 1) == mem16[i]);
  assert(ne16_rbo_be<uint16>(mem16, i << 1) == mem16[i]);
 }

 for(unsigned i = 0; i < 4; i++)
 {
  assert(ne16_rbo_le<uint32>(mem16, i * 4) == (uint32)(mem16[i * 2] | (mem16[i * 2 + 1] << 16)));
  assert(ne16_rbo_be<uint32>(mem16, i * 4) == (uint32)(mem16[i * 2 + 1] | (mem16[i * 2] << 16)));
 }

 for(unsigned i = 0; i < 16; i++)
 {
  assert(ne16_rbo_le<uint8>(mem16, i) == (uint8)(mem16[i >> 1] >> ((i & 1) * 8)));
  assert(ne16_rbo_be<uint8>(mem16, i) == (uint8)(mem16[i >> 1] >> (8 - ((i & 1) * 8))));
 }

 ne16_rwbo_le<uint16, false>(mem16, 0, &mem16[7]);
 ne16_rwbo_le<uint16, true>(mem16, 0, &mem16[6]);
 ne16_rwbo_be<uint16, false>(mem16, 4, &mem16[3]);
 ne16_rwbo_be<uint16, true>(mem16, 4, &mem16[1]);

 assert(mem16[7] == 0x1122);
 assert(mem16[0] == 0xDDEE);
 assert(mem16[3] == 0x5566);
 assert(mem16[2] == 0x3344);

 {
  uint64 v64 = 0xDEADBEEFCAFEBABEULL;

  for(unsigned i = 0; i < 8; i++)
  {
   if(!(i & 0x7))
   {
    assert(ne64_rbo_be<uint64>(&v64, i) == v64);
    assert(ne64_rbo_le<uint64>(&v64, i) == v64);
   }

   if(!(i & 0x3))
   {
    assert(ne64_rbo_be<uint32>(&v64, i) == (uint32)(v64 >> (32 - i * 8)));
    assert(ne64_rbo_le<uint32>(&v64, i) == (uint32)(v64 >> (i * 8)));
   }

   if(!(i & 0x1))
   {
    assert(ne64_rbo_be<uint16>(&v64, i) == (uint16)(v64 >> (48 - i * 8)));
    assert(ne64_rbo_le<uint16>(&v64, i) == (uint16)(v64 >> (i * 8)));
   }

   assert(ne64_rbo_be<uint8>(&v64, i) == (uint8)(v64 >> (56 - i * 8)));
   assert(ne64_rbo_le<uint8>(&v64, i) == (uint8)(v64 >> (i * 8)));
  }

  ne64_wbo_be<uint64>(&v64, 0, 0xCAFEBABEDEADBEEF);
  assert(v64 == 0xCAFEBABEDEADBEEF);
  ne64_wbo_le<uint32>(&v64, 0, 0xD00FDAD0);
  ne64_wbo_be<uint16>(&v64, 0, 0xF00D);
  uint8 z[2] = { 0xC0, 0xBB };
  ne64_rwbo_be<uint8, true>(&v64, 2, &z[0]);
  ne64_rwbo_le<uint8, true>(&v64, 4, &z[1]);

  ne64_rwbo_le<uint8, false>(&v64, 5, &z[0]);
  ne64_rwbo_be<uint8, false>(&v64, 3, &z[1]);

  assert(z[0] == 0xC0 && z[1] == 0xBB);
  assert(v64 == 0xF00DC0BBD00FDAD0ULL);
 }

 //
 //
 //
 for(unsigned i = 0; i < 8; i++)
 {
  for(unsigned z = 0; z < 8; z++)
   mem[z] = z;

  #ifdef LSB_FIRST
  Endian_V_NE_BE(mem, i);
  #else
  Endian_V_NE_LE(mem, i);
  #endif

  for(unsigned z = 0; z < 8; z++)
   assert(mem[z] == ((z >= i) ? z : (i - 1 - z)));
 }
 //
 //
 //
 {
  volatile uint16 greatzorb[2] = { 0x0123, 0x4567 };

  RunMiscEndianTests_Sub(0xA55ADEAD, greatzorb);

  assert(greatzorb[0] == 0x5AA5);
  assert(greatzorb[1] == 0x4567);
 }
}

std::vector<int> stltests_vec[2];

static void NO_INLINE NO_CLONE RunSTLTests_Sub0(int v)
{
 stltests_vec[0].assign(v, v);
}

static void RunSTLTests(void)
{
 assert(stltests_vec[0] == stltests_vec[1]);
 RunSTLTests_Sub0(0);
 assert(stltests_vec[0] == stltests_vec[1]);
 RunSTLTests_Sub0(1);
 RunSTLTests_Sub0(0);
 assert(stltests_vec[0] == stltests_vec[1]);
}

static void LZTZCount_Test(void)
{
 for(uint32 i = 0, x = 0; i < 33; i++, x = (x << 1) + 1)
 {
  assert(MDFN_tzcount16(~x) == std::min<uint32>(16, i));
  assert(MDFN_tzcount32(~x) == i);
  assert(MDFN_lzcount32(x) == 32 - i);
 }

 for(uint32 i = 0, x = 0; i < 33; i++, x = (x ? (x << 1) : 1))
 {
  assert(MDFN_tzcount16(x) == (std::min<uint32>(17, i) + 16) % 17);
  assert(MDFN_tzcount32(x) == (i + 32) % 33);
  assert(MDFN_lzcount32(x) == 32 - i);
 }

 for(uint64 i = 0, x = 0; i < 65; i++, x = (x << 1) + 1)
 {
  assert(MDFN_tzcount64(~x) == i);
  assert(MDFN_lzcount64(x) == 64 - i);
 }

 for(uint64 i = 0, x = 0; i < 65; i++, x = (x ? (x << 1) : 1))
 {
  assert(MDFN_tzcount64(x) == (i + 64) % 65);
  assert(MDFN_lzcount64(x) == 64 - i);
 }

 uint32 tv = 0;
 for(uint32 i = 0, x = 1; i < 200; i++, x = (x * 9) + MDFN_lzcount32(x) + MDFN_lzcount32(x >> (x & 31)))
 {
  tv += x;
 }
 assert(tv == 0x397d920f);

 uint64 tv64 = 0;
 for(uint64 i = 0, x = 1; i < 200; i++, x = (x * 9) + MDFN_lzcount64(x) + MDFN_lzcount64(x >> (x & 63)))
 {
  tv64 += x;
 }
 assert(tv64 == 0x7b8263de01922c29);
}

// don't make this static, and don't make it local scope.  Whole-program optimization might defeat the purpose of this, though...
unsigned int mdfn_shifty_test[4] =
{
 0, 8, 16, 32
};


// Don't make static.
MDFN_COLD NO_INLINE double mdfn_fptest0_sub(double x, double n)
{
 double u = x / (n * n);

 return(u);
}

static void fptest0(void)
{
 assert(mdfn_fptest0_sub(36, 2) == 9);
}

volatile double mdfn_fptest1_v;
static void fptest1(void)
{
 mdfn_fptest1_v = 1.0;

 for(int i = 0; i < 128; i++)
  mdfn_fptest1_v *= 2;

 assert(mdfn_fptest1_v == 340282366920938463463374607431768211456.0);
}

#if defined(HAVE_FENV_H) && defined(HAVE_NEARBYINTF)
// For advisory/debug purposes, don't error out on failure.
static void libc_rounding_test(void)
{
 unsigned old_rm = fegetround();
 float tv = 4118966.75;
 float goodres = 4118967.0;
 float res;

 fesetround(FE_TONEAREST);

 if((res = nearbyintf(tv)) != goodres)
  fprintf(stderr, "\n***** Buggy libc nearbyintf() detected(%f != %f). *****\n\n", res, goodres);

 fesetround(old_rm);
}
#else
static void libc_rounding_test(void)
{

}
#endif

static NO_INLINE NO_CLONE int pow_test_sub_a(int y, double z)
{
 return std::min<int>(floor(pow(10, z)), std::min<int>(floor(pow(10, y)), (int)pow(10, y)));
}

static NO_INLINE NO_CLONE int pow_test_sub_b(int y)
{
 return std::min<int>(floor(pow(2, y)), (int)pow(2, y));
}

static void pow_test(void)
{
 unsigned muller10 = 1;
 unsigned muller2 = 1;

 for(int y = 0; y < 10; y++, muller10 *= 10, muller2 <<= 1)
 {
  unsigned res10 = pow_test_sub_a(y, y);
  unsigned res2 = pow_test_sub_b(y);

  //printf("%u %u\n", res10, res2);

  assert(res10 == muller10);
  assert(res2 == muller2);
 }
}

static void RunFPTests(void)
{
 fptest0();
 fptest1();

 libc_rounding_test();
 pow_test();
}

static void NO_CLONE NO_INLINE NE1664_Test_Sub(uint16* buf)
{
 ne16_wbo_be<uint8>(buf, 3, 0xAA);
 ne16_wbo_be<uint16>(buf, 2, 0xDEAD);
 ne16_wbo_be<uint32>(buf, 0, 0xCAFEBEEF);
 ne16_wbo_be<uint32>(buf, 0, ne16_rbo_be<uint16>(buf, 2) ^ ne16_rbo_be<uint16>(buf, 0));
 ne16_wbo_be<uint16>(buf, 0, ne16_rbo_be<uint16>(buf, 0) ^ ne16_rbo_be<uint16>(buf, 2));
}

static void NO_CLONE NO_INLINE NE1664_Test_Sub64(uint64* buf)
{
 ne64_wbo_be<uint16>(buf, 0, 0x1111);
 ne64_wbo_be<uint16>(buf, 2, 0x2222);
 ne64_wbo_be<uint16>(buf, 4, 0x4444);
 ne64_wbo_be<uint16>(buf, 6, 0x6666);

 ne64_wbo_be<uint32>(buf, 0, 0x33333333);
 ne64_wbo_be<uint32>(buf, 4, 0x77777777);

 *buf += ne64_rbo_be<uint16>(buf, 0) + ne64_rbo_be<uint16>(buf, 2) + ne64_rbo_be<uint16>(buf, 4) + ne64_rbo_be<uint16>(buf, 6);
}

static void NE1664_Test(void)
{
 uint16 buf[2] = { 0, 0 };
 uint64 var64 = 0xDEADBEEFCAFEF00DULL;

 NE1664_Test_Sub(buf);
 NE1664_Test_Sub64(&var64);

 assert((buf[0] == buf[1]) && buf[0] == 0x7411);
 assert(var64 == 0x333333337778CCCBULL);
}

static void zlib_test(void)
{
 auto cfl = zlibCompileFlags();

 assert((2 << ((cfl >> 0) & 0x3)) == sizeof(uInt));
 assert((2 << ((cfl >> 2) & 0x3)) == sizeof(uLong));
 assert((2 << ((cfl >> 4) & 0x3)) == sizeof(voidpf));

 #ifdef Z_LARGE64
 if((2 << ((cfl >> 6) & 0x3)) != sizeof(z_off_t))
 {
  assert(sizeof(z_off64_t) == 8);
  assert(&gztell == &gztell64);
 }
 #else
 assert((2 << ((cfl >> 6) & 0x3)) == sizeof(z_off_t));
 #endif
}

static NO_INLINE NO_CLONE void memops_test_sub(uint8* mem8)
{
 for(unsigned offs = 0; offs < 8; offs++)
 {
  for(unsigned len = 1; len < 32; len++)
  {
   memset(mem8, 0x88, 64);

   MDFN_FastArraySet(&mem8[offs], 0x55, len); 

   for(unsigned i = 0; i < 64; i++)
   {
    if(i < offs || i >= (offs + len))
     assert(mem8[i] == 0x88);
    else
     assert(mem8[i] == 0x55);
   }
  }
 }
}

static void memops_test(void)
{
 uint8 mem8[64];

 memops_test_sub(mem8);
}

static void TestLog2(void)
{
 static const struct
 {
  uint64 val;
  unsigned expected;
 } log2_test_vals[] =
 {
  { 0, 0 },
  { 1, 0 },
  { 2, 1 },
  { 3, 1 },
  { 4, 2 },
  { 5, 2 },
  { 6, 2 },
  { 7, 2 },
  { 4095, 11 },
  { 4096, 12 },
  { 4097, 12 },
  { 0x7FFE, 14 },
  { 0x7FFF, 14 },
  { 0x8000, 15 },
  { 0x8001, 15 },
  { 0xFFFF, 15 },
  { 0x7FFFFFFF, 30 },
  { 0x80000000, 31 },
  { 0xFFFFFFFF, 31 },
  { 0x7FFFFFFFFFFFFFFEULL, 62 },
  { 0x7FFFFFFFFFFFFFFFULL, 62 },
  { 0x8000000000000000ULL, 63 },
  { 0x8000000000000001ULL, 63 },
  { 0x8AAAAAAAAAAAAAAAULL, 63 },
  { 0xFFFFFFFFFFFFFFFFULL, 63 },
 };

 for(const auto& tv : log2_test_vals)
 {
  if((uint32)tv.val == tv.val)
  {
   assert(MDFN_log2((uint32)tv.val) == tv.expected);
   assert(MDFN_log2((int32)tv.val) == tv.expected);  
  }

  assert(MDFN_log2((uint64)tv.val) == tv.expected);
  assert(MDFN_log2((int64)tv.val) == tv.expected);  
 }
}

static void TestRoundPow2(void)
{
 static const struct
 {
  uint64 val;
  uint64 expected;
 } rup2_test_vals[] =
 {
  { 0, 1 },
  { 1, 1 },
  { 2, 2 },
  { 3, 4 },
  { 4, 4 },
  { 5, 8 },
  { 7, 8 },
  { 8, 8 },
  {      0x7FFF,         0x8000 },
  {      0x8000,         0x8000 },
  {      0x8001,        0x10000 },
  {     0x10000,        0x10000 },
  {     0x10001,        0x20000 },
  {  0x7FFFFFFF,     0x80000000 },
  {  0x80000000,     0x80000000 },
  {  0x80000001,    0x100000000ULL },
  { 0x100000000ULL, 0x100000000ULL },
  { 0x100000001ULL, 0x200000000ULL },
  { 0xFFFFFFFFFFFFFFFFULL, 0 },
 };

 for(auto const& tv : rup2_test_vals)
 {
  if((uint32)tv.val == tv.val)
  {
   assert(round_up_pow2((uint32)tv.val) == (uint64)tv.expected);
   assert(round_up_pow2((int32)tv.val) == (uint64)tv.expected);
  }

  assert(round_up_pow2((uint64)tv.val) == (uint64)tv.expected);
  assert(round_up_pow2((int64)tv.val) == (uint64)tv.expected);
 }

 for(unsigned i = 1; i < 64; i++)
 {
  if(i < 32)
  {
   assert(round_up_pow2((uint32)(((uint64)1 << i) + 0)) ==  ((uint64)1 << i));
   assert(round_up_pow2((uint32)(((uint64)1 << i) + 1)) == (((uint64)1 << i) << 1));
  }
  assert(round_up_pow2(((uint64)1 << i) + 0) ==  ((uint64)1 << i));
  assert(round_up_pow2(((uint64)1 << i) + 1) == (((uint64)1 << i) << 1));
 }

 assert(round_nearest_pow2((uint16)0xC000, false) ==  0x00008000U);
 assert(round_nearest_pow2( (int16)0x6000, false) ==  0x00004000U);
 assert(round_nearest_pow2( (int16)0x6000,  true) ==  0x00008000U);
 assert(round_nearest_pow2((uint16)0xC000) 	  ==  0x00010000U);
 assert(round_nearest_pow2( (int16)0xC000) 	  == 0x100000000ULL);

 for(int i = 0; i < 64; i++)
 {
  assert( round_nearest_pow2(((uint64)1 << i)                          + 0) == (((uint64)1 << i) << 0) );
  if(i > 0)
  {
   assert( round_nearest_pow2(((uint64)1 << i) + ((uint64)1 << (i - 1))    ) == (((uint64)1 << i) << 1) );
   assert( round_nearest_pow2(((uint64)1 << i) + ((uint64)1 << (i - 1)) - 1) == (((uint64)1 << i) << 0) );
  }

  assert( round_nearest_pow2(((uint64)1 << i)                          + 0, false) == (((uint64)1 << i) << 0) );
  if(i > 0)
  {
   assert( round_nearest_pow2(((uint64)1 << i) + ((uint64)1 << (i - 1)) + 1, false) == (((uint64)1 << i) << 1) );
   assert( round_nearest_pow2(((uint64)1 << i) + ((uint64)1 << (i - 1)) + 0, false) == (((uint64)1 << i) << 0) );
   assert( round_nearest_pow2(((uint64)1 << i) + ((uint64)1 << (i - 1)) - 1, false) == (((uint64)1 << i) << 0) );
  }

  {
   float tmp = i ? floor((1.0 / 2) + (float)i / (1U << MDFN_log2(i))) * (1U << MDFN_log2(i)) : 1.0;
   //printf("%d, %d %d -- %f\n", i, round_nearest_pow2(i, true), round_nearest_pow2(i, false), tmp);
   assert(tmp == round_nearest_pow2(i));
  }
 }

 #if 0
 {
  uint64 lcg = 7;
  uint64 accum = 0;

  for(unsigned i = 0; i < 256; i++, lcg = (lcg * 6364136223846793005ULL) + 1442695040888963407ULL)
   accum += round_up_pow2(lcg) * 1 + round_up_pow2((uint32)lcg) * 3 + round_up_pow2((uint16)lcg) * 5 + round_up_pow2((uint8)lcg) * 7;

  assert(accum == 0xb40001fbdb46577cULL);
 }
 #endif
}

static void TestAbs(void)
{
 assert(MDFN_abs64(0) == 0);
 assert(MDFN_abs64(-1) == 1);
 assert(MDFN_abs64(-2) == 2);
 assert(MDFN_abs64(-7) == 7);
 assert(MDFN_abs64(-(int64)0xDEADBEEF) == 0xDEADBEEF);
 assert(MDFN_abs64(1) == 1);
 assert(MDFN_abs64(2) == 2);
 assert(MDFN_abs64(7) == 7);
 assert(MDFN_abs64(0xDEADBEEF) == 0xDEADBEEF);
 assert((uint64)MDFN_abs64(((uint64)1 << 63) + 1) == (((uint64)1 << 63) - 1));
 assert((uint64)MDFN_abs64((uint64)1 << 63) == ((uint64)1 << 63));
}

static void TestClamp(void)
{
 for(volatile unsigned i = 0; i < 33; i++)
 {
  const uint32 tv0 = (uint64)1 << i;
  const uint32 tv1 = tv0 - 1;
  const uint32 tv2 = tv0 + 1;

  assert(clamp_to_u8(tv0)  == std::min<int32>(0xFF, std::max<int32>(0x00, tv0)));
  assert(clamp_to_u16(tv0) == std::min<int32>(0xFFFF, std::max<int32>(0x0000, tv0)));

  assert(clamp_to_u8(tv1)  == std::min<int32>(0xFF, std::max<int32>(0x00, tv1)));
  assert(clamp_to_u16(tv1) == std::min<int32>(0xFFFF, std::max<int32>(0x0000, tv1)));

  assert(clamp_to_u8(tv2)  == std::min<int32>(0xFF, std::max<int32>(0x00, tv2)));
  assert(clamp_to_u16(tv2) == std::min<int32>(0xFFFF, std::max<int32>(0x0000, tv2)));
 }
}

template<typename RT, typename T, unsigned sa>
static NO_INLINE NO_CLONE RT TestCasts_Sub_L(T v)
{
 return (RT)v << sa;
}

template<typename RT, typename T, unsigned sa>
static NO_INLINE NO_CLONE RT TestCasts_Sub_R(T v)
{
 return (RT)v >> sa;
}

template<typename RT, typename T, signed sa>
static INLINE RT TestCasts_Sub(T v)
{
 if(sa < 0)
  return TestCasts_Sub_R<RT, T, (-sa) & (8 * sizeof(RT) - 1)>(v);
 else
  return TestCasts_Sub_L<RT, T, sa & (8 * sizeof(RT) - 1)>(v);
}

static void TestCastShift(void)
{
 assert((TestCasts_Sub< int64, uint8, 4>(0xEF) == 0x0000000000000EF0ULL));
 assert((TestCasts_Sub<uint64,  int8, 4>(0xEF) == 0xFFFFFFFFFFFFFEF0ULL));

 assert((TestCasts_Sub< int64, uint16, 4>(0xBEEF) == 0x00000000000BEEF0ULL));
 assert((TestCasts_Sub<uint64,  int16, 4>(0xBEEF) == 0xFFFFFFFFFFFBEEF0ULL));

 assert((TestCasts_Sub< int64, uint32, 4>(0xDEADBEEF) == 0x0000000DEADBEEF0ULL));
 assert((TestCasts_Sub<uint64,  int32, 4>(0xDEADBEEF) == 0xFFFFFFFDEADBEEF0ULL));

 assert((TestCasts_Sub< int64, uint8, 20>(0xEF) == 0x000000000EF00000ULL));
 assert((TestCasts_Sub<uint64,  int8, 20>(0xEF) == 0xFFFFFFFFFEF00000ULL));

 assert((TestCasts_Sub< int64, uint16, 20>(0xBEEF) == 0x0000000BEEF00000ULL));
 assert((TestCasts_Sub<uint64,  int16, 20>(0xBEEF) == 0xFFFFFFFBEEF00000ULL));

 assert((TestCasts_Sub< int64, uint32, 20>(0xDEADBEEF) == 0x000DEADBEEF00000ULL));
 assert((TestCasts_Sub<uint64,  int32, 20>(0xDEADBEEF) == 0xFFFDEADBEEF00000ULL));

 assert((TestCasts_Sub< int64, uint8, -4>(0xEF) == 0x000000000000000EULL));
 assert((TestCasts_Sub<uint64,  int8, -4>(0xEF) == 0x0FFFFFFFFFFFFFFEULL));

 assert((TestCasts_Sub< int64, uint16, -4>(0xBEEF) == 0x0000000000000BEEULL));
 assert((TestCasts_Sub<uint64,  int16, -4>(0xBEEF) == 0x0FFFFFFFFFFFFBEEULL));

 assert((TestCasts_Sub< int64, uint32, -4>(0xDEADBEEF) == 0x000000000DEADBEEULL));
 assert((TestCasts_Sub<uint64,  int32, -4>(0xDEADBEEF) == 0x0FFFFFFFFDEADBEEULL));

 assert((TestCasts_Sub< int64, uint8, -20>(0xEF) == 0x0000000000000000ULL));
 assert((TestCasts_Sub<uint64,  int8, -20>(0xEF) == 0x00000FFFFFFFFFFFULL));

 assert((TestCasts_Sub< int64, uint16, -20>(0xBEEF) == 0x0000000000000000ULL));
 assert((TestCasts_Sub<uint64,  int16, -20>(0xBEEF) == 0x00000FFFFFFFFFFFULL));

 assert((TestCasts_Sub< int64, uint32, -20>(0xDEADBEEF) == 0x0000000000000DEAULL));
 assert((TestCasts_Sub<uint64,  int32, -20>(0xDEADBEEF) == 0x00000FFFFFFFFDEAULL));
}

union tup_floatyint
{
 float f;
 uint32 i;
 uint64 j;
};

void NO_INLINE NO_CLONE TestUnionPun_Sub0(tup_floatyint* t)
{
 t->f = 1.0;
 t->i++;
 t->j -= 0x100000001ULL;
}

float NO_INLINE NO_CLONE TestUnionPun_Sub1(tup_floatyint* t, int z)
{
 float a = 0;

 while(z--)
 {
  t->f = 1.0;
  t->i++;
  t->j -= 0x100000001ULL;
  a += t->f;
 }

 return a;
}

float NO_INLINE NO_CLONE TestUnionPun_Sub2(tup_floatyint* t, int z)
{
 float a = 0;

 while(z--)
 {
  t->f *= 2;
  t->i++;
  t->j -= 0x100000001ULL;
  t->f /= 2;
  a += t->f * 2;
 }

 return a;
}


static void TestUnionPun(void)
{
 tup_floatyint v;

 v.j = (uint64)-1;
 v.f = 1.0;
 v.i++;
 assert(v.f != 1.0);
 v.j -= 0x100000001ULL;
 assert(v.f == 1.0);

 v.f++;
 v.j = (uint64)-1;
 TestUnionPun_Sub0(&v);
 assert(v.f == 1.0);

 v.f--;
 v.j = (uint64)-1;
 float t0 = TestUnionPun_Sub1(&v, 9);
 assert(t0 == 9.0);
 assert(v.f == 1.0);

 v.j = (uint64)-1;
 v.f = 32;
 float t1 = TestUnionPun_Sub2(&v, 15);
 assert(t1 == 960.0);
 assert(v.f == 32.0);
}

void NO_INLINE NO_CLONE TestI8Alias_Sub(int8* a, uint8* b, unsigned* c)
{
 (*a)++;
 *c *= 2;
 (*b)++;
 *c *= 3;
 (*a)++;
 *c *= 4;
 (*b)++;
 *c *= 5;

 (*a)++;
 *c *= 6;
 (*a)++;
 *c *= 7;
 (*a)++;
 *c *= 8;
 (*a)++;
 *c *= 9;

 (*b)++;
 *c *= 10;
 (*b)++;
 *c *= 11;
 (*b)++;
 *c *= 12;
 (*b)++;
 *c *= 13;

 (*b)++;
 *c *= 14 + (*a < 0);
 (*b)++;
 *c *= 15 + (*a < 0);
 (*b)++;
 *c *= 16 + (*a < 0);
 (*b)++;
 *c *= 17 + (*a < 0);
}

static void TestI8Alias(void)
{
 unsigned v = 1;
 for(char* z = (char*)&v; z != (char*)&v + sizeof(v); z++)
 {
  if(*z)
  {
   TestI8Alias_Sub((int8*)z, (uint8*)z, &v);
   //printf("%08x\n", v);
   break;
  }
 }
 assert(v == 0x297adbae);
}

template<typename T, typename U>
NO_INLINE NO_CLONE void TestSUSAlias_Sub(T* a, U* b)
{
 *a *= 2;
 *b += 1;
 *a *= 2;
}

static void TestSUSAlias(void)
{
 unsigned char d = 1;
 unsigned short e = 1;
 unsigned int f = 1;
 unsigned long g = 1;
 unsigned long long h = 1;

 TestSUSAlias_Sub((unsigned char*)&d, (signed char*)&d);
 TestSUSAlias_Sub((unsigned short*)&e, (signed short*)&e);
 TestSUSAlias_Sub((unsigned int*)&f, (signed int*)&f);
 TestSUSAlias_Sub((unsigned long*)&g, (signed long*)&g);
 TestSUSAlias_Sub((unsigned long long*)&h, (signed long long*)&h);

 assert(d == 6);
 assert(e == 6);
 assert(f == 6);
 assert(g == 6);
 assert(h == 6);
}

NO_INLINE NO_CLONE int8 TestDiv_Sub0(int8 a)
{
 return (uint16)a / -3;
}

NO_INLINE NO_CLONE int8 TestDiv_Sub1(int8 a)
{
 return (int8)(-a) / 2;
}

NO_INLINE NO_CLONE int16 TestDiv_Sub2(int16 a)
{
 return (int16)(-a) / 2;
}

NO_INLINE NO_CLONE int32 TestDiv_Sub3(int32 a)
{
 return (int32)(-(uint32)a) / 2;
}

NO_INLINE NO_CLONE int64 TestDiv_Sub4(int64 a)
{
 return (int64)(-(uint64)a) / 2;
}

static void TestDiv(void)
{
 //assert((uint8)TestDiv_Sub0(-1) == (uint8)(0xFFFF / -3));
 assert(TestDiv_Sub1(-128) == -64);
 assert(TestDiv_Sub2(-32768) == -16384);
 assert(TestDiv_Sub3((uint32)1 << 31) == -1073741824);
 assert(TestDiv_Sub4((uint64)1 << 63) == (int64)((uint64)1 << 63) >> 1);
}

static void TestMDAP(void)
{
 const int arr2[3][1] = { { 0 }, { 1 }, { 2 } };
 const int arr3[4][1][1] = { { { 0 } }, { { 1 } } , { { 2 } }, { { 3 } }, };
 const int arr4[5][1][1][1] = { { { { 0 } } }, { { { 1 } } }, { { { 2 } } }, { { { 3 } } }, { { { 4 } } } };
 int a, b, c;

 for(a = 0; MDAP(arr2)[a] != 2; a++);
 for(b = 0; MDAP(arr3)[b] != 3; b++);
 for(c = 0; MDAP(arr4)[c] != 4; c++);

 assert(a == 2);
 assert(b == 3);
 assert(c == 4);
}

NO_INLINE NO_CLONE void TestArrayStruct_Sub(void* p, int s, int c)
{
 for(int i = 0; i < c; i++)
  *(int*)((char*)p + s * i) = i * i;
}

static NO_INLINE NO_CLONE void TestArrayStruct(void)
{
 struct
 {
  int a;
  int b;
  int c;
  int d;
 } test[4];

 TestArrayStruct_Sub((char*)test + ((char*)&test->c - (char*)test), sizeof(*test), 4);
 assert(test[1].c == 1);
 assert(test[3].c == 9);
 //
 //
 //
 struct
 {
  short a;
  int b;
  char c;
 } test2[4];

 for(int i = 0; i < 4; i++)
  *(int*)((char*)test2 + ((char*)&test2->b - (char*)test2) + sizeof(*test2) * i) = i * i * i;

 assert(test2[1].b == 1);
 assert(test2[3].b == 27);
 //
 //
 //
 struct
 {
  float a;
  int b;
  long c;
 } test3[3];

 for(int i = 0; i < 3; i++)
  *(int*)((uintptr_t)test3 + ((uintptr_t)&test3->b - (uintptr_t)test3) + sizeof(*test3) * i) = i * i * i * i;

 assert(test3[1].b == 1);
 assert(test3[2].b == 16);
}

static void Time_Test(void)
{
 {
  struct tm ut = Time::UTCTime(0);

  assert(ut.tm_sec == 0);
  assert(ut.tm_min == 0);
  assert(ut.tm_hour == 0);
  assert(ut.tm_mday == 1);
  assert(ut.tm_mon == 0);
  assert(ut.tm_year == 70);
  assert(ut.tm_wday == 4);
  assert(ut.tm_yday == 0);
  assert(ut.tm_isdst <= 0);
 }

 #ifndef WIN32
 if(sizeof(time_t) >= 8)
 #endif
 {
  struct tm ut = Time::UTCTime((int64)1 << 32);

  assert(ut.tm_sec == 16);
  assert(ut.tm_min == 28);
  assert(ut.tm_hour == 6);
  assert(ut.tm_mday == 7);
  assert(ut.tm_mon == 1);
  assert(ut.tm_year == 206);
  assert(ut.tm_wday == 0);
  assert(ut.tm_yday == 37);
  assert(ut.tm_isdst <= 0);
 }
}

const char* MDFN_tests_stringA = "AB\0C";
const char* MDFN_tests_stringB = "AB\0CD";
const char* MDFN_tests_stringC = "AB\0X";

static void TestSStringNullChar(void)
{
 assert(MDFN_tests_stringA != MDFN_tests_stringB && MDFN_tests_stringA[3] == 'C' && MDFN_tests_stringB[4] == 'D');
 assert(MDFN_tests_stringA != MDFN_tests_stringC && MDFN_tests_stringB != MDFN_tests_stringC && MDFN_tests_stringC[3] == 'X');
}

static void TestArithRightShift(void)
{
 static_assert(((int)(1U << 31) >> 31) == -1, "unexpected result");
 static_assert(-1 == ((int)0xFFFFFFFF >> 31), "unexpected result");
 static_assert(1 == ((1U + 2147483647) >> 31), "unexpected result");
 static_assert(1 == ((2147483647 + 1U) >> 31), "unexpected result");
 static_assert(-1 == ((int)(1U + 2147483647) >> 31), "unexpected result");
 static_assert(-1 == ((int)(2147483647 + 1U) >> 31), "unexpected result");

 {
  int32 meow;

  meow = 1;
  meow >>= 1;
  assert(meow == 0);

  meow = 5;
  meow >>= 1;
  assert(meow == 2);

  meow = -1;
  meow >>= 1;
  assert(meow == -1);

  meow = -5;
  meow >>= 1;
  assert(meow == -3);

  meow = 1;
  meow /= 2;
  assert(meow == 0);

  meow = 5;
  meow /= 2;
  assert(meow == 2);

  meow = -1;
  meow /= 2;
  assert(meow == 0);

  meow = -5;
  meow /= 2;
  assert(meow == -2);

  meow = -5;
  meow = (int32)(meow + ((uint32)meow >> 31)) >> 1;
  assert(meow == -2);

  #if 0
  meow = 1 << 30;
  meow <<= 1;
  assert(meow == -2147483648);

  meow = 1 << 31;
  meow <<= 1;
  assert(meow == 0);
  #endif
 }


 // New tests added May 22, 2010 to detect MSVC compiler(and possibly other compilers) bad code generation.
 {
  uint32 test_tab[4] = { 0x2000 | 0x1000, 0x2000, 0x1000, 0x0000 };
  const uint32 result_tab[4][2] = { { 0xE, 0x7 }, { 0xE, 0x0 }, { 0x0, 0x7 }, { 0x0, 0x0 } };

  for(int i = 0; i < 4; i++)
  {
   uint32 hflip_xor;
   uint32 vflip_xor;
   uint32 bgsc;

   bgsc = test_tab[i];

   hflip_xor = ((int32)(bgsc << 18) >> 30) & 0xE;
   vflip_xor = ((int32)(bgsc << 19) >> 31) & 0x7;

   assert(hflip_xor == result_tab[i][0]);
   assert(vflip_xor == result_tab[i][1]);

   //printf("%d %d\n", hflip_xor, result_tab[i][0]);
   //printf("%d %d\n", vflip_xor, result_tab[i][1]);
  }

  uint32 lfsr = 1;

  // quick and dirty RNG(to also test non-constant-expression evaluation, at least until compilers are extremely advanced :b)
  for(int i = 0; i < 256; i++)
  {
   int feedback = ((lfsr >> 7) & 1) ^ ((lfsr >> 14) & 1);
   lfsr = ((lfsr << 1) & 0x7FFF) | feedback;
	
   uint32 hflip_xor;
   uint32 vflip_xor;
   uint32 hflip_xor_alt;
   uint32 vflip_xor_alt;
   uint32 bgsc;

   bgsc = lfsr;

   hflip_xor = ((int32)(bgsc << 18) >> 30) & 0xE;
   vflip_xor = ((int32)(bgsc << 19) >> 31) & 0x7;

   hflip_xor_alt = bgsc & 0x2000 ? 0xE : 0;
   vflip_xor_alt = bgsc & 0x1000 ? 0x7 : 0;

   assert(hflip_xor == hflip_xor_alt);
   assert(vflip_xor == vflip_xor_alt);
  }
 }
}

NO_INLINE NO_CLONE uint64_t TestMemcpySanity_Sub0(void)
{
 void* p = malloc(8);
 assert(p);
 uint64_t v = 0x1234567812345678ULL;
 uint64_t ret;
 uint64_t tmp;

 *((uint32_t*)p + 0) = 0x89ABCDEF;
 *((uint32_t*)p + 1) = 0;
 memcpy(p, &v, 8);
 *((uint32_t*)p + 0) += 0x11111110;
 *((uint32_t*)p + 1) += 0x11111110;
 memcpy(&tmp, p, 8);
 memcpy(p, &tmp, 8);

 ret = *(uint64_t*)p;
 free(p);

 return ret;
}

NO_INLINE NO_CLONE uint32_t TestMemcpySanity_Sub1(void)
{
 void* p = malloc(4);
 assert(p);
 uint32_t v = 0x12341234;
 uint32_t ret;
 uint32_t tmp;

 *((uint16_t*)p + 0) = 0xCDEF;
 *((uint16_t*)p + 1) = 0;
 memcpy(p, &v, 4);
 *((uint16_t*)p + 0) += 0x1110;
 *((uint16_t*)p + 1) += 0x1110;
 memcpy(&tmp, p, 4);
 memcpy(p, &tmp, 4);

 ret = *(uint32_t*)p;
 free(p);

 return ret;
}

union TestMemcpySanity_DU
{
 double a;
 uint64 yay;
};

NO_INLINE NO_CLONE void TestMemcpySanity_Sub2_Copy(TestMemcpySanity_DU* d, TestMemcpySanity_DU* s)
{
 memcpy(d, s, sizeof(TestMemcpySanity_DU));
}

NO_INLINE NO_CLONE uint64 TestMemcpySanity_Sub2(void)
{
 TestMemcpySanity_DU a, b;
 a.yay = 0x7FF0000000000001ULL;
 TestMemcpySanity_Sub2_Copy(&b, &a);
 return b.yay;
}

NO_INLINE NO_CLONE uint8 TestMemcpySanity_Sub3_Copy2(volatile uint8 v)
{
 return v;
}

static INLINE float TestMemcpySanity_Sub3_Copy(float v)
{
 uint8 i[sizeof(float)];
 float ret;

 memcpy(&i, &v, sizeof(float));
 i[0] = TestMemcpySanity_Sub3_Copy2(i[0]);
 memcpy(&ret, &i, sizeof(float));

 return ret;
}

NO_INLINE NO_CLONE MDFN_COLD double TestMemcpySanity_Sub3(double v)
{
 return TestMemcpySanity_Sub3_Copy(v);
}

static void TestMemcpySanity(void)
{
 assert(TestMemcpySanity_Sub0() == 0x2345678823456788ULL);
 assert(TestMemcpySanity_Sub1() == 0x23442344);
 assert(TestMemcpySanity_Sub2() == 0x7FF0000000000001ULL);
 assert(TestMemcpySanity_Sub3(123.0) == 123.0);
}

static struct
{
 MDFN_jmp_buf jbuf;
 uint8 dummy[8];
} TestJumpS;

NO_INLINE NO_CLONE bool TestJump_Sub0(int v)
{
 if(v == 0)
 {
  assert(MDFN_de64lsb(TestJumpS.dummy) == 0xDEADBEEF5555AAAAULL);
 }
 else if(v >= 4)
 {
  assert(MDFN_de64lsb(TestJumpS.dummy) == 0xCAFEF00DAAAA5555ULL);
 }

 if(v == 3)
 {
  MDFN_en64lsb(&TestJumpS.dummy, 0xCAFEF00DAAAA5555ULL);
  MDFN_longjmp(TestJumpS.jbuf);
  return false;
 }

 return true;
}

static NO_INLINE NO_CLONE void TestJump(void)
{
 volatile int i = 0;
 volatile uint32 a = 987654321;
 volatile uint32 b = 420349502;
 volatile uint32 c = 692094390;
 volatile uint32 d =   2394209;
 uint32 e = 398457985;
 uint32 f = 150590249;
 uint32 g = 593049509;
 uint32 h = 203402499;
 MDFN_en64lsb(TestJumpS.dummy, 0xDEADBEEF5555AAAAULL);

 MDFN_setjmp(TestJumpS.jbuf);

 while(i < 8)
 {
  a = (a * b) + c;
  b = (a * c) + d;
  c = (a * d) + e;
  d = (a * e) + f;

  bool rv = TestJump_Sub0(i++);

  assert(i != 4);

  if(i >= 5)
  {
   e = (a * f) + g;
   f = (a * g) + h;
   g = (a * h) + a;
   h = (a * a) + b;
  }

  assert(rv);
 }

 assert(a == 0x2c05efe7);
 assert(b == 0x8a16b667);
 assert(c == 0x921de4a5);
 assert(d == 0xafaeef58);
 assert(e == 0x1c8cdf2d);
 assert(f == 0xc7f04e88);
 assert(g == 0x05402fff);
 assert(h == 0x31edd8d8);

 assert(MDFN_de64lsb(TestJumpS.dummy) == 0xCAFEF00DAAAA5555ULL);
}

static void TestSimpleBitset(void)
{
 SimpleBitset<1> a;
 SimpleBitset<31> b;
 SimpleBitset<32> c;
 SimpleBitset<129> d;

 assert(sizeof(a.data) == sizeof(uint32) * 1 && a.data_count == 1);
 assert(sizeof(b.data) == sizeof(uint32) * 1 && b.data_count == 1);
 assert(sizeof(c.data) == sizeof(uint32) * 1 && c.data_count == 1);
 assert(sizeof(d.data) == sizeof(uint32) * 5 && d.data_count == 5);

 //static const unsigned test_bit_counts[] = { 1, 2, 30, 31, 32, 33, 34, 63, 64, 65, 66 };
 //static const unsigned test_bit_offsets[] = { 
 //for(unsigned 

 assert(!a.data[0]);
 assert(!b.data[0]);
 assert(!c.data[0]);
 assert(!d.data[0] && !d.data[1] && !d.data[2] && !d.data[3] && !d.data[4]);

 a.set_multi_wrap(0, true, 2);
 assert(a.data[0] == 0x1);

 a.data[0] = 0;
 a.set_multi_wrap(0, true, 32);
 assert(a.data[0] == 0x1);

 a.data[0] = ~0U;
 a.set_multi_wrap(0, false, 32);
 assert(a.data[0] == ~(uint32)1);
 //
 //
 b.set_multi_wrap(30, true, 2);
 assert(b.data[0] == 0x40000001);

 b.data[0] = 0;
 b.set_multi_wrap(0, true, 32);
 assert(b.data[0] == 0x7FFFFFFF);

 b.data[0] = ~0U;
 b.set_multi_wrap(0, false, 32);
 assert(b.data[0] == 0x80000000);
 //
 //
 c.set_multi_wrap(32, true, 31);
 assert(c.data[0] == 0x7FFFFFFF);

 c.data[0] = 0;
 c.set_multi_wrap(16, true, 8);
 assert(c.data[0] == 0x00FF0000);

 c.data[0] = ~0U;
 c.set_multi_wrap(31, false, 32);
 assert(c.data[0] == 0x00000000);
 //
 //
 //
 d.set_multi_wrap(0, true, 129);
 assert(d.data[0] == ~0U && d.data[1] == ~0U && d.data[2] == ~0U && d.data[3] == ~0U && d.data[4] == 1);

 d.set_multi_wrap(1, false, 128);
 assert(d.data[0] == 1 && d.data[1] == 0 && d.data[2] == 0 && d.data[3] == 0 && d.data[4] == 0);
}

static void TestStrArgsSplit(void)
{
 assert(MDFN_strargssplit("") == std::vector<std::string>({}));
 assert(MDFN_strargssplit(" ") == std::vector<std::string>({}));
 assert(MDFN_strargssplit("\"\"") == std::vector<std::string>({""}));
 assert(MDFN_strargssplit("poodles") == std::vector<std::string>({"poodles"}));
 assert(MDFN_strargssplit("poodles ") == std::vector<std::string>({"poodles"}));
 assert(MDFN_strargssplit(" poodles") == std::vector<std::string>({"poodles"}));
 assert(MDFN_strargssplit("poodles fur") == std::vector<std::string>({"poodles", "fur"}));
 assert(MDFN_strargssplit("\"poodles\" \"fur\"") == std::vector<std::string>({"poodles", "fur"}));
 assert(MDFN_strargssplit("\"poodle\"s \"fur") == std::vector<std::string>({"poodles", "fur"}));
 assert(MDFN_strargssplit("\"poodle\"s \"fur fur\"\" fur\" \" brush\" \"") == std::vector<std::string>({"poodles", "fur fur fur", " brush", ""}));

 assert(MDFN_strargssplit("\"Admiral Poodle's \\\"Fur Fur Fur, Brush Brush Brush\\\" Greatest Hits\" \"\\n") == std::vector<std::string>({"Admiral Poodle's \"Fur Fur Fur, Brush Brush Brush\" Greatest Hits", "\n"}));
 //
 //
 assert(MDFN_strargssplit("\"poodles\\\\\" \"fur\\\n\" \\\"brush\\ brush \"brush\\o5\\\"\\x4\\\"\\3\\\"\\002\\\"\\1\"") == std::vector<std::string>({"poodles\\", "fur\n", "\"brush", "brush", "brush\005\"\004\"\003\"\002\"\001"}));
}

static void TestEscapeString(void)
{
 //const uint64 st = Time::MonoUS();
 //

 assert(MDFN_strunescape("\\1") == "\001");
 assert(MDFN_strunescape("\\11") == "\011");
 assert(MDFN_strunescape("\\111") == "\111");
 assert(MDFN_strunescape("\\18") == "\0018");
 assert(MDFN_strunescape("\\118") == "\0118");
 assert(MDFN_strunescape("\\1118") == "\1118");
 assert(MDFN_strunescape("\\1m") == "\001m");
 assert(MDFN_strunescape("\\11m") == "\011m");
 assert(MDFN_strunescape("\\111m") == "\111m");
 assert(MDFN_strunescape("\\005123") == "\005123");
 assert(MDFN_strunescape("\\1\\n") == "\001\n");

 assert(MDFN_strunescape("\\o") == std::string("\0", 1));
 assert(MDFN_strunescape("\\o1") == "\001");
 assert(MDFN_strunescape("\\o11") == "\011");
 assert(MDFN_strunescape("\\o111") == "\111");
 assert(MDFN_strunescape("\\o18") == "\0018");
 assert(MDFN_strunescape("\\o118") == "\0118");
 assert(MDFN_strunescape("\\o1118") == "\1118");
 assert(MDFN_strunescape("\\o1m") == "\001m");
 assert(MDFN_strunescape("\\o11m") == "\011m");
 assert(MDFN_strunescape("\\o111m") == "\111m");
 assert(MDFN_strunescape("\\o005123") == "\005123");
 assert(MDFN_strunescape("\\o\\n") == (std::string("\0", 1) + "\n"));
 assert(MDFN_strunescape("\\o1\\n") == "\001\n");

 assert(MDFN_strunescape("\\x") == std::string("\0", 1));
 assert(MDFN_strunescape("\\x1") == "\001");
 assert(MDFN_strunescape("\\x1f") == "\x1f");
 assert(MDFN_strunescape("\\x1ff") == "\x1f" "f");
 assert(MDFN_strunescape("\\x1fg") == "\x1fg");
 assert(MDFN_strunescape("\\x\\n") == (std::string("\0", 1) + "\n"));
 assert(MDFN_strunescape("\\x1\\n") == "\001\n");

 assert(MDFN_strunescape("\\") == "");
 assert(MDFN_strunescape("\\a\\b\\f\\n\\r\\t\\v\\\\\\'\\\"\\?") == "\a\b\f\n\r\t\v\\'\"?");

 assert(MDFN_strunescape("\\0\\1\\2\\3\\4\\5\\6\\7\\10\\11\\12\\13\\14\\15\\16\\17") == std::string("\0\1\2\3\4\5\6\7\10\11\12\13\14\15\16\17", 16));

 assert(MDFN_strunescape("\\123\\321\\177\\377\\777") == "\123\321\177\377\377");
 assert(MDFN_strunescape("\\x7F\\xfF\\xFf\xab\xAB") == "\x7f\xff\xff\xab\xab");
 //
 //
 //
 static const unsigned char esc_compare_seq[] =
 {
  0x5c, 0x30, 0x30, 0x30, 0x5c, 0x30, 0x30, 0x31, 0x5c, 0x30, 0x30, 0x32, 0x5c, 0x30, 0x30, 0x33, 
  0x5c, 0x30, 0x30, 0x34, 0x5c, 0x30, 0x30, 0x35, 0x5c, 0x30, 0x30, 0x36, 0x5c, 0x61, 0x5c, 0x62, 
  0x5c, 0x74, 0x5c, 0x6e, 0x5c, 0x76, 0x5c, 0x66, 0x5c, 0x72, 0x5c, 0x30, 0x31, 0x36, 0x5c, 0x30, 
  0x31, 0x37, 0x5c, 0x30, 0x32, 0x30, 0x5c, 0x30, 0x32, 0x31, 0x5c, 0x30, 0x32, 0x32, 0x5c, 0x30, 
  0x32, 0x33, 0x5c, 0x30, 0x32, 0x34, 0x5c, 0x30, 0x32, 0x35, 0x5c, 0x30, 0x32, 0x36, 0x5c, 0x30, 
  0x32, 0x37, 0x5c, 0x30, 0x33, 0x30, 0x5c, 0x30, 0x33, 0x31, 0x5c, 0x30, 0x33, 0x32, 0x5c, 0x30, 
  0x33, 0x33, 0x5c, 0x30, 0x33, 0x34, 0x5c, 0x30, 0x33, 0x35, 0x5c, 0x30, 0x33, 0x36, 0x5c, 0x30, 
  0x33, 0x37, 0x20, 0x21, 0x5c, 0x22, 0x23, 0x24, 0x25, 0x26, 0x5c, 0x27, 0x28, 0x29, 0x2a, 0x2b, 
  0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 
  0x3c, 0x3d, 0x3e, 0x3f, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 
  0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b, 
  0x5c, 0x5c, 0x5d, 0x5e, 0x5f, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 
  0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 
  0x7b, 0x7c, 0x7d, 0x7e, 0x5c, 0x31, 0x37, 0x37, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 
  0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 
  0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 
  0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 
  0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 
  0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 
  0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 
  0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0xef, 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 
  0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff
 };

 std::string in_str;
 std::string out_str;
 std::string unesc_str;

 in_str.resize(256);

 for(unsigned i = 0; i < 256; i++)
  in_str[i] = i;

 out_str = MDFN_strescape(in_str);
 unesc_str = MDFN_strunescape(out_str);

 assert(unesc_str == in_str);
 assert(out_str.size() == sizeof(esc_compare_seq) && !memcmp(out_str.data(), esc_compare_seq, sizeof(esc_compare_seq)));

#if 0
 for(size_t i = 0; i < out_str.size(); i++)
 {
  if((i & 0xF) == 0x0)
   printf("\n  ");
  printf("0x%02x, ", (unsigned char)out_str[i]);
 }
 printf("%s\n", out_str.c_str());
#endif
 //printf("Time: %llu\n", (unsigned long long)(Time::MonoUS() - st));
}

static void TestMiscString(void)
{
 assert(!MDFN_strazicmp("", ""));
 assert(!MDFN_strazicmp("AA", "AZ", 1));
 assert(!MDFN_strazicmp("\0A", "\0B", 2));
 assert(!MDFN_strazicmp("abc0", "ABC1", 3) && !MDFN_strazicmp("ABC0", "abc1", 3));
 assert(!MDFN_strazicmp("i", "I") && !MDFN_strazicmp("I", "i"));
 assert(MDFN_strazicmp("A", "\xFF") < 0 && MDFN_strazicmp("\xFF", "A") > 0);
 assert(MDFN_strazicmp("a", "[") > 0 && MDFN_strazicmp("A", "[") > 0);
 assert(MDFN_strazicmp("a", "z") < 0 && MDFN_strazicmp("z", "a") > 0);
 assert(MDFN_strazicmp("A", "z") < 0 && MDFN_strazicmp("z", "A") > 0);
 assert(MDFN_strazicmp("a", "Z") < 0 && MDFN_strazicmp("Z", "a") > 0);
 assert(MDFN_strazicmp("`", "@") > 0 && MDFN_strazicmp("@", "`") < 0);
 assert(MDFN_strazicmp("{", "[") > 0 && MDFN_strazicmp("]", "}") < 0);

 assert(!MDFN_strazicmp(std::string(""), ""));
 assert(!MDFN_strazicmp(std::string(""), std::string("")));

 assert(MDFN_strazicmp(std::string("A"), "") > 0 && MDFN_strazicmp(std::string(""), "A") < 0);
 assert(MDFN_strazicmp(std::string("A"), std::string("")) > 0 && MDFN_strazicmp(std::string(""), std::string("A")) < 0);

 assert(MDFN_strazicmp(std::string(1, '\0'), "") > 0 && MDFN_strazicmp("", std::string(1, '\0')) < 0);
 assert(MDFN_strazicmp(std::string(1, '\0'), std::string("")) > 0 && MDFN_strazicmp(std::string(""), std::string(1, '\0')) < 0);

 assert(MDFN_strazicmp(std::string(2, '\0'), "]") > 0 && MDFN_strazicmp("]", std::string(2, '\0')) < 0);
 assert(MDFN_strazicmp(std::string(2, '\0'), std::string("]")) > 0 && MDFN_strazicmp(std::string("]"), std::string(2, '\0')) < 0);

 assert(MDFN_strazicmp(std::string("A"), "\xFF") < 0 && MDFN_strazicmp(std::string("\xFF"), "A") > 0);
 assert(MDFN_strazicmp(std::string("A"), std::string("\xFF")) < 0 && MDFN_strazicmp(std::string("\xFF"), std::string("A")) > 0);

 assert(!MDFN_memazicmp("", "", 0));
 assert(!MDFN_memazicmp("abc0", "ABC1", 3) && !MDFN_memazicmp("ABC0", "abc1", 3));
 assert(MDFN_memazicmp("a", "[", 1) > 0 && MDFN_memazicmp("A", "[", 1) > 0);
 assert(MDFN_memazicmp("a", "z", 1) < 0 && MDFN_memazicmp("z", "a", 1) > 0);
 assert(MDFN_memazicmp("A", "z", 1) < 0 && MDFN_memazicmp("z", "A", 1) > 0);
 assert(MDFN_memazicmp("a", "Z", 1) < 0 && MDFN_memazicmp("Z", "a", 1) > 0);
 assert(MDFN_memazicmp("{", "[", 1) > 0 && MDFN_memazicmp("]", "}", 1) < 0);

 assert(MDFN_strazlower(std::string("@ABCDEFGHIJKLMNOPQRSTUVWXYZ[@abcdefghijklmnopqrstuvwxyz[")) == "@abcdefghijklmnopqrstuvwxyz[@abcdefghijklmnopqrstuvwxyz[");
 assert(MDFN_strazupper(std::string("@ABCDEFGHIJKLMNOPQRSTUVWXYZ[@abcdefghijklmnopqrstuvwxyz[")) == "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[@ABCDEFGHIJKLMNOPQRSTUVWXYZ[");
 assert(MDFN_trim(std::string(" \f\r\n\t\v! \f\r\n\t\v")) == "!");
 assert(MDFN_rtrim(std::string(" \f\r\n\t\v! \f\r\n\t\v")) == " \f\r\n\t\v!");
 assert(MDFN_ltrim(std::string(" \f\r\n\t\v! \f\r\n\t\v")) == "! \f\r\n\t\v");
 //
 //
 {
  char a[4 + 4] = { 0 };
  char b[4 + 4] = { 0 };

  b[5] = 0x55;
  b[6] = 0xAA;

  MDFN_en32msb(a, 0x89ABCDEF);
  MDFN_en32msb(b, 0x01234567);
  MDFN_strlcpy(a, b, 0);
  assert(MDFN_de32msb(a) == 0x89ABCDEF);

  MDFN_strlcpy(a, b, 1);
  assert(MDFN_de32msb(a) == 0x00ABCDEF);

  MDFN_en32msb(a, 0x89ABCDEF);
  MDFN_strlcpy(a, b, 2);
  assert(MDFN_de32msb(a) == 0x0100CDEF);

  MDFN_en32msb(a, 0x89ABCDEF);
  MDFN_strlcpy(a, b, 3);
  assert(MDFN_de32msb(a) == 0x012300EF);

  MDFN_en32msb(a, 0x89ABCDEF);
  MDFN_strlcpy(a, b, 4);
  assert(MDFN_de32msb(a) == 0x01234500);

  MDFN_en32msb(a, 0x89ABCDEF);
  MDFN_strlcpy(a, b, 8);
  assert(MDFN_de32msb(a) == 0x01234567);
  assert(MDFN_de32msb(a + 4) == 0x00000000);
 }
 //
 //
/*
 {
  const char* a =  "EaPopgkvxHOa^jSFsrFtyji4tAS{v'iAHTKpak";
  const char* ax = "EaPOpGKvxHOA^jsfsRFTYJI4Tas{v'iAHTKpak";
  const char* b =  "!!!AbCDefGHIJklmnOPQRSTUVwxyz...09";
  const char* bx = "!!!abcdefGHijkLMnoPqrstuvWXyz...09";
  char tmp[64];

  strncpy(tmp, sizeof(tmp), a);
  MDFN_strazcasexlate(tmp, b);
  assert(!strcmp(tmp, ax));

  strncpy(tmp, sizeof(tmp), b);
  MDFN_strazcasexlate(tmp, a);
  assert(!strcmp(tmp, bx));
 }
*/
 //
 //
 {
  char tmp[33];

  for(unsigned i = 0; i < 0x20; i++)
   tmp[i] = i;

  tmp[32] = 0x7F;

  assert(MDFN_strhumesc(std::string(tmp, 33)) == "^@^A^B^C^D^E^F^G^H^I^J^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\\^]^^^_^?");

  assert(MDFN_strhumesc("AZaz09^!\x80") == "AZaz09^!\x80");
 }
 //
 //
 {
  static const struct
  {
   const char* a;
   const char* b;
   size_t r;
  } tv[] =
  {
   { "abc", "abc", SIZE_MAX },
   { "", "", SIZE_MAX },
   { "A", "", 0 },
   { "", "A", 0 },
   { "abcd", "abc", 3 },
   { "abc", "abcd", 3 },
   { "abcdf", "abcef", 3 },
   { "", "abcdefghijklmnopqrstuvwxyz", 0 },
  };

  for(auto const& tve : tv)
  {
   assert(MDFN_strmismatch(tve.a, tve.b) == tve.r);
   assert(MDFN_strmismatch(std::string(tve.a), tve.b) == tve.r);
   assert(MDFN_strmismatch(tve.a, std::string(tve.b)) == tve.r);
   assert(MDFN_strmismatch(std::string(tve.a), std::string(tve.b)) == tve.r);
  }
 }
}

static void TestFromStr(void)
{
 static const struct
 {
  const char* s;
  unsigned base;
  unsigned exp_error;
  uint64 exp_value;
 } test_vectors_u64[] =
 {
  { "0", 0, XFROMSTR_ERROR_NONE, 0 },
  { "-0", 0, XFROMSTR_ERROR_NONE, 0 },
  { "+0", 0, XFROMSTR_ERROR_NONE, 0 },
  { "0x0", 0, XFROMSTR_ERROR_NONE, 0 },
  { "00", 0, XFROMSTR_ERROR_NONE, 0 },
  { "1", 0, XFROMSTR_ERROR_NONE, 1 },
  { "+3", 0, XFROMSTR_ERROR_NONE, 3 },
  { "0000000000000000000033", 0, XFROMSTR_ERROR_NONE, 33 },
  { "9", 0, XFROMSTR_ERROR_NONE, 9 },
  { "10", 0, XFROMSTR_ERROR_NONE, 10 },
  { "010", 0, XFROMSTR_ERROR_NONE, 10 },
  { "010", 8, XFROMSTR_ERROR_NONE, 8 },
  { "0110", 2, XFROMSTR_ERROR_NONE, 6 },
  { "0110", 2, XFROMSTR_ERROR_NONE, 6 },

  { "0x0000000000000000000033", 0, XFROMSTR_ERROR_NONE, 0x33 },
  { "4294967295", 0, XFROMSTR_ERROR_NONE, (uint32)-1 },
  { "18446744073709551615", 0, XFROMSTR_ERROR_NONE, (uint64)-1 },
  { "0xDEADBEEfCAFEBABE", 0, XFROMSTR_ERROR_NONE, 0xDEADBEEFCAFEBABEULL },
  { "0X0123456789ABCDEF", 0, XFROMSTR_ERROR_NONE, 0x0123456789ABCDEFULL },
  { "dEADBeEfCaFeBaBe", 16, XFROMSTR_ERROR_NONE, 0xDEADBEEFCAFEBABEULL },
  { "0xDeadBeefCaFEBaBE", 16, XFROMSTR_ERROR_NONE, 0xDEADBEEFCAFEBABEULL },
  { "0XFEDCBA9876543210", 16, XFROMSTR_ERROR_NONE, 0xFEDCBA9876543210ULL },

  { "-18446744073709551616", 0, XFROMSTR_ERROR_UNDERFLOW, 0 },
  { "-0xFFFFFFFFFFFFFFFFF", 0, XFROMSTR_ERROR_UNDERFLOW, 0 },
  { "-1", 0, XFROMSTR_ERROR_UNDERFLOW, 0 },

  { "18446744073709551616", 0, XFROMSTR_ERROR_OVERFLOW, (uint64)-1 },
  { "0xDEADBEEFCAFEBABE1", 0, XFROMSTR_ERROR_OVERFLOW, (uint64)-1 },

  { "0xDEADBEEFCAFEBABEG", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "DEADBEEFCAFEBABG", 16, XFROMSTR_ERROR_MALFORMED, 0 },
  { "", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "  ", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { " 0", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "0 ", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "-", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "+", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "+0x", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "-0X", 0, XFROMSTR_ERROR_MALFORMED, 0 },
  { "0X", 16, XFROMSTR_ERROR_MALFORMED, 0 },
  { "0x", 0, XFROMSTR_ERROR_MALFORMED, 0 },
 };

 for(auto const& tve : test_vectors_u64)
 {
  unsigned error;
  uint64 value;

  value = MDFN_u64fromstr(tve.s, tve.base, &error);
  //printf("%s %u --- %u %llu\n", tve.s, tve.base, error, (unsigned long long)value);

  assert(error == tve.exp_error);
  assert(value == tve.exp_value);
 }
 //
 //
 static const struct
 {
  const char* s;
  unsigned base;
  unsigned exp_error;
  int64 exp_value;
 } test_vectors_s64[] =
 {
  { "-12345", 6, XFROMSTR_ERROR_NONE, -1865 },
  { "-0x8000000000000000", 0, XFROMSTR_ERROR_NONE, (int64)((uint64)1 << 63) },
  { "0x7FFFFFFFFFFFFFFF", 0, XFROMSTR_ERROR_NONE, (int64)(((uint64)1 << 63) - 1) },

  { "-0x8000000000000001", 0, XFROMSTR_ERROR_UNDERFLOW, (int64)((uint64)1 << 63) },
  { "0x8000000000000001", 0, XFROMSTR_ERROR_OVERFLOW, (int64)(((uint64)1 << 63) - 1) },

  { "-0x80000000000000000", 0, XFROMSTR_ERROR_UNDERFLOW, (int64)((uint64)1 << 63) },
  { "0x80000000000000000", 0, XFROMSTR_ERROR_OVERFLOW, (int64)(((uint64)1 << 63) - 1) },
  { "0x8000000000000000", 0, XFROMSTR_ERROR_OVERFLOW, (int64)(((uint64)1 << 63) - 1) },
  { "0xFFFFFFFFFFFFFFFF", 0, XFROMSTR_ERROR_OVERFLOW, (int64)(((uint64)1 << 63) - 1) },
  { "18446744073709551616", 0, XFROMSTR_ERROR_OVERFLOW, (int64)(((uint64)1 << 63) - 1) },
  { "-18446744073709551616", 0, XFROMSTR_ERROR_UNDERFLOW, (int64)((uint64)1 << 63) },
  { "-123456", 6, XFROMSTR_ERROR_MALFORMED, 0 },
 };

 for(auto const& tve : test_vectors_s64)
 {
  unsigned error;
  int64 value;

  value = MDFN_s64fromstr(tve.s, tve.base, &error);
  //printf("%s %u 0x%08x --- 0x%016llx\n", tve.s, tve.base, tve.flags, (unsigned long long)value);

  assert(error == tve.exp_error);
  assert(value == tve.exp_value);
 }

 {
  unsigned error;

  assert(MDFN_s64fromstr((char*)"0x7FFFFFFFFFFFFFFF", 0, &error) == ((uint64)-1 >> 1));
  assert(MDFN_u64fromstr((char*)"0xFFFFFFFFFFFFFFFF", 0, &error) == (uint64)-1);

  assert(MDFN_s32fromstr((char*)"0x7FFFFFFFFFFFFFFF", 0, &error) == ((uint32)-1 >> 1));
  assert(MDFN_u32fromstr((char*)"0xFFFFFFFFFFFFFFFF", 0, &error) == (uint32)-1);
 }
}

static void TestSndec(void)
{
 static const struct
 {
  const int64 value;
  const char* exp_s;
 } test_vectors_s64[] =
 {
  { 0, "0" },
  { 1, "1" },
  { -1, "-1" },
  { 21, "21" },
  { -21, "-21" },
  { 321, "321" },
  { 4321, "4321" },
  { 54321, "54321" },
  { 654321, "654321" },
  { 7654321, "7654321" },
  { 87654321, "87654321" },
  { 987654321, "987654321" },
  { (int64)(((uint64)1 << 63) - 1), "9223372036854775807" },
  { (int64)((uint64)1 << 63), "-9223372036854775808" },
 };

 for(auto const& tve : test_vectors_s64)
 {
  char tmp[64];

  MDFN_sndec_s64(tmp, sizeof(tmp), tve.value);
  //printf("%lld %s\n", tve.value, tmp);
  assert(!strcmp(tmp, tve.exp_s));
 }

 static const struct
 {
  const uint64 value;
  const char* exp_s;
 } test_vectors_u64[] =
 {
  { 0, "0" },
  { 1, "1" },
  { 21, "21" },
  { 321, "321" },
  { 4321, "4321" },
  { 54321, "54321" },
  { 654321, "654321" },
  { 7654321, "7654321" },
  { 87654321, "87654321" },
  { 987654321, "987654321" },
  { ((uint64)1 << 63) - 1, "9223372036854775807" },
  { (uint64)1 << 63, "9223372036854775808" },
  { (uint64)-1, "18446744073709551615" },
 };

 for(auto const& tve : test_vectors_u64)
 {
  char tmp[64];

  MDFN_sndec_u64(tmp, sizeof(tmp), tve.value);
  //printf("%llu %s\n", tve.value, tmp);
  assert(!strcmp(tmp, tve.exp_s));
 }
}

static void TestCDUtility(void)
{
/*
 for(unsigned i = 0; i < 0x200; i++)
 {
  const uint8 tmp = i;

  assert(CDUtility::BCD_is_valid(i) == (((tmp & 0xF) < 0xA) && ((tmp & 0xF0) < 0xA0)));
 }
*/
 {
  uint8 tmp;

  assert(CDUtility::BCD_is_valid(-0x67));
  assert(CDUtility::BCD_is_valid(0x00));
  assert(CDUtility::BCD_is_valid(0x09));
  assert(CDUtility::BCD_is_valid(0x90));
  assert(CDUtility::BCD_is_valid(0x99));
  assert(CDUtility::BCD_is_valid(0x01));
  assert(CDUtility::BCD_is_valid(0x10));
  assert(CDUtility::BCD_is_valid(0x91));
  assert(CDUtility::BCD_is_valid(0x19));
  assert(!CDUtility::BCD_is_valid(0x1A));
  assert(!CDUtility::BCD_is_valid(0xA1));
  assert(!CDUtility::BCD_is_valid(0x8A));
  assert(!CDUtility::BCD_is_valid(0xA8));
  assert(!CDUtility::BCD_is_valid(0xBA));
  assert(!CDUtility::BCD_is_valid(0xAB));
  assert(!CDUtility::BCD_is_valid(0xBB));
  assert(!CDUtility::BCD_is_valid(0x0A));
  assert(!CDUtility::BCD_is_valid(0xA0));
  assert(!CDUtility::BCD_is_valid(0x0F));
  assert(!CDUtility::BCD_is_valid(0xF0));
  assert(!CDUtility::BCD_is_valid(0x9A));
  assert(!CDUtility::BCD_is_valid(0xA9));
  assert(!CDUtility::BCD_is_valid(0x9F));
  assert(!CDUtility::BCD_is_valid(0xF9));
  assert(!CDUtility::BCD_is_valid(0xAA));
  assert(!CDUtility::BCD_is_valid(0xAA));
  assert(!CDUtility::BCD_is_valid(0xAF));
  assert(!CDUtility::BCD_is_valid(0xFA));
  assert(!CDUtility::BCD_is_valid(0xFA));
  assert(!CDUtility::BCD_is_valid(0xAF));
  assert(!CDUtility::BCD_is_valid(0xFF));


  assert(CDUtility::BCD_to_U8(0x00) == 0);
  assert(CDUtility::U8_to_BCD(0) == 0x00);
  assert(CDUtility::BCD_to_U8(0x11) == 11);
  assert(CDUtility::U8_to_BCD(11) == 0x11);
  assert(CDUtility::BCD_to_U8(0x77) == 77);
  assert(CDUtility::U8_to_BCD(77) == 0x77);

  assert(CDUtility::U8_to_BCD(95) == 0x95);
  assert(CDUtility::BCD_to_U8(0x95) == 95);
  assert(CDUtility::U8_to_BCD(255) == 0x95);

  assert((tmp = 0xAA, !CDUtility::BCD_to_U8_check(0x8F, &tmp) && tmp == 95));
  assert((tmp = 0xAA,  CDUtility::BCD_to_U8_check(0x95, &tmp) && tmp == 95));
 }
 //
 //
 assert(CDUtility::LBA_to_ABA(-151) == (uint32)-1);
 assert(CDUtility::ABA_to_LBA((uint32)-1) == -151);

 static const struct
 {
  uint8 m, s, f;
  uint8 bcd_m, bcd_s, bcd_f;
  uint32 aba;
  int32 lba;
 } test_vectors[] =
 {
  {  0,  0,  0, /**/ 0x00, 0x00, 0x00, /**/          0, /**/     -150 },
  {  0,  2,  0, /**/ 0x00, 0x02, 0x00, /**/        150, /**/        0 },
  { 99, 59, 74, /**/ 0x99, 0x59, 0x74, /**/     449999, /**/   449849 },
 };

 for(auto const& tve : test_vectors)
 {
  uint8 mt, st, ft;

  assert(CDUtility::LBA_to_ABA(tve.lba) == tve.aba);
  assert(CDUtility::ABA_to_LBA(tve.aba) == tve.lba);
  assert(CDUtility::AMSF_to_ABA(tve.m, tve.s, tve.f) == tve.aba);
  assert(CDUtility::AMSF_to_LBA(tve.m, tve.s, tve.f) == tve.lba);
  assert((CDUtility::ABA_to_AMSF(tve.aba, &mt, &st, &ft), (mt == tve.m && st == tve.s && ft == tve.f)));
  assert((CDUtility::LBA_to_AMSF(tve.lba, &mt, &st, &ft), (mt == tve.m && st == tve.s && ft == tve.f)));
  assert((CDUtility::ABA_to_AMSF_BCD(tve.aba, &mt, &st, &ft), (mt == tve.bcd_m && st == tve.bcd_s && ft == tve.bcd_f)));
  //
  //
  //
  assert((CDUtility::ABA_to_AMSF(tve.aba, &ft, &ft, &ft), (ft == tve.f)));
  assert((CDUtility::LBA_to_AMSF(tve.lba, &ft, &ft, &ft), (ft == tve.f)));
  assert((CDUtility::ABA_to_AMSF(tve.aba, &ft, &ft, &ft), (ft == tve.f)));

  assert((CDUtility::ABA_to_AMSF(tve.aba, &mt, &ft, &ft), (mt == tve.m && ft == tve.f)));
  assert((CDUtility::LBA_to_AMSF(tve.lba, &mt, &ft, &ft), (mt == tve.m && ft == tve.f)));
  assert((CDUtility::ABA_to_AMSF(tve.aba, &mt, &ft, &ft), (mt == tve.m && ft == tve.f)));

  assert((CDUtility::ABA_to_AMSF(tve.aba, &st, &st, &ft), (st == tve.s && ft == tve.f)));
  assert((CDUtility::LBA_to_AMSF(tve.lba, &st, &st, &ft), (st == tve.s && ft == tve.f)));
  assert((CDUtility::ABA_to_AMSF(tve.aba, &st, &st, &ft), (st == tve.s && ft == tve.f)));
  //
  //
  //
  assert((CDUtility::ABA_to_AMSF_BCD(tve.aba, &ft, &ft, &ft), (ft == tve.bcd_f)));
  assert((CDUtility::ABA_to_AMSF_BCD(tve.aba, &mt, &ft, &ft), (mt == tve.bcd_m && ft == tve.bcd_f)));
  assert((CDUtility::ABA_to_AMSF_BCD(tve.aba, &st, &st, &ft), (st == tve.bcd_s && ft == tve.bcd_f)));
 }
}

static void TestPathManip(void)
{
 static const struct
 {
  const char* path;
  const char* parts[3];
 } gfpc_tv[] =
 {
#if MDFN_PSS_STYLE == 1 || MDFN_PSS_STYLE == 2
  { "/meow", 		{ "", "meow", "" } },
  { "/meow/cow",	{ "/meow", "cow", "" } },
  { "/meow.",		{ "", "meow", "." } },
  { "/me.ow/cow.",	{ "/me.ow", "cow" ,"." } },
  { "/meow.txt",	{ "", "meow", ".txt" } },
  { "/me.ow/cow.txt",	{ "/me.ow", "cow", ".txt" } },
  { "/meow/cow/.txt",	{ "/meow/cow", "", ".txt" } },
#endif

#if defined(DOS) || defined(WIN32) // MDFN_PSS_STYLE == 2
  { "A:/meow", 		{ "A:", "meow", "" } },
  { "a:/meow/cow",	{ "a:/meow", "cow", "" } },
  { "Z:/meow.",		{ "Z:", "meow", "." } },
  { "z:/me.ow/cow.",	{ "z:/me.ow", "cow" ,"." } },
  { "B:/meow.txt",	{ "B:", "meow", ".txt" } },
  { "b:/me.ow/cow.txt",	{ "b:/me.ow", "cow", ".txt" } },

  { "a:\\meow", 		{ "a:", "meow", "" } },
  { "A:\\meow\\cow",		{ "A:\\meow", "cow", "" } },
  { "z:\\meow.",		{ "z:", "meow", "." } },
  { "Z:\\me.ow/cow.",		{ "Z:\\me.ow", "cow" ,"." } },
  { "b:\\meow.txt",		{ "b:", "meow", ".txt" } },
  { "B:\\me.ow\\cow.txt",	{ "B:\\me.ow", "cow", ".txt" } },

  // Current handling of drive-cwd-relative paths is not ideal, but meh.
  { "a:meow",			{ "a:.", "meow", "" } },
  { "A:meow.txt",		{ "A:.", "meow", ".txt" } },
  { "z:meow/cow.",		{ "z:meow", "cow", "." } },
  { "Z:meow\\cats.exe",		{ "Z:meow", "cats", ".exe" } },
#endif
 };

 for(auto const& tve : gfpc_tv)
 {
  const std::string path = tve.path;
  std::string dir_path, file_base, file_ext;

  NVFS.get_file_path_components(path, &dir_path, &file_base, &file_ext);
  //
  if(dir_path != tve.parts[0] || file_base != tve.parts[1] || file_ext != tve.parts[2])
  {
   printf("%s: [%s] [%s] [%s]\n", path.c_str(), dir_path.c_str(), file_base.c_str(), file_ext.c_str());
   assert(0);
  }
 }
 //
 //
#if defined(WIN32) || defined(DOS)
 static const bool is_w32d = true;
#else
 static const bool is_w32d = false;
#endif
 static const bool pss12 = (MDFN_PSS_STYLE == 1 || MDFN_PSS_STYLE == 2);
 static const bool pss23 = (MDFN_PSS_STYLE == 2 || MDFN_PSS_STYLE == 3);
 static const bool pss2 = (MDFN_PSS_STYLE == 2);

 static const struct
 {
  const char* path;
  const bool is_abs;
  const bool is_dcwr;
 } whatever_tv[] =
 {
  { "meow", false, false },

  { "/meow", pss12, false },
  { "/meow/cow", pss12, false },

  { "\\meow", pss2, false },
  { "\\meow\\cow", pss2, false },

  { "a:\\", is_w32d, false },
  { "A://", is_w32d, false },
  { "z:\\", is_w32d, false },
  { "Z:\\", is_w32d, false },

  //
  // TODO: eventual code fixes so is_absolute_path() doesn't need to return 'true' for 
  // drive-cwd-relative paths on Windows?
  //
  { "a:", is_w32d, is_w32d },
  { "A:", is_w32d, is_w32d },
  { "z:", is_w32d, is_w32d },
  { "Z:", is_w32d, is_w32d },
  { "a:moo", is_w32d, is_w32d },
  { "A:moo", is_w32d, is_w32d },
  { "z:moo", is_w32d, is_w32d },
  { "Z:moo", is_w32d, is_w32d },
  { "C:./moo\\cow", is_w32d, is_w32d },
 };

 for(auto const& tve : whatever_tv)
 {
  const std::string path = tve.path;
  const bool is_abs = NVFS.is_absolute_path(path);
  const bool is_dcwr = NVFS.is_driverel_path(path);

  if(is_abs != tve.is_abs || is_dcwr != tve.is_dcwr)
  {
   printf("%s: %u %u\n", path.c_str(), is_abs, is_dcwr);
   assert(0);
  }
 }

 assert(NVFS.is_path_separator('/') == pss12);
 assert(NVFS.is_path_separator('\\') == pss23);
 assert(!NVFS.is_path_separator('A'));
 assert(!NVFS.is_path_separator(0));
}

}

using namespace MDFN_TESTS_CPP;

void MDFN_RunCheapTests(void)
{
 TestSStringNullChar();

 TestArithRightShift();

 DoAlignmentChecks();
 TestSignedOverflow();
 TestDefinedOverShift();
 TestBoolConv();
 TestNarrowConstFold();

 TestGCC60196();
 TestGCC69606();
 TestGCC70941();
 TestGCC71488();
 TestGCC80631();
 TestGCC81740();
 TestGCC86927();
 TestGCC97760();
 TestGCC98640();

 TestModTern();
 TestBWNotMask31GTZ();
 TestTernary();
 TestLLVM15470();

 TestSUCompare();

 TestSignExtend();

 DoAntiNSOBugTest();
 DoAntiNSOBugTest2014();

 TestMemcpySanity();

 DoLEPackerTest();

 TestLog2();

 TestRoundPow2();

 TestAbs();

 TestClamp();

 RunFPTests();

 RunMASMemTests();

 RunMiscEndianTests(0xAA010203, 0xBB030201);

 MDFN_RunExceptionTests(1, 0);

 RunSTLTests();

 LZTZCount_Test();

 NE1664_Test();

 md5_test();
 sha1_test();
 sha256_test();
 crc_test();

 zlib_test();

 memops_test();

 Time_Test();

 TestCastShift();

 TestUnionPun();

 TestI8Alias();

 TestSUSAlias();

 TestDiv();

 TestMDAP();

 TestArrayStruct();

 TestJump();

 TestSimpleBitset();

 TestStrArgsSplit();

 TestEscapeString();

 TestMiscString();

 TestFromStr();

 TestSndec();

 TestCDUtility();

 TestPathManip();
}

}
