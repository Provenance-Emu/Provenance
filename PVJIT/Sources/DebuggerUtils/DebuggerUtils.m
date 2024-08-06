// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#import "DebuggerUtils.h"

#import <dlfcn.h>
#import <stdio.h>
#import <unistd.h>

#define CS_OPS_STATUS 0 /* OK */
#define CS_DEBUGGED 0x10000000 /* process is or has been debugged */
extern int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);

#define PT_TRACEME 0
extern int ptrace(int a, int b, void* c, int d);

#define FLAG_PLATFORMIZE (1 << 1) /* jailbreakd - set as platform binary */

bool IsProcessDebugged()
{
  int flags;
  int retval = csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags));
  return retval == 0 && flags & CS_DEBUGGED;
}

bool SetProcessDebuggedWithPTrace()
{
  if (@available(iOS 14, *))
  {
    return false;
  }
  
  ptrace(PT_TRACEME, 0, NULL, 0);
  
  return true;
}

