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


#ifndef __LZMASDKOBJCTYPES_H__
#define __LZMASDKOBJCTYPES_H__ 1

/**
 no #include
 */


#if !defined(LZMASDKOBJC_EXTERN)
#if defined(__cplusplus) || defined(_cplusplus)
#define LZMASDKOBJC_EXTERN extern "C"
#else
#define LZMASDKOBJC_EXTERN extern
#endif
#endif

typedef enum _LzmaSDKObjCFileType {
	LzmaSDKObjCFileTypeUndefined = 0,
	LzmaSDKObjCFileType7z = 1
} LzmaSDKObjCFileType;

typedef enum _LzmaSDKObjCMethod {
	LzmaSDKObjCMethodLZMA = 0,
	LzmaSDKObjCMethodLZMA2 = 1
} LzmaSDKObjCMethod;

typedef void * (*LzmaSDKObjCGetVoidCallback)(void * context);
typedef void (*LzmaSDKObjCSetFloatCallback)(void * context, float value);

#if (defined(DEBUG) || defined(_DEBUG)) && !defined(LZMASDKOBJC_NO_DEBUG_LOG)
#define LZMASDK_DEBUG_LOG(M, ...) fprintf(stdout, "LZMA DEBUG %d: " M "\n", __LINE__, ##__VA_ARGS__);
#define LZMASDK_DEBUG_ERR(M, ...) fprintf(stderr, "LZMA ERROR %d: " M "\n", __LINE__, ##__VA_ARGS__);
#else
#define LZMASDK_DEBUG_LOG(M, ...)
#define LZMASDK_DEBUG_ERR(M, ...)
#endif

#endif
