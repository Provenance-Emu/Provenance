//
//  MednafenGameCoreC.h
//  MednafenGameCoreC
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#pragma once

#define LSB_FIRST 1

#include "mednafen/types.h"

#include <string>
#include <fstream>
#include <iostream>
#include <vector>
#include <map>
#include <algorithm>
#include <functional>
#include <memory>

#include "mednafen/mednafen.h"
#include "mednafen/driver.h"
#include "mednafen/git.h"
#include "mednafen/mempatcher.h"
#include <mednafen/mednafen-driver.h>
#include <mednafen/NativeVFS.h>
#include <mednafen/MemoryStream.h>

#import <string>
#import <Foundation/Foundation.h>

#ifdef __cplusplus

namespace MDFN_IEN_VB
{
extern void VIP_SetParallaxDisable(bool disabled);
extern void VIP_SetAnaglyphColors(uint32 lcolor, uint32 rcolor);
int mednafenCurrentDisplayMode = 1;
}
#endif


#ifdef __cplusplus
extern "C" {
#endif

const char* swiftStringToCppString(NSString* swiftString);
void* createCppString(const char* cString);
void deleteCppString(void* cppStringPtr);
const char* getCppStringContents(void* cppStringPtr);

#ifdef __cplusplus
}
#endif
