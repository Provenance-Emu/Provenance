/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *  Copyright (C) 2002 Paul Kuliniewicz
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

/* PK: SDL joystick input stuff */

#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#include "sdl.h"

#define MAX_JOYSTICKS	32
static SDL_Joystick *Joysticks[MAX_JOYSTICKS] = {NULL};

int DTestButtonJoy(ButtConfig *bc)
{
 int x;

 for(x=0;x<bc->NumC;x++)
 {
  if(bc->ButtonNum[x]&0x8000)	/* Axis "button" */
  {
	int pos;
        pos = SDL_JoystickGetAxis(Joysticks[bc->DeviceNum[x]], bc->ButtonNum[x]&16383);
        if ((bc->ButtonNum[x]&0x4000) && pos <= -16383)
	 return(1);
        else if (!(bc->ButtonNum[x]&0x4000) && pos >= 16363)
	 return(1);
  }
  else if(bc->ButtonNum[x]&0x2000)	/* Hat "button" */
  {
   if( SDL_JoystickGetHat(Joysticks[bc->DeviceNum[x]],(bc->ButtonNum[x]>>8)&0x1F) & (bc->ButtonNum[x]&0xFF))
    return(1);
  }
  else
   if(SDL_JoystickGetButton(Joysticks[bc->DeviceNum[x]], bc->ButtonNum[x] )) 
    return(1);
 }
 return(0);
}

static int jinited=0;

/* Cleanup opened joysticks. */
int KillJoysticks (void)
{
	int n;			/* joystick index */

	if(!jinited) return(0);
	for (n = 0; n < MAX_JOYSTICKS; n++)
	{
		if (Joysticks[n] != 0)
 	  	 SDL_JoystickClose(Joysticks[n]);
		Joysticks[n]=0;
	}
	SDL_QuitSubSystem(SDL_INIT_JOYSTICK);
	return(1);
}

/* Initialize joysticks. */
int InitJoysticks (void)
{
	int n;			/* joystick index */
	int total;

        SDL_InitSubSystem(SDL_INIT_JOYSTICK);
	total=SDL_NumJoysticks();
	if(total>MAX_JOYSTICKS) total=MAX_JOYSTICKS;

	for (n = 0; n < total; n++)
	{
 	 /* Open the joystick under SDL. */
	 Joysticks[n] = SDL_JoystickOpen(n);
	 //printf("Could not open joystick %d: %s.\n",
	 //joy[n] - 1, SDL_GetError());
 	 continue;
	}
	jinited=1;
	return(1);
}
