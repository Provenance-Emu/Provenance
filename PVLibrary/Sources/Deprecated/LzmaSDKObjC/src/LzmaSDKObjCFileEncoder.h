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


#ifndef __LZMASDKOBJCFILEENCODER_H__
#define __LZMASDKOBJCFILEENCODER_H__ 1

#include "LzmaSDKObjCBaseCoder.h"

#include "../lzma/CPP/7zip/Archive/IArchive.h"
#include "../lzma/CPP/7zip/IPassword.h"
#include "../lzma/CPP/7zip/Common/FileStreams.h"
#include "../lzma/CPP/Common/MyCom.h"
#include "../lzma/CPP/Common/MyString.h"
#include "../lzma/CPP/Windows/PropVariant.h"

#define LZMAOBJC_ENC_SOLID			1
#define LZMAOBJC_ENC_COMPR_HDR		(1 << 1)
#define LZMAOBJC_ENC_COMPR_HDR_FULL	(1 << 2)
#define LZMAOBJC_ENC_ENC_CONTENT	(1 << 3)
#define LZMAOBJC_ENC_ENC_HEADER		(1 << 4)
#define LZMAOBJC_ENC_WRITE_CTIME	(1 << 5)
#define LZMAOBJC_ENC_WRITE_MTIME	(1 << 6)
#define LZMAOBJC_ENC_WRITE_ATIME	(1 << 7)

namespace LzmaSDKObjC {
	
	class UpdateCallback;

	class FileEncoder final : public LzmaSDKObjC::BaseCoder {
	private:
		LzmaSDKObjC::UpdateCallback * _updateCallbackRef;
		COutFileStream * _outFileStreamRef;
		
		CMyComPtr<IOutArchive> _archive;
		CMyComPtr<IArchiveUpdateCallback2> _updateCallback;
		CMyComPtr<IOutStream> _outFileStream;

		unsigned char _settings;

		void cleanUpdateCallbackRef();
		void cleanOutFileStreamRef();
		void upplySettings();
	public:
		bool encodeItems(void * items, const uint32_t numItems);

		virtual bool requiredCallback1() const override final; // pwd.

		// Required section, `LzmaSDKObjC::BaseCoder`
		// find codec, create encode/decode object and check error.
		virtual bool prepare(const LzmaSDKObjCFileType type) override final;

		virtual bool openFile(const char * path) override final;

		// Properties
		void setSettingsValue(const bool value, const unsigned char flag);
		bool settingsValue(const unsigned char flag) const;
		unsigned char compressionLevel; //[1 .. 9]
		unsigned char method;

		FileEncoder();
		virtual ~FileEncoder();
	};
}

#endif
