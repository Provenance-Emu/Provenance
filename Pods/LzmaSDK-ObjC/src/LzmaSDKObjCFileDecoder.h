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


#ifndef __LZMASDKOBJCFILEDECODER_H__
#define __LZMASDKOBJCFILEDECODER_H__ 1

#include "LzmaSDKObjCBaseCoder.h"

#include "../lzma/CPP/7zip/Archive/IArchive.h"
#include "../lzma/CPP/7zip/IPassword.h"
#include "../lzma/CPP/Common/MyCom.h"
#include "../lzma/CPP/Common/MyString.h"
#include "../lzma/CPP/Windows/PropVariant.h"

#include "LzmaSDKObjCOpenCallback.h"
#include "LzmaSDKObjCExtractCallback.h"

namespace LzmaSDKObjC {
	
	class FileDecoder final : public LzmaSDKObjC::BaseCoder {
	private:
		LzmaSDKObjC::OpenCallback * _openCallbackRef;
		LzmaSDKObjC::ExtractCallback * _extractCallbackRef;

		CMyComPtr<IInArchive> _archive;
		CMyComPtr<IInStream> _inFile;
		CMyComPtr<IArchiveOpenCallback> _openCallback;
		CMyComPtr<IArchiveExtractCallback> _extractCallback;

		uint32_t _itemsCount;
		uint32_t _iterateIndex;
        
		void cleanOpenCallbackRef();
		void cleanExtractCallbackRef();

	public:
        bool isSolidArchive() const;
		uint32_t itemsCount() const;
		void iterateStart();
		bool iterateNext();
		uint32_t iteratorIndex() const;

		bool readIteratorProperty(PROPVARIANT * property, const uint32_t identifier);

		bool process(const uint32_t * itemsIndices,
					 const uint32_t itemsCount,
					 const char * path = NULL,
					 bool isWithFullPaths = false);

		// Required section, `LzmaSDKObjC::BaseCoder`
		// find codec, create encode/decode object and check error.
		virtual bool prepare(const LzmaSDKObjCFileType type) override final;

		virtual bool openFile(const char * path) override final;

		FileDecoder();
		virtual ~FileDecoder();
	};
}

#endif 
