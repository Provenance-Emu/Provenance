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


#include "LzmaSDKObjCOutFile.h"
#include <unistd.h>

namespace LzmaSDKObjC {

	STDMETHODIMP OutFile::Write(const void *data, UInt32 size, UInt32 *processedSize) {
		if (_f) {
			const size_t writed = fwrite(data, 1, size, _f);
			if (processedSize) *processedSize = (UInt32)writed;
		}
		return S_OK;
	}

	STDMETHODIMP OutFile::Seek(Int64 offset, UInt32 seekOrigin, UInt64 *newPosition) {
		if (_f) {
			if (fseeko(_f, offset, seekOrigin) == 0) {
				if (newPosition) *newPosition = ftello(_f);
			} else {
				return S_FALSE;
			}
		}
		return S_OK;
	}

	STDMETHODIMP OutFile::SetSize(UInt64 newSize) {
		return S_OK;
	}

	bool OutFile::open(const char * path) {
		if (path) _f = fopen(path, "w+b");
		return (_f != NULL);
	}

	void OutFile::close() {
		if (_f) {
			fclose(_f);
			_f = NULL;
		}
	}

	OutFile::OutFile() :
		_f(NULL) {

	}

	OutFile::~OutFile() {
		this->close();
	}
	
}


