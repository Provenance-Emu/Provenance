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


#include "LzmaSDKObjCInFile.h"

namespace LzmaSDKObjC {

	STDMETHODIMP InFile::Read(void *data, UInt32 size, UInt32 *processedSize) {
		if (processedSize) *processedSize = 0;
		if (_f && size > 0) {
			const size_t r = fread(data, 1, size, _f);
			if (processedSize) *processedSize = (UInt32)r;
		}
		return S_OK;
	}

	STDMETHODIMP InFile::Seek(Int64 offset, uint32_t seekOrigin, UInt64 *newPosition) {
		if (newPosition) *newPosition = 0;
		if (_f) {
			if (fseeko(_f, offset, seekOrigin) == 0) {
				if (newPosition) *newPosition = ftello(_f);
				return S_OK;
			}
		}
		return S_FALSE;
	}

	bool InFile::open(const char * p) {
		if (p) _f = fopen(p, "rb");
		return (_f != NULL);
	}

	void InFile::close() {
		if (_f) {
			fclose(_f);
			_f = NULL;
		}
	}

	InFile::InFile() :
		_f(NULL) {

	}
	
	InFile::~InFile() {
		this->close();
	}
	
}

