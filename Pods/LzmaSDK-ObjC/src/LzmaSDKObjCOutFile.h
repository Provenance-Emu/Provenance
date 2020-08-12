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


#ifndef __LZMASDKOBJCOUTFILE_H__
#define __LZMASDKOBJCOUTFILE_H__ 1

#include "LzmaAppleCommon.h"
#include "LzmaSDKObjCTypes.h"
#include "LzmaSDKObjCCommon.h"

#include "../lzma/CPP/Common/MyCom.h"
#include "../lzma/CPP/Common/MyString.h"
#include "../lzma/CPP/7zip/Common/FileStreams.h"
#include "../lzma/C/7zCrc.h"

namespace LzmaSDKObjC {

	class OutFile final : public IOutStream, public CMyUnknownImp {
	private:
		FILE * _f;

	public:
		MY_UNKNOWN_IMP1(IOutStream)

		STDMETHOD(Write)(const void *data, UInt32 size, UInt32 *processedSize);
		STDMETHOD(Seek)(Int64 offset, UInt32 seekOrigin, UInt64 *newPosition);
		STDMETHOD(SetSize)(UInt64 newSize);

		bool open(const char * path);
		void close();

		OutFile();
		virtual ~OutFile();
	};

}

#endif 
