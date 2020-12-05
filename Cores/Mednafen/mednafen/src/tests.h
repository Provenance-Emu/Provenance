#ifndef __MDFN_TESTS_H
#define __MDFN_TESTS_H

namespace Mednafen
{

bool MDFN_RunMathTests(void);
void MDFN_RunExceptionTests(const unsigned thread_count, const unsigned thread_delay);
void MDFN_RunSwiftResamplerTest(void);
void MDFN_RunOwlResamplerTest(void);

}

#endif

