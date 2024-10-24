/***************************************************************************************
 *  Genesis Plus
 *  Sega/Mega Mouse support
 *
 *  Copyright (C) 2007-2017  Eke-Eke (Genesis Plus GX)
 *
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************************/

#include "shared.h"

static struct
{
  uint8 State;
  uint8 Counter;
  uint8 Wait;
  uint8 Port;
} mouse;

void mouse_reset(int port)
{
  input.analog[port][0] = 0;
  input.analog[port][1] = 0;
  mouse.State = 0x60;
  mouse.Counter = 0;
  mouse.Wait = 0;
  mouse.Port = port;
}

unsigned char mouse_read()
{
  unsigned int temp = 0x00;
  int x = input.analog[mouse.Port][0];
  int y = input.analog[mouse.Port][1];

  switch (mouse.Counter)
  {
    case 0: /* initial */
      temp = 0x00;
      break;

    case 1: /* xxxx1011 */
      temp = 0x0B;
      break;

    case 2: /* xxxx1111 */
      temp = 0x0F;
      break;

    case 3: /* xxxx1111 */
      temp = 0x0F;
      break;

    case 4: /* Axis sign & overflow (not emulated) bits */
      temp |= (x < 0);
      temp |= (y < 0) << 1;
      /*
      temp |= (abs(x) > 255) << 2;
      temp |= (abs(y) > 255) << 3;
      */
      break;

    case 5: /* START, A, B, C buttons state (active high) */
      temp = (input.pad[mouse.Port] >> 4) & 0x0F;
      break;

    case 6: /* X Axis MSB */
      temp = (x >> 4) & 0x0F;
      break;
      
    case 7: /* X Axis LSB */
      temp = (x & 0x0F);
      break;

    case 8: /* Y Axis MSB */
      temp = (y >> 4) & 0x0F;
      break;
      
    case 9: /* Y Axis LSB */
      temp = (y & 0x0F);
      break;
  }

  /* TL = busy status */
  if (mouse.Wait)
  {
    /* wait before acknowledging handshake request */
    mouse.Wait--; 

    /* TL = !TR (handshake in progress) */
    temp |= (~mouse.State & 0x20) >> 1;;
  }
  else
  {
    /* TL = TR (handshake completed) */
    temp |= (mouse.State & 0x20) >> 1;
  }

  return temp;
}

void mouse_write(unsigned char data, unsigned char mask)
{
  /* update bits set as output only */
  data = (mouse.State & ~mask) | (data & mask);

  /* TR transition */
  if ((mouse.State ^ data) & 0x20)
  {
    /* check if acquisition is started */
    if ((mouse.Counter > 0) && (mouse.Counter < 9))
    {
      /* increment phase */
      mouse.Counter++;
    }

    /* TL handshake latency (fix buggy mouse routine in Cannon Fodder, Shangai 2, Wacky World, Star Blade, ...) */
    mouse.Wait = 2;
  }

  /* TH transition  */
  if ((mouse.State ^ data) & 0x40)
  {
    /* start (TH=1->0) or stop (TH=0->1) data acquisition */
    mouse.Counter = (mouse.State >> 6) & 1;
  }

  /* update internal state */
  mouse.State = data;
}
