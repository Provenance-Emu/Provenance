#include <stdio.h>

enum { N_FLAG = 0x80 };
enum { V_FLAG = 0x40 };
enum { T_FLAG = 0x20 };
enum { B_FLAG = 0x10 };
enum { D_FLAG = 0x08 };
enum { I_FLAG = 0x04 };
enum { Z_FLAG = 0x02 };
enum { C_FLAG = 0x01 };

typedef unsigned char uint8;
typedef unsigned int uint32;

static void GenADC(void)
{
 uint8 ftab[4] = { 0x00, 0x01, 0xC2, 0xC3 };
 FILE* fp = fopen("adcresults.bin", "wb");

 for(int FI = 0; FI < 4; FI++)
 {
  for(int arg = 0x00; arg < 0x100; arg++)
  {
   for(int A = 0x00; A < 0x100; A++)
   {
    uint8 P = ftab[FI] | I_FLAG | D_FLAG | B_FLAG;
    uint8 Aout;
    uint32 tmp;

    tmp = (A & 0x0F) + (arg & 0x0F) + (P & 1);
    if(tmp >= 0x0A)
     tmp += 0x06;

    tmp += (A & 0xF0) + (arg & 0xF0);
    if(tmp >= 0xA0)
     tmp += 0x60;

    P &= ~(Z_FLAG | N_FLAG | C_FLAG);

    if(tmp & 0xFF00)
     P |= C_FLAG;

    Aout = tmp;

    if(Aout & 0x80)
     P |= N_FLAG;

    if(!Aout)
     P |= Z_FLAG;

    if(Aout & 0x80)
     P |= N_FLAG;

    fseek(fp, (FI << 17) + ((arg & 0xF0) << 9) + ((arg & 0x0F) << 8) + A + 0x0000, SEEK_SET);
    fwrite(&Aout, 1, 1, fp);

    fseek(fp, (FI << 17) + ((arg & 0xF0) << 9) + ((arg & 0x0F) << 8) + A + 0x1000, SEEK_SET);
    fwrite(&P, 1, 1, fp);
   }
  }
 }

 fclose(fp);
}

static void GenSBC(void)
{
 uint8 ftab[4] = { 0x00, 0x01, 0xC2, 0xC3 };
 FILE* fp = fopen("sbcresults.bin", "wb");

 for(int FI = 0; FI < 4; FI++)
 {
  for(int arg = 0x00; arg < 0x100; arg++)
  {
   for(int A = 0x00; A < 0x100; A++)
   {
    uint8 P = ftab[FI] | I_FLAG | D_FLAG | B_FLAG;
    uint8 Aout;

    uint8 res = A - arg - ((P & 1) ^ 1);
    const uint8 m = (A & 0xF) - (arg & 0xF) - ((P & 1) ^ 1);
    const uint8 n = (A >> 4) - (arg >> 4) - ((m >> 4) & 1);

    P &= ~(Z_FLAG | N_FLAG | C_FLAG);

    if(m & 0x10)
     res -= 0x06;

    if(n & 0x10)
     res -= 0x60;

    Aout = res;
    P |= ((n >> 4) & 0x1) ^ 1;

    if(!Aout)
     P |= Z_FLAG;

    if(Aout & 0x80)
     P |= N_FLAG;

    //if(A == 0x00 && arg == 0x0A && FI == 0)
    // printf("00 0A 00: %02x %02x\n", Aout, P);

    //if(A == 0x0F && arg == 0x0A && FI == 0)
    // printf("00 0A 00: %02x %02x\n", Aout, P);

    //if(A == 0x10 && arg == 0x0A && FI == 0)
    // printf("00 0A 10: %02x %02x\n", Aout, P);

    fseek(fp, (FI << 17) + ((arg & 0xF0) << 9) + ((arg & 0x0F) << 8) + A + 0x0000, SEEK_SET);
    fwrite(&Aout, 1, 1, fp);

    fseek(fp, (FI << 17) + ((arg & 0xF0) << 9) + ((arg & 0x0F) << 8) + A + 0x1000, SEEK_SET);
    fwrite(&P, 1, 1, fp);
   }
  }
 }

 fclose(fp);
}

int main(int argc, char* argv[])
{
 GenADC();
 GenSBC();
 return 0;
}
