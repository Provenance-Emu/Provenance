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
/// @param patch Opaque pointer to a Mednafen::MemoryPatch that will be updated on success
/// @param needsMoreParts Out-parameter set to true if this cheat is multipart and requires further
///        calls to DecodeCheat, or false if decoding is complete for this cheat.
/// @return true if decoding succeeded and `patch` (and `*needsMoreParts`) were set successfully;
///         false if an error occurred and no outputs were modified.
bool mednafen_decodeCheat(const void* game,
                          uint8_t formatIndex,
                          const char* cheatCode,
                          void* patch,
                          bool *needsMoreParts);

#if __cplusplus
}
#endif
