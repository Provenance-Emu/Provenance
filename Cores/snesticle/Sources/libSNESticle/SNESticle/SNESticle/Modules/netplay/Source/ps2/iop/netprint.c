
/*
  _____     ___ ____
   ____|   |    ____|      PS2 OpenSource Project
  |     ___|   |____       (C)2002, David Ryan ( oobles@hotmail.com )
  ------------------------------------------------------------------------
  ps2debug.c               Thread safe printf.

  All rights reserved.

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, and/or sell copies of the
  Software, and to permit persons to whom the Software is furnished to do so,
  provided that the above copyright notice(s) and this permission notice appear
  in all copies of the Software and that both the above copyright notice(s)
  and this permission notice appear in supporting documentation.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF THIRD PARTY RIGHTS.
  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE BE
  LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES, OR
  ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
  IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
  OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

  Except as contained in this notice, the name of a copyright holder shall not
  be used in advertising or otherwise to promote the sale, use or other dealings
  in this Software without prior written authorization of the copyright holder.  
*/

#include <stdarg.h>

#include <loadcore.h>
#include <thsemap.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

int vsprintf (char *str, const char *format, va_list args);

static int initialised = 0;
static int mutex = 0;
static char buffer[2048];

void NetPrintInit()
{
  if ( initialised == 0 )
  {
     struct t_sema sema;

     sema.attr = 0;
     sema.option = 0;
     sema.init_count = 1;
     sema.max_count = 1;
     mutex = CreateSema( &sema );
     if ( mutex < 0 )
        printf( "PS2DEBUG: CreateSema failed %i\n", mutex );

     // initialise once on first call.
     initialised = 1;

  }
}



int NetPrintf( const char * fmt, ... )
{
  va_list ap;
  int mret;
  char buf[256];
  int ret = 0;
  
  if (!initialised) return 0;

  buf[0]=0;

  va_start( ap , fmt );

  mret = WaitSema( mutex );
  if ( mret < 0 )
  {
     printf( "PS2DEBUG: WaitSema failed %i\n", mret );
     return 0;
  }

  /*
   * The vsprintf call fails..  so we just print the fmt.
   */

  vsprintf( buffer, fmt, ap );
  va_end(ap);

//  printf("NET: ");
  printf( "%s", fmt );
//  printf( buffer );

  mret = SignalSema( mutex );
  if ( mret < 0 )
     printf( "PS2DEBUG: SignalSema failed %i\n", mret );

  return ret;

}



