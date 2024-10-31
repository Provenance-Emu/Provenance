// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

typedef NS_ENUM(NSUInteger, DOLJitType)
{
  DOLJitTypeNone,
  DOLJitTypeDebugger,
  DOLJitTypeAllowUnsigned
};

typedef NS_ENUM(NSUInteger, DOLJitError)
{
  DOLJitErrorNone,
  DOLJitErrorNotArm64e, // on NJB iOS 14.2+, need arm64e
  DOLJitErrorImproperlySigned, // on NJB iOS 14.2+, need correct code directory version and flags set
  DOLJitErrorNeedUpdate, // iOS not supported
  DOLJitErrorWorkaroundRequired, // NJB iOS 14.4+ broke the JIT hack
  DOLJitErrorGestaltFailed, // an error occurred with loading MobileGestalt
  DOLJitErrorJailbreakdFailed, // an error occurred with contacting jailbreakd
  DOLJitErrorCsdbgdFailed // an error occurred with contacting csdbgd
};

void AcquireJit(void);
bool HasJit(void);
bool HasJitWithPTrace(void);
bool HasJitWithPsychicpaper(void);
DOLJitError GetJitAcquisitionError(void);
char* GetJitAcquisitionErrorMessage(void);
void SetJitAcquisitionErrorMessage(char* error);

#ifdef __cplusplus
}
#endif
