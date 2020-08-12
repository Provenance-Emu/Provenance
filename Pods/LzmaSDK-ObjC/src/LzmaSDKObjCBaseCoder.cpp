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


#include "LzmaSDKObjCBaseCoder.h"

#include "../lzma/CPP/Common/IntToString.h"
#include "../lzma/CPP/Common/StringConvert.h"

#include "../lzma/CPP/7zip/Archive/DllExports2.h" // custom header with `STDAPI CreateObject(const GUID *clsid, const GUID *iid, void **outObject);`
#include "../lzma/CPP/7zip/Archive/IArchive.h"
#include "../lzma/CPP/7zip/IPassword.h"

namespace LzmaSDKObjC {

	void BaseCoder::createObject(const LzmaSDKObjCFileType type, const GUID * iid, void ** outObject) {
		this->clearLastError();
		if (type) {
			const GUID * clsid = NULL;
			const GUID clsid7z = Common::CLSIDFormat7z();
			switch (type) {
				case LzmaSDKObjCFileType7z: clsid = &clsid7z; break;
				default:
					this->setLastError(-1, __LINE__, __FILE__, "Can't find codec for unsupported file type: %i", (int)type);
					this->setLastErrorReason("Not one of the: ['7z']");
					return;
					break;
			}

			if (CreateObject(clsid, iid, outObject) != S_OK) {
				this->setLastError(-1, __LINE__, __FILE__, "Can't create archive object file type: %i", (int)type);
				this->setLastErrorReason("- Unsupported archive GUID.\n"
										 "- Codec was not compiled in or stripped by static linking. Make sure you are using 'use_frameworks!' and/or dynamic linking.");
			}
		} else {
			this->setLastError(-1, __LINE__, __FILE__, "Type of the archive is undefined, create reader with manual type");
		}
	}

	void BaseCoder::onProgress(const float progress) {
		if (context && setFloatCallback2) setFloatCallback2(context, progress);
	}

	bool BaseCoder::requiredCallback1() const {
		return false;
	}

	UString BaseCoder::onGetVoidCallback1() {
		wchar_t * w = (context && getVoidCallback1) ? (wchar_t *)getVoidCallback1(context) : NULL;
		if (w) {
			UString r(w);
			free(w);
			return r;
		}
		return UString();
	}

	BaseCoder::BaseCoder() : LzmaSDKObjC::LastErrorHolder(),
		context(NULL),
		getVoidCallback1(NULL),
		setFloatCallback2(NULL) {
		LzmaSDKObjC::Common::initialize();
	}

	BaseCoder::~BaseCoder() {

	}

}
