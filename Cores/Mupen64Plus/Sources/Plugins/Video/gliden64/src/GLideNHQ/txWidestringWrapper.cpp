#ifdef OS_ANDROID

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include "txWidestringWrapper.h"

tx_wstring::tx_wstring(const wchar_t * wstr) : _wstring(wstr)
{
	wcstombs(cbuf, wstr, BUF_SIZE);
	_astring.assign(cbuf);
}

tx_wstring::tx_wstring(const tx_wstring & other) : _wstring(other.c_str())
{
	wcstombs(cbuf, other.c_str(), BUF_SIZE);
	_astring.assign(cbuf);
}

void tx_wstring::assign(const wchar_t * wstr)
{
	_wstring.assign(wstr);
	wcstombs(cbuf, wstr, BUF_SIZE);
	_astring.assign(cbuf);
}

void tx_wstring::assign(const tx_wstring & wstr)
{
	_wstring.assign(wstr.c_str());
	wcstombs(cbuf, wstr.c_str(), BUF_SIZE);
	_astring.assign(cbuf);
}

void tx_wstring::append(const tx_wstring & wstr)
{
	wcstombs(cbuf, wstr.c_str(), BUF_SIZE);
	_astring.append(cbuf);
	mbstowcs(wbuf, _astring.c_str(), BUF_SIZE);
	_wstring.assign(wbuf);
}

tx_wstring & tx_wstring::operator=(const tx_wstring & other)
{
	assign(other);
	return *this;
}

tx_wstring & tx_wstring::operator+=(const tx_wstring & other)
{
	append(other);
	return *this;
}

tx_wstring & tx_wstring::operator+=(const wchar_t * wstr)
{
	append(wstr);
	return *this;
}

tx_wstring tx_wstring::operator+(const tx_wstring & wstr) const
{
	tx_wstring ans(_wstring.c_str());
	ans.append(wstr);
	return ans;
}

tx_wstring tx_wstring::operator+(const wchar_t * wstr) const
{
	tx_wstring ans(_wstring.c_str());
	ans.append(wstr);
	return ans;
}

const wchar_t * tx_wstring::c_str() const
{
	return _wstring.c_str();
}

bool tx_wstring::empty() const
{
	return _astring.empty();
}

int tx_wstring::compare(const wchar_t * wstr)
{
	wcstombs(cbuf, wstr, BUF_SIZE);
	return _astring.compare(cbuf);
}

dummyWString::dummyWString(const char * _str)
{
	wchar_t buf[BUF_SIZE];
	mbstowcs(buf, _str, BUF_SIZE);
	_wstr.assign(buf);
}

int tx_swprintf(wchar_t* ws, size_t len, const wchar_t* format, ...)
{
	char cbuf[BUF_SIZE];
	char fmt[BUF_SIZE];
	wcstombs(fmt, format, BUF_SIZE);

	va_list ap;
	va_start(ap, format);
	int res = vsprintf(cbuf, fmt, ap);
	va_end(ap);
	mbstowcs(ws, cbuf, len);
	return res;
}

bool wccmp(const wchar_t* w1, const wchar_t* w2)
{
	char cbuf1[16];
	wcstombs(cbuf1, w1, 16);
	char cbuf2[16];
	wcstombs(cbuf2, w2, 16);
	return cbuf1[0] == cbuf2[0];
}
#endif // OS_ANDROID
