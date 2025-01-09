//
//  MednafenGameCoreC.h
//  MednafenGameCoreC
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#pragma once

//#import <string>
#import <Foundation/Foundation.h>

#if __cplusplus
extern "C" {
#endif
const char* swiftStringToCppString(NSString* swiftString);
void* createCppString(const char* cString);
void deleteCppString(void* cppStringPtr);
const char* getCppStringContents(void* cppStringPtr);
#if __cplusplus
}
#endif
