/***************************************************************************************
 *  Genesis Plus
 *  2-Buttons, 3-Buttons & 6-Buttons controller support
 *  with support for J-Cart, 4-Way Play & Master Tap adapters
 *
 *  Copyright (C) 2007-2019  Eke-Eke (Genesis Plus GX)
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
#include "gamepad.h"

static struct
{
  uint8 State;
  uint8 Counter;
  uint8 Timeout;
  uint32 Latency;
} gamepad[MAX_DEVICES];

static struct
{
  uint8 Latch;
  uint8 Counter;
} flipflop[2];

static uint8 latch;


void gamepad_reset(int port)
{
  /* default state (Gouketsuji Ichizoku / Power Instinct, Samurai Spirits / Samurai Shodown) */
  gamepad[port].State = 0x40;
  gamepad[port].Counter = 0;
  gamepad[port].Timeout = 0;
  gamepad[port].Latency = 0;

  /* reset 4-WayPlay latch (controller #0 used by default) */
  latch = 0x00;

  /* reset Master Tap flip-flop */
  flipflop[port>>2].Latch = 0;
  flipflop[port>>2].Counter = 0;
}

void gamepad_refresh(int port)
{
  /* 6-buttons pad */
  if (gamepad[port].Timeout++ > 25)
  {
    gamepad[port].Counter = 0;
    gamepad[port].Timeout = 0;
  }
}

void gamepad_end_frame(int port, unsigned int cycles)
{
  if (gamepad[port].Latency > cycles)
  {
    /* adjust TH direction switching latency for next frame */
    gamepad[port].Latency -= cycles;
  }
  else
  {
    /* reset TH direction switching latency */
    gamepad[port].Latency = 0;
  }
}

INLINE unsigned char gamepad_read(int port)
{
  /* D7 is not connected, D6 returns TH input state */
  unsigned int data = gamepad[port].State | 0x3F;

  /* pad state */
  unsigned int pad = input.pad[port];

  /* get current TH input pulse counter */
  unsigned int step = gamepad[port].Counter | (data >> 6);

  /* get current timestamp */
  unsigned int cycles = ((system_hw & SYSTEM_PBC) == SYSTEM_MD) ? m68k.cycles : Z80.cycles;

  /* TH direction switching latency */
  if (cycles < gamepad[port].Latency)
  {
    /* TH internal state switching has not occured yet (Decap Attack) */
    step &= ~1;
  }

  /* C/B or START/A buttons status is returned on D5-D4 (active low) */
  /* D-PAD or extra buttons status is returned on D3-D0 (active low) */
  switch (step)
  {
    /* From gen_hw.txt (*):

       A 6-button gamepad allows the extra buttons to be read based on how
       many times TH is switched from 0 to 1. Observe the following sequence:

       TH = 1 : ?1CBRLDU    3-button pad return value
       TH = 0 : ?0SA00DU    3-button pad return value
       TH = 1 : ?1CBRLDU    3-button pad return value (*)
       TH = 0 : ?0SA00DU    3-button pad return value (*)
       TH = 1 : ?1CBRLDU    3-button pad return value
       TH = 0 : ?0SA0000    D3-D0 are forced to '0'
       TH = 1 : ?1CBMXYZ    Extra buttons returned in D3-0
       TH = 0 : ?0SA1111    D3-D0 are forced to '1'

       From this point on, the standard 3-button pad values will be returned if any further TH transitions are done.

       (*) additional High-to-Low transition is necessary to access extra buttons according to official MK-1653-50 specification 
    */
    case 4: /*** Third Low ***/
    {
      /* TH = 0 : ?0SA0000    D3-D0 forced to '0' */
      data &= ~(((pad >> 2) & 0x30) | 0x0F);
      break;
    }

    case 7: /*** Fourth High ***/
    {
      /* TH = 1 : ?1CBMXYZ    Extra buttons returned in D3-D0 */
      data &= ~((pad & 0x30) | ((pad >> 8) & 0x0F));
      break;
    }

    case 6: /*** Fourth Low ***/
    {
      /* TH = 0 : ?0SA1111    D3-D0 forced to '1' */
      data &= ~((pad >> 2) & 0x30);
      break;
    }

    default: /*** 3-button mode ***/
    {
      if (step & 1)
      {
        /* TH = 1 : ?1CBRLDU */
        data &= ~(pad & 0x3F);
      }
      else
      {
        /* TH = 0 : ?0SA00DU */
        data &= ~((pad & 0x03) | ((pad >> 2) & 0x30) | 0x0C);
      }
      break;
    }
  }

  return data;
}

INLINE void gamepad_write(int port, unsigned char data, unsigned char mask)
{
  /* Check TH pin direction */
  if (mask & 0x40)
  {
    /* get TH output state */
    data &= 0x40;

    /* reset TH direction switching latency */
    gamepad[port].Latency = 0;

    /* 6-Buttons controller specific */
    if ((input.dev[port] == DEVICE_PAD6B) && (gamepad[port].Counter < 8))
    {
      /* TH 0->1 transition */
      if (data && !gamepad[port].State)
      {
        gamepad[port].Counter += 2;
        gamepad[port].Timeout = 0;
      }
    }
  }
  else
  {
    /* retrieve current timestamp */
    unsigned int cycles = ((system_hw & SYSTEM_PBC) == SYSTEM_MD) ? m68k.cycles : Z80.cycles;

    /* TH is pulled high when not configured as output by I/O controller */
    data = 0x40;

    /* TH 0->1 internal switching does not occur immediately (verified on MK-1650 model) */
    if (!gamepad[port].State)
    {
      gamepad[port].Latency = cycles + 172;
    }
  }

  /* update TH input state */
  gamepad[port].State = data;
}

/*--------------------------------------------------------------------------*/
/*  Default ports handlers                                                  */
/*--------------------------------------------------------------------------*/

unsigned char gamepad_1_read(void)
{
  return gamepad_read(0);
}

unsigned char gamepad_2_read(void)
{
  return gamepad_read(4);
}

void gamepad_1_write(unsigned char data, unsigned char mask)
{
  gamepad_write(0, data, mask);
}

void gamepad_2_write(unsigned char data, unsigned char mask)
{
  gamepad_write(4, data, mask);
}

/*--------------------------------------------------------------------------*/
/*  4-WayPlay ports handler                                                 */
/*--------------------------------------------------------------------------*/

unsigned char wayplay_1_read(void)
{
  /* check if latched TH input on port B is HIGH */
  if (latch & 0x04)
  {
    /* 4-WayPlay detection : xxxxx00 */
    return 0x7C;
  }

  /* latched TR & TL input state on port B select controller # (0-3) on port A */
  return gamepad_read(latch);
}

unsigned char wayplay_2_read(void)
{
  return 0x7F;
}

void wayplay_1_write(unsigned char data, unsigned char mask)
{
  /* latched TR & TL input state on port B select controller # (0-3) on port A */
  gamepad_write(latch & 0x03, data, mask);
}

void wayplay_2_write(unsigned char data, unsigned char mask)
{
  /* pins not configured as output by I/O controller are pulled HIGH */
  data |= ~mask;

  /* check if both UP & DOWN inputs are LOW */
  if (!(data & 0x03))
  {
    /* latch TH, TR & TL input state */
    latch = (data >> 4) & 0x07;
  }
}


/*--------------------------------------------------------------------------*/
/*  J-Cart memory handlers                                                  */
/*--------------------------------------------------------------------------*/

unsigned int jcart_read(unsigned int address)
{
   /* D6 returns TH state, D14 is fixed low (fixes Micro Machines 2) */
   return (gamepad_read(5) | ((gamepad_read(6) & 0x3F) << 8));
}

void jcart_write(unsigned int address, unsigned int data)
{
  data = (data & 0x01) << 6;
  gamepad_write(5, data, 0x40);
  gamepad_write(6, data, 0x40);
}


/*--------------------------------------------------------------------------*/
/*  Master Tap ports handler (unofficial, designed by Furrtek)              */
/*  cf. http://www.smspower.org/uploads/Homebrew/BOoM-SMS-sms4p_2.png       */
/*--------------------------------------------------------------------------*/
unsigned char mastertap_1_read(void)
{
  return gamepad_read(flipflop[0].Counter);
}

unsigned char mastertap_2_read(void)
{
  return gamepad_read(flipflop[1].Counter + 4);
}

void mastertap_1_write(unsigned char data, unsigned char mask)
{
  /* update bits set as output only */
  data = (flipflop[0].Latch & ~mask) | (data & mask);
  
  /* check TH 1->0 transitions */
  if ((flipflop[0].Latch & 0x40) && !(data & 0x40))
  {
    flipflop[0].Counter = (flipflop[0].Counter + 1) & 0x03;
  }

  /* update internal state */
  flipflop[0].Latch = data;
}

void mastertap_2_write(unsigned char data, unsigned char mask)
{
  /* update bits set as output only */
  data = (flipflop[1].Latch & ~mask) | (data & mask);
  
  /* check TH 1->0 transition */
  if ((flipflop[1].Latch & 0x40) && !(data & 0x40))
  {
    flipflop[1].Counter = (flipflop[1].Counter + 1) & 0x03;
  }

  /* update internal state */
  flipflop[1].Latch = data;
}
