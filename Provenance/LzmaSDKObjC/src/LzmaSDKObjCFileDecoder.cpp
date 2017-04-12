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


#include "LzmaSDKObjCFileDecoder.h"

#include "../lzma/CPP/Common/MyWindows.h"
#include "../lzma/CPP/Common/Defs.h"
#include "../lzma/CPP/Common/MyGuidDef.h"
#include "../lzma/CPP/Common/IntToString.h"
#include "../lzma/CPP/Common/StringConvert.h"

#include "../lzma/CPP/Windows/PropVariant.h"
#include "../lzma/CPP/Windows/PropVariantConv.h"

#include "../lzma/CPP/7zip/Common/FileStreams.h"
#include "../lzma/CPP/7zip/Archive/DllExports2.h" // custom header with `STDAPI CreateObject(const GUID *clsid, const GUID *iid, void **outObject);`
#include "../lzma/CPP/7zip/Archive/IArchive.h"
#include "../lzma/CPP/7zip/IPassword.h"

#include "LzmaSDKObjCCommon.h"
#include "LzmaSDKObjCInFile.h"
#include "LzmaSDKObjCOpenCallback.h"
#include "LzmaSDKObjCOutFile.h"


namespace LzmaSDKObjC {

	bool FileDecoder::process(const uint32_t * itemsIndices,
							  const uint32_t itemsCount,
							  const char * path /* = NULL */,
							  bool isWithFullPaths /* = false */) {
		this->cleanExtractCallbackRef();
		this->clearLastError();
		
		_extractCallbackRef = new LzmaSDKObjC::ExtractCallback();
		_extractCallback = CMyComPtr<IArchiveExtractCallback>(_extractCallbackRef);
		if (!_extractCallbackRef) {
			this->setLastError(-1, __LINE__, __FILE__, "Can't create extract object");
			return false;
		}

		int32_t mode = NArchive::NExtract::NAskMode::kSkip;
		if (path) {
			if (_extractCallbackRef->prepare(path, isWithFullPaths)) {
				mode = NArchive::NExtract::NAskMode::kExtract;
			} else {
				this->setLastError(_extractCallbackRef);
				return false;
			}
		} else {
			mode = NArchive::NExtract::NAskMode::kTest;
		}

		_extractCallbackRef->setCoder(this);
		_extractCallbackRef->setArchive(_archive);
		_extractCallbackRef->setMode(mode);

		const HRESULT result = _archive->Extract(itemsIndices, itemsCount, mode, _extractCallback);
		_extractCallbackRef->setArchive(NULL);

		if (result != S_OK) {
			this->setLastError(result, __LINE__, __FILE__, "Archive extract error with result: %lli", (long long)result);
			return false;
		}

		return true;
	}

	bool FileDecoder::readIteratorProperty(PROPVARIANT * property, const uint32_t identifier) {
		return (_iterateIndex < _itemsCount) ? (_archive->GetProperty(_iterateIndex, identifier, property) == S_OK) : false;
	}

	bool FileDecoder::prepare(const LzmaSDKObjCFileType type) {
		this->clearLastError();
		this->createObject(type, &IID_IInArchive, (void **)&_archive);
		return (_archive != NULL && this->lastError() == NULL);
	}

	bool FileDecoder::openFile(const char * path) {
		this->cleanOpenCallbackRef();
		this->cleanExtractCallbackRef();
		this->clearLastError();
		
		LzmaSDKObjC::InFile * inFile = new LzmaSDKObjC::InFile();
		if (!inFile) {
			this->setLastError(-1, __LINE__, __FILE__, "Can't open file for reading: [%s]", path);
			return false;
		}

		_inFile = inFile;

		_openCallbackRef = new LzmaSDKObjC::OpenCallback();
		_openCallback = CMyComPtr<IArchiveOpenCallback>(_openCallbackRef);
		if (!_openCallbackRef) {
			this->setLastError(-1, __LINE__, __FILE__, "Can't create open callback");
			return false;
		}

		_openCallbackRef->setCoder(this);

		if (!inFile->open(path)) {
			this->setLastError(-1, __LINE__, __FILE__, "Can't open file for reading: [%s]", path);
			this->setLastErrorReason("- File not exists.\n"
									 "- File have no read permissions for the current user.");
			return false;
		}

		HRESULT res = _archive->Open(_inFile, 0, _openCallback);
		if (res == S_OK) {
			UInt32 numItems = 0;
			res = _archive->GetNumberOfItems(&numItems);
			if (res != S_OK) {
				this->setLastError(res, __LINE__, __FILE__, "Can't receive number of archive items with result: %lli", (long long)res);
				return false;
			}
			_itemsCount = numItems;
			return true;
		}

		this->setLastError(res, __LINE__, __FILE__, "Can't open archive file with result: %lli", (long long)res);
		return false;
	}

	uint32_t FileDecoder::itemsCount() const { return _itemsCount; }
	void FileDecoder::iterateStart() { _iterateIndex = 0; }
	bool FileDecoder::iterateNext() { return (++_iterateIndex < _itemsCount); }
	uint32_t FileDecoder::iteratorIndex() const { return _iterateIndex; };

	FileDecoder::FileDecoder() : LzmaSDKObjC::BaseCoder(),
		_openCallbackRef(NULL),
		_extractCallbackRef(NULL),
		_itemsCount(0),
		_iterateIndex(0) {

	}

	void FileDecoder::cleanOpenCallbackRef() {
		CMyComPtr<IArchiveOpenCallback> op = _openCallback;
		if (op != NULL && _openCallbackRef) {
			_openCallbackRef->setCoder(NULL);
		}

		_openCallbackRef = NULL;
		_openCallback.Release();
	}

	void FileDecoder::cleanExtractCallbackRef() {
		CMyComPtr<IArchiveExtractCallback> ep = _extractCallback;
		if (ep != NULL && _extractCallbackRef) {
			_extractCallbackRef->setCoder(NULL);
		}

		_extractCallbackRef = NULL;
		_extractCallback.Release();
	}

	FileDecoder::~FileDecoder() {
		this->cleanOpenCallbackRef();
		this->cleanExtractCallbackRef();
	}

}

