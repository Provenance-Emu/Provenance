//
//  MednafenGameCoreC.m
//  MednafenGameCoreC
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#import <string>
#import <Foundation/Foundation.h>

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
#if __cplusplus
}
#endif
