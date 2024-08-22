#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

int main(int argc, char* argv[])
{
 uint64_t r = 0; //~(uint64_t)0;
 FILE* ofp[8];
 uint64_t table[256];

 for(unsigned i = 0; i < 8; i++)
 {
  char fn[64];
  snprintf(fn, sizeof(fn), "crctab-%u.bin", i);
  ofp[i] = fopen(fn, "wb");
 }

 for(unsigned i = 0; i < 256; i++)
 {
  r = (uint64_t)(i) << 56;
  for(unsigned b = 8; b; b--)
   r = (r << 1) ^ (((int64_t)r >> 63) & 0x42F0E1EBA9EA3693ULL);

  printf("0x%016llx,\n", (unsigned long long)r);
  table[i] = r;
  for(unsigned j = 0; j < 8; j++)
  {
   fputc((uint8_t)r, ofp[j]);
   r >>= 8;
  }
 }

 for(unsigned i = 0; i < 8; i++)
 {
  fclose(ofp[i]);
 }

 uint64_t crc64 = ~(uint64_t)0;

 crc64 = (crc64 << 8) ^ table[(crc64 >> 56) ^ 0xAA];

 printf("0x%016llx\n", (unsigned long long)~crc64);

 return 0;
}
