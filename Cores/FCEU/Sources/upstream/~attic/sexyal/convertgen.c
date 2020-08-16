#include <stdio.h>

char *check[]={"SEXYAL_FMT_PCMS8","SEXYAL_FMT_PCMU8","SEXYAL_FMT_PCMS16",
"SEXYAL_FMT_PCMU16","SEXYAL_FMT_PCMS32S16","SEXYAL_FMT_PCMU32U16","SEXYAL_FMT_PCMS32S24","SEXYAL_FMT_PCMU32U24"};
char *str[]={"int8_t","uint8_t","int16_t","uint16_t","int32_t","uint32_t","int32_t","uint32_t"};

int bitss[]={8,8,16,16,16,16,24,24};
int bitsreal[]={8,8,16,16,32,32,32,32};

void Fetch(int x,char *wt)
{
 //printf(" int32_t tmp%s=*src;\n",wt);
 printf("tmp%s=*src;\n",wt);
 printf(" src++;\n");
}

void BitConv(int src, int dest, char *wt)
{
 if((src^dest)&1) /* signed/unsigned change. */
  if(src&1)	/* Source unsigned, dest signed. */
  {
   if(src==1) printf(" tmp%s-=128;\n",wt);
   else if(src==3) printf(" tmp%s-=32768;\n",wt);
   else if(src==5) printf(" tmp%s-=32768;\n",wt);
   else if(src==7) printf(" tmp%s-=(1<<23);\n",wt);
  }
  else		/* Source signed, dest unsigned */
  {
   if(src==0) printf(" tmp%s+=128;\n",wt);
   else if(src==2) printf(" tmp%s+=32768;\n",wt);
   else if(src==4) printf(" tmp%s+=32768;\n",wt);
   else if(src==6) printf(" tmp%s+=(1<<23);\n",wt);
  }
 if((src>>1) != (dest>>1))
 {
  int shifty=bitss[src]-bitss[dest];
  if(shifty>0)
   printf(" tmp%s >>= %d;\n",wt,shifty);
  else
   printf(" tmp%s <<= %d;\n",wt,-shifty);
 }
}

void Save(int x, char *wt)
{
 printf(" *dest=tmp%s;\n",wt);
 printf(" dest++;\n");
}

main()
{
 int srcbits,destbits,srcchannels,destchannels;
 int srcbo,destbo;

 puts("void SexiALI_Convert(SexyAL_format *srcformat, SexyAL_format *destformat, void *vdest, void *vsrc, uint32_t frames)");
 puts("{");

 for(srcbits=0;srcbits<8;srcbits++)
 {
  printf("if(srcformat->sampformat == %s)\n{\n",check[srcbits]);

  printf("%s* src=vsrc;\n",str[srcbits]);

  for(destbits=0;destbits<8;destbits++)
  {
   printf("if(destformat->sampformat == %s)\n{\n",check[destbits]);

   printf("%s* dest=vdest;\n",str[destbits]);

   for(srcchannels=0;srcchannels<2;srcchannels++)
   {
    printf("if(srcformat->channels == %c)\n{\n",'1'+srcchannels);
    for(destchannels=0;destchannels<2;destchannels++)
    {
     printf("if(destformat->channels == %c)\n{\n",'1'+destchannels);
     for(srcbo=0;srcbo<2;srcbo++)
     {
      printf("if(srcformat->byteorder == %d)\n{\n",srcbo);
      for(destbo=0;destbo<2;destbo++)
      {
       printf("if(destformat->byteorder == %d)\n{\n",destbo);
       //printf("if(srcformat->sampformat==%s && destformat->sameck[srcbits],check[destbits]);
       printf("while(frames--)\n{\n");

       puts("int32_t tmp;");
       if(srcchannels)
	puts("int32_t tmp2;");

       Fetch(srcbits,"");

       if(srcbo) 
       {
        if(bitsreal[srcbits]==16)
         puts("FLIP16(tmp);");
        else
         puts("FLIP32(tmp);");
       }

       if(srcchannels) 
       {
        Fetch(srcbits,"2");
        if(srcbo) 
        {
         if(bitsreal[srcbits]==16)
          puts("FLIP16(tmp2);");
         else
          puts("FLIP32(tmp2);");
        } 
       }

       BitConv(srcbits,destbits,"");

       if(srcchannels) BitConv(srcbits,destbits,"2");

       if(destbo)
       { 
        if(bitsreal[srcbits]==16)
         puts("FLIP16(tmp);");
        else
         puts("FLIP32(tmp);");
        if(srcchannels && destchannels && destbo)
        {
         if(bitsreal[srcbits]==16)
          puts("FLIP16(tmp2);");   
         else
          puts("FLIP32(tmp2);");
        }
       }

       if(srcchannels && !destchannels)
        printf("tmp = (tmp+tmp2)>>1;\n");

       Save(destbits,"");
       if(!srcchannels && destchannels)
        Save(destbits,"");

       if(srcchannels && destchannels)
        Save(destbits,"2");

       puts("}");
       puts("}");
      } // destbo
      puts("}");
     } // srcbo
     puts("}");
    }
    puts("}");
   }
   puts("}");
  }
  puts("}");
 }

 puts("}");
}
