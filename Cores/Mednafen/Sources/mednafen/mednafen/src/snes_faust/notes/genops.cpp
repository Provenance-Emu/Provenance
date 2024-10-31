#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

int main(int argc, char* argv[])
{
 char buf[1024];
 unsigned opc = 0;

 while(fgets(buf, sizeof(buf), stdin))
 {
  const size_t bsl = strlen(buf);
  size_t s = 0;

  for(size_t i = 0; i < bsl; i++)
  {
   if(buf[i] == '*' || buf[i] == '\n')
   {
    static const struct
    {
     const char* a;
     const char* b;
    } ttab[] =
    {
     { "i", "AM_IMP" },
     { "A", "AM_IMP" },
     { "s", "AM_IMP" },
     { "#1", "AM_IM_1" },
     { "#m", "AM_IM_M" },
     { "#x", "AM_IM_X" },
     { "a", "AM_AB" },
     { "al", "AM_ABL" },
     { "al,x", "AM_ABLX" },
     { "a,x", "AM_ABX" },
     { "a,y", "AM_ABY" },
     { "d", "AM_DP" },
     { "d,x", "AM_DPX" },
     { "d,y", "AM_DPY" },
     { "(d)", "AM_IND" },
     { "[d]", "AM_INDL" },
     { "(d,x)", "AM_IX" },
     { "(d),y", "AM_IY" },
     { "[d],y", "AM_ILY" },
     { "r,s", "AM_SR" },
     { "(r,s),y", "AM_SRIY" },
     { "r", "AM_R" },
     { "rl", "AM_RL" },
     { "xya", "AM_BLOCK" },
     { "(a)", "AM_ABIND" },
     { "(a,x)", "AM_ABIX" },
    };
    char mnemonic[256];
    char address_mode[256];
    const char* new_am = address_mode;

    buf[i] = 0;

    if(sscanf(buf + s, "%255s %255s", mnemonic, address_mode) != 2)
     abort();

    for(size_t ti = 0; ti < sizeof(ttab) / sizeof(ttab[0]); ti++)
    {
     if(!strcmp(address_mode, ttab[ti].a))
     {
      new_am = ttab[ti].b;
      break;
     }
    }

    printf(" /* 0x%02x */ { \"%s\", %s },\n", opc, mnemonic, new_am);

    s = i + 1;
    opc++;
   }
  }
 }
}
