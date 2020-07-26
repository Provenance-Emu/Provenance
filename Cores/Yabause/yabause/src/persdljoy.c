/*  Copyright 2005 Guillaume Duhamel
	Copyright 2005-2006 Theo Berkau
	Copyright 2008 Filipe Azevedo

	This file is part of Yabause.

	Yabause is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	Yabause is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Yabause; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*! \file persdljoy.c
    \brief SDL joystick peripheral interface.
*/

#ifdef HAVE_LIBSDL
#if defined(__APPLE__) || defined(GEKKO)
 #ifdef HAVE_LIBSDL2
  #include <SDL2/SDL.h>
 #else
  #include <SDL/SDL.h>
 #endif
#else
 #include "SDL.h"
#endif

#include "debug.h"
#include "persdljoy.h"

#define SDL_MAX_AXIS_VALUE 0x110000
#define SDL_MIN_AXIS_VALUE 0x100000
#define SDL_HAT_VALUE 0x200000
#define SDL_MEDIUM_AXIS_VALUE (int)(32768 / 2)
#define SDL_BUTTON_PRESSED 1
#define SDL_BUTTON_RELEASED 0

int PERSDLJoyInit(void);
void PERSDLJoyDeInit(void);
int PERSDLJoyHandleEvents(void);

u32 PERSDLJoyScan(u32 flags);
void PERSDLJoyFlush(void);
void PERSDLKeyName(u32 key, char * name, int size);

PerInterface_struct PERSDLJoy = {
PERCORE_SDLJOY,
"SDL Joystick Interface",
PERSDLJoyInit,
PERSDLJoyDeInit,
PERSDLJoyHandleEvents,
PERSDLJoyScan,
1,
PERSDLJoyFlush,
PERSDLKeyName
};

typedef struct {
	SDL_Joystick* mJoystick;
	s16* mScanStatus;
	Uint8* mHatStatus;
} PERSDLJoystick;

unsigned int SDL_PERCORE_INITIALIZED = 0;
unsigned int SDL_PERCORE_JOYSTICKS_INITIALIZED = 0;
PERSDLJoystick* SDL_PERCORE_JOYSTICKS = 0;
unsigned int SDL_HAT_VALUES[] = { SDL_HAT_UP, SDL_HAT_RIGHT, SDL_HAT_LEFT, SDL_HAT_DOWN };
const unsigned int SDL_HAT_VALUES_NUM = sizeof(SDL_HAT_VALUES) / sizeof(SDL_HAT_VALUES[0]);

//////////////////////////////////////////////////////////////////////////////

int PERSDLJoyInit(void) {
	int i, j;

	// does not need init if already done
	if ( SDL_PERCORE_INITIALIZED )
	{
		return 0;
	}

#if defined (_MSC_VER) && SDL_VERSION_ATLEAST(2,0,0)
   SDL_SetMainReady();
#endif

	// init joysticks
	if ( SDL_InitSubSystem( SDL_INIT_JOYSTICK ) == -1 )
	{
		return -1;
	}
	
	// ignore joysticks event in sdl event loop
	SDL_JoystickEventState( SDL_IGNORE );
	
	// open joysticks
	SDL_PERCORE_JOYSTICKS_INITIALIZED = SDL_NumJoysticks();
	SDL_PERCORE_JOYSTICKS = malloc(sizeof(PERSDLJoystick) * SDL_PERCORE_JOYSTICKS_INITIALIZED);
	for ( i = 0; i < SDL_PERCORE_JOYSTICKS_INITIALIZED; i++ )
	{
		SDL_Joystick* joy = SDL_JoystickOpen( i );
		
		SDL_JoystickUpdate();
		
		SDL_PERCORE_JOYSTICKS[ i ].mJoystick = joy;
		SDL_PERCORE_JOYSTICKS[ i ].mScanStatus = joy ? malloc(sizeof(s16) * SDL_JoystickNumAxes( joy )) : 0;
		SDL_PERCORE_JOYSTICKS[ i ].mHatStatus = joy ? malloc(sizeof(Uint8) * SDL_JoystickNumHats( joy )) : 0;
		
		if ( joy )
		{
			for ( j = 0; j < SDL_JoystickNumAxes( joy ); j++ )
			{
				SDL_PERCORE_JOYSTICKS[ i ].mScanStatus[ j ] = SDL_JoystickGetAxis( joy, j );
			}
			for ( j = 0; j < SDL_JoystickNumHats( joy ); j++ )
			{
				SDL_PERCORE_JOYSTICKS[ i ].mHatStatus[ j ] = SDL_JoystickGetHat( joy, j );
			}
		}
	}
	
	// success
	SDL_PERCORE_INITIALIZED = 1;
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

void PERSDLJoyDeInit(void) {
	// close joysticks
	if ( SDL_PERCORE_INITIALIZED == 1 )
	{
		int i;
		for ( i = 0; i < SDL_PERCORE_JOYSTICKS_INITIALIZED; i++ )
		{
#if SDL_VERSION_ATLEAST(2,0,0)
         if ( SDL_PERCORE_JOYSTICKS[ i ].mJoystick )
#else
			if ( SDL_JoystickOpened( i ) )
#endif
         {
            SDL_JoystickClose( SDL_PERCORE_JOYSTICKS[ i ].mJoystick );

            free( SDL_PERCORE_JOYSTICKS[ i ].mScanStatus );
            free( SDL_PERCORE_JOYSTICKS[ i ].mHatStatus );
         }
		}
		free( SDL_PERCORE_JOYSTICKS );
	}
	
	SDL_PERCORE_JOYSTICKS_INITIALIZED = 0;
	SDL_PERCORE_INITIALIZED = 0;
	
	// close sdl joysticks
	SDL_QuitSubSystem( SDL_INIT_JOYSTICK );
}

//////////////////////////////////////////////////////////////////////////////

int PERSDLJoyHandleEvents(void) {
	int joyId;
	int i;
	int j;
	SDL_Joystick* joy;
	Sint16 cur;
	Uint8 buttonState;
	Uint8 newHatState;
	Uint8 oldHatState;
	int hatValue;
	
	// update joysticks states
	SDL_JoystickUpdate();
	
	// check each joysticks
	for ( joyId = 0; joyId < SDL_PERCORE_JOYSTICKS_INITIALIZED; joyId++ )
	{
		joy = SDL_PERCORE_JOYSTICKS[ joyId ].mJoystick;
		
		if ( !joy )
		{
			continue;
		}
		
		// check axis
		for ( i = 0; i < SDL_JoystickNumAxes( joy ); i++ )
		{
			cur = SDL_JoystickGetAxis( joy, i );

			PerAxisValue((joyId << 18) | SDL_MEDIUM_AXIS_VALUE | i, (u8)(((int)cur+32768) >> 8));
			
			if ( cur < -SDL_MEDIUM_AXIS_VALUE )
			{
				PerKeyUp( (joyId << 18) | SDL_MAX_AXIS_VALUE | i );
				PerKeyDown( (joyId << 18) | SDL_MIN_AXIS_VALUE | i );
			}
			else if ( cur > SDL_MEDIUM_AXIS_VALUE )
			{
				PerKeyUp( (joyId << 18) | SDL_MIN_AXIS_VALUE | i );
				PerKeyDown( (joyId << 18) | SDL_MAX_AXIS_VALUE | i );
			}
			else
			{
				PerKeyUp( (joyId << 18) | SDL_MIN_AXIS_VALUE | i );
				PerKeyUp( (joyId << 18) | SDL_MAX_AXIS_VALUE | i );
			}
		}
		
		// check buttons
		for ( i = 0; i < SDL_JoystickNumButtons( joy ); i++ )
		{
			buttonState = SDL_JoystickGetButton( joy, i );
			
			if ( buttonState == SDL_BUTTON_PRESSED )
			{
				PerKeyDown( (joyId << 18) | (i +1) );
			}
			else if ( buttonState == SDL_BUTTON_RELEASED )
			{
				PerKeyUp( (joyId << 18) | (i +1) );
			}
		}

		// check hats
		for ( i = 0; i < SDL_JoystickNumHats( joy ); i++ )
		{
			newHatState = SDL_JoystickGetHat( joy, i );
			oldHatState = SDL_PERCORE_JOYSTICKS[ joyId ].mHatStatus[ i ];

			for ( j = 0 ; j < SDL_HAT_VALUES_NUM; j++ )
			{
				hatValue = SDL_HAT_VALUES[ j ];
				if ( oldHatState & hatValue && ~newHatState & hatValue )
				{
					PerKeyUp( (joyId << 18) | SDL_HAT_VALUE | (hatValue << 4) | i );
				}
			}
			for ( j = 0 ; j < SDL_HAT_VALUES_NUM; j++ )
			{
				hatValue = SDL_HAT_VALUES[ j ];
				if ( ~oldHatState & hatValue && newHatState & hatValue )
				{
					PerKeyDown( (joyId << 18) | SDL_HAT_VALUE | (hatValue << 4) | i);
				}
			}

			SDL_PERCORE_JOYSTICKS[ joyId ].mHatStatus[ i ] = newHatState;
		}
	}
	
	// execute yabause
	if ( YabauseExec() != 0 )
	{
		return -1;
	}
	
	// return success
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

u32 PERSDLJoyScan( u32 flags ) {
	// init vars
	int joyId;
	int i;
	SDL_Joystick* joy;
	Sint16 cur;
	Uint8 hatState;
	
	// update joysticks states
	SDL_JoystickUpdate();
	
	// check each joysticks
	for ( joyId = 0; joyId < SDL_PERCORE_JOYSTICKS_INITIALIZED; joyId++ )
	{
		joy = SDL_PERCORE_JOYSTICKS[ joyId ].mJoystick;
		
		if ( !joy )
		{
			continue;
		}
	
		// check axis
		for ( i = 0; i < SDL_JoystickNumAxes( joy ); i++ )
		{
			cur = SDL_JoystickGetAxis( joy, i );

			if ( cur != SDL_PERCORE_JOYSTICKS[ joyId ].mScanStatus[ i ] )
			{
				if ( cur < -SDL_MEDIUM_AXIS_VALUE )
				{
					if (flags & PERSF_AXIS)
						return (joyId << 18) | SDL_MEDIUM_AXIS_VALUE | i;
					if (flags & PERSF_HAT)
						return (joyId << 18) | SDL_MIN_AXIS_VALUE | i;
				}
				else if ( cur > SDL_MEDIUM_AXIS_VALUE )
				{
					if (flags & PERSF_AXIS)
						return (joyId << 18) | SDL_MEDIUM_AXIS_VALUE | i;
					if (flags & PERSF_HAT)
						return (joyId << 18) | SDL_MAX_AXIS_VALUE | i;
				}
			}
		}

		if (flags & PERSF_BUTTON)
		{
			// check buttons
			for ( i = 0; i < SDL_JoystickNumButtons( joy ); i++ )
			{
				if ( SDL_JoystickGetButton( joy, i ) == SDL_BUTTON_PRESSED )
				{
					return (joyId << 18) | (i +1);
					break;
				}
			}
		}

		if (flags & PERSF_HAT)
		{
			// check hats
			for ( i = 0; i < SDL_JoystickNumHats( joy ); i++ )
			{
				hatState = SDL_JoystickGetHat( joy, i );
				switch (hatState)
				{
					case SDL_HAT_UP:
					case SDL_HAT_RIGHT:
					case SDL_HAT_DOWN:
					case SDL_HAT_LEFT:
						return (joyId << 18) | SDL_HAT_VALUE | (hatState << 4) | i;
						break;
					default:
						break;
				}
			}
		}
	}

	return 0;
}

void PERSDLJoyFlush(void) {
}

void PERSDLKeyName(u32 key, char * name, UNUSED int size)
{
	sprintf(name, "%x", (int)key);
}

#endif
