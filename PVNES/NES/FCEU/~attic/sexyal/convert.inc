void SexiALI_Convert(SexyAL_format *srcformat, SexyAL_format *destformat, void *vdest, void *vsrc, uint32_t frames)
{
if(srcformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp2+=128;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp2+=128;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp2+=128;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp2+=128;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp2+=128;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp2+=128;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp2+=128;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp2+=128;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 8;
 tmp2+=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=128;
 tmp <<= 16;
 tmp2+=128;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp2-=128;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp2-=128;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp2-=128;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp2-=128;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp2-=128;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp2-=128;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp2-=128;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp2-=128;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 8;
 tmp2-=128;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=128;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=128;
 tmp <<= 16;
 tmp2-=128;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 16;
 tmp2 <<= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp2+=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp2+=32768;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp2+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp2+=32768;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp+=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp >>= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp2-=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp2-=32768;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp2-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp2-=32768;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 0;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp-=32768;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP16(tmp);
 tmp <<= 8;
FLIP16(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP16(tmp);
tmp2=*src;
 src++;
FLIP16(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP16(tmp);
FLIP16(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp >>= 8;
 tmp2+=32768;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 0;
 tmp2+=32768;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp2+=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp2+=32768;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp2+=32768;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp2+=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp2+=32768;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=32768;
 tmp <<= 8;
 tmp2+=32768;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp >>= 8;
 tmp2-=32768;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 0;
 tmp2-=32768;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 0;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 0;
 tmp2 <<= 0;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp2-=32768;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp2-=32768;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp2-=32768;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp2-=32768;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp2-=32768;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=32768;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=32768;
 tmp <<= 8;
 tmp2-=32768;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp <<= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp <<= 8;
 tmp2 <<= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 16;
 tmp2+=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp >>= 8;
 tmp2+=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp+=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp+=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp2+=(1<<23);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp2+=(1<<23);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp2+=(1<<23);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp2+=(1<<23);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp2+=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp+=(1<<23);
 tmp2+=(1<<23);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp2+=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp+=(1<<23);
 tmp2+=(1<<23);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
if(srcformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* src=vsrc;
if(destformat->sampformat == SEXYAL_FMT_PCMS8)
{
int8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 16;
 tmp2-=(1<<23);
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU8)
{
uint8_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 16;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 16;
 tmp2 >>= 16;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS16)
{
int16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU16)
{
uint16_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S16)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp >>= 8;
 tmp2-=(1<<23);
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U16)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp >>= 8;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp >>= 8;
 tmp2 >>= 8;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMS32S24)
{
int32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 tmp-=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 tmp-=(1<<23);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp2-=(1<<23);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp2-=(1<<23);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp2-=(1<<23);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp2-=(1<<23);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp2-=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 tmp-=(1<<23);
 tmp2-=(1<<23);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp2-=(1<<23);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 tmp-=(1<<23);
 tmp2-=(1<<23);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
if(destformat->sampformat == SEXYAL_FMT_PCMU32U24)
{
uint32_t* dest=vdest;
if(srcformat->channels == 1)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
tmp=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp);
 *dest=tmp;
 dest++;
 *dest=tmp;
 dest++;
}
}
}
}
}
if(srcformat->channels == 2)
{
if(destformat->channels == 1)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
tmp = (tmp+tmp2)>>1;
 *dest=tmp;
 dest++;
}
}
}
}
if(destformat->channels == 2)
{
if(srcformat->byteorder == 0)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
tmp2=*src;
 src++;
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
if(srcformat->byteorder == 1)
{
if(destformat->byteorder == 0)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
if(destformat->byteorder == 1)
{
while(frames--)
{
int32_t tmp;
int32_t tmp2;
tmp=*src;
 src++;
FLIP32(tmp);
tmp2=*src;
 src++;
FLIP32(tmp2);
FLIP32(tmp);
FLIP32(tmp2);
 *dest=tmp;
 dest++;
 *dest=tmp2;
 dest++;
}
}
}
}
}
}
}
}
