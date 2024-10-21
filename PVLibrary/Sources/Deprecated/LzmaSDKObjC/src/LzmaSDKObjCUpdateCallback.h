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


#ifndef __LZMASDKOBJCUPDATECALLBACK_H__
#define __LZMASDKOBJCUPDATECALLBACK_H__ 1

#include "LzmaSDKObjCBaseCoder.h"

#include "../lzma/CPP/7zip/Archive/IArchive.h"
#include "../lzma/CPP/7zip/IPassword.h"
#include "../lzma/CPP/7zip/ICoder.h"
#include "../lzma/CPP/Common/MyCom.h"
#include "../lzma/CPP/Common/MyString.h"
#include "../lzma/CPP/7zip/Common/FileStreams.h"

#include "LzmaSDKObjCOutFile.h"

namespace LzmaSDKObjC {
	
	class UpdateCallback final :
		public IArchiveUpdateCallback2,
		public ICryptoGetTextPassword,
		public ICryptoGetTextPassword2,
		public CMyUnknownImp,
		public LzmaSDKObjC::LastErrorHolder {
	private:
		UInt64 _total;

	public:

		MY_UNKNOWN_IMP3(IArchiveUpdateCallback2, ICryptoGetTextPassword, ICryptoGetTextPassword2)

		// IProgress
		STDMETHOD(SetTotal)(UInt64 size);
		STDMETHOD(SetCompleted)(const UInt64 *completeValue);

		// IUpdateCallback2
		STDMETHOD(GetUpdateItemInfo)(UInt32 index, Int32 *newData, Int32 *newProperties, UInt32 *indexInArchive);
		STDMETHOD(GetProperty)(UInt32 index, PROPID propID, PROPVARIANT *value);
		STDMETHOD(GetStream)(UInt32 index, ISequentialInStream **inStream);
		STDMETHOD(SetOperationResult)(Int32 operationResult);
		STDMETHOD(GetVolumeSize)(UInt32 index, UInt64 *size);
		STDMETHOD(GetVolumeStream)(UInt32 index, ISequentialOutStream **volumeStream);

		// ICryptoGetTextPassword
		STDMETHOD(CryptoGetTextPassword)(BSTR *password);

		// ICryptoGetTextPassword2
		STDMETHOD(CryptoGetTextPassword2)(Int32 *passwordIsDefined, BSTR *password);

		void * items;
		LzmaSDKObjC::BaseCoder * coder;

		UpdateCallback();

		virtual ~UpdateCallback();
	};
}

#endif
