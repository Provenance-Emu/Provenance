#include <stdio.h>


int main(int argc, char* argv[])
{
// printf("static_assert(__COUNTER__ <= 11025, \"Unexpected __COUNTER__\");\n");
 const unsigned base = 2*5000; //10000;
 const unsigned max_entries = 512; //512;
 for(int i = max_entries; i > 0; i--)
 {
  printf("#if __COUNTER__ >= %u\n", base + max_entries + 2);
  printf(" &&Resume_%u,\n", base + i);
  printf("#endif\n");
 }
}
