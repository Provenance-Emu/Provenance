//
//  MednafenGameCoreC.m
//  MednafenGameCoreC
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#import <string>
#import <Foundation/Foundation.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
#pragma clang diagnostic ignored "-Wextra"
#import <mednafen/mednafen.h>
#import <mednafen/mempatcher.h>
#pragma clang diagnostic pop

#if __cplusplus
extern "C" {
#endif
    const char* swiftStringToCppString(NSString* swiftString) {
        std::string* cppString = new std::string([swiftString UTF8String]);
        return cppString->c_str();
    }

    void* createCppString(const char* cString) {
        return new std::string(cString);
    }

    void deleteCppString(void* cppStringPtr) {
        delete static_cast<std::string*>(cppStringPtr);
    }

    const char* getCppStringContents(void* cppStringPtr) {
        return static_cast<std::string*>(cppStringPtr)->c_str();
    }

    bool mednafen_decodeCheat(const void* game, uint8_t formatIndex, const char* cheatCode, void* patch) {
        auto gi = static_cast<const Mednafen::MDFNGI*>(game);
        auto mp = static_cast<Mednafen::MemoryPatch*>(patch);
        const auto& formats = gi->CheatInfo.CheatFormatInfo;
        if (formatIndex >= formats.size()) {
            return false;
        }
        std::string codeStr(cheatCode);
        try {
            return formats[formatIndex].DecodeCheat(codeStr, mp);
        } catch (...) {
            return false;
        }
    }
#if __cplusplus
}
#endif
