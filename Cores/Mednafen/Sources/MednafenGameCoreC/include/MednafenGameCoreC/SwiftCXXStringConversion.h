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
#import <stdbool.h>
#import <stdint.h>

#if __cplusplus
extern "C" {
#endif
const char* swiftStringToCppString(NSString* swiftString);
void* createCppString(const char* cString);
void deleteCppString(void* cppStringPtr);
const char* getCppStringContents(void* cppStringPtr);

/// Wraps the C++ CheatFormatStruct::DecodeCheat call so Swift can invoke it
/// without needing direct std::string interop.
/// @param game Opaque pointer to Mednafen::MDFNGI (obtained via getGame)
/// @param formatIndex Index into CheatFormatInfo for the desired cheat format
/// @param cheatCode Null-terminated cheat string
/// @param patch Opaque pointer to a Mednafen::MemoryPatch
/// @return true if this is part of a multipart cheat, false otherwise.
///         Returns false and sets nothing on error.
bool mednafen_decodeCheat(const void* game, uint8_t formatIndex, const char* cheatCode, void* patch);

#if __cplusplus
}
#endif
