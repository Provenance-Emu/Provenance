/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* testsexp.cpp - Expensive tests
**  Copyright (C) 2014-2020 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include <mednafen/mednafen.h>
#include <mednafen/Time.h>
#include <mednafen/FileStream.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/MTStreamReader.h>
#include <mednafen/compress/GZFileStream.h>
#include <mednafen/MThreading.h>
#include <mednafen/sound/SwiftResampler.h>
#include <mednafen/sound/OwlResampler.h>
#include <mednafen/sound/WAVRecord.h>

#ifdef WIN32
 #include <mednafen/win32-common.h>
#endif

#include "testsexp.h"

#include <atomic>

#undef NDEBUG
#include <assert.h>

namespace Mednafen
{
//
static uint64 lcg;

static void TestRandInit(void)
{
 lcg = 0xDEADBEEFCAFEBABEULL;
};

static uint32 TestRand(void)
{
 lcg = (lcg * 6364136223846793005ULL) + 1442695040888963407ULL;

 return lcg >> 32;
}

void MDFNI_RunSwiftResamplerTest(void)
{
 static const double input_rates[] =
 {
  //1500000,
  1662607.125,
  1789772.72727272
  //2000000
 };

 const double rate_error = 0.00004;

 for(int quality = 3; quality <= 3; quality++)
 {
  for(unsigned iri = 0; iri < sizeof(input_rates) / sizeof(input_rates[0]); iri++)
  {
   const double irate = input_rates[iri];
   const int32 output_rates[] =
   {
    //22050, 32000, 44100, 48000, 64000, 96000, 192000
    22050,
    44100,
    48000, 96000, 192000, 
    //(int32)floor(0.5 + irate / 32)
   };

   for(unsigned ori = 0; ori < sizeof(output_rates) / sizeof(output_rates[0]); ori++)
   {
    const int32 orate = output_rates[ori];
    std::unique_ptr<SwiftResampler> res(new SwiftResampler(irate, orate, rate_error, 0, quality));
    char fn[256];
    snprintf(fn, sizeof(fn), "swift-%s-q%d-%u-%u.wav", res->GetSIMDType(), quality, (unsigned)irate, (unsigned)orate);
    std::unique_ptr<WAVRecord> wr(new WAVRecord(fn, orate, 1));
    std::unique_ptr<int16[]> ibuf(new int16[65536]);
    std::unique_ptr<int16[]> obuf(new int16[65536]);
    int32 leftover = 0;
    double phase = 0;
    double phase_inc = 0.000;
    double phase_inc_inc = 0.000000001;

    for(int base_i = 0; base_i < irate * 60 * 2; base_i += 32768)
    {
     for(int i = 0; i < 32768; i++)
     {
      ibuf[i + leftover] = floor(0.5 + 32767 * 0.95 * sin(phase));
      phase += phase_inc;
      phase_inc += phase_inc_inc;
     }
     const int32 inlen = leftover + 32768;
     const int32 outlen = res->Do(&ibuf[0], &obuf[0], 65536, inlen, &leftover);

     memmove(&ibuf[0], &ibuf[inlen - leftover], leftover * sizeof(int16));

     wr->WriteSound(&obuf[0], outlen);
    }
   }
  }
 }
}

void MDFNI_RunOwlResamplerTest(void)
{
 static const double input_rates[] =
 {
  /*1500000, 1662607.125,*/ 1789772.72727272 /*, 2000000*/
 };

 const double rate_error = 0.00004;
 //for(int quality = -2; quality <= 5; quality++)
 int quality = 5;
 {
  for(unsigned iri = 0; iri < sizeof(input_rates) / sizeof(input_rates[0]); iri++)
  {
   const double irate = input_rates[iri];

   const int32 output_rates[] =
   {
    44100, 48000, 96000, 192000, (int32)floor(0.5 + irate / 32)
   };

   for(unsigned ori = 0; ori < sizeof(output_rates) / sizeof(output_rates[0]); ori++)
   {
    const int32 orate = output_rates[ori];
    std::unique_ptr<OwlResampler> res(new OwlResampler(irate, orate, rate_error, 0, quality));
    std::unique_ptr<OwlBuffer> ibuf(new OwlBuffer());
    char fn[256];
    snprintf(fn, sizeof(fn), "owl-%s-q%d-%u-%u.wav", res->GetSIMDType(), quality, (unsigned)irate, (unsigned)orate);
    std::unique_ptr<WAVRecord> wr(new WAVRecord(fn, orate, 1));
    std::unique_ptr<int16[]> obuf(new int16[65536 * 2]);
    double phase = 0;
    double phase_inc = 0.000;
    double phase_inc_inc = 0.000000001;
    const int32 inlen = 16384;

    for(int base_i = 0; base_i < irate * 60 * 2; base_i += inlen)
    {
     for(int i = 0; i < inlen; i++)
     {
      ibuf->BufPudding()[i].f = 256 * 32767 * 0.95 * sin(phase);
      phase += phase_inc;
      phase_inc += phase_inc_inc;
     }
     const int32 outlen = res->Resample(ibuf.get(), inlen, &obuf[0], 65536);

     for(int32 i = 0; i < outlen; i++)
      obuf[i] = obuf[i * 2];

     wr->WriteSound(&obuf[0], outlen);
    }
   }
  }
 }
}

static void TestMTStreamReader(void)
{
 for(uint32 pzb = 0; pzb < 256; pzb = (pzb * 3) + 1)
 for(uint32 test_size = 0; test_size < 256 * 2; test_size++)
 for(uint32 loop_pos = 0; loop_pos <= test_size; loop_pos++)
 {
  //printf("pzb=0x%04x, test_size=0x%04x, loop_pos=0x%04x\n", pzb, test_size, loop_pos);
  //
  std::unique_ptr<MTStreamReader> test_mtsr(new MTStreamReader(0));
  std::unique_ptr<MemoryStream> test_stream(new MemoryStream(test_size, true));
  //
  for(uint64 i = 0; i < test_size; i++)
  {
   test_stream->map()[i] = TestRand();
   //printf("%u: 0x%02x\n", (unsigned)i, (uint8)(lcg >> 32));
  }
  //
  const uint8* const g = test_stream->map();
  {
   MTStreamReader::StreamInfo si;
   si.size = test_stream->size();
   si.loop_pos = loop_pos;
   si.stream = std::move(test_stream);
   si.pos = 0;

   test_mtsr->add_stream(std::move(si));
   test_mtsr->set_active_stream(0, 0, pzb);
  }
  //
  for(uint64 i = 0; i < pzb; i++)
  {
   uint8* b =  test_mtsr->get_buffer(1);
   if(*b != 0)
   {
    printf("0x%02x\n", *b);
    assert(*b == 0);
   }
   test_mtsr->advance(1);
  }
  
  for(uint32 i = 0; i < /*1024 * 1024*/16384; i++)
  {
   uint8* b = test_mtsr->get_buffer(1);

   if(test_size == loop_pos && i >= test_size)
   {
    assert(*b == 0);
   }
   else
   {
    uint8 test_b = g[(i < test_size) ? i : loop_pos + ((i - test_size) % (test_size - loop_pos))];

    //printf("%u: 0x%02x 0x%02x\n", (unsigned)i, *b, test_b);

    if(*b != test_b)
    {
     fprintf(stderr, "TestMTStreamReader() test_size=%llu, i=%llu\n", (unsigned long long)test_size, (unsigned long long)i);
     abort();
    }
   }
   //
   test_mtsr->advance(1);
  }
 }
}

static void Stream64Test(const char* path)
{
 try
 {
  {
   FileStream fp(path, FileStream::MODE_WRITE);

   assert(fp.tell() == 0);
   assert(fp.size() == 0);
   fp.put_BE<uint32>(0xDEADBEEF);
   assert(fp.tell() == 4);
   assert(fp.size() == 4);

   fp.seek(0x7FFFFFFFU, SEEK_SET);
   assert(fp.tell() == 0x7FFFFFFFU);
   fp.truncate(0x7FFFFFFFU);
   assert(fp.size() == 0x7FFFFFFFU);
   fp.put_LE<uint8>(0xB0);
   assert(fp.tell() == 0x80000000U);
   assert(fp.size() == 0x80000000U);
   fp.put_LE<uint8>(0x0F);
   assert(fp.tell() == 0x80000001U);
   assert(fp.size() == 0x80000001U);

   fp.seek(0xFFFFFFFFU, SEEK_SET);
   assert(fp.tell() == 0xFFFFFFFFU);
   fp.truncate(0xFFFFFFFFU);
   assert(fp.size() == 0xFFFFFFFFU);
   fp.put_LE<uint8>(0xCA);
   assert(fp.tell() == 0x100000000ULL);
   assert(fp.size() == 0x100000000ULL);
   fp.put_LE<uint8>(0xAD);
   assert(fp.tell() == 0x100000001ULL);
   assert(fp.size() == 0x100000001ULL);

   fp.seek((uint64)8192 * 1024 * 1024, SEEK_SET);
   fp.put_BE<uint32>(0xCAFEBABE);
   assert(fp.tell() == (uint64)8192 * 1024 * 1024 + 4);
   assert(fp.size() == (uint64)8192 * 1024 * 1024 + 4);

   fp.put_BE<uint32>(0xAAAAAAAA);
   assert(fp.tell() == (uint64)8192 * 1024 * 1024 + 8);
   assert(fp.size() == (uint64)8192 * 1024 * 1024 + 8);

   fp.truncate((uint64)8192 * 1024 * 1024 + 4);
   assert(fp.size() == (uint64)8192 * 1024 * 1024 + 4);

   fp.seek(-((uint64)8192 * 1024 * 1024 + 8), SEEK_CUR);
   assert(fp.tell() == 0);
   fp.seek((uint64)-4, SEEK_END);
   assert(fp.tell() == (uint64)8192 * 1024 * 1024);
  }

  {
   FileStream fp(path, FileStream::MODE_READ);
   uint32 tmp;

   assert(fp.size() == (uint64)8192 * 1024 * 1024 + 4);
   tmp = fp.get_LE<uint32>();
   assert(tmp == 0xEFBEADDE);
   fp.seek((uint64)8192 * 1024 * 1024 - 4, SEEK_CUR);
   tmp = fp.get_LE<uint32>(); 
   assert(tmp == 0xBEBAFECA);
  }

  {
   GZFileStream fp(path, GZFileStream::MODE::READ);
   uint32 tmp;

   tmp = fp.get_LE<uint32>();
   assert(tmp == 0xEFBEADDE);
   fp.seek((uint64)8192 * 1024 * 1024 - 4, SEEK_CUR);
   tmp = fp.get_LE<uint32>(); 
   assert(tmp == 0xBEBAFECA);  
   assert(fp.tell() == (uint64)8192 * 1024 * 1024 + 4);
  }
 }
 catch(std::exception& e)
 {
  printf("%s\n", e.what());
  abort();
 }
}

static void StreamBufTest(const char* path)
{
 try
 {
  MemoryStream fp2;
  {
   FileStream fp(path, FileStream::MODE_WRITE, false, 4);
   //const uint64 st = Time::MonoUS();

   for(unsigned i = 0; i < 1024 * 1024; i++)
   {
    const uint32 t = TestRand() & 0xF;
    uint8 buf[16];

    for(unsigned j = 0; j < t; j++)
     buf[j] = TestRand();

    assert(fp.tell() == fp2.tell());
    //printf("%lld %lld (%d) \n", (long long)fp.size(), (long long)fp2.size(), t);

    fp.write(buf, t);
    fp2.write(buf, t);

    switch(TestRand() & 0x1FF)
    {
     case 0:
     case 1:
     {
      int64 sd = (int64)(TestRand() & 0xF) - 8;

      if((fp2.tell() + sd) < 0)
       sd = -fp2.tell();

      //printf("Seek: %lld\n", (long long)sd);

      fp.seek(sd, SEEK_CUR);
      fp2.seek(sd, SEEK_CUR);
     }
     break;

     case 2:
     {
      const int64 ta = (int64)(TestRand() & 0xF) - 8;

      //printf("Truncate: %lld (%lld %lld)\n", (long long)ta, (long long)fp.tell(), (long long)fp2.tell());

      fp.truncate(std::max<int64>(0, fp.tell() + ta));
      fp2.truncate(std::max<int64>(0, fp2.tell() + ta));
     }
     break;

     case 3:
     {
      assert(fp.size() == fp2.size());
     }
     break;
    }
   }
   //printf("%llu\n", (unsigned long long)Time::MonoUS() - st);
  }

  fp2.rewind();
  {
   FileStream fp(path, FileStream::MODE_READ, false, 4);

   //printf("%lld %lld\n", (long long)fp.size(), (long long)fp2.size());
   assert(fp.size() == fp2.size());

   for(uint64 i = fp2.size(); i; i--)
   {
    int a = fp.get_char();
    int b = fp2.get_u8(); //char();

    assert(fp.tell() == fp2.tell());
    assert(a == b);
   }
  }

  fp2.rewind();
  {
   FileStream fp(path, FileStream::MODE_READ, false, 4);

   assert(fp.size() == fp2.size());

   for(uint64 i = fp2.size(); i;)
   {
    uint64 ra = std::min<uint64>(i, TestRand() & 0xF);
    uint8 a[16];
    uint8 b[16];

    fp.read(a, ra);
    fp2.read(b, ra);

    assert(fp.tell() == fp2.tell());
    assert(!memcmp(a, b, ra));

    i -= ra;
   }
  }


  fp2.rewind();
  {
   FileStream fp(path, FileStream::MODE_READ, false, 4);

   for(unsigned i = 0; i < 1024 * 1024; i++)
   {
    const uint32 t = TestRand() & 0xF;
    uint8 a[16];
    uint8 b[16];
    uint64 rva;
    uint64 rvb;

    rva = fp.read(a, t, false);
    rvb = fp2.read(b, t, false);

    assert(fp.tell() == fp2.tell());
    assert(rva == rvb);
    assert(!memcmp(a, b, t));

    switch(TestRand() & 0x1FF)
    {
     case 0:
     case 1:
     {
      int64 sd = (int64)(TestRand() & 0xF) - 8;

      if((fp2.tell() + sd) < 0)
       sd = -fp2.tell();

      //printf("Seek: %lld\n", (long long)sd);

      fp.seek(sd, SEEK_CUR);
      fp2.seek(sd, SEEK_CUR);
     }
     break;

     case 2:
     {
      uint8 tmp;

      fp.get_char();
      fp2.read(&tmp, 1, false);
     }
     break;
    }
   }
  }

  fp2.rewind();
  {
   FileStream fp(path, FileStream::MODE_READ_WRITE, false, 4);

   for(unsigned i = 0; i < 1024 * 1024; i++)
   {
    const uint32 t = TestRand() & 0xF;
    uint8 a[16];
    uint8 b[16];
    uint64 rva;
    uint64 rvb;

    rva = fp.read(a, t, false);
    rvb = fp2.read(b, t, false);

    assert(fp.tell() == fp2.tell());
    assert(rva == rvb);
    assert(!memcmp(a, b, t));

    switch(TestRand() & 0x1FF)
    {
     case 0:
     case 1:
     {
      int64 sd = (int64)(TestRand() & 0xF) - 8;

      if((fp2.tell() + sd) < 0)
       sd = -fp2.tell();

      //printf("Seek: %lld\n", (long long)sd);

      fp.seek(sd, SEEK_CUR);
      fp2.seek(sd, SEEK_CUR);
     }
     break;

     case 2:
     {
      uint8 tmp;

      fp.get_char();
      fp2.read(&tmp, 1, false);
     }
     break;

     case 3:
     case 4:
     case 5:
     {
	uint16 tmp = TestRand();
	fp.put_LE<uint16>(tmp);
	fp2.put_LE<uint16>(tmp);
     }
     break;
    }
   }
  }

  fp2.rewind();
  {
   FileStream fp(path, FileStream::MODE_READ, false, 4);

   //printf("%lld %lld\n", (long long)fp.size(), (long long)fp2.size());
   assert(fp.size() == fp2.size());

   for(uint64 i = fp2.size(); i; i--)
   {
    int a = fp.get_char();
    int b = fp2.get_u8(); //char();

    assert(fp.tell() == fp2.tell());
    assert(a == b);
   }
  }
  //
  //
  //
  {
   FileStream fp(path, FileStream::MODE_WRITE, false);

   fp.put_BE<uint32>(0x5A1DA265);
  }

  {
   FileStream fp(path, FileStream::MODE_READ_WRITE, false);

   assert(fp.get_char() == 0x5A);
   fp.put_LE<uint16>(0x57BF);
   assert(fp.get_char() == 0x65);
   assert(fp.get_char() == -1);
   assert(fp.get_char() == -1);
   fp.put_LE<uint8>(0xAA);
   assert(fp.get_char() == -1);
   fp.seek(0, SEEK_SET);
   assert(fp.get_char() == 0x5A);
   assert(fp.get_char() == 0xBF);
   assert(fp.get_char() == 0x57);
   assert(fp.get_char() == 0x65);
   assert(fp.get_char() == 0xAA);
   assert(fp.get_char() == -1);
   assert(fp.tell() == 5);
   assert(fp.size() == 5);
   fp.seek(0, SEEK_SET);
  }
 }
 catch(std::exception& e)
 {
  printf("%s\n", e.what());
  abort();
 }
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

static NO_CLONE NO_INLINE int RunExceptionTests_TEP(void* data)
{
 std::atomic_int_least32_t* sv = (std::atomic_int_least32_t*)data;

 sv->fetch_sub(1, std::memory_order_release);

 while(sv->load(std::memory_order_acquire) > 0);

 unsigned t = 0;

 for(; !t || sv->load(std::memory_order_acquire) == 0; t++)
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

 return t;
}

static int ThreadSafeErrno_Test_Entry(void* data)
{
 MThreading::Sem** sem = (MThreading::Sem**)data;

 errno = 0;

 MThreading::Sem_Post(sem[0]);
 MThreading::Sem_Wait(sem[1]);

 errno = 0xDEAD;
 MThreading::Sem_Post(sem[0]);
 return 0;
}

static void ThreadSafeErrno_Test(void)
{
 //uint64 st = Time::MonoUS();
 //
 MThreading::Sem* sem[2] = { MThreading::Sem_Create(), MThreading::Sem_Create() };
 MThreading::Thread* thr = MThreading::Thread_Create(ThreadSafeErrno_Test_Entry, sem);

 MThreading::Sem_Wait(sem[0]);
 errno = 0;
 MThreading::Sem_Post(sem[1]);
 MThreading::Sem_Wait(sem[0]);
 assert(errno != 0xDEAD);
 MThreading::Thread_Wait(thr, nullptr);
 //
 for(int i = 9; i >= 0; i--)
 {
  const uint64 st = Time::MonoUS();
  unsigned ms = i * 10;

  MThreading::Sem_TimedWait(sem[i & 1], ms);

  printf("sem wait requested: %uus, actual: %lluus\n", ms * 1000, (unsigned long long)(Time::MonoUS() - st));
 }
 //
 MThreading::Sem_Destroy(sem[0]);
 MThreading::Sem_Destroy(sem[1]);
 //
 //
 //
 errno = 0;
 //printf("%llu\n", (unsigned long long)Time::MonoUS() - st);
}

void MDFN_RunExceptionTests(const unsigned thread_count, const unsigned thread_delay)
{
 std::atomic_int_least32_t sv;

 if(thread_count == 1)
 {
  sv.store(-1, std::memory_order_release);
  RunExceptionTests_TEP(&sv);
 }
 else
 {
  ThreadSafeErrno_Test();
  //
  //
  std::vector<MThreading::Thread*> t;
  std::vector<int> trv;

  t.resize(thread_count);
  trv.resize(thread_count);

  sv.store(thread_count, std::memory_order_release);

  for(unsigned i = 0; i < thread_count; i++)
   t[i] = MThreading::Thread_Create(RunExceptionTests_TEP, &sv);

  Time::SleepMS(thread_delay);

  sv.store(-1, std::memory_order_release);

  for(unsigned i = 0; i < thread_count; i++)
   MThreading::Thread_Wait(t[i], &trv[i]);

  for(unsigned i = 0; i < thread_count; i++)
   printf("%d: %d\n", i, trv[i]);
 }
}

#if 0
static MThreading::Mutex* milk_mutex = NULL;
static MThreading::Cond* milk_cond = NULL;
static volatile unsigned cow_milk = 0;
static volatile unsigned farmer_milk = 0;
static volatile unsigned calf_milk = 0;
static volatile unsigned am3000_milk = 0;

static int CowEntry(void*)
{
 uint32 start_time = Time::MonoMS();

 for(unsigned i = 0; i < 1000 * 1000; i++)
 {
  MThreading::Mutex_Lock(milk_mutex);
  cow_milk++;

  MThreading::Cond_Signal(milk_cond);
  MThreading::Mutex_Unlock(milk_mutex);

  while(cow_milk != 0);
 }

 while(cow_milk != 0);

 return Time::MonoMS() - start_time;
}

static int FarmerEntry(void*)
{
 MThreading::Mutex_Lock(milk_mutex);
 while(1)
 {
  MThreading::Cond_Wait(milk_cond, milk_mutex);

  farmer_milk += cow_milk;
  cow_milk = 0;
 }
 MThreading::Mutex_Unlock(milk_mutex);

 return 0;
}

static int CalfEntry(void*)
{
 MThreading::Mutex_Lock(milk_mutex);
 while(1)
 {
  MThreading::Cond_Wait(milk_cond, milk_mutex);

  calf_milk += cow_milk;
  cow_milk = 0;
 }
 MThreading::Mutex_Unlock(milk_mutex);
 return 0;
}

static int AutoMilker3000Entry(void*)
{
 MThreading::Mutex_Lock(milk_mutex);
 while(1)
 {
  MThreading::Cond_Wait(milk_cond, milk_mutex);

  am3000_milk += cow_milk;
  cow_milk = 0;
 }
 MThreading::Mutex_Unlock(milk_mutex);
 return 0;
}

static void ThreadTest(void)
{
 MThreading::Thread *cow_thread, *farmer_thread, *calf_thread, *am3000_thread;
 int rec;

 milk_mutex = MThreading::Mutex_Create();
 milk_cond = MThreading::Cond_Create();

 //farmer_thread = MThreading::Thread_Create(FarmerEntry, NULL);
 //calf_thread = MThreading::Thread_Create(CalfEntry, NULL);
 //am3000_thread = MThreading::Thread_Create(AutoMilker3000Entry, NULL);

 cow_thread = MThreading::Thread_Create(CowEntry, NULL);
 MThreading::Thread_Wait(cow_thread, &rec);

 printf("%8u %8u %8u --- %8u, time=%u\n", farmer_milk, calf_milk, am3000_milk, farmer_milk + calf_milk + am3000_milk, rec);
}
#endif

static void TestSurface(void)
{
 static const uint64 formats[] =
 {
  MDFN_PixelFormat::ABGR32_8888,
  MDFN_PixelFormat::ARGB32_8888,
  MDFN_PixelFormat::RGBA32_8888,
  MDFN_PixelFormat::BGRA32_8888,
  MDFN_PixelFormat::IRGB16_1555,
  MDFN_PixelFormat::RGB16_565,
  MDFN_PixelFormat::ARGB16_4444
 };

 for(int pitch_fudge = 0; pitch_fudge < 8; pitch_fudge++)
 {
  for(uint64 src_format_tag : formats)
  {
   const MDFN_PixelFormat src_format(src_format_tag);

   for(uint64 dest_format_tag : formats)
   {
    const MDFN_PixelFormat dest_format(dest_format_tag);
    MDFN_Surface surf(nullptr, 256, 128, 256 + pitch_fudge, src_format);

    TestRandInit();
    for(int y = 0; y < surf.h; y++)
    {
     for(int x = 0; x < surf.w; x++)
     {
      const uint8 r = TestRand();
      const uint8 g = TestRand();
      const uint8 b = TestRand();
      const uint8 a = TestRand(); 
      const uint32 c = surf.MakeColor(r, g, b, a);

      if(surf.format.opp == 4)
       surf.pix<uint32>()[y * surf.pitchinpix + x] = c;
      else
       surf.pix<uint16>()[y * surf.pitchinpix + x] = c;
     }
    }

    surf.SetFormat(dest_format, true);
    assert(surf.format.tag == dest_format_tag);
    assert(surf.format.colorspace == (uint8)(surf.format.tag >> 56));
    assert(surf.format.opp == (uint8)(surf.format.tag >> 48));
    assert(surf.w == 256);
    assert(surf.h == 128);
    assert(surf.pitchinpix == (256 + pitch_fudge));

    TestRandInit();
    for(int y = 0; y < surf.h; y++)
    {
     for(int x = 0; x < surf.w; x++)
     {
      const uint8 r = TestRand();
      const uint8 g = TestRand();
      const uint8 b = TestRand();
      const uint8 a = TestRand();
      uint32 cc;

      cc = src_format.MakeColor(r, g, b, a) & (((uint64)1U << (src_format.opp * 8)) - 1);
      if(src_format_tag != dest_format_tag)
      {
       int nr, ng, nb, na;
       src_format.DecodeColor(cc, nr, ng, nb, na);
       cc = dest_format.MakeColor(nr, ng, nb, na) & (((uint64)1U << (dest_format.opp * 8)) - 1);
      }
      //
      uint32 c;

      if(surf.format.opp == 4)
       c = surf.pix<uint32>()[y * surf.pitchinpix + x];
      else
       c = surf.pix<uint16>()[y * surf.pitchinpix + x];

      if(c != cc)
      {
       printf("0x%016llx -> 0x%016llx: y=%d x=%d --- r=0x%02x g=0x%02x b=0x%02x 0x%08x 0x%08x\n", (unsigned long long)src_format_tag, (unsigned long long)dest_format_tag, y, x, r, g, b, c, cc);
       assert(0);
      }
     }
    }
   }
   //
   //
   //
   {
    MDFN_Surface surf(nullptr, 8, 8, 8 + pitch_fudge, src_format);

    TestRandInit();
    for(int i = 0; i < 64; i++)
    {
     const uint8 r = TestRand();
     const uint8 g = TestRand();
     const uint8 b = TestRand();
     const uint8 a = TestRand();
     const uint32 cc = surf.MakeColor(r, g, b, a) & (((uint64)1U << (src_format.opp * 8)) - 1);

     surf.Fill(r, g, b, a);

     for(int y = 0; y < surf.h; y++)
     {
      for(int x = 0; x < surf.pitchinpix; x++)
      {
       uint32 c;

       if(surf.format.opp == 4)
        c = surf.pix<uint32>()[y * surf.pitchinpix + x];
       else
        c = surf.pix<uint16>()[y * surf.pitchinpix + x];

       if(c != cc)
       {
        printf("0x%08x 0x%08x\n", c, cc);
        assert(0);
       }
      }
     }
    }
   }
  }
 }
}

void MDFNI_RunExpensiveTests(const char* dirpath)
{
 TestRandInit();
 //
 TestSurface();
 //
 //TestMTStreamReader();

 {
  const std::string path = std::string(dirpath) + PSS + "streamtest.bin";

  #if defined(WIN32) && !defined(UNICODE)
  if(!(GetVersion() & 0x80000000))
  #endif
  {
   Stream64Test(path.c_str());
  }

  StreamBufTest(path.c_str());
 }
 //
 //ThreadTest();
 //
 MDFN_RunExceptionTests(1, 0);
 MDFN_RunExceptionTests(4, 30000);
}


//
}
