#include "smallc.h"

void sal_memcpy(void *dest, const void *src, uint32_t n)
{
 while(n--)
 {
  *(uint8_t*)dest=*(uint8_t *)src;
  (uint8_t*)dest++;
  (uint8_t*)src++;
 }
}

uint32_t sal_strlen(const char *buf)
{
 uint32_t size=0;

 while(*buf++) size++;

 return(size);
}

void sal_strcpy(char *dest, const char *src)
{
 while(*src)
  *dest++ = *src++;
 *dest=0;
}

void sal_strcat(char *dest, const char *src)
{
 while(*dest)
  dest++;
 while(*src)
  *dest++ = *src++;
 *dest=0;
}

const char *sal_uinttos(int value)
{
 static char buf[64],buf2[64];
 char *tmp;
 int len=0;

 tmp=buf;

 while(value)
 {
  *tmp='0'+(value%10);
  len++;
  tmp++;
  value/=10;
 }

 tmp=buf2;
 while(len-- >= 0)
 {
  *tmp=buf[len];
  tmp++;
 }

 *tmp=0;
 return(buf2);
}
