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
#include <time.h>
#include <unistd.h>

#include <dpmi.h>
#include <sys/farptr.h>
#include <go32.h>
#include <pc.h>

#include "dos.h"
#include "dos-joystick.h"

#define JOY_A   1
#define JOY_B   2
#define JOY_SELECT      4
#define JOY_START       8
#define JOY_UP  0x10
#define JOY_DOWN        0x20
#define JOY_LEFT        0x40
#define JOY_RIGHT       0x80

int joy=0;
int joyBMap[6];

static int32 joybuttons=0;
static uint32 joyx=0;
static uint32 joyy=0;
static uint32 joyxcenter;
static uint32 joyycenter;

static void ConfigJoystick(void);
volatile int soundjoyer=0;
volatile int soundjoyeron=0;

/* Crude method to detect joystick. */
static int DetectJoystick(void)
{
 uint8 b;

 outportb(0x201,0);
 b=inportb(0x201);
 sleep(1);
 if((inportb(0x201)&3)==(b&3))
  return 0;
 else
  return 1;
}

void UpdateJoyData(void)
{
 uint32 xc,yc;


 joybuttons=((inportb(0x201)&0xF0)^0xF0)>>4;

 xc=yc=0;

 {
  outportb(0x201,0);

  for(;;)
  {
   uint8 b;

   b=inportb(0x201);
   if(!(b&3))
    break;
   if(b&1) xc++;
   if(b&2) yc++;
  }
 }

 joyx=xc;
 joyy=yc;
}

uint32 GetJSOr(void)
{
        int y;
        unsigned long ret;
	static int rtoggle=0;
        ret=0;

	rtoggle^=1;
        if(!soundo)
         UpdateJoyData();
        for(y=0;y<6;y++)
	 if((y>=4 && rtoggle) || y<4)
          if(joybuttons&joyBMap[y]) ret|=(1<<y&3)<<((joy-1)<<3);

        if(joyx<=joyxcenter*.25) ret|=JOY_LEFT<<((joy-1)<<3);
        else if(joyx>=joyxcenter*1.75) ret|=JOY_RIGHT<<((joy-1)<<3);
        if(joyy<=joyycenter*.25) ret|=JOY_UP<<((joy-1)<<3);
        else if(joyy>=joyycenter*1.75) ret|=JOY_DOWN<<((joy-1)<<3);

        return ret;
}

int InitJoysticks(void)
{
	if(!joy) return(0);
        if(!DetectJoystick())
        {
         printf("Joystick not detected!\n");
         joy=0;
         return 0;
        }
        if(soundo)
        {
         soundjoyeron=1;
         while(!soundjoyer);
        }
        else
         UpdateJoyData();

        joyxcenter=joyx;
        joyycenter=joyy;

        if(!(joyBMap[0]|joyBMap[1]|joyBMap[2]|joyBMap[3]))
         ConfigJoystick();
        return(1);
}

static void BConfig(int b)
{
  int c=0;
  uint32 st=time(0);

  while(time(0)< (st+4) )
  {
   if(!soundo)
    UpdateJoyData();
   if(joybuttons) c=joybuttons;
   else if(c && !joybuttons)
   {
    joyBMap[b]=c;
    break;
   }

  }
}

void KillJoysticks(void)
{

}

static void ConfigJoystick(void)
{
 static char *genb="** Press button for ";

 printf("\n\n Joystick button configuration:\n\n");
 printf("   Push and release the button to map to the virtual joystick.\n");
 printf("   If you do not wish to assign a button, wait a few seconds\n");
 printf("   and the configuration will continue.\n\n");
 printf("   Press enter to continue...\n");
 getchar();
                                                        
 printf("%s\"Select\".\n",genb);
 BConfig(2);

 printf("%s\"Start\".\n",genb);
 BConfig(3);

 printf("%s\"B\".\n",genb);
 BConfig(1);

 printf("%s\"A\".\n",genb);
 BConfig(0);

 printf("%s\"Rapid fire B\".\n",genb);
 BConfig(5);
 
 printf("%s\"Rapid fire A\".\n",genb);
 BConfig(4);

}

