// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#import "DebuggerUtils.h"

#import <dlfcn.h>
#import <stdio.h>
#import <unistd.h>

#import "DOLJitManager.h"
#import "StringUtils.h"

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

bool WaitUntilProcessDebugged(int timeout)
{
  int time_left = timeout;
  bool is_debugged = false;
  
  while (time_left > 0)
  {
    is_debugged = IsProcessDebugged();
    if (is_debugged)
    {
      break;
    }
    
    time_left--;
    
    usleep(1000000);
  }
  
  return is_debugged;
}

// Set CS_DEBUGGED if it hasn't been already (ie running through Xcode).
//
// We contact csdbgd (installed with the deb) which will attach to our
// process using ptrace, then immediately detach. This will permanently
// set CS_DEBUGGED on our process. We need to be in the sandbox for
// dynamic-codesigning to function properly, but the trick used in
// ppsspp requires fork(), which does not work in the sandbox. So, we
// have another process set CS_DEBUGGED for us.
//
// Yes, this is a giant hack. However, it works across jailbreaks so
// that's enough for me.
bool SetProcessDebuggedWithDaemon()
{
  // Serialize the process name
  int process_id = getpid();
  NSData* data = [NSData dataWithBytes:&process_id length:sizeof(process_id)];
  
  // Acquire the port
  CFMessagePortRef port = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("me.oatmealdome.csdbgd-port"));
  if (port == NULL)
  {
    [[DOLJitManager sharedManager] setAuxiliaryError:@"Unable to open port"];
    return false;
  }
  
  // Send the message
  SInt32 ret = CFMessagePortSendRequest(port, 1, (__bridge CFDataRef)data, 1000, 0, NULL, NULL);
  if (ret != kCFMessagePortSuccess)
  {
    [[DOLJitManager sharedManager] setAuxiliaryError:@"Failed to send message through port"];
    return false;
  }
  
  // Wait until CS_DEBUGGED is set
  bool success = WaitUntilProcessDebugged(5);
  if (!success)
  {
    [[DOLJitManager sharedManager] setAuxiliaryError:@"csdbgd timed out"];
  }
  
  return success;
}

void* LoadLibJailbreak()
{
  // Try to use one provided by the jailbreak first
  void* dylib_handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
  if (dylib_handle)
  {
    return dylib_handle;
  }
  
  // Attempt to use our internal copy taken from Chimera
  NSString* internal_path = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks"] stringByAppendingPathComponent:@"libjailbreak.dylib"];
  return dlopen(FoundationToCString(internal_path), RTLD_LAZY);
}

// We can just ask jailbreakd to set CS_DEBUGGED for us.
bool SetProcessDebuggedWithJailbreakd()
{
  // Open a handle to libjailbreak
  void* dylib_handle = LoadLibJailbreak();
  if (!dylib_handle)
  {
    [[DOLJitManager sharedManager] setAuxiliaryError:CToFoundationString(dlerror())];
    return false;
  }
  
  // Load the function
  typedef int (*entitle_now_ptr)(pid_t pid, uint32_t flags);
  entitle_now_ptr ptr = (entitle_now_ptr)dlsym(dylib_handle, "jb_oneshot_entitle_now");
  
  if (!ptr)
  {
    [[DOLJitManager sharedManager] setAuxiliaryError:CToFoundationString(dlerror())];
    
    dlclose(dylib_handle);
    return false;
  }
  
  // Go!
  ptr(getpid(), FLAG_PLATFORMIZE);
  
  dlclose(dylib_handle);
  
  return true;
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

