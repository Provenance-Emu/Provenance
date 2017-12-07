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


#ifndef __LZMASDKOBJCOPENCALLBACK_H__
#define __LZMASDKOBJCOPENCALLBACK_H__ 1

#include "LzmaSDKObjCBaseCoder.h"

#include "../lzma/CPP/7zip/Archive/IArchive.h"
#include "../lzma/CPP/7zip/IPassword.h"
#include "../lzma/CPP/Common/MyCom.h"
#include "../lzma/CPP/Common/MyString.h"

namespace LzmaSDKObjC {
	
	class OpenCallback :
		public IArchiveOpenCallback,
		public ICryptoGetTextPassword,
		public ICryptoGetTextPassword2,
		public CMyUnknownImp,
		public LzmaSDKObjC::LastErrorHolder {
	private:
		LzmaSDKObjC::BaseCoder * _coder;

	public:
		MY_UNKNOWN_IMP3(IArchiveOpenCallback, ICryptoGetTextPassword, ICryptoGetTextPassword2)

		// IArchiveOpenCallback
		STDMETHOD(SetTotal)(const UInt64 *files, const UInt64 *bytes);
		STDMETHOD(SetCompleted)(const UInt64 *files, const UInt64 *bytes);

		// ICryptoGetTextPassword
		STDMETHOD(CryptoGetTextPassword)(BSTR *password);

		// ICryptoGetTextPassword2
		STDMETHOD(CryptoGetTextPassword2)(Int32 *passwordIsDefined, BSTR *password);

		void setCoder(LzmaSDKObjC::BaseCoder * coder) { _coder = coder; }

		OpenCallback();
		virtual ~OpenCallback();
	};
	
}

#endif 
