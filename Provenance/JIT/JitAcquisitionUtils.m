// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#import "JitAcquisitionUtils.h"

#import <dlfcn.h>

#import "CodeSignatureUtils.h"
#import "DebuggerUtils.h"
#import "FastmemUtil.h"

static bool s_has_jit = false;
static bool s_has_jit_with_ptrace = false;
static bool s_has_jit_with_debugger = false;
static bool s_is_arm64e = false;
static DOLJitError s_acquisition_error = DOLJitErrorNone;
static char s_acquisition_error_message[256];

bool GetCpuArchitecture(void)
{
  // Query MobileGestalt for the CPU architecture
  void* gestalt_handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
  if (!gestalt_handle)
  {
    return false;
  }
  
  typedef NSString* (*MGCopyAnswer_ptr)(NSString*);
  MGCopyAnswer_ptr MGCopyAnswer = (MGCopyAnswer_ptr)dlsym(gestalt_handle, "MGCopyAnswer");
  
  if (!MGCopyAnswer)
  {
    return false;
  }
  
  NSString* cpu_architecture = MGCopyAnswer(@"k7QIBwZJJOVw+Sej/8h8VA"); // "CPUArchitecture"
  s_is_arm64e = [cpu_architecture isEqualToString:@"arm64e"];
  
  dlclose(gestalt_handle);
  
  return true;
}

DOLJitError AcquireJitWithAllowUnsigned(void)
{
  if (!GetCpuArchitecture())
  {
    SetJitAcquisitionErrorMessage(dlerror());
    return DOLJitErrorGestaltFailed;
  }
  
  if (!s_is_arm64e)
  {
    return DOLJitErrorNotArm64e;
  }
  
  if (!HasValidCodeSignature())
  {
    return DOLJitErrorImproperlySigned;
  }
  
  // CS_EXECSEG_ALLOW_UNSIGNED will let us have JIT
  // (assuming it's signed correctly)
  return DOLJitErrorNone;
}

void AcquireJit(void)
{
  if (IsProcessDebugged())
  {
    s_has_jit = true;
    return;
  }
  
#if TARGET_OS_SIMULATOR
  s_has_jit = true;
  return;
#endif
  
#ifdef NONJAILBROKEN
  if (@available(iOS 14.4, *))
  {
    // "Yes", we do have JIT. At least, we will later when AltServer/Jitterbug/
    // Xcode/etc connnects to us.
    s_has_jit = true;
  }
  else if (@available(iOS 14.2, *))
  {
    s_acquisition_error = AcquireJitWithAllowUnsigned();
    if (s_acquisition_error == DOLJitErrorNone)
    {
      s_has_jit = true;
    }
  }
  else if (@available(iOS 14, *))
  {
    s_acquisition_error = DOLJitErrorNeedUpdate;
  }
  else if (@available(iOS 13.5, *))
  {
    SetProcessDebuggedWithPTrace();
    
    s_has_jit = true;
    s_has_jit_with_ptrace = true;
  }
  else
  {
    s_acquisition_error = DOLJitErrorNeedUpdate;
  }
#else // jailbroken
  bool success = false;
  
  // Check for jailbreakd (Chimera, Electra, Odyssey...)
  NSFileManager* file_manager = [NSFileManager defaultManager];
  if ([file_manager fileExistsAtPath:@"/var/run/jailbreakd.pid"])
  {
    success = SetProcessDebuggedWithJailbreakd();
    if (!success)
    {
      s_acquisition_error = DOLJitErrorJailbreakdFailed;
    }
  }
  else
  {
    success = SetProcessDebuggedWithDaemon();
    if (!success)
    {
      s_acquisition_error = DOLJitErrorCsdbgdFailed;
    }
  }
  
  s_has_jit = success;
#endif
}

bool HasJit(void)
{
  return s_has_jit;
}

bool HasJitWithPTrace(void)
{
  return s_has_jit_with_ptrace;
}

DOLJitError GetJitAcquisitionError(void)
{
  return s_acquisition_error;
}

char* GetJitAcquisitionErrorMessage(void)
{
  return s_acquisition_error_message;
}

void SetJitAcquisitionErrorMessage(char* error)
{
  strncpy(s_acquisition_error_message, error, 256);
  s_acquisition_error_message[255] = '\0';
}
