/***************************************************************************************
 *  Genesis Plus
 *  Sega Graphic Board support
 *
 *  Copyright (C) 2014  Eke-Eke (Genesis Plus GX)
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
  uint8 Port;
} board;

void graphic_board_reset(int port)
{
  input.analog[0][0] = 128;
  input.analog[0][1] = 128;
  board.State = 0x7f;
  board.Counter = 0;
  board.Port = port;
}

unsigned char graphic_board_read(void)
{
  uint8 data;

  if (board.State & 0x20)
  {
    return 0x60;
  }

  switch (board.Counter & 7)
  {
    case 0:
      data = ~input.pad[board.Port];
      break;
    case 1:
      data = 0x0f;
      break;
    case 2:
      data = 0x0f;
      break;
    case 3:
      data = input.analog[board.Port][0] >> 4;
      break;
    case 4:
      data = input.analog[board.Port][0];
      break;
    case 5:
      data = input.analog[board.Port][1] >> 4;
      break;
    case 6:
      data = input.analog[board.Port][1];
      break;
    case 7:
      data = 0x0f;
      break;
  }

  return (board.State & ~0x1f) | (data  & 0x0f);
}

void graphic_board_write(unsigned char data, unsigned char mask)
{
  data = (board.State & ~mask) | (data & mask);

  if ((data ^ board.State) & 0x20)
  {
    board.Counter = 0;
  }
  else if ((data ^ board.State) & 0x40)
  {
    board.Counter++;
  }

  board.State = data;
}
