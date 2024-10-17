//
// g++ -Wall -O2 -o bintodsk bintodsk.cpp
//
#include <stdio.h>
#include <stddef.h>
#include <inttypes.h>
#include <string.h>

int main(int argc, char* argv[])
{
 if(argc != 3)
 {
  printf("Incorrect number of arguments.\n");
  return -1;
 }
 //
 FILE* ifp = fopen(argv[1], "rb");
 FILE* ofp = fopen(argv[2], "wb");
 uint8_t buf[256 * 16 * 35];
 size_t count;

 memset(buf, 0, sizeof(buf));

 if(!ifp)
 {
  printf("Error opening input file.\n");
  return -1;
 }

 if(!ofp)
 {
  printf("Error opening output file.\n");
  return -1;
 }

 clearerr(ifp);
 count = fread(buf, 1, sizeof(buf), ifp);

 if(ferror(ifp))
 {
  printf("Error reading input file.\n");
  return -1;
 }

 if(count > 256 * 16) // 4096 bytes, one track
 {
  printf("Input file is too large.\n");
  return -1;
 }

 int ret = 0;

 for(unsigned i = 0; i < 16 * 35; i++)
 {
  static const uint8_t tab[16] = { 0x00, 0x0d, 0x0b, 0x09, 0x07, 0x05, 0x03, 0x01, 0x0e, 0x0c, 0x0a, 0x08, 0x06, 0x04, 0x02, 0x0f };

  if(fwrite(&buf[((i - (i % 16)) + tab[i % 16]) * 256], 1, 256, ofp) != 256)
  { 
   printf("Error writing to output file.\n");
   ret = -1;
   break;
  }
 }

 if(fclose(ifp))
 {
  printf("Error closing input file.\n");
  ret = -1;
 }

 if(fclose(ofp))
 {
  printf("Error closing output file.\n");
  ret = -1;
 }

 return ret;
}
