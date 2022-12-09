/***************************************************************************************
 *  Genesis Plus
 *  XE-1AP analog controller support
 *
 *  Copyright (C) 2011-2015  Eke-Eke (Genesis Plus GX)
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

#define XE_1AP_LATENCY 3

static struct
{
  uint8 State;
  uint8 Counter;
  uint8 Latency;
} xe_1ap[2];

void xe_1ap_reset(int index)
{
  input.analog[index][0] = 128;
  input.analog[index][1] = 128;
  input.analog[index+1][0] = 128;
  index >>= 2;
  xe_1ap[index].State = 0x40;
  xe_1ap[index].Counter = 11;
  xe_1ap[index].Latency = 0;
}

INLINE unsigned char xe_1ap_read(int index)
{
  unsigned char data;
  unsigned int port = index << 2;

  /* Current data transfer cycle */
  switch (xe_1ap[index].Counter)
  {
    case 0: /* E1 E2 Start Select buttons status (active low) */
      data = (~input.pad[port] >> 10) & 0x0F;
      break;
    case 1: /* A/A' B/B' C D buttons status (active low) */
      data = ((~input.pad[port] >> 4) & 0x0F) & ~((input.pad[port] >> 6) & 0x0C);
      break;
    case 2: /* CH0 high (Analog Stick Left/Right direction) */
      data = (input.analog[port][0] >> 4) & 0x0F;
      break;
    case 3: /* CH1 high (Analog Stick Up/Down direction) */
      data = (input.analog[port][1] >> 4) & 0x0F;
      break;
    case 4: /* CH2 high (N/A) */
      data = 0x0;
      break;
    case 5: /* CH3 high (Throttle vertical or horizontal direction) */
      data = (input.analog[port+1][0] >> 4) & 0x0F;
      break;
    case 6: /* CH0 low (Analog Stick Left/Right direction) */
      data = input.analog[port][0] & 0x0F;
      break;
    case 7: /* CH1 low (Analog Stick Up/Down direction)*/
      data = input.analog[port][1] & 0x0F;
      break;
    case 8: /* CH2 low (N/A) */
      data = 0x0;
      break;
    case 9: /* CH3 low (Throttle vertical or horizontal direction) */
      data = input.analog[port+1][0] & 0x0F;
      break;
    case 10: /* A B A' B' buttons status (active low) */
      data = (~input.pad[port] >> 6) & 0x0F;
      break;
    default: /* N/A */
      data = 0x0F;
      break;
  }

  /* TL indicates current data cycle (0=1st cycle, 1=2nd cycle, etc) */
  data |= ((xe_1ap[index].Counter & 1) << 4);

  /* TR indicates if data is valid (0=valid, 1=not ready) */
  /* Some games expect this bit to switch between 0 and 1 */
  /* so we actually keep it high for some reads after the */
  /* data cycle has been initialized or incremented */
  if (xe_1ap[index].Latency)
  {
    if (xe_1ap[index].Latency > 1)
    {
      /* data is not ready */
      data |= 0x20;
    }

    /* decrement internal latency */
    xe_1ap[index].Latency--;
  }
  else if (xe_1ap[index].Counter <= 10)
  {
    /* next data cycle */
    xe_1ap[index].Counter++;

    /* reinitialize internal latency */
    xe_1ap[index].Latency = XE_1AP_LATENCY;
  }

  return data;
}

INLINE void xe_1ap_write(int index, unsigned char data, unsigned char mask)
{
  /* only update bits set as output */
  data = (xe_1ap[index].State & ~mask) | (data & mask);

  /* look for TH 1->0 transitions */
  if (!(data & 0x40) && (xe_1ap[index].State & 0x40))
  {
    /* reset data acquisition cycle */
    xe_1ap[index].Counter = 0;

    /* initialize internal latency */
    xe_1ap[index].Latency = XE_1AP_LATENCY;
  }

  /* update internal state */
  xe_1ap[index].State = data;
}

unsigned char xe_1ap_1_read(void)
{
  return xe_1ap_read(0);
}

unsigned char xe_1ap_2_read(void)
{
  return xe_1ap_read(1);
}

void xe_1ap_1_write(unsigned char data, unsigned char mask)
{
  xe_1ap_write(0, data, mask);
}

void xe_1ap_2_write(unsigned char data, unsigned char mask)
{
  xe_1ap_write(1, data, mask);
}
