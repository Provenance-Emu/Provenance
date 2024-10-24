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


#include "LzmaSDKObjCOpenCallback.h"

#include "../lzma/CPP/Common/Defs.h"

namespace LzmaSDKObjC {

	STDMETHODIMP OpenCallback::SetTotal(const UInt64 * files, const UInt64 * bytes) {
		return S_OK;
	}

	STDMETHODIMP OpenCallback::SetCompleted(const UInt64 * files, const UInt64 * bytes) {
		return S_OK;
	}

	STDMETHODIMP OpenCallback::CryptoGetTextPassword(BSTR *password) {
		if (_coder) {
			UString w(_coder->onGetVoidCallback1());
			if (w.Len() > 0) return StringToBstr(w, password);
		}
		return S_OK;
	}

	STDMETHODIMP OpenCallback::CryptoGetTextPassword2(Int32 *passwordIsDefined, BSTR *password) {
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

	OpenCallback::OpenCallback() : LzmaSDKObjC::LastErrorHolder(),
		_coder(NULL) {

	}
	
	OpenCallback::~OpenCallback() {

	}
	
}

