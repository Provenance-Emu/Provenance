/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/farptr.h>
#include <pc.h>
#include <dos.h>
#include <dpmi.h>
#include <go32.h>
#include <ctype.h>

#include "dos.h"
#include "dos-sound.h"
#include "dos-joystick.h"


static void SBIRQHandler(_go32_dpmi_registers *r);
static uint32 LMBuffer;         /* Address of low memory DMA playback buffer. */
static int LMSelector;

static uint8 *WaveBuffer;
static unsigned int IVector, SBIRQ, SBDMA, SBDMA16, SBPort;
static int DSPV,hsmode;
static int format;
static int frags, fragsize, fragtotal;
static volatile int WritePtr, ReadPtr;
static volatile int hbusy;
static volatile int whichbuf;


static uint8 PICMask;
/* Protected mode interrupt vector info. */
static _go32_dpmi_seginfo SBIH,SBIHOld;

/* Real mode interrupt vector info. */
static _go32_dpmi_seginfo SBIHRM,SBIHRMOld;
static _go32_dpmi_registers SBIHRMRegs;

static int WriteDSP(uint8 V)
{
 int x;

 for(x=65536;x;x--)
 {
  if(!(inportb(SBPort+0xC)&0x80))
  {
   outportb(SBPort+0xC,V);
   return(1);
  }
 }
 return(0);
}

static int ReadDSP(uint8 *V)
{
 int x;

 for(x=65536;x;x--)             /* Should be more than enough time... */
 {
  if(inportb(SBPort+0xE)&0x80)
  {
   *V=inportb(SBPort+0xA);
   return(1);
  }
 }
 return(0);
}


static int SetVectors(void)
{
 SBIH.pm_offset=SBIHRM.pm_offset=(int)SBIRQHandler;
 SBIH.pm_selector=SBIHRM.pm_selector=_my_cs();

 /* Get and set real mode interrupt vector.  */
 _go32_dpmi_get_real_mode_interrupt_vector(IVector,&SBIHRMOld);
 _go32_dpmi_allocate_real_mode_callback_iret(&SBIHRM, &SBIHRMRegs);
 _go32_dpmi_set_real_mode_interrupt_vector(IVector,&SBIHRM);  

 /* Get and set protected mode interrupt vector. */
 _go32_dpmi_get_protected_mode_interrupt_vector(IVector,&SBIHOld);
 _go32_dpmi_allocate_iret_wrapper(&SBIH);
 _go32_dpmi_set_protected_mode_interrupt_vector(IVector,&SBIH); 

 return(1);
}

static void ResetVectors(void)
{
 _go32_dpmi_set_protected_mode_interrupt_vector(IVector,&SBIHOld);
 _go32_dpmi_free_iret_wrapper(&SBIH);
 _go32_dpmi_set_real_mode_interrupt_vector(IVector,&SBIHRMOld);
 _go32_dpmi_free_real_mode_callback(&SBIHRM);
}

int GetBLASTER(void)
{
 int check=0;
 char *s;

 if(!(s=getenv("BLASTER")))
 {
  puts(" Error getting BLASTER environment variable.");
  return(0);
 }

 while(*s)
 {
  switch(toupper(*s))
  {
   case 'A': check|=(sscanf(s+1,"%x",&SBPort)==1)?1:0;break;
   case 'I': check|=(sscanf(s+1,"%d",&SBIRQ)==1)?2:0;break;
   case 'D': check|=(sscanf(s+1,"%d",&SBDMA)==1)?4:0;break;
   case 'H': check|=(sscanf(s+1,"%d",&SBDMA16)==1)?8:0;break;
  }
  s++;
 }
 
 if((check^7)&7 || SBDMA>=4 || (SBDMA16<=4 && check&8) || SBIRQ>15)
 {
  puts(" Invalid or incomplete BLASTER environment variable.");
  return(0);
 }
 if(!(check&8))
  format=0;
 return(1);
}

static int ResetDSP(void)
{
 uint8 b;

 outportb(SBPort+0x6,0x1);
 delay(10);
 outportb(SBPort+0x6,0x0);
 delay(10);

 if(ReadDSP(&b))
  if(b==0xAA)
   return(1); 
 return(0);
}

static int GetDSPVersion(void)
{
 int ret;
 uint8 t;

 if(!WriteDSP(0xE1))
  return(0);
 if(!ReadDSP(&t))
  return(0);
 ret=t<<8;
 if(!ReadDSP(&t))
  return(0);
 ret|=t;

 return(ret);
}

static void KillDMABuffer(void)
{
 __dpmi_free_dos_memory(LMSelector);
}

static int MakeDMABuffer(void)
{
 uint32 size;
 int32 tmp;

 size=fragsize*2;       /* Two buffers in the DMA buffer. */
 size<<=format;         /* Twice the size for 16-bit than for 8-bit. */

 size<<=1;              /* Double the size in case the first 2 buffers
                           cross a 64KB or 128KB page boundary.
                        */
 size=(size+15)>>4;     /* Convert to paragraphs */

 if((tmp=__dpmi_allocate_dos_memory(size,&LMSelector))<0)
  return(0);

 LMBuffer=tmp<<=4;

 if(format)   /* Check for and fix 128KB page boundary crossing. */
 {
  if((LMBuffer&0x20000) != ((LMBuffer+fragsize*2*2-1)&0x20000))
   LMBuffer+=fragsize*2*2;
 }
 else   /* Check for and fix 64KB page boundary crossing. */
 {
  if((LMBuffer&0x10000) != ((LMBuffer+fragsize*2-1)&0x10000))
   LMBuffer+=fragsize*2;
 }

 DOSMemSet(LMBuffer, format?0:128, (fragsize*2)<<format);

 return(1);
}

static void ProgramDMA(void)
{
 static int PPorts[8]={0x87,0x83,0x81,0x82,0,0x8b,0x89,0x8a};
 uint32 tmp;

 if(format)
 {
  outportb(0xd4,(SBDMA16&0x3)|0x4);
  outportb(0xd8,0x0);
  outportb(0xd6,(SBDMA16&0x3)|0x58);
  tmp=((SBDMA16&3)<<2)+0xC2;
 }
 else
 {
  outportb(0xA,SBDMA|0x4);
  outportb(0xC,0x0);
  outportb(0xB,SBDMA|0x58);
  tmp=(SBDMA<<1)+1;
 }

 /* Size of entire buffer. */
 outportb(tmp,(fragsize*2-1));
 outportb(tmp,(fragsize*2-1)>>8);

 /* Page of buffer. */
 outportb(PPorts[format?SBDMA16:SBDMA],LMBuffer>>16);

 /* Offset of buffer within page. */
 if(format)
  tmp=((SBDMA16&3)<<2)+0xc0;
 else
  tmp=SBDMA<<1;

 outportb(tmp,(LMBuffer>>format));
 outportb(tmp,(LMBuffer>>(8+format)));
}

int InitSB(int Rate, int bittage)
{
 hsmode=hbusy=0;
 whichbuf=1;
 puts("Initializing Sound Blaster...");

 format=bittage?1:0;
 frags=8;

 if(Rate<=11025)
  fragsize=1<<5;
 else if(Rate<=22050)
  fragsize=1<<6;
 else
  fragsize=1<<7;

 fragtotal=frags*fragsize;
 WaveBuffer=malloc(fragtotal<<format);

 if(format)
  memset(WaveBuffer,0,fragtotal*2);
 else
  memset(WaveBuffer,128,fragtotal);

 WritePtr=ReadPtr=0;

 if((Rate<8192) || (Rate>65535))
 {
  printf(" Unsupported playback rate: %d samples per second\n",Rate);
  return(0);
 }

 if(!GetBLASTER())
  return(0);
 
 /* Disable IRQ line in PIC0 or PIC1 */
 if(SBIRQ>7)
 {
  PICMask=inportb(0xA1);
  outportb(0xA1,PICMask|(1<<(SBIRQ&7)));
 }
 else
 {
  PICMask=inportb(0x21);
  outportb(0x21,PICMask|(1<<SBIRQ));
 }
 if(!ResetDSP())
 {
  puts(" Error resetting the DSP.");
  return(0);
 }
 
 if(!(DSPV=GetDSPVersion()))
 {
  puts(" Error getting the DSP version.");
  return(0);
 }

 printf(" DSP Version: %d.%d\n",DSPV>>8,DSPV&0xFF);
 if(DSPV<0x201)
 {
  printf(" DSP version number is too low.\n");
  return(0);
 }

 if(DSPV<0x400)
  format=0;
 if(!MakeDMABuffer())
 {
  puts(" Error creating low-memory DMA buffer.");
  return(0);
 }

 if(SBIRQ>7) IVector=SBIRQ+0x68;
 else IVector=SBIRQ+0x8;

 if(!SetVectors())
 {
  puts(" Error setting interrupt vectors.");
  KillDMABuffer();
  return(0);
 }

 /* Reenable IRQ line. */
 if(SBIRQ>7)
  outportb(0xA1,PICMask&(~(1<<(SBIRQ&7))));
 else
  outportb(0x21,PICMask&(~(1<<SBIRQ)));

 ProgramDMA();

 /* Note that the speaker must always be turned on before the mode transfer
    byte is sent to the DSP if we're going into high-speed mode, since
    a real Sound Blaster(at least my SBPro) won't accept DSP commands(except
    for the reset "command") after it goes into high-speed mode.
 */
 WriteDSP(0xD1);                 // Turn on DAC speaker

 if(DSPV>=0x400)
 {
  WriteDSP(0x41);                // Set sampling rate
  WriteDSP(Rate>>8);             // High byte
  WriteDSP(Rate&0xFF);           // Low byte
  if(!format)
  {
   WriteDSP(0xC6);                // 8-bit output
   WriteDSP(0x00);                // 8-bit mono unsigned PCM
  }
  else
  {
   WriteDSP(0xB6);                // 16-bit output
   WriteDSP(0x10);                // 16-bit mono signed PCM
  }
  WriteDSP((fragsize-1)&0xFF);// Low byte of size
  WriteDSP((fragsize-1)>>8);  // High byte of size
 }
 else
 {
  int tc,command;
  if(Rate>22050)
  {
   tc=(65536-(256000000/Rate))>>8;
   Rate=256000000/(65536-(tc<<8));
   command=0x90;                  // High-speed auto-initialize DMA mode transfer
   hsmode=1;
  }
  else
  {
   tc=256-(1000000/Rate);
   Rate=1000000/(256-tc);
   command=0x1c;                  // Auto-initialize DMA mode transfer
  }
  WriteDSP(0x40);       // Set DSP time constant
  WriteDSP(tc);         // time constant
  WriteDSP(0x48);       // Set DSP block transfer size
  WriteDSP((fragsize-1)&0xFF);
  WriteDSP((fragsize-1)>>8);

  WriteDSP(command);
 }

 /* Enable DMA */
 if(format)
  outportb(0xd4,SBDMA16&3);
 else
  outportb(0xa,SBDMA);

 printf(" %d hz, %d-bit\n",Rate,8<<format);
 return(Rate);
}

extern volatile int soundjoyer;
extern volatile int soundjoyeron;
static int ssilence=0;

static void SBIRQHandler(_go32_dpmi_registers *r)
{
        uint32 *src;
	uint32 dest;
	int32 x;


        if(format)
        {
         uint8 status;

         outportb(SBPort+4,0x82);
         status=inportb(SBPort+5);
         if(status&2)
          inportb(SBPort+0x0F);
        }
        else
         inportb(SBPort+0x0E);

        #ifdef OLD
        {
         uint8 status;

         outportb(SBPort+4,0x82);
         status=inportb(SBPort+5);
         if(status&1)
          inportb(SBPort+0x0E);
         else if(status&2)
          inportb(SBPort+0x0F);
         else
          return;               // Mysterious interrupt source!  *eerie music*
        }         
        #endif

        if(hbusy)
        {
         outportb(0x20,0x20);
         if(SBIRQ>=8)
          outportb(0xA0,0x20);
         whichbuf^=1;         
         return;
        }
        hbusy=1;

        {
         /* This code seems to fail on many SB emulators.  Bah.
            SCREW SB EMULATORS. ^_^ */
         uint32 count;
	 uint32 block;
	 uint32 port;
       
         if(format)
          port=((SBDMA16&3)*4)+0xc2;
         else
          port=(SBDMA*2)+1;

         count=inportb(port);
         count|=inportb(port)<<8;

         if(count>=fragsize)
          block=1;
         else
          block=0;
         dest=LMBuffer+((block*fragsize)<<format);

         #ifdef MOO
         dest=LMBuffer+((whichbuf*fragsize)<<format);
         whichbuf^=1;
         #endif
        }

        _farsetsel(_dos_ds);

        src=(uint32 *)(WaveBuffer+(ReadPtr<<format));

	if(ssilence)
	{
	 uint32 sby;
	 if(format) sby=0;	/* 16-bit silence.  */
	 else sby=0x80808080;	/* 8-bit silence.   */

         for(x=(fragsize<<format)>>2;x;x--,dest+=4)
         {
          _farnspokel(dest,sby);
         }
	}
	else
	{
         for(x=(fragsize<<format)>>2;x;x--,dest+=4,src++)
         {
          _farnspokel(dest,*src);
         }
         ReadPtr=(ReadPtr+fragsize)&(fragtotal-1);
	}

        if(soundjoyeron)
        {
         static int coot=0;
         if(!coot)
         {
          UpdateJoyData();
          soundjoyer=1;
         }
         coot=(coot+1)&3;
        }
        hbusy=0;
        outportb(0x20,0x20);
        if(SBIRQ>=8)        
         outportb(0xA0,0x20);
}

void SilenceSound(int s)
{
 ssilence=s;
}

void WriteSBSound(int32 *Buffer, int Count, int NoBlocking)
{
 int x;

 if(!format)
 {
   for(x=0;x<Count;x++)
   {
    while(WritePtr==ReadPtr)
     if(NoBlocking)
      return;
    WaveBuffer[WritePtr]=(uint8)((Buffer[x])>>8)^128;
    WritePtr=(WritePtr+1)&(fragtotal-1);
   }
 }	
 else // 16 bit
 {
   for(x=0;x<Count;x++)
   {
    while(WritePtr==ReadPtr)
     if(NoBlocking)
      return;
    ((int16 *)WaveBuffer)[WritePtr]=Buffer[x];
    WritePtr=(WritePtr+1)&(fragtotal-1);
   }
 }
}

void KillSB(void)
{
 if(hsmode)
  ResetDSP();                   /* High-speed mode requires a DSP reset. */
 else
  WriteDSP(format?0xD9:0xDA);    /* Exit auto-init DMA transfer mode. */ 
 WriteDSP(0xD3);                /* Turn speaker off. */

 outportb((SBIRQ>7)?0xA1:0x21,PICMask|(1<<(SBIRQ&7)));
 ResetVectors();
 outportb((SBIRQ>7)?0xA1:0x21,PICMask);
 KillDMABuffer();
}
