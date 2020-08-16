/*
 *   Copyright (c) 2015 - 2020 Oleh Kulykov <olehkulykov@gmail.com>
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


#ifndef __LZMASDKOBJCBASECODER_H__
#define __LZMASDKOBJCBASECODER_H__ 1

#include "LzmaAppleCommon.h"
#include "LzmaSDKObjCTypes.h"
#include "LzmaSDKObjCCommon.h"
#include "LzmaSDKObjCError.h"

#include "../lzma/CPP/Common/MyGuidDef.h"

namespace LzmaSDKObjC {

	class BaseCoder : public LzmaSDKObjC::LastErrorHolder {
	protected:
		void createObject(const LzmaSDKObjCFileType type, const GUID * iid, void ** outObject);

	public:
		void * context;
		LzmaSDKObjCGetVoidCallback getVoidCallback1;
		LzmaSDKObjCSetFloatCallback setFloatCallback2;

		// callbacks section
		void onProgress(const float progress); // encode/decode
		virtual bool requiredCallback1() const; // pwd, default is `false`.
		UString onGetVoidCallback1(); // pwd

		// Required
		// find codec, create encode/decode object and check error.
		virtual bool prepare(const LzmaSDKObjCFileType type) = 0;

		virtual bool openFile(const char * path) = 0;

		BaseCoder();
		virtual ~BaseCoder();
	};

}

#endif
