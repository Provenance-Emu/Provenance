#ifndef __MDFN_TESTSEXP_H
#define __MDFN_TESTSEXP_H

namespace Mednafen
{
 void MDFNI_RunExpensiveTests(const char* dirpath) MDFN_COLD;
 void MDFNI_RunSwiftResamplerTest(void) MDFN_COLD;
 void MDFNI_RunOwlResamplerTest(void) MDFN_COLD;
 //
 void MDFN_RunExceptionTests(const unsigned thread_count, const unsigned thread_delay); // Called from tests.cpp
}

#endif

