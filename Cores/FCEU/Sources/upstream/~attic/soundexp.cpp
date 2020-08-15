#include <stdio.h>

#include <vorbis/vorbisfile.h>

#include "types.h"
#include "fceu.h"

static OggVorbis_File cursong;

void InstallSoundExp(void)
{
 FILE *fp=fopen("test.ogg","rb");

 ov_open(fp,&cursong,NULL,0);
 FCEUGameInfo->soundrate=44100;
 FCEUGameInfo->soundchan=2;
}

int cur=0;

void UpdateSoundExp(int32 *buf, int32 len)
{
 int16 boo[8192];
 int32 offset=0;
 int x;
 int32 tlen=len;

 while(len)
 {
  int32 t=ov_read(&cursong,(char *)boo+offset*4,len*4,0,2,1,&cur)/4;
  len-=t;
  offset+=t;
 }

// printf("%d\n",inboo);
 for(x=0;x<tlen*2;x++) 
 {
  buf[x]=boo[x];
  //buf[x]=(x&4)*4096; //(x&3)?0x3FFF:0;
 }//buf[x]+=boo[x];
// inboo-=len;
}
