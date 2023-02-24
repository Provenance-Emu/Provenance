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

#import "LzmaSDKObjCUpdateCallback.h"
#include "../lzma/CPP/Common/Defs.h"
#include "../lzma/CPP/Windows/PropVariant.h"

#import "LzmaSDKObjCMutableItem.h"
#import "LzmaSDKObjCMutableItem+Private.h"
#import "LzmaSDKObjCItem+Private.h"

namespace LzmaSDKObjC {
	
	class NSDataFileStream final : public ISequentialInStream, public CMyUnknownImp {
	private:
		NSData * _data;
		NSUInteger _pos;
	public:
		MY_UNKNOWN_IMP1(ISequentialInStream)
		STDMETHOD(Read)(void *data, UInt32 size, UInt32 *processedSize);
		NSDataFileStream(NSData * data) : _data(data), _pos(0) { }
	};

	STDMETHODIMP NSDataFileStream::Read(void *data, UInt32 size, UInt32 *processedSize) {
		NSRange range = NSMakeRange(_pos, 0);
		if (size > 0) {
			const NSUInteger len = [_data length];
			const NSUInteger left = len > range.location ? len - range.location : 0;
			range.length = MIN(left, size);
			if (range.length) {
				_pos += range.length;
				[_data getBytes:data range:range];
			}
		}

		if (processedSize) *processedSize = (UInt32)range.length;
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::SetTotal(UInt64 size) {
		_total = size;
		if (coder) coder->onProgress(0);
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::SetCompleted(const UInt64 * completeValue) {
		if (completeValue && coder) {
			const long double complete = *completeValue;
			const float progress = (_total > 0) ? (float)(complete / _total) : 0;
			coder->onProgress(progress);
		}
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::GetUpdateItemInfo(UInt32 index, Int32 *newData, Int32 *newProperties, UInt32 *indexInArchive) {
		if (newData) {
			*newData = BoolToInt(true);
		}

		if (newProperties) {
			*newProperties = BoolToInt(true);
		}

		if (indexInArchive) {
			*indexInArchive = (UInt32)(Int32)-1;
		}

		return S_OK;
	}

	STDMETHODIMP UpdateCallback::GetProperty(UInt32 index, PROPID propID, PROPVARIANT *value) {
		NSMutableArray * arr = (__bridge NSMutableArray *)items;
		LzmaSDKObjCMutableItem * item = (arr && index < [arr count]) ? [arr objectAtIndex:index] : nil;
		if (!item) {
			this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't locate item at index: %lu.", (unsigned long)index);
			return E_ABORT;
		}

		NWindows::NCOM::CPropVariant prop;
		if (propID == kpidIsAnti) {
			prop = false;
			prop.Detach(value);
			return S_OK;
		}

	  switch (propID) {
		  case kpidPath: prop = UString((const wchar_t*)[item.path cStringUsingEncoding:NSUTF32LittleEndianStringEncoding]); break;
		  case kpidIsDir: prop = item.isDirectory ? true : false; break;
		  case kpidSize: prop = item->_orgSize; break;
//		  case kpidAttrib: prop = dirItem.Attrib; break;
		  case kpidCTime: prop = Common::UnixTimeToFILETIME(item->_cDate); break;
		  case kpidATime: prop = Common::UnixTimeToFILETIME(item->_aDate); break;
		  case kpidMTime: prop = Common::UnixTimeToFILETIME(item->_mDate); break;
	  }
		prop.Detach(value);
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::GetStream(UInt32 index, ISequentialInStream **inStream) {
		NSMutableArray * arr = (__bridge NSMutableArray *)items;
		LzmaSDKObjCMutableItem * item = (arr && index < [arr count]) ? [arr objectAtIndex:index] : nil;

		if (!item) return S_FALSE;
		if (item.isDirectory) return S_OK;

		NSData * data = item.fileData;
		if (data) {
			NSDataFileStream * stream = new NSDataFileStream(data);
			if (!stream) {
				this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't create NSData stream object.");
				return E_ABORT;
			}

			CMyComPtr<ISequentialInStream> inStreamLoc(stream);
			*inStream = inStreamLoc.Detach();
			return S_OK;
		}

		NSString * path = item.sourceFilePath;
		if (path) {
			const char * utf8Path = [path UTF8String];
			CInFileStream * inStreamSpec = new CInFileStream();
			if (!inStreamSpec) {
				this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't create file stream object for path: %s", utf8Path);
				return E_ABORT;
			}

			CMyComPtr<ISequentialInStream> inStreamLoc(inStreamSpec);
			if (inStreamSpec->Open(utf8Path)) {
				*inStream = inStreamLoc.Detach();
				return S_OK;
			} else {
				this->setLastError(E_ABORT, __LINE__, __FILE__, "Can't open file for reading at path: %s", utf8Path);
				return E_ABORT;
			}
		}

		LZMASDK_DEBUG_LOG("UpdateCallback::GetStream error: no source info for stream")
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::SetOperationResult(Int32 operationResult) {
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::GetVolumeSize(UInt32 index, UInt64 *size) {
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::GetVolumeStream(UInt32 index, ISequentialOutStream **volumeStream) {
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::CryptoGetTextPassword(BSTR *password) {
		if (coder) {
			if (coder->requiredCallback1()) {
				UString w(coder->onGetVoidCallback1());
				if (w.Len() > 0) return StringToBstr(w, password);
			}
		}
		return S_OK;
	}

	STDMETHODIMP UpdateCallback::CryptoGetTextPassword2(Int32 *passwordIsDefined, BSTR *password) {
		if (passwordIsDefined) *passwordIsDefined = BoolToInt(false);
		if (coder) {
			if (coder->requiredCallback1()) {
				UString w(coder->onGetVoidCallback1());
				if (w.Len() > 0) {
					if (passwordIsDefined) *passwordIsDefined = BoolToInt(true);
					return StringToBstr(w, password);
				}
			}
		}
		return S_OK;
	}

	UpdateCallback::UpdateCallback() : LzmaSDKObjC::LastErrorHolder(),
		_total(0),
		items(NULL),
		coder(NULL) {
		
	}

	UpdateCallback::~UpdateCallback() {

	}
}
