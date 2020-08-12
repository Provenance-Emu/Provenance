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

#include <Foundation/Foundation.h>

#include "LzmaSDKObjCExtractCallback.h"
#include "LzmaSDKObjCCommon.h"

#include "../lzma/CPP/Common/Defs.h"
#include "../lzma/CPP/Windows/PropVariant.h"
#include "../lzma/CPP/7zip/Archive/Common/DummyOutStream.h"

namespace LzmaSDKObjC {
	
	STDMETHODIMP ExtractCallback::ReportExtractResult(UInt32 indexType, UInt32 index, Int32 opRes) {
		return S_OK;
	}

	STDMETHODIMP ExtractCallback::SetRatioInfo(const UInt64 *inSize, const UInt64 *outSize) {
		return S_OK;
	}

	STDMETHODIMP ExtractCallback::SetTotal(UInt64 size) {
		_total = size;
		if (_coder) _coder->onProgress(0);
		return S_OK;
	}

	STDMETHODIMP ExtractCallback::SetCompleted(const UInt64 * completeValue) {
		if (completeValue && _coder) {
			const long double complete = *completeValue;
			const float progress = (_total > 0) ? (float)(complete / _total) : 0;
			_coder->onProgress(progress);
		}
		return S_OK;
	}

	HRESULT ExtractCallback::getTestStream(uint32_t index, ISequentialOutStream **outStream) {
		CDummyOutStream * dummy = new CDummyOutStream();
		if (!dummy) {
			this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't create out test stream");
			return E_ABORT;
		}

		CMyComPtr<ISequentialOutStream> outStreamLoc = dummy;

		_outFileStream = outStreamLoc;
		*outStream = outStreamLoc.Detach();

		return S_OK;
	}

	HRESULT ExtractCallback::getExtractStream(uint32_t index, ISequentialOutStream **outStream) {
		PROPVARIANT pathProp;
        memset(&pathProp, 0, sizeof(PROPVARIANT));
		if (_archive->GetProperty(index, kpidPath, &pathProp) != S_OK) {
			this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't read path property by index: %i", (int)index);
			return E_ABORT;
		}

		NSString * archivePath = [[NSString alloc] initWithBytes:pathProp.bstrVal
														  length:wcslen(pathProp.bstrVal) * sizeof(wchar_t)
														encoding:NSUTF32LittleEndianStringEncoding];
		if (!archivePath || [archivePath length] == 0) {
			this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't initialize path object");
			return E_ABORT;
		}

		NSString * fullPath = [NSString stringWithUTF8String:_dstPath];
		NSString * fileName = [archivePath lastPathComponent];
		if (!fileName || [fileName length] == 0) {
			this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't initialize path file name");
			return E_ABORT;
		}

		if (_isFullPath) {
			NSString * subPath = [archivePath stringByDeletingLastPathComponent];
			if (subPath && [subPath length] > 0) {
                NSString * fullSubPath = [fullPath stringByAppendingPathComponent:subPath];
				NSFileManager * manager = [NSFileManager defaultManager];
				BOOL isDir = NO;
				NSError * error = nil;
				if ([manager fileExistsAtPath:fullSubPath isDirectory:&isDir]) {
					if (!isDir) {
						this->setLastError(E_ABORT, __LINE__, __FILE__, "Destination path: [%s] exists in directory: [%s] and it's file", [subPath UTF8String], [fullPath UTF8String]);
						return E_ABORT;
					}
				} else if (![manager createDirectoryAtPath:fullSubPath withIntermediateDirectories:YES attributes:nil error:&error] || error) {
					this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't create subdirectory: [%s] in directory: [%s]", [subPath UTF8String], [fullPath UTF8String]);
					return E_ABORT;
				}

				fullPath = fullSubPath;
			}
		}

		fullPath = [fullPath stringByAppendingPathComponent:fileName];

		PROPVARIANT isDirProp = {0};
		HRESULT res = _archive->GetProperty(index, kpidIsDir, &isDirProp);
		if (res != S_OK) {
			this->setLastError(res, __LINE__, __FILE__, "Can't get property of the item by index: %u", (unsigned int)index);
			return res;
		}

		if (Common::PROPVARIANTGetBool(&isDirProp)) {
			NSError * error = nil;
			if (![[NSFileManager defaultManager] createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:&error] || error) {
				this->setLastError(S_FALSE, __LINE__, __FILE__, "Can't create directory: [%s]", [fullPath UTF8String]);
				return E_ABORT;
			}
		} else {
			LzmaSDKObjC::OutFile * outFile = new LzmaSDKObjC::OutFile();
			if (!outFile) {
				this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't create out file stream");
				return E_ABORT;
			}

			if (!outFile->open([fullPath UTF8String])) {
				delete outFile;
				this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't open destination for write: [%s]", [fullPath UTF8String]);
				return E_ABORT;
			}

			_outFileStreamRef = outFile;
			CMyComPtr<ISequentialOutStream> outStreamLoc = _outFileStreamRef;

			_outFileStream = outStreamLoc;
			*outStream = outStreamLoc.Detach();
		}

		return S_OK;
	}

	STDMETHODIMP ExtractCallback::GetStream(UInt32 index,
											ISequentialOutStream **outStream,
											Int32 askExtractMode) {
		*outStream = NULL;
		_outFileStream.Release();
		_outFileStreamRef = NULL;

		if (!_archive) {
			this->setLastError(E_ABORT, __LINE__, __FILE__, "No input archive");
			return E_ABORT;
		}

        if (_itemsIndices) {
            uint32_t key = index;
            uint32_t * indexPtr = (uint32_t *)bsearch(&key, _itemsIndices, _itemsIndicesCount, sizeof(uint32_t), LzmaSDKObjC::Common::compareIndices);
            if (!indexPtr) {
                return S_OK;
            }
        }
        
		switch (_mode) {
			case NArchive::NExtract::NAskMode::kExtract:
				return this->getExtractStream(index, outStream);
				break;

			case NArchive::NExtract::NAskMode::kTest:
				return this->getTestStream(index, outStream);
				break;

			case NArchive::NExtract::NAskMode::kSkip:
				return S_OK;
				break;
		}

		return E_FAIL;
	}

	STDMETHODIMP ExtractCallback::PrepareOperation(Int32 askExtractMode) {
		return S_OK;
	}

	STDMETHODIMP ExtractCallback::SetOperationResult(Int32 operationResult) {
		HRESULT res = E_FAIL;
		switch (operationResult) {
			case NArchive::NExtract::NOperationResult::kOK:
				res = S_OK;
				break;

			case NArchive::NExtract::NOperationResult::kUnsupportedMethod:
				this->setLastError(operationResult, __LINE__, __FILE__, "kUnsupportedMethod");
				break;

			case NArchive::NExtract::NOperationResult::kCRCError:
				this->setLastError(operationResult, __LINE__, __FILE__, "kCRCError");
				break;

			case NArchive::NExtract::NOperationResult::kDataError:
				this->setLastError(operationResult, __LINE__, __FILE__, "kDataError");
				break;

			case NArchive::NExtract::NOperationResult::kUnavailable:
				this->setLastError(operationResult, __LINE__, __FILE__, "kUnavailable");
				break;

			case NArchive::NExtract::NOperationResult::kUnexpectedEnd:
				this->setLastError(operationResult, __LINE__, __FILE__, "kUnexpectedEnd");
				break;

			case NArchive::NExtract::NOperationResult::kDataAfterEnd:
				this->setLastError(operationResult, __LINE__, __FILE__, "kDataAfterEnd");
				break;

			case NArchive::NExtract::NOperationResult::kIsNotArc:
				this->setLastError(operationResult, __LINE__, __FILE__, "kIsNotArc");
				break;

			case NArchive::NExtract::NOperationResult::kHeadersError:
				this->setLastError(operationResult, __LINE__, __FILE__, "kHeadersError");
				break;

			default:
				break;
		}

		if (_outFileStream != NULL) {
			if (_outFileStreamRef) _outFileStreamRef->close();
		}
		_outFileStream.Release();
		_outFileStreamRef = NULL;
		return res;
	}

	STDMETHODIMP ExtractCallback::CryptoGetTextPassword(BSTR *password) {
		if (_coder) {
			UString w(_coder->onGetVoidCallback1());
			if (w.Len() > 0) return StringToBstr(w, password);
		}
		return S_OK;
	}

	STDMETHODIMP ExtractCallback::CryptoGetTextPassword2(Int32 *passwordIsDefined, BSTR *password) {
		if (passwordIsDefined) *passwordIsDefined = BoolToInt(false);
		if (_coder) {
			UString w(_coder->onGetVoidCallback1());
			if (w.Len() > 0) {
				if (passwordIsDefined) *passwordIsDefined = BoolToInt(true);
				return StringToBstr(w, password);
			}
		}
		return S_OK;
	}
    
	bool ExtractCallback::prepare(const char * extractPath, bool isFullPath) {
		_dstPath = extractPath;
		_isFullPath = isFullPath;

		NSString * path = [NSString stringWithUTF8String:extractPath];

		NSFileManager * manager = [NSFileManager defaultManager];
		BOOL isDir = NO;
		if ([manager fileExistsAtPath:path isDirectory:&isDir]) {
			if (!isDir) {
				this->setLastError(-1, __LINE__, __FILE__, "Extract path: [%s] exists and it's file", extractPath);
				return false;
			}
		} else {
			NSError * error = nil;
			if (![manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error] || error) {
				this->setLastError(-1, __LINE__, __FILE__, "Can't create directory path: [%s]", [path UTF8String]);
				return false;
			}
		}

		return true;
	}

	ExtractCallback::ExtractCallback() : LzmaSDKObjC::LastErrorHolder(),
		_outFileStreamRef(NULL),
		_coder(NULL),
		_archive(NULL),
        _itemsIndices(NULL),
		_total(0),
        _itemsIndicesCount(0),
		_mode(NArchive::NExtract::NAskMode::kSkip),
		_isFullPath(false) {

	}

	ExtractCallback::~ExtractCallback() {

	}
	
}

