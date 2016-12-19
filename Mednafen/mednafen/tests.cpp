// DO NOT REMOVE/DISABLE THESE MATH AND COMPILER SANITY TESTS.  THEY EXIST FOR A REASON.

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

// We really don't want NDEBUG defined ;)
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#undef NDEBUG

#include "mednafen.h"
#include "lepacker.h"

#include <mednafen/hash/sha1.h>
#include <mednafen/hash/sha256.h>

#include <zlib.h>

#undef NDEBUG
#include <assert.h>
#include <math.h>

#include "psx/masmem.h"
#include "general.h"

#if defined(HAVE_FENV_H)
#include <fenv.h>
#endif

#define FATALME	 { printf("Math test failed: %s:%d\n", __FILE__, __LINE__); fprintf(stderr, "Math test failed: %s:%d\n", __FILE__, __LINE__); return(0); }

namespace MDFN_TESTS_CPP
{

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

static bool DoSizeofTests(void)
{
 const int SizePairs[][2] =
 {
  { sizeof(uint8), 1 },
  { sizeof(int8), 1 },

  { sizeof(uint16), 2 },
  { sizeof(int16), 2 },

  { sizeof(uint32), 4 },
  { sizeof(int32), 4 },

  { sizeof(uint64), 8 },
  { sizeof(int64), 8 },

  { 0, 0 },
 };

 int i = -1;

 while(SizePairs[++i][0])
 {
  if(SizePairs[i][0] != SizePairs[i][1])
   FATALME;
 }

 assert(sizeof(char) == 1);
 assert(sizeof(int) == 4);
 assert(sizeof(long) >= 4);

 assert(sizeof(char) == SIZEOF_CHAR);
 assert(sizeof(short) == SIZEOF_SHORT);
 assert(sizeof(int) == SIZEOF_INT);
 assert(sizeof(long) == SIZEOF_LONG);
 assert(sizeof(long long) == SIZEOF_LONG_LONG);

 assert(sizeof(off_t) == SIZEOF_OFF_T);

 return(1);
}

static void AntiNSOBugTest_Sub1_a(int *array) NO_INLINE;
static void AntiNSOBugTest_Sub1_a(int *array)
{
 for(int value = 0; value < 127; value++)
  array[value] += (int8)value * 15;
}

static void AntiNSOBugTest_Sub1_b(int *array) NO_INLINE;
static void AntiNSOBugTest_Sub1_b(int *array)
{
 for(int value = 127; value < 256; value++)
  array[value] += (int8)value * 15;
}

static void AntiNSOBugTest_Sub2(int *array) NO_INLINE;
static void AntiNSOBugTest_Sub2(int *array)
{
 for(int value = 0; value < 256; value++)
  array[value] += (int8)value * 15;
}

static void AntiNSOBugTest_Sub3(int *array) NO_INLINE;
static void AntiNSOBugTest_Sub3(int *array)
{
 for(int value = 0; value < 256; value++)
 {
  if(value >= 128)
   array[value] = (value - 256) * 15;
  else
   array[value] = value * 15;
 }
}

static bool DoAntiNSOBugTest(void)
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
  if((array1[i] != array2[i]) || (array2[i] != array3[i]))
  {
   printf("%d %d %d %d\n", i, array1[i], array2[i], array3[i]);
   FATALME;
  }
 }
 //for(int value = 0; value < 256; value++)
 // printf("%d, %d\n", (int8)value, ((int8)value) * 15);

 return(1);
}

//
// Related: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=61741
//
// Not found to be causing problems in Mednafen(unlike the earlier no-strict-overflow problem and associated test),
// but better safe than sorry.
//
static void DoAntiNSOBugTest2014_SubA(int a) NO_INLINE NO_CLONE;
static void DoAntiNSOBugTest2014_SubA(int a)
{
 char c = 0;

 for(; a; a--)
 {
  for(; c >= 0; c++)
  {

  }
 }

 assert(c == -128);
}

static int ANSOBT_CallCount;
static void DoAntiNSOBugTest2014_SubMx_F(void) NO_INLINE NO_CLONE;
static void DoAntiNSOBugTest2014_SubMx_F(void)
{
 ANSOBT_CallCount++;

 assert(ANSOBT_CallCount < 1000);
}

static void DoAntiNSOBugTest2014_SubM1(void) NO_INLINE NO_CLONE;
static void DoAntiNSOBugTest2014_SubM1(void)
{
 char a;

 for(a = 127 - 1; a >= 0; a++)
  DoAntiNSOBugTest2014_SubMx_F();
}

static void DoAntiNSOBugTest2014_SubM3(void) NO_INLINE NO_CLONE;
static void DoAntiNSOBugTest2014_SubM3(void)
{
 char a;

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


bool DoLEPackerTest(void)
{
 MDFN::LEPacker mizer;
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

 if(mizer.size() != 24)
 {
  printf("Test failed: LEPacker data incorrect size.\n");
  return(FALSE);
 }

 for(unsigned int i = 0; i < mizer.size(); i++)
  if(mizer[i] != correct_result[i])
  {
   printf("Test failed: LEPacker packed data incorrect.\n");
   return(FALSE);
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

 mizer.set_read_mode(TRUE);

 mizer ^ u32_test;
 mizer ^ u16_test;
 mizer ^ u64_test;
 mizer ^ bool_test1;
 mizer ^ s32_test;
 mizer ^ bool_test0;
 mizer ^ s16_test;
 mizer ^ u8_test;
 mizer ^ s8_test;


 if(u32_test != 0xDEEDFEED)
 {
  printf("Test failed: LEPacker u32 unpacking incorrect.\n");
  return(FALSE);
 }

 if(u16_test != 0xCAAA)
 {
  printf("Test failed: LEPacker u16 unpacking incorrect.\n");
  return(FALSE);
 }

 if(u64_test != 0xDEADCAFEBABEBEEFULL)
 {
  printf("%16llx\n", (unsigned long long)u64_test);
  printf("Test failed: LEPacker u64 unpacking incorrect.\n");
  return(FALSE);
 }

 if(u8_test != 0x55)
 {
  printf("Test failed: LEPacker u8 unpacking incorrect.\n");
  return(FALSE);
 }

 if(s32_test != -5829478)
 {
  printf("Test failed: LEPacker s32 unpacking incorrect.\n");
  return(FALSE);
 }

 if(s16_test != -1)
 {
  printf("Test failed: LEPacker s16 unpacking incorrect.\n");
  return(FALSE);
 }

 if(s8_test != 127)
 {
  printf("Test failed: LEPacker s8 unpacking incorrect.\n");
  return(FALSE);
 }

 if(bool_test0 != 0)
 {
  printf("Test failed: LEPacker bool unpacking incorrect.\n");
  return(FALSE);
 }

 if(bool_test1 != 1)
 {
  printf("Test failed: LEPacker bool unpacking incorrect.\n");
  return(FALSE);
 }

 return(TRUE);
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

volatile int32 MDFNTestsCPP_SLS_Var = (int32)0xDEADBEEF;
volatile int8 MDFNTestsCPP_SLS_Var8 = (int8)0xEF;
volatile int16 MDFNTestsCPP_SLS_Var16 = (int16)0xBEEF;
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

static void TestSignedOverflow(void)
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

static uint8 BoolConvSupportFunc(void) MDFN_COLD NO_INLINE;
static uint8 BoolConvSupportFunc(void)
{
 return 0xFF;
}

static bool BoolConv0(void) MDFN_COLD NO_INLINE;
static bool BoolConv0(void)
{
 return BoolConvSupportFunc() & 1;
}

static void BoolTestThing(unsigned val) MDFN_COLD NO_INLINE;
static void BoolTestThing(unsigned val)
{
 if(val != 1)
  printf("%u\n", val);

 assert(val == 1);
}

static void TestBoolConv(void)
{
 BoolTestThing(BoolConv0());
}

static void TestNarrowConstFold(void) NO_INLINE MDFN_COLD;
static void TestNarrowConstFold(void)
{
 unsigned sa = 8;
 uint8 za[1] = { 0 };
 int a;

 a = za[0] < (uint8)(1 << sa);

 assert(a == 0);
}


unsigned MDFNTests_ModTern_a = 2;
unsigned MDFNTests_ModTern_b = 0;
static void ModTernTestEval(unsigned v) NO_INLINE MDFN_COLD;
static void ModTernTestEval(unsigned v)
{
 assert(v == 0);
}

static void TestModTern(void) NO_INLINE MDFN_COLD;
static void TestModTern(void)
{
 if(!MDFNTests_ModTern_b)
 {
  MDFNTests_ModTern_b = MDFNTests_ModTern_a;

  if(1 % (MDFNTests_ModTern_a ? MDFNTests_ModTern_a : 2))
   MDFNTests_ModTern_b = 0;
 }
 ModTernTestEval(MDFNTests_ModTern_b);
}

static int TestBWNotMask31GTZ_Sub(int a) NO_INLINE NO_CLONE;
static int TestBWNotMask31GTZ_Sub(int a)
{
 a = (((~a) & 0x80000000LL) > 0) + 1;
 return a;
}

static void TestBWNotMask31GTZ(void)
{
 assert(TestBWNotMask31GTZ_Sub(0) == 2);
}

int MDFN_tests_TestTernary_val = 0;
static void NO_INLINE NO_CLONE TestTernary_Sub(void)
{
 MDFN_tests_TestTernary_val++;
}

static void TestTernary(void)
{
 int a = ((MDFN_tests_TestTernary_val++) ? (MDFN_tests_TestTernary_val = 20) : (TestTernary_Sub(), MDFN_tests_TestTernary_val));

 assert(a == 2);
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
 int64 g = ~(uint32)0;
 uint64 h = ~(uint64)0;

 assert(a < b);
 assert(c < d);
 assert((uint32)e < f);
 assert((uint64)g < h);

 TestSUCompare_Sub<int8, uint8>(1, 255);
 TestSUCompare_Sub<int16, uint16>(1, 65535);

 TestSUCompare_Sub<int8, uint8>(TestSUCompare_x0, 255);
}

static void DoAlignmentChecks(void)
{
 uint8 padding0[3];
 alignas(16) uint8 aligned0[7];
 alignas(4)  uint8 aligned1[2];
 alignas(16) uint32 aligned2[2];
 uint8 padding1[3];

 static uint8 g_padding0[3];
 alignas(16) static uint8 g_aligned0[7];
 alignas(4)  static uint8 g_aligned1[2];
 alignas(16) static uint32 g_aligned2[2];
 static uint8 g_padding1[3];

 // Make sure compiler doesn't removing padding vars
 assert((&padding0[1] - &padding0[0]) == 1);
 assert((&padding1[1] - &padding1[0]) == 1);
 assert((&g_padding0[1] - &g_padding0[0]) == 1);
 assert((&g_padding1[1] - &g_padding1[0]) == 1);


 assert( (((unsigned long long)&aligned0[0]) & 0xF) == 0);
 assert( (((unsigned long long)&aligned1[0]) & 0x3) == 0);
 assert( (((unsigned long long)&aligned2[0]) & 0xF) == 0);

 assert(((uint8 *)&aligned0[1] - (uint8 *)&aligned0[0]) == 1);
 assert(((uint8 *)&aligned1[1] - (uint8 *)&aligned1[0]) == 1);
 assert(((uint8 *)&aligned2[1] - (uint8 *)&aligned2[0]) == 4);


 assert( (((unsigned long long)&g_aligned0[0]) & 0xF) == 0);
 assert( (((unsigned long long)&g_aligned1[0]) & 0x3) == 0);
 assert( (((unsigned long long)&g_aligned2[0]) & 0xF) == 0);

 assert(((uint8 *)&g_aligned0[1] - (uint8 *)&g_aligned0[0]) == 1);
 assert(((uint8 *)&g_aligned1[1] - (uint8 *)&g_aligned1[0]) == 1);
 assert(((uint8 *)&g_aligned2[1] - (uint8 *)&g_aligned2[0]) == 4);
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

static void NO_INLINE NO_CLONE ExceptionTestSub(int v, int n, int* y)
{
 if(n)
 {
  if(n & 1)
  {
   try
   {
    ExceptionTestSub(v + n, n - 1, y);
   }
   catch(const std::exception &e)
   {
    (*y)++;
    throw;
   }
  }
  else
   ExceptionTestSub(v + n, n - 1, y);
 }
 else
  throw MDFN_Error(v, "%d", v);
}

static void RunExceptionTests(void)
{
 int y = 0;
 int z = 0;

 for(int x = -8; x < 8; x++)
 {
  try
  {
   ExceptionTestSub(x, x & 3, &y);
  }
  catch(const MDFN_Error &e)
  {
   int epv = x;

   for(unsigned i = x & 3; i; i--)
    epv += i;

   z += epv;

   assert(e.GetErrno() == epv);
   assert(atoi(e.what()) == epv);
   continue;
  }
  catch(...)
  {
   abort();
  }
  abort();
 }

 assert(y == 16);
 assert(z == 32);
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

static void LZCount_Test(void)
{
 for(uint32 i = 0, x = 0; i < 33; i++, x = (x << 1) + 1)
 {
  assert(MDFN_lzcount32(x) == 32 - i);
 }

 for(uint32 i = 0, x = 0; i < 33; i++, x = (x ? (x << 1) : 1))
 {
  assert(MDFN_lzcount32(x) == 32 - i);
 }

 for(uint64 i = 0, x = 0; i < 65; i++, x = (x << 1) + 1)
 {
  assert(MDFN_lzcount64(x) == 64 - i);
 }

 for(uint64 i = 0, x = 0; i < 65; i++, x = (x ? (x << 1) : 1))
 {
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
double mdfn_fptest0_sub(double x, double n) MDFN_COLD NO_INLINE;
double mdfn_fptest0_sub(double x, double n)
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

static int pow_test_sub_a(int y, double z) NO_INLINE NO_CLONE;
static int pow_test_sub_a(int y, double z)
{
 return std::min<int>(floor(pow(10, z)), std::min<int>(floor(pow(10, y)), (int)pow(10, y)));
}

static int pow_test_sub_b(int y) NO_INLINE NO_CLONE;
static int pow_test_sub_b(int y)
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

#if 0
static void NO_CLONE NO_INLINE ThreadSub(int tv)
{
 throw MDFN_Error(tv, "%d\n", tv);
}


static int ThreadTestEntry(void* data)
{
 const uint32 st = *(uint32*)data;

 while(MDFND_GetTime() < st)
 {
  try
  {
   ThreadSub(rand());
  }
  catch(MDFN_Error &e)
  {
   assert(e.GetErrno() == atoi(e.what()));
  }
 }

 return 0;
}


static void RunThreadTests(void)
{
 MDFN_Thread *a, *b, *c, *d;
 uint32 t = MDFND_GetTime() + 5000;

 a = MDFND_CreateThread(ThreadTestEntry, &t);
 b = MDFND_CreateThread(ThreadTestEntry, &t);
 c = MDFND_CreateThread(ThreadTestEntry, &t);
 d = MDFND_CreateThread(ThreadTestEntry, &t);
 
 MDFND_WaitThread(a, NULL);
 MDFND_WaitThread(b, NULL);
 MDFND_WaitThread(c, NULL);
 MDFND_WaitThread(d, NULL);
}
#endif

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

const char* MDFN_tests_stringA = "AB\0C";
const char* MDFN_tests_stringB = "AB\0CD";
const char* MDFN_tests_stringC = "AB\0X";

}

using namespace MDFN_TESTS_CPP;

bool MDFN_RunMathTests(void)
{
 MathTestEntry *itoo = math_test_vals;

 if(!DoSizeofTests())
  return(0);

 assert(MDFN_tests_stringA != MDFN_tests_stringB && MDFN_tests_stringA[3] == 'C' && MDFN_tests_stringB[4] == 'D');
 assert(MDFN_tests_stringA != MDFN_tests_stringC && MDFN_tests_stringB != MDFN_tests_stringC && MDFN_tests_stringC[3] == 'X');

 // Make sure the "char" type is signed(pass -fsigned-char to gcc).  New code in Mednafen shouldn't be written with the
 // assumption that "char" is signed, but there likely is at least some code that does.
 {
  char tmp = 255;
  assert(tmp < 0);
 }

 #if 0
 // TODO(except for 32-bit >> 32 test)
 {
  uint8 test_cow8 = (uint8)0xFF >> mdfn_shifty_test[1];
  uint16 test_cow16 = (uint16)0xFFFF >> mdfn_shifty_test[2];
  uint32 test_cow32 = (uint32)0xFFFFFFFF >> mdfn_shifty_test[3];
  uint32 test_cow32_2 = (uint32)0xFFFFFFFF >> mdfn_shifty_test[0];

 printf("%08x\n", test_cow32);

  assert(test_cow8 == 0);
  assert(test_cow16 == 0);
  assert(test_cow32 == 0);
  assert(test_cow32_2 == 0xFFFFFFFF);
 }
 #endif

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

 DoAlignmentChecks();
 TestSignedOverflow();
 TestDefinedOverShift();
 TestBoolConv();
 TestNarrowConstFold();

 TestGCC60196();

 TestModTern();
 TestBWNotMask31GTZ();
 TestTernary();
 TestLLVM15470();

 TestSUCompare();

 if(sign_9_to_s16(itoo->negative_one) != -1 || sign_9_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_10_to_s16(itoo->negative_one) != -1 || sign_10_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_11_to_s16(itoo->negative_one) != -1 || sign_11_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_12_to_s16(itoo->negative_one) != -1 || sign_12_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_13_to_s16(itoo->negative_one) != -1 || sign_13_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_14_to_s16(itoo->negative_one) != -1 || sign_14_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_15_to_s16(itoo->negative_one) != -1 || sign_15_to_s16(itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(17, itoo->negative_one) != -1 || sign_x_to_s32(17, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(18, itoo->negative_one) != -1 || sign_x_to_s32(18, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(19, itoo->negative_one) != -1 || sign_x_to_s32(19, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(20, itoo->negative_one) != -1 || sign_x_to_s32(20, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(21, itoo->negative_one) != -1 || sign_x_to_s32(21, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(22, itoo->negative_one) != -1 || sign_x_to_s32(22, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(23, itoo->negative_one) != -1 || sign_x_to_s32(23, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(24, itoo->negative_one) != -1 || sign_x_to_s32(24, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(25, itoo->negative_one) != -1 || sign_x_to_s32(25, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(26, itoo->negative_one) != -1 || sign_x_to_s32(26, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(27, itoo->negative_one) != -1 || sign_x_to_s32(27, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(28, itoo->negative_one) != -1 || sign_x_to_s32(28, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(29, itoo->negative_one) != -1 || sign_x_to_s32(29, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(30, itoo->negative_one) != -1 || sign_x_to_s32(30, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sign_x_to_s32(31, itoo->negative_one) != -1 || sign_x_to_s32(31, itoo->mostneg) != itoo->mostnegresult)
  FATALME;
 itoo++;

 if(sizeof(int8) != 1 || sizeof(uint8) != 1)
  FATALME;


 if(!DoAntiNSOBugTest())
  return(0);

 DoAntiNSOBugTest2014();

 if(!DoLEPackerTest())
  return(0);

 assert(uilog2(0) == 0);
 assert(uilog2(1) == 0);
 assert(uilog2(3) == 1);
 assert(uilog2(4095) == 11);
 assert(uilog2(0xFFFFFFFF) == 31);

 RunFPTests();

 RunMASMemTests();

#pragma message "this test is failing, if something goes wrong, it could be because of this comment"
 //RunExceptionTests();

 //RunThreadTests();

 RunSTLTests();

 LZCount_Test();

 sha1_test();
 sha256_test();

 zlib_test();

#if 0
// Not really a math test.
 const char *test_paths[] = { "/meow", "/meow/cow", "\\meow", "\\meow\\cow", "\\\\meow", "\\\\meow\\cow",
			      "/meow.", "/me.ow/cow.", "\\meow.", "\\me.ow\\cow.", "\\\\meow.", "\\\\meow\\cow.",
			      "/meow.txt", "/me.ow/cow.txt", "\\meow.txt", "\\me.ow\\cow.txt", "\\\\meow.txt", "\\\\meow\\cow.txt"

			      "/meow", "/meow\\cow", "\\meow", "\\meow/cow", "\\\\meow", "\\\\meow/cow",
			      "/meow.", "\\me.ow/cow.", "\\meow.", "/me.ow\\cow.", "\\\\meow.", "\\\\meow/cow.",
			      "/meow.txt", "/me.ow\\cow.txt", "\\meow.txt", "\\me.ow/cow.txt", "\\\\meow.txt", "\\\\meow/cow.txt",
			      "/bark///dog", "\\bark\\\\\\dog" };

 for(unsigned i = 0; i < sizeof(test_paths) / sizeof(const char *); i++)
 {
  std::string file_path = std::string(test_paths[i]);
  std::string dir_path;
  std::string file_base;
  std::string file_ext;

  MDFN_GetFilePathComponents(file_path, &dir_path, &file_base, &file_ext);

  printf("%s ------ dir=%s --- base=%s --- ext=%s\n", file_path.c_str(), dir_path.c_str(), file_base.c_str(), file_ext.c_str());

 }
#endif


 return(1);
}
