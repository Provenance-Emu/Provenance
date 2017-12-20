/*
 *   Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */


#ifndef __LZMASDKOBJC_H__
#define __LZMASDKOBJC_H__ 1


/*
 *   Lzma SDK for Objective-C based on extended functionality of the C++ LZMA code
 *
 *   Changes on version 2.0.13 (current):
 *   - Added all default (de)coders.
 *
 *   Changes on version 2.0.12:
 *   - Add BCJ2 and PPMdH (de)coders.
 *
 *   Changes on version 2.0.10:
 *   - Update C++ source to version 16.04 (1604 - latest for now).
 *
 *   Changes on version 2.0.9:
 *   - Update C++ source to version 16.03 (1603 - latest for now).
 *
 *   Changes on version 2.0.8:
 *   - Fix Cocoapod script.
 *
 *   Changes on version 2.0.5:
 *   - Omin some unused code.
 *   - Disable Unicode, used UTF8 instead.
 *
 *   Changes on version 2.0.3:
 *   - Remove redurant string conversion code.
 *
 *   Changes on version 2.0.2:
 *   - Fix encode settings count. 
 *
 *   Changes on version 2.0.1:
 *   - Remove xz support.
 *   - Customize all writer settings.
 *
 *   Changes on version 2.0.0:
 *   - Reduce ammount of static variables.
 *   - Error domain, e.g. `kLzmaSDKObjCErrorDomain` was changed to `LzmaSDKObjC`.
 *   - Deprecated xz decoding, will be removed in next release.
 *   - 7z archive writer.
 *
 *   Changes on version 1.1.5:
 *   - Added error possible failure reason description. 
 *     Use `NSLocalizedFailureReasonErrorKey` to get possible failure string.
 *
 *   Changes on version 1.1.4:
 *   - Update C++ source to version 16.02 (1602 - latest for now).
 *
 *   Changes on version 1.1.3:
 *   - Update C++ source to version 16.00.
 *
 *   Changes on version 1.1.2:
 *   - Added functionality for compress/decompress single NSData buffer object with LZMA2.
 *
 *   Changes on version 1.0.7:
 *   -  Fix Undefined value access.
 *
 *   Changes on version 1.0.4:
 *   - Add nullability delegate flag to Objective-C reader.
 *
 *   Changes on version 1.0.3:
 *   - Ignore debug log messages via LZMASDKOBJC_NO_DEBUG_LOG.
 *
 *   Changes on version 1.0.2:
 *   - Move additional includes to private part of the code.
 *
 *   Changes on version 1.0.1:
 *   - Lzma & lzma2 test reader.
 *
 *   Changes on version 1.0.0:
 *   - Stable reader.
 *
 *   Changes on version 0.1.2:
 *   - Update C++ source to version 15.14.
 *
 *   Changes on version 0.1.1:
 *   - Update C++ source to version 15.12.
 *
 *   Changes on version 0.1.0:
 *   - iOS min version 8.0.
 *   - Cocoapods framework.
 *
 *   Changes on version 0.0.10:
 *   - Added iOS framework target.
 *   
 *   Changes on version 0.0.9:
 *   - Extract empty archive folders.
 *
 *   Changes on version 0.0.8:
 *   - Update LZMA SDK to version 15.12.
 *     Note: If you use XZ code from LZMA SDK, it's recommended to upgrade to new XZ code from 7-Zip 15.12.
 *     That new code fixes some bugs.
 *
 *   Changes on version 0.0.7:
 *   - Enabled test functionality.
 *
 *   Changes on version 0.0.6:
 *   - Add missed folder creation functionality during extract.
 *   - Add initial error processing.
 *
 *   Changes on version 0.0.5:
 *   - LzmaSDKObjCItem strong field references.
 *
 *   Changes on version 0.0.4:
 *   - LzmaSDKObjCReader strong field references.
 *
 *   Changes on version 0.0.3:
 *   - Less static consts & variables.
 *   - Exclude some unused code with preprocessor define.
 *   - Test archive items CRC.
 *
 *   Changes on version 0.0.2:
 *   - Define memory size allocation for list and extract functionality.
 *   - Fix closing last extracted file before deallocating reader.
 *   - Code description.
 *
 *   Version 0.0.1:
 *   - Implemented list and extract of the Lzma & Lzma2 7z files.
 */


#define LZMASDKOBJC_VERSION_MAJOR 2
#define LZMASDKOBJC_VERSION_MINOR 0
#define LZMASDKOBJC_VERSION_PATCH 13


#import "LzmaSDKObjCTypes.h"
#import "LzmaSDKObjCReader.h"
#import "LzmaSDKObjCWriter.h"


/**
 Convert `NSString` to wide character string with NULL terminated character at the end.
 @warning Call `free` ater using the result.
 */
LZMASDKOBJC_EXTERN wchar_t * _Nullable NSStringToWideCharactersString(NSString * _Nullable string);


#endif
