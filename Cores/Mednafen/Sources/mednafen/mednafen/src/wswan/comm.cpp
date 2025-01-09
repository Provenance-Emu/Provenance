/* Mednafen - Multi-system Emulator
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

#include "wswan.h"

#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>

#ifdef HAVE_FORK
#include <sys/wait.h>
#include <signal.h>
#endif

namespace MDFN_IEN_WSWAN
{

static uint8 Control;
static uint8 SendBuf, RecvBuf;
static bool SendLatched, RecvLatched;

static int child_pid = -1;
static int stdin_pipes[2] = { -1, -1 };
static int stdout_pipes[2] = { -1, -1 };

void Comm_Init(const char *wfence_path)
{
 child_pid = -1;

 stdin_pipes[0] = -1;
 stdin_pipes[1] = -1;

 stdout_pipes[0] = -1;
 stdout_pipes[1] = -1;

#ifdef HAVE_FORK
 if(wfence_path != NULL)
 {
  pipe(stdin_pipes);
  pipe(stdout_pipes);

  child_pid = fork();

  if(child_pid == -1)
   abort();
  else if(child_pid == 0)	// Child
  {
   dup2(stdin_pipes[0], 0);
   dup2(stdout_pipes[1], 1);
   execlp(wfence_path, wfence_path, "ASDF", (char*)NULL);
   abort();
  }

  fcntl(stdout_pipes[0], F_SETFL, fcntl(stdout_pipes[0], F_GETFL) | O_NONBLOCK);
 }
#endif
}

void Comm_Kill(void)
{
#ifdef HAVE_FORK
 if(child_pid != -1)
 {
  int status;

  kill(child_pid, SIGTERM);
  waitpid(child_pid, &status, 0);

  child_pid = -1;
 }
#endif

 for(unsigned i = 0; i < 2; i++)
 {
  if(stdin_pipes[i] != -1)
  {
   close(stdin_pipes[i]);
   stdin_pipes[i] = -1;
  }

  if(stdout_pipes[i] != -1)
  {
   close(stdout_pipes[i]);
   stdout_pipes[i] = -1;
  }
 }
}

void Comm_Reset(void)
{
 SendBuf = 0x00;
 RecvBuf = 0x00;

 SendLatched = false;
 RecvLatched = false;

 Control = 0x00;

 WSwan_InterruptAssert(WSINT_SERIAL_RECV, RecvLatched);

 //if(child_pid != -1)
 // kill(child_pid, SIGUSR1);
}

void Comm_Process(void)
{
 if(SendLatched && (Control & 0x80))
 {
  if(stdin_pipes[1] != -1)
  {
   if(write(stdin_pipes[1], &SendBuf, 1) == 1)
   {
    //printf("SENT: %02x %d\n", SendBuf, RecvLatched);
    SendLatched = false;
    WSwan_Interrupt(WSINT_SERIAL_SEND);
   }
  }
  else
  {
   //printf("DummySend: %02x %d\n", SendBuf, RecvLatched);
   SendLatched = false;
   WSwan_Interrupt(WSINT_SERIAL_SEND);
  }
 }
 else if(!RecvLatched && (Control & 0x20))
 {
  if(stdout_pipes[0] != -1)
  {
   if(read(stdout_pipes[0], &RecvBuf, 1) == 1)
   {
    //printf("RECEIVED: %02x\n", RecvBuf);
    RecvLatched = true;
    WSwan_InterruptAssert(WSINT_SERIAL_RECV, RecvLatched);
   }
  }
 }
}

uint8 Comm_Read(uint8 A)
{
 //printf("Read: %02x\n", A);

 if(A == 0xB1)
 {
  if(!WS_InDebug)
  {
   RecvLatched = false;
   WSwan_InterruptAssert(WSINT_SERIAL_RECV, RecvLatched);
  }

  return(RecvBuf);
 }
 else if(A == 0xB3)
 {
  uint8 ret = Control & 0xF0;

  if((Control & 0x80) && !SendLatched)
   ret |= 0x4;

  if((Control & 0x20) && RecvLatched)
   ret |= 0x1;

  return(ret);
 }

 return(0x00);
}

void Comm_Write(uint8 A, uint8 V)
{
 //printf("Write: %02x %02x\n", A, V);

 if(A == 0xB1)
 {
  if(Control & 0x80)
  {
   SendBuf = V;
   SendLatched = true;
  }
 }
 else if(A == 0xB3)
 {
  Control = V & 0xF0;
 }
}

void Comm_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SendBuf),
  SFVAR(RecvBuf),

  SFVAR(SendLatched),
  SFVAR(RecvLatched),

  SFVAR(Control),

  SFEND
 };

 if(load && load < 0x0936)
 {
  SendBuf = 0x00;
  RecvBuf = 0x00;

  SendLatched = false;
  RecvLatched = false;

  Control = 0x00;
 } 
 else
 {
  MDFNSS_StateAction(sm, load, data_only, StateRegs, "COMM");

  if(load)
  {
   WSwan_InterruptAssert(WSINT_SERIAL_RECV, RecvLatched);
  }
 }
}

}
